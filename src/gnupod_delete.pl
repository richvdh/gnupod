
use strict;
use XML::Parser;
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

use vars qw($filedata %pldata $trash %paratt %opts %dull_helper @playlist_pos);
print "gnupod delete 0.8-rc1 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool removes files from your iPod and updates the gnuPod file\n\n";



$opts{m} = $ENV{IPOD_MOUNTPOINT};
Getopt::Mixed::init("help h>help gui g>gui debug d>debug\
                     mount=s m>mount");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();


chck_opts(); #check getopts
&stdtest;


if(!$opts{g})
{
 print "IDs to remove:\n@ARGV\n?\n";
 print "\nHit ENTER to continue, CTRL+C to abort\n";
 <STDIN>;
}




cachedb();
writedb();

exit(0);


#find an element in an array
sub search_array {
my($to_find, @list) = @_;
foreach(@list) {
 return 1 if ($to_find eq $_);
}
return 0;
}




sub writedb
{
 open(GPH, "> $opts{m}/iPod_Control/.gnupod/GNUtunesDB") or die "Fatal: failed to write GNUtunesDB: $!\n";
 binmode(GPH);

#Be sure to write UTF8 data
 $filedata = utf8($filedata);
 
 print GPH "<?xml version=\"1.0\"?>\n<gnuPod>\n<files>\n$filedata</files>\n\n";
 foreach (@playlist_pos)
 {
  print GPH utf8("<playlist name=\"$_\">\n$pldata{$_}</playlist>\n\n");
 }
 print GPH "</gnuPod>";
 close(GPH);
}


sub cachedb
{
 print "> Parsing old GNUtunesDB (time to pray!)\n";
 my $parser = new XML::Parser(ErrorContext => 2);
 $parser->setHandlers(Start => \&start_handler, End => \&end_handler);
 $parser->parsefile("$opts{m}/iPod_Control/.gnupod/GNUtunesDB");
}


sub start_handler
{
my($p, @el) = @_;
my ($parent) = $p->current_element;


if($el[0] eq "playlist"){
 die "FATAL ERROR: <playlist> Element found, but no </files> was found!\n -> Correct your GNUtunesDB!\n" if !$dull_helper{files_end_found};
  if($el[1] eq "name" && $el[2]) {
    push(@playlist_pos, $el[2]) if !search_array($el[2], @playlist_pos);
  }
  else {
   die "FATAL ERROR: Playlist without name found!\n";
  }
 }
  elsif($el[0] eq "file" && $parent eq "files")
 {
 	print "Got new F  EL: @el\n" if $opts{d};
   $filedata .= rm_o_matic($el[0], @el);
 }
 elsif( ($el[0] eq "add" || $el[0] eq "regex" || $el[0] eq "iregex") && $parent eq "playlist")
 {
	print "Got new PL EL: @el\n" if $opts{d};
  $pldata{$paratt{"name"}} .= rm_o_matic($el[0], @el);
 }
 else {
  print "Throw away $el[0]\n" if $opts{d};
 }

#set some parent info for next element
  for(my $j=1;$j<=int(@el)-1;$j+=2)
  {
   $paratt{$el[$j]} = $el[$j+1];
  }
}



# XML parser - handler for end tags (</foo>)
sub end_handler {
 if (@_[int(@_)-1] eq "files") {
   $dull_helper{files_end_found} = 1;
 }
}




sub rm_o_matic
{
 my(%zipfel, $kill, $ok_line);
 my($type, @el) = @_;
     #get attributes for this element
     for(my $i=1;$i<=int(@el)-1;$i+=2)
     {
      my $value = xmlstring($el[$i+1]);
      $zipfel{$el[$i]} = $value;
     }
   
      for(my $j=0;$j<int(@ARGV);$j++)
      {
       if(($ARGV[$j] == $zipfel{id}) && defined($zipfel{id}))
        {
	  $kill = 1; #this ID is on the kill list!
	  last;
        }
      }
 
   
    if(!$kill) #we have to keep this entry
    {
       $ok_line = " <$type ";
       $ok_line .= "id=\"$zipfel{id}\" " if $zipfel{id}; #Add 'id' as first element
	  foreach (reverse(keys(%zipfel)))
	  {
	        next if $_ eq "id"; #Drop the ID element.. we added it above..
	  	$ok_line .= "$_=\"".$zipfel{$_}."\" ";
	  }
	  	$ok_line .="/>\n";
    }
    elsif($type eq "file") #found on kill-list... we don't keep this entry..
    {
    	my($podpath);
	    $podpath = $zipfel{path};
	    $podpath =~ tr/:/\//;
	     if($podpath)
	     {
	       if(unlink("$opts{m}$podpath"))
	       {
	         print "- $podpath\n";
	       }
	       else
	       {
	         print "!! Failed to remove $opts{m}$podpath from iPod drive!\n";
	       }
	    }
	    else
	    {
	      print "ID ".$zipfel{id}." removed from GNUtunesDB, but file won't get deleted (no 'path=' found...)\n";
	    }
    }
      
return $ok_line;
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




sub stdtest
{
if(!(-w "$opts{m}/iPod_Control/.gnupod/GNUtunesDB"))
{
 print "Error: Cant write to your gnuPod-file\ndid you run 'gnupod_INITpod.pl' ?\n";
 exit(1);
}
if(!(-w "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: Cant write to your iTunesDB\ndid you run 'gnupod_INITpod.pl' ?\n";
 exit(1);
}
if ((-M "$opts{m}/iPod_Control/.gnupod/GNUtunesDB") > (-M "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: your gnuPod-file is older than your iTunesDB! (Last update not done with gnuPod?)\n";
 print "Please run this command to correct this problem:\n";
 print "tunes2pod.pl -m \$IPOD_MOUNTPOINT\n\n";
 print "This command will update your current gnuPodfile with the contents of your (newer) iTunesDB\n";
 exit(1);
}

return 0;
}




###################################################

sub chck_opts
{
	if($opts{h} || !(@ARGV)) #help switch
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
	return 0;
	}
}

sub usage
{
die << "EOF";

    usage: $0 [-hg] [-m directory] IDs to remove

     -h  --help             : displays this help message
     -g  --gui              : run as GUI slave
     -d  --debug            : display debug messages
     -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
}

###################################################



