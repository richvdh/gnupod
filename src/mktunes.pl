
use strict;

use XML::Parser;
use Getopt::Mixed qw(nextOption);
use Unicode::String qw(utf8 utf16 byteswap2);
         
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



use vars qw($parent %paratt %dull_helper %mhod_id $hsd_a $hsd_b $sid %opts %mem_eater %cs_mem_eater %plists @playlist_pos);
$dull_helper{files} = 53; #start ID
$sid = $dull_helper{files};


# xml 2 iTunes helper
%mhod_id = ("title", 1, "path", 2, "album", 3, "artist", 4, "genre", 5, "fdesc", 6, "comment", 8, "composer", 12) ;




print "mktunes.pl 0.8-rc1 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool updates your iTunesDB with the content of the gnuPodDB\n\n";



$opts{m} = $ENV{IPOD_MOUNTPOINT};
Getopt::Mixed::init("help h>help gui g>gui debug d>debug status s>status\
                     mount=s m>mount force f>force");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();


chck_opts(); #check getopts
stdtest(); #test if setup is sane



if(!$opts{g})
{ 
 print "This action will *REPLACE* your current iTunesDB with the contents of the\n";
 print "current GNUpod file\n\nHit ENTER to continue, CTRL+C to abort\n";
 <STDIN>;
}

go("$opts{m}/iPod_Control/.gnupod/GNUtunesDB");




sub go
{
my($file) = @_;

$| = 1; #Turn off buffering of stdout


print "\r> Parsing '$file' (time to pray!)\n";
my $parser = new XML::Parser(ErrorContext => 2);
$parser->setHandlers(Start => \&start_handler, End => \&end_handler);
$parser->parsefile($file);


print "\r> Creating File Database..\n";

#add header to 'files' part..
$dull_helper{_f_data} = mk_mhlt(($dull_helper{files}-$sid)).$dull_helper{_f_data};
$dull_helper{_f_data} = mk_mhsd(length($dull_helper{_f_data})
                         , 1).$dull_helper{_f_data};

print "\r> Creating Playlists..\n";
$dull_helper{_pl_data} = pl_generator();
$dull_helper{_pl_data} = mk_mhsd(length($dull_helper{_pl_data}),2).$dull_helper{_pl_data};



print "\r> Packing file\n";
open(ITUNES, "> $opts{m}/iPod_Control/iTunes/iTunesDB") or die "Failed to open: $!\n";
 binmode(ITUNES); #Try to be nice to RedHat8 perl..
 print ITUNES mk_mhbd(length($dull_helper{_f_data}.$dull_helper{_pl_data}));
 print ITUNES $dull_helper{_f_data};
 print ITUNES $dull_helper{_pl_data};
close(ITUNES);

print "\r> Correcting timestamps...\n";

#gnutunesdb has to be newer than iTunesDB
my $now = time();
utime($now, $now, "$opts{m}/iPod_Control/.gnupod/GNUtunesDB");
$now -= 1;
utime($now, $now, "$opts{m}/iPod_Control/iTunes/iTunesDB");


print "\nYou can now umount your iPod. [Files: ".($dull_helper{files}-$sid)."]\n  - May the iPod be with you!\n\n";

}


# XML parser - handler for end tags (</foo>)
sub end_handler {
 if (@_[int(@_)-1] eq "files") {
   $dull_helper{files_end_found} = 1;
 }
}


#find an element in an array
sub search_array {
my($to_find, @list) = @_;
foreach(@list) {
 return 1 if ($to_find eq $_);
}
return 0;
}



