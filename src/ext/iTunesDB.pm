# iTunesDB.pm - Version 20050205
#  Copyright (C) 2002-2005 Adrian Ulrich <pab at blinkenlights.ch>
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

#
# FIXME: I should add some new fields from http://ipodlinux.org/ITunesDB
#

package GNUpod::iTunesDB;
use strict;
use Unicode::String;
use GNUpod::FooBar;
use File::Glob ':glob';

use vars qw(%mhod_id @mhod_array %SPLDEF %SPLREDEF);

use constant ITUNESDB_MAGIC => 'mhbd';
use constant MAGIC_PODCAST_GROUP          => 256;
use constant OLD_ITUNESDB_MHIT_HEADERSIZE => 156;
use constant NEW_ITUNESDB_MHIT_HEADERSIZE => 244;

#mk_mhod() will take care of lc() entries
my %mhod_id = ( title=>1, path=>2, album=>3, artist=>4, genre=>5, fdesc=>6, eq=>7, comment=>8, category=>9, composer=>12, group=>13,
                 desc=>14, podcastguid=>15, podcastrss=>16, chapterdata=>17, subtitle=>18, tvshow=>19, tvepisode=>20,
                 tvnetwork=>21, albumartist=>22, artistthe=>23, keywords=>24, sorttitle=>27, sortalbum=>28, sortalbumartist=>29,
                 sortcomposer=>30, sorttvshow=>31);

 foreach(keys(%mhod_id)) {
  $mhod_array[$mhod_id{$_}] = $_;
 }







############# SMART PLAYLIST DEFS ##########################

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
$SPLDEF{num_action}{0x01}    = "eq";
$SPLDEF{num_action}{0x10}    = "gt";
$SPLDEF{num_action}{0x20}    = "gtoreq"; #GreaterThanOrEQ
$SPLDEF{num_action}{0x40}    = "lt";
$SPLDEF{num_action}{0x80}    = "ltoreq"; #LessThanOrEQ
$SPLDEF{num_action}{0x0100}  = "range";
$SPLDEF{num_action}{0x0200}  = "within";
$SPLDEF{num_action}{0x0400}  = "bbbfixme";

#Within is completly different, thx to apple :p
$SPLDEF{within_key}{86400}   = "day";
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
$SPLDEF{field}{23} = "lastplay";
$SPLDEF{field}{24} = "cdnum";
$SPLDEF{field}{25} = "rating";
$SPLDEF{field}{31} = "compilation";
$SPLDEF{field}{35} = "bpm";
$SPLDEF{field}{39} = "GROUP";
$SPLDEF{field}{40} = "playlist";
$SPLDEF{field}{54} = "DESCRIPTION";
$SPLDEF{field}{55} = "CATEGORY";
$SPLDEF{field}{57} = "podcast";
$SPLDEF{field}{60} = "aaafixme"; #Unknown field! Looks like INT


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


#Sort stuff. _low fields are below zero here..
#In the iTunesDB, we don't (can't) have negative
#values.. but we use it so see, if we have to set
#the _low flag.... blabla
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




%SPLREDEF = _r_spldef();


## IPOD SHUFFLE ####################################################
# Create iPod shuffle header
sub mk_itunes_sd_header {
	my($ref) = @_;
	my $ret = undef;
	$ret .= tnp($ref->{files});
	$ret .= tnp(0x010800);
	$ret .= tnp(0x12); #Hardcoded header size
	$ret .= tnp().tnp().tnp();
	return $ret;
}

## IPOD SHUFFLE ####################################################
# Create an entry
sub mk_itunes_sd_file {
	my($ref) = @_;
	my $ret = undef;

	#The Shuffle needs / , not :
	$ref->{path} =~ tr/:/\//;
	my $uc = new Unicode::String($ref->{path});
	
	$ret .= tnp(0x00022E);	#Static?
	$ret .= tnp(0x5AA501);	#unk1
	$ret .= tnp();					#StartTime
	$ret .= tnp();					#unk2
	$ret .= tnp();					#unk3
	$ret .= tnp();					#StopTime
	$ret .= tnp();					#unk4
	$ret .= tnp();					#unk5
	$ret .= tnp(0x64-($ref->{volume}));			#Volume (64=+-0)
	
	## This is ugly!
	my $fixmetype = 1; #MP3
	if($ref->{path} =~ /\.m4.$/i) {
		$fixmetype = 2;
	}
	elsif($ref->{path} =~ /\.wav$/i) {
		$fixmetype = 4;
	}

	$ret .= tnp($fixmetype);	#Type: MP3=1 / AAC=2 / WAV=4
	$ret .= tnp(0x000200);	#Static?
	$ret .= Unicode::String::byteswap2($uc->utf16);
	$ret .= "\0" x (522-length($uc->utf16));
	my $bmflag = undef;
	$bmflag += 0x010000 if $ref->{shuffleskip}  == 0;
	$bmflag += 0x000100 if $ref->{bookmarkable} != 0; #Well.. this is somehow broken.. hmm FIXME
	$ret .= tnp($bmflag); #shuffle#bookmark#unknown#
	return $ret;
}

