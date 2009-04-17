package GNUpod::SysInfo;
#
#
#  Copyright (C) 2007 Adrian Ulrich <pab at blinkenlights.ch>
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

use strict;
use Config;
use GNUpod::FooBar;


############################################################
# Collects various device information
sub GetDeviceInformation {
	my(%args) = @_;
	
	my $connection = $args{Connection};
	
	my $info = { Serial => undef, Version => undef,  Model => undef,   FirewireGuid => undef,
	             HasAudio => 1,   HasVideo => undef, HasAlac => undef, HasPhotos => undef };
	
	_GrabSysinfo(Sysinfo=>$connection->{sysinfo}, Hash=>$info);
	_GrabSysinfoExtended(Sysinfo=>$connection->{extsysinfo}, Hash=>$info);
	_GrabFirewireGuid($info) if !defined($info->{FirewireGuid}) && !$args{NoDeviceSearch};
	return $info;
}

############################################################
# Parse sysinfo file
sub _GrabSysinfo {
	my(%args) = @_;
	
	my $hash = $args{Hash};
	my $file = $args{Sysinfo};
	open(SYSINFO,"<",$file) or return; # nothing here
	while (<SYSINFO>) {
		my $line = $_; chomp($line);
		if    ($line =~ /^pszSerialNumber: (.+)$/)             { $hash->{Serial}       = $1; }
		elsif ($line =~ /^visibleBuildID: \S+ \(([^)]+)\)$/)   { $hash->{Version}      = $1; }
		elsif ($line =~ /^ModelNumStr: (\S+)$/)                { $hash->{Model}        = $1; }
		elsif ($line =~ /^FirewireGuid: 0x([A-Za-z0-9]{16})$/) { $hash->{FirewireGuid} = $1; }
	}
	close(SYSINFO);
}

############################################################
# Parse libgpod/gtkpod extended sysinfo file
sub _GrabSysinfoExtended {
	my(%args) = @_;
	
	# tbd
}


############################################################
# Detect operating system and dispatch the firewireguid grabber
sub _GrabFirewireGuid {
	my($ref) = @_;
	
	if($Config{'osname'} eq "linux") {
		print "> Searching iPod via sysfs\n";
		__GrabFWGUID_LINUX($ref);
	}
	elsif($Config{'osname'} eq "solaris") {
		print "> Searching iPod via prtconf -v\n";
		__GrabFWGUID_SOLARIS($ref);
	}
	else {
		warn "$0: iPod-GUID detection for '$Config{osname}' not implemented (yet)\n";
	}
}

############################################################
# Try to get iPods firewire guid using udev
sub __GrabFWGUID_LINUX {
	my($ref) = @_;
	
	my $found = undef;
	opendir(BLOCKDIR, "/sys/block") or return undef;
	while (my $dirent = readdir(BLOCKDIR)) {
		next if $dirent eq '.'; next if $dirent eq '..';
		next unless $dirent =~ /^sd/;
		open(UDEV, "-|") or exec("/sbin/udevadm", "info", "--name", $dirent, "--query", "env");
		while(<UDEV>) {
			if($_ =~ /^ID_SERIAL=Apple_iPod_([A-Za-z0-9]{16})/) {
				$found = $1;
			}
			last if $found;
		}
		close(UDEV);
		last if $found
	}
	closedir(BLOCKDIR);
	$ref->{FirewireGuid} = $found if $found;
}

############################################################
# Grab iPod firewire guid using solaris prtconf
sub __GrabFWGUID_SOLARIS {
	my($ref) = @_;
	my $hw = 0;
	my $i  = -1;
	my $cn = '';
	my @A  = ();
	
	open(PRT, "/usr/sbin/prtconf -v |") or return;
	while(<PRT>) {
		my $l = $_; chomp($l);
		if($l =~ /\s+Hardware properties:$/) {
			$i++;
			$hw=1;
		}
		elsif($hw) {
			if($l =~ /\s+name='([^']*)'/)        { $cn           = $1; }
			elsif($l =~ /\s+value='?([^']+)'?$/) { $A[$i]->{$cn} = $1; }
			else                                 { $hw           = 0;  }
		}
	}
	close(PRT);
	
	foreach my $r (@A) {
		if($r->{'usb-vendor-name'}  =~ /^Apple/ &&
		   $r->{'usb-product-name'} =~ /^iPod/ &&
		   $r->{'usb-serialno'}     =~ /^([A-Za-z0-9]{16})$/) {
			$ref->{FirewireGuid} = $r->{'usb-serialno'};
			return;
		}
	}
}



1;
