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

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

use constant MACTIME => GNUpod::FooBar::MACTIME;


use vars qw(%opts);

$opts{mount} = $ENV{IPOD_MOUNTPOINT};


print "gnupod_find.pl Version ###__VERSION__### (C) Heinrich Langos\n";

GetOptions(\%opts, "version", "help|h", "mount|m=s",
                   "filter|f=s@","view|v=s@","sort|s=s@",
                   "once|or|o",
                   "limit|l=s"
                   );
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_search");

#print Dumper(\%opts);

$opts{filter} ||= []; #Default search
$opts{sort}   ||= ['+addtime']; #Default sort
$opts{view}   ||= ['id,artist,album,title']; #Default view

#print "Options: ".Dumper(\%opts);

usage()   if $opts{help};
version() if $opts{version};

#Check if input makes sense:


# full attribute list
#print Dumper(\%GNUpod::iTunesDB::FILEATTRDEF);

## all work but 1 and 2 are deprecated
#print "1: ".%GNUpod::iTunesDB::FILEATTRDEF->{year}{help}."\n";
#print "2: ".%GNUpod::iTunesDB::FILEATTRDEF->{year}->{help}."\n";
#print "3: ".$GNUpod::iTunesDB::FILEATTRDEF{year}{help}."\n";
#print "4: ".$GNUpod::iTunesDB::FILEATTRDEF{year}->{help}."\n";
#
## this does not work and without "use warnings;" you woudln't even know!
## did i mention that i hate perl?
#print "5: ".$GNUpod::iTunesDB::FILEATTRDEF->{year}->{help}."\n";

sub help_find_attribute {
  my ($input) = @_;
  my %candidates =();
  my $output;
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
  #    print "\t".$key.":\t".$GNUpod::iTunesDB::FILEATTRDEF{$key}{help}."\n";
      $output .= sprintf "\t%-15s %s\n", $key.":", $GNUpod::iTunesDB::FILEATTRDEF{$key}{help};
    } 
  }
  return $output;
}

########################
# prepare sortlist

my @sortlist = ();
for my $sortopt (@{$opts{sort}}) {
  
  for my $sortkey (split(/\s*,\s*/, $sortopt )) {
    if ( (substr($sortkey,0,1) ne "+") && 
         (substr($sortkey,0,1) ne "-") ) {
       $sortkey = "+".$sortkey;
    }
    if (!defined($GNUpod::iTunesDB::FILEATTRDEF{substr($sortkey,1)})) {
      die ("Unknown sortkey \"".substr($sortkey,1)."\". ".help_find_attribute(substr($sortkey,1)));
    }
    push @sortlist, $sortkey;
  }
}
#print "Sortlist: ".Dumper(\@sortlist);

########################
# prepare filterlist
#So --filter artist=="Pink" would find just "Pink" and not "Pink Floyd",
#and --filter year=<2005 would find songs made before 2005,
#and --filter addtime=<2008-07-15 would find songs added to my ipod before July 15th,
#and --filter addtime=>"yesterday" would find songs added in the last 24h,
#and --filter releasedate=<"last week" will find podcast entries that are older than a week.

my @filterlist =();
for my $filteropt (@{$opts{filter}}) {
  for my $filterkey (split(/\s*,\s*/, $filteropt)) {
#    print "filterkey: $filterkey\n";
    if ($filterkey =~ /^([0-9a-z_]+)([!=<>~]+)(.*)$/) {

      if (!defined($GNUpod::iTunesDB::FILEATTRDEF{$1})) {
        die ("Unknown filterkey \"".$1."\". ".help_find_attribute($1));
      }

      my $value;
      if ($GNUpod::iTunesDB::FILEATTRDEF{$1}{format} eq "numeric") {
        if ($GNUpod::iTunesDB::FILEATTRDEF{$1}{content} eq "mactime") {   #handle content MACTIME
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
            print "Time value \"$3\" evaluates to $value unix epoch time (".($value+MACTIME)." mactime) which is ".time2str("%C",$value)."\n";
            $value += MACTIME; 
          } else {
            die ("Sorry, your time/date definition \"$3\" was not understood.");
          }
        } else { #not "mactime"
          $value = $3; # DO NOT USE : $value = int($3); or you will screw up regex matches on numeric fields
        }
      } else { #not numeric
        $value = $3; # not much we could check for
      }
  
      my $filterdef = { 'attr' => $1, 'operator' => $2, 'value' => $value };
      push @filterlist,  $filterdef;
    } else {
      die ("Invalid filter definition: ", $filterkey);
    }
  }
}