## IPOD SHUFFLE ####################################################
# ThreeNetworkPack -> ShuffleDB thingy
sub tnp {
	my($in) = @_;
	my $ret = pack("N", $in);
	return substr($ret,1);
}




## GENERAL #########################################################
# create an iTunesDB header
### XHR: size
sub mk_mhbd {
	my ($hr) = @_;

	my $ret = "mhbd";
	   $ret .= pack("V", 104);                        #Header Size
	   $ret .= pack("V", _icl($hr->{size}+104));      #Size of whole mhdb
	   $ret .= pack("V", 0x1);                        #?
	   $ret .= pack("V", 0xC);                        # Version, we are iTunes 4.7 -> 12
	   $ret .= pack("V", _icl($hr->{childs}));        # Childs, currently always 2
	   $ret .= pack("V", 0xE0ADECAD);                 # UID -> 0xA_Decade_0f_bad_f00d
	   $ret .= pack("V", 0x0DF0ADFB);
	   $ret .= pack("V", 0x2);                        #?
	   $ret .= pack("V17", "00");                     #dummy space
return $ret;
}

## GENERAL #########################################################
# a iTunesDB has 2 mhsd's: (This is a child of mk_mhbd)
# mhsd1 holds every song on the ipod
# mhsd2 holds playlists
#
### XHR: size type
sub mk_mhsd {
 my ($hr) = @_;
 my $ret = "mhsd";
    $ret .= pack("V", _icl(96));                      #Headersize, static
    $ret .= pack("V", _icl($hr->{size}+96));          #Size
    $ret .= pack("V", _icl($hr->{type}));             #type .. 1 = song .. 2 = playlist
    $ret .= pack("V20", "00");                         #dummy space
 return $ret;
}



