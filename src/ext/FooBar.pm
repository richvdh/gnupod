package GNUpod::FooBar;
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

sub connect {
 my($opth) = @_;
 
 my($mp, $itb, $xml) = undef;

 my $stat = "No mountpoint defined / missing in and out file";
unless(!$opth->{mount} && (!$opth->{itunes} || !$opth->{xml})) {
  $itb = $opth->{itunes} || $opth->{mount}."/iPod_Control/iTunes/iTunesDB";
  $xml = $opth->{xml} || $opth->{mount}."/iPod_Control/.gnupod/GNUtunesDB";
  $mp = $opth->{mount};
  $stat = undef;
}
 
 return ($stat, $itb, $xml, $mp);
}


sub shx2int {
 my($shx) = @_;
 my $buff = undef;
   foreach(split(//,$shx)) {
    $buff = sprintf("%02X",ord($_)).$buff;
   }
  return hex($buff);
   
}

1;
