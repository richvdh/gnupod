#!/usr/bin/perl

use strict;
use GNUpod::iTunesDB;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;

use vars qw(%opts);

print "tunes2pod.pl Version 0.9-rc1 (C) 2002-2003 Adrian Ulrich\n";
print "--------------------------------------------------------\n";
print "This program may be copied only under the terms of the\n";
print "GNU General Public License v2 or later.\n";
print "--------------------------------------------------------\n\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "help|h", "xml|x=s", "itunes|i=s", "mount|m=s");


usage() if $opts{help};

#Normal operation
converter();

sub converter {
my($stat, $in, $out) = GNUpod::FooBar::connect(\%opts);
usage("$stat\n") if $stat;

GNUpod::iTunesDB::open_itunesdb($in) or usage("Could not open $in\n");


#Check where the FILES and PLAYLIST part starts..
#..and how many files are in this iTunesDB
my($pos, $pdi,$xpct_songs, $xpc_pl) = GNUpod::iTunesDB::get_starts();

my $href = undef;
my @xar  = ();
my %hout = ();
 for(my $i=0;$i<$xpct_songs;$i++) {
  ($pos,$href) = GNUpod::iTunesDB::get_mhits($pos); #get_nod_a returns wher it's guessing the next MHIT, if it fails, it returns '-1'
  #Seek failed.. this shouldn't happen..  
  if($pos == -1) {
   print STDERR "*** FATAL: Expected to find $xpct_songs files,\n";
   print STDERR "*** but i failed to get nr. $i\n";
   print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
   print STDERR "*** a bug in GNUpod. Please send this\n";
   print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
   exit(1);
  }  
  push(@xar, $href);
 }


#<files> part built
$hout{gnuPod}{files}{file} = \@xar;
my $found_files = int(@xar);
print STDOUT "> Found $found_files files, ok\n";


#Now get each playlist
print STDOUT "> Found ".($xpc_pl-1)." playlists:\n";
for(my $i=0;$i<$xpc_pl;$i++) {
  ($pdi, $href) = GNUpod::iTunesDB::get_pl($pdi);
  if($pdi == -1) {
   print STDERR "*** FATAL: Expected to find $xpc_pl playlists,\n";
   print STDERR "*** but i failed to get nr. $i\n";
   print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
   print STDERR "*** a bug in GNUpod. Please send this\n";
   print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
   exit(1);
  }
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

open(OUT, ">$out") or die "Could not write to $out\n";
 print OUT  XML::Simple::XMLout(\%hout,keeproot=>1,xmldecl=>1);
close(OUT);

print STDOUT "\n Done\n";
}









sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: tunes2pod.pl [-h] [-m directory | -i iTunesDB | -x GNUtunesDB]

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --itunes=iTunesDB  : Specify an alternate iTunesDB
   -x, --xml=file         : GNUtunesDB (XML File)

EOF
}




