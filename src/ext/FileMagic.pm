package GNUpod::FileMagic;
#  Copyright (C) 2002-2003 Adrian Ulrich <pab at blinkenlights.ch>
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
use Unicode::String;
use MP3::Info qw(:all);
use GNUpod::FooBar;
use GNUpod::QTfile;

BEGIN {
 MP3::Info::use_winamp_genres();
 MP3::Info::use_mp3_utf8(0);
 open(NULLFH, "> /dev/null") or die "Could not open /dev/null, $!\n";
}
#Try to discover the file format (mp3 or QT (AAC) )
sub wtf_is {

 my($file) = @_;
  if(my $h = __is_mp3($file)) {
   return $h;
  }
  elsif(my $h = __is_pcm($file)) {
   return $h
  }
  elsif(my $h = __is_qt($file)) {
   return $h
  }
  else {
   print "Unknown file type: $file\n";
  }
  return undef;
}

sub __is_qt {
 my($file) = @_;
 my $ret = GNUpod::QTfile::parsefile($file);
 return undef unless $ret; #No QT file
 
 my %rh = ();
 if($ret->{time} < 0) {
  warn "QTfile parsing failed, invalid time!\n";
  warn "You found a bug\n";
  return undef;
 }
 
 $rh{time} = $ret->{time};
 $rh{filesize} = $ret->{filesize};
 $rh{fdesc}    = $ret->{fdesc};
 $rh{artist} = $ret->{artist} || "Unknown Artist";
 $rh{album}  = $ret->{album}  || "Unknown Album";
 $rh{title}  = $ret->{title}  || "Unknown Title";
 return  \%rh;
}

######################################################################
# Check if the file is an PCM (WAVE) File
sub __is_pcm {
 my($file) = @_;

  open(PCM, "$file") or return undef;
   #Get the group id and riff type
   my ($gid, $rty);
   seek(PCM, 0, 0);
   read(PCM, $gid, 4);
   seek(PCM, 8, 0);
   read(PCM, $rty, 4);
   
   return undef unless($gid eq "RIFF" && $rty eq "WAVE");
#Ok, maybe a wave file.. try to get BPS and SRATE
   my $size = -s $file;
   return undef if ($size < 32); #File to small..
   
   my ($bs) = undef;
   seek(PCM, 24,0);
   read(PCM, $bs, 4);
   my $srate = GNUpod::FooBar::shx2int($bs);

   seek(PCM, 28,0); 
   read(PCM, $bs, 4);
   my $bps = GNUpod::FooBar::shx2int($bs);



  #Check if something went wrong..
   if($bps < 1 || $srate < 1) {
    warn "FileMagic.pm: Looks like '$file' is a crazy pcm-file: bps: *$bps* // srate: *$srate* -> skipping!!\n";
    return undef;
   }

#fixme
warn "FileMagic: debug: bps -> *$bps* / srate -> *$srate*\n";   
  my %rh = ();
  $rh{bitrate}  = $bps;
  $rh{filesize} = $size;
  $rh{srate}    = $srate;
  $rh{time}     = int(1000*$size/$bps);
  $rh{fdesc}    = "RIFF Audio File";
 
  #No id3 tags for us.. but mmmmaybe...
  #We use getuft8 because you could use umlauts and such things :)  
  $rh{title}    = getutf8(((split(/\//, $file))[-1]) || "Unknown Title");
  $rh{album} =    getutf8(((split(/\//, $file))[-2]) || "Unknown Album");
  $rh{artist} =   getutf8(((split(/\//, $file))[-3]) || "Unknown Artist");


return \%rh;
}

######################################################################
# Read mp3 tags, return undef if file is not an mp3
sub __is_mp3 {
 my($file) = @_;
 
 my $h = MP3::Info::get_mp3info($file);
 return undef unless $h; #No mp3
 
#This is our default fallback:
#If we didn't find a title, we'll use the
#Filename.. why? because you are not able
#to play the file without an filename ;)
 my $cf = ((split(/\//,$file))[-1]);
 
 my %rh = ();

 $rh{bitrate} = $h->{BITRATE};
 $rh{filesize} = $h->{SIZE};
 $rh{srate}    = int($h->{FREQUENCY}*1000);
 $rh{time}     = int($h->{SECS}*1000);
 $rh{fdesc}    = "MPEG ${$h}{VERSION} layer ${$h}{LAYER} file";
 my $h = MP3::Info::get_mp3tag($file,1);  #Get the IDv1 tag
 my $hs = MP3::Info::get_mp3tag($file, 2,1); #Get the IDv2 tag


#IDv2 is stronger than IDv1..
 #Try to parse things like 01/01
 my @songa = pss(getutf8($hs->{TRCK} || $h->{TRACKNUM}));
 my @cda   = pss(getutf8($hs->{TPOS}));
 
     $rh{songs}    = int($songa[1]);
     $rh{songnum} =  int($songa[0]);
     $rh{cdnum}   =  int($cda[0]);
     $rh{cds}    =   int($cda[1]);
     $rh{year} =     getutf8($hs->{TYER} || $h->{YEAR} || 0);
     $rh{title} =    getutf8($hs->{TIT2} || $h->{TITLE} || $cf || "Untitled");
     $rh{album} =    getutf8($hs->{TALB} || $h->{ALBUM} || "Unknown Album");
     $rh{artist} =   getutf8($hs->{TPE1} || $h->{ARTIST}  || "Unknown Artist");
     $rh{genre} =    getutf8(               $h->{GENRE}   || "");
     $rh{comment} =  getutf8($hs->{COMM} || $h->{COMMENT} || "");
     $rh{composer} = getutf8($hs->{TCOM} || "");
     $rh{playcount}= int(getutf8($hs->{PCNT})) || 0;

 return \%rh;
}


########
# Guess format
sub pss {
 my($string) = @_;
 if(my($s,$n) = $string =~ /(\d+)\/(\d+)/) {
  return($s,$n);
 }
 else {
  return int($string);
 }
}

#########
# Try to 'auto-guess' charset and return utf8
sub getutf8 {
 my($in) = @_;

 $in =~ s/^(.)//;
 my $encoding = $1;

 if(ord($encoding) > 0 && ord($encoding) < 32) {
   warn "FileMagic.pm: warning: unsupportet ID3 Encoding found: ".ord($encoding)."\n";
   warn "                       send a bugreport to pab\@blinkenlights.ch\n";
   return undef;
 }
 else { #AutoGuess (We accept invalid id3tags)
  $in = $encoding.$in;
  #Remove all 00's
  $in =~ tr/\0//d;
  my $oldstderr = *STDERR; #Kill all utf8 warnings.. this is uuugly
  *STDERR = "NULLFH";
  my $bfx = Unicode::String::utf8($in)->utf8;
  *STDERR = $oldstderr;    #Restore old filehandle
   if($bfx ne $in) {
    #Input was no valid utf8, assume latin1 input
    $in =~  s/[\000-\037]//gm; #Kill stupid chars..
    $in = Unicode::String::latin1($in)->utf8
   }
   else { #Return the unicoded input
    $in = $bfx;
   }
 }
 return $in;
}

1;