#print "Filterlist (".($opts{once}?"or":"and")."-connected): ".Dumper(\@filterlist);


########################
# prepare viewlist

my @viewlist =();
for my $viewopt (@{$opts{view}}) {
  for my $viewkey (split(/\s*,\s*/,   $viewopt)) {
    if (!defined($GNUpod::iTunesDB::FILEATTRDEF{$viewkey})) {
      die ("Unknown viewkey \"".$viewkey."\". ".help_find_attribute($viewkey));
    }
    push @viewlist, $viewkey;
  }
}
#print "Viewlist: ".Dumper(\@viewlist);


my @resultlist=();

# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

main($connection);


####################################################
# sorter
sub comparesongs {
  
  my $result=0;
  for my $sortkey (@sortlist) {   # go through all sortkeys
    # take the data that needs to be comapred into $x and $y
    my ($x,$y) = ($a->{substr($sortkey,1)}, $b->{substr($sortkey,1)} ); 

    # if sort order is reversed simply switch x any y
    if (substr ($sortkey,0,1) eq "-") {
      ($x, $y)=($y, $x);
    }

    # now compare x and y     
    if ($GNUpod::iTunesDB::FILEATTRDEF{substr($sortkey,1)}{format} eq "numeric") {
      $result = int($x) <=> int($y); # avoid problems of comparing NaN with NaN
    } else {
      $result = $x cmp $y;
    }

    # if they are equal we will go on to the next sortkey. otherwise we return the result
    if ($result != 0) { return $result; }
  }

  # after comparing according to all sortkeys the songs are still equal.
  return 0;
}


###################################################
# matcher

sub matcher {
  my ($filter, $testdata) = @_;
#  print "filter:\n".Dumper($filter);
#  print "data:\n".Dumper($data);
  my $value;
  my $data;
  if ($GNUpod::iTunesDB::FILEATTRDEF{$filter->{attr}}{format} eq "numeric") {
    $data = $testdata; # TODO: Check if $testdata is indeed numeric. it should be since we get it from the database
    $value = $filter->{value}; # TODO: Check if Filter->Value is indeed numeric OR if we do regex matching

    $_ = $filter->{operator};
    if ($_ eq ">")  { return ($data >  $value); }
    if ($_ eq "<")  { return ($data <  $value); }
    if ($_ eq ">=") { return ($data >= $value); }
    if ($_ eq "<=") { return ($data <= $value); }
    if (($_ eq "=") or ($_ eq "==")) { return ($data == $value); }
    if ($_ eq "!=") { return ($data != $value); }
    if (($_ eq "~") or ($_ eq "~=") or ($_ eq "=~"))  { return ($data =~ /$value/i); }
    die ("No handler for your operator \"".$_."\" with numeric data found. Could be a bug."); 

  } else { # non numeric attributes
    $data = $testdata;
    $value = $filter->{value};

    $_ = $filter->{operator};
    if ($_ eq ">")  { return ($data gt $value); }
    if ($_ eq "<")  { return ($data lt $value); }
    if ($_ eq ">=") { return ($data ge $value); }
    if ($_ eq "<=") { return ($data le $value); }
    if ($_ eq "==") { return ($data eq $value); }
    if ($_ eq "!=") { return ($data ne $value); }
    if (($_ eq "~") or ($_ eq "=") or ($_ eq "~=") or ($_ eq "=~"))  { return ($data =~ /$value/i); }
    die ("No handler for your operator \"".$_."\" with non-numeric data found. Could be a bug."); 
  }

}

