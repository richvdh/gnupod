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
use vars qw(%opts);

print "gnupod_search.pl Version 0.91 (C) 2002-2003 Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "help|h", "mount|m=s", "artist|a=s",
                   "album|l=s", "title|t=s", "id|i=s",
		   "genre|g=s", "once|o", "delete|d");

usage() if $opts{help};

go();

####################################################
# Worker
sub go {
 my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);
 usage($stat."\n") if $stat;
 
 my ($xmldoc) = GNUpod::XMLhelper::parsexml($xml, cleanit=>$opts{restore}) or usage("Failed to parse $xml\n");

 usage("Could not open $xml , did you run gnupod_INIT.pl ?\n") unless $xmldoc;



my ($href) = GNUpod::XMLhelper::build_quickhash($xmldoc);

my $ntm = keys(%opts)-1-$opts{once}-$opts{delete}; #-2 because we skip 'mount|once' .. dirty hack

usage("Nothing to do!\n") unless $ntm;

my @nomatch = ();
my %present = ();
## Start!


print "ID      : ARTIST / ALBUM / TITLE\n";
print "================================\n";
    foreach my $xlr (keys(%{$href})) {
       my $ch = $href->{$xlr};
       #We got now the hash of the current item..       
       #Let's loop!
       # %opts will *never* be bigger than
       # our hashes...
       my $matched = 0;
       foreach my $element (keys(%opts)) {
        next if $element =~ /mount|once|delete/; #Skip this..
          if($ch->{$element} =~ /$opts{$element}/i) {
	   $matched++;
	    if($opts{once} || $matched == $ntm) {
	        
		#Remove the file if --delete is present
		if($opts{delete}) {
		  unlink GNUpod::XMLhelper::realpath($opts{mount},$ch->{path}) or
		  warn "*** Could not unlink ".$ch->{path}.", but item is removed from XML-Doc !\n";
	          print "[RM]";
		}
		
		print " " x (7-(length($ch->{id}))-$opts{delete});
	        print $ch->{id}." ";
		print ": ".$ch->{artist}." / ".$ch->{album}." / ".$ch->{title}."\n";
	      last; #We matched.. no need to loop again (and print out duplicates)
	    }
	  }
	  elsif($opts{delete}){ #We have to delete: hold good items
	   push(@nomatch, $ch);
	   $present{$ch->{id}}++; #We found this item.. merk it ;)
	  }
       }
    }
    

## FIXME:: Rewrite the delete part.. it's slow and very ugly    
if($opts{delete}) { #Clean doctree and rebuild..
 ## Clean the old file hash..
  foreach my $gp (@{$xmldoc->{gnuPod}}) {
   foreach my $fx (@{$gp->{files}}) {
    $fx = undef;
   }
#Now cleanup all playlists here
   foreach my $pl (@{$gp->{playlist}}) {
   next unless ref($pl->{add}) eq "ARRAY";
 
my @hpl = (); #HoldPlayList
     foreach my $pli (@{$pl->{add}}) {
	#No id part or on our holdlist.. damd bug!
	if(!defined($pli->{id}) || keys(%$pli) != 1 || $present{$pli->{id}}) { 
	 push(@hpl, $pli);
	}
     }
     @{$pl->{add}} = @hpl;
   }
  }
 @{$xmldoc->{gnuPod}->[0]->{files}->[0]->{file}} = @nomatch;
GNUpod::XMLhelper::write_xml($xml,$xmldoc);
}

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
   -d, --delete           : REMOVE (!) matched songs
EOF
}





