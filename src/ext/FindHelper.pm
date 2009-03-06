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

our $findhelp = '
   -f, --filter FILTERDEF  only show songss that match FILTERDEF
   -s, --sort SORTDEF      order output according to SORTDEF
   -v, --view VIEWDEF      only show song attributes listed in VIEWDEF
   -o, --or, --once        make any filter match (think OR vs. AND)
   -l, --limit=N           Only output N first tracks (-N: all but N first)

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
	return $input if defined($GNUpod::iTunesDB::FILEATTRDEF{$input});

	#short cuts
	if (length($input) == 1) {
		my $out = undef;
		if (defined($out = $GNUpod::iTunesDB::FILEATTRDEF_SHORT{$input})) {
			return $out;
		}
	}

	#prefix match
	my @candidates=();
	for my $attr (sort(keys %GNUpod::iTunesDB::FILEATTRDEF)) {
		push @candidates,$attr if (index($attr, $input) == 0) ;
	}
	if (@candidates == 1) {
		return $candidates[0];
	}

	#default
	return undef;
}

=item process_options ( %options )

Examines the "filter" "sort" and "view" options and returns an array with
three hashrefs containing the filterlist sortlist and viewlist.
If an error is encountered either undef or a string containing an error
description is returned.

It also prepares three lists that other FindHelper functions will need
to work properly:

  @filterlist
  @sortlist
  @viewlist

Those are also exported by this module. So it's up to you if you want to
use them directly, from the returned references, via the exported array
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
our @sortlist = ();
our @viewlist = ();

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
				if ($GNUpod::iTunesDB::FILEATTRDEF{$attr}{format} eq "numeric") {
					if ($GNUpod::iTunesDB::FILEATTRDEF{$attr}{content} eq "mactime") {   #handle content MACTIME
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
							require Date::Format;
							import Date::Format;
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
	return [ \@filterlist, \@sortlist, \@viewlist ];
}

sub help_find_attribute {
	my ($input) = @_;
	my %candidates =();
	my $output="";
	# substring of attribute name
	for my $attr (sort(keys %GNUpod::iTunesDB::FILEATTRDEF)) {
		$candidates{$attr} = 1 if (index($attr, $input) != -1) ;
	}
	# substring of attribute help
	for my $attr (sort(keys %GNUpod::iTunesDB::FILEATTRDEF)) {
		$candidates{$attr} += 2 if (index(lc($GNUpod::iTunesDB::FILEATTRDEF{$attr}{help}), $input) != -1) ;
	}

	if (%candidates) {
		$output = "Did you mean: \n";
		for my $key (sort( keys( %candidates))) {
			$output .= sprintf "\t%-15s %s\n", $key.":", $GNUpod::iTunesDB::FILEATTRDEF{$key}{help};
		}
	}
	return $output;
}

####################################################
# sorter

=item comparesong($$)

Sort routine that uses @GNUpod::FindHelper::sortlist to compare the songs.
If data in numeric fields (see %GNUpod::iTunesDB::FILEATTRDEF) is
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
		if ($GNUpod::iTunesDB::FILEATTRDEF{substr($sortkey,1)}{format} eq "numeric") {
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


=item croplist ($limit, @list)

Crop a list to contain the right amount of elements.

If passed a positive integer in $limit, the first $limit elements of @list are returned.

If passed a negative integer in $limit, ALL BUT the first $limit elements of @list are returned.

If a non-numeric variable is passed in $limit, the whole @list is returned.

=cut

sub croplist {
	my ($limit, @resultlist) = @_;
	if (defined($limit) and ($limit =~ /^-?\d+/)) {
		if ($limit >= 0) {
			splice @resultlist, $limit if ($#resultlist >= $limit);
		} else {
			if (-1 * $limit > $#resultlist) {
				@resultlist = ();
			} else {
				my @limitedlist = splice @resultlist, -1 * $limit;
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
	if ($GNUpod::iTunesDB::FILEATTRDEF{$filter->{attr}}{format} eq "numeric") {

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

=item filematches ($el, $once)

Returns 1 if the hasref $el->{file} matches the @FindHelper::filterlist and 0 if it doesn't match.

If $once evaluates to the boolean value True than a single match on any
condition specified in the @FindHelper::filterlist is enough. Otherwise
all conditions have to match.

NOTE: If an attribute is not present (like releasedate in non-podcast items)
than a match on those elements will always fail.

=cut

sub filematches {
	my ($el,$once) =  @_;
	# check for matches
	my $matches=1;
	foreach my $filter (@filterlist) {
		#print "Testing for filter:\n".Dumper($filter);

		if (matcher($filter, $el->{file}->{$filter->{attr}})) {
			#matching
			$matches = 1;
			if ($once) {
				#ok one match is enough.
				last;
			}
		} else {
			#not matching
			$matches = 0;
			if (! $once) {
				# one mismatch is enough
				last;
			}
		}
	}
	return $matches;
}

##############################################################
# computed attributes

=item computeresults ($connection, $el, $field)

Computes result song data passed in the array ref $results
according to the list of fields passed in the array ref $view.

=cut


sub computeresults {
	my ($song, $fieldname) = @_;
	if (defined ($GNUpod::iTunesDB::FILEATTRDEF_COMPUTE{$fieldname})) {
		#print "Found code for $fieldname \n";
		my $coderef = $GNUpod::iTunesDB::FILEATTRDEF_COMPUTE{$fieldname};
		return &$coderef($song);
	} else {
		return $song->{$fieldname};
	}
}


##############################################################
# Printout

=item prettyprint ($results, $view)

Prints the song data passed in the array ref $results according to the
list of fields passed in the array ref $view.

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
	my $totalwidth=0;
	my $firstcolumn=1;
	my $overhang=0;
	foreach my $viewkey (@viewlist) {
		if ($firstcolumn) {$firstcolumn=0;} else { print " | "; $totalwidth+=3; }
		$overhang = printonefield($GNUpod::iTunesDB::FILEATTRDEF{$viewkey}, $GNUpod::iTunesDB::FILEATTRDEF{$viewkey}{header}, $overhang);
		$totalwidth += $GNUpod::iTunesDB::FILEATTRDEF{$viewkey}{width};
	}
	print "\n";
	print "=" x $totalwidth ."\n";
}

sub printoneline {
	my ($song) = @_;
	my $totalwidth=0;
	my $firstcolumn=1;
	my $overhang=0;
	foreach my $viewkey (@viewlist) {
		if ($firstcolumn) {$firstcolumn=0;} else { print " | "; $totalwidth+=3; }
		$overhang = printonefield($GNUpod::iTunesDB::FILEATTRDEF{$viewkey}, computeresults($song,$viewkey), $overhang);
	}
}


sub prettyprint {
	my ($results) = @_ ;

	printheader();

	foreach my $song (@{$results}) {
		printoneline($song);
		print "\n";
	}

# $qh{u}{k} = GNUpod::XMLhelper::realpath($opts{mount},$orf->{path}); $qh{u}{w} = 96; $qh{u}{s} = "UNIXPATH";

}

1;

