# iTunesDB.pm - Version 20030923
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

package GNUpod::iTunesDB;
use strict;
use Unicode::String;

use vars qw(%mhod_id @mhod_array);


%mhod_id = ("title", 1, "path", 2, "album", 3, "artist", 4, "genre", 5, "fdesc", 6, "eq", 7, "comment", 8, "composer", 12, "SPLPREF",50, "SPLDATA",51, "PLTHING", 100) ;

 foreach(keys(%mhod_id)) {
  $mhod_array[$mhod_id{$_}] = $_;
 }

## GENERAL #########################################################
# create an iTunesDB header
sub mk_mhbd
{
my ($hr) = @_;

my $ret = "mhbd";
   $ret .= pack("h8", _itop(104));                  #Header Size
   $ret .= pack("h8", _itop($hr->{size}+104));       #size of the whole mhdb
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
my ($hr) = @_;

my $ret = "mhsd";
   $ret .= pack("h8", _itop(96));                      #Headersize, static
   $ret .= pack("h8", _itop($hr->{size}+96));               #Size
   $ret .= pack("h8", _itop($hr->{type}));                   #type .. 1 = song .. 2 = playlist
   $ret .= pack("H160", "00");                        #dummy space
return $ret;
}

## GENERAL ##########################################################
# Create an mhit entry, needs to know about the length of his
# mhod(s) (You have to create them yourself..!)
sub mk_mhit {
my($hr) = @_;
my $file_hash = $hr->{fh};

#We have to fix 'volume'
my $vol = sprintf("%.0f",( int($file_hash->{volume})*2.55 ));

if($vol >= 0 && $vol <= 255) { } #Nothing to do
elsif($vol < 0 && $vol >= -255) {            #Convert value
 $vol = oct("0xFFFFFFFF") + $vol; 
}
else {
 print STDERR "** Warning: ID $file_hash->{id} has volume set to $file_hash->{volume} percent. Volume set to +-0%\n";
 $vol = 0; #We won't nuke the iPod with an ultra high volume setting..
}

foreach( ("rating", "prerating") ) {
 if($file_hash->{$_} < 0 || $file_hash->{$_} > 5) {
  print STDERR "Warning: Song $file_hash->{id} has an invalid $_: $file_hash->{$_}\n";
  $file_hash->{$_} = 0;
 }
}


#Check for stupid input
my ($c_id) = $file_hash->{id} =~ /(\d+)/;
if($c_id < 1) {
  print STDERR "Warning: ID has can't be $c_id, has to be > 0\n";
  print STDERR "         This song *won't* be visible on the iPod\n";
}

my $ret = "mhit";
   $ret .= pack("h8", _itop(156));                           #header size
   $ret .= pack("h8", _itop(int($hr->{size})+156));           #len of this entry
   $ret .= pack("h8", _itop($hr->{count}));                     #num of mhods in this mhit
   $ret .= pack("h8", _itop($c_id));                 #Song index number
   $ret .= pack("h8", _itop(1));                             #?
   $ret .= pack("H8");                                      #dummyspace
   $ret .= pack("h8", _itop(256+(oct('0x14000000')
                            *$file_hash->{rating})));           #type+rating .. this is very STUPID..
   $ret .= pack("h8", _mactime());                           #timestamp (we create a dummy timestamp, iTunes doesn't seem to make use of this..?!)
   $ret .= pack("h8", _itop($file_hash->{filesize}));          #filesize
   $ret .= pack("h8", _itop($file_hash->{time}));              #seconds of song
   $ret .= pack("h8", _itop($file_hash->{songnum}));           #nr. on CD .. we dunno use it (in this version)
   $ret .= pack("h8", _itop($file_hash->{songs}));             #songs on this CD
   $ret .= pack("h8", _itop($file_hash->{year}));              #the year
   $ret .= pack("h8", _itop($file_hash->{bitrate}));           #bitrate
   $ret .= pack("H8", "000044AC");                          #Srate*something ?!?
   $ret .= pack("h8", _itop($vol));                         #Volume
   $ret .= pack("h8", _itop($file_hash->{starttime}));        #Start time?
   $ret .= pack("h8", _itop($file_hash->{stoptime}));          #Stop time?
   $ret .= pack("H8");
   $ret .= pack("h8", _itop($file_hash->{playcount}));
   $ret .= pack("H8");                                      #Sometimes eq playcount .. ?!
   $ret .= pack("h8");                                      #Last playtime.. FIXME
   $ret .= pack("h8", _itop($file_hash->{cdnum}));            #cd number
   $ret .= pack("h8", _itop($file_hash->{cds}));              #number of cds
   $ret .= pack("H8");                                      #hardcoded space 
   $ret .= pack("h8", _mactime());                          #dummy timestamp again...
   $ret .= pack("H16");
   $ret .= pack("H8");                          #??
   $ret .= pack("h8", _itop($file_hash->{prerating}*oct('0x140000')));      #This is also stupid: the iTunesDB has a rating history
   $ret .= pack("H8");                          # ???
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
#7   - EQ Setting
#8   - comment
#12  - composer
#50  - SPL Stuff
#51  - SPL Stuff
#100 - Playlist item or/and PlaylistLayout (used for trash? ;))

my ($hr) = @_;
my $type_string = $hr->{stype};
my $string = $hr->{string};
my $fqid = $hr->{fqid};
my $type = $mhod_id{lc($type_string)};

#Appnd size for normal mhod's
my $mod = 40;

#Called with fqid, this has to be an PLTHING (100)
if($fqid) { 
 #fqid set, that's a pl item!
 $type = 100;
 #Playlist mhods are longer
 $mod += 4;
}
elsif(!$type) { #No type, skip it
 return undef;
}
else { #has a type, default fqid
 $fqid=1;
}

if($type == 7 && $string !~ /#!#\d+#!#/) {
warn "iTunesDB.pm: warning: wrong format: '$type_string=\"$string\"'\n";
warn "             value should be like '#!#NUMBER#!#', ignoring value\n";
$string = undef;
}

$string = _ipod_string($string); #cache data
my $ret = "mhod";                 		           #header
$ret .= pack("h8", _itop(24));                     #size of header
$ret .= pack("h8", _itop(length($string)+$mod));   # size of header+body
$ret .= pack("h8", _itop("$type"));                #type of the entry
$ret .= pack("H16");                               #dummy space
$ret .= pack("h8", _itop($fqid));                  #Refers to this id if a PL item
                                                   #else ->  1
$ret .= pack("h8", _itop(length($string)));        #size of string


if($type != 100){ #no PL mhod
 $ret .= pack("h16");           #trash
 $ret .= $string;               #the string
}
else { #PL mhod
 $ret .= pack("h24"); #playlist mhods are a different
}
return $ret;
}


