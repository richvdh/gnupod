# iTunesDB.pm - Version 20040313
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

use vars qw(%mhod_id @mhod_array %SPLDEF);

use constant ITUNESDB_MAGIC => 'mhbd';

#mk_mhod() will take care of lc() entries
%mhod_id = ("title", 1, "path", 2, "album", 3, "artist", 4, "genre", 5, "fdesc", 6, "eq", 7, "comment", 8, "composer", 12, "group", 13);# "SPLPREF",50, "SPLDATA",51, "PLTHING", 100) ;
 foreach(keys(%mhod_id)) {
  $mhod_array[$mhod_id{$_}] = $_;
 }




#Human prefix
$SPLDEF{hprefix}{2} = "!";
$SPLDEF{hprefix}{3} = "NOT_";

#String types
$SPLDEF{is_string}{3} = 1;
$SPLDEF{is_string}{1} = 1;



#String Actions
$SPLDEF{string_action}{1} = 'IS';
$SPLDEF{string_action}{2} = 'CONTAINS';
$SPLDEF{string_action}{4} = 'STARTWITH';
$SPLDEF{string_action}{8} = 'ENDWITH';

#Num. Actions
$SPLDEF{num_action}{1}       = "eq";
$SPLDEF{num_action}{0x10}    = "gt";
$SPLDEF{num_action}{0x40}    = "lt";
$SPLDEF{num_action}{0x0100}  = "range";
$SPLDEF{num_action}{0x0200}  = "within";

$SPLDEF{within_key}{86400} = "day";
$SPLDEF{within_key}{86400*7} = "week";
$SPLDEF{within_key}{2628000} = "month";


#Field names  ## string types uc() .. int types lc()

$SPLDEF{field}{2}  = "TITLE";
$SPLDEF{field}{3}  = "ALBUM";
$SPLDEF{field}{4}  = "ARTIST";
$SPLDEF{field}{5}  = "bitrate";
$SPLDEF{field}{6}  = "srate";
$SPLDEF{field}{7}  = "year";
$SPLDEF{field}{8}  = "GENRE";
$SPLDEF{field}{9}  = "FDESC";
$SPLDEF{field}{10} = "changetime";
$SPLDEF{field}{11} = "tracknum";
$SPLDEF{field}{12} = "size";
$SPLDEF{field}{13} = "time";
$SPLDEF{field}{14} = "COMMENT";
$SPLDEF{field}{16} = "addtime";
$SPLDEF{field}{18} = "COMPOSER";
$SPLDEF{field}{22} = "playcount";
$SPLDEF{field}{23} = "playtime";
$SPLDEF{field}{24} = "cdnum";
$SPLDEF{field}{25} = "rating";
$SPLDEF{field}{31} = "compilation";
$SPLDEF{field}{35} = "bpm";
$SPLDEF{field}{39} = "GROUP";
$SPLDEF{field}{40} = "PLAYLIST";


#Checkrule (COMPLETE)
$SPLDEF{checkrule}{1} = "limit";
$SPLDEF{checkrule}{2} = "spl";
$SPLDEF{checkrule}{3} = "both";

#Limititem (COMPLETE)
$SPLDEF{limititem}{1} = "minute";
$SPLDEF{limititem}{2} = "megabyte";
$SPLDEF{limititem}{3} = "song";
$SPLDEF{limititem}{4} = "hour";
$SPLDEF{limititem}{5} = "gigabyte";



$SPLDEF{limitsort}{2}   = "random";
$SPLDEF{limitsort}{3}   = "title";
$SPLDEF{limitsort}{4}   = "album";
$SPLDEF{limitsort}{5}   = "artist";
$SPLDEF{limitsort}{7}   = "genre";

$SPLDEF{limitsort}{16}  = "addtime_high";
$SPLDEF{limitsort}{-16} = "addtime_low";

$SPLDEF{limitsort}{20}  = "playcount_high";
$SPLDEF{limitsort}{-20} = "playcount_low";

