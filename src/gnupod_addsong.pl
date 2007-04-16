###__PERLBIN__###
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

use strict;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::FileMagic;
use Getopt::Long;
use File::Copy;
use File::Glob ':glob';
use XML::Parser; #Loaded by XMLhelper, but hey..

use constant MACTIME => GNUpod::FooBar::MACTIME;
use vars qw(%opts %dupdb_normal %dupdb_lazy %dupdb_podcast $int_count %podcast_infos %per_file_info);

print "gnupod_addsong.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$int_count = 3; #The user has to send INT (Ctrl+C) x times until we stop

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "version", "help|h", "mount|m=s", "decode=s", "restore|r", "duplicate|d", "disable-v2", "disable-v1",
                   "set-artist=s", "set-album=s", "set-genre=s", "set-rating=i", "set-playcount=i",
                   "set-songnum", "playlist|p=s", "playlists=s", "reencode|e=i",
                   "min-vol-adj=i", "max-vol-adj=i" );
GNUpod::FooBar::GetConfig(\%opts, {'decode'=>'s', mount=>'s', duplicate=>'b',
                                   'disable-v1'=>'b', 'disable-v2'=>'b', 'set-songnum'=>'b',
                                   'min-vol-adj'=>'i', 'max-vol-adj'=>'i' },
                                   "gnupod_addsong");



usage("\n--decode needs 'pcm' 'mp3' 'aac' 'video' or 'aacbm' -> '--decode=mp3'\n") if $opts{decode} && $opts{decode} !~ /^(mp3|video|aac|aacbm|pcm|crashme)$/;
usage() if $opts{help};
version() if $opts{version};

$SIG{'INT'} = \&handle_int;
if($opts{restore}) {
	print "If you use --restore, you'll *lose* your playlists\n";
	print " Hit ENTER to continue or CTRL+C to abort\n\n";
	<STDIN>;
	delete($opts{decode});    #We don't decode anything
	$opts{duplicate} = 1;     #Don't skip dups on restore
	$opts{decode}    = undef; #Do not encode, only native files are on an iPod
	startup(bsd_glob("$opts{mount}/iPod_Control/Music/*/*", GLOB_NOSORT));
}
elsif($ARGV[0] eq "-" && @ARGV == 1) {
	print STDERR "Reading from STDIN, hit CTRL+D (EOF) when finished\n";
	my @files = ();
	while(<STDIN>) {
		chomp;
		push(@files, $_); #This eats memory, but it isn't so bad...
	}
	startup(@files);
}
else {
	startup(@ARGV);
}



