###__PERLBIN__###
#  Copyright (C) 2002-2004 Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://www.gnu.org/software/gnupod/
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;
use vars qw(%opts @keeplist);

print "gnupod_search.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "version", "help|h", "mount|m=s", "artist|a=s",
                   "album|l=s", "title|t=s", "id|i=s",
                   "view=s","genre|g=s", "match-once|o", "delete", "RMME|d");
GNUpod::FooBar::GetConfig(\%opts, {view=>'s', mount=>'s', 'match-once'=>'b'}, "gnupod_search");

usage() if $opts{help};
version() if $opts{version};
usage("\n-d was removed, use '--delete'\n") if $opts{RMME};
$opts{view} ||= 'ialt'; #Default view

go();

####################################################
# Worker
sub go {
 my $con = GNUpod::FooBar::connect(\%opts);
 usage($con->{status}."\n") if $con->{status};

 pview(undef,1);
 
 GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");
 #XML::Parser finished, write new file
 GNUpod::XMLhelper::writexml($con) if $opts{delete};


}

#############################################
# Eventhandler for FILE items
sub newfile {
 my($el) =  @_;
my $matched;
                      # 2 = mount + view (both are ALWAYS set)
my $ntm = keys(%opts)-2-$opts{'match-once'}-$opts{delete};

  foreach my $opx (keys(%opts)) {
   next if $opx =~ /mount|match-once|delete|view/; #Skip this
   if($el->{file}->{$opx} =~ /$opts{$opx}/i) {
    $matched++;
   }
  }

  if(($opts{'match-once'} && $matched) || $ntm == $matched) {
    pview($el->{file},undef,$opts{delete});
    unlink(GNUpod::XMLhelper::realpath($opts{mount},$el->{file}->{path}))
    or warn "[!!] Remove failed: $!\n" if $opts{delete};
  }
  elsif($opts{delete}) { #Did not match, keep this item..
   GNUpod::XMLhelper::mkfile($el);
   $keeplist[$el->{file}->{id}] = 1;
  }
}

############################################
# Eventhandler for PLAYLIST items
sub newpl {
 return unless $opts{delete}; #Just searching
 my ($el, $name, $plt) = @_;
 if($plt eq "pl" && ref($el->{add}) eq "HASH") { #Add action
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
 $qh{t}{k} = $orf->{title};                     $qh{t}{s} = "TITLE";
 $qh{a}{k} = $orf->{artist};                    $qh{a}{s} = "ARTIST";
 $qh{r}{k} = $orf->{rating};    $qh{r}{w} = 4;  $qh{r}{s} = "RTNG";
 $qh{p}{k} = $orf->{path};      $qh{p}{w} = 96; $qh{p}{s} = "PATH";
 $qh{l}{k} = $orf->{album};                     $qh{l}{s} = "ALBUM";
 $qh{g}{k} = $orf->{genre};                     $qh{g}{s} = "GENRE";
 $qh{c}{k} = $orf->{playcount}; $qh{c}{w} = 4;  $qh{c}{s} = "CNT";
 $qh{i}{k} = $orf->{id};        $qh{i}{w} = 4;  $qh{i}{s} = "ID";
 
 #Prepare view
 
 my $ll = 0; #LineLength
  foreach(split(//,$opts{view})) {
      print "|" if $ll;
      my $cs = $qh{$_}{k};           #CurrentString
         $cs = $qh{$_}{s} if $xhead; #Replace it if HEAD is needed
 
      my $cl = $qh{$_}{w}||32;       #Current length
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
   -o, --match-once        Search doesn't need to match multiple times (eg. -a & -l)
       --delete            REMOVE (!) matched songs
       --view=ialt         Modify output, default=ialt
                            t = title    a = artist   r = rating      p = path
                            l = album    g = genre    c = playcount   i = id

Note: Argument for title/artist/album.. has to be UTF8 encoded, *not* latin1!

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}


sub version {
die << "EOF";
gnupod_search.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2004

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