$SPLDEF{limitsort}{21}  = "lastplay_high";
$SPLDEF{limitsort}{-21} = "lastplay_low";

$SPLDEF{limitsort}{23}  = "rating_high";
$SPLDEF{limitsort}{-23} = "rating_low";




my %SPLREDEF = _r_spldef();









## GENERAL #########################################################
# create an iTunesDB header
#
sub mk_mhbd {
 my ($hr) = @_;

 my $ret = "mhbd";
    $ret .= pack("h8", _itop(104));                 #Header Size
    $ret .= pack("h8", _itop($hr->{size}+104));     #size of the whole mhdb
    $ret .= pack("H8", "01");                       #?
    $ret .= pack("H8", "01");                       #? - changed to 2 from itunes2 to 3 .. version? We are iTunes version 1 ;)
    $ret .= pack("H8", "02");                       # (Maybe childs?)
    $ret .= pack("H160", "00");                     #dummy space
 return $ret;
}

## GENERAL #########################################################
# a iTunesDB has 2 mhsd's: (This is a child of mk_mhbd)
# mhsd1 holds every song on the ipod
# mhsd2 holds playlists
#
sub mk_mhsd {
 my ($hr) = @_;

 my $ret = "mhsd";
    $ret .= pack("h8", _itop(96));                      #Headersize, static
    $ret .= pack("h8", _itop($hr->{size}+96));          #Size
    $ret .= pack("h8", _itop($hr->{type}));             #type .. 1 = song .. 2 = playlist
    $ret .= pack("H160", "00");                         #dummy space
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
  print STDERR "Warning: ID can't be '$c_id', has to be > 0\n";
  print STDERR "  ---->  This song *won't* be visible on the iPod\n";
  print STDERR "  ---->  This may confuse other scripts...\n";
  print STDERR "  ----> !! YOU SHOULD FIX THIS AND RERUN mktunes.pl !!\n";
 }

 my $ret = "mhit";
    $ret .= pack("h8", _itop(156));                           #header size
    $ret .= pack("h8", _itop(int($hr->{size})+156));          #len of this entry
    $ret .= pack("h8", _itop($hr->{count}));                  #num of mhods in this mhit
    $ret .= pack("h8", _itop($c_id));                         #Song index number
    $ret .= pack("h8", _itop(1));                             #debug flag? - the ipod stops parsing if this isnt == 1
    $ret .= pack("H8");                                       #dummyspace
    $ret .= pack("h8", _itop(256+(oct('0x14000000')
                            *($file_hash{rating}/20))));      #type+rating .. this is very STUPID..
    $ret .= pack("h8", _itop($file_hash{changetime}));        #Time changed
    $ret .= pack("h8", _itop($file_hash{filesize}));          #filesize
    $ret .= pack("h8", _itop($file_hash{time}));              #seconds of song
    $ret .= pack("h8", _itop($file_hash{songnum}));           #nr. on CD .. we dunno use it (in this version)
    $ret .= pack("h8", _itop($file_hash{songs}));             #songs on this CD
    $ret .= pack("h8", _itop($file_hash{year}));              #the year
    $ret .= pack("h8", _itop($file_hash{bitrate}));           #bitrate
    $ret .= pack("H4", "00");                                 #??
    $ret .= pack("h4", _itop( ($file_hash{srate} || 44100),0xffff));    #Srate (note: h4!)
    $ret .= pack("h8", _itop($vol));                          #Volume
    $ret .= pack("h8", _itop($file_hash{starttime}));         #Start time?
    $ret .= pack("h8", _itop($file_hash{stoptime}));          #Stop time?
    $ret .= pack("h8", _itop($file_hash{soundcheck}));        #Soundcheck from iTunesNorm
    $ret .= pack("h8", _itop($file_hash{playcount}));
    $ret .= pack("H8");                                       #Sometimes eq playcount .. ?!
    $ret .= pack("h8", _itop($file_hash{lastplay}));          #Last playtime..
    $ret .= pack("h8", _itop($file_hash{cdnum}));             #cd number
    $ret .= pack("h8", _itop($file_hash{cds}));               #number of cds
    $ret .= pack("H8");                                       #hardcoded space ?
    $ret .= pack("h8", _itop($file_hash{addtime}));           #File added @
    $ret .= pack("H16");
    $ret .= pack("H12");                                       #??
    $ret .= pack("h4", _itop($file_hash{bpm},0xffff));         #BPM
