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
use vars qw(%hchild %reth);

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

sub parsefile {
 my($qtfile) = @_;
 open(QTFILE, $qtfile) or return undef;

 my $fsize = -s "$qtfile";
 my $pos = 0;
 my $level = 1;
 my %lx = ();

 if($fsize < 16 || rseek(4,4) ne "ftyp") {
  return undef;
 }

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
 $reth{filesize} = $fsize;
 return \%reth;
}

############################################################
# Get a single ATOM
sub get_atom {
 my($level, $pos, $lt) = @_;

 my $len = getoct($pos,4);
 #Error
 return(undef, undef) if $len < 1;
 my $typ = rseek($pos+4,4);
 
 $level = $lt->{ltrack}->{$pos} if $lt->{ltrack}->{$pos};
 $lt->{topic}->{$level} = $typ;

#print "_" x $level;
#print int($level)."] \@$pos L $len -> $typ \n";
#print " parent : ".$lt->{"topic_".($level-1)}."\n";

 if($typ eq "data") {
  return(undef,undef) if $len < 16;
  my $parent =$lt->{topic}->{$level-1};
  my $dat = rseek($pos+16,$len-16);
  if($parent eq "©alb") {
   $reth{album} = $dat;
  }
  elsif($parent eq "©cmt") {
   $reth{comment} = $dat;
  }
  elsif($parent eq "©gen") {
   $reth{genre} = $dat;
  }
  elsif($parent eq "©grp") {
   $reth{group} = $dat;
  }
  elsif($parent eq "©wrt") {
   $reth{composer} = $dat;
  }
  elsif($parent eq "©ART") {
   $reth{artist} = $dat;
  }
  elsif($parent eq "©nam") {
   $reth{title} = $dat;
  }
  elsif($parent eq "©too") {
   $reth{fdesc} = $dat;
  }
  elsif($parent eq "©day") {
   $reth{year} = $dat;
  }
  elsif($parent eq "tmpo") {
    $reth{bpm} = GNUpod::FooBar::shx2_x86_int($dat);
  }
  elsif($parent eq "trkn") {
   $reth{tracknum} = GNUpod::FooBar::shx2_x86_int(substr($dat,2,2));
   $reth{tracks}   = GNUpod::FooBar::shx2_x86_int(substr($dat,4,2));
  }
  elsif($parent eq "disk") {
   $reth{cdnum} = GNUpod::FooBar::shx2_x86_int(substr($dat,2,2));
   $reth{cds}   = GNUpod::FooBar::shx2_x86_int(substr($dat,4,2));
  }
  elsif($parent eq "----" or $parent eq "disk") {
   #Do nothing.. iTunes does this fields and we
   #don't need to warn about this..
  }
  else {
   warn "QTfile warning: Skipping $typ -> $parent [<-- unknown field]\n";
  }
 }
 elsif($typ eq "mvhd") {
  $reth{time} = int(getoct($pos+24,4)/getoct($pos+20,4)*1000);
 }

  if(defined($hchild{$typ})) { #This type has a child
   #Track the old level
   $lt->{ltrack}->{$pos+$len} = $level unless $lt->{ltrack}->{$pos+$len};
   #Go to the next
   $level++;
   #Fix len
   $len = $hchild{$typ};
  }
 return($level,$len);
}




###################################################
# Get INT vaules
sub getoct {
my($offset, $len) = @_;
  GNUpod::FooBar::shx2_x86_int(rseek($offset,$len));
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