# XML parser - handler for start tags (<foo>)
# REWRITE ME!
sub start_handler
{
print "\r$dull_helper{files}" if $opts{s};
my($p, @el) = @_;
my ($parent) = $p->current_element;

#<files></files> has to start BEFORE <playlist>... test if we found </files> when a <playlist> starts
if($el[0] eq "playlist"){
 die "FATAL ERROR: <playlist> Element found, but no </files> was found!\n -> Correct your GNUtunesDB!\n" if !$dull_helper{files_end_found};
  if($el[1] eq "name" && $el[2]) {
    push(@playlist_pos, $el[2]) if !search_array($el[2], @playlist_pos);
  }
  else {
   die "FATAL ERROR: Playlist without name found!\n Correct Syntax: <playlist name=\"FooBar\">\n";
  }
}
elsif($el[0] eq "file" && $parent eq "files")
{
  new_ipod_file(@el);
}
elsif($el[0] eq "add" && $parent eq "playlist")
 {
  new_pl_item(@el);
 }
elsif(($el[0] eq "regex" || $el[0] eq "iregex") && $parent eq "playlist")
 {
  new_pl_regex_item($el[0], @el);
 }
else 
{
 print "*WARNING* Ignoring element $el[0] with parent *$parent*\n" if $opts{d};
}

#set some parent info for next element

# ..hmm.. there should be a better way to
# do this.. maybe i should buy a book
# about XML::Parser

  for(my $j=1;$j<=int(@el)-1;$j+=2)
  {
   $paratt{$el[$j]} = $el[$j+1];
  }

}


sub new_pl_regex_item
{
my($option, @el) = @_;
my(%pl_elements, %hash, $i);

if($option ne "iregex") {
 %hash = %cs_mem_eater;
}
else {
 %hash = %mem_eater;
}


 for($i=1;$i<int(@el);$i+=2) { #get every element
  print "Checking $el[$i] with $el[$i+1]\n" if $opts{d};
     foreach(keys(%{$hash{$el[$i]}})) {
     print "->$_\n" if $opts{d};
     $el[$i+1] = lc($el[$i+1]) if $option eq "iregex";
      if($_ =~ /$el[$i+1]/) {
        foreach(split(/ /, $hash{$el[$i]}{$_})) {
	 print "->$_\n" if $opts{d};
	 $pl_elements{$_}++;
	}
      }
    }
  
 }
 
$i = ($i-1)/2; #we reuse $i
foreach (sort {$a<=>$b} keys(%pl_elements)) {
 $plists{$paratt{name}} .= $_." " if ($pl_elements{$_} == $i);
}

}



sub new_pl_item
{
my(@el) = @_;
my(%pl_elements, $i);


for($i=1;$i<int(@el);$i+=2) { #get every element
my @left = split(/ /, $mem_eater{$el[$i]}{"\L$el[$i+1]"});
 foreach(@left) {
  $pl_elements{$_}++; #found element with this attrib
 }
}

$i = ($i-1)/2; #reuse $i
foreach (sort {$a<=>$b} keys(%pl_elements)) {
 #add element to PL if it matched each criteria
 $plists{$paratt{name}} .= $_." " if ($pl_elements{$_} == $i);
}
}



# create optional playlists and main playlist (mk_playlist)
sub pl_generator
{
my $ret =  mk_mhyp(mk_playlist(), "gnuPod",1, $dull_helper{files}-$sid);
my ($pl_content);
print "> Generating playlists, found ". int(@playlist_pos)."\n";
  
	foreach $_ (@playlist_pos)
   {
    print "\r>> Adding Playlist '$_'";
    # #resort files.
    # #playlist elements are in the order as they are found in the GNUtunesDB,
    # #we ignore ID, songnum and other fancy things..
    # my(@plidx) = sort {$a <=> $b} split(/ /, $plists{$_});
    my(@plidx) = split(/ /, $plists{$_});
     print " with ".scalar(@plidx)." item";
     print "s" if scalar(@plidx) != 1;
     print "\n";
     undef $pl_content;
     
      foreach my $i (@plidx)
      {
       print "\r $i" if $opts{s};
         $pl_content .= mk_mhip(($i));
         $pl_content .= mk_mhod(100, "", ($i));
      }
   
   $ret .= mk_mhyp($pl_content, $_, 0, scalar(@plidx));
   }
	 
return mk_mhlp($ret, (int(@playlist_pos)+1));

#return mk_mhsd(mk_mhlp($ret, (int(@playlist_pos)+1)), 2);

}





