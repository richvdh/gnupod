# gnupod-utils: utilities for GnuPod tunes database
# Copyright (C) 2002  Eric C. Cooper <ecc@cmu.edu>
# Released under the GNU General Public License

package iPod;

use strict;
use XML::Simple;
use Unicode::String qw(utf8);

our $xml;
our $songs;
our $playlists;

# The expat XML parser produces UTF-8 strings internally,
# no matter what encoding is specified.
# The following functions convert them (back) to Latin-1.

Unicode::String->stringify_as("latin1");

sub make_songs_latin1() {
    for my $s (@$songs) {
	for (keys %$s) {
	    $s->{$_} = utf8($s->{$_})->as_string;
	}
    }
}

sub make_playlists_latin1() {
    for my $p (@$playlists) {
	$p->{name} = utf8($p->{name})->as_string;
	for my $a (@{$p->{add}}) {
	    for (keys %$a) {
		$a->{$_} = utf8($a->{$_})->as_string;
	    }
	}
    }
}

sub read_xml($) {
    my ($file) = @_;
    $xml = XMLin($file, keeproot => 1, keyattr => [], forcearray => 1);
    my $gnupod = $xml->{gnuPod} ||
	die "$0: $file is not in GnuPod XML format\n";
    $songs = $gnupod->[0]->{files}->[0]->{file};
    make_songs_latin1();
    $playlists = $gnupod->[0]->{playlist};
    make_playlists_latin1();
}

# print the (possibly modified) XML on stdout

sub write_xml() {
    XMLout($xml, xmldecl => '<?xml version="1.0" encoding="ISO-8859-1"?>',
	   keeproot => 1, keyattr => [], outputfile => \*STDOUT);
}

# remove extra whitespace

sub canonical($) {
    my ($s) = @_;
    $s =~ s/\s+/ /g;
    $s =~ s/^ ?(.*) ?$/$1/;
    return $s;
}

# match(song, tag, value)
# test whether song's tag attribute matches the given value

sub match($$$) {
    my ($song, $tag, $value) = @_;
    if ($tag eq "id") {
	return $song->{id} == $value;  # numerical equality
    } else {
	my $pattern = canonical($value);
	$pattern = qr/\Q$pattern\E/i;
	return canonical($song->{$tag}) =~ $pattern;
    }
}

sub print_song($) {
    my ($a) = @_;
    printf("%4d:  %s / %s / %s\n",
	   $a->{id}, $a->{artist}, $a->{album}, $a->{title});
}

# print a playlist entry

sub print_entry($$) {
    my ($fh, $entry) = @_;
    my $first = 1;
    for my $tag (keys %$entry) {
	my $val = $entry->{$tag};
	next unless defined $val;
	printf $fh "%s%s=\"%s\"", ($first ? "" : " "), $tag, $val;
	$first = 0;
    }
}

1;

