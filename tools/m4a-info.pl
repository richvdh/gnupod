#!/usr/bin/perl

use strict;
use GNUpod::QTfile;

die "Usage: $0 m4a-file\n" unless @ARGV;

foreach(@ARGV) {
  my $fref = GNUpod::QTfile::parsefile($_);
  
  print "\nFile '$_'\n";
  
  if(ref($fref) eq "HASH") {
   foreach(sort keys(%$fref)) {
    printf ("  %-12s :  %s\n",$_,$fref->{$_});
   }
  }
  else {
   print "  [!!] Not an M4A File\n";
  }
}