# creates a new entry for a file
sub new_ipod_file
{
 my(@el) = @_;
 my(%file_hash) = ();
 my($ret, $hod_data, $hodcount);

# fill array with content of a <file /> line
 for(my $i=1;$i<=int(@el)-1;$i+=2)
  {
	 
	  #mhod data
	   if($mhod_id{$el[$i]})
	   {
		  $hod_data = $hod_data.mk_mhod($mhod_id{$el[$i]}, $el[$i+1]);
	    $hodcount++;
	   }
	 
	 $file_hash{$el[$i]} = $el[$i+1]; 
	}
	
 # fill array for extended PL support with information,
 # We should kill $cs_mem_eater.. we don't need it..
 # But atm i'm to lazy...
 foreach (keys(%file_hash))
 {
 # print "\$mem_eater -> *$_*$file_hash{$_}*=*$file_hash{id}*\n" if $opts{d};
  $mem_eater{$_}{"\L$file_hash{$_}"} .= $dull_helper{files}." ";
  
 #the case SENSITIVE mem_eater, used for 'regex'
 $cs_mem_eater{$_}{"$file_hash{$_}"} .= $dull_helper{files}." ";
 }

#####
if(!($file_hash{time} && $file_hash{filesize} && $file_hash{bitrate} && $file_hash{id}))
{
 die "Fatal error in XML file, not enough information for $file_hash{id} (need time/filesize/bitrate)\n";
}

$ret .= "mhit";
$ret .= pack("h8", itop(156));                           #header size
$ret .= pack("h8", itop(length($hod_data)+156));         #len of this entry
$ret .= pack("h8", itop($hodcount));                     #num of mhods in this mhit
$ret .= pack("h8", itop($dull_helper{files}));           #Song index number
$ret .= pack("h8", itop(1));                             #?
$ret .= pack("H8");                                      #dummyspace
$ret .= pack("h8", itop(256));                           #type
$ret .= pack("h8", mactime());                           #timestamp (we create a dummy timestamp, iTunes doesn't seem to make use of this..?!)
$ret .= pack("h8", itop($file_hash{filesize}));          #filesize
$ret .= pack("h8", itop($file_hash{time}));              #seconds of song
$ret .= pack("h8", itop($file_hash{songnum}));           #nr. on CD .. we dunno use it (in this version)
$ret .= pack("h8", itop($file_hash{songs}));             #songs on this CD
$ret .= pack("h8", itop($file_hash{year}));              #the year
$ret .= pack("h8", itop($file_hash{bitrate}));           #bitrate
$ret .= pack("H8", "000044AC");                          #whats this?! 
$ret .= pack("H56");                                     #dummyspace
$ret .= pack("h8", itop($file_hash{cdnum}));             #cd number
$ret .= pack("h8", itop($file_hash{cds}));               #number of cds
$ret .= pack("H8");                                      #hardcoded space 
$ret .= pack("h8", mactime());                           #dummy timestamp again...
$ret .= pack("H96");                                     #dummy space

$dull_helper{files}++;

$dull_helper{_f_data} .= $ret.$hod_data;
return 0;
}



# create an iTunesDB header
sub mk_mhbd
{
my($ret, $dullme);
($dullme) = @_;
$ret = "mhbd";
$ret .= pack("h8", itop(104));                  #Header Size
$ret .= pack("h8", itop($dullme+104));  #size of the whole mhdb
$ret .= pack("H8", "01");                       #?
$ret .= pack("H8", "01");                       #? - changed to 2 from itunes2 to 3 .. version? We are iTunes version 1 ;)
$ret .= pack("H8", "02");                       #?
$ret .= pack("H160", "00");                     #dummy space
return $ret;
}





# header for ALL playlists
sub mk_mhlp
{
my($dull, $ret, $lists);
($dull, $lists) = @_;
 $ret = "mhlp";
 $ret .= pack("h8", itop(92));
 $ret .= pack("h8", itop($lists)); #playlists on iPod (including main!)
 $ret .= pack("h160", "00");
return $ret.$dull;
}