####################################################
# Worker
sub startup {
	my(@argv_files) = @_;
	
	#Don't sync if restore is true
	$opts{_no_sync} = $opts{restore};
	
	my @plarray     = split(/;/,$opts{playlists});
	push(@plarray,$opts{playlist}) if defined($opts{playlist});
	
	
	my $con = GNUpod::FooBar::connect(\%opts);
	usage($con->{status}."\n") if $con->{status} || !@argv_files;

	unless($opts{restore}) { #We parse the old file, if we are NOT restoring the iPod
		GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");
	}

	if(int(@plarray)) { #Create this playlist
		foreach my $xcpl (@plarray) {
			print "> Adding songs to Playlist '$xcpl'\n";
			GNUpod::XMLhelper::addpl($xcpl); #Fixme: this may printout a warning..
		}
	} 

	# Check volume adjustment options for sanity
	my $min_vol_adj = int($opts{'min-vol-adj'});
	my $max_vol_adj = int($opts{'max-vol-adj'});
	
	usage("Invalid settings: --min-vol-adj=$min_vol_adj > --max-vol-adj=$max_vol_adj\n") if ($min_vol_adj > $max_vol_adj);
	usage("Invalid settings: --min-vol-adj=$min_vol_adj < -100\n")                       if ($min_vol_adj < -100);
	usage("Invalid settings: --max-vol-adj=$max_vol_adj > 100\n")                        if ($max_vol_adj > 100);
	
	
	#We parsed the XML-Document
	#resolve_podcasts fetches new podcasts from http:// stuff and adds them to real_files
#	warn "DEBUG: START RESOLVE\n";
	my @real_files = resolve_podcasts(@argv_files);
#	warn "DEBUG: END RESOLVE\n";
	
	my $addcount = 0;
	#We are ready to copy each file..
	foreach my $file (@real_files) {
		#Skip all songs if user sent INT
		next if !$int_count;
		#Skip all dirs
		next if -d $file;
		
		#Get the filetype
		my ($fh,$media_h,$converter) =  GNUpod::FileMagic::wtf_is($file, {noIDv1=>$opts{'disable-v1'}, 
		                                                                  noIDv2=>$opts{'disable-v2'},
		                                                                  decode=>$opts{'decode'}},$con);

		unless($fh) {
			warn "* [****] Skipping '$file', unknown file type\n";
			next;
		}
		my $wtf_ftyp = $media_h->{ftyp};      #'codec' .. maybe ALAC
		my $wtf_frmt = $media_h->{format};    #container ..maybe M4A
		my $wtf_ext  = $media_h->{extension}; #Possible extensions (regexp!)

		#Force tags for current file
		#This is only used for RSS ATM.
		my $c_per_file_info = $per_file_info{$file};
		foreach(keys(%$c_per_file_info)) {
			next unless lc($_) eq $_; #lc keys are there to overwrite $fh keys
			$fh->{$_} = $c_per_file_info->{$_};
		}
				
		#wtf_is found a filetype, override data if needed
		$fh->{artist}      = $opts{'set-artist'}      if $opts{'set-artist'};
		$fh->{album}       = $opts{'set-album'}       if $opts{'set-album'};
		$fh->{genre}       = $opts{'set-genre'}       if $opts{'set-genre'};
		$fh->{rating}      = $opts{'set-rating'}      if $opts{'set-rating'};
		$fh->{playcount}   = $opts{'set-playcount'}   if $opts{'set-playcount'};
		$fh->{songnum}     = 1+$addcount              if $opts{'set-songnum'};
		
		#Set the addtime to unixtime(now)+MACTIME (the iPod uses mactime)
		#This breaks perl < 5.8 if we don't use int(time()) !
		$fh->{addtime} = int(time())+MACTIME;
		
		#Ugly workaround to avoid a warning while running mktunes.pl:
		#All (?) int-values returned by wtf_is won't go above 0xffffffff
		#Thats fine because almost everything inside an mhit can handle this.
		#But bpm and srate are limited to 0xffff
		# -> We fix this silently to avoid ugly warnings while running mktunes.pl
		$fh->{bpm}   = 0xFFFF if $fh->{bpm}   > 0xFFFF;
		$fh->{srate} = 0xFFFF if $fh->{srate} > 0xFFFF;


		#Check for duplicates
		if(!$opts{duplicate} && (my $dup = checkdup($fh,$converter))) {
			print "! [!!!] '$file' is a duplicate of song $dup, skipping file\n";
			create_playlist_now(\@plarray, $dup); #We also add duplicates to a playlist..
			next;
		}

		if($converter) {
			print "> Converting '$file' from $wtf_ftyp into $opts{decode}, please wait...\n";
			my $path_of_converted_file = GNUpod::FileMagic::kick_convert($converter,$opts{reencode},$file, uc($opts{decode}), $con);
			unless($path_of_converted_file) {
				print "! [!!!] Could not convert $file into $opts{decode}\n";
				next;
			}
			#Ok, we got a converted file, fillout the gaps
			my($conv_fh, $conv_media_h) = GNUpod::FileMagic::wtf_is($path_of_converted_file, undef, $con);
			
			unless($conv_fh) {
				warn "* [***] Internal problem: $converter did not produce valid data.\n";
				warn "* [***] Something is wrong with $path_of_converted_file (file not deleted, debug it! :) )\n";
				next; 	
			}
    
			#We didn't know things like 'filesize' before...
			$fh->{time}     = $conv_fh->{time};
			$fh->{bitrate}  = $conv_fh->{bitrate};
			$fh->{srate}    = $conv_fh->{srate};        
			$fh->{filesize} = $conv_fh->{filesize};   
			$wtf_frmt = $conv_media_h->{format};    #Set the new format (-> container)
			$wtf_ext  = $conv_media_h->{extension}; #Set the new possible extension
			#BUT KEEP ftyp! (= codec)
			$file = $path_of_converted_file; #Point $file to new file
			$per_file_info{$file}->{UNLINK} = 1; #Request unlink of this file after adding
		}
		elsif(defined($opts{reencode})) {
			print "> ReEncoding '$file' with quality ".int($opts{reencode}).", please wait...\n";
			my $path_of_converted_file = GNUpod::FileMagic::kick_reencode($opts{reencode},$file,$wtf_frmt,$con);
			
			if($path_of_converted_file) {
				#Ok, we could convert.. check if it made sense:
				if( (-s $path_of_converted_file) < (-s $file) ) {
					#Ok, output is smaller, we are going to use thisone
					#1. Replace path to file
					$file = $path_of_converted_file;
					#2. Set UNLINK-state : This will unlink the file after copy finished!
					$per_file_info{$file}->{UNLINK} = 1;
				}
				else {
					#Nope.. input was smaller, converting was silly..
					print "* [***] Reencoded output bigger than input! Adding source file\n";
					unlink($path_of_converted_file) or warn "Could not unlink $path_of_converted_file, $!\n";
					#Ok, do nothing! 
				}
			}
			else {
				print "* [***] ReEncoding of file failed! Adding given file\n";
			}
		}
		
		# Clamp volume, if any
		my $vol = $fh->{volume} || 0;
		$vol = $min_vol_adj if ($vol < $min_vol_adj);
		$vol = $max_vol_adj if ($vol > $max_vol_adj);
		# print "$file vol $fh->{volume} -> $vol\n";
		$fh->{volume} = $vol;
		
		#Get a path
		(${$fh}{path}, my $target) = GNUpod::XMLhelper::getpath($opts{mount}, $file, 
		                                                        {format=>$wtf_frmt, extension=>$wtf_ext, keepfile=>$opts{restore}});

		if(!defined($target)) {
			warn "*** FATAL *** Skipping '$file' , no target found!\n";
		}
		elsif($opts{restore} || File::Copy::copy($file, $target)) {
			printf("+ [%-4s][%3d] %-32s | %-32s | %-24s\n",
			uc($wtf_ftyp),1+$addcount, $fh->{title}, $fh->{album},$fh->{artist});

			my $id = GNUpod::XMLhelper::mkfile({file=>$fh},{addid=>1}); #Try to add an id
			create_playlist_now(\@plarray, $id);
			$addcount++; #Inc. addcount
		}
		else { #We failed..
			warn "*** FATAL *** Could not copy '$file' to '$target': $!\n";
			unlink($target); #Wipe broken file
		}
		#Is it a tempfile? Remove it.
		#This is the case for 'converter' files and 'rss'
		unlink($file) if $per_file_info{$file}->{UNLINK} == 1;
	}

 
 
	if(int(@plarray) || $addcount) { #We have to modify the xmldoc
		print "> Writing new XML File, added $addcount file(s)\n";
		GNUpod::XMLhelper::writexml($con);
	}
	print "\n Done\n";
}



