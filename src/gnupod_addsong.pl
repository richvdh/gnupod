#!/usr/bin/perl -w

use strict;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::FileMagic;
use Getopt::Long;
use vars qw($xmldoc %opts);

print "gnupod_addsong.pl Version 0.9-rc0 (C) 2002-2003 Adrian Ulrich\n";
print "-------------------------------------------------------------\n";
print "This program may be copied only under the terms of the\n";
print "GNU General Public License v2 or later.\n";
print "-------------------------------------------------------------\n\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
GetOptions(\%opts, "help|h", "xml|x=s", "mount|m=s");

usage() if $opts{help};

startup(@ARGV);

sub startup {
 my(@files) = @_;
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);
 if($stat) {
  usage($stat."\n");
 }
 ($xmldoc) = GNUpod::XMLhelper::parsexml($xml) or usage("Failed to parse $xml\n");
 
 foreach(@files) {
  my %fh = GNUpod::FileMagic::wtf_is($_);
  unless(%fh) {
   print "** Blabla.. unknown file type, skipping $_\n";
   next;
  }
 }
 
}




sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_addsong.pl [-h] [-m directory | -x GNUtunesDB] File1 File2 ...

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -x, --xml=file         : GNUtunesDB (XML File)

EOF
}





