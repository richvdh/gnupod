# iTunesDB.pm - Version 20040116
#  Copyright (C) 2002-2004 Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://blinkenlights.ch/cgi-bin/fm.pl?get=ipod
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
use GNUpod::FooBar;

use vars qw(%mhod_id @mhod_array);

#mk_mhod() will take care of lc() entries
%mhod_id = ("title", 1, "path", 2, "album", 3, "artist", 4, "genre", 5, "fdesc", 6, "eq", 7, "comment", 8, "composer", 12);# "SPLPREF",50, "SPLDATA",51, "PLTHING", 100) ;
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
my %file_hash = %{$hr->{fh}};

#We have to fix 'volume'
my $vol = sprintf("%.0f",( int($file_hash{volume})*2.55 ));

if($vol >= 0 && $vol <= 255) { } #Nothing to do
elsif($vol < 0 && $vol >= -255) {            #Convert value
 $vol = oct("0xFFFFFFFF") + $vol; 
}
else {
 print STDERR "** Warning: ID $file_hash{id} has volume set to $file_hash{volume} percent. Volume set to +-0%\n";
 $vol = 0; #We won't nuke the iPod with an ultra high volume setting..
}

foreach( ("rating", "prerating") ) {
 if($file_hash{$_} && $file_hash{$_} !~ /^(2|4|6|8|10)0$/) {
  print STDERR "Warning: Song $file_hash{id} has an invalid $_: $file_hash{$_}\n";
  $file_hash{$_} = 0;
 }
}