#############################################################
# Add item to playlist
sub create_playlist_now {
	my($plref, $id) = @_;
	
	my @pla = @$plref;
	
	if(int(@pla) && $id >= 0) {
		foreach my $plname (@pla) {
			#Broken-by-design: We don't have a ID-Pool for playlists..
			#-> Create a fake_entry
			my $fake_entry = GNUpod::XMLhelper::mkfile({ add => { id => $id } }, { return=>1 });
			my $found = 0;
			foreach(GNUpod::XMLhelper::getpl_content($plname)) {
				if($_ eq $fake_entry) {
					$found++; last;
				}
			}
			GNUpod::XMLhelper::mkfile({ add => { id => $id } },{"plname"=>$plname}) unless $found;
		}
	}
}



## XML Handlers ##
sub newfile {
	$dupdb_normal{lc($_[0]->{file}->{title})."/$_[0]->{file}->{bitrate}/$_[0]->{file}->{time}/$_[0]->{file}->{filesize}"}= $_[0]->{file}->{id}||-1;

	#This is worse than _normal, but the only way to detect dups *before* re-encoding...
	$dupdb_lazy{lc($_[0]->{file}->{title})."/".lc($_[0]->{file}->{album})."/".lc($_[0]->{file}->{artist})}= $_[0]->{file}->{id}||-1;
	
	#Add podcast infos if it is an podcast
	if($_[0]->{file}->{podcastguid}) {
		$dupdb_podcast{$_[0]->{file}->{podcastguid}."\0".$_[0]->{file}->{podcastrss}}++;
	}
	
	GNUpod::XMLhelper::mkfile($_[0],{addid=>1});
}

