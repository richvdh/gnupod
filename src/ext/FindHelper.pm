package GNUpod::FindHelper;
#  Copyright (C) 2009 Heinrich Langos <henrik-gnupod at prak.org>
#  based on gnupod_search by Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://www.gnu.org/software/gnupod/
#
#    GNUpod is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    GNUpod is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.#
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use warnings;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::ArtworkDB;
use Getopt::Long;

use Date::Format;

use Text::CharWidth;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

use constant MACTIME => GNUpod::FooBar::MACTIME;


=pod

=head1 NAME

GNUpod::FindHelper - Utility module for searching the data base.

=head1 DESCRIPTION

=over 4

=cut

use vars qw(%FILEATTRDEF %FILEATTRDEF_SHORT %FILEATTRDEF_COMPUTE);

############ FILE ATTRIBUTE INFO ##########################

=item %FILEATTRDEF_SHORT

DOCUMENT ME!

=cut

%FILEATTRDEF_SHORT = (
#                            t = title    a = artist   r = rating      p = iPod Path
#                            l = album    g = genre    c = playcount   i = id
#                            u = UnixPath n = Songnum  G = podcastguid R = podcastrss
#                            d = dbid
't' => 'title',    'a' => 'artist',   'r' => 'rating',      'p' => 'path',
'l' => 'album',    'g' => 'genre',    'c' => 'playcount',   'i' => 'id',
'u' => 'unixpath', 'n' => 'songnum',  'G' => 'podcastguid', 'R' => 'podcastrss',
'd' => 'dbid_1',
);

=item %FILEATTRDEF_COMPUTE

This hash contains functions to convert/compute attribute values to
human readable forms. E.g. it contains conversions from MACTIME based
dates to something human readable.

=cut

%FILEATTRDEF_COMPUTE = (
	'unixpath' => sub {
			my ($song) = @_;
			return GNUpod::XMLhelper::realpath('',$song->{path});
		},
	'changetime' => sub {
			my ($song) = @_;
			return undef unless defined($song->{changetime});
			return time2str( "%Y-%m-%d %T" , $song->{changetime} - 2082844800);
		},
	'addtime' => sub {
			my ($song) = @_;
			return undef unless defined($song->{addtime});
			return time2str( "%Y-%m-%d %T" , $song->{addtime} - 2082844800);
		},
	'releasedate' => sub {
			my ($song) = @_;
			return undef unless defined($song->{releasedate});
			return time2str( "%Y-%m-%d %T" , $song->{releasedate} - 2082844800);
		},
	'lastplay' => sub {
			my ($song) = @_;
			return undef unless defined($song->{lastplay});
			return time2str( "%Y-%m-%d %T" , $song->{lastplay} - 2082844800);
		},
	'lastskip' => sub {
			my ($song) = @_;
			return undef unless defined($song->{lastskip});
			return time2str( "%Y-%m-%d %T" , $song->{lastskip} - 2082844800);
		},
	'soundcheck' => sub {
			my ($song) = @_;
			return undef unless defined($song->{soundcheck});
			return undef if ($song->{soundcheck} eq "");
			return sprintf("%+.2f",log($song->{soundcheck}/1000)/log(10)/-0.1) ." dB";
		},
	'volume' => sub {
			my ($song) = @_;
			return undef unless defined($song->{volume});
			return "" if ($song->{volume} == 0);
			return "-100% (silence)" if ($song->{volume} == -100);
			return sprintf("%+d%% (%+.2fdB)",$song->{volume},20*log($song->{volume}/100.0 + 1.0)/log(10));
		},
);

=item %FILEATTRDEF

DOCUMENT ME!

=cut

