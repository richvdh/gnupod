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
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::FileMagic;
use Getopt::Long;
use File::Copy;
use vars qw(%opts);

print "gnupod_addsong.pl Version 0.90 (C) 2002-2003 Adrian Ulrich\n";

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
else {
 startup(@ARGV);
}



####################################################
# Worker
sub startup {
 my(@files) = @_;
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);

 usage($stat."\n") if $stat;
my ($xmldoc) = GNUpod::XMLhelper::parsexml($xml, cleanit=>$opts{restore}) or usage("Failed to parse $xml\n");
my ($qh) = GNUpod::XMLhelper::build_quickhash($xmldoc);
 usage("Could not open $xml , did you run gnupod_INIT.pl ?\n") unless $xmldoc;


#We are ready to copy each file..
 foreach my $file (@files) {
    #Get the filetype
    my $fh = GNUpod::FileMagic::wtf_is($file);
    unless($fh) {
     print STDERR "*** Skipping '$file'\n";
     next;
    }
   
   #Get a path
   (${$fh}{path}, my $target) = GNUpod::XMLhelper::getpath($opts{mount}, $file, keepfile=>$opts{restore});
   #Copy the file
   if(!$opts{duplicate} && (my $dup = checkdup($qh, $fh))) {
    print "> $fh->{title} is a duplicate of song $dup, skipping file\n";
    next;
   }
   if($opts{restore} || File::Copy::copy($file, $target)) {
     print "+ $fh->{title}\n";
     GNUpod::XMLhelper::addfile($xmldoc, $fh);
   }
   else { #We failed..
     print STDERR "-- FATAL -- Could not copy $file to $target: $! ... skipping\n";
   }
   
 }
 print "> Writing new XML File\n";
 GNUpod::XMLhelper::write_xml($xml, $xmldoc);
 print "\n Done\n";
}

sub checkdup {
 my($qh, $fh) = @_;
 foreach my $item (keys(%$qh)) {
  if($qh->{$item}->{filesize} == $fh->{filesize} &&
     $qh->{$item}->{bitrate}  == $fh->{bitrate}  &&
     $qh->{$item}->{time}     == $fh->{time}) {
    return $item || -1; #This is a duplicate   
  }
 }
 return undef; #no match
}

###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_addsong.pl [-h] [-m directory | -x GNUtunesDB] File1 File2 ...

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -r, --restore          : Restore the iPod (create a new GNUtunesDB from scratch)
   -d, --duplicate        : Allow duplicate files

EOF
}





