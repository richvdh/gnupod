###__PERLBIN__###
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
use GNUpod::FooBar;
use GNUpod::FileMagic;

my $file  = $ARGV[0] or exit(1);
my $gimme = $ARGV[1];
my $quality = $ARGV[2];


if(!(-r $file)) {
 warn "$file is not readable!\n";
 exit(1);
}
elsif($gimme eq "GET_META") {
 my $ftag = undef;
 ## This is a UGLY trick to cheat perl!
 ## 1. Create a string
 
 my $ogg_pmod = undef;
 
 foreach my $ogg_pmod ('Ogg::Vorbis::Header::PurePerl','Ogg::Vorbis::Header') {
  my $nocompile = "use $ogg_pmod; \$ftag = $ogg_pmod->new(\$file);";
  eval $nocompile; #2. eval it!
  last unless $@;
 }
 ## 3. = no errors
 if($@) {
   warn "gnupod_convert_OGG.pl: Could not read OGG-Metadata from $file (".ref($ftag).")\n";
   warn "gnupod_convert_OGG.pl: Maybe $ogg_pmod is not installed?\n";
   warn "Error: *$@*\n";
   exit(1);
 }
 
 
print "_ARTIST:".($ftag->comment('artist'))[0]."\n";
print "_ALBUM:".($ftag->comment('album'))[0]."\n";
print "_TITLE:".($ftag->comment('title'))[0]."\n";
print "_GENRE:".($ftag->comment('genre'))[0]."\n";
print "_TRACKNUM:".( ($ftag->comment('tracknum'))[0] |
                     ($ftag->comment('tracknumber'))[0] )."\n";
print "_COMMENT:".($ftag->comment('comment'))[0]."\n";
print "_REPLAYGAIN_TRACK_GAIN:".($ftag->comment('REPLAYGAIN_TRACK_GAIN'))[0]."\n";
print "_REPLAYGAIN_ALBUM_GAIN:".($ftag->comment('REPLAYGAIN_ABLUM_GAIN'))[0]."\n";
print "_MEDIATYPE:".(GNUpod::FileMagic::MEDIATYPE_AUDIO)."\n";
print "FORMAT:OGG\n";
}
elsif($gimme eq "GET_PCM") {
  my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_pcm", "wav");

  my $status = system("oggdec", "--quiet", "-o", $tmpout, $file);
  
  if($status) {
   warn "oggdec exited with $status, $!\n";
   exit(1);
  }
  
  print "PATH:$tmpout\n";
  
}
elsif($gimme eq "GET_MP3") {
  #Open a secure flac pipe and open anotherone for lame
  #On errors, we'll get a BrokenPipe to stout
  my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_mp3", "mp3");
  open(OGGOUT, "-|") or exec("oggdec", "--quiet", "-o", "-", $file) or die "Could not exec oggdec: $!\n";
  open(LAMEIN , "|-") or exec("lame", "-V", $quality, "--silent", "-", $tmpout) or die "Could not exec lame: $!\n";
  binmode(OGGOUT);
  binmode(LAMEIN);
   while(<OGGOUT>) {
    print LAMEIN $_;
   }
  close(OGGOUT);
  close(LAMEIN);
  print "PATH:$tmpout\n";
}
elsif($gimme eq "GET_AAC" or $gimme eq "GET_AACBM") {
 #Yeah! FAAC is broken and can't write to stdout..
  my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_faac", "m4a");
     $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_faac", "m4b") if $gimme eq "GET_AACBM";
  $quality = 140 - ($quality*10);
  open(OGGOUT, "-|") or exec("oggdec", "--quiet", "-o", "-", $file) or die "Could not exec oggdec: $!\n";
  open(FAACIN , "|-") or exec("faac", "-w", "-q", $quality, "-o", $tmpout, "-") or die "Could not exec faac: $!\n";
  binmode(OGGOUT);
  binmode(FAACIN);
   while(<OGGOUT>) { #Feed faac
    print FAACIN $_;
   }

  close(OGGOUT);
  close(FAACIN);

  print "PATH:$tmpout\n";
}
else {
 warn "$0 can't encode into $gimme\n";
 exit(1);
}

exit(0);
