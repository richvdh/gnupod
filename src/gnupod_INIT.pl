#!/usr/bin/perl

use strict;
use GNUpod::FooBar;
use GNUpod::XMLhelper;
use Getopt::Long;
use vars qw(%opts);

print "gnupod_addsong.pl Version 0.9-rc0 (C) 2002-2003 Adrian Ulrich\n";
print "-------------------------------------------------------------\n";
print "This program may be copied only under the terms of the\n";
print "GNU General Public License v2 or later.\n";
print "-------------------------------------------------------------\n\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s");

usage() if $opts{help};

print << "EOF";
Your iPod is mounted at $opts{mount} , ok?
FIXME:: Write some txt

EOF
<STDIN>;
go();


sub go {
 
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);
 usage("$stat\n") if $stat;
 
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
 
 print "> Creating dummy files\n";
 
  my($xmldoc) = GNUpod::XMLhelper::parsexml($xml, cleanit=>1);
  GNUpod::XMLhelper::write_xml($xml, $xmldoc);
 
 if(-e $itunes) {
 ## Fixme: Does this work??
  print "Found *existing* iTunesDB, running tunes2pod.pl\n";
  system("tunes2pod.pl -m $opts{mount}") or die "Failed to run tunes2pod.pl : $!\n";
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

EOF
}

