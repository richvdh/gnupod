#!/usr/bin/perl
#  Copyright (C) 2002-2003 Adrian Ulrich <pab at blinkenlights.ch>
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

print "gnupod_search.pl Version 0.91 (C) 2002-2003 Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s", "artist|a=s",
                   "album|l=s", "title|t=s", "id|i=s",
        		   "genre|g=s", "once|o", "delete", "RMME|d");

usage() if $opts{help};

usage("-d was removed, use '--delete'\n") if $opts{RMME};

go();

####################################################
# Worker
sub go {
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);
 usage($stat."\n") if $stat;


print "ID        : ARTIST / ALBUM / TITLE\n";
print "==================================\n"; 
GNUpod::XMLhelper::doxml($xml) or usage("Failed to parse $xml\n");
GNUpod::XMLhelper::writexml($xml) if $opts{delete};


}

#############################################
# Eventhandler for FILE items
sub newfile {
 my($el) =  @_;
my $matched;
my $ntm = keys(%opts)-1-$opts{once}-$opts{delete};

  foreach my $opx (keys(%opts)) {
   next if $opx =~ /mount|once|delete/; #Skip this
   if($el->{file}->{$opx} =~ /$opts{$opx}/i) {
    $matched++;
   }
  }

  if(($opts{once} && $matched) || $ntm == $matched) {
    print "[RM] " if $opts{delete};
    print "$el->{file}->{id}";
    print " " x (10-length($el->{file}->{id})-($opts{delete}*5));
    print ": $el->{file}->{artist} / ";
    print "$el->{file}->{album} / ";
    print "$el->{file}->{title}\n";
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
 my ($el, $name) = @_;
 if(ref($el->{add}) eq "HASH") { #Add action
  if(defined($el->{add}->{id}) && int(keys(%{$el->{add}})) == 1) { #Only id
   return unless($keeplist[$el->{add}->{id}]); #ID not on keeplist. dropt it
  }
 }

  GNUpod::XMLhelper::mkfile($el,{plname=>$name});
}

###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_search.pl [-h] [-m directory | -x GNUtunesDB] File1 File2 ...

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -t, --title=TITLE      : print songs by Title
   -a, --artist=ARTIST    : print songs by Artist
   -l, --album=ALBUM      : print songs by Album
   -i, --id=ID            : print songs by ID
   -g, --genre=GENRE      : print songs by Genre
   -o, --once             : Search doesn't need to match multiple times (eg. -a & -l)
       --delete           : REMOVE (!) matched songs
EOF
}