####################################################
# Worker
sub main {

	my($con) = @_;
	
	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

#        print "resultlist:\n".Dumper(\@resultlist);

	my @sortedresultlist = sort comparesongs @resultlist;

#        print "sortedresultlist:\n".Dumper(\@sortedresultlist);

	if (defined($opts{limit})) {
		if ($opts{limit} > 0) {
			splice @sortedresultlist, $opts{limit};
		} else {
			my @limitedlist = splice @sortedresultlist, -1 * $opts{limit};
			@sortedresultlist = @limitedlist;
		}
	}
	prettyprint (\@sortedresultlist);
}

#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;
	my $matched;

        # check for matches
	my $filematches=1;
	foreach my $filter (@filterlist) {
#                print "Testing for filter:\n".Dumper($filter);

               	if (matcher($filter, $el->{file}->{$filter->{attr}})) {
			#matching
	                $filematches = 1;
			if ($opts{once}) {
				#ok one match is enough.
				last;
			}
		} else {
			#not matching
			$filematches = 0;
			if (! $opts{once}) {
				# one mismatch is enough 
				last;
			}
		}
		
	}

	if ($filematches) {
		#add to output list
		my %hit = %{$el->{file}}; #copy the hash
		push @resultlist, \%hit;  #add a reference to that copy to @resultlist
	}
}

##############################################################
# Printout 
sub prettyprint {
  my ($results) = @_ ;
    foreach my $viewkey (@viewlist) {
      printf "%-".$GNUpod::iTunesDB::FILEATTRDEF{$viewkey}{width}."s"." | ", $GNUpod::iTunesDB::FILEATTRDEF{$viewkey}{header};
    }
    print "\n";

  foreach my $song (@{$results}) {
    foreach my $viewkey (@viewlist) {
      printf "%-".$GNUpod::iTunesDB::FILEATTRDEF{$viewkey}{width}."s"." | ", $song->{$viewkey};
    }
    print "\n";
  }


# $qh{u}{k} = GNUpod::XMLhelper::realpath($opts{mount},$orf->{path}); $qh{u}{w} = 96; $qh{u}{s} = "UNIXPATH";
 
 #Prepare view
 
# my $ll = 0; #LineLength
#  foreach(split(//,$opts{view})) {
#      print "|" if $ll;
#      my $cs = $qh{$_}{k};           #CurrentString
#         $cs = $qh{$_}{s} if $xhead; #Replace it if HEAD is needed
# 
#      my $cl = $qh{$_}{w}||DEFAULT_SPACE;       #Current length
#         $ll += $cl+1;               #Incrase LineLength
#     printf("%-*s",$cl,$cs);
#  }
  
#  if($xhead) {
#   print "\n";
#   print "=" x $ll;
#   print "\n";
#  }
#  else {
#   print "\n";
#  }

}


###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_find.pl [-m directory] ...

   -h, --help              display this help and exit
       --list-attributes   display all attributes for filter/view/sort
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -f, --filter FILTERDEF  only show songss that match FILTERDEF
   -v, --view VIEWDEF      only show song attributes listed in VIEWDEF
   -s, --sort SORTDEF      order output according to SORTDEF
   -o, --or, --once        make any filter match (think OR vs. AND)
   -l, --limit=N           Only output N first tracks (-N: all but N first)

VIEWDEF ::= <attribute>[,<attribute>]...
    A comma separated list of fields that you want to see in the output.
    Example: "album,songnum,artist,title"
    Default: "id,artist,album,title"

SORTDEF ::= ["+"|"-"]<attribute>,[["+"|"-"]<attribute>] ...
    Is a comma separated list of fields to order the output by. 
    A "-" (minus) reverses the sort order.
    Example "-year,+artist,+album,+songnum"
    Default "+addtime"

FILTERDEF ::= <attribute>["<"|">"|"="|"<="|">="|"=="|"!="|"~"|"~="|"=~"]<value>
   The operators "<", ">", "<=", ">=", "==", and "!=" work as you might expect.
   The operators "~", "~=", and "=~" symbolize regex match (no need for // though).
   The operator "=" checks equality on numeric fields and does regex match on strings.
   TODO: document value for boolean and time fields
   
Note: * String arguments (title/artist/album/etc) have to be UTF8 encoded!

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}


sub version {
die << "EOF";
gnupod_find.pl (gnupod) ###__VERSION__###
Copyright (C) Heinrich Langos 2009

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

