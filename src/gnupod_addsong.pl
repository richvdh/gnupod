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
GetOptions(\%opts, "help|h", "mount|m=s");

usage() if $opts{help};

startup(@ARGV);

sub startup {
 my(@files) = @_;
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);

 usage($stat."\n") if $stat;
my ($xmldoc) = GNUpod::XMLhelper::parsexml($xml) or usage("Failed to parse $xml\n");

#We are ready to copy each file..
 foreach my $file (@files) {
    #Get the filetype
    my $fh = GNUpod::FileMagic::wtf_is($file);
    unless($fh) {
     print STDERR "*** Skipping '$file'\n";
     next;
    }
   
   #Get a path
   (${$fh}{path}, my $target) = GNUpod::XMLhelper::getpath($opts{mount}, $file);
   #Copy the file
   if(File::Copy::copy($file, $target)) {
#  if(1) { print "FIXME:: Didn't copy!\n";
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




sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_addsong.pl [-h] [-m directory | -x GNUtunesDB] File1 File2 ...

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
}





