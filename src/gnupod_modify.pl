###__PERLBIN__###
#  Copyright (C) 2010 Heinrich Langos <henrik-gnupod at prak.org>
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
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use warnings;
use GNUpod::XMLhelper;
use GNUpod::FindHelper;
use GNUpod::ArtworkDB;
use Getopt::Long;

my $programName = "gnupod_modify.pl";

my $fullVersionString = "$programName Version ###__VERSION__### (C) Heinrich Langos";

use vars qw(%opts @keeplist);

my $AWDB;

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

my $getoptres = GetOptions(\%opts, "version", "help|h", "mount|m=s",
	"interactive|i", "force",
	"set=s@",
	@GNUpod::FindHelper::findoptions
);

# take model, mountpoint, automktunes, and bgcolor from gnupod_search preferences
# this should not override options that are already set in opts
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s', automktunes=>'b', bgcolor=>'s'}, "gnupod_search");


usage()   if ($opts{help} || !$getoptres );
version() if $opts{version};
GNUpod::FindHelper::fullattributes() if $opts{'list-attributes'};
if ($opts{'interactive'} && $opts{'force'}) { usage("Can't use --force and --interactive together.") };

my @resultlist=();
my %resultids=(); #only used for second pass to skip searching the resultlist

my $max_non_interactive_modify = 20; #how many files get modified without asking (if not forced)

my $foo = GNUpod::FindHelper::process_options(\%opts);

if (!defined $foo) { usage("Trouble parsing find options.") };
if (ref(\$foo) eq "SCALAR") { usage($foo)};

my $changingArtwork;
my %changingAttributes = ();
for (@{$opts{set}}) {
	if (/^(.+?)=(.*)$/) {
		if (defined(GNUpod::FindHelper::resolve_attribute($1))) {
			# TODO check for readonly flag
			$changingAttributes{$1}=$2;
		} elsif ($1 eq 'artwork') {
			$changingArtwork=$2;
		} else {
			usage("Unknown attribute \"".$1."\". ".GNUpod::FindHelper::help_find_attribute($1));
		}
	} else {
		usage("Trouble parsing set option (\"$_\").");
	}
}

# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

my $firstrun = 1; #first run will look for the songs and playlists to modify. the second run will modify them.
my $modificationconfirmed = 0;

main($connection);

####################################################
# Worker
sub main {

	my($con) = @_;

	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

	#print "resultlist:\n".Dumper(\@resultlist);

	# sort result list according to the user's wishes
	@resultlist = sort GNUpod::FindHelper::comparesongs @resultlist;

	# crop result list according to the user's wishes
	@resultlist = GNUpod::FindHelper::croplist({results => \@resultlist});

	if (@resultlist) {
		#output results
		GNUpod::FindHelper::prettyprint ({ results => \@resultlist }) if @resultlist;

		#ask confirmation
		if ($opts{force}) {
			$modificationconfirmed = 1;
		} elsif ($opts{interactive} or (scalar(@resultlist) > $max_non_interactive_modify)) {
			print "Modify ? (y/n) ";# request confirmation
			my $answer = "n";
			chomp ( $answer = <> );
			$modificationconfirmed = 1 if ($answer eq "y");
		} else {
			$modificationconfirmed = 1;
		}

		#start second run to modify selected files/playlists
		if ($modificationconfirmed) {
			foreach my $res (@resultlist) { $resultids{$res->{id}}=1; }
			$firstrun = 0;
			if (defined($changingArtwork)) {
				$AWDB = GNUpod::ArtworkDB->new(Connection=>$connection, DropUnseen=>1);
				if( $AWDB->PrepareImage(File=>$changingArtwork, Model=>$opts{model}, bgcolor=>$opts{bgcolor}) ) {
					$AWDB->LoadArtworkDb or die "Failed to load artwork database\n";
				} else {
					warn "$0: Could not load $changingAttributes{artwork}, skipping artwork\n";
					undef $changingArtwork;
				}
			}
			GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");
			GNUpod::XMLhelper::writexml($con,{automktunes=>$opts{automktunes}});
			if (defined($changingArtwork)) {
				$AWDB->WriteArtworkDb;
			}
		}
	}
}


#############################################
# Eventhandler for FILE items
sub newfile {
	my($fileTag) =  @_;
	if ($firstrun) {
		if (GNUpod::FindHelper::filematches($fileTag)) {
			push @resultlist, \%{$fileTag->{file}};  #add a reference to @resultlist
		}
	} else {
		if ($resultids{$fileTag->{file}{id}}) {
			# make changes to the file
			for (keys (%changingAttributes)) {
				# set the fileTags attributes to their new values
				$fileTag->{file}{$_} = $changingAttributes{$_};
			}
			if (defined($changingArtwork)) {
				# -> Add/Set artwork
				$fileTag->{file}{has_artwork} = 1;
				$fileTag->{file}{artworkcnt}  = 1;
				$fileTag->{file}{dbid_1}      = $AWDB->InjectImage;
			}
		}
		# add it to XML
		GNUpod::XMLhelper::mkfile($fileTag);

		# -> and keep artwork
		$AWDB->KeepImage($fileTag->{file}{dbid_1});
	}
}

#############################################
# Eventhandler for playlist items
sub newpl {
	my ($el, $name, $plt) = @_;
	if ($firstrun) {
		return;
	} else {
		GNUpod::XMLhelper::mkfile($el,{$plt."name"=>$name});
	}
}

###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
$rtxt = "" if (! defined($rtxt));
die << "EOF";
$fullVersionString
$rtxt
Usage: $programName ...

   -h, --help              display this help and exit
       --list-attributes   display all attributes for filter/view/sort
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --interactive       always ask
       --force             never ask
   -s, --set=attr=value    set attribute to value
$GNUpod::FindHelper::findhelp
Report bugs to <bug-gnupod\@nongnu.org>
EOF
}


sub version {
die << "EOF";
$fullVersionString

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

=head1 NAME

gnupod_modify.pl  - modify songs on your iPod

=head1 SYNOPSIS

gnupod_modify.pl [OPTION]

=head1 DESCRIPTION

C<gnupod_modify.pl> searches the F<GNUtunesDB.xml> file for matches to its
arguments and modifies those files' attributes according to your command.

=head1 OPTIONS

###___PODINSERT man/gnupod_find-options.pod___###

=head2 Interaction Options

By default gnupod_modify.pl will only make changes to 20 songs without asking.
If there are more than 20 matches then gnupod_modify.pl will present
the matches and ask the user to confirm the modification.

=over 4

=item -i, --interactive

Always ask the user before making changes to the matching songs. No matter how
few matches there are.

=item --force

Never ask the user before making changes. No matter how many songs will be
modified.

=back

=head2 Modification options

=over 4

=item --set <attribute>=<value>

Sets the attribute for all maching songs to the given value.
This option may be repeated several times in order to set more
than one attribute at a time.

Example
  --set artist="Pink Floyd" --set album="The Wall"

=back

###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Written by Eric C. Cooper <ecc at cmu dot edu> - Contributed to the 'old' GNUpod (< 0.9)

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

Heinrich Langos <henrik-gnupod at prak dot org> - Some patches

###___PODINSERT man/footer.pod___###

