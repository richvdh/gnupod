###__PERLBIN__###
#  Copyright (C) 2002-2004 Adrian Ulrich <pab at blinkenlights.ch>
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

use strict;
use GNUpod::XMLhelper;
use GNUpod::iTunesDB;
use GNUpod::FooBar;
use Getopt::Long;


use vars qw($cid %pldb %spldb %itb %opts %meat %cmeat @MPLcontent);
#cid = CurrentID
#pldb{name}  = array with id's
#spldb{name} = '<spl' prefs
#itb         = buffer
#MPLcontent  = MasterPlaylist content (all songs)
#              Note: if you don't add ALL songs to MPLcontent,
#                    you'd break OTG and Rating AND the iPod
#                    wouldn't boot if it finds a hidden-id in the
#                    OTGPlaylist!!

$| = 1;

use constant MPL_UID => 1234567890;
print "mktunes.pl ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "version", "help|h", "ipod-name|n=s", "mount|m=s", "volume|v=i", "energy|e");
GNUpod::FooBar::GetConfig(\%opts, {'ipod-name'=>'s', mount=>'s', volume=>'i', energy=>'b'}, "mktunes");

$opts{'ipod-name'} ||= "###__VERSION__###";


usage() if $opts{help};
version() if $opts{version};

startup();




sub startup {

my $con = GNUpod::FooBar::connect(\%opts);

usage("$con->{status}\n") if $con->{status};

print "! Volume-adjust set to $opts{volume} percent\n" if defined($opts{volume});

print "> Parsing XML and creating FileDB\n";
GNUpod::XMLhelper::doxml($con->{xml}) or usage("Could not read $con->{xml}, did you run gnupod_INIT.pl ?");


# Create header for mhits
 $itb{mhlt}{_data_}   = GNUpod::iTunesDB::mk_mhlt({songs=>$itb{INFO}{FILES}});
 $itb{mhlt}{_len_}    = length($itb{mhlt}{_data_});

# Create header for the mhit header
 $itb{mhsd_1}{_data_} = GNUpod::iTunesDB::mk_mhsd({size=>$itb{mhit}{_len_}+$itb{mhlt}{_len_}, type=>1});
 $itb{mhsd_1}{_len_} = length($itb{mhsd_1}{_data_});



## PLAYLIST STUFF
print "> Creating playlists:\n";

 $itb{playlist}{_data_} = genpls();
 $itb{playlist}{_len_}  = length($itb{playlist}{_data_});
# Create headers for the playlist part..
 $itb{mhsd_2}{_data_} = GNUpod::iTunesDB::mk_mhsd({size=>$itb{playlist}{_len_}, type=>2});
 $itb{mhsd_2}{_len_}  = length($itb{mhsd_2}{_data_});


#Calculate filesize from buffered calculations...
#This is *very* ugly.. but it's fast :-)
my $fl = 0;
foreach my $xk (keys(%itb)) {
 foreach my $xx (keys(%{$itb{$xk}})) {
  next if $xx ne "_len_";
  $fl += $itb{$xk}{_len_};
 }
}


## FINISH IT :-)
print "> Writing iTunesDB...\n";
open(ITB, ">$con->{itunesdb}") or die "** Sorry: Could not write your iTunesDB: $!\n";
 binmode(ITB); #Maybe this helps win32? ;)
 print ITB GNUpod::iTunesDB::mk_mhbd({size=>$fl});  #Main header
 print ITB $itb{mhsd_1}{_data_};            #Header for FILE part
 print ITB $itb{mhlt}{_data_};              #mhlt stuff
 print ITB $itb{mhit}{_data_};              #..now the mhit stuff

 print ITB $itb{mhsd_2}{_data_};            #Header for PLAYLIST part
 print ITB $itb{playlist}{_data_};          #Playlist content
close(ITB);
## Finished!

print "> Updating Sync-Status\n";
GNUpod::FooBar::setsync_itunesdb($con);
GNUpod::FooBar::setvalid_otgdata($con);

print "You can now umount your iPod. [Files: $itb{INFO}{FILES}]\n";
print " - May the iPod be with you!\n\n";
}



