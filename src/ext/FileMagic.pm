package GNUpod::FileMagic;
#  Copyright (C) 2002-2005 Adrian Ulrich <pab at blinkenlights.ch>
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

#
# How to add a converter:
# 1. Define the first 4 bytes in NN_HEADERS
# 2. write a decoder: gnupod_convert_BLA.pl
# done!
#

my $NN_HEADERS = {'MThd' => { encoder=>'gnupod_convert_MIDI.pl', ftyp=>'MIDI'},
                  'fLaC' => { encoder=>'gnupod_convert_FLAC.pl', ftyp=>'FLAC'},
                  'OggS' => { encoder=>'gnupod_convert_OGG.pl',  ftyp=>'OGG'}};
               



BEGIN {
 MP3::Info::use_winamp_genres();
 
 if($MP3::Info::VERSION >= 1.01) { #Check for very old MP3::Info versions
   MP3::Info::use_mp3_utf8(0);
 }
 else {
  warn "FileMagic.pm: Warning: You are using a VERY OLD ($MP3::Info::VERSION) Version\n";
  warn "              of MP3::Info. ** DISABLING UNICODE SUPPORT BECAUSE IT WOULD BREAK **\n";
  warn "              PLEASE UPGRADE TO 1.01 OR NEWER (See: http://search.cpan.org)\n";
 }
 
  open(NULLFH, "> /dev/null") or die "Could not open /dev/null, $!\n";
}

########################################################################
#Try to discover the file format (mp3 or QT (AAC) )
# Returns: (FILE_HASH{artist,album..}, MEDIA_HASH{ftyp,format,extension}, DECODER_SCALAR)
sub wtf_is {
 my($file, $flags, $con) = @_;
  
  if(-d $file) { #Don't add dirs
   warn "FileMagic.pm: '$file' is a directory!\n";
  }
  elsif(!-r $file) {
   warn "FileMagic.pm: Can't read '$file'\n";
  }
  elsif(my $nnat  = __is_NonNative($file,$flags,$con)) { #Handle non-native formats
   return($nnat->{ref}, {ftyp=>$nnat->{codec}}, $nnat->{encoder});
  }
  elsif(my $xqt = __is_qt($file,$flags)) {
   return ($xqt->{ref},  {ftyp=>$xqt->{codec}, format=>"m4a", extension=>"m4a|m4p|m4b"});
  }
  elsif(my $h = __is_mp3($file,$flags)) {
   return ($h, {ftyp=>"MP3", format=>"mp3"});
  }
  elsif(my $h = __is_pcm($file,$flags)) {
   return ($h, {ftyp=>"PCM", format=>"wav"});
  }

#Still no luck..
   return (undef, undef, undef);
}

