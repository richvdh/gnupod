package GNUpod::iTunesDB;
use strict;
use Unicode::String;

use vars qw(%mhod_id);

BEGIN {
 %mhod_id = ("title", 1, "path", 2, "album", 3, "artist", 4, "genre", 5, "fdesc", 6, "comment", 8, "composer", 12) ;
}


## GENERAL #########################################################
# create an iTunesDB header
sub mk_mhbd
{
my ($mhdb_size) = @_;

my $ret = "mhbd";
   $ret .= pack("h8", _itop(104));                  #Header Size
   $ret .= pack("h8", _itop($mhdb_size+104));       #size of the whole mhdb
   $ret .= pack("H8", "01");                       #?
   $ret .= pack("H8", "01");                       #? - changed to 2 from itunes2 to 3 .. version? We are iTunes version 1 ;)
   $ret .= pack("H8", "02");                       #?
   $ret .= pack("H160", "00");                     #dummy space
return $ret;
}

## GENERAL #########################################################
# a iTunesDB has 2 mhsd's: (This is a child of mk_mhbd)
# mhsd1 holds every song on the ipod
# mhsd2 holds playlists
sub mk_mhsd
{
my ($fsize, $type) = @_;

my $ret = "mhsd";
   $ret .= pack("h8", _itop(96));                      #Headersize, static
   $ret .= pack("h8", _itop($fsize+96));               #Size
   $ret .= pack("h8", _itop($type));                   #type .. 1 = song .. 2 = playlist
   $ret .= pack("H160", "00");                        #dummy space
return $ret;
}

## GENERAL ##########################################################
# Create an mhit entry, needs to know about the length of his
# mhod(s) (You have to create them yourself..!)
sub mk_mhit {
my($hod_length, $hodcount, %file_hash) = @_;
my $ret = "mhit";
   $ret .= pack("h8", _itop(156));                           #header size
   $ret .= pack("h8", _itop(int($hod_length)+156));           #len of this entry
   $ret .= pack("h8", _itop($hodcount));                     #num of mhods in this mhit
   $ret .= pack("h8", _itop($file_hash{id}));                 #Song index number
   $ret .= pack("h8", _itop(1));                             #?
   $ret .= pack("H8");                                      #dummyspace
   $ret .= pack("h8", _itop(256));                           #type
   $ret .= pack("h8", _mactime());                           #timestamp (we create a dummy timestamp, iTunes doesn't seem to make use of this..?!)
   $ret .= pack("h8", _itop($file_hash{filesize}));          #filesize
   $ret .= pack("h8", _itop($file_hash{time}));              #seconds of song
   $ret .= pack("h8", _itop($file_hash{songnum}));           #nr. on CD .. we dunno use it (in this version)
   $ret .= pack("h8", _itop($file_hash{songs}));             #songs on this CD
   $ret .= pack("h8", _itop($file_hash{year}));              #the year
   $ret .= pack("h8", _itop($file_hash{bitrate}));           #bitrate
   $ret .= pack("H8", "000044AC");                          #whats this?! 
   $ret .= pack("H56");                                     #dummyspace
   $ret .= pack("h8", _itop($file_hash{cdnum}));             #cd number
   $ret .= pack("h8", _itop($file_hash{cds}));               #number of cds
   $ret .= pack("H8");                                      #hardcoded space 
   $ret .= pack("h8", _mactime());                           #dummy timestamp again...
   $ret .= pack("H96");                                     #dummy space
return $ret;
}

## GENERAL ##########################################################
# An mhod simply holds information

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

my ($type_string, $string, $fqid) = @_;

my $type = $mhod_id{lc($type_string)};

return undef if !$type && !$fqid; #Invalid type string.. no problemo
#Appnd size for normal mhod's
my $mod = 40;

if(!$fqid) { 
  #normal mhod, default fqid
  $fqid = 1; 
}
else {
 #pl mhod's are longer... fix size
 $type = 100;
 $mod += 4;
}



$string = _ipod_string($string); #cache data

