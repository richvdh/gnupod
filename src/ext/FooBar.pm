package GNUpod::FooBar;
#  Copyright (C) 2002-2005 Adrian Ulrich <pab at blinkenlights.ch>
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
use File::Glob ':glob';
use GNUpod::iTunesDB;

use constant MACTIME => 2082844800; #Mac EPOCH offset


#####################################################################
# Get paths / files
sub connect {
 my($opth) = @_;
 my $rr = ();
  

 $rr->{status} = "No mountpoint defined";
 $rr->{bindir} = ($0 =~ m%^(.+)/%)[0] || ".";

if(-d $opth->{mount}) {
  $rr->{mountpoint}     = $opth->{mount};
  $rr->{etc}            = $opth->{mount}."/iPod_Control/.gnupod";

  $rr->{xml}            = $opth->{mount}."/iPod_Control/.gnupod/GNUtunesDB";
  #It can also be called GNUtunesDB.xml
  $rr->{xml}            = $rr->{xml}.".xml" if !(-e $rr->{xml});
  $rr->{itunesdb}       = $opth->{mount}."/iPod_Control/iTunes/iTunesDB";
  $rr->{itunessd}       = $opth->{mount}."/iPod_Control/iTunes/iTunesSD";
  $rr->{shufflestat}    = $opth->{mount}."/iPod_Control/iTunes/iTunesShuffle";
  $rr->{playcounts}     = "$rr->{mountpoint}/iPod_Control/iTunes/Play Counts";
  $rr->{itunesdb_md5}   = "$rr->{etc}/.itunesdb_md5";
  $rr->{onthego_invalid}  = "$rr->{etc}/.onthego_invalid";
  $rr->{lastfm_queue}   = "$rr->{etc}/lastfmqueue.txt";
  $rr->{onthego}        = "$rr->{mountpoint}/iPod_Control/iTunes/OTGPlaylist*";
  $rr->{status}         = undef;

	$rr->{tzdiff} =         GNUpod::iTunesDB::getTimezone($opth->{mount}."/iPod_Control/Device/Preferences");
  _check_casesensitive($rr->{mountpoint}); #Check if somebody mounted the iPod caseSensitive
      
 #Do an iTunesDB Sync if not disabled and needed
  do_itbsync($rr) if(!$opth->{_no_it_sync} && !$opth->{_no_sync} && _itb_needs_sync($rr));
 
 #Do an OTG Sync if not disabled and needed
  do_otgsync($rr) if(!$opth->{_no_otg_sync} && !$opth->{_no_sync} && (_otg_needs_sync($rr) || -e $rr->{lastfm_queue}))
}
elsif($opth->{mount}) {
 $rr->{status} = "$opth->{mount} is not a directory";
}

 return $rr
}

#######################################################################
# Check if someone mounted the iPod CaseSensitive
sub _check_casesensitive {
 my($target) = @_;
 
 if(open(CSTEST,">$target/csTeSt")) {
   my $inode_a = (stat("$target/csTeSt"))[1]; #Get inode of just-creaded file
   my $inode_b = (stat("$target/CStEsT"))[1]; #Get inode of another file..
   close(CSTEST) or die "FATAL: Could not close CSTEST FD ($target/csTeST) : $!\n";
   unlink("$target/csTeSt"); #Boom!
  
   if($inode_a != $inode_b) { #Whops, different inodes? -> case sensitive fs
     #Nerv the user
     warn "Warning: $target seems to be mounted *CASE SENSITIVE*\n";
     warn "         Mounting VFAT like this is a very bad idea!\n";
     warn "         Please mount the Filesystem CASE *IN*SENSITIVE\n";
     warn "         (use 'mount ... -o check=r' for VFAT)\n";
     warn "         [Ignore this message if $target isn't a\n";
     warn "          VFAT Filesystem (like HFS+) ]\n";
   }
  
 }
 else {
   warn "warning: Could not write to $target, iPod mounted read-only? ($!)\n";
 }
}

#######################################################################
# Call mktunes.pl
sub do_automktunes {
	my($con) = @_;
	my $XBIN = "$con->{bindir}/mktunes.pl";
	if(-x $XBIN) {
		{
			local  $ENV{IPOD_MOUNTPOINT} = $con->{mountpoint};
			if(system("$XBIN > /dev/null")) {
				die "Unexpected die of $XBIN\n";
			}
		}
	}
	else {
		warn "FooBar.pm: Could not execute $XBIN, automktunes SKIPPED!\n";
		warn "Looks like GNUpod isn't installed correct! did you run 'make install' ?\n";
	}
	
}

#######################################################################
# Call tunes2pod
sub do_itbsync {
 my($con) = @_;

my $XBIN = "$con->{bindir}/tunes2pod.pl";

if(-x $XBIN) {
  {
   local  $ENV{IPOD_MOUNTPOINT} = $con->{mountpoint};
   print "> GNUtunesDB sync needed...\n";
    if(system("$XBIN > /dev/null")) {
      die "Unexpected die of $XBIN\n
      You can disable auto-sync (=autorun of $XBIN)
      by removing '$con->{etc}/.itunesdb_md5'\n";
    } 
  }
  print "> GNUtunesDB synced\n";
}
else {
 warn "FooBar.pm: Could not execute $XBIN, autosync SKIPPED!\n";
 warn "Looks like GNUpod isn't installed correct! did you run 'make install' ?\n";
}

}

