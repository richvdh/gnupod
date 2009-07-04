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
  print "_MEDIATYPE:".(GNUpod::FileMagic::MEDIATYPE_AUDIO)."\n";
  print "FORMAT:MIDI\n";
}
elsif($gimme eq "GET_PCM") {
  my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_pcm", "wav");

  my $status = system("timidity", "-idqq", "-Ow", "-o", $tmpout, $file);
  
  if($status) {
   warn "timidity exited with $status, $!\n";
   exit(1);
  }
  
  print "PATH:$tmpout\n";
  
}
elsif($gimme eq "GET_MP3") {
  #Open a secure timidity pipe and open anotherone for lame
  #On errors, we'll get a BrokenPipe to stout
  my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_mp3", "mp3");
  open(MIDIOUT, "-|") or exec("timidity", "-idqq", "-Ow", "-o", "-", $file) or die "Could not exec timidity: $!\n";
  open(LAMEIN , "|-") or exec("lame", "-V", $quality, "--silent", "-", $tmpout) or die "Could not exec lame: $!\n";
  binmode(MIDIOUT);
  binmode(LAMEIN);
   while(<MIDIOUT>) {
    print LAMEIN $_;
   }
  close(MIDIOUT);
  close(LAMEIN);
  print "PATH:$tmpout\n";
}
elsif($gimme eq "GET_AAC" or $gimme eq "GET_AACBM") {
  my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_faac", "m4a");
     $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_faac", "m4b") if $gimme eq "GET_AACBM";
  $quality = 140 - ($quality*10);
  open(MIDIOUT, "-|") or exec("timidity", "-idqq", "-Ow", "-o", "-", $file) or die "Could not exec timidity: $!\n";
  open(FAACIN , "|-") or exec("faac", "-w", "-q", $quality, "-o", $tmpout, "-") or die "Could not exec faac: $!\n";
  binmode(MIDIOUT);
  binmode(FAACIN);
   while(<MIDIOUT>) { #Feed faac
    print FAACIN $_;
   }

  close(MIDIOUT);
  close(FAACIN);

  print "PATH:$tmpout\n";
}
else {
 warn "$0 can't encode into $gimme\n";
 exit(1);
}

exit(0);

#############################################
# Get Unique path
sub GNUpod::FooBar::get_u_path {
 my($prefix, $ext) = @_;
 my $dst = undef;
 while($dst = sprintf("%s_%d_%d.$ext",$prefix, int(time()), int(rand(99999)))) {
  last unless -e $dst;
 }
 return $dst;
}

=head1 NAME

gnupod_convert_MIDI.pl - Convert a file to an iPod supported format.

=head1 SYNOPSIS

B<gnupod_convert_MIDI.pl> SOURCEFILE FORMATSELECTOR QUALITY

=head1 DESCRIPTION

gnupod_convert_MIDI.pl converts a media file to one of the formats
that are supported by the iPod. This tool is not supposed to be called
by the user directly but rather by gnupod_addsong.pl. Therefore this
documentation is rudimentary and will remain so.

=head1 OPTIONS

=over 4

=item SOURCEFILE

Source file.

=item FORMATSELECTOR

Target format selector.

=item QUALITY

Encoding quality setting.

=back

=head1 BUGS

Email bug reports to C<< <bug-gnupod@nongnu.org> >>, a mailing
list whose archives can be found at
C<< <http://lists.gnu.org/archive/html/bug-gnupod/> >>.

=head1 SEE ALSO

=over 4

=item *

L<gnupod_addsong.pl> - Add songs, podcasts and books to your iPod.

=back

=head1 AUTHORS

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

=head1 COPYRIGHT

Copyright (C) Adrian Ulrich

###___PODINSERT man/footer.pod___###
