package GNUpod::FooBar;
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
use Digest::MD5;
use GNUpod::iTunesDB;

#####################################################################
# Get paths / files
sub connect {
 my($opth) = @_;
 my $rr = ();
  

 $rr->{status} = "No mountpoint defined / missing in and out file";
unless(!$opth->{mount} && (!$opth->{itunes} || !$opth->{xml})) {
  $rr->{itunesdb}   = $opth->{itunes} || $opth->{mount}."/iPod_Control/iTunes/iTunesDB";
  $rr->{etc}        = $opth->{mount}."/iPod_Control/.gnupod";
  $rr->{xml}        = $opth->{xml} || $opth->{mount}."/iPod_Control/.gnupod/GNUtunesDB";
  $rr->{mountpoint} = $opth->{mount};
  $rr->{onthego}    = "$rr->{mountpoint}/iPod_Control/iTunes/OTGPlaylistInfo";
  $rr->{status}     = undef;


#1. Check if we have to write a new GNUtunesDB with the content of the iTunesDB
 handle_it_sync($rr) unless $opth->{_no_sync}; 
#2. Try to parse the OTG list (if found..) and ReWrite the XMLdoc (again?!)
 handle_otg_sync($rr) if !$opth->{_no_sync} && int(GNUpod::iTunesDB::readOTG($rr->{onthego}));
}

 return $rr
}


######################################################################
# Get int value
sub shx2int {
 my($shx) = @_;
 my $buff = undef;
   foreach(split(//,$shx)) {
    $buff = sprintf("%02X",ord($_)).$buff;
   }
  return hex($buff);
}

######################################################################
# Returns '1' if we MAY have to sync..
sub havetosync {
 my($rr) = @_;
 if(-r "$rr->{etc}/.itunesdb_md5") {
   my $itmd = getmd5($rr->{itunesdb});
   open(MDX,"$rr->{etc}/.itunesdb_md5");
   my $otmd = <MDX>;
   chomp($otmd);
   close(MDX);
   return 1 if $otmd ne $itmd;
  }
  return undef;
}

######################################################################
# Check up to date status
sub handle_it_sync {
 my($rr) = @_;
  if(havetosync($rr)) {
    warn "*** GNUtunesDB outdated, running tunes2pod.pl to fix it...\n";
    $ENV{IPOD_MOUNTPOINT} = $rr->{mountpoint};
    if(system("tunes2pod.pl --force > /dev/null")) {
     die "tunes2pod.pl died, can't continue!\n";
    }
    warn "*** done!\n";
  }
}

######################################################################
# Call gnupod_otgsync to update OnTheGo lists
sub handle_otg_sync {
 my($rr) = @_;
 $ENV{IPOD_MOUNTPOINT} = $rr->{mountpoint};
 if(system("gnupod_otgsync.pl --top4secret")) {
  warn "gnupod_otgsync.pl failed. On-The-Go playlist *NOT* Synced!\n";
 }
 else {
  print "> Synced On-The-Go playlist\n";
 }
}

######################################################################
# Call this to set GNUtunesDB <-> iTuneDB 'in-sync'
sub setsync {
 my($rr) = @_;
 
 die "FATAL: Unable to read iTunesDB\n" unless (-r $rr->{itunesdb});
 #Write the file with md5sum content
 open(MDX,">$rr->{etc}/.itunesdb_md5") or die "Can't write md5-sum, $!\n";
  print MDX getmd5($rr->{itunesdb})."\n";
 close(MDX);
 
}

######################################################################
# Get the MD5 sum of a file
sub getmd5 {
 my($file) = @_;
   open(UTDATE, $file) or die "** FATAL: Unable to open $file, $!\n";
   binmode(UTDATE);
   my $md5 = Digest::MD5->new->addfile(*UTDATE)->hexdigest;
   close(UTDATE);
 return $md5;
}


1;