######################################################################
# Call gnupod_otgsync.pl
sub do_otgsync {
 my($con) = @_;
 
my $XBIN = "$con->{bindir}/gnupod_otgsync.pl";

if(-x $XBIN) {
  {
     local $ENV{IPOD_MOUNTPOINT} = $con->{mountpoint};
     print "> On-The-Go data sync needed...\n";
     if(system("$XBIN --top4secret")) {
      warn "** UUUPS **: $XBIN died! On-The-Go list lost, sorry!\n";
     }
     else {
      print "> On-The-Go data synced\n";
     }
  
  }
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

 if(-r $rr->{itunesdb_md5} && -r $rr->{itunesdb}) {
   my $itmd = getmd5($rr->{itunesdb});
   my $otmd = getmd5line($rr->{itunesdb_md5});
   return 1 if $otmd ne $itmd;
  }
  return undef;
}


######################################################################
# Checks if we need to do an OTG-Sync
sub _otg_needs_sync {
	my($rr) = @_;
	#warn "debug: otgsync need? (request from $$)\n";
	#OTG Sync needed
	foreach my $otgf (bsd_glob($rr->{onthego},GLOB_NOSORT)) {
		return 1 if ( -e $otgf && -s $otgf > 0 );
	}

	if(-e $rr->{playcounts}) { #PlayCounts file exists..
		return 1;
	}
	
	#No OTG and no PLC file, no sync needed
	return 0;
}


######################################################################
# Check for broken onTheGo data (= GNUtunesDB <-> iTunesDB out of sync)
sub _otgdata_broken {
 my($rr) = @_;
 return (-e $rr->{onthego_invalid});
}

######################################################################
# Set otgdata synched
sub setvalid_otgdata {
 my($rr) = @_;
 return undef unless -e $rr->{onthego_invalid};
 unlink($rr->{onthego_invalid});
}
######################################################################
# Set otgdata synched
sub setINvalid_otgdata {
 my($rr) = @_;
 open(OTGINVALID, ">$rr->{onthego_invalid}") or die "Can't write $rr->{onthego_invalid}\n";
  print OTGINVALID undef;
 close(OTGINVALID);
 return undef;
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
 setsync_itunesdb($rr);
 setsync_playcounts($rr);
 setsync_otg($rr);
 setvalid_otgdata($rr);
}

######################################################################
# Remove the Shuffle Database of the iPodShuffle
sub wipe_shufflestat {
	my($rr) = @_;
	if(-e $rr->{shufflestat}) {
		unlink($rr->{shufflestat}) || warn "Could not unlink '$rr->{shufflestat}', $!\n";
	}
}

######################################################################
# SetSync for onthego
sub setsync_otg {
my($rr) = @_;


 if( !(bsd_glob($rr->{onthego},GLOB_NOSORT)) || unlink(bsd_glob(($rr->{onthego},GLOB_NOSORT)) )) {
  return undef;
 }

warn "Could not setsync for onthego\n";
return 1;
}

######################################################################
# Set only playcounts in sync
sub setsync_playcounts {
my($rr) = @_;

if( !(-e $rr->{playcounts}) || unlink($rr->{playcounts})) {
 return undef;
}

 warn "Can't set sync for playcounts to true: file not found\n";
 return 1;
}

######################################################################
# Set only itunesdb sync
sub setsync_itunesdb {
my($rr) = @_;
 if(-r $rr->{itunesdb}) {
 #Write the file with md5sum content
 open(MDX,">$rr->{itunesdb_md5}") or die "Can't write md5-sum, $!\n";
  print MDX getmd5($rr->{itunesdb})."\n";
 close(MDX);
 return undef;
 }
 warn "Can't set sync for iTunesDB to true: file not found\n";
 return 1;
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



########################################################################
# Parse configuration
sub GetConfig {
 my($getopts, $doset, $name) = @_;

  my($topic,$val,$optarget);
  
  foreach my $filerc ( ("$ENV{HOME}/.gnupodrc", "$getopts->{mount}/iPod_Control/.gnupod/gnupodrc") ) {
    open(RCFILE, $filerc) or next;
     while (my $line = <RCFILE>) {
      chomp($line);
      next if !$line or $line =~ /^#/;
      
      #Ok, line is not a comment and has some content, read it..
      unless(($topic,$val) = $line =~ /^(\S+)\s*=\s*(.+)$/) {
       warn "warning: Invalid line '$line' found in $filerc\n";
       next;
      }
      
      #We matched and got $topic + $val, check it $topic has a
      #specific target (like 'mktunes.volume')
      if($topic =~ /^([^.]+)\.(.+)/) {
       $optarget = $1;
       $topic    = $2;
      }
      else { #No target found
       $optarget = undef;
      }

  #    warn "### PARSE($line): *$topic* -> *$val*\n";
  #    warn "### $topic with target $optarget\n";
      
         if ($optarget&&$name&&$name ne $optarget) { next}
      elsif ($getopts->{$topic})      { next } #this is a dup 
      elsif ($doset->{$topic} eq "s") { $getopts->{$topic} = $val }
      elsif ($doset->{$topic} eq "i") { $getopts->{$topic} = int($val) }
      elsif ($doset->{$topic} eq "b") { $getopts->{$topic} = 1 if($val && $val ne "no") }
     }
     close(RCFILE);
 #    warn "** Parser finished $filerc\n";
  }
  
 # foreach(keys(%$getopts)) {
 #  warn "CONF: $_ - $getopts->{$_}\n";
 # }
  
  
  return 1;
}

#############################################
# Get Unique path
sub get_u_path {
 my($prefix, $ext) = @_;
 my $dst = undef;
 while($dst = sprintf("%s_%d_%d.$ext",$prefix, int(time()), int(rand(99999)))) {
  last unless -e $dst;
 }
 return $dst;
}


1;
