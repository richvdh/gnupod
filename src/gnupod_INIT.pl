#!/usr/bin/perl

#  Copyright (C) 2002-2003 Adrian Ulrich <pab at blinkenlights.ch>
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
use GNUpod::FooBar;
use GNUpod::XMLhelper;
use Getopt::Long;
use vars qw(%opts);


print "gnupod_addsong.pl Version 0.92 (C) 2002-2003 Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s", "disable-convert|d", "france|f");

usage() if $opts{help};

go();


sub go {
 
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);
 usage("$stat\n") if $stat;

## Ask the user, if he still knows what he/she's doing..
print << "EOF";

Your iPod it mounted at $opts{mount}, ok ?
=========================================================
This tool creates the default directory tree on your iPod
and creates an *empty* GNUtunesDB (..or convert your old
iTunesDB to a new GNUtunesDB).

You only have to use this command if
 a) You never used GNUpod with this iPod
 b) You did an 'rm -rf' on your iPod

btw: use 'gnupod_addsong -m $opts{mount} --restore'
     if you lost your songs on the iPod after using
     gnupod_INIT.pl (..but this won't happen, because
     this tool has no bugs ;) )


Hit ENTER to continue or CTRL+C to abort

EOF
##

<STDIN>;
 
 print "Creating directory structure on $opts{mount}\n\n";
 print "> AppFolders:\n";
 
 foreach( ("iPod_Control", "iPod_Control/Music",
             "iPod_Control/iTunes", "iPod_Control/.gnupod") ) {
   my $path = "$opts{mount}/$_";
   next if -d $path;
   mkdir("$path") or die "Could not create $path ($!)\n";
   print "+$path\n";
 }
 
 print "> Music folders:\n";
 for(0..19) {
   my $path = sprintf("$opts{mount}/iPod_Control/Music/F%02d", $_);
   next if -d $path;
   mkdir("$path") or die "Could not create $path ($!)\n";
   print "+$path\n";
 }

if($opts{france}) {
 print "> Creating 'Limit' file (because you used --france)\n";
 mkdir("$opts{mount}/iPod_Control/Device");
 open(LIMIT, ">$opts{mount}/iPod_Control/Device/Limit") or die "Failed: $!\n";
  print LIMIT "216\n"; #Why?
 close(LIMIT);
}
else {
 print "> Removing 'Limit' file (because you didn't use --france)\n";
 unlink("$opts{mount}/iPod_Control/Device/Limit");
}
 
 print "> Creating dummy files\n";
 
  GNUpod::XMLhelper::writexml($xml);
 
 if(-e $itunes && !$opts{'disable-convert'}) {
 ## Fixme: Does this work??
  print "Found *existing* iTunesDB, running tunes2pod.pl\n";
  system("tunes2pod.pl -m $opts{mount}");
 }
 else {
  print "No iTunesDB found, creating a dummy file\n";
  open(ITUNES, ">$itunes") or die "Could not create $itunes: $!\n";
   print ITUNES "";
  close(ITUNES);
 }
 
 print "\n Done\n   Your iPod is now ready for GNUpod :)\n";
}



###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_INIT.pl [-h] [-m directory]

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -d, --disable-convert  : Don't try to convert an exiting iTunesDB
   -f, --france           : Limit Volume to 100dB (For French-People)
                            Maximal-volume without this is ~104dB (VERY LOUD)
			    *WARNING* This works only for iPods running
			    Firmware 1.x (1st & 2nd generation)

EOF
}