sub newpl {
 GNUpod::XMLhelper::mkfile($_[0],{$_[2]."name"=>$_[1]});
}
##################


#### PODCAST START ####

#############################################################
# Calls wget to get files
sub PODCAST_fetch {
	my($url,$prefix) = @_;
	my $tmpout = GNUpod::FooBar::get_u_path($prefix,"");
	my $return = system("wget", "-q", "-O", $tmpout, $url);
	return{file=>$tmpout, status=>$return};
}

#############################################################
#Eventer for START:
# -> Push array if we found a new item beginning
# -> Add '<foo bar=barz oink=yak />' stuff to the hash
# => Fillsup %podcast_infos
sub podcastStart {
	my($hr,$el,@it) = @_;
	my $hashref_key = $hr->{Base};
	if($hr->{Context}[-2] eq "rss" &&
	   $hr->{Context}[-1] eq "channel" &&
		 $el eq "item") {
		push(@{$podcast_infos{$hashref_key}}, {});
	}
	elsif($hr->{Context}[-3] eq "rss" &&
	   $hr->{Context}[-2] eq "channel" &&
	   $hr->{Context}[-1] eq "item" &&
	   @it) {
		my $xref = GNUpod::XMLhelper::mkh($el,@it);
		${$podcast_infos{$hashref_key}}[-1]->{$el} ||= $xref->{$el};
	}
}

#############################################################
#Eventer for <foo>CONTENT</foo>
# => Fillsup %podcast_infos
sub podcastChar {
	my($hr,$el) = @_;
	my $hashref_key = $hr->{Base};
	if($hr->{Context}[-4] eq "rss" &&
	   $hr->{Context}[-3] eq "channel" &&
	   $hr->{Context}[-2] eq "item") {
		my $ccontext = $hr->{Context}[-1];
		${$podcast_infos{$hashref_key}}[-1]->{$ccontext}->{"\0"} ||= $el;
	}
}

#############################################################
# This is the heart of our podcast support
#
sub resolve_podcasts {
	my(@xfiles) = @_;
	my @files = ();
	my $i = 0;
	foreach my $cf (@xfiles) {
		if($cf =~ /^http:\/\//i) {
			$i++;
			print "* [HTTP] Fetching Podcast #$i: $cf\n";
			my $pcrss = PODCAST_fetch($cf, "/tmp/gnupodcast$i");
			if($pcrss->{status} or (!(-f $pcrss->{file}))) {
				warn "! [HTTP] Unable to download the file '$cf', wget exitcode: $pcrss->{status}\n";
				next;
			}
			#Add the stuff to %podcast_infos and unlink the file after this.
			eval {
				my $px = new XML::Parser(Handlers=>{Start=>\&podcastStart, Char=>\&podcastChar});
				$px->parsefile($pcrss->{file});
			};
			warn "! [HTTP] Error while parsing XML: $@\n" if $@;
			unlink($pcrss->{file}) or warn "Could not unlink $pcrss->{file}, $!\n";
			$per_file_info{$pcrss->{file}}->{REAL_RSS} = $cf;
		}
		else {
			push(@files, $cf);
		}
	}

foreach my $key (keys(%podcast_infos)) {
	my $cref = $podcast_infos{$key};
	foreach my $podcast_item (@$cref) {
		my $c_title = $podcast_item->{title}->{"\0"};
		my $c_author = $podcast_item->{author}->{"\0"};
		my $c_url   = $podcast_item->{enclosure}->{url};
		#We use the URL as GUID if there isn't one...			
		my $c_guid  = $podcast_item->{guid}->{"\0"} || $c_url;
		my $c_podcastrss = $per_file_info{$key}->{REAL_RSS};
		my $possible_dupdb_entry = $c_guid."\0".$c_podcastrss;

		if(length($c_guid) == 0 or length($c_podcastrss) == 0 or length($c_url) == 0) {
			warn "! [HTTP] '$c_podcastrss' is an invalid podcast item (No URL/RSS?)\n";
			next;
		}
		elsif($dupdb_podcast{$possible_dupdb_entry}) {
			warn "! [HTTP] Podcast $c_url ($c_title) exists, no need to download this file\n";
			next;
		}		
		print "* [HTTP] Downloading $c_url ...\n";
		my $rssmedia = PODCAST_fetch($c_url, "/tmp/gnupodcast_media");
		if($rssmedia->{status} or (!(-f $rssmedia->{file}))) {
			warn "! [HTTP] Unable to download $rssmedia->{file}\n";
			next;
		}

		$per_file_info{$rssmedia->{file}}->{UNLINK} = 1;
		$per_file_info{$rssmedia->{file}}->{podcastguid} = $c_guid;
		$per_file_info{$rssmedia->{file}}->{podcastrss}  = $c_podcastrss;
		$per_file_info{$rssmedia->{file}}->{title}  = $c_title  if $c_title;
		$per_file_info{$rssmedia->{file}}->{artist} = $c_author if $c_author;
		push(@files,$rssmedia->{file});
	}
}
	
	return @files;
}