# header for all files (like mk_mhlp for playlists)
sub mk_mhlt
{
my($dull, $ret, $songnum,$xsongnum);
($songnum) = @_;

$ret = "mhlt";
$ret .= pack("h8", itop(92)); 		#Header size (static)
$ret .= pack("h8", itop($songnum));     #songs in this itunesdb
$ret .= pack("H160", "00");             #dummy space
return $ret;
}





# header for one playlist
sub mk_mhyp
{
my($dull, $ret,  $listname, $type, $anz);
($dull, $listname, $type, $anz) = @_;
 $dull = mk_weired().mk_mhod(1, $listname).$dull;   #itunes prefs for this PL & PL name (default PL has  device name as PL name)
 
 $ret = "mhyp";
 $ret .= pack("h8", itop(108)); #type?
 $ret .= pack("h8", itop(length($dull)+108));       #size
 $ret .= pack("H8", "02");			    #? 
 $ret .= pack("h8", itop($anz));     		    #songs in pl
 $ret .= pack("h8", itop($type));  	            # 1 = main .. 0=not main
 $ret .= pack("H8", "00"); 			    #?
 $ret .= pack("H8", "00");                          #?
 $ret .= pack("H8", "00");                          #?
 $ret .= pack("H144", "00");       		    #dummy space
 return $ret.$dull;
}







#generates a default playlist (in mhip's)
sub mk_playlist
{
my($i, $ret);
 for($i=0;$i<=($dull_helper{files}-$sid-1);$i++)
 {
  $ret .= mk_mhip(($i+$sid));
  $ret .= mk_mhod(100, "", ($i+$sid));
 }
 
 #now we got all DEFAULT-PLAYLIST-mhods we need 
  return $ret;
}





# header for new PL item
sub mk_mhip
 {
 my($id, $ret);
 ($id) = @_;
  
 $ret = "mhip";
 $ret .= pack("h8", itop(76));
 $ret .= pack("h8", itop(76));
 $ret .= pack("h8", itop(1));
 $ret .= pack("H8", "00");
 $ret .= pack("h8", itop($id)); #song id in playlist
 $ret .= pack("h8", itop($id)); #ditto.. don't know the difference, but this seems to work
                                #maybe a special ID used for playlists?!
 $ret .= pack("H96", "00");
  return $ret;
 }


# a iTunesDB has 2 mhsd's:
# mhsd1 holds every song on the ipod
# mhsd2 holds playlists
sub mk_mhsd
{
my($ret, $whole_file, $siz, $type);
($whole_file, $type) = @_;
$ret = "mhsd";
$ret .= pack("h8", itop(96));           		     #Headersize, static
$ret .= pack("h8", itop($whole_file+96));                   #size
$ret .= pack("h8", itop($type));      			     #type .. 1 = song .. 2 = playlist
$ret .= pack("H160", "00");         			     #dummy space
return $ret;
}







#create a new mhod
# 'data' is stored in mhods
sub mk_mhod
{
# - type id
#1   - titel
#2   - ipod filename
#3   - album
#4   - interpret
#5   - genre
#6   - filetype
#7   - ??? (EQ?)
#8   - comment
#12  - composer
#100 - Playlist item

my ($type, $string, $fqid) = @_;
my $mod = 40;

if(!$fqid) { 
#normal mhod
 $fqid = 1; 
}
else {
#pl mhod
 $mod = 44;
# print "Refers to $fqid\n" if $opts{d};
}



$string = ipod_string($string); #cache data

my $ret = "mhod";                 		  #header
$ret .= pack("h8", itop(24));                     #size of header
$ret .= pack("h8", itop(length($string)+$mod));   # size of header+body
$ret .= pack("h8", itop("$type"));                #type of the entry
$ret .= pack("H16");                              #dummy space
$ret .= pack("h8", itop($fqid));                  #Referst to this id if a PL item
                                                  #else -> always 1
$ret .= pack("h8", itop(length($string)));        #size of string

if($type < 100){ #no PL mhod
 $ret .= pack("h16");           #trash
 $ret .= $string;               #the string
}
else { #PL mhod
 $ret .= pack("h24"); #playlist mhods are a different
}

return $ret;
}



