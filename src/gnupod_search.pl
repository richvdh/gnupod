###__PERLBIN__###
#  Copyright (C) 2002-2007 Adrian Ulrich <pab at blinkenlights.ch>
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

use vars qw(%opts @keeplist %rename_tags);

use constant DEFAULT_SPACE => 32;

my $dbid     = undef;  # Artwork DB-ID
my $dirty    = 0;      # Do we need to re-write the XML version?

$opts{mount} = $ENV{IPOD_MOUNTPOINT};



print "gnupod_search.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

# WARNING: If you add new options wich don't do matching, change newfile()
#
GetOptions(\%opts, "version", "help|h", "mount|m=s", "artist|a=s",
                   "album|l=s", "title|t=s", "id|i=s", "rename=s@", "artwork=s",
                   "playcount|c=s", "rating|s=s", "podcastrss|R=s", "podcastguid|U=s",
                   "bitrate|b=s",
                   "view=s","genre|g=s", "match-once|o", "delete");
GNUpod::FooBar::GetConfig(\%opts, {view=>'s', mount=>'s', 'match-once'=>'b', 'automktunes'=>'b', model=>'s', bgcolor=>'s'}, "gnupod_search");

$opts{view} ||= 'ialt'; #Default view

usage()   if $opts{help};
version() if $opts{version};
#Check if input makes sense:
die "You can't use --delete and --rename together\n" if($opts{delete} && $opts{rename});

# -> Connect the iPod
my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

my $AWDB  = GNUpod::ArtworkDB->new(Connection=>$connection, DropUnseen=>1);

main($connection);

####################################################
# Worker
sub main {
	my($con) = @_;
	
	#Build %rename_tags
	foreach(@{$opts{rename}}) {
		my($key,$val) =  split(/=/,$_,2);
		next unless $key && defined($val);
		#$key =~ s/^\s*-+//g; # -- is not valid for xml tags!
		next if lc($key) eq "id";#Dont allow something like THIS
		$rename_tags{lc($key)} = $val;
	}
	
	if($opts{artwork}) {
		if( $AWDB->PrepareImage(File=>$opts{artwork}, Model=>$opts{model}, bgcolor=>$opts{bgcolor}) ) {
			$AWDB->LoadArtworkDb or die "Failed to load artwork database\n";
		}
		else {
			warn "$0: Could not load $opts{artwork}, skipping artwork\n";
			delete($opts{artwork});
		}
	}
	
	pview(undef,1);
	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");
	#XML::Parser finished, write new file if we deleted or renamed
	if($dirty) {
		GNUpod::XMLhelper::writexml($con,{automktunes=>$opts{automktunes}});
	}
	
	$AWDB->WriteArtworkDb;
}