#### PODCAST END ####


###############################################################
# Check if the file is a duplicate
sub checkdup {
 my($fh, $from_lazy) = @_;
 
 return  $dupdb_lazy{lc($_[0]->{title})."/".lc($_[0]->{album})."/".lc($_[0]->{artist})}
   if $from_lazy;
   
 return $dupdb_normal{lc($fh->{title})."/$fh->{bitrate}/$fh->{time}/$fh->{filesize}"};
}


################################################################
#Sighandler
sub handle_int {
 if($int_count) {
  warn "RECEIVED SIGINT (CTRL+C): gnupod_addsong.pl is still working! hit CTRL+C again $int_count time(s) to quit.\n";
  $int_count--;
 }
 else {
  warn "..wait.. cleaning up..\n";
 }
}


###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_addsong.pl [-h] [-m directory] File1 File2 ...

   -h, --help                       display this help and exit
       --version                    output version information and exit
   -m, --mount=directory            iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -r, --restore                    Restore the iPod (create a new GNUtunesDB from scratch)
   -d, --duplicate                  Allow duplicate files
   -p, --playlist=string            Add songs to this playlist
       --playlists=string1;string2  Add songs to multiple playlists. Use ';' as separator
       --disable-v1                 Do not read ID3v1 Tags (MP3 Only)
       --disable-v2                 Do not read ID3v2 Tags (MP3 Only)
       --decode=pcm|mp3|aac|aacbm   Convert FLAC Files to WAVE/MP3 or AAC 'on-the-fly'
       --decode=video               Convert .avi Files into iPod video 'on-the-fly' (needs ffmpeg with AAC support!)
   -e  --reencode=int               Reencode MP3/AAC files with new quality 'on-the-fly'
                                    (0 = Good .. 9 = Bad)
                                    You may be able to save some space if you do not need
                                    crystal-clear sound ;-)
       --set-artist=string          Set Artist (Override ID3 Tag)
       --set-album=string           Set Album  (Override ID3 Tag)
       --set-genre=string           Set Genre  (Override ID3 Tag)
       --set-rating=int             Set Rating
       --set-playcount=int          Set Playcount
       --set-songnum                Override 'Songnum/Tracknum' field
       --min-vol-adj=int            Minimum volume adjustment allowed by ID3v2.4 RVA2 tag
       --max-vol-adj=int            Maximum ditto.  The volume can be adjusted in the range
                                    -100% to +100%.  The default for these two options is 0,
                                    which effectively ignored the RVA2 tag.

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

sub version {
die << "EOF";
gnupod_addsong.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2005

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

