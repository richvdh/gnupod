# iTunesDB.pm - Version 20030723
#
# (C) 2003 Adrian Ulrich <pab@blinkenlights.ch>
#
# --------------------------------------------------------
# This program may be copied only under the terms of the
# GNU General Public License v2 or later.
# --------------------------------------------------------
#
#
=head1 NAME

iTunesDB - Read/Write the DB File of an iPod

=head1 SYNOPSIS

   use iTunesDB;

=head1 DESCRIPTION

With this module, you can read and write an iTunesDB.
Apple uses this Format to store information about
Songs (Name, Comment, Rating, Bitrate...) and Playlists
on (eg.) the iPod.

Because Apple doesn't publish any (free) information
about the format, this module maybe (is) incomplete.
Some (mostly useless) features are *not* supportet atm.

Reverse-Engineering rocks ;-)

=head1 EXPORTED_SYMBOLS

iTunesDB.pm doesn't export anything.

=head1 READING AN iTunesDB

Reading an iTunesDB is very easy, you'll only
have to do something like this: (FIXME!!)

 use iTunesDB;
 my $xmldoc = iTunesDB::parseitunes($ARGV[0]);


You'll get the hashref '$xmldoc'.

You can use XML::Simple::XMLout to
see the XML-Doc
(Note: XML::Simple is loaded by
 iTunesDB.pm)

 XML::Simple::XMLout($xmldoc,keeprot=>1);


..foo

=cut


package GNUpod::iTunesDB;
use strict;
use Unicode::String;

use vars qw(%mhod_id @mhod_array);


%mhod_id = ("title", 1, "path", 2, "album", 3, "artist", 4, "genre", 5, "fdesc", 6, "eq", 7, "comment", 8, "composer", 12, "PLTHING", 100) ;

 foreach(keys(%mhod_id)) {
  $mhod_array[$mhod_id{$_}] = $_;
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

#We have to fix 'volume'
my $vol = sprintf("%.0f",( int($file_hash{volume})*2.55 ));

if($vol >= 0 && $vol <= 255) { } #Nothing to do
elsif($vol < 0 && $vol >= -255) {            #Convert value
 $vol = oct("0xFFFFFFFF") + $vol; 
}
else {
 print "Warning: ID $file_hash{id} has volume set to $file_hash{volume} percent. Ignoring value\n";
 $vol = 0; #We won't nuke the iPod with an ultra high volume setting..
}

#print ">> $vol // $file_hash{volume}%\n" if $vol;

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
   $ret .= pack("H8", "000044AC");                          #Srate*something ?!?
   $ret .= pack("h8", _itop($vol));                         #Volume
   $ret .= pack("h8", _itop($file_hash{starttime}));        #Start time?
   $ret .= pack("h8", _itop($file_hash{stoptime}));          #Stop time?
   $ret .= pack("H8");
   $ret .= pack("h8", _itop($file_hash{playcount}));
   $ret .= pack("H8");                                      #Sometimes eq playcount .. ?!
   $ret .= pack("h8", _mactime());                          #Last playtime.. FIXME
#   $ret .= pack("H32");                                     #dummyspace
   $ret .= pack("h8", _itop($file_hash{cdnum}));            #cd number
   $ret .= pack("h8", _itop($file_hash{cds}));              #number of cds
   $ret .= pack("H8");                                      #hardcoded space 
   $ret .= pack("h8", _mactime());                          #dummy timestamp again...
   $ret .= pack("H16");
   $ret .= pack("H8", "BBF85D87");                          #??
   $ret .= pack("h8", _itop($file_hash{rating}*5120));      #rating, FIXME: doesn't work
   $ret .= pack("H8", "0000FFFF");                          # ???
   $ret .= pack("H56");                                     #
return $ret;
}

## GENERAL ##########################################################
# An mhod simply holds information

