use strict;
use Getopt::Mixed qw(nextOption);


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

use vars qw(%opts);

print "gnupod INIT 0.8-rc1 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool creates the default directory-tree for your iPod\n\n";

$opts{m} = $ENV{IPOD_MOUNTPOINT};
Getopt::Mixed::init("help h>help gui g>gui mount=s m>mount");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();

chck_opts();


###################################################
sub chck_opts
{
	if($opts{h}) #help switch
	{
		usage();
	}
	elsif(!"$opts{m}") #no ipod MP
	{
print STDERR << "EOF";
 
 Do not know where the iPod is mounted,
 please set \$IPOD_MOUNTPOINT or use
 the '-m' switch.
 
EOF
	usage();
	}
	else
	{
	go();
	}
}

sub usage
{
print STDERR << "EOF";

    usage: $0 [-hg] [-m directory]

     -h  --help             : displays this help message
     -g  --gui              : run as GUI slave
     -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
exit(1);
}

###################################################






sub go
{

if(!$opts{g})
{
	print "Your iPod is mounted at:\n";
	print " $opts{m}\n";
	print "correct?\n\n";
	print "** WARNING ** This will KILL your iTunesDB (if there is any)\n";
	print "              If your iPod isn't fresh formatted (-> has files)\n";
	print "              hit CTRL+C *now* and do a:\n";
	print "tunes2pod.pl -m $opts{m}\n\n";
	print "This will convert your current iTunesDB to the gnuPod-file\n\n";
	print "hit ENTER to continue (and erase your iTunesDB) or CTRL+C to abort\n";
	<STDIN>;
}


print "Creating directory structure on $opts{m}\n";


print mkdir("$opts{m}/iPod_Control");
print mkdir("$opts{m}/iPod_Control/Music");
print mkdir("$opts{m}/iPod_Control/iTunes");
print mkdir("$opts{m}/iPod_Control/.gnupod");

my($i, $xi);
for($i=0;$i<=19;$i++)
 {
 $xi = sprintf("%02d", $i);
 print mkdir("$opts{m}/iPod_Control/Music/F$xi");
 }
print "\n";
open(FOO, "> $opts{m}/iPod_Control/iTunes/iTunesDB") or die "\nCould not create dummy iTunesDB: $!\n(got *write* access?)";
close(FOO);

open(FOO, "> $opts{m}/iPod_Control/.gnupod/GNUtunesDB");
print FOO "<?xml version=\"1.0\"?>\n";
print FOO "<gnuPod>\n<files>\n</files>\n</gnuPod>\n";
close(FOO);
print "\ndone!\n";


if(!$opts{g})
{
	print "\nYou should now be able to use\n gnupod_addsong.pl $opts{m} /path/to/my/mp3/files/*\nto add files to your iPod\n";
	print "AND: don't forget to run 'mktunes.pl' *AFTER* you added\nfiles with 'gnupod_addsong.pl', but *BEFORE* umounting ";
	print "your iPod!!!\n  --- Have fun! :)\n";
}

}
