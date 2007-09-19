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
use Data::Dumper;
use GNUpod::FooBar;

my %opts = ();
$opts{mount} = '/mnt/ipod';

my $con = GNUpod::FooBar::connect(\%opts);

GetDeviceInformation(Connection=>$con);

sub GetDeviceInformation {
	my(%args) = @_;
	
	my $connection = $args{Connection};
	
	my $info = { Serial => undef, Version => undef,  Model => undef,   FirewireGuid => undef,
	             HasAudio => 1,   HasVideo => undef, HasAlac => undef, HasPhotos => undef };
	
	_GrabSysinfo(Sysinfo=>$connection->{sysinfo}, Hash=>$info);
	_GrabFirewireGuid($info) if !defined($info->{FirewireGuid});
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
# Detect operating system and dispatch the firewireguid grabber
sub _GrabFirewireGuid {
	my($ref) = @_;
	
	if($Config{'osname'} eq "linux") {
		__GrabFWGUID_LINUX($ref);
	}
	else {
		warn "$0: Support for '$Config{osname}' not implemented\n";
	}

}

############################################################
# Try to get iPods firewire guid using the proc interface
sub __GrabFWGUID_LINUX {
	my($ref) = @_;
	
	my $procfile = '/proc/bus/usb/devices';
	my $hbuff    = ();
	
	unless( open(PROC, "<", $procfile) ) {
		warn "$0 : Unable to open '$procfile' : $!\n";
		return;
	}
	
	while(<PROC>) {
		if($_ =~ /^$/) {
			if($hbuff->{Manufacturer} =~ /^Apple/ &&
			  $hbuff->{Product}      =~ /^iPod/ &&
			  $hbuff->{SerialNumber} =~ /^([A-Za-z0-9]{16})$/) {
				
				$ref->{FirewireGuid} = $hbuff->{SerialNumber};
				return;
			}
			$hbuff = ();
		}
		elsif($_ =~ /^S:\s+([^=]+)=(.+)$/) {
			$hbuff->{$1} = $2;
		}
	}
	close(PROC);
	
	
}



1;
