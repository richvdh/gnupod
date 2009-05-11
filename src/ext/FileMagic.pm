package GNUpod::FileMagic;
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
use Unicode::String;
use MP3::Info qw(:all);
use GNUpod::FooBar;
use GNUpod::QTfile;

use constant MEDIATYPE_AUDIO => 0x01;
use constant MEDIATYPE_VIDEO => 0x02;



=pod

=head1 NAME

GNUpod::FileMagic - Convert media files to iPod compatible formats and/or extract technical information and meta information (tags) from media files.

=head1 DESCRIPTION

=over 4

=cut

#
# How to add a converter:
# 1. Define the first 4 bytes in NN_HEADERS
# 2. write a decoder: gnupod_convert_BLA.pl
# done!
#

my $NN_HEADERS = {'MThd' => { encoder=>'gnupod_convert_MIDI.pl', ftyp=>'MIDI'},
                  'fLaC' => { encoder=>'gnupod_convert_FLAC.pl', ftyp=>'FLAC'},
                  'OggS' => { encoder=>'gnupod_convert_OGG.pl',  ftyp=>'OGG' },
                  'MAC ' => { encoder=>'gnupod_convert_APE.pl',  ftyp=>'APE' },
                  'RIFF' => { encoder=>'gnupod_convert_RIFF.pl', ftyp=>'RIFF', magic2=>'AVI '}};




BEGIN {
 MP3::Info::use_winamp_genres(); # Import winamp genres
 MP3::Info::use_mp3_utf8(1);     # Force-Enable UTF8 support
  open(NULLFH, "> /dev/null") or die "Could not open /dev/null, $!\n";
}

########################################################################

=item wtf_is(FILE, FLAGS, CONNECTION)

Tries to discover the file format (mp3 or QT (AAC)). For MP3, QT(AAC) and
PCM files it calls other sub routines to extracts the meta information
from file tags or filename. For other formats it calls external decoders
and converters to convert the $file into something iPod compatible and to
extract the meta/media information.

FLAGS is a hash that may contain a true value for the keys 'noIDv1', 'noIDv2'
and 'noAPE' if you want to skip the extraction of ID3v1, ID3v2 or APE tags
from MP3 files. APE tags are always read in conjunction with ID3 tags.
Disabling the use of both ID3v1 and ID3v2 tags also disables the reading
of APE tags from MP3 files. Set a true value for the key 'rgalbum' if you
want to use the album ReplayGain value instead of the track ReplayGain
value (default).

Returns:

=over 8

=item * a hash with information extracted from the file's meta information (aka. tags),

=item * a hash with format information

=item * the name of the external decoder if any was used.

=back

Example:

        (%metainfo, %mediainfo, $converter_used) = wtf_is($file, $flags, $con);
	print "Title: $metainfo{'title'}\nArtist: $metainfo{'artist'}\nAlbum: $metainfo{'album'}\n";
	print "Type: $mediainfo{'ftyp'}\nFormat: $mediainfo{'format'}\n";
	print "Converter: $converter_used\n" if defined($converter_used);

=cut

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
		return ($xqt->{ref},  {ftyp=>$xqt->{codec}, format=>"m4a", extension=>"m4a|m4p|m4b|mp4|m4v"});
	}
	elsif(my $h = __is_pcm($file,$flags)) {
		return ($h, {ftyp=>"PCM", format=>"wav"});
	}
	elsif(my $h = __is_mp3($file,$flags)) {
		return ($h, {ftyp=>"MP3", format=>"mp3"});
	}
	#Still no luck..
	return (undef, undef, undef);
}

########################################################################
#Handle Non-Native files :)

=item __is_NonNative(FILE, FLAGS, CONNECTION)

Tries to guess the filetype by extracting magic numbers from the file's beginning.
The extracted $magic (from the first four bytes) and $magic2 (from bytes 8 to 11)
are used to find an ecoder in %FileMagic::NN_HEADERS.


Returns a hash with:
        ref     => HASHREF     containing the meta information.
        encoder => STRING      filename of the encoder used
        codec   => STRING      file type ("FLAC", "OGG", "RIFF" ...)

=cut

