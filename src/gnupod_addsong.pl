#!/usr/bin/perl -w

use strict;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::FileMagic;
use Getopt::Long;
use File::Copy;
use vars qw(%opts);

print "gnupod_addsong.pl Version 0.9-rc0 (C) 2002-2003 Adrian Ulrich\n";
print "-------------------------------------------------------------\n";
print "This program may be copied only under the terms of the\n";
print "GNU General Public License v2 or later.\n";
print "-------------------------------------------------------------\n\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s", "restore|r", "duplicate|d");

usage() if $opts{help};



if($opts{restore}) {
 print "If you use --restore, you'll *lose* your playlists\n";
 print " Hit ENTER to continue or CTRL+C to abort\n\n";
 <STDIN>;
 $opts{duplicate} = 1; #Don't skip dups on restore
 startup(glob("$opts{mount}/iPod_Control/Music/F*/*"));
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
   if($opts{restore} || File::Copy::copy($file, $target)) {
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





