

# gnupod-utils: utilities for GnuPod tunes database
# Copyright (C) 2002  Eric C. Cooper <ecc@cmu.edu>
# Released under the GNU General Public License
# Some changes made by Adrian Ulrich

use strict;
use iPod;
use Getopt::Long;

sub usage() {
    die <<END_USAGE
Usage: $0 [ablsth] [-m directory]
List GnuPod tunes database.

  -a --artist            :  list artist
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



$opt{m} = $ENV{IPOD_MOUNTPOINT} if !$opt{m}; #defaulting

GetOptions ('help|h' => \$opt{h}, 'mount|m=s' => \$opt{m},
            'artist|a'      => \$opt{a},
	    'by-artist|b'   => \$opt{b},
	    'list-albums|l' => \$opt{l},
	    'songs|s'       => \$opt{s},
	    'titles|t'      => \$opt{t},
	    'genres|g'      => \$opt{g},	    
	    'mount|m=s'     => \$opt{m});

$opt{b} = 1 unless keys %opt;  # default: list albums by artist

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
