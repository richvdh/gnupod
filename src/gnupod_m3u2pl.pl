use strict;

use Getopt::Mixed qw(nextOption);
use Unicode::String qw(utf8);
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

print "gnupod_m3u2pl 0.6 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool re-converts playlists written by gnupod_mkm3u.pl (EXPERIMENTAL)\n\n";

use vars qw(%opts);

$opts{m} = $ENV{IPOD_MOUNTPOINT};
Getopt::Mixed::init("help h>help debug d>debug\
                     mount=s m>mount");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();


chck_opts(); #check getopts
go();




sub go
{
 foreach(@ARGV) {
   my $plname = fileof(xmlstring($_));
   print STDERR utf8("<playlist name=\"$plname\">\n");
   print "> $plname\n" if $opts{d};
   if(open(FILE, "$_")) {
    while(my $i = <FILE>) {
     print STDERR utf8(mkfoo($i));
    }   
   close(FILE);
   }
  print STDERR "</playlist>\n\n";
 }
 print "done!\n";
 exit(0);
}



sub mkfoo {
my($i) = @_;
my($path, $ret);
chomp($i);

my @splited = split(/\//, $i);

if($splited[int(@splited)-2] =~ /^f(\d{2})$/i) {
 $splited[int(@splited)-2] = "F$1";
}
else {
 return undef;
}
return undef if $splited[int(@splited)-3] !~ /^music$/i;
return undef if $splited[int(@splited)-4] !~ /^ipod_control$/i;


 $path .= ":iPod_Control:Music:".$splited[int(@splited)-2].":".$splited[int(@splited)-1];



#our path looks ok..
$ret = "<add path=\"".xmlstring($path)."\" />\n";

return $ret;
}


sub fileof {
my($string) = @_;
my(@bar);
@bar = split(/\//,$string);
return $bar[int(@bar)-1];
}


###################################################

sub chck_opts
{
	if($opts{h} || !@ARGV) #help switch
	{
		usage();
	}
	else
	{
	return 0;
	}
}


sub xmlstring
{
my($ret) = @_;
$ret =~ s/&/&amp;/g;
$ret =~ s/"/&quot;/g;
$ret =~ s/</&lt;/g;
$ret =~ s/>/&gt;/g;
$ret =~ s/'/&apos;/g;
return $ret;
}


sub usage
{
die << "EOF";

    usage: $0 [-hds] M3U-FILES

     -h  --help             : displays this help message
     -d  --debug            : display debug messages
     
Content is sent to STDERR:
 $0 foobar.m3u 2> out
Is very usefull for big playlists. (and smallones ;))
EOF
}

###################################################



