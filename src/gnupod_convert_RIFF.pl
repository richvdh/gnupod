###__PERLBIN__###
#  Copyright (C) 2006 Adrian Ulrich <pab at blinkenlights.ch>
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
	print "FORMAT: MP4\n";
}
elsif($gimme eq "GET_VIDEO") {
	my $tmpout = GNUpod::FooBar::get_u_path("/tmp/gnupod_video", "mp4");
	my $x = system("ffmpeg", "-i", $file, "-b", 600, "-r", "29.97", "-s", "320x240",
	               "-vcodec", "mpeg4", "-ab", 128, "-acodec", "aac", $tmpout);
	print "PATH:$tmpout\n";
}
else {
	warn "$0 can't encode into $gimme\n";
	exit(1);
}

exit(0);