## GENERAL ##########################################################
# Create an mhit entry, needs to know about the length of his
# mhod(s) (You have to create them yourself..!)
### XHR: fh 
sub mk_mhit {
 my($hr) = @_;
 my %file_hash = %{$hr->{fh}};

 #We have to fix 'volume'
 my $vol = sprintf("%.0f",( int($file_hash{volume})*2.55 ));

 if($vol >= 0 && $vol <= 255) { } #Nothing to do
 elsif($vol < 0 && $vol >= -255) {            #Convert value
  $vol = ((0xFFFFFFFF) + $vol); 
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
    $ret .= pack("V", _icl(0xF4));                          #header size
    $ret .= pack("V", _icl(int($hr->{size})+0xF4));         #len of this entry
    $ret .= pack("V", _icl($hr->{count}));                  #num of mhods in this mhit
    $ret .= pack("V", _icl($c_id));                         #Song index number
    $ret .= pack("V", _icl(1));                             #Visible?
    $ret .= pack("V");                                      #FileType. Should be 'MP3 '. (FIXME: Extension or type?)
    $ret .= pack("v", 0x100);                               #cbr = 100, vbr = 101, aac = 0x010 ##FIXME: COrrect?
    $ret .= pack("c", (($file_hash{compilation})==0));      #compilation ?
    $ret .= pack("c",$file_hash{rating});                   #rating
    $ret .= pack("V", _icl($file_hash{changetime}));        #Time changed
    $ret .= pack("V", _icl($file_hash{filesize}));          #filesize
    $ret .= pack("V", _icl($file_hash{time}));              #seconds of song
    $ret .= pack("V", _icl($file_hash{songnum}));           #nr. on CD .. we dunno use it (in this version)
    $ret .= pack("V", _icl($file_hash{songs}));             #songs on this CD
    $ret .= pack("V", _icl($file_hash{year}));              #the year
    $ret .= pack("V", _icl($file_hash{bitrate}));           #bitrate
    $ret .= pack("v", "00");                                #??
    $ret .= pack("v", _icl( ($file_hash{srate} || 44100),0xffff));    #Srate (note: v4!)
    $ret .= pack("V", _icl($vol));                          #Volume
    $ret .= pack("V", _icl($file_hash{starttime}));         #Start time?
    $ret .= pack("V", _icl($file_hash{stoptime}));          #Stop time?
    $ret .= pack("V", _icl($file_hash{soundcheck}));        #Soundcheck from iTunesNorm
    $ret .= pack("V", _icl($file_hash{playcount}));         #Playcount
    $ret .= pack("V", _icl($file_hash{playcount}));         #Sometimes eq playcount .. ?!
    $ret .= pack("V", _icl($file_hash{lastplay}));          #Last playtime..
    $ret .= pack("V", _icl($file_hash{cdnum}));             #cd number
    $ret .= pack("V", _icl($file_hash{cds}));               #number of cds
    $ret .= pack("V");                                      #hardcoded space ? (Apple DRM id?)
    $ret .= pack("V", _icl($file_hash{addtime}));           #File added @
    $ret .= pack("V", _icl($file_hash{bookmark}));          #QTFile Bookmark
    $ret .= pack("V", (_icl($file_hash{dbid_lsw}) || 0xDEADBABE) );            #DBID Prefix (Cannot be 0x0)
    $ret .= pack("V", (_icl($file_hash{dbid_msw}) || _icl($c_id) ));           #DBID Postfix (Cannot be 0x0)
    $ret .= pack("v");                                      #??
    $ret .= pack("v", _icl($file_hash{bpm},0xffff));        #BPM
    $ret .= pack("v", _icl($file_hash{artworkcnt}));        #Artwork Count
    $ret .= pack("v");                                      #ipodlinux-wiki => unk9
    $ret .= pack("V", _icl($file_hash{artworksize}));       #Artwork Size
		$ret .= pack("V8");
		$ret .= pack("C", _icl(($file_hash{artworkcnt} ?  1 : 2)));
		$ret .= pack("C", _icl(($file_hash{shuffleskip} ? 1 : 0)));
		$ret .= pack("C", _icl(($file_hash{bookmarkable} ? 1 : 0)));
		$ret .= pack("C", _icl(($file_hash{mhitpodcastinfo} ? 1 : 0)));
		
		$ret .= pack("V", (_icl($file_hash{dbid2_lsw}) || 0xDEADBABE) );            #DBID2 Prefix (Cannot be 0x0)
		$ret .= pack("V", (_icl($file_hash{dbid2_msw}) || _icl($c_id) ));           #DBID2 Postfix (Cannot be 0x0)
		$ret .= pack("C", (_icl(($file_hash{lyrics_flag} ? 1 : 0))));
		$ret .= pack("C", (_icl(($file_hash{movie_flag} ? 1 : 0))));
		$ret .= pack("C", (_icl(($file_hash{played_flag} ? 1 : 2))));
		$ret .= pack("C", 0);		
		$ret .= pack("H56");
		$ret .= pack("V", _icl($file_hash{mediatype}));
		$ret .= pack("V", _icl($file_hash{seasonnum}));
		$ret .= pack("V", _icl($file_hash{episodenum}));
		$ret .= pack("H47");  


return $ret;
}


## GENERAL ##########################################################
# An mhod simply holds information
### XHR: stype string fqid
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
	
	#Append
	my $apx = undef;

	#Called with fqid, this has to be an PLTHING (100)
	if(defined $fqid) { 
		#fqid set, that's a pl item!
		$type = 100;
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
	###
	
	#Create AppendX for Special types
	
	#Podcast
	if($type == 16 or $type == 15) {
		#Dummy: Podcast UTF8 stuff.
		#Dunno convert utf8-string into byteswap2-utf16
		$apx .= $string;
	}
	#Playlist
	elsif($type == 100) {
		#Playlist mhod
		$apx .= pack("V", _icl($fqid));  #Refers to this id
		$apx .= pack("V", 0x00);         #Mhod 0 has no string
		$apx .= pack("V3"); #Playlist append
	}
	#Normal
	else {
		#Normal mhods:
		warn "ASSERT: Bug? -> fqid defined for non-playlist id!\n" if $fqid != 1;
		$string = _ipod_string($string); #cache data
		$apx .= pack("V", _icl($fqid));                  #Refers to this id if a PL item, else -> 1
		$apx .= pack("V", _icl(length($string)));        #size of string
		$apx .= pack("V2");           #trash
		$apx .= $string;               #the string
	}

	my $ret = "mhod";                 		           #header
	$ret .= pack("V", _icl(24));                     #size of header
	$ret .= pack("V", _icl(24+length($apx)));   # size of header+body
	$ret .= pack("V", _icl($type));                #type of the entry
	$ret .= pack("V2");                               #dummy space
	###

	return $ret.$apx;
}


## GENERAL #################################################################
# Create a spl-pref (type=50) mhod
### XHR: liveupdate mos checkrule item
sub mk_splprefmhod {
 my($hs) = @_;
 my($live, $chkrgx, $chklim, $mos, $sort_low) = 0;

 #Bool stuff
 $live        = 1 if $hs->{liveupdate};
 $mos         = 1 if $hs->{mos};
 #Tristate
my $checkrule   = $SPLREDEF{checkrule}{lc($hs->{checkrule})};
 #INT
my $int_item    = $SPLREDEF{limititem}{lc($hs->{item})};

 #sort stuff
#Build SORT Flags
my $sort = $SPLREDEF{limitsort}{lc($hs->{sort})};
if($sort == 0) {
 warn "Unknown limitsort value ($hs->{sort})\n";
 return undef; #Skip this spl
}
elsif($sort < 0) { # <0 ---> Is a _low sort
 $sort_low = 1; #Set LOW flag
 $sort *= -1;   #Get positive value
}

#Check checkrule range
if($checkrule < 1 || $checkrule > 3) {
 warn "iTunesDB.pm: error: 'checkrule' ($hs->{checkrule}) invalid.\n";
 return undef; #Skip this spl
}

if($int_item < 1) {
 warn "iTunesDB.pm: error: 'item' ($hs->{item}) invalid.\n";
 return undef; #Skip this spl
}

#lim-only = 1 / match only = 2 / both = 3
$chkrgx = 1 if $checkrule>1;
$chklim = $checkrule-$chkrgx*2;

 my $ret = "mhod";
 $ret .= pack("V", _icl(24));    #Size of header
 $ret .= pack("V", _icl(96));
 $ret .= pack("V", _icl(50));
 $ret .= pack("V2");
 $ret .= pack("C", _icl($live,0xff)); #LiveUpdate ?
 $ret .= pack("C", _icl($chkrgx,0xff)); #Check regexps?
 $ret .= pack("C", _icl($chklim,0xff)); #Check limits?
 $ret .= pack("C", _icl($int_item,0xff)); #Wich item?
 $ret .= pack("C", _icl($sort,0xff)); #How to sort
 $ret .= pack("h6");
 $ret .= pack("V", _icl($hs->{value})); #lval
 $ret .= pack("C", _icl($mos,0xff));        #MatchOnlySelected (?)
 $ret .= pack("C", _icl($sort_low, 0xff)); #Set LOW flag..
 $ret .= pack("h116");

}

## GENERAL #################################################################
# Create a spl-data (type=51) mhod
sub mk_spldatamhod {
 my($hs) = @_;

 my $anymatch = 1 if $hs->{anymatch};

 if(ref($hs->{data}) ne "ARRAY") {
  #This is an iTunes/iPod bug/feature: it will go crazy if it finds an spldatamhod without data...
  #workaround: Create a fake-entry if we didn't catch one from the GNUtunesDB.xml
  # ..-> iTunes does the same :)
  push(@{$hs->{data}}, {field=>'ARTIST',action=>'CONTAINS',string=>""});
 }

 my $cr = undef;
 my $CHTM = 0; #Count HasToMatch...
 
 foreach my $chr (@{$hs->{data}}) {
     my $string        = undef;
     my $int_field     = undef;
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
         warn "iTunesDB.pm: action $chr->{action} is invalid for $chr->{field} , skipping rule\n";
         next;
        }
     
     }
     elsif($int_field = $SPLREDEF{field}{lc($chr->{field})}) { #Int type
        #int has 0x0 as prefix..
        $action_prefix = 0x00000000;
        my($is_negative,$real_action) = $chr->{action} =~ /^(!)?(.+)/;
        
        #..but negative int action has 0x2
        $action_prefix = 0x02000000 if $is_negative;
		
        unless($action_num = $SPLREDEF{num_action}{lc($real_action)}) {
          warn "iTunesDB.pm: action $chr->{action} is invalid for $chr->{field}, skipping rule\n";
          next;
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
         
          if($SPLREDEF{within_key}{lc($within_key)}) {
            $within_key = $SPLREDEF{within_key}{lc($within_key)}; #Known
          }
          else {
           warn "Invalid value for 'within' action: '$chr->{string}', skipping rule\n";
           next;
          }
         
          if($within_range > 0) {
           $within_range--; #0x..ff = 1;
          }
          else {
           warn "iTunesDB.pm: Value of within set to 0!\n";
           $within_range = 0;
          }
         
        }
        else { #Fallback for normal stuff
         $to ||=$from; #Set $to == $from is $to is empty
        }
                
        $string  = pack("N", _icl($within_magic_a));
        $string .= pack("N", _icl($from));
        $string .= pack("N", _icl($within_magic_b));
        $string .= pack("N", _icl($within_magic_b-$within_range)); #0-0 for non within
        $string .= pack("N");
        $string .= pack("N", _icl($within_key||1));
        $string .= pack("N", _icl($within_magic_a));
        $string .= pack("N", _icl($to));
        $string .= pack("N3");
        $string .= pack("N", _icl(1));
        $string .= pack("N5");
	}
	else { #Unknown type, this is fatal!
	  warn "iTunesDB.pm: ERROR: <spl field=\"$chr->{field}\"... is unknown, skipping SPL\n";
      next;
	}

     if(length($string) > 0xfe) { #length field is limited to 0xfe!
        warn "iTunesDB.pm: splstring to long for iTunes, cropping (yes, that's stupid)\n";
        $string = substr($string,0,254);
     }
     
     $cr .= pack("H6"); #Add data in for() loop... (= new chunk)
     $cr .= pack("C", _icl($int_field,0xff));
     $cr .= pack("N", _icl($action_num+$action_prefix)); #Yepp.. everything here is x86! ouch
     $cr .= pack("H94");
     $cr .= pack("C", _icl(length($string),0xff));
     $cr .= $string;
     $CHTM++; #Ok, we got a complete SPL
 }

 return undef unless $CHTM; #Ouch, EVERYTHING failed. Refuse to create an empty SPL

 my $ret = "mhod";
 $ret .= pack("V", _icl(24));    #Size of header
 $ret .= pack("V", _icl(length($cr)+160));    #header+body size
 $ret .= pack("V", _icl(51));    #type
 $ret .= pack("H16");
 $ret .= "SLst";                   #Magic
 $ret .= pack("H8", reverse("00010001")); #?
 $ret .= pack("h6");
 $ret .= pack("C", _icl($CHTM,0xff));     #HTM (Childs from cr) FIXME: is this really limited to 0xff childs?
 $ret .= pack("h6");
 $ret .= pack("C", _icl($anymatch,0xff));     #anymatch rule on or off
 $ret .= pack("h240");
 $ret .= $cr; #add data