%FILEATTRDEF= (
	'compilation' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => '1 if this file is part of a compilation, 0 else.',
		'header' => 'CMPL',
		'width' => 1,
		},
	'rating' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'rating 0 to 100, stars * 20',
		'header' => 'RTNG',
		'width' => 3,
		},
	'changetime' => {
		'format' => 'numeric',
		'content' => 'mactime',
		'help' => 'last modified time of the track',
		'header' => 'CHANGED',
		'width' => 19,
		},
	'filesize' => {
		'format' => 'numeric',
		'content' => 'bytes',
		'help' => 'file size in bytes',
		'header' => 'FILESIZE',
		'width' => 8,
		},
	'time' => {
		'format' => 'numeric',
		'content' => 'milliseconds',
		'help' => 'length of the track, in milliseconds',
		'header' => 'LENGTH(MS)',
		'width' => 6,
		},
	'songnum' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'track number of this song',
		'header' => 'SNUM',
		'width' => 2,
		},
	'songs' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'total number of tracks',
		'header' => 'SONGS',
		'width' => 2,
		},
	'year' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'year of the track',
		'header' => 'YEAR',
		'width' => 4,
		},
	'bitrate' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'bit rate in kbit/s',
		'header' => 'KBPS',
		'width' => 3,
		},
	'srate' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'sample rate',
		'header' => 'SRATE',
		'width' => 5,
		},
	'starttime' => {
		'format' => 'numeric',
		'content' => 'milliseconds',
		'help' => 'time, in milliseconds, that the song will start playing at',
		'header' => 'STARTTIME',
		'width' => 6,
		},
	'stoptime' => {
		'format' => 'numeric',
		'content' => 'milliseconds',
		'help' => 'time, in milliseconds, that the song will stop playing at',
		'header' => 'STOPTIME',
		'width' => 6,
		},
	'soundcheck' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'Soundcheck value for volume normalization',
		'header' => 'SOUNDCHECK',
		'width' => 8,
		},
	'playcount' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'play count of the song',
		'header' => 'PLAYCOUNT',
		'width' => 8,
		},
	'lastplay' => {
		'format' => 'numeric',
		'content' => 'mactime',
		'help' => 'time the song was last played',
		'header' => 'LASTPLAY',
		'width' => 19,
		},
	'cdnum' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'disc number',
		'header' => 'CD#',
		'width' => 2,
		},
	'cds' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'total number of disks',
		'header' => 'CDS',
		'width' => 2,
		},
	'addtime' => {
		'format' => 'numeric',
		'content' => 'mactime',
		'help' => 'time the song was added',
		'header' => 'ADDTIME',
		'width' => 19,
		},
	'bookmark' => {
		'format' => 'numeric',
		'content' => 'milliseconds',
		'help' => 'time in milliseconds that the playback will continue at. used for audio books and podcasts.',
		'header' => 'BOOKMARK',
		'width' => 6,
		},
	'dbid_1' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'iPod database id',
		'header' => 'ID',
		'width' => 4,
		},
	'bpm' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'beats per minute',
		'header' => 'BPM',
		'width' => 4,
		},
	'artworkcnt' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'number of album artwork items',
		'header' => 'ARTWORKCNT',
		'width' => 2,
		},
	'artworksize' => {
		'format' => 'numeric',
		'content' => 'bytes',
		'help' => 'total size of artwork attached to this file',
		'header' => 'ARTWORKSIZE',
		'width' => 6,
		},
	'releasedate' => {
		'format' => 'numeric',
		'content' => 'mactime',
		'help' => 'time the song was released. podcasts are usually sorted by this',
		'header' => 'RELEASEDATE',
		'width' => 19,
		},
	'skipcount' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'skip count of the song',
		'header' => 'SKIPCOUNT',
		'width' => 8,
		},
	'lastskip' => {
		'format' => 'numeric',
		'content' => 'mactime',
		'help' => 'time the song was last skipped',
		'header' => 'LASTSKIP',
		'width' => 19,
		},
	'has_artwork' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'has arwork',
		'header' => 'HAS_ARTWORK',
		'width' => 1,
		},
	'shuffleskip' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'skip when shuffle play is active',
		'header' => 'SHUFFLESKIP',
		'width' => 1,
		},
	'bookmarkable' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'remember playback position as bookmark',
		'header' => 'BOOKMARKABLE',
		'width' => 1,
		},
	'podcast' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'is a podcast',
		'header' => 'PODCAST',
		'width' => 1,
		},
	'lyrics_flag' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'set to 1 if lyrics are stored in the MP3 tags ("USLT"), 0 otherwise.',
		'header' => 'LYRICS_FLAG',
		'width' => 1,
		},
	'movie_flag' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'set to 1 for movies, 0 for audio files',
		'header' => 'MOVIE_FLAG',
		'width' => 1,
		},
	'played_flag' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'With podcasts a value of "0" marks this track with a bullet as "not played" on the iPod, irrespective of the value of play count.',
		'header' => 'PLAYED_FLAG',
		'width' => 1,
		},
	'pregap' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'Number of samples of silence before the songs starts (for gapless playback).',
		'header' => 'PREGAP',
		'width' => 6,
		},
	'samplecount' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'Number of samples in the song (for gapless playback).',
		'header' => 'SAMPLES',
		'width' => 6,
		},
	'postgap' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'Number of samples of silence at the end of the song (for gapless playback).',
		'header' => 'POSTGAP',
		'width' => 6,
		},
	'mediatype' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => '00-Audio/Video  01-Audio  02-Video  04-Podcast  06-Video Podcast  08-Audiobook  20-Music Video  40-TV Show (shows up ONLY in TV Shows)  60-TV Show (shows up in the Music lists as well)',
		'header' => 'MEDIATYPE',
		'width' => 2,
		},
	'seasonnum' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'the season number of the track, for TV shows only',
		'header' => 'SEASON#',
		'width' => 2,
		},
	'episodenum' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'the episode number of the track, for TV shows only - although not displayed on the iPod, the episodes are sorted by episode number',
		'header' => 'EPISODE#',
		'width' => 2,
		},
	'gaplessdata' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'The size in bytes from first Synch Frame until the 8th before the last frame.',
		'header' => '',
		'width' => 1,
		},
	'has_gapless' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'if 1, this track has gapless playback data',
		'header' => 'HAS_GAPLESS',
		'width' => 1,
		},
	'nocrossfade' => {
		'format' => 'numeric',
		'content' => 'boolean',
		'help' => 'if 1, this track does not use crossfading in iTunes',
		'header' => 'NOCROSSFADE',
		'width' => 1,
		},

