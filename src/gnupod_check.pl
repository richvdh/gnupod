###__PERLBIN__###
#  Copyright (C) 2002-2004 Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://www.gnu.org/software/gnupod/
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;
use vars qw(%opts %TRACKER);

print "gnupod_check.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s");
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s'}, "gnupod_check");

usage() if $opts{help};

go();

####################################################
# Worker
sub go {
 my $con = GNUpod::FooBar::connect(\%opts);
 usage($con->{status}."\n") if $con->{status};

 print "Pass 1: Checking Files in the GNUtunesDB.xml...\n";
 GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}\n");

 print "Pass 2: Checking Files on the iPod...\n";
 checkGNUtunes();
 
 print "..finished\n\n";
 print "  Total Playtime : ".int($TRACKER{TIME}/1000/60/60)." h\n";
 print "  Space used     : ".int($TRACKER{SIZE}/1024/1024/1024)." GB\n";
 print "  iPod files     : $TRACKER{GLOBFILES}\n";
 print "  GNUpod files   : $TRACKER{ITFILES}\n";
 
 if($TRACKER{GLOBFILES} == $TRACKER{ITFILES} && $TRACKER{ERR} == 0) {
  print " -> Everything is fine :)\n";
 }
 elsif($TRACKER{GLOBFILES} != $TRACKER{ITFILES}) {
  print " -> The GNUtunesDB.xml is inconsistent. Please try to fix the errors.\n";
 }
 
 if($TRACKER{ERR} > 25) {
  print " -> I found MANY ($TRACKER{ERR}) errors. Maybe you should run\n";
  print "    'gnupod_addsong.pl --restore'. This would wipe all your Playlists\n";
  print "    but you would get rid of the inconsistenty very fast...\n";
 }
 
}

############################################
# Glob all files
sub checkGNUtunes {
  foreach my $file (glob($opts{mount}."/iPod_Control/Music/*/*")) {
   next if -d $file;
    $TRACKER{GLOBFILES}++;
    unless($TRACKER{PATH}{lc($file)}) { #Hmpf.. file maybe not in the GNUtunesDB
      print "  Stale file '$file' found. Remove the file, it wastes space...\n"; 
     $TRACKER{ERR}++;
    }
  }
}

#############################################
# Eventhandler for FILE items
sub newfile {
 my($el) =  @_;
 
 my $rp = GNUpod::XMLhelper::realpath($opts{mount},$el->{file}->{path});
 my $id = $el->{file}->{id};
 
 my $HINT = "Remove this zombie using 'gnupod_search --delete -i \"^$id\$\"'";

 $TRACKER{SIZE}+=int($el->{file}->{filesize});
 $TRACKER{TIME}+=int($el->{file}->{time});
 
 $TRACKER{ID}{int($id)}++;
 $TRACKER{PATH}{lc($rp)}++; #FAT32 is caseInsensitive.. HFS+ should also be caseInsensitive (ON THE IPOD)
 $TRACKER{ITFILES}++;
 
 if($TRACKER{ID}{int($id)} != 1) {
  print "  ID $id is used ".int($TRACKER{ID}{int($id)})." times!\n";
  $TRACKER{ERR}++;
 }
 
 if(int($id) < 1) {
  print "  ID $id is < 1 .. You shouldn't do this!\n";
  $TRACKER{ERR}++;
 }
 
 if(!-e $rp) {
  print "  ID $id vanished! ($rp) -> $HINT\n";
  $TRACKER{ERR}++;
 }
 elsif(-d $rp) {
  print "  ID $id is a DIRECTORY?! ($rp)\n";
 }
 elsif(-s $rp < 1) {
  print "  ID $id has zero size! ($rp) -> $HINT\n";
  $TRACKER{ERR}++;
 }
 
 

}

############################################
# Eventhandler for PLAYLIST items
sub newpl {
}



###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_check.pl [-h] [-m directory]

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

 gnupod_check.pl checks for 'lost' files

EOF
}


