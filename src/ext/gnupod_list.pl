

# gnupod-utils: utilities for GnuPod tunes database
# Copyright (C) 2002  Eric C. Cooper <ecc@cmu.edu>
# Released under the GNU General Public License
# Some changes made by Adrian Ulrich

use strict;
use iPod;
use Getopt::Std;
use Getopt::Mixed qw(nextOption);

sub usage() {
    die <<END_USAGE
Usage: $0 [ablsth] [-m directory]
List GnuPod tunes database.

  -a --album             :  list artists
  -b --by-artist         :  list albums by artist
  -l --list-albums       :  list albums
  -s --songs             :  list songs
  -t --titles            :  list titles
  -g --genres            :  list genres
  -m --mount=directory   :  iPod mountpoint, default is \$IPOD_MOUNTPOINT
  -h --help             :  print this summary and exit
END_USAGE
}

my %opt = ();


Getopt::Mixed::init("help h>help titles t>titles songs s>songs \
list-albums l>list-albums by-artist b>by-artist album a>album mount=s m>mount genres g>genres");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opt{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();



$opt{b} = 1 unless keys %opt;  # default: list albums by artist
$opt{m} = $ENV{IPOD_MOUNTPOINT} if !$opt{m}; #defaulting
usage() if !$opt{m} || $opt{h};

iPod::read_xml("$opt{m}/iPod_Control/.gnupod/GNUtunesDB");

my %albums = ();
my %artists = ();
my %titles = ();
my %genres = ();
# order albums alphabetically by artist, then album name

sub album_list() {
    return sort { ($a->{artist} cmp $b->{artist} ||
		   $a->{album} cmp $b->{album}) } values %albums;
}

sub print_album($) {
    my ($s) = @_;
    printf "%s / %s\n", $s->{artist}, $s->{album};
}

if ($opt{a}) {
    for my $s (@{$iPod::songs}) { $artists{$s->{artist}} = $s; }
    print $_, "\n" for sort keys %artists;
} elsif ($opt{b}) {
    for my $s (@{$iPod::songs}) { $albums{$s->{album}} = $s; }
    print_album($_) for album_list();
} elsif ($opt{l}) {
    for my $s (@{$iPod::songs}) { $albums{$s->{album}} = $s; }
    print $_, "\n" for sort keys %albums;
} elsif ($opt{t}) {
    for my $s (@{$iPod::songs}) { $titles{$s->{title}} = $s; }
    print $_, "\n" for sort keys %titles;
} elsif ($opt{s}) {
    iPod::print_song($_) for @$iPod::songs;
} elsif ($opt{g}) {
    for my $s (@{$iPod::songs}) { $genres{$s->{genre}} = $s; }
    print $_, "\n" for sort keys %genres;
} else {
    die "$0: this shouldn't happen\n";
}