#Convert utf8 (what we got from XML::Parser) to utf16 (ipod)
sub ipod_string {
my ($utf8string) = @_;
#We got utf8 from parser, the iPod likes utf16.., swapped..

$utf8string = utf8($utf8string)->utf16;
$utf8string = byteswap2($utf8string);
return $utf8string;

}




#returns a timestamp in MAC time format
sub mactime {
# FIXME!!
# The time should now be correct, but gnuPod doesn't
# _use_ this function like it should be used...
# The iPod (and even iTunes) doesn't seem to make
# a real use of the DATE field..

my($x, $y);
$x  = time();
$x += 2082844800;
$y = sprintf("%08X", $x);
return $y;
}




#int to ipod
sub itop
{
my($int) = @_;
$int =~ /(\d+)/; 
$int = $1;
return scalar(reverse(sprintf("%08X", $int)));
}




#Seems to be a Preferences mhod, every PL has such a thing
# FIXME!!!!
sub mk_weired
{
my($ret, $foobar);
$ret = "mhod";                          #header
$ret .= pack("H8", reverse("18"));      #size of header
$ret .= pack("H8", reverse("8802"));    #$slen+40 - size of header+body
$ret .= pack("H8", reverse("64"));      #type of the entry
$ret .= pack("H48", "00");
$ret .= pack("H8", reverse("840001"));  #?
$ret .= pack("H8", reverse("05"));      #?
$ret .= pack("H8", reverse("09"));      #?
$ret .= pack("H8", reverse("03"));      #?
$ret .= pack("H32", reverse("010012")); #static? (..or width of col?)
$ret .= pack("H32", reverse("0200C8")); #static?
$ret .= pack("H32", reverse("0D003C")); #?
$ret .= pack("H32", reverse("04007D")); #static?
$ret .= pack("H32", reverse("03007D")); #static?
$ret .= pack("H32", reverse("080064")); #static?

$ret .= pack("H8", reverse("170064")); #static?
$ret .= pack("H8", reverse("01"));      #bool? (Visible?)
$ret .= pack("H16", "00");
$ret .= pack("H8", reverse("140050")); #static? 
$ret .= pack("H8", reverse("01"));      #bool? (Visible?)
$ret .= pack("H16", "00");
$ret .= pack("H8", reverse("15007D")); #static? 
$ret .= pack("H8", reverse("01"));      #bool? (Visible?)
$ret .= pack("H912", "00");


# Every playlist has such an mhod, it tells iTunes (and other programs?) how the
# the playlist shall look (visible coloums.. etc..)
# But we are using always the same layout static.. we don't support this mhod type..
# But we write it (to make iTunes happy)
return $ret
}



sub stdtest
{
if(!(-w "$opts{m}/iPod_Control/.gnupod/GNUtunesDB"))
{
 print "Error: Cant write to your gnuPod-file\ndid you run 'gnupod_INITpod.pl -m $opts{m}' ?\n";
 exit(1);
}
if(!(-w "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: Cant write to your iTunesDB\n";
 exit(1);
}


if ((-M "$opts{m}/iPod_Control/.gnupod/GNUtunesDB") > (-M "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: your gnuPod-file is older than your iTunesDB! (Last update not done with gnuPod?)\n";
 print "Please run this command to correct this issue:\n";
 print "tunes2pod.pl -m \$IPOD_MOUNTPOINT\n\n";
 print "This command will update your current gnuPodfile with the contents of your (newer) iTunesDB\n";
 
  if($opts{f}) {
   print "Operation forced\n";
  }
  else {
   print "or use '$0 -f -m $opts{m}' to force operation.. (if you know what you are doing)\n exiting\n";
   exit(1);
  }
}

return 0;
}



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
	return 0;
	}
}

sub usage
{
die << "EOF";

    usage: $0 [-hgds] [-m directory]

     -h  --help             : displays this help message
     -g  --gui              : run as GUI slave
     -f  --force            : do not check timestamps
     -d  --debug            : display debug messages
     -s  --status           : display status
     -m  --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
}

###################################################