my $ret = "mhod";                 		  #header
$ret .= pack("h8", _itop(24));                     #size of header
$ret .= pack("h8", _itop(length($string)+$mod));   # size of header+body
$ret .= pack("h8", _itop("$type"));                #type of the entry
$ret .= pack("H16");                              #dummy space
$ret .= pack("h8", _itop($fqid));                  #Referst to this id if a PL item
                                                  #else -> always 1
$ret .= pack("h8", _itop(length($string)));        #size of string


if($type < 100){ #no PL mhod
 $ret .= pack("h16");           #trash
 $ret .= $string;               #the string
}
else { #PL mhod
 $ret .= pack("h24"); #playlist mhods are a different
}
return $ret;
}







## FILES #########################################################
# header for all files (like you use mk_mhlp for playlists)
sub mk_mhlt
{
my ($songnum) = @_;

my $ret = "mhlt";
   $ret .= pack("h8", _itop(92)); 		    #Header size (static)
   $ret .= pack("h8", _itop($songnum));              #songs in this itunesdb
   $ret .= pack("H160", "00");                      #dummy space
return $ret;
}









## PLAYLIST #######################################################
# header for ALL playlists
sub mk_mhlp
{

my ($list_count) = @_;

my $ret = "mhlp";
   $ret .= pack("h8", _itop(92));                   #Static header size
   $ret .= pack("h8", _itop($list_count));          #playlists on iPod (including main!)
   $ret .= pack("h160", "00");                     #dummy space
return $ret;
}


## PLAYLIST ######################################################
# Creates an header for a new playlist (child of mk_mhlp)
sub mk_mhyp
{
my ($plc_size, $listname, $type, $anz) = @_;


#We need to create a listview-layout and an mhod with the name..
my $appnd = __dummy_listview().mk_mhod("title", $listname);   #itunes prefs for this PL & PL name (default PL has  device name as PL name)

 
my $ret .= "mhyp";
   $ret .= pack("h8", _itop(108)); #type?
   $ret .= pack("h8", _itop($plc_size+108+(length($appnd))));          #size
   $ret .= pack("H8", "02");			      #? 
   $ret .= pack("h8", _itop($anz));     		      #songs in pl
   $ret .= pack("h8", _itop($type));  	              # 1 = main .. 0=not main
   $ret .= pack("H8", "00"); 			      #?
   $ret .= pack("H8", "00");                          #?
   $ret .= pack("H8", "00");                          #?
   $ret .= pack("H144", "00");       		      #dummy space

 return $ret.$appnd;
}


## PLAYLIST ##################################################
# header for new Playlist item (child if mk_mhyp)
sub mk_mhip
 {
my ($id) = @_;
  
my $ret = "mhip";
   $ret .= pack("h8", _itop(76));
   $ret .= pack("h8", _itop(76));
   $ret .= pack("h8", _itop(1));
   $ret .= pack("H8", "00");
   $ret .= pack("h8", _itop($id)); #song id in playlist
   $ret .= pack("h8", _itop($id)); #ditto.. don't know the difference, but this seems to work
                                  #maybe a special ID used for playlists?!
   $ret .= pack("H96", "00");
  return $ret;
 }








## _INTERNAL ###################################################
#Convert utf8 (what we got from XML::Parser) to utf16 (ipod)
sub _ipod_string {
my ($utf8string) = @_;
#We got utf8 from parser, the iPod likes utf16.., swapped..
$utf8string = Unicode::String::utf8($utf8string)->utf16;
$utf8string = Unicode::String::byteswap2($utf8string);
return $utf8string;
}



## _INTERNAL ##################################################
#returns a /dummy) timestamp in MAC time format
sub _mactime {
#my $x  = time();
#my   $x = 2082844800;
my $x = 666;
return sprintf("%08X", $x);
}



## _INTERNAL ##################################################
#int to ipod
sub _itop
{
my($int) = @_;
$int =~ /(\d+)/; #Paranoia checking..
$int = $1;
return scalar(reverse(sprintf("%08X", $int)));
}



## _INTERNAL ##################################################
#Create a dummy listview, this function could disappear in
#future, only meant to be used internal by this module, dont
#use it yourself..
sub __dummy_listview
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

1;
