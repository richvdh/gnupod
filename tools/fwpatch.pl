#!/usr/bin/perl
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
#
###########################################################
# Well, this is tested with Firmware 2.2.2 and 3.2.3 (mini)
#
#
#
#
use strict;
use Getopt::Long;

use constant LEN => 1; #DunnoTouch

use constant USPOD => chr(0).chr(1);
use constant EUPOD => chr(1).chr(0);

my %opts = ();
GetOptions(\%opts, "video");


my @TOSEEK       = (0x00, 0x08, 0x00, 0x9f, 0xe5,
                    0x38, 0x01, 0x90, 0xe5);

my @TOSEEK_VIDEO = (0xbd, 0xe8, 0x08, 0x00, 0x9F, 0xE5, 0x94,
                    0x00, 0x90, 0xE5);

if($opts{video}) {
	@TOSEEK = @TOSEEK_VIDEO;
}


my $FIRMWARE = $ARGV[0] or usage();
my $CMD      = $ARGV[1];


open(FW, $FIRMWARE) or die "Could not open $FIRMWARE ,$!\n";

unless(is_FW(*FW)) {
	die "Wrong magic, doesn't look like iPod firmware image\n";
}
my $pos2patch = search_pos(*FW);
if($pos2patch < 0) {
	die "Nothing found :/\n";
}
seek(FW,$pos2patch,0);
my $fw_state = get_status(*FW);
close(FW);


if($fw_state == 0) {
	print "This is *not* an EU iPod (good!)\n";
}
elsif($fw_state == 1) {
	print "Bonjour! This is an EU iPod\n";
}
else {
	die "I don't know what this firmware is\n";
}

if($CMD eq "EU") {
	open(WFW, "+<$FIRMWARE");
	seek(WFW,$pos2patch,0);
	syswrite(WFW,EUPOD);
	close(WFW);
	print "> Patched firmware to EU\n";
}
elsif($CMD eq "INT") {
	open(WFW, "+<$FIRMWARE");
	seek(WFW,$pos2patch,0);
	syswrite(WFW,USPOD);
	close(WFW);
	print "> Patched firmware to US/INT\n";
}







##########################################
# Get status from current POS
# 0 = INT
# 1 = EU
#-1 = ERROR
sub get_status {
	my($fh) = @_;

	my $iE = 0;
	my $iI = 0;
	read(FW,$iE,1);
	read(FW,$iI,1);
	$iE = ord($iE);
	$iI = ord($iI);

	
	if( ($iE == 0x01) && ($iI == 0x00) ) {
		return 1;
	}
	elsif( ($iE == 0x00) && ($iI == 0x01) ) {
		return 0;
	}
	else {
	printf("%X %X\n",$iE, $iI);
		return -1;
	}
}

##################################
#Search patchpos
sub search_pos {
	my($fh) = @_;
	my $chain = 0;
	my $last_match = 0;
	my $buff = undef;
	seek($fh,0,0);
	while(read($fh,$buff,LEN) == LEN) {
		my @chars = split(//,$buff);
		foreach my $c (@chars) { ##Fixme.. this is silly because LEN == 1
			if(ord($c) == $TOSEEK[$chain]) {
				$last_match = tell($fh);
				$chain++;
			}
			else {
				if($chain) {
					seek($fh,$last_match,0);
				}
				$chain = 0;
			}
		}
		return(tell($fh)) if $chain == int(@TOSEEK);
	}
	return(-1);
}

########################
#Firmware?
sub is_FW {
 my($fh) = @_;
 seek($fh,54,0);
 my $buff = undef;
 read($fh,$buff,8);
 seek($fh,0,0);
 if($buff eq "S T O P ") {
  return 1;
 }
 return 0;
}


sub usage {
 die << "EOF";

fwpatch.pl 0.4 - (C) Adrian Ulrich

Idea and \@TOSEEK stolen from
goPod : http://gopod.free-go.net, written by  JiB, kang & Alf

Usage: $0 <FIRMWARE> [--video] [EU|INT]

--video         : Given firmware is a Video / 5.x gen iPod

Commands:
 <FIRMWARE>     : Check firmware, do not write anything
 <FIRMWARE> EU  : Patch <FIRMWARE> into EU mode (= Low volume)
 <FIRMWARE> INT : Patch <FIRMWARE> into International mode (= No limit :) )

**NOTE** fwpatch.pl writes to <FIRMWARE>, create a backup if you don't
         like this! You've been warned!
         <FIRMWARE> can also be an iPod FW-Partition (= first partition for FAT iPods)
         Examples
            Get information:  $0 /dev/sda1
            Patch Video-iPod: $0 /dev/sda1 --video INT

Have fun and beware of tinnitus! (Not a joke)

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

You've been warned!

EOF
}

