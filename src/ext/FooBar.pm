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
 $rr->{bindir} = ($0 =~ m%^(.+)/%)[0] || ".";
warn "Runtimee: $rr->{bindir}\n";
unless(!$opth->{mount} && (!$opth->{itunes} || !$opth->{xml})) {
  $rr->{itunesdb}   = $opth->{itunes} || $opth->{mount}."/iPod_Control/iTunes/iTunesDB";
  $rr->{etc}        = $opth->{mount}."/iPod_Control/.gnupod";
  $rr->{xml}        = $opth->{xml} || $opth->{mount}."/iPod_Control/.gnupod/GNUtunesDB";
  $rr->{mountpoint} = $opth->{mount};
  $rr->{onthego}    = "$rr->{mountpoint}/iPod_Control/iTunes/OTGPlaylistInfo";
  $rr->{playcounts} = "$rr->{mountpoint}/iPod_Control/iTunes/Play Counts";
  $rr->{status}     = undef;

 #Do an iTunesDB Sync if not disabled and needed
  do_itbsync($rr) if(!$opth->{_no_it_sync} && !$opth->{_no_sync} && _itb_needs_sync($rr));
 
 #Do an OTG Sync if not disabled and needed
  do_otgsync($rr) if(!$opth->{_no_otg_sync} && !$opth->{_no_sync} && _otg_needs_sync($rr));
}

 return $rr
}

#######################################################################
# Call tunes2pod
sub do_itbsync {
 my($con) = @_;

my $XBIN = "$con->{bindir}/tunes2pod.pl";

if(-x $XBIN) {
    my $OLDENV = $ENV{IPOD_MOUNTPOINT};
    $ENV{IPOD_MOUNTPOINT} = $con->{mountpoint};
   print "> GNUtunesDB sync needed...\n";
    if(system("$XBIN > /dev/null")) {
      die "Unexpected die of $XBIN\n
      You can disable auto-sanc (=autorun of $XBIN)
      by removing '$con->{etc}/.itunesdb_md5'\n";
    }
    
    $ENV{IPOD_MOUNTPOINT} = $OLDENV;
  print "> GNUtunesDB synced\n";
}
else {
 warn "FooBar.pm: Could not execute $XBIN, autosync SKIPPED!\n";
 warn "Looks like GNUpod isn't installed correct! did you run 'make install?'\n";
}

}

######################################################################
# Call gnupod_otgsync.pl
sub do_otgsync {
 my($con) = @_;
 
my $XBIN = "$con->{bindir}/gnupod_otgsync.pl";

if(-x $XBIN) {
     my $OLDENV = $ENV{IPOD_MOUNTPOINT}
     $ENV{IPOD_MOUNTPOINT} = $con->{mountpoint};
     print "> On-The-Go data sync needed...\n";
     if(system("$XBIN --top4secret")) {
      warn "** UUUPS **: $XBIN died! On-The-Go list lost, sorry!\n";
     }
     else {
      print "> On-The-Go data synced\n";
     }
  
   $ENV{IPOD_MOUNTPOINT} = $OLDENV;
}
else {
 warn "FooBar.pm: Could not execute $XBIN, autosync SKIPPED!\n";
 warn "Looks like GNUpod isn't installed correct! did you run 'make install?'\n";
} 
 

}


######################################################################
# Get int value (Network format)
sub shx2int {
 my($shx) = @_;
 my $buff = undef;
   foreach(split(//,$shx)) {
    $buff = sprintf("%02X",ord($_)).$buff;
   }
  return hex($buff);
}

######################################################################
# Get int value (x86)
sub shx2_x86_int {
 my($shx) = @_;
 my $buff = undef;
  foreach(split(//, $shx)) {
    $buff .= sprintf("%02X", ord($_));
  }
 return hex($buff);
}


######################################################################
# Returns '1' if we MAY have to sync..
sub _itb_needs_sync {
 my($rr) = @_;
warn "debug: havetosync call ($$)\n";
 if(-r "$rr->{etc}/.itunesdb_md5" && -r $rr->{itunesdb}) {
   my $itmd = getmd5($rr->{itunesdb});
   my $otmd = getmd5line("$rr->{etc}/.itunesdb_md5");
   return 1 if $otmd ne $itmd;
  }
  return undef;
}


######################################################################
# Checks if we need to do an OTG-Sync
sub _otg_needs_sync {
 my($rr) = @_;

 #OTG Sync needed
 return 1 if(GNUpod::iTunesDB::readOTG($rr->{onthego}));
 
 if(-e $rr->{playcounts}) { #PlayCounts file exists..
  if(-r "$rr->{etc}/.playcounts_md5") { #We got a md5 hash
   my $plmd = getmd5line("$rr->{etc}/.playcounts_md5");
   #MD5 is the same
   return 0 if $plmd eq getmd5($rr->{playcounts});
  }
  #Playcounts file, but no md5, parse it..
  return 1;
 }

 #No OTG and no PLC file, no sync needed
 return 0;
}


######################################################################
# Getmd5line
sub getmd5line {
 my($file) = @_;
   open(MDX, "$file") || warn "Could not open $file, md5 will fail!\n";
    my $plmd = <MDX>;
   close(MDX);
   chomp($plmd);
   return $plmd;
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
 
#We also create an MD5 sum of the playcounts file
 if(-r $rr->{playcounts}) { #Test this, because getmd5 would die
  open(MDX,">$rr->{etc}/.playcounts_md5") or die "Can't write pc-md5-sum, $!\n";
   print MDX getmd5($rr->{playcounts});
  close(MDX);
 }
 
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
