package GNUpod::FooBar;
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
use Digest::MD5;
use File::Glob ':glob';
use GNUpod::iTunesDB;

use constant MACTIME => 2082844800; #Mac EPOCH offset


#####################################################################
# Get paths / files
sub connect {
	my($opth) = @_;
	my $rr = ();
	my $model  = lc($opth->{model});
	$model  =~ tr/a-z0-9_//cd; # relax

	$rr->{status}  = "No mountpoint defined";
	$rr->{bindir}  = ($0 =~ m%^(.+)/%)[0] || ".";
	$rr->{iroot}   = ($model eq 'iphone' ? 'iTunes_Control' : 'iPod_Control' );
	
	if(-d $opth->{mount}) {
		$rr->{mountpoint}     = $opth->{mount};
		$rr->{rootdir}        = $opth->{mount}."/".$rr->{iroot};
		$rr->{etc}            = $rr->{rootdir}."/.gnupod";
		$rr->{xml}            = $rr->{rootdir}."/.gnupod/GNUtunesDB";
		#It can also be called GNUtunesDB.xml
		$rr->{xml}            = $rr->{xml}.".xml" if !(-e $rr->{xml});
		$rr->{artworkdir}     = $rr->{rootdir}."/Artwork";
		$rr->{musicdir}       = $rr->{rootdir}."/Music";
		$rr->{itunesdir}      = $rr->{rootdir}."/iTunes";
		$rr->{artworkdb}      = $rr->{artworkdir}."/ArtworkDB";
		$rr->{itunesdb}       = $rr->{itunesdir}."/iTunesDB";
		$rr->{itunessd}       = $rr->{itunesdir}."/iTunesSD";
		$rr->{shufflestat}    = $rr->{itunesdir}."/iTunesShuffle";
		$rr->{playcounts}     = $rr->{itunesdir}."/Play Counts";
		$rr->{onthego}        = $rr->{itunesdir}."/OTGPlaylist*";
		$rr->{sysinfo}        = $rr->{rootdir}."/Device/SysInfo";
		$rr->{extsysinfo}     = $rr->{rootdir}."/Device/SysInfoExtended";
		$rr->{itunesdb_md5}   = "$rr->{etc}/.itunesdb_md5";
		$rr->{onthego_invalid}  = "$rr->{etc}/.onthego_invalid";
		$rr->{status}         = undef;
		$rr->{_no_cstest}     = $opth->{_no_cstest};
		
		if(!$rr->{_no_cstest}++) {
			_check_casesensitive($rr->{mountpoint}); #Check if somebody mounted the iPod caseSensitive
		}
		
		$rr->{autotest}       = _check_autotest_mode($rr->{mountpoint});

		#Do an iTunesDB Sync if not disabled and needed
		StartItunesDBSync($rr) if(!$opth->{_no_it_sync} &&  !$opth->{_no_sync} && ItunesDBNeedsSync($rr));
		#Do an OTG Sync if not disabled and needed
		StartOnTheGoSync($rr)  if(!$opth->{_no_otg_sync} && !$opth->{_no_sync} && OnTheGoNeedsSync($rr) );
	}
	elsif($opth->{mount}) {
		$rr->{status} = "$opth->{mount} is not a directory";
	}
return $rr
}

#######################################################################
# Check if we are running autotests and act accordingly
sub _check_autotest_mode {
	my($target) = @_;

	if (-e "$target/autotest") {
		srand(42);
		return 1;
	} else {
		return 0;
	}
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
		
		if(!defined($inode_b) || ($inode_a != $inode_b)) { #Whops, different inodes? -> case sensitive fs
			#Nerv the user
			warn "$0: Warning: $target is mounted case sensitive, that's bad:\n";
			warn "".(" " x length($0))."  FAT32-iPods should be mounted case in-sensitive!\n";
			warn "".(" " x length($0))."  (try 'mount ... -o check=relaxed')\n";
		}
	
	}
	else {
		die "Could not write to $target, iPod mounted read-only? ($!)\n";
	}
}

