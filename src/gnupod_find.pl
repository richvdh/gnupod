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
#use GNUpod::FooBar;
use GNUpod::FindHelper;
#use GNUpod::ArtworkDB;
use Getopt::Long;

#use Text::CharWidth;

my $programName = "gnupod_find.pl";

my $fullversionstring = "$programName Version ###__VERSION__### (C) Heinrich Langos";

#use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;
#$Data::Dumper::Terse = 1;

use vars qw(%opts);

$opts{mount} = $ENV{IPOD_MOUNTPOINT};


my $getoptres = GetOptions(\%opts, "version", "help|h", "mount|m=s",
	@GNUpod::FindHelper::findoptions
);

# take model and mountpoint from gnupod_search preferences
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_search");


#print Dumper(\%opts);
#print "Options: ".Dumper(\%opts);

usage()   if ($opts{help} || !$getoptres );
version() if $opts{version};
GNUpod::FindHelper::fullattributes() if $opts{'list-attributes'};

## all work but 1 and 2 are deprecated
#print "1: ".%GNUpod::FindHelper::FILEATTRDEF->{year}{help}."\n";
#print "2: ".%GNUpod::FindHelper::FILEATTRDEF->{year}->{help}."\n";
#print "3: ".$GNUpod::FindHelper::FILEATTRDEF{year}{help}."\n";
#print "4: ".$GNUpod::FindHelper::FILEATTRDEF{year}->{help}."\n";
#
## this does not work and without "use warnings;" you woudln't even know!
## did i mention that i hate perl?
#print "5: ".$GNUpod::FindHelper::FILEATTRDEF->{year}->{help}."\n";

my @resultlist=();

my $foo = GNUpod::FindHelper::process_options(\%opts);

if (!defined $foo) { usage("Trouble parsing find options.") };
if (ref(\$foo) eq "SCALAR") { usage($foo)};

#my @filterlist = @{${$foo}[0]};
#my @sortlist = @{${$foo}[1]};
#my @viewlist = @{${$foo}[2]};
# well isn't that an ugly piece of code? it takes the array reference foo, dereferences it,
# takes one element (another array reference) out of it and dereferences that one before assigning it


# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

main($connection);

####################################################
# Worker
sub main {

	my($con) = @_;

	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

	#print "resultlist:\n".Dumper(\@resultlist);

	@resultlist = sort GNUpod::FindHelper::comparesongs @resultlist;

	@resultlist = GNUpod::FindHelper::croplist({results => \@resultlist});
	#print "sortedresultlist:\n".Dumper(\@resultlist);
	GNUpod::FindHelper::prettyprint ({ results => \@resultlist }) if (@resultlist);
}


#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;

	if (GNUpod::FindHelper::filematches($el)) {
		push @resultlist, \%{$el->{file}};  #add a reference to @resultlist
	}
}

#############################################
# Eventhandler for playlist items
sub newpl {
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

gnupod_find.pl  - Find songs on your iPod

=head1 SYNOPSIS

gnupod_find.pl [OPTION]

=head1 DESCRIPTION

C<gnupod_find.pl> searches the F<GNUtunesDB.xml> file for matches to its
arguments and shows those files.

=head1 OPTIONS

=head2 Generic Program Information

=over 4

=item -h, --help

Display a brief help and exist.

=item --version

Output version information and exit.

=item -m, --mount=directory

iPod mount point, default is C<$IPOD_MOUNTPOINT>.

=item     --list-attributes

Display all attributes that can be used for the filter/view/sort options
and exit.

=item -f, --filter FILTERDEF[,FILTERDEF[,FILTERDEV...]]

Only show songs that match FILTERDEF.

FILTERDEF ::= <attribute>["<"|">"|"="|"<="|">="|"=="|"!="|"~"|"~="|"=~"]<value>
  The operators "<", ">", "<=", ">=", "==", and "!=" work as you might expect.
  The operators "~", "~=", and "=~" symbolize regex match (no need for // though).
  The operator "=" checks equality on numeric fields and does regex match on strings.
  TODO: document value for boolean and time fields

Examples of filter options:
  --filter artist="Pink" would find "Pink", "Pink Floyd" and "spinki",
  --filter artist=="Pink" would find just "Pink" and not "pink" or "Pink Floyd",
  --filter 'year<2005' would find songs made before 2005,
  --filter 'addtime<2008-07-15' would find songs added before July 15th,
  --filter 'addtime>yesterday' would find songs added in the last 24h,
  --filter 'releasedate<last week' will find podcast entries that are older than a week.

Note
    --filter 'year=<1955,artist=Elvis'
  will find the early songs of Elvis and is equivalent to
    --filter 'year=<1955' --filter 'artist=Elvis'

Please note that "<" and ">" most probably need to be escaped on your shell prompt.
So you should probably use
    --filter 'addtime>yesterday'
  rather than
    --filter addtime>yesterday

=item -o, --or, --once

Make any one filter rule match (think OR instead of AND logic)

If the --once option is given any single match on one of the
filter rules is enough to make a song match. Otherwise all conditions
have to match a file.

Example:
    --filter 'year=<1955,artist=Elvis' --or
  would find anything up to 1955 and everything by Elvis (even the
  stuff older than 1955).

=item -s, --sort SORTDEF

Order output according to SORTDEF

SORTDEF ::= ["+"|"-"]<attribute>,[["+"|"-"]<attribute>] ...
  Is a comma separated list of fields to order the output by.
  A "-" (minus) reverses the sort order.
  Example "-year,+artist,+album,+songnum"
  Default "+addtime"

=item -v, --view VIEWDEF

Show song attributes listed in VIEWDEF

VIEWDEF ::= <attribute>[,<attribute>]...
  A comma separated list of fields that you want to see in the output.
  Example: "album,songnum,artist,title"
  Default: "id,artist,album,title"


The special attribute "default" can be used in the --view argument.

Example:
  --view "filesize,default"

The special attribute "all" can be used to display all attributes.

=item -l, --limit=N

Only output N first matches. If N is negative, all "but" the N first
matches will be listed.

Example:
  --limit=10
  will print the first 10 matches
  --limit=-3
  will skip the first 3 matches and print the rest

Note:
  If you need the last 5 matches reverse the sort order and use --limit=5.

=item --noheader

Don't print headers for result list.

=item --rawprint

Output of raw values instead of human readable ones. This includes all
timestamps and the attributes volume and soundcheck. Only attributes that
don't have a raw value like unixpath, are still computed.

=back


###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Written by Eric C. Cooper <ecc at cmu dot edu> - Contributed to the 'old' GNUpod (< 0.9)

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

Heinrich Langos <henrik-gnupod at prak dot org> - Some patches

###___PODINSERT man/footer.pod___###