sub __is_NonNative {
	my($file, $flags, $con) = @_;
	return undef unless $flags->{decode}; #Decoder is OFF per default!
	
	my $size = (-s $file);
	my $magic = undef;
	my $magic2= undef;
	
	return undef if $size < 12;
	open(TNN, $file) or return undef;
	binmode(TNN);
	seek(TNN,0,0);
	read(TNN,$magic,4);
	seek(TNN,8,0);
	read(TNN,$magic2,4);
	close(TNN);
	
	
	my $encoder = $NN_HEADERS->{$magic}->{encoder};
	return undef unless $encoder; # No encoder -> Not supported magic
	
	if(defined($NN_HEADERS->{$magic}->{magic2}) && $magic2 ne $NN_HEADERS->{$magic}->{magic2}) {
		# Submagic failed (currently only used for RIFF-AVI)
		return undef;
	}
	
	#Still here? -> We know how to decode this stuff
	my $metastuff = converter_readmeta($encoder, $file, $con);
	return undef unless ref($metastuff) eq "HASH"; #Failed .. hmm
	
	my %rh = ();
	my $cf = ((split(/\//,$file))[-1]);
	my @songa = pss($metastuff->{_TRACKNUM});
	
	# Use track ReplayGain by default, use album ReplayGain if requested
	my $rgtag = "_REPLAYGAIN_TRACK_GAIN";
	$rgtag = "_REPLAYGAIN_ALBUM_GAIN" if($flags->{'rgalbum'});

	$rh{artist}    = getutf8($metastuff->{_ARTIST} || "Unknown Artist");
	$rh{album}     = getutf8($metastuff->{_ALBUM}  || "Unknown Album");
	$rh{title}     = getutf8($metastuff->{_TITLE}  || $cf || "Unknown Title");
	$rh{genre}     = getutf8($metastuff->{_GENRE}  || "");
	$rh{songs}     = int($songa[1]);
	$rh{songnum}   = int($songa[0]);
	$rh{comment}   = getutf8($metastuff->{_COMMENT} || $metastuff->{FORMAT}." file");
	$rh{fdesc}     = getutf8($metastuff->{_VENDOR}  || "Converted using $encoder");
	$rh{soundcheck} = _parse_ReplayGain($metastuff->{$rgtag}) || "";
	$rh{mediatype} = int($metastuff->{_MEDIATYPE}   || MEDIATYPE_AUDIO);
	return {ref=>\%rh, encoder=>$encoder, codec=>$NN_HEADERS->{$magic}->{ftyp} };
}




#######################################################################
# Check if the QTparser thinks, it's a QT-AAC (= m4a) file

=item __is_qt(FILE)

Tries to extract the relevant information from FILE using GNUpod::QTfile::parsefile()

Returns undef if FILE is no QT file. Otherwise returns a hash with:
        ref     => HASHREF     containing the meta information.
        codec   => STRING      the codec name

=cut

sub __is_qt {
 my($file) = @_;
 my $ret = GNUpod::QTfile::parsefile($file);
 return undef unless $ret; #No QT file

 my %rh = ();
 if($ret->{time} < 1) {
  warn "QTfile parsing failed, (expected \$ret->{time} >= 0)!\n";
  warn "Looks like we got no sound stream.. hmm..\n";
  warn "You found a bug - send an email to: pab\@blinkenlights.ch\n";
  return undef;
 }

 my $cf = ((split(/\//,$file))[-1]);
 $rh{songs}      = int($ret->{tracks});
 $rh{songnum}    = int($ret->{tracknum});
 $rh{cds}        = int($ret->{cds});
 $rh{cdnum}      = int($ret->{cdnum});
 $rh{srate}      = int($ret->{srate});
 $rh{time}       = int($ret->{time});
 $rh{bitrate}    = int($ret->{bitrate});
 $rh{filesize}   = int($ret->{filesize});
 $rh{fdesc}      = getutf8($ret->{fdesc});
 $rh{artist}     = getutf8($ret->{artist}   || "Unknown Artist");
 $rh{album}      = getutf8($ret->{album}    || "Unknown Album");
 $rh{title}      = getutf8($ret->{title}    || $cf || "Unknown Title");
 $rh{genre}      = _get_genre( getutf8($ret->{genre} || $ret->{gnre} || "") );
 $rh{composer}   = getutf8($ret->{composer} || "");
 $rh{soundcheck} = _parse_iTunNORM($ret->{iTunNORM});
 $rh{mediatype}  = int($ret->{mediatype} || MEDIATYPE_AUDIO);
 return  ({codec=>$ret->{_CODEC}, ref=>\%rh});
}

######################################################################
# Check if the file is an PCM (WAVE) File

=item __is_pcm(FILE)

Tries to extract the relevant information from FILE. For a WAVE file this
is usually limited to technical information like sample rate and resolution.
If however FILE is a path that contains directory names, then the directory
structure "[[<artist>/]<album>/]<title>.wav" is assumed.

Returns a hash with:
        ref     => HASHREF     containing the meta information.

=cut

sub __is_pcm {
 my($file) = @_;

	my $size = (-s $file);
	return undef if $size < 32;
	open(PCM, "$file") or return undef;
	binmode(PCM);
	#Get the group id and riff type
	my ($gid, $rty, $buff,$srate,$bps) = undef;
	
	seek(PCM, 0, 0);
	read(PCM, $gid, 4);
	seek(PCM, 8, 0);
	read(PCM, $rty, 4);
	
	seek(PCM, 24,0);
	read(PCM,$buff,4);
	$srate = GNUpod::FooBar::shx2int($buff);
	
	seek(PCM, 28, 0);
	read(PCM,$buff,4);
	$bps = GNUpod::FooBar::shx2int($buff);
	close(PCM);
	
	return undef if $gid ne "RIFF";
	return undef if $rty ne "WAVE";

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
	$rh{mediatype}  = MEDIATYPE_AUDIO;
return \%rh;
}


######################################################################
# Flatten deep data structures

=item __flatten(REF[,EXCLUDE])

Tries to flatten complex data structures to a single string.
Currently also removes null characters that may have been added to
tags by programmers of languages that use null terminated strings.


Strings are returned as strings.
Arrays returned as a string with the array elements joined by " / ".
Hashes are returned like arrays of "<key> : <value>" strings or just
"<key>" strings if the value is undefined or an empty string.

With EXCLUDE you can pass on a regular expression to exlclude certain
strings from the result.

Example:
        $nonitunescomment = __flatten($comref, "^iTun");

=cut

sub __flatten {
	my ($in,$exclude) = @_;
	if (!defined($in)) { return undef; }
	if ( (ref($in) eq "") && (ref(\$in) eq "SCALAR") ) {
		my $out = $in;
		$out =~ s/\x0//g;
		if (defined($exclude) && ($out =~ /$exclude/)) { return undef; }
		return $out;
	}
	if ( ref($in) eq "ARRAY" ) {
		my @out=();
		foreach (@{$in}) {
			my $flat = __flatten($_, $exclude);
			if (!defined($flat)) { next; }
			push  @out, $flat;
		}
		if (@out) {
			return join(" / ", @out);
		} else {
			return undef;
		}
	}
	if ( ref($in) eq "HASH" ) {
		my @out = ();
		foreach (keys(%{$in})) {
			my $kvp = __flatten($_, $exclude); # key
			next if !defined($kvp);
			my $v = __flatten(%{$in}->{$_}, $exclude); # value
			$kvp .= " : ".$v     if (defined($v) && ("$v" ne ""));
			push @out, $kvp;
		}
		if (@out) {
			return __flatten(\@out,$exclude);
		} else {
			return undef;
		}
	}
}

######################################################################
# Join strings if their content is different. skip strings if they are
# completely contained in the other ones

=item __merge_strings(OPTIONS,STRING1,STRING2,...)

Takes strings and joins them. A string is not added if it is already
contained in the other(s).

Joining takes place left to right.

OPTIONS is a hasref with the following data:

        joinby => STRING      String used in joining the others. (default:" ")

        wspace => "asis"|"norm"|"kill"  This sets the way whitespace characters
          are handled during the comparison. (default:"asis")
          "asis"  Leave whitespace as it is. "a b" and "a  b" are seen as different.
          "norm"  Normalize whitespaces to a single space. "a b" and "a\t\n \t b"
                  are seen as the same.
          "kill"  Kill whitespace before comparing. "a b" and "ab" are seen as the same.

        case => "check"|"ignore"  Sets the way case differences are handled. (default:"check")
          "check"  Regard case differences as important. "a" and "A" are different.
          "ignore" Discard case differences. "a" and "A" are the same.

Returns the joined string. Empty string is returned if only emtpy strings or undefined values where joined.

Usage example:
        $x = __merge_strings({ joinby => "/",
                               whitespace => "norm",
                               case => "ignore"},
                             "a  a", "a A b", "foo", "Foo", "B/F" );
        #returns "a A b/foo"

=cut

sub __merge_strings {
	my $options = shift(@_);
	my $joinby = " ";
	my $wspace = "asis";
	my $case = "check";

	if (ref($options) eq "HASH") {
		$joinby = %{$options}->{joinby}        if defined(%{$options}->{joinby});
		$wspace = lc(%{$options}->{wspace})    if defined(%{$options}->{wspace});
		$case   = lc(%{$options}->{case})      if defined(%{$options}->{case});
	}
	my $merged = "";

	foreach (@_) {
		# only merge non-empty strings
		next if (!defined($_) || ("$_" eq ""));

		my $left = $merged;
		my $right = $_;

		if ($wspace eq "norm") {
			$left  =~ s/\s+/ /g;
			$right =~ s/\s+/ /g;
		} elsif ($wspace eq "kill") {
			$left  =~ s/\s+//g;
			$right =~ s/\s+//g;
		}
		if ($case eq "ignore") {
			$left  = lc($left);
			$right = lc($right);
		}
		
		if (index($left,$right) >= 0) {next;} # $_ already contained
		if (index($right,$left) >= 0) {$merged = $_; next;} # $_ is a superset
		$merged = join ( $joinby, $merged, $_);
	}
	return $merged;
}

######################################################################
# Read mp3 tags, return undef if file is not an mp3

=item __is_mp3(FILE, FLAGS)

Tries to extract the meta information from FILE using MP3::Info.

FLAGS is a hash that may contain a true value for the keys 'noIDv1' and 'noIDv2' if
you want to skip the extraction of ID3v1 or ID3v2 tags from MP3 files.

Returns undef if MP3::Info::get_mp3info failes or says that the file
has zero frames.

Otherwise returns a HASHREF containing the meta information.

=cut

sub __is_mp3 {
	my($file,$flags) = @_;
	
	my $h  = MP3::Info::get_mp3info($file);
	my $hs = undef;
	if(ref($h) ne 'HASH') {
		return undef; # Not an mp3 file
	}
	elsif($h->{FRAMES} == 0) {
		return undef; # Smells fishy..
	}
	
	
	#This is our default fallback:
	#If we didn't find a title, we'll use the
	#Filename.. why? because you are not able
	#to play the file without an filename ;)
	my $cf = ((split(/\//,$file))[-1]);
	
	my %rh = ();
	$rh{bitrate}  = $h->{BITRATE};
	$rh{filesize} = $h->{SIZE};
	$rh{srate}    = int($h->{FREQUENCY}*1000);
	$rh{time}     = int($h->{SECS}*1000);
	$rh{fdesc}    = "MPEG ${$h}{VERSION} layer ${$h}{LAYER} file";
	
	$h  = MP3::Info::get_mp3tag($file,1,0,$flags->{'noAPE'}?0:1) unless $flags->{'noIDv1'};  #Get the IDv1 tag
	$hs = MP3::Info::get_mp3tag($file,2,2,$flags->{'noAPE'}?0:1) unless $flags->{'noIDv2'};  #Get the IDv2 tag
	
	my $nonitunescomment = undef;
	#The IDv2 Hashref may return arrays.. kill them :)
	foreach my $xkey (keys(%$hs)) {
		if ($xkey =~ /^COM[ M]?$/) {
			my $comref = $hs->{$xkey};
			#use Data::Dumper;
			#print Dumper($comref);
			$nonitunescomment = __flatten($comref,"^iTun");
			#print Dumper($nonitunescomment);
		}
		if (($xkey ne "APIC") && ($xkey ne "PIC")) {
			$hs->{$xkey} = __flatten($hs->{$xkey});
		}
	}


	#IDv2 is stronger than IDv1..
	#Try to parse things like 01/01
	my @songa = pss($hs->{TRCK} || $hs->{TRK} || $h->{TRACKNUM});
	my @cda   = pss($hs->{TPOS});

	# Use track ReplayGain by default, use album ReplayGain if requested
	my $rgtag = "REPLAYGAIN_TRACK_GAIN";
	$rgtag = "REPLAYGAIN_ALBUM_GAIN" if($flags->{'rgalbum'});
	
	$rh{songs}      = int($songa[1]);
	$rh{songnum}    = int($songa[0]);
	$rh{cdnum}      = int($cda[0]);
	$rh{cds}        = int($cda[1]);
	$rh{year}       = ($hs->{TYER} || $hs->{TYE} || $h->{YEAR}    || 0);
	$rh{title}      = ($hs->{TIT2} || $hs->{TT2} || $h->{TITLE}   || $cf || "Untitled");
	$rh{album}      = ($hs->{TALB} || $hs->{TAL} || $h->{ALBUM}   || "Unknown Album");
	$rh{artist}     = ($hs->{TPE1} || $hs->{TP1} || $hs->{TPE2}   || $hs->{TP2} || $h->{ARTIST}  || "Unknown Artist");
	$rh{genre}      = _get_genre($hs->{TCON} || $hs->{TCO} || $h->{GENRE}   || "");
	$rh{comment}    = ($hs->{COMM} || $hs->{COM} || $h->{COMMENT} || "");
	$rh{desc}       = __merge_strings({joinby => " ", wspace => "norm", case => "ignore"},($hs->{USLT} || $hs->{ULT}),($nonitunescomment || $h->{COMMENT}));
	$rh{composer}   = ($hs->{TCOM} || $hs->{TCM} || "");
	$rh{playcount}  = int($hs->{PCNT} || $hs->{CNT}) || 0;
	$rh{soundcheck} = _parse_iTunNORM($hs->{COMM} || $hs->{COM} || $h->{COMMENT}) unless defined($rh{soundcheck} = _parse_ReplayGain($hs->{$rgtag} || $h->{$rgtag}));
	$rh{mediatype}  = MEDIATYPE_AUDIO;

	# Handle volume adjustment information
	if ($hs->{RVA2} or $hs->{XRVA}) {
		# if XRVA is present, handle it like RVA2 (http://www.id3.org/Experimental_RVA2)
		$hs->{RVA2} = $hs->{XRVA} if (!defined($hs->{RVA2}) && defined($hs->{XRVA}));
		# Very limited RVA2 parsing, only handle master volume changes.
		# See http://www.id3.org/id3v2.4.0-frames for format spec
		my ($app, $channel, $adj) = unpack("Z* C n", $hs->{RVA2});
		if ($channel == 1) {
			
			$adj -= 0x10000 if ($adj > 0x8000);
			my $adjdb = $adj / 512.0;
			# Translate decibel volume adjustment into relative percentage
			# adjustment.  As far as I understand this, +6dB is perceived
			# as the double volume, i.e. +100%, while -6dB is
			# perceived as the half volume, i.e. -50%.
			# The dB volume adjustment adjdb correlates to the absolute
			# adjustment adjabs like this:
			#     adjdb = 20 * log10(1 + adjabs)
			# =>  adjabs = 10 ** (adjdb / 20) - 1
			
			my $vol = int(100 * (10 ** ($adjdb / 20) - 1));
			$vol = 100 if ($vol > 100);
			$vol = -100 if ($vol < -100);
			
			# print "$file: adjusting volume by $vol% ($adjdb dB)\n";
			$rh{volume} = $vol;
		}
	}
	
	return \%rh;
}

########
# Guess a genre

=item _get_genre(GENRE)

Translates numeric GENRE into its name.

Returns a genre name if GENRE is numeric. Otherwise
GENRE is returned.

=cut

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

=item pss(STRING)

Parses song number and returns either just the song number
or the song number and the total number.

Example:
        ($i,$n)=pss("05/12"); # returns ints "5" and "12"

=cut

sub pss {
	my($string) = @_;
	if(my($s,$n) = $string =~ /(\d+)\/(\d+)/) {
		return(int($s),int($n));
	}
	else {
		return int($string);
	}
}

#########
# Try to 'auto-guess' charset and return utf8

=item getutf8(STRING)

Tries to convert whatever you thow at it into a UTF8 string.


=cut

sub getutf8 {
	my($in) = @_;
	return undef unless $in; #Do not fsckup empty input
	
	#Get the ENCODING
	$in =~ s/^(.)//;
	my $encoding = $1;
	
	# -> UTF16 with or without BOM
	if(ord($encoding) == 1 || ord($encoding) == 2) {
		# -> UTF16 with or without BOM
		my $bfx = Unicode::String::utf16($in); #Object is utf16
		$bfx->byteswap if $bfx->ord == 0xFFFE;
		$in = $bfx->utf8; #Return utf8 version
		$in =~ s/\x00+$//;         # Removes trailing 0's
		if(unpack("H*",substr($in,0,3)) eq 'efbbbf') {
			# -> Remove faulty utf16-to-utf8 BOM
			$in = substr($in,3);
		}
	}
	elsif(ord($encoding) == 3) {
		# -> UTF8
		$in =~ s/\x00+$//;         # Removes trailing 0's
		$in = Unicode::String::utf8($in)->utf8; #Paranoia
	}
	elsif(ord($encoding) > 0 && ord($encoding) < 32) {
		warn "FileMagic.pm: warning: unsupportet ID3 Encoding found: ".ord($encoding)."\n";
		warn "                       send a bugreport to adrian\@blinkenlights.ch\n";
		return undef;
	}
	else {
		$in = $encoding.$in;     # Restores input
		$in =~ tr/\0//d;         # Removes evil 0's
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
#

=item _parse_iTunNORM(STRING)

Searches STRING for a sequence of 8 hex numbers of 8 digits each
used by iTunes to describe the dynamic range.
see http://www.id3.org/iTunes_Normalization_settings

=cut

sub _parse_iTunNORM {
	my($string) = @_;
	if($string =~ /\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})\s([0-9A-Fa-f]{8})/) {
		return oct("0x".($1>$2 ? $1:$2));
	}
	return undef;
}

#########################################################
# Start the converter

=item kick_convert(PROG, QUALITY, FILE, FORMAT, CONNECTION)

Document me!

=cut

sub kick_convert {
	my($prog, $quality, $file, $format, $con) = @_;

	$prog = "$con->{bindir}/$prog";
	#Set Quality to a normal level
	$quality = 0 if $quality < 0;
	$quality = 9 if $quality > 9;
	open(KICKOMATIC, "-|") or exec($prog, $file, "GET_$format", int($quality)) or die "FileMagic::kick_convert: Could not exec $prog\n";
	binmode(KICKOMATIC);
	my $newP = <KICKOMATIC>;
	chomp($newP);
	close(KICKOMATIC);
	
	if($newP =~ /^PATH:(.+)$/) {
		return $1;
	}
	return undef;
}

#########################################################
# Start the ReEncoder

=item kick_reencode(QUALITY, FILE, FORMAT, CONNECTION)

Document me!

=cut

sub kick_reencode {
	my($quality, $file, $format, $con) = @_;
	
	$quality = int($quality);
	
	#Lame's limits
	return undef if $quality < 0; #=Excellent Quality
	return undef if $quality > 9; #=Bad Quality
	
	#Try to get an unique name
	my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_reencode", "tmp") or return undef;
	
	if($format eq 'm4a') {
		#Faac is not as nice as lame: We have to decode ourself.. and fixup the $quality value
		$quality = 140 - ($quality*10);
		my $pcmout = $tmpout.".wav";
		system( ("faad", "-o", $pcmout, $file) );
		#Ok, we've got a pcm version.. encode it!
		
		$tmpout .= ".m4a"; #Fixme: This breaks m4b.. well.. next time i'll fix it..
		my $ret = system( ("faac", "-w", "-q", $quality, "-o", $tmpout, $pcmout) );
		unlink($pcmout) or warn "FileMagic.pm: Could not unlink '$pcmout' , $!\n";
		if($ret) {
			unlink($tmpout) or warn "FileMagic.pm: Could not unlink '$tmpout', $!\n";
			return undef;
		}
		else {
			return $tmpout;
		}
	}
	elsif($format eq 'mp3') {
		$tmpout .= ".mp3";
		my $ret = system( ("lame", "--silent", "-V", $quality, $file, $tmpout) );
		if($ret) {
			#We failed for some reason..
			unlink($tmpout) or warn "FileMagic.pm: Could not unlink '$tmpout', $!\n";
		}
		else {
			return $tmpout;
		}
	}
	return undef;
}


#########################################################
# Read metadata from converter

=item converter_readmeta(PROG, FILE, CONNECTION)

Document me!

=cut

sub converter_readmeta {
	my($prog, $file, $con) = @_;
	
	$prog = "$con->{bindir}/$prog";
	my %metastuff = ();
	open(CFLAC, "-|") or exec($prog, $file, "GET_META") or die "converter_readmeta: Could not exec $prog\n";
	binmode(CFLAC);
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

=back

=cut

#########################################################
# Convert ReplayGain to SoundCheck
# Code adapted from http://projects.robinbowes.com/flac2mp3/trac/ticket/30

=item _parse_ReplayGain(VALUE)

Converts ReplayGain VALUE in dB to iTunes Sound Check value. Anything
outside the range of -18.16 dB to 33.01 dB will be rounded to those values.
For more information on ReplayGain see http://replaygain.hydrogenaudio.org/

=cut

sub _parse_ReplayGain {
	my ($gain) = @_;
	return undef unless defined($gain);
	if($gain =~ /(.*)\s+dB$/) {
		$gain = $1
	}
	return undef unless ($gain =~ /^\s*-?\d+\.?\d*\s*$/);
	my $result = int((10 ** (-$gain / 10)) * 1000 + .5);
	if ($result > 65534) {
		$result = 65534;
	}
	return oct(sprintf("0x%08X",$result));
}

1;