#########################################
# tags
#############

	'album' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Album Name',
		'header' => 'ALBUM',
		'width' => 28,
		},

	'artist' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Main Artists Name',
		'header' => 'ARTIST',
		'width' => 20,
		},

	'comment' => {
		'format' => 'string',
		'content' => 'text',
		'help' => 'Comment',
		'header' => 'COMMENT',
		'width' => 30,
		},

	'composer' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Composer Name',
		'header' => 'COMPOSER',
		'width' => 20,
		},

	'genre' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Genre',
		'header' => 'GENRE',
		'width' => 16,
		},

	'path' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'iPod path',
		'header' => 'IPODPATH',
		'width' => 40,
		},

	'unixpath' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Unix path',
		'header' => 'UNIXPATH',
		'width' => 40,
		},

	'podcastguid' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Podcast GUID',
		'header' => 'GUID',
		'width' => 32,
		},

	'podcastrss' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Podcast RSS',
		'header' => 'RSS',
		'width' => 32,
		},

	'fdesc' => {
		'format' => 'string',
		'content' => 'line',
		'help' => 'Format decription',
		'header' => 'FDESC',
		'width' => 15,
		},

	'desc' => {
		'format' => 'string',
		'content' => 'text',
		'help' => 'Item Description',
		'header' => 'DESCRIPTION',
		'width' => 40,
		},

	'title' => {
		'format' => 'line',
		'content' => 'string',
		'help' => 'Track Title',
		'header' => 'TITLE',
		'width' => 32,
		},

	'volume' => {
		'format' => 'line',
		'content' => 'string',
		'help' => 'Volume in +/- percent',
		'header' => 'VOLUME',
		'width' => 5,
		},

	'id' => {
		'format' => 'numeric',
		'content' => 'int',
		'help' => 'Item ID within GNUpod',
		'header' => 'ID',
		'width' => 6,
		},

);



