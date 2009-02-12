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
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::ArtworkDB;
use Getopt::Long;
#use GNUpod::iTunesDB qw(FILEATTRDEF);
use Data::Dumper;

use constant MACTIME => GNUpod::FooBar::MACTIME;


use vars qw(%opts @keeplist);

use constant DEFAULT_SPACE => 32;

my $dbid     = undef;  # Artwork DB-ID

$opts{mount} = $ENV{IPOD_MOUNTPOINT};


print "gnupod_find.pl Version ###__VERSION__### (C) Heinrich Langos\n";

GetOptions(\%opts, "version", "help|h", "mount|m=s",
                   "filter|f=s@","show|s=s@","sort|o=s@",
                   "limit|l=s"
                   );
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_search");

print Dumper(\%opts);

$opts{filter} ||= []; #Default search
$opts{sort}   ||= ['+addtime']; #Default sort
$opts{show}   ||= ['id,artist,album,title']; #Default show

print Dumper(\%opts);

usage()   if $opts{help};
version() if $opts{version};

#Check if input makes sense:


# full attribute list
#print Dumper(\%GNUpod::iTunesDB::FILEATTRDEF);

# both work:
#print %GNUpod::iTunesDB::FILEATTRDEF->{year}{help}."\n";
#print %GNUpod::iTunesDB::FILEATTRDEF->{year}->{help}."\n";

# get a copy 
#my %x = %GNUpod::iTunesDB::FILEATTRDEF;
#print Dumper(\%x);

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
    $candidates{$attr} += 2 if (index(lc(%GNUpod::iTunesDB::FILEATTRDEF->{$attr}{help}), $input) != -1) ;
  }
  
  if (defined(%candidates) ) {
    $output = "Did you mean: \n";
    for my $key (sort( keys( %candidates))) {
  #    print "\t".$key.":\t".%GNUpod::iTunesDB::FILEATTRDEF->{$key}{help}."\n";
      $output .= sprintf "\t%-15s %s\n", $key.":", %GNUpod::iTunesDB::FILEATTRDEF->{$key}{help};
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
    if (!defined(%GNUpod::iTunesDB::FILEATTRDEF->{substr($sortkey,1)})) {
      die ("Unknown sortkey \"".substr($sortkey,1)."\". ".help_find_attribute(substr($sortkey,1)));
    }
    push @sortlist, $sortkey;
  }
}
#print "Sortlist:\n".Dumper(\@sortlist);

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
    print "filterkey: $filterkey\n";
    if ($filterkey =~ /^([0-9a-z_]+)([!=<>~]+)(.*)$/) {
  
      if (!defined(%GNUpod::iTunesDB::FILEATTRDEF->{$1})) {
        die ("Unknown filterkey \"".$1."\". ".help_find_attribute($1));
      }
  
      my $filterdef = { 'attr' => $1, 'operator' => $2, 'value' => $3 };
      push @filterlist,  $filterdef;
    } else {
      die ("Invalid filter definition: ", $filterkey);
    }
  }
}

print "Filterlist:\n".Dumper(\@filterlist);


########################
# prepare showlist

my @showlist =();
for my $showopt (@{$opts{show}}) {
  for my $showkey (split(/\s*,\s*/,   $showopt)) {
    if (!defined(%GNUpod::iTunesDB::FILEATTRDEF->{$showkey})) {
      die ("Unknown showkey \"".$showkey."\". ".help_find_attribute($showkey));
    }
    push @showlist, $showkey;
  }
}
#print "Showlist:\n".Dumper(\@showlist);

# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

#my $AWDB  = GNUpod::ArtworkDB->new(Connection=>$connection, DropUnseen=>1);


main($connection);



####################################################
# sorter
sub compare {
  my $result=0;
  for my $sortkey (@sortlist) {
    if (substr ($sortkey,0,1) eq "+") {
      $result = $a->{substr($sortkey,1)} <=> $b->{substr($sortkey,1)};
    } else { #"-"
      $result = $b->{substr($sortkey,1)} <=> $a->{substr($sortkey,1)};
    }
    if ($result != 0) { return $result; }
  }
}


###################################################
# matcher

sub matcher {
  my ($filter, $testdata) = @_;
#  print "filter:\n".Dumper($filter);
#  print "data:\n".Dumper($data);
  my $value;
  my $data;
  if (%GNUpod::iTunesDB::FILEATTRDEF->{$filter->{attr}}->{format} eq "numeric") {
    $data = int($testdata); # TODO: Check if $testdata is indeed numeric
    if (%GNUpod::iTunesDB::FILEATTRDEF->{$filter->{attr}}->{content} eq "mactime") {   #handle content MACTIME 
      if (eval "require Date::Manip") {
        # use Date::Manip if it is available
        require Date::Manip;
        import Date::Manip; 
        $value = UnixDate(ParseDate($filter->{value}),"%s")+MACTIME;
      } else {
        # fall back to Date::Parse
        $value = int(Date::Parse::str2time($filter->{value}))+MACTIME;
      }
    } else {
      $value = int($filter->{value}); # TODO: Check if Filter->Value is indeed numeric
    }
  } else { # non numeric attributes
    $data = $testdata;
    $value = $filter->{value};
  }
  $_= $filter->{operator};
#    if (/^(([<>])|([<>!=]=))$/) { $op = $_; return 1 if (eval ($numdata.$op.$numvalue)) ;} # this covers < > <= >= != and ==  ... but eval is slow
  if ($_ eq ">")  { return ($data >  $value); last SWITCH; }
  if ($_ eq "<")  { return ($data <  $value); last SWITCH; }
  if ($_ eq ">=") { return ($data >= $value); last SWITCH; }
  if ($_ eq "<=") { return ($data <= $value); last SWITCH; }
  if ($_ eq "==") { return ($data == $value); last SWITCH; }
  if ($_ eq "!=") { return ($data != $value); last SWITCH; }
  if (($_ eq "~=") or ($_ eq "=") or ($_ eq "=~"))  { return ($data =~ /$value/i); last SWITCH; }
  die ("No handler for your operator \"".$_."\" found. Could be a bug."); 
}