#Check for stupid input
my ($c_id) = $file_hash{id} =~ /(\d+)/;
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
                            *($file_hash{rating}/20))));     #type+rating .. this is very STUPID..
   $ret .= pack("h8", _mactime());                           #timestamp (we create a dummy timestamp, iTunes doesn't seem to make use of this..?!)
   $ret .= pack("h8", _itop($file_hash{filesize}));          #filesize
   $ret .= pack("h8", _itop($file_hash{time}));              #seconds of song
   $ret .= pack("h8", _itop($file_hash{songnum}));           #nr. on CD .. we dunno use it (in this version)
   $ret .= pack("h8", _itop($file_hash{songs}));             #songs on this CD
   $ret .= pack("h8", _itop($file_hash{year}));              #the year
   $ret .= pack("h8", _itop($file_hash{bitrate}));           #bitrate
   $ret .= pack("H4", "00");                                #??
   $ret .= pack("h4", _itop( ($file_hash{srate} || 44100),0xffff));    #Srate (note: h4!)
   $ret .= pack("h8", _itop($vol));                         #Volume
   $ret .= pack("h8", _itop($file_hash{starttime}));        #Start time?
   $ret .= pack("h8", _itop($file_hash{stoptime}));          #Stop time?
   $ret .= pack("H8");
   $ret .= pack("h8", _itop($file_hash{playcount}));
   $ret .= pack("H8");                                      #Sometimes eq playcount .. ?!
   $ret .= pack("h8");                                      #Last playtime.. FIXME
   $ret .= pack("h8", _itop($file_hash{cdnum}));            #cd number
   $ret .= pack("h8", _itop($file_hash{cds}));              #number of cds
   $ret .= pack("H8");                                      #hardcoded space 
   $ret .= pack("h8", _mactime());                          #dummy timestamp again...
   $ret .= pack("H16");
   $ret .= pack("H8");                          #??
   $ret .= pack("h8", _itop(($file_hash{prerating}/20)*oct('0x140000')));      #This is also stupid: the iTunesDB has a rating history
   $ret .= pack("H8");                          # ???
   $ret .= pack("H56");  
                         
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
elsif(!$type) { #No type and no fqid, skip it
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


## GENERAL #################################################################
# Create a spl-pref (type=50) mhod
sub mk_splprefmhod {
 my($hs) = @_;
 my($live, $chkrgx, $chklim, $mos) = 0;
 #Bool stuff
 $live        = 1 if $hs->{liveupdate};
my $checkrule   = int($hs->{checkrule});
 $mos         = 1 if $hs->{mos};

if($checkrule < 1 || $checkrule > 3) {
 warn "iTunesDB.pm: error: 'checkrule' ($checkrule) out of range. value set to 1 (=LimitMatch)\n";
 $checkrule = 1;
}

$chkrgx = 1 if $checkrule>1;
$chklim = $checkrule-$chkrgx*2;
#lim-only = 1 / match only = 2 / both = 3

 my $ret = "mhod";
 $ret .= pack("h8", _itop(24));    #Size of header
 $ret .= pack("h8", _itop(96));
 $ret .= pack("h8", _itop(50));
 $ret .= pack("H16");
 $ret .= pack("h2", _itop($live,0xff)); #LiveUpdate ?
 $ret .= pack("h2", _itop($chkrgx,0xff)); #Check regexps?
 $ret .= pack("h2", _itop($chklim,0xff)); #Check limits?
 $ret .= pack("h2", _itop($hs->{item},0xff)); #Wich item?
 $ret .= pack("h2", _itop($hs->{sort},0xff)); #How to sort
 $ret .= pack("h6");
 $ret .= pack("h8", _itop($hs->{value})); #lval
 $ret .= pack("h2", _itop($mos,0xff));        #mos
 $ret .= pack("h118");
}

## GENERAL #################################################################
# Create a spl-data (type=51) mhod
sub mk_spldatamhod {
 my($hs) = @_;

 my $anymatch = 1 if $hs->{anymatch};

if(ref($hs->{data}) ne "ARRAY") {
 warn "iTunesDB.pm: warning: no spldata found in spl, iTunes4-workaround enabled\n";
 push(@{$hs->{data}}, {field=>4,action=>2,string=>""});
}

 my $cr = undef;
 foreach my $chr (@{$hs->{data}}) {
     my $string = undef;
#Fixme: this is ugly (same as read_spldata)
     if($chr->{field} =~ /^(2|3|4|8|9|14|18)$/) {
        $string = Unicode::String::utf8($chr->{string})->utf16;
     }
     else {
        my ($from, $to) = $chr->{string} =~ /(\d+):?(\d*)/;
        $to ||=$from;
        $string  = pack("H8");
        $string .= pack("H8", _x86itop($from));
        $string .= pack("H24");
        $string .= pack("H8", _x86itop(1));
        $string .= pack("H8");
        $string .= pack("H8", _x86itop($to));
        $string .= pack("H24");
        $string .= pack("H8", _x86itop(1));
        $string .= pack("H40");
      #  __hd($string);
     }

     if(length($string) > 254) { #length field is limited to 0xfe!
        warn "iTunesDB.pm: splstring to long for iTunes, cropping\n";
        $string = substr($string,0,254);
     }
     
     $cr .= pack("H6");
     $cr .= pack("h2", _itop($chr->{field},0xff));
     $cr .= pack("H6", reverse("010000"));
     $cr .= pack("h2", _itop($chr->{action},0xff));
     $cr .= pack("H94");
     $cr .= pack("h2", _itop(length($string),0xff));
     $cr .= $string;
 }

 my $ret = "mhod";
 $ret .= pack("h8", _itop(24));    #Size of header
 $ret .= pack("h8", _itop(length($cr)+160));    #header+body size
 $ret .= pack("h8", _itop(51));    #type
 $ret .= pack("H16");
 $ret .= "SLst";                   #Magic
 $ret .= pack("H8", reverse("00010001")); #?
 $ret .= pack("h6");
 $ret .= pack("h2", _itop(int(@{$hs->{data}}),0xff));     #HTM (Childs from cr)
 $ret .= pack("h6");
 $ret .= pack("h2", _itop($anymatch,0xff));     #anymatch rule on or off
 $ret .= pack("h240");


 $ret .= $cr;
return $ret;
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
my $appnd = mk_mhod({stype=>"title", string=>$hr->{name}}).__dummy_listview();   #itunes prefs for this PL & PL name (default PL has  device name as PL name)

##Child mhods calc..
##We create 2 mhod's here.. mktunes may have created more mhods.. so we
##have to adjust the childs here
my $cmh = 2+$hr->{mhods};

my $ret .= "mhyp";
   $ret .= pack("h8", _itop(108)); #type
   $ret .= pack("h8", _itop($hr->{size}+108+(length($appnd))));          #size
   $ret .= pack("h8", _itop($cmh));			      #mhods
   $ret .= pack("h8", _itop($hr->{files}));   #songs in pl
   $ret .= pack("h8", _itop($hr->{type}));    # 1 = main .. 0=not main
   $ret .= pack("H8", "00"); 			      #?
   $ret .= pack("H8", "00");                  #?
   $ret .= pack("H8", "00");                  #?
   $ret .= pack("H144", "00");       		  #dummy space

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
   $ret .= pack("h8", _itop($hr->{childs})); #Mhod childs !
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
#returns a (dummy) timestamp in MAC time format
sub _mactime {
my $x =    1234567890;
return sprintf("%08X", $x);
}



## _INTERNAL ##################################################
#int to ipod
sub _itop
{
my($in, $checkmax) = @_;
my($int) = $in =~ /(\d+)/;

$checkmax |= 0xffffffff;

if($int > $checkmax) {
 die "iTunesDB.pm: FATAL: $int > $checkmax (<- maximal value), can't continue!\n"
}

return scalar(reverse(sprintf("%08X", $int )));
}

## _INTERNAL ##################################################
#int to x86 ipodval (spl!!)
sub _x86itop
{
my($in, $checkmax) = @_;
my($int) = $in =~ /(\d+)/;

$checkmax |= 0xffffffff;

if($int > $checkmax) {
 die "iTunesDB.pm: FATAL: $int > $checkmax (<- maximal value), can't continue!\n"
}


return scalar((sprintf("%08X", $int )));
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
# Get a INT value
sub get_int {
my($start, $anz) = @_;
my $buffer = undef;
# paranoia checks
$start = int($start);
$anz = int($anz);
#seek to the given position
seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);
 return GNUpod::FooBar::shx2int($buffer);
}


###########################################
# Get a x86INT value
sub get_x86_int {
my($start, $anz) = @_;

my($buffer, $xx, $xr) = undef;
# paranoia checks
$start = int($start);
$anz = int($anz);

#seek to the given position
seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);
 return GNUpod::FooBar::shx2_x86_int($buffer);
}



####################################################
# Get all SPL items
sub read_spldata {
 my($hr) = @_;
 
my $diff = $hr->{start}+160;
my @ret = ();

 for(1..$hr->{htm}) {
  my $field = get_int($diff+3, 1);
  my $action= get_int($diff+7, 1);
  my $slen  = get_int($diff+55,1); #Whoa! This is true: string is limited to 0xfe (254) chars!! (iTunes4)
  my $rs    = undef; #ReturnSting
#Fixme: this is ugly
   if($field =~ /^(2|3|4|8|9|14|18)$/) { #Is a string type
    my $string= get_string($diff+56, $slen);
    #No byteswap here?? why???
    $rs = Unicode::String::utf16($string)->utf8;
   }
   else { #Is INT (Or range)
    my $xfint = get_x86_int($diff+56+4,4);
    my $xtint = get_x86_int($diff+56+28,4);
    $rs = "$xfint:$xtint";
   }
  $diff += $slen+56;
  push(@ret, {field=>$field,action=>$action,string=>$rs});
 }
 return \@ret;
}


#################################################
# Read SPLpref data
sub read_splpref {
 my($hs) = @_;
 my ($live, $chkrgx, $chklim, $mos);
 
    $live    = 1 if   get_int($hs->{start}+24,1);
    $chkrgx  = 1 if get_int($hs->{start}+25,1);
    $chklim  = 1 if get_int($hs->{start}+26,1);
 my $item    =    get_int($hs->{start}+27,1);
 my $sort    =    get_int($hs->{start}+28,1);
 my $limit   =   get_int($hs->{start}+32,4);
    $mos     = 1 if get_int($hs->{start}+36,1);
 return({live=>$live,
         value=>$limit, iitem=>$item, isort=>$sort,mos=>$mos,checkrule=>($chklim+($chkrgx*2))});
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

## That's spl stuff, only to be used with 51 mhod's
my $htm = get_int($seek+35,1); #Only set for 51
my $anym= get_int($seek+39,1); #Only set for 51
my $spldata = undef; #dummy
my $splpref = undef; #dummy

if($id eq "mhod") { #Seek was okay
    my $foo = get_string($seek+($ml-$xl), $xl); #string of the entry 
    #$foo is now UTF16 (Swapped), but we need an utf8
    $foo = Unicode::String::byteswap2($foo);
    $foo = Unicode::String::utf16($foo)->utf8;

 ##Special handling for SPLs
 if($mty == 51) { #Get data from spldata mhod
   $foo = undef;
   $spldata = read_spldata({start=>$seek, htm=>$htm});
 }
 elsif($mty == 50) { #Get prefs from splpref mhod
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
 my $oid = 0;
 if(get_string($pos, 4) eq "mhip") {
  my $oof = get_int($pos+4, 4);
  my $mhods=get_int($pos+12,4);

  for(my $i=0;$i<$mhods;$i++) {
   my $mhs = get_mhod($pos+$oof)->{size};
   die "Fatal seek error in get_mhip, can't continue\n" if $mhs == -1;
   $oid+=$mhs;
  }

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
# Get a playlist (Should be called get_mhyp, but it does the whole playlist)
sub get_pl {
 my($pos) = @_;

 my %ret_hash = ();
 my @pldata = ();
 
  if(get_string($pos, 4) eq "mhyp") { #Ok, its an mhyp
      $ret_hash{type} = get_int($pos+20, 4); #Is it a main playlist?
   my $scount         = get_int($pos+16, 4); #How many songs should we expect?
   my $header_len     = get_int($pos+4, 4);  #Size of the header
   my $mhyp_len     = get_int($pos+8, 4);   #Size of mhyp
   my $mhods          = get_int($pos+12,4); #How many mhods we have here
#Its a MPL, do a fast skip
if($ret_hash{type}) {
 return ($pos+$mhyp_len, {type=>1}) 
}
   $pos += $header_len; #set pos to start of first mhod
   #We can now read the name of the Playlist
   #Ehpod is buggy and writes the playlist name 2 times.. well catch both of them
   #MusicMatch is also stupid and doesn't create a playlist mhod
   #for the mainPlaylist
   my ($oid, $plname, $itt) = undef;
 for(my $i=0;$i<$mhods;$i++) {
   my $mhh = get_mhod($pos);
   if($mhh->{size} == -1) {
    print STDERR "*** FATAL: Expected to find $mhods mhods,\n";
    print STDERR "*** but i failed to get nr. $i\n";
    print STDERR "*** Please send your iTuneDB to:\n";
    print STDERR "*** pab\@blinkenlights.ch\n";
    print STDERR "!!! iTunesDB.pm panic!\n";
    exit(1);
   }
   $pos+=$mhh->{size};
   if($mhh->{type} == 1) {
     $ret_hash{name} = $mhh->{string};
   }
   elsif(ref($mhh->{splpref}) eq "HASH") {
     $ret_hash{splpref} = $mhh->{splpref};
   }
   elsif(ref($mhh->{spldata}) eq "ARRAY") {
     $ret_hash{spldata} = $mhh->{spldata};
     $ret_hash{matchrule}=$mhh->{matchrule};
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
       print STDERR "!!! iTunesDB.pm panic!\n";
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
# Get mhit + child mhods
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
$ret{srate}    = get_int($sum+62,2); #What is 60-61 ?!!
$ret{volume}   = get_int($sum+64,4);
$ret{starttime}= get_int($sum+68,4);
$ret{stoptime} = get_int($sum+72,4);
$ret{playcount} = get_int($sum+80,4); #84 has also something to do with playcounts. (Like rating + prerating?)
$ret{rating}    = int((get_int($sum+28,4)-256)/oct('0x14000000')) * 20;
$ret{prerating} = int(get_int($sum+120,4) / oct('0x140000')) * 20;

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
my $mhods = get_int($sum+12,4);
$sum += get_int($sum+4,4);

 for(my $i=0;$i<$mhods;$i++) {
    my $mhh = get_mhod($sum);
    if($mhh->{size} == -1) {
     print STDERR "** FATAL: Expected to find $mhods mhods,\n";
     print STDERR "** but i failed to get nr $i\n";
     print STDERR "*** Please send your iTuneDB to:\n";
     print STDERR "*** pab\@blinkenlights.ch\n";
     print STDERR "!!! iTunesDB.pm panic!\n";     
     exit(1);
    }
    $sum+=$mhh->{size};
    my $xml_name = $mhod_array[$mhh->{type}];
    if($xml_name) { #Has an xml name.. sounds interesting
      $ret{$xml_name} = $mhh->{string};
    }
    else {
     warn "iTunesDB.pm: found unhandled mhod type '$mhh->{type}'\n";
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



######################## Other funny stuff #########################


##############################################
# Read PlayCounts (We don't read the PLAYTIME)
sub readPLC {
 my($file) = @_;
 open(RATING, "$file") or return ();
 
 my $offset = 16*6;
 my $buff;
 my %pcrh = ();
 while(1) {

  seek(RATING, $offset+12, 0);
  last unless read(RATING,$buff,4) ==4;
  my $rating = GNUpod::FooBar::shx2int($buff);
  
  seek(RATING, $offset, 0);
  read(RATING,$buff,4);
  my $playc  = GNUpod::FooBar::shx2int($buff);
  
  my $songnum = (($offset-(16*6))/16)+1;

  $pcrh{playcount}{$songnum} = $playc if $playc;
  $pcrh{rating}{$songnum}    = $rating if $rating; 
  warn "debug: $songnum> $playc / $rating\n" if $playc||$rating;

  $offset += 16;
 }

close(RATING);
 return \%pcrh;
}


##############################################
# Read OnTheGo data
sub readOTG {
 my($file) = @_;
 
 my $buff = undef;
 open(OTG, "$file") or return ();
  seek(OTG, 12, 0);
  read(OTG, $buff, 4);
  
  my $items = GNUpod::FooBar::shx2int($buff); 

  my @content = ();
  my $offst = 20;
  for(1..$items) {
   seek(OTG, $offst, 0);
   read(OTG, $buff, 4);
   push(@content, GNUpod::FooBar::shx2int($buff));
   $offst+=4;
  }
  return @content;
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
