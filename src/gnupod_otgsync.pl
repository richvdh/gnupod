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
use GNUpod::iTunesDB;
use Getopt::Long;

use File::Glob ':glob';

use vars qw(%opts @keeper $plcref);


$opts{mount} = $ENV{IPOD_MOUNTPOINT};

#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "top4secret");
GNUpod::FooBar::GetConfig(\%opts, {nosync=>'b', 'automktunes'=>'b', model=>'s'}, "otgsync");
#otgsync does just red nosync.. DONT add mount and such funny things!


if($opts{top4secret} && !$opts{nosync}) {
 go();
 exit(0);
}
elsif($opts{top4secret}) { #&& $opts{nosync}
 print "> On-The-Go sync disabled by configuration, skipping work...\n";
 exit(0);
}
else {
 usage("$0 isn't for humans :-)\nGNUpod::FooBar.pm has to execute me\n");
# exit(1);
}

####################################################
# Worker
sub go {

	$opts{_no_sync}   = 1;  # Do not run tunes2pod
	$opts{_no_cstest} = 1;  # Do not show case-sensitive warning
	my $con = GNUpod::FooBar::connect(\%opts);
	usage($con->{status}."\n") if $con->{status};
	
	if(GNUpod::FooBar::ItunesDBNeedsSync($con)) {
		die "gnupod_otgsync.pl: Bug detected! You need to run tunes2pod.pl -> Sync broken!\n";
	}
	
	##Check if GNUtunesDB <-> iTunesDB is really in-sync
	if(GNUpod::FooBar::OnTheGoDataIsInvalid($con)) { #Ok, On-The-Go data is ** BROKEN **
		warn "> On-The-Go data dropped, data belongs to an outdated iTunesDB\n";
	}
	else {
		#Read on The Go list written by the iPod
		my @xotg    = GNUpod::iTunesDB::readOTG($con->{onthego});
		#plcref is used by newfile()
		#so we have to call this before doxml()
		$plcref  = GNUpod::iTunesDB::readPLC($con->{playcounts});
		#Add dummy entry, we start to count at 1, not at 0
		if(int(@xotg) || $plcref) { #We have to modify
			push(@keeper, -1);
			#First, we parse the old xml document and create the keeper
			GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}\n");
			mkotg(@xotg) if int(@xotg);
			GNUpod::FooBar::SetEverythingAsInSync($con); # Needed for automktunes
			GNUpod::XMLhelper::writexml($con, {automktunes=>$opts{automktunes}});
		}
	}
	
	# Everythig should be ok now..
	GNUpod::FooBar::SetEverythingAsInSync($con);
}




#############################################
# Add onthego contents to XML
sub mkotg {
	my(@otgrefs) = @_;

	#Get all old playlists and create a new name
	my $otggen = 1;
	foreach(GNUpod::XMLhelper::getpl_attribs()) {
		my $plname = $_->{name};
		if($plname =~ /^On-The-Go (\d+)/) {
			$otggen = ($1+1) if $otggen<=$1;
		}
	}

	foreach (@otgrefs) {
		my @xotg = @$_; #Change ref to array
		next if int(@xotg) == 0; #Do not create empty OTG-Lists
		GNUpod::XMLhelper::addpl("On-The-Go $otggen");
		foreach(@xotg) {
			my $otgid = $_+1;
			my $plfh = ();
			$plfh->{add}->{id} = $keeper[$otgid];
			next unless $plfh->{add}->{id};
			GNUpod::XMLhelper::mkfile($plfh,{"plname"=>"On-The-Go $otggen"});
		}
		$otggen++;
	}

}

#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;

	#This has to be 'in-sync' with the mktunes.pl method
	# (GNUtunesDB_id <-> iTunesDB_id)
	# in mktunes.pl, every <file.. will create a new
	# id, like here :)
	
	push(@keeper, int($el->{file}->{id}));
	if($plcref) { #PlayCountref exists (=v2 ipod) -> adjust
		#Adjust rating
		my $playcount = $plcref->{playcount}{int(@keeper)-1};
		$el->{file}->{rating}    =  $plcref->{rating}{int(@keeper)-1};
		$el->{file}->{playcount} += $playcount;
		$el->{file}->{skipcount} += $plcref->{skipcount}{int(@keeper)-1};
		$el->{file}->{bookmark}  =  $plcref->{bookmark}{int(@keeper)-1};
		$el->{file}->{played_flag} = 1 if ($el->{file}->{playcount} > 0 || $el->{file}->{skipcount} > 0 || $el->{file}->{bookmark} > 0);
		
		if($plcref->{lastplay}{int(@keeper)-1}) {
			$el->{file}->{lastplay}  = $plcref->{lastplay}{int(@keeper)-1};
		}
		if($plcref->{lastskip}{int(@keeper)-1}) {
			$el->{file}->{lastskip}  = $plcref->{lastskip}{int(@keeper)-1};
		}
	}
	#Add content
	GNUpod::XMLhelper::mkfile($el);
}

############################################
# Eventhandler for PLAYLIST items
sub newpl {
 my($el,$name,$plt) = @_;
 #Add playlist to output
  GNUpod::XMLhelper::mkfile($el,{$plt."name"=>$name});
}

############################################
# Die with status
sub usage {
 die "died: $_[0]\n";
}

