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
use GNUpod::FileMagic;
use Getopt::Long;
use File::Copy;
use vars qw(%opts %dupdb);

print "gnupod_addsong.pl Version 0.94 (C) 2002-2004 Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s", "restore|r", "duplicate|d");

usage() if $opts{help};



if($opts{restore}) {
 print "If you use --restore, you'll *lose* your playlists\n";
 print " Hit ENTER to continue or CTRL+C to abort\n\n";
 <STDIN>;
 $opts{duplicate} = 1; #Don't skip dups on restore
 startup(glob("$opts{mount}/iPod_Control/Music/*/*"));
}
elsif($ARGV[0] eq "-" && @ARGV == 1) {
 print STDERR "Reading from STDIN, hit CTRL+D (EOF) when finished\n";
 my @files = ();
  while(<STDIN>) {
   chomp;
   push(@files, $_);
  }
  startup(@files);
}
else {
 startup(@ARGV);
}



####################################################
# Worker
sub startup {
 my(@files) = @_;
 
 #Don't sync if restore is true
 $opts{_no_sync} = $opts{restore};
 
 my $con = GNUpod::FooBar::connect(\%opts);
usage($con->{status}."\n") if $con->{status} || !@files;

unless($opts{restore}) {
 GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}\n");
}

my $addcount = 0;

#We are ready to copy each file..
 foreach my $file (@files) {
    #Skip dirs..
    next if -d $file;
    
    #Get the filetype
    my $fh = GNUpod::FileMagic::wtf_is($file);
    
    unless($fh) {
     print STDERR "* Skipping '$file', unknown file type\n";
     next;
    }
   
   #Get a path
   (${$fh}{path}, my $target) = GNUpod::XMLhelper::getpath($opts{mount}, $file, keepfile=>$opts{restore});
   #Copy the file
   if(!$opts{duplicate} && (my $dup = checkdup($fh))) {
    print "! '$fh->{title}' is a duplicate of song $dup, skipping file\n";
    next;
   }
   if($opts{restore} || File::Copy::copy($file, $target)) {
     print "+ $file ($fh->{album} / $fh->{title})\n";
     my $fmh;
     $fmh->{file} = $fh;
     GNUpod::XMLhelper::mkfile($fmh,{addid=>1}); #Try to add an id
     $addcount++;
   }
   else { #We failed..
     print STDERR "-- FATAL -- Could not copy $file to $target: $! ... skipping\n";
   }
   
 }

if($addcount) { #We have to modify the xmldoc
 print "> Writing new XML File\n";
 GNUpod::XMLhelper::writexml($con->{xml});
}
 print "\n Done\n";
}

## XML Handlers ##
sub newfile {
 $dupdb{"$_[0]->{file}->{bitrate}/$_[0]->{file}->{time}/$_[0]->{file}->{filesize}"}= $_[0]->{file}->{id}||-1;
 GNUpod::XMLhelper::mkfile($_[0],{addid=>1});
}

sub newpl {
 GNUpod::XMLhelper::mkfile($_[0],{$_[2]."name"=>$_[1]});
}
##################


###############################################################
# Check if the file is a duplicate
sub checkdup {
 my($fh) = @_;
 return $dupdb{"$fh->{bitrate}/$fh->{time}/$fh->{filesize}"};
}

###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_addsong.pl [-h] [-m directory] File1 File2 ...

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -r, --restore          : Restore the iPod (create a new GNUtunesDB from scratch)
   -d, --duplicate        : Allow duplicate files

EOF
}