#Fixme: this was wrong.. so i removed it now..
#    $ret .= pack("h8", _itop(($file_hash{prerating}/20)*oct('0x140000')));      #This is also stupid: the iTunesDB has a rating history
    $ret .= pack("H8");                                       # ???
    $ret .= pack("H56");  
                         
return $ret;
}


## GENERAL ##########################################################
# An mhod simply holds information
sub mk_mhod {
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
 $ret .= pack("h8", _itop($type));                #type of the entry
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
 my($live, $chkrgx, $chklim, $mos, $sort_low) = 0;

 #Bool stuff
 $live        = 1 if $hs->{liveupdate};
 $mos         = 1 if $hs->{mos};
 #Tristate
my $checkrule   = $SPLREDEF{checkrule}{lc($hs->{checkrule})};
my $int_item    = $SPLREDEF{limititem}{lc($hs->{item})};

 #sort stuff

#Build SORT Flags
my $sort = $SPLREDEF{limitsort}{lc($hs->{sort})};
if($sort == 0) {
 warn "Unknown limitsort value ($hs->{sort}) , setting sort to 'random'\n";
 $sort = $SPLREDEF{limitsort}{random};
}
elsif($sort < 0) {
 $sort_low = 1; #Set LOW flag
 $sort *= -1;   #Get positive value
}


if($checkrule < 1 || $checkrule > 3) {
 warn "iTunesDB.pm: error: 'checkrule' ($hs->{checkrule}) invalid. Value set to 'limit')\n";
 $checkrule = $SPLREDEF{checkrule}{limit};
}

if($int_item < 1) {
 warn "iTunesDB.pm: error: 'item' ($hs->{item}) invalid. Value set to 'minute'\n";
 $int_item = $SPLREDEF{limititem}{minute};
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
 $ret .= pack("h2", _itop($int_item,0xff)); #Wich item?
 $ret .= pack("h2", _itop($sort,0xff)); #How to sort
 $ret .= pack("h6");
 $ret .= pack("h8", _itop($hs->{value})); #lval
 $ret .= pack("h2", _itop($mos,0xff));        #MatchOnlySelected (?)
 $ret .= pack("h2", _itop($sort_low, 0xff)); #Set LOW flag..
 $ret .= pack("h116");

}

## GENERAL #################################################################
# Create a spl-data (type=51) mhod
sub mk_spldatamhod {
 my($hs) = @_;

 my $anymatch = 1 if $hs->{anymatch};

 if(ref($hs->{data}) ne "ARRAY") {
  #This is an iTunes bug: it will go crazy if it finds an spldatamhod without data...
  #workaround: Create a fake-entry if we didn't catch one from the GNUtunesDB.xml
  # ..-> iTunes does the same :)
  push(@{$hs->{data}}, {field=>'ARTIST',action=>'CONTAINS',string=>""});
 }

 my $cr = undef;
 foreach my $chr (@{$hs->{data}}) {
     my $string = undef;
     my $int_field = undef;
     my $action_prefix = undef;
     my $action_num    = undef;
    
     if($int_field = $SPLREDEF{field}{uc($chr->{field})}) { #String type
        $string = Unicode::String::utf8($chr->{string})->utf16;
        #String has 0x1 as prefix
        $action_prefix = 0x01000000;
        my($is_negative,$real_action) = $chr->{action} =~ /^(NOT_)?(.+)/;
		
        #..but a negative string has 0x3 as prefix
        $action_prefix = 0x03000000 if $is_negative;
		
        unless($action_num = $SPLREDEF{string_action}{uc($real_action)}) {
         warn "iTunesDB.pm: action $chr->{action} is invalid for $chr->{field} , setting action to ".$is_negative."IS\n";
         $action_num = $SPLREDEF{string_action}{IS};
        }
     
     }
     elsif($int_field = $SPLREDEF{field}{lc($chr->{field})}) { #Int type
        #int has 0x0 as prefix..
        $action_prefix = 0x00000000;
        my($is_negative,$real_action) = $chr->{action} =~ /^(!)?(.+)/;
        
        #..but negative int action has 0x2
        $action_prefix = 0x02000000 if $is_negative;
		
        unless($action_num = $SPLREDEF{num_action}{lc($real_action)}) {
          warn "iTunesDB.pm: action $chr->{action} is invalid for $chr->{field}, setting action to ".$is_negative."eq\n";
          $action_num = $SPLREDEF{num_action}{eq};
        }
        
        my ($within_magic_a, $within_magic_b, $within_range, $within_key) = undef;
        my ($from, $to) = $chr->{string} =~ /(\d+):?(\d*)/;
        
        #within stuff is different.. aaaaaaaaaaaaahhhhhhhhhhhh
        if($action_num == $SPLREDEF{num_action}{within}) {
         $within_magic_a = 0x2dae2dae;        #Funny stuff at apple
         $from           = $within_magic_a;
         $to             = $within_magic_a;
         
         $within_magic_b = 0xffffffff;        #Isn't magic.. but we are not 64 bit..
         ($within_range, $within_key) = $chr->{string} =~ /(\d+)_(\S+)/;
         $within_key = $SPLREDEF{within_key}{lc($within_key)};
         $within_range-- if $within_range > 0; #0x..ff = 1.. 
        }
        else { #Fallback for normal stuff
         $to ||=$from; #Set $to == $from is $to is empty
        }
                
        $string  = pack("H8", _x86itop($within_magic_a));
        $string .= pack("H8", _x86itop($from));
        $string .= pack("H8", _x86itop($within_magic_b));
        $string .= pack("H8", _x86itop($within_magic_b-$within_range)); #0-0 for non within
        $string .= pack("H8");
        $string .= pack("H8", _x86itop($within_key||1));
        $string .= pack("H8", _x86itop($within_magic_a));
        $string .= pack("H8", _x86itop($to));
        $string .= pack("H24");
        $string .= pack("H8", _x86itop(1));
        $string .= pack("H40");
        #__hd($string);die;
	}
	else { #Unknown type, this is fatal!
	  die "iTunesDB.pm: FATAL ERROR: <spl field=\"$chr->{field}\"... is unknown, can't continue!\n";
	}

     if(length($string) > 0xfe) { #length field is limited to 0xfe!
        warn "iTunesDB.pm: splstring to long for iTunes, cropping (yes, that's stupid)\n";
        $string = substr($string,0,254);
     }
     
     $cr .= pack("H6");
     $cr .= pack("h2", _itop($int_field,0xff));
     $cr .= pack("H8",_x86itop($action_num+$action_prefix)); #Yepp.. everything here is x86! ouch
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
 $ret .= pack("h2", _itop(int(@{$hs->{data}}),0xff));     #HTM (Childs from cr) FIXME: is this really limited to 0xff childs?
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
   $ret .= pack("h8", _itop($hr->{playlists}));     #playlists on iPod (including main!)
   $ret .= pack("h160", "00");                      #dummy space
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
#int to ipod
sub _itop
{
my($in, $checkmax) = @_;
my($int) = $in =~ /(\d+)/;

$checkmax ||= 0xffffffff;

if($int > $checkmax or $int < 0) {
 _itBUG("_itop: FATAL: $int > $checkmax (<- maximal value)",1);
}

return scalar(reverse(sprintf("%08X", $int )));
}

## _INTERNAL ##################################################
#int to x86 ipodval (spl!!)
sub _x86itop
{
my($in, $checkmax) = @_;
my($int) = $in =~ /(\d+)/;

$checkmax ||= 0xffffffff;

if($int > $checkmax) {
 _itBUG("_x86itop: FATAL: $int > $checkmax (<- maximal value)",1);
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
my($start, $anz, $fh) = @_;

$fh ||= *FILE;

my $buffer = undef;
# paranoia checks
$start = int($start);
$anz = int($anz);
#seek to the given position
seek($fh, $start, 0);
#start reading
read($fh, $buffer, $anz);
 return GNUpod::FooBar::shx2int($buffer);
}


###########################################
# Get a x86INT value
sub get_x86_int {
my($start, $anz, $fh) = @_;
$fh ||= *FILE;
my($buffer, $xx, $xr) = undef;
# paranoia checks
$start = int($start);
$anz = int($anz);

#seek to the given position
seek($fh, $start, 0);
#start reading
read($fh, $buffer, $anz);
 return GNUpod::FooBar::shx2_x86_int($buffer);
}



####################################################
# Get all SPL items
sub read_spldata {
 my($hr) = @_;
 
my $diff = $hr->{start}+160;
my @ret = ();
 for(1..$hr->{htm}) {
  my $field = get_int($diff+3, 1);  #Field
  my $ftype = get_int($diff+4,1);   #Field TYPE
  my $action= get_x86_int($diff+5, 3);  #Field ACTION
  my $slen  = get_int($diff+55,1); #Whoa! This is true: string is limited to 0xfe (254) chars!! (iTunes4)
  my $rs    = undef; #ReturnSting
#__hd(get_string($diff+56,69));
#__hd(get_string($diff+56,96));


  my $human_exp = $SPLDEF{hprefix}{$ftype};
 
   if($SPLDEF{is_string}{$ftype}) { #Is a string type
	my $string= get_string($diff+56, $slen);
    #No byteswap here?? why???
    $rs = Unicode::String::utf16($string)->utf8;
    $human_exp .= $SPLDEF{string_action}{$action};
	#Warn about bugs 
	$SPLDEF{string_action}{$action} or _itBUG("Unknown s_action $action for $ftype (= GNUpod doesn't understand this SmartPlaylist)");
   }
   elsif($action == $SPLREDEF{num_action}{within} 
         && get_x86_int($diff+56+8,4) == 0xffffffff
         && get_x86_int($diff+56,4)   == 0x2dae2dae) {
     ## Within type is handled different... ask apple why...
     $rs = (0xffffffff-get_x86_int($diff+56+12,4)+1);
  
     $human_exp .= $SPLDEF{num_action}{$action}; #Set human exp
     my $within_key = $SPLDEF{within_key}{get_x86_int($diff+56+20,4)}; #Set within key
     if($within_key) {
      $rs = $rs."_".$within_key;
     }
     else {
      _itBUG("Can't handle within_SPL_FIELD - unknown within_key, using 1_day");
      $rs = "1_day";
     }
   }
   else { #Is INT (Or range)
    my $xfint = get_x86_int($diff+56+4,4);
    my $xtint = get_x86_int($diff+56+28,4);
    $rs = "$xfint:$xtint";
	$human_exp .= $SPLDEF{num_action}{$action};
	$SPLDEF{num_action}{$action} or  _itBUG("Unknown a_action $action for $ftype (= GNUpod doesn't understand this SmartPlaylist)");
   }
   
  $diff += $slen+56;
  
  my $human_field = $SPLDEF{field}{$field};
  $SPLDEF{field}{$field} or _itBUG("Unknown SPL-Field: $field (= GNUpod doesn't understand this SmartPlaylist)");
  
  push(@ret, {action=>$human_exp,field=>$human_field,string=>$rs});
 }
 return \@ret;
}


#################################################
# Read SPLpref data
sub read_splpref {
 my($hs) = @_;
 my ($live, $chkrgx, $chklim, $mos, $sort_low);
 
    $live     = 1 if   get_int($hs->{start}+24,1);
    $chkrgx   = 1 if   get_int($hs->{start}+25,1);
    $chklim   = 1 if   get_int($hs->{start}+26,1);
 my $item     =        get_int($hs->{start}+27,1);
 my $sort     =        get_int($hs->{start}+28,1);
 my $limit    =        get_int($hs->{start}+32,4);
    $mos      = 1 if   get_int($hs->{start}+36,1);
    $sort_low = 1 if   get_int($hs->{start}+37,1) == 0x1;

#We don't pollute everything with this sort_low flag, we do something nasty to the
#$sort value ;)
$sort *= -1 if $sort_low;

 if($SPLDEF{limitsort}{$sort}) {
  $sort = $SPLDEF{limitsort}{$sort};
 }
 else {
  _itBUG("Don't know how to handle SPLSORT '$sort', setting sort to RANDOM",);
  $sort = "random";
 }

$SPLDEF{limititem}{int($item)} or warn "Bug: limititem $item unknown\n";
$SPLDEF{checkrule}{int($chklim+($chkrgx*2))} or warn "Bug: Checkrule ".int($chklim+($chkrgx*2))." unknown\n";
 return({live=>$live,
         value=>$limit, iitem=>$SPLDEF{limititem}{int($item)}, isort=>$sort,mos=>$mos,checkrule=>$SPLDEF{checkrule}{int($chklim+($chkrgx*2))}});
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
#__hd(get_string($seek,$ml));
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
   _itBUG("Fatal seek error in get_mhip, can't continue!",1) if $mhs == -1;
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
my ($start, $anz, $fh) = @_;
$fh ||= *FILE;
my($buffer) = undef;
$start = int($start);
$anz = int($anz);
seek($fh, $start, 0);
#start reading
read($fh, $buffer, $anz);
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
   my $mhyp_len       = get_int($pos+8, 4);   #Size of mhyp
   my $mhods          = get_int($pos+12,4); #How many mhods we have here
#Its a MPL, do a fast skip  --> We don't parse the mpl, because we know the content anyway
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
    _itBUG("Failed to get $i mhod of $mhods (plpart)",1);
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
       _itBUG("Failed to parse Song $i of $scount songs",1);
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
$ret{id}         = get_int($sum+16,4);
$ret{changetime} = get_int($sum+32,4);
$ret{filesize}   = get_int($sum+36,4);
$ret{time}       = get_int($sum+40,4);
$ret{cdnum}      = get_int($sum+92,4);
$ret{cds}        = get_int($sum+96,4);
$ret{songnum}    = get_int($sum+44,4);
$ret{songs}      = get_int($sum+48,4);
$ret{year}       = get_int($sum+52,4);
$ret{bitrate}    = get_int($sum+56,4);
$ret{srate}      = get_int($sum+62,2); #What is 60-61 ?!!
$ret{volume}     = get_int($sum+64,4);
$ret{starttime}  = get_int($sum+68,4);
$ret{stoptime}   = get_int($sum+72,4);
$ret{soundcheck} = get_int($sum+76,4);
$ret{playcount}  = get_int($sum+80,4); #84 has also something to do with playcounts. (Like rating + prerating?)
$ret{lastplay}   = get_int($sum+88,4);
$ret{rating}     = int((get_int($sum+28,4)-256)/oct('0x14000000')) * 20;
$ret{addtime}    = get_int($sum+104,4);
$ret{bpm} = get_int($sum+122,2);

#Fixme: prerating is invalid.. rerere..
#$ret{prerating}  = int(get_int($sum+120,4) / oct('0x140000')) * 20;
#__hd(get_string($sum+120,4));


####### We have to convert the 'volume' to percent...
####### The iPod doesn't store the volume-value in percent..
#Minus value (-X%)
$ret{volume} -= oct("0xffffffff") if $ret{volume} > 255;

#Convert it to percent
$ret{volume} = sprintf("%.0f",($ret{volume}/2.55));

## Paranoia check
if(abs($ret{volume}) > 100) {
 _itBUG("Volume is $ret{volume} percent. Impossible Value! -> Volume set to 0 percent!");
 $ret{volume} = 0;
}


 #Now get the mhods from this mhit
my $mhods = get_int($sum+12,4);
$sum += get_int($sum+4,4);

 for(my $i=0;$i<$mhods;$i++) {
    my $mhh = get_mhod($sum);
    if($mhh->{size} == -1) {
     _itBUG("Failed to parse mhod $i of $mhods",1);
    }
    $sum+=$mhh->{size};
    my $xml_name = $mhod_array[$mhh->{type}];
    if($xml_name) { #Has an xml name.. sounds interesting
      $ret{$xml_name} = $mhh->{string};
    }
    else {
     _itBUG("found unhandled mhod type '$mhh->{type}' (content: $mhh->{string})");
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
#Get magic
my $magic      = get_string(0,4);
return undef if $magic ne ITUNESDB_MAGIC;

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
# Read PlayCounts 
sub readPLC {
 my($file) = @_;
 open(RATING, "$file") or return ();
 
 
 my $offset    = get_int(4 ,4,*RATING);
 my $chunksize = get_int(8, 4,*RATING);
 my $chunks    = get_int(12,4,*RATING);

 my $buff;
 my %pcrh = ();


 my $rating = 0;
 my $playc  = 0;
 my $lastply= 0;
 for(1..$chunks) {
  seek(RATING, $offset, 0);
  read(RATING,$buff,4) or warn "readPLC bug, seek failed! Please send a bugreport to pab\@blinkenlights.ch!\n";
  $playc  = GNUpod::FooBar::shx2int($buff);
 
  seek(RATING,$offset+4,0);
  read(RATING,$buff,4) or warn "readPLC bug, seek failed! Please send a bugreport to pab\@blinkenlights.ch!\n";
  $lastply = GNUpod::FooBar::shx2int($buff);
  
  if($chunksize >= 16) { #12+4 - v2 firmware? 
   seek(RATING, $offset+12, 0);
   read(RATING, $buff,4) or warn "readPLC bug, read failed! Please send a bugreport to pab\@blinkenlights.ch!\n";
   $rating = GNUpod::FooBar::shx2int($buff);
  }
  
  my $songnum = (($offset-(16*6))/16)+1;

#print "$songnum] ";
#print "*" x int($pcrh{rating}{songnum}/20);
#print " $pcrh{lastplay}{$songnum}\n";

  $pcrh{playcount}{$songnum} = $playc if $playc;
  $pcrh{rating}{$songnum}    = $rating if $rating; 
  $pcrh{lastplay}{$songnum}  = $lastply if $lastply;
  $offset += $chunksize;
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



#########################################################
# Default Bugreport view
sub _itBUG {
 my($info, $fatal) = @_;
 
 warn "\n"; #Make sure to get a newline
 warn "iTunesDB.pm: Ups, something bad happened, you found a bug in GNUpod!\n";
 warn "====================================================================\n";
 warn $info."\n";
 warn "====================================================================\n";
 warn "> Please write a Bugreport to <pab\@blinkenlights.ch>\n";
 warn "> - Please send me the complete Output of the program\n";
 warn "> - Please create a backup of the iTunesDB file, because i may ask you\n";
 warn ">   to send me this file. Thanks.\n";
 
 if($fatal) {
  warn " *** THIS ERROR IS FATAL, I CAN'T CONTINUE, SORRY!\n";
  exit(1);
 }
 else {
  warn " *** THIS ERROR IS NOT FATAL, BUT GNUPOD MAYBE GET CONFUSED %-)\n";
 }
 
 
}

##########################################
#ReConvert the SPLDEF hash
sub _r_spldef {
my %RES = ();
 foreach my $spldsc (keys(%SPLDEF)) {
   foreach my $xkey (keys(%{$SPLDEF{$spldsc}})) {
    my $xval = $SPLDEF{$spldsc}{$xkey};
    $RES{$spldsc}{$xval} = int($xkey);
   }
 }
 return %RES;
}



1;