sub mk_splprefmhod {
 my($hs) = @_;
 my($live, $chkrgx, $chklim, $mos) = 0;
 $live   = 1 if $hs->{liveupdate};
 $chkrgx = 1 if $hs->{chkrgx};
 $chklim = 1 if $hs->{chklim};
 $mos    = 1 if $hs->{mos};
 
 my $ret = "mhod";
 $ret .= pack("h8", _itop(24));    #Size of header
 $ret .= pack("h8", _itop(96));
 $ret .= pack("h8", _itop(50));
 $ret .= pack("H16");
 $ret .= pack("h2", _itop($live)); #LiveUpdate ?
 $ret .= pack("h2", _itop($chkrgx)); #Check regexps?
 $ret .= pack("h2", _itop($chklim)); #Check limits?
 $ret .= pack("h2", _itop($hs->{item})); #Wich item?
 $ret .= pack("h2", _itop($hs->{sort})); #How to sort
 $ret .= pack("h6");
 $ret .= pack("h8", _itop($hs->{value})); #lval
 $ret .= pack("h2", _itop($mos));        #mos
 $ret .= pack("h118");
}





## FILES #########################################################
# header for all files (like you use mk_mhlp for playlists)
sub mk_mhlt
{
my ($hr) = @_;

my $ret = "mhlt";
   $ret .= pack("h8", _itop(92)); 		    #Header size (static)
   $ret .= pack("h8", _itop($hr->{songs})); #songs in this itunesdb
   $ret .= pack("H160", "00");                      #dummy space
return $ret;
}









