

# gnupod-utils: utilities for GnuPod tunes database
# Copyright (C) 2002  Eric C. Cooper <ecc@cmu.edu>
# Released under the GNU General Public License
# Some changes made by Adrian Ulrich
use strict;
use iPod;
use Getopt::Long;

sub usage() {
    die <<END_USAGE
Usage: $0 OPTIONS
Search GnuPod tunes database.

  -a --artist=ARTIST    :  print songs by ARTIST
  -l --album=ALBUM      :  print songs from ALBUM
  -t --title=TITLE      :  print songs with TITLE
  -i --id=ID            :  print song with ID
  -g --genre=GENRE      :  print songs with GENRE
  -n --numbers          :  print IDs only (useful with gnupod_delete)
  -m --mount=DIRECTORY  :  iPod mountpoint, default is \$IPOD_MOUNTPOINT
  -h  --help            :  print this summary and exit
END_USAGE
}

my %opt = ();
$opt{m} = $ENV{IPOD_MOUNTPOINT}; #defaulting


GetOptions ('help|h' => \$opt{h}, 'numbers|n' => \$opt{n},
            'artist|a=s' => \$opt{a},
	    'album|l=s'  => \$opt{l},
	    'title|t=s'  => \$opt{t},
	    'id|i=s'     => \$opt{i},
	    'genre|g=s'  => \$opt{g},
	    'mount|m=s'  => \$opt{m});


usage() if !$opt{m} || $opt{h};

my %search = (artist => $opt{a},
	      album => $opt{l},
	      title => $opt{t},
	      id => $opt{i},
	      genre => $opt{g}
	      );

my $only_ids = $opt{n};

usage() unless grep(defined, values %search);

iPod::read_xml("$opt{m}/iPod_Control/.gnupod/GNUtunesDB");

unless ($only_ids) {
    printf "[ ";
    iPod::print_entry \*STDOUT, \%search;
    printf " ]\n";
}

SONG: for my $song (@$iPod::songs) {
    for my $tag (keys %search) {
	my $val = $search{$tag};
	next SONG if defined $val && !iPod::match($song, $tag, $val);
    }
    # if we reach here, song passes all the criteria
    if ($only_ids) {
	printf "%d\n", $song->{id};
    } else {
	iPod::print_song($song);
    }
}
