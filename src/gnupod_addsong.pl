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
use vars qw(%opts %dupdb $int_count);

print "gnupod_addsong.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$int_count = 3; #The user has to send INT (Ctrl+C) x times until we stop

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "version", "help|h", "mount|m=s", "decode", "restore|r", "duplicate|d", "disable-v2", "disable-v1",
                   "set-artist=s", "set-album=s", "set-genre=s", "set-rating=i", "set-playcount=i");
GNUpod::FooBar::GetConfig(\%opts, {'decode'=>'b', mount=>'s', duplicate=>'b', 'disable-v1'=>'b', 'disable-v2'=>'b'},
                          "gnupod_addsong");

usage() if $opts{help};
version() if $opts{version};

$SIG{'INT'} = \&handle_int;
if($opts{restore}) {
 print "If you use --restore, you'll *lose* your playlists\n";
 print " Hit ENTER to continue or CTRL+C to abort\n\n";
 <STDIN>;
 delete($opts{decode}); #We don't decode anything
 $opts{duplicate} = 1;  #Don't skip dups on restore
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
  GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}\n");
 }

 my $addcount = 0;

 #We are ready to copy each file..
 foreach my $file (@files) {
    #Skip all songs if user sent INT
    next if !$int_count;
    #Skip all dirs
    next if -d $file;
    
    #Get the filetype
    my ($fh,$media_h,$converted) =  GNUpod::FileMagic::wtf_is($file, {noIDv1=>$opts{'disable-v1'}, 
                                                                      noIDv2=>$opts{'disable-v2'},
								                                      decode=>$opts{'decode'}});
    unless($fh) {
     warn "* [****] Skipping '$file', unknown file type\n";
     next;
    }
    
   my $wtf_ftyp = $media_h->{ftyp};
   my $wtf_frmt = $media_h->{format};
   my $wtf_ext  = $media_h->{extension};
   
   #wtf_is found a filetype, override data if needed
   $fh->{artist}    = $opts{'set-artist'}    if $opts{'set-artist'};
   $fh->{album}     = $opts{'set-album'}     if $opts{'set-album'};
   $fh->{genre}     = $opts{'set-genre'}     if $opts{'set-genre'};
   $fh->{rating}    = $opts{'set-rating'}    if $opts{'set-rating'};
   $fh->{playcount} = $opts{'set-playcount'} if $opts{'set-playcount'};
   
   #Set the addtime to unixtime(now)+MACTIME (the iPod uses mactime)
   $fh->{addtime} = time()+MACTIME;
   #Get a path
   (${$fh}{path}, my $target) = GNUpod::XMLhelper::getpath($opts{mount}, $file, 
                                                           {format=>$wtf_frmt, extension=>$wtf_ext, keepfile=>$opts{restore}});
   #Check for duplicates
   if(!$opts{duplicate} && (my $dup = checkdup($fh))) {
    print "! [!!!] '$file' is a duplicate of song $dup, skipping file\n";
    unlink($converted) if $converted; #Unlink file, if we converted it.. (tmp)
    next;
   }
   
   
   #ReSet filename if we did a convert
   $file = $converted if $converted;
   
   if(!defined($target)) {
    warn "*** FATAL *** Skipping '$file' , no target found!\n";
   }
   elsif($opts{restore} || File::Copy::copy($file, $target)) {
     printf("+ [%-4s][%3d] %-32s | %-32s | %-24s\n",
	    uc($wtf_ftyp),1+$addcount, $fh->{title}, $fh->{album},$fh->{artist});
     
	 my $fmh;
     $fmh->{file} = $fh;
     GNUpod::XMLhelper::mkfile($fmh,{addid=>1}); #Try to add an id
     $addcount++; #Inc. addcount
   }
   else { #We failed..
     warn "*** FATAL *** Could not copy '$file' to '$target': $!\n";
   }
   
   #Now we unlink leftover converted files even if we couldn't
   #copy the file to the iPod
   unlink($converted) if $converted;
   
 }

 
 
 if($addcount) { #We have to modify the xmldoc
  print "> Writing new XML File, added $addcount file(s)\n";
  GNUpod::XMLhelper::writexml($con);
 }
 
 print "\n Done\n";
}








## XML Handlers ##
sub newfile {
 $dupdb{lc($_[0]->{file}->{title})."/$_[0]->{file}->{bitrate}/$_[0]->{file}->{time}/$_[0]->{file}->{filesize}"}= $_[0]->{file}->{id}||-1;
 GNUpod::XMLhelper::mkfile($_[0],{addid=>1});
}

sub newpl {
 GNUpod::XMLhelper::mkfile($_[0],{$_[2]."name"=>$_[1]});
}
##################


###############################################################
# Check if the file is a duplicate
sub checkdup {
 my($fh) = @_;
 return $dupdb{lc($fh->{title})."/$fh->{bitrate}/$fh->{time}/$fh->{filesize}"};
}


################################################################
#Sighandler
sub handle_int {
 if($int_count) {
  warn "RECEIVED SIGINT (CTRL+C): gnupod_addsong.pl is still working! hit CTRL+C again $int_count time(s) to quit.\n";
  $int_count--;
 }
 else {
  warn "..wait.. about to shutdown (cleaning up, etc..)\n";
 }
}


###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_addsong.pl [-h] [-m directory] File1 File2 ...

   -h, --help               display this help and exit
       --version            output version information and exit
   -m, --mount=directory    iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -r, --restore            Restore the iPod (create a new GNUtunesDB from scratch)
   -d, --duplicate          Allow duplicate files
       --disable-v1         Do not read ID3v1 Tags (MP3 Only)
       --disable-v2         Do not read ID3v2 Tags (MP3 Only)
       --decode             Convert FLAC Files to WAVE 'onthefly'
       --set-artist=string  Set Artist (Override ID3 Tag)
       --set-album=string   Set Album  (Override ID3 Tag)
       --set-genre=string   Set Genre  (Override ID3 Tag)
       --set-rating=int     Set Rating
       --set-playcount=int  Set Playcount

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

sub version {
die << "EOF";
gnupod_addsong.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2004

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