## PLAYLIST #######################################################
# header for ALL playlists
sub mk_mhlp
{

my ($hr) = @_;

my $ret = "mhlp";
   $ret .= pack("h8", _itop(92));                   #Static header size
   $ret .= pack("h8", _itop($hr->{playlists}));          #playlists on iPod (including main!)
   $ret .= pack("h160", "00");                     #dummy space
return $ret;
}


## PLAYLIST ######################################################
# Creates an header for a new playlist (child of mk_mhlp)
sub mk_mhyp
{
my($hr) = @_;

#We need to create a listview-layout and an mhod with the name..
my $appnd = __dummy_listview().mk_mhod({stype=>"title", string=>$hr->{name}});   #itunes prefs for this PL & PL name (default PL has  device name as PL name)

#mk_splprefmhod({stype=>"SPLPREF", value=>"20", sort=>2, liveupdate=>1, chkrgx=>1, chklim=>1, mos=>1, item=>1});
my $ret .= "mhyp";
   $ret .= pack("h8", _itop(108)); #type
   $ret .= pack("h8", _itop($hr->{size}+108+(length($appnd))));          #size
   $ret .= pack("H8", "02");			      #? 
   $ret .= pack("h8", _itop($hr->{files}));   #songs in pl
   $ret .= pack("h8", _itop($hr->{type}));    # 1 = main .. 0=not main
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
my ($hr) = @_;
#sid = SongId
#plid = playlist order ID
my $ret = "mhip";
   $ret .= pack("h8", _itop(76));
   $ret .= pack("h8", _itop(76));
   $ret .= pack("h8", _itop(1));
   $ret .= pack("H8", "00");
   $ret .= pack("h8", _itop($hr->{plid})); #ORDER id
   $ret .= pack("h8", _itop($hr->{sid}));   #song id in playlist
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
my($in) = @_;
my($int) = $in =~ /(\d+)/;
return scalar(reverse(sprintf("%08X", $int )));
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
$ret .= pack("H48", "00");                #?
$ret .= pack("H8", reverse("840001"));  #? (Static?)
$ret .= pack("H8", reverse("01"));      #?
$ret .= pack("H8", reverse("09"));      #?
$ret .= pack("H8", reverse("00"));      #?
$ret .= pack("H8",reverse("010025")); #static? (..or width of col?)
$ret .= pack("H8",reverse("00"));     #how to sort
$ret .= pack("H16", "00");
$ret .= pack("H8", reverse("0200c8"));
$ret .= pack("H8", reverse("01"));
$ret .= pack("H16","00");
$ret .= pack("H8", reverse("0d003c"));
$ret .= pack("H24","00");
$ret .= pack("H8", reverse("04007d"));
$ret .= pack("H24", "00");
$ret .= pack("H8", reverse("03007d"));
$ret .= pack("H24", "00");
$ret .= pack("H8", reverse("080064"));
$ret .= pack("H24", "00");
$ret .= pack("H8", reverse("170064"));
$ret .= pack("H8", reverse("01"));
$ret .= pack("H16", "00");
$ret .= pack("H8", reverse("140050"));
$ret .= pack("H8", reverse("01"));
$ret .= pack("H16", "00");
$ret .= pack("H8", reverse("15007d"));
$ret .= pack("H8", reverse("01"));
$ret .= pack("H752", "00");
$ret .= pack("H8", reverse("65"));
$ret .= pack("H152", "00");

# Every playlist has such an mhod, it tells iTunes (and other programs?) how the
# the playlist shall look (visible coloums.. etc..)
# But we are using always the same layout static.. we don't support this mhod type..
# But we write it (to make iTunes happy)
return $ret
}


