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

use MP3::Info qw(:all);
#use GNUpod::QTparser;
$^W = undef;
BEGIN {
 MP3::Info::use_winamp_genres();
}
#Try to discover the file format (mp3 or QT (AAC) )
sub wtf_is {

 my($file) = @_;
 print "FileMagic: $file\n";
  if(my $h = __is_mp3($file)) {
   print "--> MP3 detected\n";
   return $h;
  }
  elsif(__is_qt($file)) {
   print "--> QT File (AAC) Detected\n";
  }
  else {
   print "Unknown file type: $file\n";
  }
  return undef;
}

sub __is_qt {
 my($file) = @_;
# print "FIXME\n";
 return undef;
}

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
 $rh{time}     = int($h->{SECS}*1000);
 $rh{fdesc}    = "MPEG ${$h}{VERSION} layer ${$h}{LAYER} file";
 $h = MP3::Info::get_mp3tag($file, 1);  #Get the IDv1 tag
 $hs = MP3::Info::get_mp3tag($file, 2); #Get the IDv2 tag

#IDv2 is stronger than IDv1..
 #Try to parse things like 01/01
 my @songa = pss($hs->{TRCK} || $h->{TRACKNUM});
 my @cda   = pss($hs->{TPOS});
 
     $rh{songs}    =  int($songa[1]);
     $rh{songnum} =  int($songa[0]);
     $rh{cdnum}   =  int($cda[0]);
     $rh{cds}    =   int($cda[1]);
     $rh{year} =     getutf8($hs->{TYER} || $h->{YEAR} || 0);
     $rh{title} =    getutf8($hs->{TPE2} || $h->{TITLE} || $cf || "");
     $rh{album} =    getutf8($hs->{TALB} || $h->{ALBUM} || "Unknown Album");
     $rh{artist} =   getutf8($hs->{TPE1} || $h->{ARTIST}  || "Unknown Artist");
     $rh{genre} =    getutf8(               $h->{GENRE}   || "");
     $rh{comment} =  getutf8($hs->{COMM} || $h->{COMMENT} || "");
     $rh{composer} = getutf8($hs->{TCOM} || "");
     $rh{playcount}= int($hs->{PCNT}) || 0;
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

#Guess charset and try to return valid UTF8 data
sub getutf8 {
 my($in) = @_;
 my $bfx = Unicode::String::utf8($in)->utf8;
 return $in if $bfx eq $in; #Input was valid utf8 data
 return Unicode::String::latin1($in)->utf8; #Maybe it was latin1?
}

1;

