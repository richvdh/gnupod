###__PERLBIN__###
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

my $programName = "gnupod_delete.pl";

my $fullversionstring = "$programName Version ###__VERSION__### (C) Heinrich Langos";

use vars qw(%opts @keeplist);

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

my $getoptres = GetOptions(\%opts, "version", "help|h", "mount|m=s",
	"interactive|i", "force",
	"playlist|p=s",
	@GNUpod::FindHelper::findoptions
);

# take model and mountpoint from gnupod_search preferences
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_search");


usage()   if ($opts{help} || !$getoptres );
version() if $opts{version};
GNUpod::FindHelper::fullattributes() if $opts{'list-attributes'};
if ($opts{'interactive'} && $opts{'force'}) { usage("Can't use --force and --interactive together.") };

my %playlist_names=(); # names of the playlists to be deleted
my %playlist_resultids=(); #ids of the songs to be deleted because they are part of a deleted playlist

my @resultlist=();
my %resultids=(); #only used for second pass to skip searching the resultlist

my $max_non_interactive_delete = 20; #how many files get deleted without asking (if not forced)

my $foo = GNUpod::FindHelper::process_options(\%opts);

if (!defined $foo) { usage("Trouble parsing find options.") };
if (ref(\$foo) eq "SCALAR") { usage($foo)};

# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

my $AWDB;

my $firstrun = 1;


my $deletionconfirmed = 0;

main($connection);

####################################################
# Worker
sub main {

	my($con) = @_;

	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

	#print "resultlist:\n".Dumper(\@resultlist);

	if ($opts{playlist}) {

		#consolidate playlist results

	} else {

		# sort results list according to users wishes
		@resultlist = sort GNUpod::FindHelper::comparesongs @resultlist;
		# crop results according to users wishes
		@resultlist = GNUpod::FindHelper::croplist({results => \@resultlist});

	}

	if (@resultlist or %playlist_names) {
		#output results
		GNUpod::FindHelper::prettyprint ({ results => \@resultlist }) if @resultlist;
		if (%playlist_names) {
			print "             PLAYLIST | #ELEMENTS \n";
			print "======================|===========\n";
			foreach my $name (keys(%playlist_names)) {
				printf " %20s | %d\n",$name,$playlist_names{$name};
			}
		}

		#ask confirmation
		if ($opts{force}) {
			$deletionconfirmed = 1;
		} elsif ($opts{interactive} or (scalar(@resultlist) > $max_non_interactive_delete)) {
			print "Delete ? (y/n) ";# request confirmation
			my $answer = "n";
			chomp ( $answer = <> );
			$deletionconfirmed = 1 if ($answer eq "y");
		} else {
			$deletionconfirmed = 1;
		}

		#start second run to delete selected files/playlists
		if ($deletionconfirmed) {
			foreach my $res (@resultlist) { $resultids{$res->{id}}=1; }
			$firstrun = 0;
			$AWDB = GNUpod::ArtworkDB->new(Connection=>$connection, DropUnseen=>1);
			GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");
			GNUpod::XMLhelper::writexml($con,{automktunes=>$opts{automktunes}});
			$AWDB->WriteArtworkDb;
		}
	}
}


#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;
	if ($firstrun) {
		return if ($opts{playlist});
		if (GNUpod::FindHelper::filematches($el)) {
			push @resultlist, \%{$el->{file}};  #add a reference to @resultlist
		}
	} else {
		if ($resultids{$el->{file}{id}}) {
			# -> Remove file as requested
			unlink(GNUpod::XMLhelper::realpath($opts{mount},$el->{file}->{path})) or warn "[!!] Remove failed: $!\n";
		} else {
			# -> Keep file: add it to XML
			GNUpod::XMLhelper::mkfile($el);
			# -> and keep artwork
			$AWDB->KeepImage($el->{file}->{dbid_1});
			# -> and playlists
			$keeplist[$el->{file}->{id}] = 1;
		}
	}
}

#############################################
# Eventhandler for playlist items
sub newpl {
	my ($el, $name, $plt) = @_;
	if ($firstrun) {
		if ($opts{'playlist'} && ( $name =~ /$opts{'playlist'}/)) {
			# adding $name to delete list;
			$playlist_names{$name}++;
			#adding $id to droplist for --with-files option
			if(($plt eq "pl" or $plt eq "pcpl") && ref($el->{add}) eq "HASH") { #Add action
				if(defined($el->{add}->{id})) { #Only id
					$playlist_resultids{$el->{add}->{id}} = 1;
				}
			}
		}
	} else {
		if ($opts{playlist} && ( $name =~ /$opts{'playlist'}/)) {
			#print "skipping playlist element:\n".Dumper(\@_);
			return;
		}
		# Delete or rename needs to rebuild the XML file
		if(($plt eq "pl" or $plt eq "pcpl") && ref($el->{add}) eq "HASH") { #Add action
			if(defined($el->{add}->{id}) && int(keys(%{$el->{add}})) == 1) { #Only id
				return unless($keeplist[$el->{add}->{id}]); #ID not on keeplist. drop it
			}
		}
		elsif($plt eq "spl" && ref($el->{splcont}) eq "HASH") { #spl content
			if(defined($el->{splcont}->{id}) && int(keys(%{$el->{splcont}})) == 1) { #Only one item
				return unless($keeplist[$el->{splcont}->{id}]);
			}
		}
		GNUpod::XMLhelper::mkfile($el,{$plt."name"=>$name});
	}
}

###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
$rtxt = "" if (! defined($rtxt));
die << "EOF";
$fullversionstring
$rtxt
Usage: $programName ...

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --interactive       always ask before deleting
       --force             never ask before deleting
   -p, --playlist=regex    delete playlists that match regex
$GNUpod::FindHelper::findhelp
Report bugs to <bug-gnupod\@nongnu.org>
EOF
}


sub version {
die << "EOF";
$fullversionstring

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

=head1 NAME

gnupod_delete.pl  - delete songs from your iPod

=head1 SYNOPSIS

gnupod_delete.pl [OPTION]

=head1 DESCRIPTION

C<gnupod_delete.pl> searches the F<GNUtunesDB.xml> file for matches to its
arguments and deletes those files from your ipod.

=head1 OPTIONS

###___PODINSERT man/gnupod_find-options.pod___###

=head2 Interaction Options

By default gnupod_delete.pl will only delete up to 20 songs without asking.
If there are more than 20 matches then gnupod_delete.pl will present
the matches and ask the user to confirm the deletion.

=over 4

=item -i, --interactive

Always ask the user before deleting the matching songs. No matter how
few matches there are.

=item --force

Never ask the user before deleting. No matter how many songs will be
deleted.

=back

=head2 Playlist option

=over 4

=item --playlist <regex>

Deletes a playlist that matches regex instead of the actual songs.

Example
  --playlist news
  Will delete playlists that contain the word "news" in their name.

Be careful to anchor the regex if you want exact matches.
The example above would also match a playlist named "mynewstuff" and one named "sinews".

=back

###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Written by Eric C. Cooper <ecc at cmu dot edu> - Contributed to the 'old' GNUpod (< 0.9)

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

Heinrich Langos <henrik-gnupod at prak dot org> - Some patches

###___PODINSERT man/footer.pod___###



#first run will look for the songs and playlists to delete.
#the second run will delete the files from the disk and will
#generate the new xml file.
#A keeplist of file ids is generated during the second run
#in order to remove files not on that list from all playlists.