########################################################################
#Handle Non-Native files :)
sub __is_NonNative {
 my($file, $flags, $con) = @_;
 return undef unless $flags->{decode}; #Decoder is OFF per default!
 
 open(TNN, $file) or return undef;
  my $buff = undef;
  read(TNN,$buff,4);
 close(TNN);
 
 my $encoder = $NN_HEADERS->{$buff}->{encoder};
 return undef unless $encoder; #Nope
 
 #Still here? -> We know how to decode this stuff
 my $metastuff = converter_readmeta($encoder, $file, $con);
 return undef unless ref($metastuff) eq "HASH"; #Failed .. hmm
 
 my %rh = ();
 my $cf = ((split(/\//,$file))[-1]);
 my @songa = pss($metastuff->{_TRACKNUM});


 $rh{artist}   = getutf8($metastuff->{_ARTIST} || "Unknown Artist");
 $rh{album}    = getutf8($metastuff->{_ALBUM}  || "Unknown Album");
 $rh{title}    = getutf8($metastuff->{_TITLE}  || $cf || "Unknown Title");
 $rh{genre}    = getutf8($metastuff->{_GENRE}  || "");
 $rh{songs}    = int($songa[1]);
 $rh{songnum}  = int($songa[0]); 
 $rh{comment}  = getutf8($metastuff->{_COMMENT} || $metastuff->{FORMAT}." file");
 $rh{fdesc}    = getutf8($metastuff->{_VENDOR} || "Converted using $encoder"); 


 return {ref=>\%rh, encoder=>$encoder, codec=>$NN_HEADERS->{$buff}->{ftyp} };
}




#######################################################################
# Check if the QTparser thinks, it's a QT-AAC (= m4a) file
sub __is_qt {
 my($file) = @_;
 my $ret = GNUpod::QTfile::parsefile($file);
 return undef unless $ret; #No QT file
 
 my %rh = ();
 if($ret->{time} < 1) {
  warn "QTfile parsing failed, (expected $ret->{time} >= 0)!\n";
  warn "You found a bug - send an email to: pab\@blinkenlights.ch\n";
  return undef;
 }
 
 my $cf = ((split(/\//,$file))[-1]);
 $rh{songs}     = int($ret->{tracks});
 $rh{songnum}   = int($ret->{tracknum});
 $rh{cds}       = int($ret->{cds});
 $rh{cdnum}     = int($ret->{cdnum});
 $rh{srate}     = int($ret->{srate});
 $rh{time}      = int($ret->{time});
 $rh{bitrate}   = int($ret->{bitrate});
 $rh{filesize}  = int($ret->{filesize});
 $rh{fdesc}     = getutf8($ret->{fdesc});
 $rh{artist}    = getutf8($ret->{artist}   || "Unknown Artist");
 $rh{album}     = getutf8($ret->{album}    || "Unknown Album");
 $rh{title}     = getutf8($ret->{title}    || $cf || "Unknown Title");
 $rh{genre}     = _get_genre( getutf8($ret->{genre} || $ret->{gnre} || "") );
 $rh{composer}  = getutf8($ret->{composer} || ""); 
 $rh{soundcheck}= _parse_iTunNORM($ret->{iTunNORM});
 return  ({codec=>$ret->{_CODEC}, ref=>\%rh});
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

 
  my %rh = ();
  $rh{bitrate}  = $bps;
  $rh{filesize} = $size;
  $rh{srate}    = $srate;
  $rh{time}     = int(1000*$size/$bps);
  $rh{fdesc}    = "RIFF Audio File";
  #No id3 tags for us.. but mmmmaybe...
  #We use getuft8 because you could use umlauts and such things :)  
  #Fixme: absolute versus relative paths :
  $rh{title}    = getutf8(((split(/\//, $file))[-1]) || "Unknown Title");
  $rh{album} =    getutf8(((split(/\//, $file))[-2]) || "Unknown Album");
  $rh{artist} =   getutf8(((split(/\//, $file))[-3]) || "Unknown Artist");


return \%rh;
}

######################################################################
# Read mp3 tags, return undef if file is not an mp3
sub __is_mp3 {
 my($file,$flags) = @_;
 
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
 
 my $h =undef;
 my $hs=undef;
 
 $h = MP3::Info::get_mp3tag($file,1)     unless $flags->{'noIDv1'};  #Get the IDv1 tag
 $hs = MP3::Info::get_mp3tag($file, 2,1) unless $flags->{'noIDv2'};  #Get the IDv2 tag


 #The IDv2 Hashref may return arrays.. kill them :)
 foreach my $xkey (keys(%$hs)) {
   if( ref($hs->{$xkey}) eq "ARRAY" ) {
    $hs->{$xkey} = join(":", @{$hs->{$xkey}});
   } 
 }


#IDv2 is stronger than IDv1..
 #Try to parse things like 01/01
 my @songa = pss(getutf8($hs->{TRCK} || $hs->{TRK} || $h->{TRACKNUM}));
 my @cda   = pss(getutf8($hs->{TPOS}));
 
     $rh{songs}    = int($songa[1]);
     $rh{songnum} =  int($songa[0]);
     $rh{cdnum}   =  int($cda[0]);
     $rh{cds}    =   int($cda[1]);
     $rh{year} =     getutf8($hs->{TYER} || $hs->{TYE} || $h->{YEAR}    || 0);
     $rh{title} =    getutf8($hs->{TIT2} || $hs->{TT2} || $h->{TITLE}   || $cf || "Untitled");
     $rh{album} =    getutf8($hs->{TALB} || $hs->{TAL} || $h->{ALBUM}   || "Unknown Album");
     $rh{artist} =   getutf8($hs->{TPE1} || $hs->{TP1} || $h->{ARTIST}  || "Unknown Artist");
     $rh{genre} =    _get_genre( getutf8($hs->{TCON} || $hs->{TCO} || $h->{GENRE}   || "") );
     $rh{comment} =  getutf8($hs->{COMM} || $hs->{COM} || $h->{COMMENT} || "");
     $rh{composer} = getutf8($hs->{TCOM} || $hs->{TCM} || "");
     $rh{playcount}= int(getutf8($hs->{PCNT} || $hs->{CNT})) || 0;
     $rh{soundcheck} = _parse_iTunNORM(getutf8($hs->{COMM} || $hs->{COM} || $h->{COMMENT}));
 return \%rh;
}

########
# Guess a genre
sub _get_genre {
 my ($string) = @_;
 my $num_to_txt = undef;
 if($string =~ /^\((\d+)\)$/) {
  $num_to_txt = $mp3_genres[$1];
 }
 return ($num_to_txt || $string);
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

 return undef unless $in; #Do not fsckup empty input

 #Get the ENCODING
 $in =~ s/^(.)//;
 my $encoding = $1;

 # -> UTF16 with or without BOM
 if(ord($encoding) == 1 || ord($encoding) == 2) {
  my $bfx = Unicode::String::utf16($in); #Object is utf16
  $bfx->byteswap if $bfx->ord == 0xFFFE;
  $in = $bfx->utf16; #Return utf16 version
 }
 # -> UTF8
 elsif(ord($encoding) == 3) {
  my $bfx = Unicode::String::utf8($in)->utf8; #Paranoia
  $in = $bfx;
 }
 # -> INVALID
 elsif(ord($encoding) > 0 && ord($encoding) < 32) {
   warn "FileMagic.pm: warning: unsupportet ID3 Encoding found: ".ord($encoding)."\n";
   warn "                       send a bugreport to pab\@blinkenlights.ch\n";
   return undef;
 }
 # -> 0 or nothing
 else {
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

##############################
# Parse iTunNORM string
# FIXME: result isn't the same as iTunes sometimes..
sub _parse_iTunNORM {
 my($string) = @_;
 if($string =~ /^(engiTunNORM\s|\s)(\S{8})\s(\S{8})\s/) {
  return oct("0x".$3);
 }
 return undef;
 
}

#########################################################
# Start the converter
sub kick_convert {
 my($prog, $file, $format, $con) = @_;

 $prog = "$con->{bindir}/$prog";

 open(KICKOMATIC, "-|") or exec($prog, $file, "GET_$format") or die "FileMagic::kick_convert: Could not exec $prog\n";
  my $newP = <KICKOMATIC>;
  chomp($newP);
 close(KICKOMATIC);
 
 if($newP =~ /^PATH:(.+)$/) {
  return $1;
 }
 return undef;
}


#########################################################
# Read metadata from converter
sub converter_readmeta {
 my($prog, $file, $con) = @_;

 $prog = "$con->{bindir}/$prog";


 my %metastuff = ();
 open(CFLAC, "-|") or exec($prog, $file, "GET_META") or die "converter_readmeta: Could not exec $prog\n";
  while(<CFLAC>) {
   chomp($_);
   if($_ =~ /^([^:]+):(.*)$/) {
    $metastuff{$1} = $2;
   }
  }
  close(CFLAC);
 return undef unless $metastuff{FORMAT};
 return \%metastuff;
}

1;