#########################################################################
# Create a single playlist
sub r_mpl {
 my($name, $type, $xidref, $spl, $plid) = @_;

my $pl = undef;
my $fc = 0;
my $mhp = 0;

if(ref($spl) eq "HASH") { #We got splpref!
 $pl .= GNUpod::iTunesDB::mk_splprefmhod({item=>$spl->{limititem},sort=>$spl->{limitsort},mos=>$spl->{moselected}
                                          ,liveupdate=>$spl->{liveupdate},value=>$spl->{limitval},
                                          checkrule=>$spl->{checkrule}}) || return undef;
                                           
 $pl .= GNUpod::iTunesDB::mk_spldatamhod({anymatch=>$spl->{matchany},data=>$spldb{$name}}) || return undef;
 $mhp=2; #Add a mhod
}

 
 foreach(@{$xidref}) {
  $cid++; #Whoo! We ReUse the global CID.. first plitem = last file item+1 (or maybe 2 ;) )
  my $cmhip = GNUpod::iTunesDB::mk_mhip({childs=>1,plid=>$cid, sid=>$_});
  my $cmhod = GNUpod::iTunesDB::mk_mhod({fqid=>$_});
  next unless (defined($cmhip) && defined($cmhod)); #mk_mhod needs to be ok
  $fc++;
  $pl .= $cmhip.$cmhod;
 }
 my $plSize = length($pl);
print ">> $name\n";
  #mhyp appends a listview to itself
  return(GNUpod::iTunesDB::mk_mhyp({size=>$plSize,name=>$name,type=>$type,files=>$fc,
                                    mhods=>$mhp, plid=>$plid}).$pl,$fc);
}


#########################################################################
# Generate playlists from %pldb (+MPL)
sub genpls {

 #Create mainPlaylist and set PlayListCount to 1
 my ($pldata,undef) = r_mpl(Unicode::String::utf8($opts{'ipod-name'})->utf8, 1,\@MPLcontent, undef,MPL_UID);
 my $plc = 1;
 
#CID is now used by r_mpl, dont use it yourself anymore
  foreach my $plref (GNUpod::XMLhelper::getpl_attribs()) {
    my $splh = GNUpod::XMLhelper::get_splpref($plref->{name}); #Get SPL Prefs
    
    my($pl, $xc) = r_mpl($plref->{name}, 0, $pldb{$plref->{name}}, $splh, $plref->{plid}); #Kick Playlist creator
    
       if($pl) { #r_mpl got data, we can create a playlist..
        $plc++;         #INC Playlist count
        $pldata .= $pl; #Append data
        #GUI Stuff
        my $plxt = "Smart-" if $splh;
        print ">> Created $plxt"."Playlist '$plref->{name}' with $xc file"; print "s" if $xc !=1;
        print "\n";
       }
       else {
        warn "!! SKIPPED Playlist '$plref->{name}', something went wrong...\n";
       }     
  }
 
 return GNUpod::iTunesDB::mk_mhlp({playlists=>$plc}).$pldata;
}


#########################################################################
# Create the file index (like <files>)
sub build_mhit {
 my($oid, $xh) = @_;
 my %chr = %{$xh};
 $chr{id} = $oid;
my ($nhod,$cmhod,$cmhod_count) = undef;

 foreach(keys(%chr)) {
  next unless $chr{$_}; #Dont create empty fields

  #Crop title if enabled
  $chr{$_} = Unicode::String::utf8($chr{$_})->substr(0,18)->utf8 if $_ eq "title" && $opts{energy};
  $nhod = GNUpod::iTunesDB::mk_mhod({stype=>$_, string=>$chr{$_}});
  next unless $nhod; #mk_mhod refused work, go to next item
  $cmhod .= $nhod;
  $cmhod_count++;
 }
 
  push(@MPLcontent,$oid);
 
     #Volume adjust
     if($opts{volume}) {
      $chr{volume} += int($opts{volume});
      if(abs($chr{volume}) > 100) {
        print "** Warning: volume=\"$chr{volume}\" out of range: Volume set to ";
        $chr{volume} = ($chr{volume}/abs($chr{volume})*100);
        print "$chr{volume}% for id $chr{id}\n";
      }
     }
     
     
     #Ok, we created the mhod's for this item, now we have to create an mhit
     my $mhit = GNUpod::iTunesDB::mk_mhit({size=>length($cmhod), count=>$cmhod_count, fh=>\%chr}).$cmhod;
     $itb{mhit}{_data_} .= $mhit;
     my $length = length($mhit);
     $itb{INFO}{FILES}++; #Count all files (Needed for iTunesDB header (first part)

return $length;
}