#######################################################################
# Call mktunes.pl
sub StartAutoMkTunes {
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
sub StartItunesDBSync {
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
sub StartOnTheGoSync {
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
	return unpack("V",pack("H16",unpack("H16",$shx)));
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
sub ItunesDBNeedsSync {
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
sub OnTheGoNeedsSync {
	my($rr) = @_;
	
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
# Returns true if we can't use OnTheGoData now
sub OnTheGoDataIsInvalid {
 my($rr) = @_;
 return (-e $rr->{onthego_invalid});
}




######################################################################
# Call this to set GNUtunesDB <-> iTuneDB 'in-sync'
sub SetEverythingAsInSync {
	my($rr) = @_;
	SetItunesDBAsInSync($rr);
	SetPlayCountsAsInSync($rr);
	SetOnTheGoAsInSync($rr);
	SetOnTheGoAsValid($rr);
}

######################################################################
# Remove the Shuffle Database of the iPodShuffle
sub WipeShuffleStat {
	my($rr) = @_;
	if(-e $rr->{shufflestat}) {
		unlink($rr->{shufflestat}) || warn "Could not unlink '$rr->{shufflestat}', $!\n";
	}
}

######################################################################
# SetSync for onthego
sub SetOnTheGoAsInSync {
my($rr) = @_;
	
	if( !(bsd_glob($rr->{onthego},GLOB_NOSORT)) || unlink(bsd_glob(($rr->{onthego},GLOB_NOSORT)) )) {
		return undef;
	}
	else {
		warn "Could not setsync for onthego\n";
		return 1;
	}
}

######################################################################
# Set only playcounts in sync
sub SetPlayCountsAsInSync {
my($rr) = @_;

if( !(-e $rr->{playcounts}) || unlink($rr->{playcounts})) {
 return undef;
}

 warn "Can't set sync for playcounts to true: file not found\n";
 return 1;
}

######################################################################
# Set only itunesdb sync
sub SetItunesDBAsInSync {
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
# Set otgdata synched
sub SetOnTheGoAsValid {
 my($rr) = @_;
 return undef unless -e $rr->{onthego_invalid};
 unlink($rr->{onthego_invalid});
}

######################################################################
# Set otgdata non-synched
sub SetOnTheGoAsInvalid {
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
# Get the MD5 sum of a file
sub getmd5 {
	my($file) = @_;
	open(UTDATE, $file) or die "** FATAL: Unable to open $file, $!\n";
	binmode(UTDATE);
	my $md5 = Digest::MD5->new->addfile(*UTDATE)->hexdigest;
	close(UTDATE);
	return $md5;
}

####################################################################
# Seek and destroy ;-)
sub SeekFix {
	my($fd,$at,$string) = @_;
	my $now = tell($fd);
	seek($fd,$at,0) or die "Unable to seek to $at in $fd : $!\n";
	print $fd $string;
	seek($fd,$now,0) or die "Unable to seek to $now in $fd : $!\n";
}


########################################################################
# Parse configuration
sub GetConfig {
 my($getopts, $doset, $name) = @_;

  my($topic,$val,$optarget);
  
  foreach my $filerc ( ("$ENV{HOME}/.gnupodrc",
                        "$getopts->{mount}/iPod_Control/.gnupod/gnupodrc",
                        "$getopts->{mount}/iTunes_Control/.gnupod/gnupodrc") ) {
    open(RCFILE, "<", $filerc) or next;
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

      
         if ($optarget&&$name&&$name ne $optarget) { next}
      elsif ($getopts->{$topic})      { next } #this is a dup 
      elsif ($doset->{$topic} eq "s") { $getopts->{$topic} = $val }
      elsif ($doset->{$topic} eq "i") { $getopts->{$topic} = int($val) }
      elsif ($doset->{$topic} eq "b") { $getopts->{$topic} = 1 if($val && $val ne "no") }
     }
     close(RCFILE);
  }
  
  return 1;
}

#############################################
# Get Unique path, this is not race-condition save
sub get_u_path {
	my($prefix, $ext) = @_;
	my $dst = undef;
	while($dst = sprintf("%s_%x_%x.$ext",$prefix, int(time()), int(rand(0xFFFFFFF)))) {
		last unless -e $dst;
	}
	return $dst;
}


1;