return $ret;
}





## FILES #########################################################
# header for all files (like you use mk_mhlp for playlists)
sub mk_mhlt
{
my ($hr) = @_;

my $ret = "mhlt";
   $ret .= pack("V", _icl(92)); 		    #Header size (static)
   $ret .= pack("V", _icl($hr->{songs})); #songs in this itunesdb
   $ret .= pack("V20", "00");                      #dummy space
return $ret;
}









## PLAYLIST #######################################################
# header for ALL playlists
sub mk_mhlp
{

my ($hr) = @_;

my $ret = "mhlp";
   $ret .= pack("V", _icl(92));                   #Static header size
   $ret .= pack("V", _icl($hr->{playlists}));     #playlists on iPod (including main!)
   $ret .= pack("V20", "00");                      #dummy space
return $ret;
}


## PLAYLIST ######################################################
# Creates an header for a new playlist (child of mk_mhlp)
sub mk_mhyp
{
my($hr) = @_;

#We need to create a listview-layout and an mhod with the name..

my $append = mk_mhod({stype=>"title", string=>$hr->{name}});
my $cmh = 1+$hr->{mhods};
unless($hr->{no_dummy_listview}) {
	$append .= __dummy_listview();
	$cmh++; # Add a new ChildMhod
}



my $ret .= "mhyp";
   $ret .= pack("V", _icl(108)); #type
   $ret .= pack("V", _icl($hr->{size}+108+(length($append))));          #size
   $ret .= pack("V", _icl($cmh));			      #mhits
   $ret .= pack("V", _icl($hr->{files}));   #songs in pl
   $ret .= pack("V", _icl($hr->{type}));    # 1 = main .. 0=not main
   $ret .= pack("V", "00");                 #Timestamp FIXME
   $ret .= pack("V", _icl($hr->{plid}));    #Playlist ID
   $ret .= pack("V", "00");                 #fixme: plid2
   $ret .= pack("V", "00");
   $ret .= pack("CC", _icl($hr->{stringmhods},0xff));
   $ret .= pack("CC", _icl($hr->{podcast}    ,0xff));
   $ret .= pack("H128", "00");              #dummy space

 return $ret.$append;
}


