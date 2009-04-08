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

my $fullversionstring = "gnupod_delete.pl Version ###__VERSION__### (C) Heinrich Langos";

use vars qw(%opts @keeplist);

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "version", "help|h", "mount|m=s", "interactive|i",
	"playlist|p=s",
	@GNUpod::FindHelper::findoptions
);
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_search");


usage()   if $opts{help};
version() if $opts{version};
fullattributes() if $opts{'list-attributes'};

my %playlist_names=(); # names of the playlists to be deleted
my %playlist_resultids=(); #ids of the songs to be deleted because they are part of a deleted playlist

my @resultlist=();
my %resultids=(); #only used for second pass to skip searching the resultlist

my $foo = GNUpod::FindHelper::process_options(\%opts);

if (!defined $foo) { usage("Trouble parsing find options.") };
if (ref(\$foo) eq "SCALAR") { usage($foo)};

# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

my $AWDB;

my $firstrun = 1; #first run will look for the songs and playlists to delete. the second run will delete them.
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

		@resultlist = sort GNUpod::FindHelper::comparesongs @resultlist;

		@resultlist = GNUpod::FindHelper::croplist($opts{limit}, @resultlist);

	}

	if (@resultlist or %playlist_names) {
		#output results
		GNUpod::FindHelper::prettyprint (\@resultlist) if @resultlist;
		if (%playlist_names) {
			print "             PLAYLIST | #ELEMENTS \n";
			print "======================|===========\n";
			foreach my $name (keys(%playlist_names)) {
				printf " %20s | %d\n",$name,$playlist_names{$name};
			}
		}

		#ask confirmation
		if ($opts{interactive}) {
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
		if (GNUpod::FindHelper::filematches($el,$opts{once})) {
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
Usage: gnupod_find.pl [-m directory] ...

   -h, --help              display this help and exit
       --list-attributes   display all attributes for filter/view/sort
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --interactive       ask before deleting
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

sub fullattributes {
	print $fullversionstring."\n\n";
	printf "\t%-15s | %s\n", "Attribute name" , "Description";
	print "\t================|=========================\n";
	foreach my $key (sort ( keys (%GNUpod::iTunesDB::FILEATTRDEF))) {
		printf "\t%-15s | %s\n", $key, $GNUpod::iTunesDB::FILEATTRDEF{$key}{help};
	}
	exit;
}

