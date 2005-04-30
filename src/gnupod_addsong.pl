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

use constant MACTIME => 2082931200; #Mac EPOCH offset
use vars qw(%opts %dupdb_normal %dupdb_lazy $int_count);

print "gnupod_addsong.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$int_count = 3; #The user has to send INT (Ctrl+C) x times until we stop

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "version", "help|h", "mount|m=s", "decode=s", "restore|r", "duplicate|d", "disable-v2", "disable-v1",
                   "set-artist=s", "set-album=s", "set-genre=s", "set-rating=i", "set-playcount=i",
                   "set-songnum", "playlist|p=s", "reencode|e=i");
GNUpod::FooBar::GetConfig(\%opts, {'decode'=>'s', mount=>'s', duplicate=>'b',
                                   'disable-v1'=>'b', 'disable-v2'=>'b', 'set-songnum'=>'b'},
                          "gnupod_addsong");


usage("\n--decode needs 'pcm' 'mp3' 'aac' or 'aacbm' -> '--decode=mp3'\n") if $opts{decode} && $opts{decode} !~ /^(mp3|aac|aacbm|pcm|crashme)$/;
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
	startup(glob("$opts{mount}/iPod_Control/Music/*/*"));
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
	my(@files) = @_;
	
	#Don't sync if restore is true
	$opts{_no_sync} = $opts{restore};

	my $con = GNUpod::FooBar::connect(\%opts);
	usage($con->{status}."\n") if $con->{status} || !@files;

	unless($opts{restore}) { #We parse the old file, if we are NOT restoring the iPod
		GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");
	}

	if ($opts{playlist}) { #Create this playlist
		print "> Adding songs to Playlist '$opts{playlist}'\n";
		GNUpod::XMLhelper::addpl($opts{playlist}); #Fixme: this may printout a warning..
	} 

	my $addcount = 0;
	#We are ready to copy each file..
	foreach my $file (@files) {
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
		
		#wtf_is found a filetype, override data if needed
		$fh->{artist}    = $opts{'set-artist'}    if $opts{'set-artist'};
		$fh->{album}     = $opts{'set-album'}     if $opts{'set-album'};
		$fh->{genre}     = $opts{'set-genre'}     if $opts{'set-genre'};
		$fh->{rating}    = $opts{'set-rating'}    if $opts{'set-rating'};
		$fh->{playcount} = $opts{'set-playcount'} if $opts{'set-playcount'};
		$fh->{songnum}   = 1+$addcount            if $opts{'set-songnum'};
		
		#Set the addtime to unixtime(now)+MACTIME (the iPod uses mactime)
		#This breaks perl < 5.8 if we don't use int(time()) !
		$fh->{addtime} = int(time())+MACTIME;


		#Check for duplicates
		if(!$opts{duplicate} && (my $dup = checkdup($fh,$converter))) {
			print "! [!!!] '$file' is a duplicate of song $dup, skipping file\n";
			create_playlist_now($opts{playlist}, $dup); #We also add duplicates to a playlist..
			next;
		}

		if($converter) {
			print "> Converting '$file' from $wtf_ftyp into $opts{decode}, please wait...\n";
			my $path_of_converted_file = GNUpod::FileMagic::kick_convert($converter,$file, uc($opts{decode}), $con);
			unless($path_of_converted_file) {
				print "! [!!!] Could not convert $file\n";
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
					#2. Set converted-state : This will unlink the file after copy finished!
					$converter = 1;
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
			create_playlist_now($opts{playlist}, $id);
			$addcount++; #Inc. addcount
		}
		else { #We failed..
			warn "*** FATAL *** Could not copy '$file' to '$target': $!\n";
		}
		unlink($file) if $converter; #File is in $tmp if $converter is set...
	}

 
 
	if($opts{playlist} || $addcount) { #We have to modify the xmldoc
		print "> Writing new XML File, added $addcount file(s)\n";
		GNUpod::XMLhelper::writexml($con);
	}
	print "\n Done\n";
}



#############################################################
# Add item to playlist
sub create_playlist_now {
 my($plname, $id) = @_;

 if($plname && $id >= 0) {
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



## XML Handlers ##
sub newfile {
 $dupdb_normal{lc($_[0]->{file}->{title})."/$_[0]->{file}->{bitrate}/$_[0]->{file}->{time}/$_[0]->{file}->{filesize}"}= $_[0]->{file}->{id}||-1;

#This is worse than _normal, but the only way to detect dups *before* re-encoding...
 $dupdb_lazy{lc($_[0]->{file}->{title})."/".lc($_[0]->{file}->{album})."/".lc($_[0]->{file}->{artist})}= $_[0]->{file}->{id}||-1;

 GNUpod::XMLhelper::mkfile($_[0],{addid=>1});
}

sub newpl {
 GNUpod::XMLhelper::mkfile($_[0],{$_[2]."name"=>$_[1]});
}
##################


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

   -h, --help                      display this help and exit
       --version                   output version information and exit
   -m, --mount=directory           iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -r, --restore                   Restore the iPod (create a new GNUtunesDB from scratch)
   -d, --duplicate                 Allow duplicate files
   -p, --playlist=string           Add songs to this playlist
       --disable-v1                Do not read ID3v1 Tags (MP3 Only)
       --disable-v2                Do not read ID3v2 Tags (MP3 Only)
       --decode=pcm|mp3|aac|aacbm  Convert FLAC Files to WAVE/MP3 or AAC 'on-the-fly'
   -e  --reencode=int              Reencode MP3/AAC files with new quality 'on-the-fly'
                                   (0 = Good .. 9 = Bad)
                                   You may be able to save some space if you do not need
                                   crystal-clear sound ;-)
       --set-artist=string         Set Artist (Override ID3 Tag)
       --set-album=string          Set Album  (Override ID3 Tag)
       --set-genre=string          Set Genre  (Override ID3 Tag)
       --set-rating=int            Set Rating
       --set-playcount=int         Set Playcount
       --set-songnum               Override 'Songnum/Tracknum' field

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