## PLAYLIST ##################################################
# header for new Playlist item (child if mk_mhyp)
sub mk_mhip
 {
my ($hr) = @_;
#sid = SongId
#plid = playlist order ID
my $ret = "mhip";
   $ret .= pack("V", _icl(76));
   $ret .= pack("V", _icl(76+$hr->{size}));
   $ret .= pack("V", _icl($hr->{childs})); #Mhod childs !
   $ret .= pack("V", _icl($hr->{podcast_group}));
   $ret .= pack("V", _icl($hr->{plid}));   #ORDER id
   $ret .= pack("V", _icl($hr->{sid}));    #song id in playlist
   $ret .= pack("V", _icl($hr->{timestamp}));
   $ret .= pack("V", _icl($hr->{podcast_group_ref}));
   $ret .= pack("H80", "00");
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
# IntCheckLimit
sub _icl {
	my($in, $checkmax) = @_;
	my($int) = $in =~ /(\d+)/;
	$checkmax ||= 0xffffffff;
	
	if($int > $checkmax or $int < 0) {
		_itBUG("_icl: Value '$int' is out of range! (Maximum: $checkmax)\n => Forcing value to $checkmax\
 => Check if your GNUtunesDB.xml contains the string \"$int\" and fix it ;-)\
 => The written iTunesDB may be unuseable!");
		$int = $checkmax; #Force it!
	}
	return $int;
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
  my $field = get_int($diff+3, 1);       #Field
  my $ftype = get_int($diff+4,1);        #Field TYPE
  my $action= get_x86_int($diff+5, 3);   #Field ACTION
  my $slen  = get_int($diff+55,1);       #Whoa! This is true: string is limited to 0xfe (254) chars!! (iTunes4)
  my $rs    = undef;                     #ReturnSting


  my $human_exp = $SPLDEF{hprefix}{$ftype}; #Set NOT for $ftype
 
   if($SPLDEF{is_string}{$ftype}) { #Is a string type
	my $string= get_string($diff+56, $slen);
    #No byteswap here?? why???
    $rs = Unicode::String::utf16($string)->utf8;
    #Translate $action to a human field
    $human_exp .= $SPLDEF{string_action}{$action}; 
	#Warn about bugs 
	$SPLDEF{string_action}{$action} or _itBUG("Unknown s_action $action for $ftype (= GNUpod doesn't understand this SmartPlaylist)");
   }
   elsif($action == $SPLREDEF{num_action}{within} 
         && get_x86_int($diff+56+8,4) == 0xffffffff
         && get_x86_int($diff+56,4)   == 0x2dae2dae) {
     ## Within type is handled different... ask apple why...
     
     #Get the value (Bug: we are 32 bit.. this looks 64 bit)
     $rs = (0xffffffff-get_x86_int($diff+56+12,4)+1);
  
     $human_exp .= $SPLDEF{num_action}{$action}; #Set human exp
     my $within_key = $SPLDEF{within_key}{get_x86_int($diff+56+20,4)}; #Set within key
     if($within_key) {
      $rs = $rs."_".$within_key;
     }
     else {
      _itBUG("Can't handle within_SPL_FIELD - unknown within_key, using 1_day");
      $rs = "1_day"; #Default fallback
     }
   }
   else { #Is INT (Or range)
		my $xfint = get_x86_int($diff+56+4,4);
		my $xtint = get_x86_int($diff+56+28,4);
		$rs = "$xfint:$xtint";
		$human_exp .= $SPLDEF{num_action}{$action};
		$SPLDEF{num_action}{$action} or  _itBUG("Unknown num_action $action for $ftype (= GNUpod doesn't understand this SmartPlaylist)");
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
  $sort = $SPLDEF{limitsort}{$sort}; #Convert it to a human word
 }
 else { #Hups, unknown field, random is our fallback
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

	my $id    = get_string($seek, 4);          #are we lost?
	my $mhl   = get_int($seek+4, 4);           #Mhod Header Length
	my $ml    = get_int($seek+8, 4);           #Length of this mhod
	my $mty   = get_int($seek+12, 4);          #type number
	my $plpos = get_int($seek+24, 4);          #Used for 100 MHODs => Position
	my $xl    = get_int($seek+28,4);           #String length
	
	## That's spl stuff, only to be used with 51 mhod's
	my $htm = get_int($seek+35,1); #Only set for 51
	my $anym= get_int($seek+39,1); #Only set for 51
	my $spldata = undef; #dummy
	my $splpref = undef; #dummy

	my $foo = undef; #Mhod value
	if($id eq "mhod") { #Seek was okay
		if($mty == 16 or $mty == 15) {
			#Here we go again: Apple did strange things!
			#They could have used a normal mhod, but no!
			#Apple is cool and needs to f*ckup mhod-type 16 and 15!
			#aargs!
			$foo = get_string($seek+$mhl,$ml-$mhl);
			$foo = Unicode::String::utf8($foo)->utf8; #Paranoia
		}
		##Special handling for SPLs
		elsif($mty == 51) { #Get data from spldata mhod
			$foo = undef;
			$spldata = read_spldata({start=>$seek, htm=>$htm});
		}
		elsif($mty == 50) { #Get prefs from splpref mhod
			$foo = undef;
			$splpref = read_splpref({start=>$seek, end=>$ml});
		}
		elsif($mty == 100) { #This is a PLTHING mhod
			#No more information and the stringlength is garbage...
			$foo = undef;
		}
		elsif($mty == 32) { $foo = undef; } # iTunes bug?
		else { #A normal Mhod, puh!
			_itBUG("Assert \$xl < \$ml failed! ($xl => $ml) [type: $mty]",1) if $xl >= $ml;
			$foo = get_string($seek+($ml-$xl), $xl); #String of entry
			$foo = Unicode::String::byteswap2($foo);
			$foo = Unicode::String::utf16($foo)->utf8;			
		}
		return({size=>$ml,string=>$foo,type=>$mty,spldata=>$spldata,splpref=>$splpref,matchrule=>$anym,plpos=>$plpos});
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
		my $oof               = get_int($pos+4, 4);
		my $mhods             = get_int($pos+12,4);
		my $podcast_group     = get_int($pos+16,4);
		my $plid              = get_int($pos+20,4);
		my $sid               = get_int($pos+24,4);
		my $timestamp         = get_int($pos+28,4);
		my $podcast_group_ref = get_int($pos+32,4);
		my $subnaming         = undef;
		
		for(my $i=0;$i<$mhods;$i++) {
			my $mhr = get_mhod($pos+$oof);
			my $mhsize = $mhr->{size};
			
			if($podcast_group == MAGIC_PODCAST_GROUP && $mhod_array[$mhr->{type}] eq "title") {
				$subnaming = $mhr->{string};
			}
			_itBUG("Fatal seek error in get_mhip, can't continue! (debug: $mhsize / $i / $pos / $oof)",1) if $mhsize == -1;
			$oid+=$mhsize;
		}
		
		return({size=>($oid+$oof),sid=>$sid,plid=>$plid, podcast_group=>$podcast_group,
		        timestamp=>$timestamp, podcast_group_ref=>$podcast_group_ref, subnaming=>$subnaming});
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
# $opts->{nomplskip} == 1 => Skip FastSkip of MPL. Workaround for broken files written by Anapod..
sub get_pl {
	my($pos,$opts) = @_;
	my %ret_hash = ();
	my @pldata = ();
	
	
	if(get_string($pos, 4) eq "mhyp") { #Ok, its an mhyp
		my $header_len     = get_int($pos+4, 4);  #Size of the header
		my $mhyp_len       = get_int($pos+8, 4);  #Size of mhyp
		my $mhits          = get_int($pos+12,4);  #How many mhits we have here
		my $scount         = get_int($pos+16, 4); #How many songs should we expect?
		$ret_hash{type}    = get_int($pos+20, 4); #Is it a main playlist?
		$ret_hash{plid}    = get_int($pos+28,4);  #UID if the playlist..
		$ret_hash{podcast} = get_int($pos+42,2);  #Is-Podcast-Playlist flag
		
		
		#Its a MPL, do a fast skip  --> We don't parse the mpl, because we know the content anyway
		if($ret_hash{type} && ($opts->{nomplskip} != 1) ) {
			return ($pos+$mhyp_len, {type=>1}) 
		}
		$pos += $header_len; #set pos to start of first mhod
		#We can now read the name of the Playlist
		#Ehpod is buggy and writes the playlist name 2 times.. well catch both of them
		#MusicMatch is also stupid and doesn't create a playlist mhod
		#for the mainPlaylist
		my ($oid, $plname, $itt) = undef;
		for(my $i=0;$i<$mhits;$i++) {
			my $mhh = get_mhod($pos);
			if($mhh->{size} == -1) {
				_itBUG("Failed to get $i mhod of $mhits (plpart) ; Bad mhod found at offset $pos",1);
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
			push(@pldata, $mhih);
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

my $header_size = get_int($sum+4,4);

if($header_size < OLD_ITUNESDB_MHIT_HEADERSIZE) { # => Last get_int.. this is ugly
 _itBUG("Assert $header_size >= OLD_ITUNESDB_MHIT_HEADERSIZE failed. get_mhits($sum) will read BEHIND the end of this header!");
}

my %ret     = ();
#Infos stored in mhit
$ret{id}         = get_int($sum+16,4);
#$ret{rating}     = int((get_int($sum+28,4)-256)/oct('0x14000000')) * 20;
##XXX 26-30 are useless for us..
$ret{compilation}= (get_int($sum+30,1)==0);
$ret{rating}     = get_int($sum+31,1);
$ret{changetime} = get_int($sum+32,4);
$ret{filesize}   = get_int($sum+36,4);
$ret{time}       = get_int($sum+40,4);
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
$ret{cdnum}      = get_int($sum+92,4);
$ret{cds}        = get_int($sum+96,4);
$ret{addtime}    = get_int($sum+104,4);
$ret{bookmark}   = get_int($sum+108,4);
$ret{dbid_lsw}   = get_int($sum+112,4); #Database ID#1
$ret{dbid_msw}   = get_int($sum+116,4); #Database ID#2

## New iTunesDB data, appeared ~ iTunes 4.5
if($header_size >= NEW_ITUNESDB_MHIT_HEADERSIZE) {
	$ret{bpm}          = get_int($sum+122,2);
	$ret{artworkcnt}   = get_int($sum+124,2);
	$ret{artworksize}  = get_int($sum+128,4);
	$ret{dbid2_lsw}    = get_int($sum+168,4);
	$ret{dbid2_msw}    = get_int($sum+172,4);
	$ret{lyrics_flag}  = get_int($sum+176,1);
	$ret{movie_flag}   = get_int($sum+177,1);
	$ret{played_flag}  = ( get_int($sum+178,1) == 1 ? 1 : 0 );
	# 179 is unknown
	$ret{mediatype} = get_int($sum+208,4);
	$ret{seasonnum}  = get_int($sum+212,4);
	$ret{episodenum} = get_int($sum+216,4);
	
	
	##This parses the ShuffleSkipt and Bookmarkable flag
	$ret{shuffleskip} = $ret{bookmarkable} = 0;
	my $has_bookmark_flag = get_int($sum+164,1);
	if($has_bookmark_flag == 2) { #Ok, we know what to expect
		$ret{shuffleskip}    = 1 if get_int($sum+165,1);
		$ret{bookmarkable}   =1 if get_int($sum+166,1);
		$ret{mhitpodcastinfo}=1 if get_int($sum+167,1);
	}
	elsif($has_bookmark_flag != 0x00) {
	## Fixme: write code to parse this
	#	_itBUG("Whoops! Funny data found, please report this stuff:",undef);
	#	print "===>DEBUG OUTPUT FOR UNKNOWN BMFLAG STUFF: ".unpack("H*",pack("V",get_int($sum+164,4)))."\n";
	#	print "===>Don't know how to parse this stuff, ignoring it...\n";
	}
}

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
#  print "GET mhod $sum\n";
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
# Search all mhbd's and return information about them
sub get_starts {
#Get magic
my $magic      = get_string(0,4);
return undef if $magic ne ITUNESDB_MAGIC;

my $mhbd_s     = get_int(4,4);  #Size of the Header
my $total_len  = get_int(8,4);  #Total Length (of whole iTunesDB)
my $dbversion  = get_int(16,4); #Database Version
my $childs     = get_int(20,4); #How many childs do we have?


my $cpos = $mhbd_s;
my @childs = ();
foreach my $current_child (1..$childs) {
	my $c_mhsd_hlen = get_int($cpos+4,4);
	my $c_mhsd_size = get_int($cpos+8,4);
	my $mhsd_type   = get_int($cpos+12,4);
	
	my $sub_hlen = get_int($cpos+$c_mhsd_hlen+4,4);
	my $sub_cnt  = get_int($cpos+$c_mhsd_hlen+8,4);
	
	my $xstart = $cpos+$sub_hlen+$c_mhsd_hlen;
	$childs[$mhsd_type]->{start} = $xstart;
	$childs[$mhsd_type]->{type}  = $mhsd_type;
	$childs[$mhsd_type]->{childs}= $sub_cnt;
	$cpos += ($c_mhsd_size);
}

return(@childs);

}



######################## Other funny stuff #########################


##############################################
# Read PlayCounts 
sub readPLC {
 my($file) = @_;
 open(RATING, "$file") or return ();
 
 
 my $offset    = get_int(4 ,4,*RATING); #How long is the header?
 my $chunksize = get_int(8, 4,*RATING); #How long is one entry? (20 for iTunes 0xD / 16 for V2 Firmware, 12 for v1)
 my $chunks    = get_int(12,4,*RATING); #How many chunks do we have?
 
 my $buff;
 my %pcrh = ();
 my $rating   = 0;
 my $playc    = 0;
 my $bookmark = 0;
 my $lastply  = 0;
 my $chunknum = 0;
 my $itx = 0; #Unknown


 
 for my $chunknum (1..$chunks) {
  
  seek(RATING, $offset, 0);
  if (read(RATING,$buff,4) != 4) { _itBUG("Read failed at $offset while reading PLAYCOUNT ($chunks/$chunksize)"); last; }
  $playc  = GNUpod::FooBar::shx2int($buff);
 
  seek(RATING,$offset+4,0);
  if (read(RATING,$buff,4) != 4) { _itBUG("Read failed at $offset while reading LASTPLAY ($chunks/$chunksize)"); last; }
  $lastply = GNUpod::FooBar::shx2int($buff);
  
  if($chunksize >= 12) {
   seek(RATING, $offset+8,0);
   if(read(RATING, $buff,4) != 4) { _itBUG("Read failed at $offset while reading BOOKMARK ($chunks/$chunksize)"); last;}
   $bookmark = GNUpod::FooBar::shx2int($buff);
  }
  
  if($chunksize >= 16) { #12+4 - v2 firmware? 
   seek(RATING, $offset+12, 0);
   if (read(RATING, $buff,4) != 4) { _itBUG("Read failed at $offset while reading RATING ($chunks/$chunksize)"); last; }
   $rating = GNUpod::FooBar::shx2int($buff);
  }
  
	if($chunksize >= 20) {
		seek(RATING, $offset+16,0);
		if (read(RATING,$buff,4) != 4) { _itBUG("Read failed at $offset while reading ITX ($chunks/$chunksize)"); last; }
		$itx = GNUpod::FooBar::shx2int($buff);
	}
	
	

  $pcrh{playcount}{$chunknum} = $playc    if $playc;
  $pcrh{rating}{$chunknum}    = $rating   if $rating;
  $pcrh{lastplay}{$chunknum}  = $lastply  if $lastply;
  $pcrh{bookmark}{$chunknum}  = $bookmark if $bookmark;
  $offset += $chunksize; #Nex to go!
 }
close(RATING);
 return \%pcrh;
}

##############################################
# Read OnTheGo data
sub readOTG {
	my($glob) = @_;
 
	my $buff = undef;
	my @content = ();

	foreach my $file (bsd_glob($glob,GLOB_NOSORT)) {
		my @otgdb = ();
		open(OTG, "$file") or next;
		seek(OTG, 12, 0);
		read(OTG, $buff, 4);
  
		my $items = GNUpod::FooBar::shx2int($buff); 
		my $offset = 20;
		for(1..$items) {
			seek(OTG, $offset, 0);
			my $rb = read(OTG, $buff, 4);
			if($rb == 0) {
				_itBUG("readOTG($glob) i:$items / f:$file / s:$offset / fs: ".(-s $file));
				last;
			}
			push(@otgdb, GNUpod::FooBar::shx2int($buff));
			$offset+=4;
		}
		push(@content,\@otgdb);
	}
	return @content;
}

########################################################
# Read timezone from Preferences file
sub getTimezone {
	my($prefs) = @_;
	my $buff = 0x00;
	open(PREFS, $prefs) or return undef;
	seek(PREFS, (0xb10),0);
	read(PREFS, $buff, 1);
	close(PREFS);
	
	my $tzx = (GNUpod::FooBar::shx2int($buff));
	my $time_offset = ($tzx - 0x19)*30*60; #Seconds
	return int($time_offset);
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
