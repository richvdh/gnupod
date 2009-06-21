###__PERLBIN__###
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
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::Mktunes;
use GNUpod::Hash58;
use GNUpod::SysInfo;
use GNUpod::ArtworkDB;
use Getopt::Long;


$| = 1;

my $mktunes = undef;
my %opts    = ();


print "mktunes.pl ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
GetOptions(\%opts, "version", "help|h", "ipod-name|n=s", "mount|m=s", "volume|v=i", "energy|e", "fwguid|g=s");
GNUpod::FooBar::GetConfig(\%opts, {'ipod-name'=>'s', mount=>'s', volume=>'i', energy=>'b', fwguid=>'s', model=>'s', low_ram_attr=>'s'}, "mktunes");
$opts{'ipod-name'} ||= "GNUpod ###__VERSION__###";


usage()   if $opts{help};
version() if $opts{version};
main();

#########################################################################
# main() :-)
sub main {
	my $con = GNUpod::FooBar::connect(\%opts);
	usage("$con->{status}\n") if $con->{status};
	
	my $sysinfo = GNUpod::SysInfo::GetDeviceInformation(Connection=>$con, NoDeviceSearch=>(defined($opts{fwguid}) ? 1 : 0 ) );
	my $fwguid  = (defined($opts{fwguid}) ? $opts{fwguid} : $sysinfo->{FirewireGuid}); # Always prefer fwguid. may be 0 to disable search
	
	print "> Loading ArtworkDB...";
	my $AWDB  = GNUpod::ArtworkDB->new(Connection=>$con, DropUnseen=>0);
	$AWDB->LoadArtworkDb;
	print "done\n";
	
	$mktunes = GNUpod::Mktunes->new(Connection=>$con, iPodName=>$opts{'ipod-name'}, Artwork=>$AWDB);
	
	print "> Parsing XML document...\n";
	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Could not read $con->{xml}, did you run gnupod_INIT.pl ?");
	
	print "\r> ".$mktunes->GetFileCount." files parsed, assembling iTunesDB...\n";

	my $keep = {};
	foreach(split(/[ ,]+/,$opts{'low_ram_attr'})) {
		$keep->{$_}++;
	}
	$mktunes->WriteItunesDB(keep=>$keep);
	
	if($fwguid) {
		my $k = GNUpod::Hash58::HashItunesDB(FirewireId=>$fwguid, iTunesDB=>$con->{itunesdb});
	}
	else {
		print "> iPod-GUID not detected. You can force the GUID using --fwguid\n";
	}
	
	print "> Writing new iTunesShuffle DB\n";
	$mktunes->WriteItunesSD;
	
	print "> Updating Sync-Status\n";
	GNUpod::FooBar::SetItunesDBAsInSync($con);   # iTunesDB is in sync with GNUtunesDB.xml
	GNUpod::FooBar::SetOnTheGoAsValid($con);     # ..and we can now, again, trust OnTheGo data
	GNUpod::FooBar::WipeShuffleStat($con);       # Forces reshuffling of iPod-Shuffle
	print "\nYou can now umount your iPod. [Files: ".$mktunes->GetFileCount."]\n";
	print " - May the iPod be with you!\n\n";

}


#########################################################################
# Called by doxml if it finds a new <file tag
sub newfile {
	my($item) = @_;
	
	if($opts{energy}) {
		# Crop title if requested. Note: Cropping it here affects regexps! 
		# But ... this had only a visible effect on 1st-gen ipods
		# and didn't work well with iTunes anyway..
		$item->{file}->{title} = Unicode::String::utf8($item->{file}->{title})->substr(0,18)->utf8;
	}
	
	#Volume adjust
	if($opts{volume}) {
		$item->{file}->{volume} += int($opts{volume});
		if(abs($item->{file}->{volume}) > 100) {
			print "\n** Warning: volume=\"$item->{file}->{volume}\" out of range: Volume set to ";
			$item->{file}->{volume} = ($item->{file}->{volume}/abs($item->{file}->{volume})*100);
			print "$item->{file}->{volume}% for id $item->{file}->{id}\n";
		}
	}

	my $id = $mktunes->AddFile($item->{file});
	print "\r> $id files parsed" if $id % 96 == 0;
}

#########################################################################
# Called by doxml if it a new <playlist.. has been found
sub newpl {
	my($item, $name, $type) = @_;
	if($type eq "pl") {
		$mktunes->AddNormalPlaylistItem(Name=>$name, Item=>$item);
	}
	elsif($type eq "spl") {
		$mktunes->AddSmartPlaylistItem(Name=>$name, Item=>$item);
	}
	else {
		warn "$0: unknown playlist type '$type' skipped\n";
	}
}



#########################################################################
# Usage information
sub usage {
	my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: mktunes.pl [-h] [-m directory] [-v VALUE]

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -n, --ipod-name=NAME    iPod Name (For unlabeled iPods)
   -v, --volume=VALUE      Adjust volume +-VALUE% (example: -v -20)
                            (Works with Firmware 1.x and 2.x!)
   -e, --energy            Save energy (= Disable scrolling title)
   -g, --fwguid=HEXVAL     FirewireGuid / Serial of connected iPod:

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

#########################################################################
# Displays current version
sub version {
die << "EOF";
mktunes.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2007

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}