#########################################################################
# EventHandler for <file items
sub newfile {
 my($el) = @_;
 $cid++;
##Create the gnuPod 0.2x like memeater
 #$meat{KEY}{VAL} = id." ";
 foreach(keys(%{$el->{file}})) {
  $meat{$_}{$el->{file}->{$_}} .= $cid." ";
  $cmeat{$_}{lc($el->{file}->{$_})} .= $cid." ";
 }
 
 
 $itb{mhit}{_len_} += build_mhit($cid, $el->{file}); 
}


#########################################################################
# EventHandler for <playlist childs
sub newpl   {
 my($el, $name, $pltype) = @_;
 
 if($pltype eq "pl") {
  xmk_newpl($el, $name);
 }
 elsif($pltype eq "spl") {
  xmk_newspl($el, $name);
 }
 else {
  warn "mktunes.pl: unknown pltype '$pltype'\n";
 }
}

########################################################################
# Smartplaylist handler
sub xmk_newspl {
 my($el, $name) = @_;
 my $mpref = GNUpod::XMLhelper::get_splpref($name)->{matchany};

#Is spl data, add it
 if(my $xr = $el->{spl}) {
  push(@{$spldb{$name}}, $xr);
 }

 unless(GNUpod::XMLhelper::get_splpref($name)->{liveupdate}) {
  warn "mktunes.pl: warning: (pl: $name) Liveupdate disabled. Please set liveupdate=\"1\" if you don't want an empty playlist\n";
 }

 if(my $id = $el->{splcont}->{id}) { #We found an old id with disalbed liveupdate
    foreach(sort {$a <=> $b} split(/ /,$meat{id}{$id})) { push(@{$pldb{$name}}, $_); }
 }

}


#######################################################################
# Normal playlist handler
sub xmk_newpl {
 my($el, $name) = @_;
   foreach my $action (keys(%$el)) {
     if($action eq "add") {
       my $ntm;
       my %mk;
       foreach my $xrn (keys(%{$el->{$action}})) {
         foreach(split(/ /,$cmeat{$xrn}{lc($el->{$action}->{$xrn})})) {
          $mk{$_}++;
         }
         $ntm++;
       }
       foreach(sort {$a <=> $b} keys(%mk)) {
        push(@{$pldb{$name}}, $_) if $mk{$_} == $ntm;
       }
       
     }
     elsif($action eq "regex" || $action eq "iregex") {
      my $ntm;
      my %mk;
       foreach my $xrn (keys(%{$el->{$action}})) {
        $ntm++;
        my $regex = $el->{$action}->{$xrn};
         foreach my $val (keys(%{$meat{$xrn}})) {
          my $mval;
           if($val =~ /$regex/) {
            $mval = $val;
           }
           elsif($action eq "iregex" && $val =~ /$regex/i) {
            $mval = $val;
           }
           ##get the keys
           foreach(split(/ /,$meat{$xrn}{$mval})) {
            $mk{$_}++;
           }
         }
       }
       foreach(sort {$a <=> $b} keys(%mk)) {
        push(@{$pldb{$name}}, $_) if $mk{$_} == $ntm;
       }
     }
   }
}


#########################################################################
# Usage information
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: mktunes.pl [-h] [-m directory] [-v VALUE]

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -n, --ipod-name=NAME    iPod Name (For unlabeled iPods)
   -v, --volume=VALUE      Adjust volume +-VALUE% (example: -v -20)
                            (Works with Firmware 1.x and 2.x!)
   -e, --energy            Save energy (= Disable scrolling title)

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

sub version {
die << "EOF";
mktunes.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2004

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}