#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;
                          # 2 = mount + view (both are ALWAYS set)
	my $ntm      = keys(%opts)-2-(defined $opts{'match-once'})-(defined $opts{'automktunes'})-(defined $opts{'delete'})-(defined $opts{'rename'})-(defined $opts{'artwork'})-(defined $opts{'model'});
	my $matched  = 0;
	my $dounlink = 0;
	foreach my $opx (keys(%opts)) {
		next if $opx =~ /mount|match-once|delete|view|rename|artwork|model/; #Skip this
		
		
		if(substr($opts{$opx},0,1) eq '>') {
			$matched++ if  int($el->{file}->{$opx}) > int(substr($opts{$opx},1));
		}
		elsif(substr($opts{$opx},0,1) eq '<') {
			$matched++ if  int($el->{file}->{$opx}) < int(substr($opts{$opx},1));
		}
		elsif(substr($opts{$opx},0,1) eq '-') {
			my($s_from, $s_to) = substr($opts{$opx},1) =~ /^(\d+)-(\d+)$/;
			if( (int($el->{file}->{$opx}) >= $s_from) && (int($el->{file}->{$opx}) <= $s_to) ) {
				$matched++;
			}
		}
		elsif(defined($el->{file}->{$opx}) && $el->{file}->{$opx} =~ /$opts{$opx}/i) {
			$matched++;
		}
	}


	if(($opts{'match-once'} && $matched) || $ntm == $matched) {
		# => HIT
		
		# -> Rename tags
		foreach(keys(%rename_tags)) {
			$el->{file}->{$_} = $rename_tags{$_};
			$dirty++;
		}
		# -> Print output
		pview($el->{file},undef,$opts{delete});
		
		if($opts{delete}) {
			$dounlink = 1; # Request deletion
		}
		elsif(defined($opts{artwork})) {
			# -> Add/Set artwork
			$el->{file}->{has_artwork} = 1;
			$el->{file}->{artworkcnt}  = 1;
			$el->{file}->{dbid_1}      = $AWDB->InjectImage;
			$dirty++;
		}
	}
	
	if($dounlink) {
		# -> Remove file as requested
		unlink(GNUpod::XMLhelper::realpath($opts{mount},$el->{file}->{path})) or warn "[!!] Remove failed: $!\n";
		$dirty++;
	}
	else {
		# -> Keep file: add it to XML
		GNUpod::XMLhelper::mkfile($el);
		# -> and keep artwork
		$AWDB->KeepImage($el->{file}->{dbid_1});
		# -> and playlists
		$keeplist[$el->{file}->{id}] = 1;
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
 my($orf,$xhead, $xdelete) = @_;
 
 #Build refs
 my %qh = ();
 $qh{n}{k} = $orf->{songnum};   $qh{n}{w} = 4;  $qh{n}{s} = "SNUM";
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
      my $cs = defined($qh{$_}{k}) ? $qh{$_}{k} : '' ;  #CurrentString
         $cs = $qh{$_}{s} if $xhead; #Replace it if HEAD is needed
 
      my $cl = $qh{$_}{w}||DEFAULT_SPACE;       #Current length
         $ll += $cl+1;               #Incrase LineLength
     printf("%-*s",$cl,$cs);
  }
  
  if($xdelete && !$xhead) {
   print " [RM]\n";
  }
  elsif($xhead) {
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
Usage: gnupod_search.pl [-h] [-m directory] File1 File2 ...

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -t, --title=TITLE       search songs by Title
   -a, --artist=ARTIST     search songs by Artist
   -l, --album=ALBUM       search songs by Album
   -i, --id=ID             search songs by ID
   -g, --genre=GENRE       search songs by Genre
   -c, --playcount=COUNT   search songs by Playcount
   -s, --rating=COUNT      search songs by Rating (20 is one star, 40 two, etc.)
   -R, --podcastrss=RSS    search songs by RSS
   -U, --podcastguid=GUID  search songs by GUID
   -b, --bitrate=BITRATE   search songs by Bitrate
   -o, --match-once        Search doesn't need to match multiple times (eg. -a & -l)
       --delete            REMOVE (!) matched songs
       --view=ialt         Modify output, default=ialt
                            t = title    a = artist   r = rating      p = iPod Path
                            l = album    g = genre    c = playcount   i = id
                            u = UnixPath n = Songnum  G = podcastguid R = podcastrss
                            d = dbid
       --rename=KEY=VAL    Change tags on found songs. Example: --rename="ARTIST=Foo Bar"
       --artwork=FILE      Set FILE as Cover for found files, do not forget to run mktunes.pl

Note: * Argument for title/artist/album/etc has to be UTF8 encoded, *not* latin1!
      * Use '>3' to search all values above 3, use '<3' to search for values below 3
      * Use '-10-30' to search all values between (and including) 10 to 30.
      * Everything else is handled as regular expressions! If you want to search for
        eg. ID '3' (excluding 13,63,32..), you would have to write: --id="^3\$"

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}


sub version {
die << "EOF";
gnupod_search.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2008

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}


=head1 NAME

gnupod_search.pl  - Search, list, edit, delete songs from your iPod

=head1 SYNOPSIS

	gnupod_search.pl [OPTION] File1 File2 ...

=head1 DESCRIPTION

C<gnupod_search.pl> searches the F<GNUtunesDB.xml> file for matches to its
arguments.  These search results can then be changed (via C<--rename>) or
deleted (via C<--delete>).  For these changes to be visible to the iPod,
C<mktunes> must be run.

=head1 OPTIONS

=head2 Generic Program Information

=over 4

=item -h, --help

Lists out all the options.

=item --version

Output version information and exit.

=item -m, --mount=directory

iPod mount point, default is C<$IPOD_MOUNTPOINT>.

=back

=head2 Search fields

By default, search arguments are treated as regular expressions.  The
exception to this are numerical comparisons (C<< --id<4 >> and 
C<< bitrate>255 >>) and numerical ranges (C< --rating=20-40 >).

The argument for title/artist/album/etc has to be UTF8 encoded, B<not> latin1!

=over 4

=item -t, --title=TITLE

search songs by Title.

=item -a, --artist=ARTIST

search songs by Artist.

=item -l, --album=ALBUM

search songs by Album.

=item -i, --id=ID

search songs by ID.

=item -g, --genre=GENRE

search songs by Genre.

=item -c, --playcount=COUNT

search songs by Playcount.

=item -s, --rating=COUNT

search songs by Rating (20 is one star, 40 two, etc.)

=item -R, --podcastrss=RSS

search songs by RSS.

=item -U, --podcastguid=GUID

search songs by podcast group id.

