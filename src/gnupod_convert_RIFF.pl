###__PERLBIN__###
#  Copyright (C) 2006-2007 Adrian Ulrich <pab at blinkenlights.ch>
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
	#..not much
	print "_MEDIATYPE:".(GNUpod::FileMagic::MEDIATYPE_VIDEO)."\n";
	print "FORMAT:MP4\n";
}
elsif($gimme eq "GET_VIDEO") {
	my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_video", "mp4");
	my $acodec = check_ffmpeg_aac();
	
	my $x = system("ffmpeg", "-i", $file, "-acodec", $acodec, "-ab", "128k", "-vcodec", "mpeg4",
	               "-b", "1200kb", "-mbd", 2, "-flags", "+4mv+trell", "-aic", 2, "-cmp", 2,
	               "-subcmp", 2, "-s", "320x240", "-r", "29.97", $tmpout);
	print "PATH:$tmpout\n";
}
else {
	warn "$0 can't encode into $gimme\n";
	exit(1);
}


# Check if ffmpeg knows 'libfaac' or if we
# still shall call it with AAC
sub check_ffmpeg_aac {
	my @newstyle = grep(/\s+EA\s+libfaac/,split(/\n/,
	               `ffmpeg -formats 2> /dev/null`));
	return (defined(@newstyle) ? 'libfaac' : 'aac');
}


exit(0);


=head1 NAME

gnupod_convert_RIFF.pl - Convert a file to an iPod supported format.

=head1 SYNOPSIS

B<gnupod_convert_RIFF.pl> SOURCEFILE FORMATSELECTOR QUALITY

=head1 DESCRIPTION

gnupod_convert_RIFF.pl converts a media file to one of the formats
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
