#!/usr/bin/perl

use strict;
use GNUpod::iTunesDB;
use GNUpod::XMLhelper;

print "tunes2pod.pl Version 0.9-rc0 (C) 2002-2003 Adrian Ulrich\n";
print "--------------------------------------------------------\n";
print "This program may be copied only under the terms of the\n";
print "GNU General Public License v2 or later.\n";
print "--------------------------------------------------------\n\n";


startup();

sub startup { 
GNUpod::iTunesDB::open_itunesdb($ARGV[0]);

my($pos, $pdi) = GNUpod::iTunesDB::get_starts();

my $href = undef;
my @xar  = ();
my %hout = ();
 while(1) {
  ($pos,$href) = GNUpod::iTunesDB::get_mhits($pos); #get_nod_a returns wher it's guessing the next MHIT, if it fails, it returns '-1'
  last if $pos == -1;
  push(@xar, $href);
 }


#<files> part built
$hout{gnuPod}{files}{file} = \@xar;

print STDOUT "> Found ".int(@xar)." files\n";

 while(1) {
  ($pdi, $href) = GNUpod::iTunesDB::get_pl($pdi);
  last if $pdi == -1;
  next if ${$href}{type}; #Don't list the MPL

  my @xr = ();
  foreach(@{${$href}{content}}) {
   my %ch = ();
   $ch{id} = $_;
   push(@xr, \%ch);
  }
  
  my %plh = ();
  $plh{name} = ${$href}{name};
  $plh{add}  = \@xr;
  #Add new playlist to XML hash
  push(@{$hout{gnuPod}{playlist}},\%plh);  
print STDOUT ">> Playlist '$plh{name}' with ".int(@xr)." songs\n";
 }

#Print the new GNUtunesDB to STDERR (debug)
print STDERR  XML::Simple::XMLout(\%hout,keeproot=>1);
print STDOUT "\n Done\n";
}