=item -b, --bitrate=BITRATE

search songs by Bitrate.

=item -o, --match-once

Search doesn't need to match multiple times, even though there is more than
one match criteria.  Essentially changes the search from using I<and> to
I<or>.  For example:

	gnupod_search.pl -m /mnt/ipod --rating="60-100" --artist="Amos"

matches all songs by "Amos" which have a rating of 3-5 stars.  Whereas

	gnupod_search.pl -m /mnt/ipod --rating="60-100" --artist="Amos" --match-once

matches all songs by "Amos" and all songs which have a rating of 3-5 stars.

=item --view=ialt

Modify how the search results are displayed.  default=ialt  Options are:

	t = title    a = artist   r = rating      p = iPod Path
	l = album    g = genre    c = playcount   i = id
	u = UnixPath n = Songnum  G = podcastguid R = podcastrss
	d = dbid

=back

=head2 Changing song information

After you have finished making changes, you must remember to call C<mktunes.pl>
to ensure those changes are written to the iTunes database and are visible to
your iPod.

=over 4

=item --rename=KEY=VAL

Change tags on found songs. Example: --rename="ARTIST=Foo Bar"

=item --artwork=FILE

Set FILE as Cover for found files.  

The internal image format is model specific, so you should give GNUpod a
hint about the image format it should use in your GNUpod configuration file
(found at F<~/.gnupodrc> or
F<$IPOD_MOUNTPOINT/iPod_Control/.gnupod/gnupodrc>).  For example C<model =
video> for video-capable iPods, C<model = nano> for first and second
generation nanos, C<model = nano_3g> for late 2007 nanos and 
C<model = nano_4g> for late 2008 nano models.

=back

=head2 Deleting songs

=over 4

=item --delete

REMOVE (!) matched songs.  This removes the songs immediately, but you'll
still have to call C<mktunes.pl> to make the appropriate changes to the
iTunes database.

=back

=head1 EDITING GNUtunesDB.xml DIRECTLY

It is possible to perform most of the changes you might perform with
C<gnupod_search.pl> directly into the
F<iPod_Control/.gnupod/GNUtunesDB.xml> file.  It is recommended that if you
intend to do this, that you take a backup of the file first.

B<IMPORTANT>: After making any changes to the F<GNUtunesDB.xml> (whether
directly) or vial C<gnupod_search.pl> you must call C<mktunes.pl> to ensure
those changes are also reflected in the iTunes database.

=head1 EXAMPLES

	# Mount the iPod
	mount /mnt/ipod

	# Sync changes made by other tools (such as iTunes)
	# only necessary if you are using other tools in addition to these
	tunes2pod.pl -m /mnt/ipod

	# search for all songs by the artist called 'Schlummiguch'
	gnupod_search.pl -m /mnt/ipod --artist="Schlummiguch"

	# search for all songs in the album 'Seiken Densetsu'
	gnupod_search.pl -m /mnt/ipod --album="Seiken Densetsu"

	# search for all songs whose ids contain the number 4
	gnupod_search.pl -m /mnt/ipod --id=4

	# search for the songs with id 4 (it's a regular expression)
	gnupod_search.pl -m /mnt/ipod --id="^4$"

	# search for all the songs whose rating is 3 - 5 stars and whose
	# Artist contains "Amos"
	gnupod_search.pl -m /mnt/ipod --rating="60-100" --artist="Amos"

	# search for all the songs whose play count is less than 3
	gnupod_search.pl -m /mnt/ipod --playcount<3

	# Change artist and rating for all songs by Alfred Neumann
	# Sets artist to "John Doe" and rating to 5 stars (5 x 20 = 100)
	gnupod_search.pl --artist="Alfred Neumann" --rename="artist=John Doe" --rename="rating=100"

	# Set cover-artwork for all songs by "Amos" to be "amos.jpg"
	gnupod_search.pl --artist="Amos" --artwork="amos.jpg"

	# Boost the volume for all the songs on album by 50%
	gnupod_search --album="Seiken Densetsu" --rename="volume=50"

	# Cut the volume for all the songs on album by -10%
	gnupod_search --album="Seiken Densetsu" --rename="volume=-10"

	# Delete all songs by the artist called 'Schlumminguch'
	gnupod_search.pl -m /mnt/ipod --artist="Schlummiguch" --delete

	# Record the changes to the iTunes database (this is essential)
	mktunes.pl -m /mnt/ipod

	# Unmount and go
	umount /mnt/ipod

###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Written by Eric C. Cooper <ecc at cmu dot edu> - Contributed to the 'old' GNUpod (< 0.9)

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

Heinrich Langos <henrik-gnupod at prak dot org> - Some patches

###___PODINSERT man/footer.pod___###