####################################################
# Worker
sub main {

	my($con) = @_;
	
	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

}

#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;
                          # 2 = mount + view (both are ALWAYS set)
#	my $ntm      = keys(%opts)-2-$opts{'match-once'}-$opts{automktunes}-$opts{delete}-(defined $opts{rename})-(defined $opts{artwork})-(defined $opts{model});

	my $matched  = undef;
#	use Data::Dumper;
#	print Dumper(\%opts);
#	print Dumper($ntm);

        # check for matches
	my $filematches=1;
	foreach my $filter (@filterlist) {
#                print "Testing for filter:\n".Dumper($filter);

               	if (matcher($filter, $el->{file}->{$filter->{attr}})) {
			#matching
			next;
		} else {
			#not matching
			$filematches = 0;
			last;
		}
		
	}

	if ($filematches) {
		#add to output list
		print "match: ".$el->{file}->{title}."\n";
	}
}

############################################
# Eventhandler for PLAYLIST items
sub newpl {
	# Delete or rename needs to rebuild the XML file
	my ($el, $name, $plt) = @_;
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


##############################################################
# Printout Search output
sub pview {
  my ($orf,$xhead) = @_;

  for my $showkey (@showlist) {
    
  }

 #Build refs
 my %qh = ();
 $qh{n}{k} = $orf->{songnum};   $qh{n}{w} = 4;  $qh{n}{n} = "SNUM";
 $qh{t}{k} = $orf->{title};                     $qh{t}{s} = "TITLE";
 $qh{a}{k} = $orf->{artist};                    $qh{a}{s} = "ARTIST";
 $qh{r}{k} = $orf->{rating};    $qh{r}{w} = 4;  $qh{r}{s} = "RTNG";
 $qh{p}{k} = $orf->{path};      $qh{p}{w} = 96; $qh{p}{s} = "PATH";
 $qh{l}{k} = $orf->{album};                     $qh{l}{s} = "ALBUM";
 $qh{g}{k} = $orf->{genre};                     $qh{g}{s} = "GENRE";
 $qh{R}{k} = $orf->{podcastrss};                $qh{R}{s} = "RSS";
 $qh{G}{k} = $orf->{podcastguid};               $qh{G}{s} = "GUID";
 $qh{c}{k} = $orf->{playcount}; $qh{c}{w} = 4;  $qh{c}{s} = "CNT";
 $qh{i}{k} = $orf->{id};        $qh{i}{w} = 4;  $qh{i}{s} = "ID";
 $qh{d}{k} = $orf->{dbid_1};    $qh{d}{w} = 16; $qh{d}{s} = "DBID";
 $qh{b}{k} = $orf->{bitrate};   $qh{b}{w} = 8;  $qh{b}{s} = "BITRATE";
 $qh{u}{k} = GNUpod::XMLhelper::realpath($opts{mount},$orf->{path}); $qh{u}{w} = 96; $qh{u}{s} = "UNIXPATH";
 
 #Prepare view
 
 my $ll = 0; #LineLength
  foreach(split(//,$opts{view})) {
      print "|" if $ll;
      my $cs = $qh{$_}{k};           #CurrentString
         $cs = $qh{$_}{s} if $xhead; #Replace it if HEAD is needed
 
      my $cl = $qh{$_}{w}||DEFAULT_SPACE;       #Current length
         $ll += $cl+1;               #Incrase LineLength
     printf("%-*s",$cl,$cs);
  }
  
  if($xhead) {
   print "\n";
   print "=" x $ll;
   print "\n";
  }
  else {
   print "\n";
  }

}


###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_find.pl [-m directory] ...

   -h, --help              display this help and exit
       --list-attributes   display all attributes for filter/show/sort
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -f, --filter FILTERDEF  only show tracks that match FILTERDEF
   -s, --show SHOWDEF      only show track attributes listed in SHOWDEF
   -o, --sort SORTDEF      order output according to SORTDEF
   -l, --limit=#           Only output # first tracks (-# for the last #)

Note: * String arguments (title/artist/album/etc) have to be UTF8 encoded!
      * Use '>3' to search all values above 3, use '<3' to search for values below 3
      * Use '-10-30' to search all values between (and including) 10 to 30.
      * Everything else is handled as regular expressions! If you want to search for
        eg. ID '3' (excluding 13,63,32..), you would have to write: --id="^3\$"

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