=item @findoptions

List of options to include in your GetOptions() call.

Example:
  GetOptions(\%opts, "version", "help|h", "mount|m=s",
     @GNUpod::FindHelper::findoptions
  );

=cut


our @findoptions = (
"filter|f=s@",
"view|v=s@",
"sort|s=s@",
"once|or|o",
"noheader",
"rawprint",
"limit|l=s"
);


=item $defaultviewlist

String containing the default viewlist. The special attribute "default" can be used to
refer to it in the --view argument.

Example:
  --view "filesize,default"

=cut

our $defaultviewlist = 'id,artist,album,title';


=item $findhelp

String to include in your help text if you use the FindHelper module.

=cut

our $findhelp = '   -f, --filter FILTERDEF  only show songss that match FILTERDEF
   -s, --sort SORTDEF      order output according to SORTDEF
   -v, --view VIEWDEF      only show song attributes listed in VIEWDEF
   -o, --or, --once        make any filter match (think OR vs. AND)
   -l, --limit=N           only output N first tracks (-N: all but N first)
       --noheader          don\'t print headers for result list
       --rawprint          output of raw values instead of human readable

FILTERDEF ::= <attribute>["<"|">"|"="|"<="|">="|"=="|"!="|"~"|"~="|"=~"]<value>
  The operators "<", ">", "<=", ">=", "==", and "!=" work as you might expect.
  The operators "~", "~=", and "=~" symbolize regex match (no need for // though).
  The operator "=" checks equality on numeric fields and does regex match on strings.
  TODO: document value for boolean and time fields

VIEWDEF ::= <attribute>[,<attribute>]...
  A comma separated list of fields that you want to see in the output.
  Example: "album,songnum,artist,title"
  Default: "'.$defaultviewlist.'"

SORTDEF ::= ["+"|"-"]<attribute>,[["+"|"-"]<attribute>] ...
  Is a comma separated list of fields to order the output by.
  A "-" (minus) reverses the sort order.
  Example "-year,+artist,+album,+songnum"
  Default "+addtime"

Note: * String arguments (title/artist/album/etc) have to be UTF8 encoded!
';

=item fullattributes ()

Print a list of all known attributes, their shortcut and their
description and calls exit.

=cut

sub fullattributes {
	my %long2short=();
	foreach my $key (keys (%FILEATTRDEF_SHORT)) {
		$long2short{$FILEATTRDEF_SHORT{$key}} = $key;
	}
#	print $fullversionstring."\n\n";
	print " Short | Attribute name | Description\n";
	print "=======|================|=========================\n";
	foreach my $key (sort ( keys (%FILEATTRDEF))) {
		printf "     %s | %-14s | %s\n", ($long2short{$key} or " "), $key, $GNUpod::FindHelper::FILEATTRDEF{$key}{help};
	}
	exit;
}

=item resolve_attribute ( $input )

Examines $input and returns the attribute name that was ment.


If $input equals a known attribute than $input is returned.

If $input is a single character, a translation table will be consulted
that should translate the same attributes that gnupod_search.pl understood.

If $input is a unique prefix of an existing attribute, that attribute's name
is returned.

If $input can't be resolved to a single attribute then undef is returned.

Example

  resolve_attribute("played") returns "played_flag"

=cut

sub resolve_attribute {
	my ($input) = @_;

	#direct hit
	return $input if defined($FILEATTRDEF{$input});

	#short cuts
	if (length($input) == 1) {
		my $out = undef;
		if (defined($out = $FILEATTRDEF_SHORT{$input})) {
			return $out;
		}
	}

	#prefix match
	my @candidates=();
	for my $attr (sort(keys %FILEATTRDEF)) {
		push @candidates,$attr if (index($attr, $input) == 0) ;
	}
	if (@candidates == 1) {
		return $candidates[0];
	}

	#default
	return undef;
}

=item process_options ( %options )

Examines the "filter" "sort" and "view" options and returns a hash ref
containing the filterlist sortlist and viewlist and the other options
that processes_options will set.
If an error is encountered either undef or a string containing an error
description is returned.

In particular it prepares three lists that other FindHelper functions
will need to work properly:

  @filterlist
  @sortlist
  @viewlist

Those are also exported by this module. So it's up to you if you want to
use them directly from the returned references, via the exported array
variables or not at all. For most purposes you probably don't need to.

Examples of filter options:
  --filter artist="Pink" would find "Pink", "Pink Floyd" and "spinki",
  --filter artist=="Pink" would find just "Pink" and not "pink" or "Pink Floyd",
  --filter 'year<2005' would find songs made before 2005,
  --filter 'addtime<2008-07-15' would find songs added before July 15th,
  --filter 'addtime>yesterday' would find songs added in the last 24h,
  --filter 'releasedate<last week' will find podcast entries that are older than a week.

Please note that "<" and ">" most probably need to be escaped on your shell
prompt. So it will be
    --filter 'addtime>yesterday'
  rather than
    --filter addtime>yesterday


Example:

    my $foo = GNUpod::FindHelper::process_options(\%opts);
    if (!defined $foo) { die("Trouble parsing find options.") };
    if (ref(\$foo) eq "SCALAR") { die($foo)};

=cut

our @filterlist = ();
our @sortlist   = ();
our @viewlist   = ();
our $once       = 0;
our $rawprint   = 0;
our $noheader   = 0;
our $limit      = undef;

sub process_options {
	my %options;
	%options = %{$_[0]};

	#establish defaults in case the option was not given at all

	$options{filter} ||= []; #Default search
	$options{sort}   ||= ['+addtime']; #Default sort
	$options{view}   ||= [$defaultviewlist]; #Default view


	for my $filteropt (@{$options{filter}}) {
		for my $filterkey (split(/\s*,\s*/, $filteropt)) {
			#print "filterkey: $filterkey\n";
			if ($filterkey =~ /^([0-9a-z_]+)([!=<>~]+)(.*)$/) {

				my $attr;
				if (!defined($attr = resolve_attribute($1))) {
					return ("Unknown filterkey \"".$1."\". ".help_find_attribute($1));
				}

				my $value;
				if ($FILEATTRDEF{$attr}{format} eq "numeric") {
					if ($FILEATTRDEF{$attr}{content} eq "mactime") {   #handle content MACTIME
						if (eval "require Date::Manip") {
							# use Date::Manip if it is available
							require Date::Manip;
							import Date::Manip;
							$value = UnixDate(ParseDate($3),"%s");
						} else {
							# fall back to Date::Parse
							$value = Date::Parse::str2time($3);
						}
						if (defined($value)) {
							#print "Time value \"$3\" evaluates to $value unix epoch time (".($value+MACTIME)." mactime) which is ".time2str("%C",$value)."\n";
							$value += MACTIME;
						} else {
							return ("Sorry, your time/date definition \"$3\" was not understood.");
						}
					} else { #not "mactime"
						$value = $3; # DO NOT USE : $value = int($3); or you will screw up regex matches on numeric fields
					}
				} else { #not numeric
					$value = $3; # not much we could check for
				}

				my $filterdef = { 'attr' => $attr, 'operator' => $2, 'value' => $value };
				push @filterlist,  $filterdef;
			} else {
				return ("Invalid filter definition: ". $filterkey);
			}
		}
	}
	#print "Filterlist (".($options{once}?"or":"and")."-connected): ".Dumper(\@filterlist);

	########################
	# prepare sortlist
	for my $sortopt (@{$options{sort}}) {
		for my $sortkey (split(/\s*,\s*/, $sortopt )) {
			if ( (substr($sortkey,0,1) ne "+") &&
				(substr($sortkey,0,1) ne "-") ) {
				$sortkey = "+".$sortkey;
			}
			my $attr;
			if (!defined($attr = resolve_attribute (substr($sortkey,1)))) {
				return ("Unknown sortkey \"".substr($sortkey,1)."\". ".help_find_attribute(substr($sortkey,1)));
			}
			push @sortlist, substr($sortkey,0,1).$attr;
		}
	}
	#print "Sortlist: ".Dumper(\@sortlist);

	########################
	# prepare viewlist
	for my $viewopt (@{$options{view}}) {
		for my $viewkey (split(/\s*,\s*/,   $viewopt)) {
			my $attr;
			if ($viewkey eq "default") {
				for my $dk (split(/\s*,\s*/, $defaultviewlist)) {
					push @viewlist, $dk;
				}
			} elsif (!defined($attr = resolve_attribute($viewkey))) {
				return ("Unknown viewkey \"".$viewkey."\". ".help_find_attribute($viewkey));
			} else {
				push @viewlist, $attr;
			}
		}
	}
	#print "Viewlist: ".Dumper(\@viewlist);
	$rawprint = $options{rawprint};
	$noheader = $options{noheader};
	$once = $options{once};
	$limit = $options{limit};
	return { filterlist => \@filterlist,
			sortlist => \@sortlist,
			viewlist => \@viewlist,
			once => $once,
			rawprint => $rawprint,
			noheader => $noheader,
			limit => $limit,
			};
}

sub help_find_attribute {
	my ($input) = @_;
	my %candidates =();
	my $output="";
	# substring of attribute name
	for my $attr (sort(keys %FILEATTRDEF)) {
		$candidates{$attr} = 1 if (index($attr, $input) != -1) ;
	}
	# substring of attribute help
	for my $attr (sort(keys %FILEATTRDEF)) {
		$candidates{$attr} += 2 if (index(lc($FILEATTRDEF{$attr}{help}), $input) != -1) ;
	}

	if (%candidates) {
		$output = "Did you mean: \n";
		for my $key (sort( keys( %candidates))) {
			$output .= sprintf "\t%-15s %s\n", $key.":", $FILEATTRDEF{$key}{help};
		}
	}
	return $output;
}

####################################################
# sorter

=item comparesong($$)

Sort routine that uses @GNUpod::FindHelper::sortlist to compare the songs.
If data in numeric fields (see %FILEATTRDEF) is
found to be undefined/non-numeric, it is replaced by 0 for the comparison.

If data in non-numeric fields is found to be undefined, it is replaced
by "" (empty string) for comparison.

Example:

  @resultlist = sort GNUpod::FindHelper::comparesongs @resultlist;


=cut

sub comparesongs ($$) {
	my $result=0;
	for my $sortkey (@sortlist) {	 # go through all sortkeys
		# take the data that needs to be comapred into $x and $y
		my ($x,$y) = ($_[0]->{substr($sortkey,1)}, $_[1]->{substr($sortkey,1)} );

		# if sort order is reversed simply switch x any y
		if (substr ($sortkey,0,1) eq "-") {
			($x, $y)=($y, $x);
		}

		# now compare x and y
		if ($FILEATTRDEF{substr($sortkey,1)}{format} eq "numeric") {
			$x = (defined($x) && ($x =~ /^-?\d+(\.\d+)?$/))?$x:0;
			$y = (defined($y) && ($y =~ /^-?\d+(\.\d+)?$/))?$y:0;
			$result = $x <=> $y;
		} else {
			$x = "" if !defined($x);
			$y = "" if !defined($y);
			$result = $x cmp $y;
		}

		# if they are equal we will go on to the next sortkey. otherwise we return the result
		if ($result != 0) { return $result; }
	}

	# after comparing according to all sortkeys the songs are still equal.
	return 0;
}


=item croplist ({ results => \@resultlist[, limit => $limit]})

Crop a list to contain the right amount of elements.

The limit can be passed as parameter. Otherwise it will be taken from $FindHelper::limit

If passed a positive integer in $limit, only the first $limit elements of @list are returned.

If passed a negative integer in $limit, ALL BUT the first $limit elements of @list are returned.

If a non-numeric variable is passed in $limit, the whole @list is returned.

=cut

sub croplist {
	my ($options) = @_;

	my @resultlist = ();
	my $reslimit = $limit;

	@resultlist = @{$options->{results}} if defined($options->{results});
	$reslimit = $options->{limit} if defined($options->{limit});

	if (defined($reslimit) and ($reslimit =~ /^-?\d+/)) {
		if ($reslimit >= 0) {
			splice @resultlist, $reslimit if ($#resultlist >= $reslimit);
		} else {
			if (-1 * $reslimit > $#resultlist) {
				@resultlist = ();
			} else {
				my @limitedlist = splice @resultlist, -1 * $reslimit;
				@resultlist = @limitedlist;
			}
		}
	}
	return @resultlist;
}


###################################################
# matcher
sub matcher {
	my ($filter, $testdata) = @_;
	#print "filter:\n".Dumper($filter);
	#print "data:\n".Dumper($testdata);
	if (! defined($testdata)) {return 0;}
	my $value;
	my $data;
	if ($FILEATTRDEF{$filter->{attr}}{format} eq "numeric") {

		$_ = $filter->{operator};

		if (($_ eq "~") or ($_ eq "~=") or ($_ eq "=~")) { return ($data =~ /$value/i); }

		# makes sure the $data is numeric it should be since we get it from the database
		$data = ($testdata =~ /^-?\d+(\.\d+)?$/)?$testdata:0;
		# make sure Filter->Value is indeed numeric now that we do numeric
		$value = ($filter->{value} =~ /^-?\d+(\.\d+)?$/)?$filter->{value}:0;

		if ($_ eq ">")	{ return ($data > $value); }
		if ($_ eq "<")	{ return ($data < $value); }
		if ($_ eq ">=") { return ($data >= $value); }
		if ($_ eq "<=") { return ($data <= $value); }
		if (($_ eq "=") or ($_ eq "==")) { return ($data == $value); }
		if ($_ eq "!=") { return ($data != $value); }
		die ("No handler for your operator \"".$_."\" with numeric data found. Could be a bug.");

	} else { # non numeric attributes
		$data = $testdata;
		$value = $filter->{value};

		$_ = $filter->{operator};
		if ($_ eq ">")	{ return ($data gt $value); }
		if ($_ eq "<")	{ return ($data lt $value); }
		if ($_ eq ">=") { return ($data ge $value); }
		if ($_ eq "<=") { return ($data le $value); }
		if ($_ eq "==") { return ($data eq $value); }
		if ($_ eq "!=") { return ($data ne $value); }
		if (($_ eq "~") or ($_ eq "=") or ($_ eq "~=") or ($_ eq "=~"))	{ return ($data =~ /$value/i); }
		die ("No handler for your operator \"".$_."\" with non-numeric data found. Could be a bug.");
	}
}

=item filematches ($el, [{filterlist => \@filterlist, once => $once}])

Returns 1 if the hasref $el->{file} matches the @FindHelper::filterlist and 0 if it doesn't match.

If $once evaluates to the boolean value True than a single match on any
condition specified in the @filterlist is enough. Otherwise
all conditions have to match.

Both, @filterlist and $once can be passed as parameter in a hashref, otherwise
the values set by process_options will be used.

NOTE: If an attribute is not present (like releasedate in non-podcast items)
than a match on those elements will always fail.

=cut

sub filematches {
	my ($el,$options) =  @_;

	# get current module values
	my $matchonce = $once;
	my @filters = @filterlist;

	# override by parameters
	if (defined($options)) {
		$matchonce = $options->{once} if defined($options->{once});
		@filters = @{$options->{filterlist}} if defined($options->{filterlist});
	}

	# check for matches
	my $matches=1;
	foreach my $filter (@filters) {
		#print "Testing for filter:\n".Dumper($filter);

		if (matcher($filter, $el->{file}->{$filter->{attr}})) {
			#matching
			$matches = 1;
			if ($matchonce) {
				#ok one match is enough.
				last;
			}
		} else {
			#not matching
			$matches = 0;
			if (! $matchonce) {
				# one mismatch is enough
				last;
			}
		}
	}
	return $matches;
}

##############################################################
# computed attributes

=item computeresults ($song, $raw, $field)

Computes the output of $field from $song according to
$FILEATTRDEF_COMPUTE{field}. If $raw is true, the raw
value (if any) wil be returned.

=cut


sub computeresults {
	my ($song, $raw, $fieldname) = @_;
	if ((!$raw) && defined ($FILEATTRDEF_COMPUTE{$fieldname})) {
		#print "Found code for $fieldname \n";
		my $coderef = $FILEATTRDEF_COMPUTE{$fieldname};
		return &$coderef($song);
	} else {
		return $song->{$fieldname};
	}
}


##############################################################
# Printout

=item prettyprint ({ results => \@resultlist[, view => \@viewlist][, noheader => 1][, rawprint => 1]})

Prints the song data passed in resultlist.
All options are passed as one hashref.
The key "results" should point to an array ref with the results.
View can be changed according to the array ref indicated ny the "view" key.
The "noheader" option will skip the output of headers.
The "rawprint" option will skip the computed value conversion/generation.

Example:
  prettyprint ( { results => \@songs, noheader => 1 } );

=cut

##############################################################
# print one field and return the overhang
# gets the viewkey, the data and the current overhang
sub printonefield {
	my ($viewkey, $data, $overhang) = @_;
	$data = "" if !defined($data); #empty string for undefined. could be made configurable if needed.
	my $columns=Text::CharWidth::mbswidth($data)+$overhang;
	if ( $columns > $viewkey->{width} ) {
		print "$data";
		return $columns - $viewkey->{width};
	} else {
		#we could add some alignment (left,cener,right) stuff here
		print "$data"." "x($viewkey->{width} - $columns);
		return 0;
	}
}

sub printheader {
	my @headviewlist = @_;
	my $totalwidth=0;
	my $firstcolumn=1;
	my $overhang=0;
	foreach my $viewkey (@headviewlist) {
		if ($firstcolumn) {$firstcolumn=0;} else { print " | "; $totalwidth+=3; }
		$overhang = printonefield($FILEATTRDEF{$viewkey}, $FILEATTRDEF{$viewkey}{header}, $overhang);
		$totalwidth += $FILEATTRDEF{$viewkey}{width};
	}
	print "\n";
	print "=" x $totalwidth ."\n";
}

sub printoneline {
	my ($song,$raw,@view) = @_;
	my $totalwidth=0;
	my $firstcolumn=1;
	my $overhang=0;
	foreach my $viewkey (@view) {
		if ($firstcolumn) {$firstcolumn=0;} else { print " | "; $totalwidth+=3; }
		$overhang = printonefield($FILEATTRDEF{$viewkey}, computeresults($song,$raw,$viewkey), $overhang);
	}
}


sub prettyprint {
	my ($options) = (@_);
#	print "prettypriting \n".Dumper($options);
	my @view = @viewlist;
	my $raw = $rawprint;
	my $nohead = $noheader;

	@view = @{$options->{view}} if defined($options->{view});
	$raw = $options->{rawprint} if defined($options->{rawprint});
	$nohead = $options->{noheader} if defined($options->{noheader});

	printheader(@view) unless $nohead;

	foreach my $song (@{$options->{results}}) {
		printoneline($song,$raw,@view);
		print "\n";
	}

# $qh{u}{k} = GNUpod::XMLhelper::realpath($opts{mount},$orf->{path}); $qh{u}{w} = 96; $qh{u}{s} = "UNIXPATH";

}

1;

