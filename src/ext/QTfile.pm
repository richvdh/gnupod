package GNUpod::QTfile;

#  Copyright (C) 2003-2004 Adrian Ulrich <pab at blinkenlights.ch>
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

# A poor QT Parser, can (sometimes ;) ) read m4a files written
# by iTunes

use strict;
use GNUpod::FooBar;
use vars qw(%hchild %reth @LEVELA);

#Some static def
$hchild{'moov'} = 8;
$hchild{'trak'} = 8;
$hchild{'edts'} = 8;
$hchild{'mdia'} = 8;
$hchild{'minf'} = 8;
$hchild{'dinf'} = 8;
$hchild{'stbl'} = 8;
$hchild{'udta'} = 8;
$hchild{'meta'} = 12;
$hchild{'ilst'} = 8;
$hchild{'----'} = 8;
$hchild{'day'} = 8;
$hchild{'cmt'} = 8;
$hchild{'disk'} = 8;
$hchild{'wrt'} = 8;
$hchild{'dinf'} = 8;
$hchild{'©grp'} = 8;
$hchild{'©too'} = 8;
$hchild{'©nam'} = 8;
$hchild{'©ART'} = 8;
$hchild{'©alb'} = 8;
$hchild{'©gen'} = 8;
$hchild{'©cmt'} = 8;
$hchild{'©wrt'} = 8;
$hchild{'©day'} = 8;
$hchild{'trkn'} = 8;
$hchild{'tmpo'} = 8;
$hchild{'disk'} = 8;


##Call this to parse a file
sub parsefile {
 my($qtfile) = @_;
 
 
 open(QTFILE, $qtfile) or return undef;

 my $fsize = -s "$qtfile";
 my $pos = 0;
 my $level = 1;
 my %lx = ();
    %reth = (); #Cleanup

 if($fsize < 16 || rseek(4,4) ne "ftyp") { #Can't be a QTfile
  close(QTFILE);
  return undef;
 }
 

 #Ok, header looks okay.. seek each atom and buildup $lx{metadat}
 while($pos<$fsize) {
  my($clevel, $len) = get_atom($level, $pos, \%lx);
  unless($len) {
    warn "** Unexpected data found at $pos!\n";
    warn "** You found a bug! Please send a bugreport\n";
    warn "** to pab\@blinkenlights.ch\n";
    warn "** GIVING UP PARSING\n";
    last;
  }
  $pos+=$len;
  $level = $clevel;
 }
 close(QTFILE);
 
 
########### Now we build the chain #######################################
my @METADEF = ("album",   "\xA9alb",
               "comment", "\xA9cmt",
               "genre",   "\xA9gen",
               "group",   "\xA9grp",
               "composer","\xA9wrt",
               "artist",  "\xA9ART",
               "title",   "\xA9nam",
               "fdesc",   "\xA9too",
               "year",    "\xA9day",
               "comment", "\xA9cmt");

###All STRING fields..
 for(my $i = 0;$i<int(@METADEF);$i+=2) {
  my $cKey = "::moov::udta::meta::ilst::".$METADEF[$i+1]."::data";
  if($lx{metadat}{$cKey}[0]) {
   $reth{$METADEF[$i]} = $lx{metadat}{$cKey}[0];
  }
 }

###INT and such fields are here:
 
 if( my $cDat = $lx{metadat}{'::moov::udta::meta::ilst::tmpo::data'}[0] ) {
  $reth{bpm} = GNUpod::FooBar::shx2_x86_int($cDat);
 }
 
 if( my $cDat = $lx{metadat}{'::moov::udta::meta::ilst::trkn::data'}[0]) {
   $reth{tracknum} = GNUpod::FooBar::shx2_x86_int(substr($cDat,2,2));
   $reth{tracks}   = GNUpod::FooBar::shx2_x86_int(substr($cDat,4,2));  
 }

 if( my $cDat = $lx{metadat}{'::moov::udta::meta::ilst::disk::data'}[0]) {
   $reth{cdnum} = GNUpod::FooBar::shx2_x86_int(substr($cDat,2,2));
   $reth{cds}   = GNUpod::FooBar::shx2_x86_int(substr($cDat,4,2));  
 }
 

 if( my $cDat = $lx{metadat}{'::moov::mvhd'}[0] ) {
 #Calculate the time... 
 $reth{time} = int( get_string_oct(8,4,$cDat)/
                    get_string_oct(4,4,$cDat)*1000 );
 }
 
 #Get FX-Apple iTunNORM field
 if(ref($lx{metadat}{'::moov::udta::meta::ilst::----::data'}) eq "ARRAY") { #Exists!
  for(my $i=0; $i<int(@{$lx{metadat}{'::moov::udta::meta::ilst::----::data'}});$i++) {
     if($lx{metadat}{'::moov::udta::meta::ilst::----::mean'}[$i] eq "apple.iTunes" &&
        $lx{metadat}{'::moov::udta::meta::ilst::----::name'}[$i] eq "NORM") {
       $reth{iTunNORM} = $lx{metadat}{'::moov::udta::meta::ilst::----::data'}[$i];
     }
  }
 }
 
 if( my $cDat = $lx{metadat}{'::moov::trak::mdia::minf::stbl::stsd'}[0] ) {
  $reth{_CODEC} = substr($cDat,4,4);
  $reth{srate}  = get_string_oct(32,2,$cDat);
  #Fixme: Bitrate should be in stsd
 }
 $reth{filesize} = $fsize;
 return \%reth;
}

############################################################
# Get a single ATOM
sub get_atom {
 my($level, $pos, $lt) = @_;

 my $len = getoct($pos,4); #Length of field
 #Error
 return(undef, undef) if $len < 8;
 
 #Now get the type
 my $typ = rseek($pos+4,4);
 #..and keep track of it..
 $level = $lt->{ltrack}->{$pos} if $lt->{ltrack}->{$pos};

 #Build a chain for this level.. looks like '::foo::bar::bla'
 $LEVELA[$level] = $typ;
 my $cChain = undef;
 for(1..$level) {
  $cChain .= "::".$LEVELA[$_];
 }

  if(defined($hchild{$typ})) { #This type has a child
   #Track the old level
   $lt->{ltrack}->{$pos+$len} = $level unless $lt->{ltrack}->{$pos+$len};
   #Go to the next
   $level++;
   #Fix len
   $len = $hchild{$typ};
  }
  elsif($len >= 16 && $cChain !~ /(::mdat|::free)$/) {  #No child -> final element -> data!
#   print "+$cChain ($len)\n";
   push(@{$lt->{metadat}->{$cChain}},rseek($pos+16,$len-16));
  }

 return($level,$len);
}




###################################################
# Get INT vaules
sub getoct {
my($offset, $len) = @_;
  GNUpod::FooBar::shx2_x86_int(rseek($offset,$len));
}


###################################################
# Get INT vaules from string
sub get_string_oct {
my($offset, $len, $string) = @_;

 if($offset+$len > length($string)) {
  warn "Bug: invalid substr() call! Returning 0\n";
  return 0;
 }
 
  GNUpod::FooBar::shx2_x86_int(substr($string,$offset,$len));
}

####################################################
# Raw seeking
sub rseek {
 my($offset, $len) = @_;
 return undef if $len < 0;
 my $buff;
 seek(QTFILE, $offset, 0);
 read(QTFILE, $buff, $len);
 return $buff;
}

1;
