#!/usr/bin/perl
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

use strict;
use GNUpod::XMLhelper;
use GNUpod::iTunesDB;
use GNUpod::FooBar;
use Getopt::Long;


use vars qw($cid %pldb %itb %opts %meat %cmeat);
$cid=52;
$| = 1;
print "mktunes.pl Version 0.91 (C) 2002-2003 Adrian Ulrich\n";


$opts{mount} = $ENV{IPOD_MOUNTPOINT};
GetOptions(\%opts, "help|h", "xml|x=s", "itunes|i=s", "mount|m=s", "volume|v=i");

usage() if $opts{help};

startup();




sub newfile {
 my($el) = @_;
 $cid++;
 $itb{mhit}{_len_} += build_mhit($cid, $el->{file}); 

##Create the gnuPod 0.2x like memeater
 #$meat{KEY}{VAL} = id." ";
 foreach(keys(%{$el->{file}})) {
  $meat{$_}{$el->{file}->{$_}} .= $el->{file}->{id}." ";
  $cmeat{$_}{lc($el->{file}->{$_})} .= $cid." ";
 }
}

sub newpl   {
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
       foreach(keys(%mk)) {
        push(@{$pldb{$name}}, $_) if $mk{$_} >= $ntm;
       }
       
     }
     elsif($action eq "regex" || $action eq "iregex") {
      my $ntm;
      my %mk;
      my $mval;
       foreach my $xrn (keys(%{$el->{$action}})) {
        $ntm++;
        my $regex = $el->{$action}->{$xrn};
         foreach my $val (keys(%{$meat{$xrn}})) {
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
       foreach(keys(%mk)) {
        push(@{$pldb{$name}}, $_) if $mk{$_} >= $ntm;
       }
     }
   }
}

sub startup {

my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);

usage("$stat\n") if $stat;

print "! Volume-adjust set to $opts{volume} percent\n" if defined($opts{volume});

print "> Parsing XML and creating FileDB\n";
GNUpod::XMLhelper::doxml($xml);


# Create header for mhits
 $itb{mhlt}{_data_}   = GNUpod::iTunesDB::mk_mhlt($itb{INFO}{FILES});
 $itb{mhlt}{_len_}    = length($itb{mhlt}{_data_});

# Create header for the mhit header
 $itb{mhsd_1}{_data_} = GNUpod::iTunesDB::mk_mhsd($itb{mhit}{_len_}+$itb{mhlt}{_len_}, 1);
 $itb{mhsd_1}{_len_} = length($itb{mhsd_1}{_data_});



## PLAYLIST STUFF
print "> Creating playlists:\n";

 $itb{playlist}{_data_} = genpls();
 $itb{playlist}{_len_}  = length($itb{playlist}{_data_});
# Create headers for the playlist part..
 $itb{mhsd_2}{_data_} = GNUpod::iTunesDB::mk_mhsd($itb{playlist}{_len_}, 2);
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
print "> Writing file...\n";
open(ITB, ">$itunes") or die "** Sorry: Could not write your iTunesDB: $!\n";
 binmode(ITB); #Maybe this helps win32? ;)
 print ITB GNUpod::iTunesDB::mk_mhbd($fl);  #Main header
 print ITB $itb{mhsd_1}{_data_};            #Header for FILE part
 print ITB $itb{mhlt}{_data_};              #mhlt stuff
 print ITB $itb{mhit}{_data_};              #..now the mhit stuff

 print ITB $itb{mhsd_2}{_data_};            #Header for PLAYLIST part
 print ITB $itb{playlist}{_data_};          #Playlist content
close(ITB);
## Finished!

print "You can now umount your iPod. [Files: $itb{INFO}{FILES}]\n";
print " - May the iPod be with you!\n\n";
}



sub r_mpl {
 my($name, $type, @xid) = @_;
my $pl = undef;
my $fc = 0;
 foreach(@xid) {
  $pl .= GNUpod::iTunesDB::mk_mhip($_);
  $pl .= GNUpod::iTunesDB::mk_mhod(undef, undef, $_);
  $fc++;
 }
 my $plSize = length($pl);
 return (GNUpod::iTunesDB::mk_mhyp($plSize, $name, $type, $fc).$pl,$fc);
}


sub genpls {
 my ($pldata,undef) = r_mpl("gnuPod", 1,(1..$cid));
 my $plc = 1;
 
  foreach(GNUpod::XMLhelper::getpl_names()) {
    print ">> Added Playlist '$_'";
    $plc++;
    my($pl, $xc) = r_mpl($_, 0, @{$pldb{$_}});
    $pldata .= $pl;
    print " with $xc files\n";
  }
 
 return GNUpod::iTunesDB::mk_mhlp($plc).$pldata;
}

#########################################################################
# Create the file index (like <files>)
sub build_mhit {
 my($oid, $href) = @_;
 $href->{id} = $oid;
 
my ($nhod,$cmhod,$cmhod_count) = undef;
 foreach(keys(%$href)) {
  next unless $href->{$_};
  $nhod = GNUpod::iTunesDB::mk_mhod($_, $href->{$_});
  $cmhod .= $nhod;
  $cmhod_count++ if defined $nhod;
 }
     #Volume adjust
     if($opts{volume}) {
      $href->{volume} += int($opts{volume});
      if(abs($href->{volume}) > 100) {
        print "** Warning: volume=\"$href->{volume}\" out of range: Volume set to ";
        $href->{volume} = ($href->{volume}/abs($href->{volume})*100);
        print "$href->{volume}% for id $href->{id}\n";
      }
     }
     
     #Ok, we created the mhod's for this item, now we have to create an mhit
     my $mhit = GNUpod::iTunesDB::mk_mhit(length($cmhod), $cmhod_count, %{$href}).$cmhod;
     $itb{mhit}{_data_} .= $mhit;
     my $length = length($mhit);
     $itb{INFO}{FILES}++;

return $length;
}






sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: mktunes.pl [-h] [-m directory | -i iTunesDB | -x GNUtunesDB] [-v VALUE]

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --itunes=iTunesDB  : Specify an alternate iTunesDB
   -x, --xml=file         : GNUtunesDB (XML File)
   -v, --volume=VALUE     : Adjust volume +-VALUE% (example: -v -20)
                            (Works with Firmware 1.x and 2.x!)

EOF
}






