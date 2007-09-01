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
use GNUpod::lastfm;
use Getopt::Long;

use File::Glob ':glob';

use vars qw(%opts @keeper $plcref %lastfm_data $lastfm_timezone_hack);


$opts{mount} = $ENV{IPOD_MOUNTPOINT};

#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "top4secret");
GNUpod::FooBar::GetConfig(\%opts, {nosync=>'b', lastfm_enabled=>'b', lastfm_user=>'s', lastfm_password=>'s', 'automktunes'=>'b'}, "otgsync");
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

	#Disable auto-run of tunes2pod or gnupod_otgsync.pl
	$opts{_no_sync} = 1;
	my $con = GNUpod::FooBar::connect(\%opts);
	usage($con->{status}."\n") if $con->{status};
	
	if(GNUpod::FooBar::_itb_needs_sync($con)) {
		die "gnupod_otgsync.pl: Bug detected! You need to run tunes2pod.pl -> Sync broken!\n";
	}
	
	##Check if GNUtunesDB <-> iTunesDB is really in-sync
	if(GNUpod::FooBar::_otgdata_broken($con)) { #Ok, On-The-Go data is ** BROKEN **
		warn "gnupod_otgsync.pl: Error: You forgot to run mktunes.pl, wiping broken On-The-Go data...\n";
		#Remove broken data.. live is hard..
		unlink(bsd_glob($con->{onthego}, GLOB_NOSORT)) or warn "Could not remove $con->{onthego}, $!\n";
		unlink($con->{playcounts}) or warn "Could not remove $con->{playcounts}, $!\n"; 
		warn "Done!\n";
	}
	else {
		$lastfm_timezone_hack = -1* $con->{tzdiff};
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
			GNUpod::FooBar::setsync($con); # Needed for automktunes
			GNUpod::XMLhelper::writexml($con, {automktunes=>$opts{automktunes}});
		}
		else {
			#setsync .. just to be sure..
			GNUpod::FooBar::setsync($con);
		}
		#..and submit lastfm data if enabled in config file

		lfmworker($con->{lastfm_queue}) if $opts{lastfm_enabled}
	}
}

sub lfmsubmit {
	my($fm) = @_;
	return GNUpod::lastfm::dosubmission({user=>$opts{lastfm_user}, password=>$opts{lastfm_password}, tosubmit=>$fm});
}


sub lfmworker {
	my($queue) = @_;
	
	if(-e $queue) {
		print "> lastfm: Uploading data from lastfm queue ($queue)\n";
		open(LFMQ, $queue) or die "Ouch: Could not read $queue: $!\n";
		my $lfmq = lfmsubmit(GNUpod::lastfm::simple_lastfm_restore(*LFMQ));
		close(LFMQ);
		if($lfmq) {
			warn "> lastfm: Upload of queued data failed!\n";
			warn "> lastfm: Delete '$queue' if the problem persists.\n";
		}
		else {
			print "> lastfm: Uploaded queued data!\n";
			unlink($queue) or warn "Could not unlink $queue : $!\n";
		}
	}
	
	#Work on lastfm data.. %lastfm_data is empty if feature disabled
	my @fm = ();
	foreach(sort keys(%lastfm_data)) {
		push(@fm, $lastfm_data{$_});
	}
	my $lfmstat = lfmsubmit(\@fm);
	
	if($lfmstat) {
		warn "> lastfm: Upload failed, dumping data to queue\n";
		open(LFMQ, ">>".$queue) or die "Could not write to $queue: $!\n";
		GNUpod::lastfm::simple_lastfm_dump(*LFMQ,\@fm);
		close(LFMQ);
	}
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
		$el->{file}->{played_flag} = 1 if $el->{file}->{playcount};
		
		if($plcref->{lastplay}{int(@keeper)-1}) {
			$el->{file}->{lastplay}  = $plcref->{lastplay}{int(@keeper)-1};
		}
		if($plcref->{lastskip}{int(@keeper)-1}) {
			$el->{file}->{lastskip}  = $plcref->{lastskip}{int(@keeper)-1};
		}
		
		if($playcount > 0 && $opts{lastfm_enabled}) {
			my $seconds = int($el->{file}->{time}/1000);
			for(1..$playcount) {
				#Fixme: We (currently) do not care about the Timezone on the iPod
				my $gmtime = $el->{file}->{lastplay} - GNUpod::FooBar::MACTIME + $lastfm_timezone_hack; #fixme: this may cause collisions
				my @gmt    = gmtime($gmtime);
				my $lfmtime = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $gmt[5]+1900, $gmt[4]+1, $gmt[3], $gmt[2], $gmt[1], $gmt[0]);
				my $steptime = int($gmtime/10); #10-seconds 'resulution'
				
				#Search a free place for this song somewhere in our queue.
				#This is needed because the song may be played multiple times but we got only
				#the latest playtime from the iPod's database.
				while($lastfm_data{$steptime}) {
					$steptime--; #= 10 seconds
					print "=> Ouch! Adjusting Steptime to $steptime for ".$el->{file}->{title}."\n";
				}
				
				$lastfm_data{$steptime} =   {artist => $el->{file}->{artist}, album => $el->{file}->{album}, 
				                             title => $el->{file}->{title}, length => $el->{file}->{time}, xplaydate=>$lfmtime};
				print "LASTFM:    => $lfmtime   $el->{file}->{title} $el->{file}->{lastplay} $el->{file}->{time}\n";
			}
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

