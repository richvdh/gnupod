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

use vars qw(%opts @keeplist %rename_tags %FILEATTRDEF);

use constant DEFAULT_SPACE => 32;

my $dbid     = undef;  # Artwork DB-ID

$opts{mount} = $ENV{IPOD_MOUNTPOINT};


print "gnupod_find.pl Version ###__VERSION__### (C) Heinrich Langos\n";

GetOptions(\%opts, "version", "help|h", "mount|m=s",
                   "filter=s@","show=s@","sort=s@",
                   "limit|l=s"
                   );
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_search");

$opts{filter} ||= ''; #Default search
$opts{sort}   ||= '+addtime'; #Default sort
$opts{show}   ||= 'id,artist,album,title'; #Default show

usage()   if $opts{help};
version() if $opts{version};

#Check if input makes sense:



########################
# prepare sortlist

my @sortlist = ();
for my $sortkey (split(/\s*,\s*/,   $opts{sort})) {
  if ( (substr($sortkey,0,1) ne "+") && 
       (substr($sortkey,0,1) ne "-") ) {
     $sortkey = "+".$sortkey;
  }
  if (!defined($FILEATTRDEF{substr($sortkey,1)})) {
    die ("Unknown sortkey ".substr($sortkey,1));
  }
  push @sortlist, $sortkey;
}

########################
# prepare filterlist
#So --filter artist=="Pink" would find just "Pink" and not "Pink Floyd",
#and --filter year=<2005 would find songs made before 2005,
#and --filter addtime=<2008-07-15 would find songs added to my ipod before July 15th,
#and --filter addtime=>"yesterday" would find songs added in the last 24h,
#and --filter releasedate=<"last week" will find podcast entries that are older than a week.

my @filterlist =();
for my $filterkey ( split(/\s*,\s*/, $opts{filter}) ) {
  if ($filterkey =~ /^([0-9a-z_]+)([=<>~]+)(.*)$/) {

    if (!defined($FILEATTRDEF{$1})) {
      die ("Unknown filterkey $1");
    }

    my %filterdef = ( 'attr' => $1, 'operand' => $2, 'value' => $3 );
    push @filterlist,  %filterdef;
  } else {
    die ("Invalid filter definition: ", $filterkey);
  }
}

########################
# prepare showlist

my @showlist =();
for my $showkey (split(/\s*,\s*/,   $opts{show})) {
  if (!defined($FILEATTRDEF{$showkey})) {
    die ("Unknown showkey $showkey");
  }
  push @showlist, $showkey;
}


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

sub matcher_numeric {
  


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
	my $ntm      = keys(%opts)-2-$opts{'match-once'}-$opts{automktunes}-$opts{delete}-(defined $opts{rename})-(defined $opts{artwork})-(defined $opts{model});

	my $matched  = undef;
#	use Data::Dumper;
#	print Dumper(\%opts);
#	print Dumper($ntm);


        # check for matches
	my $filematches=1;
	foreach my $filter (@filterlist) {
		if ($filter->{attr} eq "numeric") {
                	if (matcher_numeric($filter, $el->{file}->{$filter}->{attr})) {
				#matching
				
				next;
			} else {
				$filematches = 0;
			}
		}
		
	}

	if ($filematches) {
	#add to output list
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