sub mk_mhod
{
##   - type id
#1   - titel
#2   - ipod filename
#3   - album
#4   - interpret
#5   - genre
#6   - filetype
#7   - ??? (EQ?)
#8   - comment
#12  - composer
#50  - SPL Stuff
#51  - SPL Stuff
#100 - Playlist item or/and PlaylistLayout (used for trash? ;))

my ($type_string, $string, $fqid) = @_;

my $type = $mhod_id{lc($type_string)};

return undef if !$type && !$fqid; #Invalid type string.. no problemo
#Appnd size for normal mhod's
my $mod = 40;

if(!$fqid) { 
  #normal mhod, default fqid
  $fqid = 1; 
  $fqid = 1397519220 if $type == 51; #Fixme: are spl mhods no pl mhods?
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
$ret .= pack("h8", _itop($fqid));                  #Refers to this id if a PL item
                                                  #else ->  1
						  #for spl -> 534C7374 (SLst)
						  #FIXME: this sub can't create spl items
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


## END WRITE FUNCTIONS ##




### Here are the READ sub's used by tunes2pod.pl

###########################################
# Get a INT value
sub get_int {
my($start, $anz) = @_;

my($buffer, $xx, $xr) = undef;
# paranoia checks
$start = int($start);
$anz = int($anz) || 1;

#seek to the given position
seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);
   foreach(split(//, $buffer)) {
    $xx = sprintf("%02X", ord($_));
   $xr = "$xx$xr";
  }
  $xr = oct("0x".$xr);
 return $xr;
}



###########################################
#get a SINGLE mhod entry:
# return+seek = new_mhod should be there
sub get_mhod {
my ($seek) = @_;

my $id  = get_string($seek, 4);          #are we lost?
my $ml  = get_int($seek+8, 4);           #Length of this mhod
my $mty = get_int($seek+12, 4);          #type number
my $xl  = get_int($seek+28,4);           #String length

if($id eq "mhod") { #Seek was okay
   my $foo = get_string($seek+40, $xl); #string of the entry            #maybe a 'no conv' flag would be better
    #$foo is now UTF16 (Swapped), but we need an utf8
    $foo = Unicode::String::byteswap2($foo);
    $foo = Unicode::String::utf16($foo)->utf8;
 if(!$mhod_array[$mty]) {
  print STDOUT "WARNING: unknown type: $mty, returning RAW data (SmartPlaylist's aren't supportet atm..)\n";
  $foo = get_string($seek+40, $xl);
 }
  return ($ml, $foo, $mty);
}

#Was no mhod, return -1
return -1;
}



##############################################
# get an mhip entry
sub get_mhip {
 my($pos) = @_;
 if(get_string($pos, 4) eq "mhip") {
  my $oof = get_int($pos+4, 4);
  my($oid) = get_mhod($pos+$oof);
  return $oid if $oid == -1; #fatal error..
   my $px = get_int($pos+6*4, 4);
  return ($oid+$oof, $px);
 }

#we are lost
 return -1;
}


###########################################
# Reads a string
sub get_string {
my ($start, $anz) = @_;
my($buffer) = undef;
$start = int($start);
$anz = int($anz) || 1;
seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);
 return $buffer;
}




#############################################
# Get a playlist
sub get_pl {
 my($pos) = @_;
 my %ret_hash = ();
 my @pldata = ();
 
  if(get_string($pos, 4) eq "mhyp") { #Ok, its an mhyp
   my $pl_type    = get_int($pos+20, 4); #Is it a main playlist?
   my $scount     = get_int($pos+16, 4); #How many songs should we expect?
   my $header_len = get_int($pos+4, 4);
   
   $pos += $header_len; #set pos to start of first mhod
  
   #We can now read the name of the Playlist
   #Ehpod is buggy and writes the playlist name 2 times.. well catch both of them
   #MusicMatch is also stupid and doesn't create a playlist mhod
   #for the mainPlaylist
   my ($oid, $plt, $type, $plname, $itt) = undef;
   
   while($oid != -1) {
    $pos += $oid;
    ($oid, $plt, $type) = get_mhod($pos);
    $plname = $plt if $type == 1;
    #1 = name
    #100 = style
    #50  = ??
    #51  = ??
   }
   $ret_hash{name} = $plname;
   $ret_hash{type} = $pl_type;
   
   #Now get the items
   $oid = 0; #clean oid
 for(my $i = 0; $i<$scount;$i++) {
    ($oid, $itt) = get_mhip($pos);
    if($oid == -1) {
       print STDERR "*** FATAL: Expected to find $scount songs,\n";
       print STDERR "*** but i failed to get nr. $i\n";
       print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
       print STDERR "*** a bug in GNUpod. Please send this\n";
       print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
       exit(1);
    }
    $pos += $oid;
     push(@pldata, $itt) if $itt;
   }
   $ret_hash{content} = \@pldata;
   return ($pos, \%ret_hash);   
  }
 
 #Seek was wrong
 return -1;
}



###########################################
# Get mhits
sub get_mhits {
my ($sum) = @_;
if(get_string($sum, 4) eq "mhit") { #Ok, its a mhit

my %ret     = ();

#Infos stored in mhit
$ret{id}       = get_int($sum+16,4);
$ret{filesize} = get_int($sum+36,4);
$ret{time}     = get_int($sum+40,4);
$ret{cdnum}    = get_int($sum+92,4);
$ret{cds}      = get_int($sum+96,4);
$ret{songnum}  = get_int($sum+44,4);
$ret{songs}    = get_int($sum+48,4);
$ret{year}     = get_int($sum+52,4);
$ret{bitrate}  = get_int($sum+56,4);
$ret{volume}   = get_int($sum+64,4);
$ret{starttime}= get_int($sum+68,4);
$ret{stoptime} = get_int($sum+72,4);
$ret{playcount} = get_int($sum+80,4); #84 has also something to do with playcounts.
$ret{rating}   = int(get_int($sum+120,4) / 5120); #We would like to write 'rating="1"', not
                                               #rating='5120' to the GNUtunesDB


####### We have to convert the 'volume' to percent...
####### The iPod doesn't store the volume-value in percent..
#Minus value (-X%)
$ret{volume} -= oct("0xffffffff") if $ret{volume} > 255;

#Convert it to percent
$ret{volume} = sprintf("%.0f",($ret{volume}/2.55));

## Paranoia check
if(abs($ret{volume}) > 100) {
 print " *** BUG *** .. Volume is $ret{volume} percent.. this is impossible :)\n";
 print "Please send this iTunesDB to pab\@blinkenlights.ch .. thanks :)\n";
 print ">> Volume set to 0 percent..\n";
 $ret{volume} = 0;
}


 #Now get the mhods from this mhit
$sum += get_int($sum+4,4);
 my ($next_start, $txt, $type) = undef;
    while($next_start != -1) {
     $sum += $next_start; 
     ($next_start, $txt, $type) = get_mhod($sum);    #returns the number where its guessing the next mhod, -1 if it's failed
       #Convert ID to XML Name
       my $xml_name = $mhod_array[$type];
       if($xml_name) { #add known name to hash
        $ret{$xml_name} = $txt;
       }
 
    }
    
return ($sum,\%ret);          #black magic, returns next (possible?) start of the mhit
}
#Was no mhod
 return -1;
}



#########################################################
# Returns start of part1 (files) and part2 (playlists)
sub get_starts {
#Get start of first mhit:
my $mhbd_s     = get_int(4,4);
my $pdi        = get_int($mhbd_s+8,4); #Used to calculate start of playlist
my $mhsd_s     = get_int($mhbd_s+4,4);
my $mhlt_s     = get_int($mhbd_s+$mhsd_s+4,4);
my $pos = $mhbd_s+$mhsd_s+$mhlt_s; #pos is now the start of the first mhit (always 292?);

#How many songs are on the iPod ?
my $sseek = $mhbd_s + $mhsd_s;
my $songs = get_int($sseek+8,4);

#How many playlists should we find ?
$sseek = $mhbd_s + $pdi;
$sseek += get_int($sseek+4,4);
my $pls = get_int($sseek+8,4);

return($pos, ($pos+$pdi), $songs, $pls);
}


########################################################
# Open the iTunesDB file..
sub open_itunesdb {
 open(FILE, $_[0]);
}

########################################################
# Close the iTunesDB file..
sub close_itunesdb {
 close(FILE);
}


1;