## END WRITE FUNCTIONS ##




### Here are the READ sub's used by tunes2pod.pl

###########################################
# Get a x86 INT value (WHY did apple mix this?)
sub get_x86_int {
 my($start, $anz) = @_;
 my($buffer,$xr) = undef;
  seek(FILE, int($start), 0);
  read(FILE, $buffer, int($anz));
  foreach(split(//,$buffer)) {
   $xr .= sprintf("%02X",ord($_));
  
  }
 return(oct("0x".$xr));
}

###########################################
# Get a INT value
sub get_int {
my($start, $anz) = @_;

my($buffer, $xx, $xr) = undef;
# paranoia checks
$start = int($start);
$anz = int($anz);

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

####################################################
# Get all SPL items
sub read_spldata {
 my($hr) = @_;
 
my $diff = $hr->{start}+160;
my @ret = ();

 for(1..$hr->{htm}) {
  my $field = get_x86_int($diff, 4);
  my $action= get_x86_int($diff+7, 1);
  my $slen  = get_x86_int($diff+52,4);
  my $string= get_string($diff+56, $slen);
  #This sucks! no byteswap here.. apple uses x86 endian.. why??
  #Is this an iTunes bug?!
  $string = Unicode::String::utf16($string)->utf8;
=head
  my @xr = ();
  $xr[2] = "SongName";
  $xr[4] = "Artist";
  $xr[7] = "Year";
  $xr[8] = "Genre";
  $xr[9] = "Kind";
  $xr[14] = "Comment";
  $xr[18] = "Composer";
 
  my @xm = ();
  $xm[1] = "IS";
  $xm[2] = "CONTAINS";
  $xm[4] = "STARTS_WITH";
  $xm[8] = "ENDS_WITH";
  $xm[16] = "GTHAN";
=cut
  $diff += $slen+56;
  push(@ret, {field=>$field,action=>$action,string=>$string});
 }
 return \@ret;
}


#################################################
# Read SPLpref data
sub read_splpref {
 my($hs) = @_;
 my $live =    get_int($hs->{start}+24,1);
 my $chkrgx  = get_int($hs->{start}+25,1);
 my $chklim  = get_int($hs->{start}+26,1);
 my $item =    get_int($hs->{start}+27,1);
 my $sort =    get_int($hs->{start}+28,1);
 my $limit =   get_int($hs->{start}+32,4);
 my $mos   =   get_int($hs->{start}+36,1);
# print "Live: $live / rgx $chkrgx / lim $chklim / val $limit / it $item / sort $sort / mos $mos\n";
 return({live=>$live, matchomatic=>$chkrgx, limitomatic=>$chklim,
         value=>$limit, iitem=>$item, isort=>$sort,mos=>$mos});
}

#################################################
# Do a hexDump ..
sub __hd {
   open(KK,">/tmp/XLZ"); print KK $_[0]; close(KK);
   system("hexdump -vC /tmp/XLZ");
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

## That's spl stuff..
## Apple seems to have big and little-endian mixed..?!
my $htm = get_x86_int($seek+32,4); #Only set for 51
my $anym= get_x86_int($seek+36,4); #Only set for 51
my $spldata = undef;
my $splpref = undef;

#__hd(get_string($seek,$ml)) if $mty == 100;
if($id eq "mhod") { #Seek was okay
    my $foo = get_string($seek+($ml-$xl), $xl); #string of the entry            #maybe a 'no conv' flag would be better
    #$foo is now UTF16 (Swapped), but we need an utf8
    $foo = Unicode::String::byteswap2($foo);
    $foo = Unicode::String::utf16($foo)->utf8;

 ##Special handling for SPLs
 if($mty == 51) {
   $foo = undef;
   $spldata = read_spldata({start=>$seek, htm=>$htm});
  __hd(get_string($seek,$ml));

 }
 elsif($mty == 50) {
  $foo = undef;
  $splpref = read_splpref({start=>$seek, end=>$ml});
 }
 
 return({size=>$ml,string=>$foo,type=>$mty,spldata=>$spldata,splpref=>$splpref,matchrule=>$anym});

}
else {
 return({size=>-1});
}
}



##############################################
# get an mhip entry
sub get_mhip {
 my($pos) = @_;
 
 if(get_string($pos, 4) eq "mhip") {
  my $oof = get_int($pos+4, 4);
  my $oid = get_mhod($pos+$oof)->{size};
  return $oid if $oid == -1; #fatal error..
   my $plid = get_int($pos+5*4,4);
   my $sid  = get_int($pos+6*4, 4);
  return({size=>($oid+$oof),sid=>$sid,plid=>$plid});
 }

#we are lost
 return ({size=>-1});
}


###########################################
# Reads a string
sub get_string {
my ($start, $anz) = @_;
my($buffer) = undef;
$start = int($start);
$anz = int($anz);
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
      $ret_hash{type} = get_int($pos+20, 4); #Is it a main playlist?
   my $scount         = get_int($pos+16, 4); #How many songs should we expect?
   my $header_len     = get_int($pos+4, 4);  #Size of the header
   
   $pos += $header_len; #set pos to start of first mhod
  
   #We can now read the name of the Playlist
   #Ehpod is buggy and writes the playlist name 2 times.. well catch both of them
   #MusicMatch is also stupid and doesn't create a playlist mhod
   #for the mainPlaylist
   my ($oid, $plname, $itt) = undef;
   
   while($oid != -1) {
    $pos += $oid;
    my $mhh = get_mhod($pos);
    $oid = $mhh->{size};
     if($mhh->{type} == 1) { #We found the PLname
       $ret_hash{name} = $mhh->{string};
     }
     elsif(ref($mhh->{splpref}) eq "HASH") { #50er mhod (splpref)
       $ret_hash{splpref} = \%{$mhh->{splpref}};
     }
     elsif(ref($mhh->{spldata}) eq "ARRAY") { #51 mhod (spldata)
       $ret_hash{spldata} = \@{$mhh->{spldata}};
       $ret_hash{matchrule} = $mhh->{matchrule};
     }
   }
    
   #Now get the items
 for(my $i = 0; $i<$scount;$i++) {
    my $mhih = get_mhip($pos);
    if($mhih->{size} == -1) {
       print STDERR "*** FATAL: Expected to find $scount songs,\n";
       print STDERR "*** but i failed to get nr. $i\n";
       print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
       print STDERR "*** a bug in GNUpod. Please send this\n";
       print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
       exit(1);
    }
    $pos += $mhih->{size};
     push(@pldata, $mhih->{sid}) if $mhih->{sid};
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

$ret{rating}    = int((get_int($sum+28,4)-256)/oct('0x14000000'));
$ret{prerating} = int(get_int($sum+120,4) / oct('0x140000'));


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
 my ($next_start) = undef;
    while($next_start != -1) {
     $sum += $next_start; 
     my $mhh = get_mhod($sum);    #returns the number where its guessing the next mhod, -1 if it's failed
       $next_start = $mhh->{size};
       #Convert ID to XML Name
       my $xml_name = $mhod_array[$mhh->{type}];
       if($xml_name) { #add known name to hash
        $ret{$xml_name} = $mhh->{string};
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
return({position=>$pos,pdi=>($pos+$pdi),songs=>$songs,playlists=>$pls});
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
