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


use vars qw($xmldoc %itb %opts);

$| = 1;
print "mktunes.pl Version 0.91 (C) 2002-2003 Adrian Ulrich\n";


$opts{mount} = $ENV{IPOD_MOUNTPOINT};
GetOptions(\%opts, "help|h", "xml|x=s", "itunes|i=s", "mount|m=s");

usage() if $opts{help};

startup();






sub startup {

my($stat, $itunes, $xml) = GNUpod::FooBar::connect(\%opts);

usage("$stat\n") if $stat;
print "> Parsing XML...\n";
($xmldoc) = GNUpod::XMLhelper::parsexml($xml);
 usage("Could not open $xml, did you run gnupod_INIT.pl ?\n") unless $xmldoc;

 my ($quickhash, $memeat, $cimemeat) = GNUpod::XMLhelper::build_quickhash($xmldoc);

## FILE STUFF
print "> Creating File Database...\n";
# Create mhits (File index stuff)
 $itb{mhit}{_len_} = build_mhits($quickhash);

# Create header for mhits
 $itb{mhlt}{_data_}   = GNUpod::iTunesDB::mk_mhlt($itb{INFO}{FILES});
 $itb{mhlt}{_len_}    = length($itb{mhlt}{_data_});

# Create header for the mhit header
 $itb{mhsd_1}{_data_} = GNUpod::iTunesDB::mk_mhsd($itb{mhit}{_len_}+$itb{mhlt}{_len_}, 1);
 $itb{mhsd_1}{_len_} = length($itb{mhsd_1}{_data_});



## PLAYLIST STUFF
print "> Creating playlists:\n";

my @xpl = GNUpod::XMLhelper::build_plarr($xmldoc);
# Build the playlists...

 $itb{playlist}{_data_} = genpldata($quickhash, $memeat, $cimemeat, @xpl);
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






#############################################################
# Create the default playlist, the iPod needs a 'MPL'
# (= MasterPlayList). This is just a normal Playlist wich
# holds *EVERY* Song on the iPod wich should show up in the
# 'Browser' ..

sub dflt_plgen { 
 my($quickhash) = @_;
 my $pl = undef;
#Note: we are now building a PL, no need to sort the keys as we had
#      to do it in the DB Part, this speeds up things :)
#      (And the ipod has to sort things anyway.. unsortet input doesn't
#       slow down the iPod)
  foreach (keys(%{$quickhash})) {
   $pl .= GNUpod::iTunesDB::mk_mhip($_);
   $pl .= GNUpod::iTunesDB::mk_mhod(undef, undef, $_);
  }
 my $plSize = length($pl);
return GNUpod::iTunesDB::mk_mhyp($plSize, "gnuPod", 1, $itb{INFO}{FILES}).$pl;
}





#############################################################
# Parses playlist stuff
sub genpldata {
my ($quickhash, $memeat, $cimemeat, @xpl) = @_;

#Create default playlist
my $pldata = dflt_plgen($quickhash);
#Set playlistc to 1 , because we got one (dflt_plgen)
my $playlistc = 1;
my %mm = ();


foreach my $cpl (@xpl) {
 my @promoted = ();
   foreach my $action (keys(%$cpl)) {
      next unless ref($cpl->{$action}) eq "ARRAY";
      foreach my $itx (@{$cpl->{$action}}) {
          my $htm = int(keys(%$itx));
	  my %plm;

	  foreach my $pel (keys(%$itx)) {
	       if($action eq "add") {
	          my @keys = split(/ /,$cimemeat->{$pel}{lc($itx->{$pel})});
	          foreach my $mid (@keys) {
	            $plm{$mid}++;
	          }
	        }
		elsif($action eq "iregex" || $action eq "regex") {
		  my $peat = $cimemeat;
		  $peat = $memeat if $action eq "regex";
		  foreach my $valx (keys(%{$peat->{$pel}})) {
		     my $cms = $itx->{$pel};
		     $cms = lc($cms) if $action eq "iregex";
		     if($valx =~ /$cms/) {
		       foreach my $mid (split(/ /,$peat->{$pel}{$valx})) {
		        $plm{$mid}++;
		       }
		     
		     }
		  }
		} else { print "Unhandled action: $action\n"; }
	       
	    }
	  
	  foreach(keys(%plm)) {
	   push(@promoted, $_) if $plm{$_} == $htm;
	  }
	  
      }
      ##end one element!
     
   }



 my $pltemp = undef;
 my $plfc = 0; #PlayListFileCount

 foreach(@promoted) {
  $pltemp .= GNUpod::iTunesDB::mk_mhip($_);
  $pltemp .= GNUpod::iTunesDB::mk_mhod(undef, undef, $_);
  $plfc++;
 }
 #Add header for $pltemp;
 $pldata .= GNUpod::iTunesDB::mk_mhyp(length($pltemp), $cpl->{name}, 0,$plfc).$pltemp;
 print ">> Added Playlist '$cpl->{name}' with $plfc item";
 print "s" if $plfc !=1; print "\n";
 $playlistc++;

}

return GNUpod::iTunesDB::mk_mhlp($playlistc).$pldata;
=head1
## FIXME: Maybe we should SORT the playlists by name?
##        iTunes does it.. hmm.. but it's stupid ;-)

#..now do the ones specified..
foreach my $cpl (@xpl) {
 #Hu.. we have to create a new playlist
 my %pldata = ();

print "DEBUG: ".($cpl->{name})."\n";
   #########################################################################################
   ## MATCH Routines.. this is very ugly and we could speedup many things..
   ## But it works as it should.. send me a patch if you like :)
   
  foreach my $cadd(@{$cpl->{add}}) {
    ## New element ##
    my %matchkey = (); #Clean matchkey
    my $smc = 0;
    print ">> ".($cadd->{id})."\n";
    foreach my $key (keys(%{$cadd})) {
     $smc++; #We have to match every item..

     if($key eq "id" && int(keys(%{$cadd})) == 1) { #Do a FastMatch
      $matchkey{${$cadd}{$key}} = $smc;
     }
     else { #Slow but ultrahyper flexible matching for 'add' target

        foreach my $xid (keys(%{$quickhash})) {
	  foreach my $xkey (keys(%{${$quickhash}{$xid}})) {
	    next if $xkey ne $key;
	    next if lc(${$quickhash}{$xid}{$xkey}) ne lc((${$cadd}{$key}));
	     #If we are still here, it did match!
	     $matchkey{$xid}++;
	  }
	}
     
     }
    }
    ## End new add element
     #Promote matched items..
     foreach(keys(%matchkey)) {
       $pldata{$_} = 1 if($matchkey{$_} == $smc);
     }
   }
   ## END ADD KEYWORD
   
   foreach my $cregex(@{$cpl->{regex}}) {
    my %matchkey = ();
    my $smc = 0;
    foreach my $key (keys(%{$cregex})) {
     $smc++;
        foreach my $xid (keys(%{$quickhash})) {
	  foreach my $xkey (keys(%{${$quickhash}{$xid}})) {
            next if $xkey ne $key;
	    #As you can see: no checking is done, we trust the user..
	    #But we are just a script, no suid root and such things..
	    #Happy regexp-bombing ;-)
	    if (${$quickhash}{$xid}{$xkey} =~ /${$cregex}{$key}/) {
	     $matchkey{$xid}++;
	     }
	  }
	}     
    }
     #Promote matched items..
     foreach(keys(%matchkey)) {
       $pldata{$_} = 1 if($matchkey{$_} == $smc);
     }
   }
   ## END REGEX KEYWORD
   
#Same as regex, but with /i switch..
   foreach my $cregex(@{$cpl->{iregex}}) {
    my %matchkey = ();
    my $smc = 0;
    foreach my $key (keys(%{$cregex})) {
     $smc++;
        foreach my $xid (keys(%{$quickhash})) {
	  foreach my $xkey (keys(%{${$quickhash}{$xid}})) {
            next if $xkey ne $key;
	    if (${$quickhash}{$xid}{$xkey} =~ /${$cregex}{$key}/i) {
	     $matchkey{$xid}++;
	     }
	  }
	}     
    }
     #Promote matched items..
     foreach(keys(%matchkey)) {
       $pldata{$_} = 1 if($matchkey{$_} == $smc);
     }
   }
   ## END IREGEX KEYWORD
   #### FIXME.:: What about these stupid smartplaylists?
 
   #########################################################################################
   #########################################################################################
  
 ### CREATE A NEW PLAYLIST FROM %pldata ###    
    my $pltemp = undef;
    my $plfc  = 0; #PlayListFileCount
     foreach(keys(%pldata)) {
       $pltemp .= GNUpod::iTunesDB::mk_mhip($_);
       $pltemp .= GNUpod::iTunesDB::mk_mhod(undef, undef, $_);
       $plfc++;
     }
      #Add header for $pltemp;
      $pldata .= GNUpod::iTunesDB::mk_mhyp(length($pltemp), $cpl->{name}, 0, $plfc).$pltemp;
  
      print ">> Adding Playlist '$cpl->{name}' with $plfc item";
      print "s" if $plfc != 1; print "\n";
  $playlistc++;
}
 return GNUpod::iTunesDB::mk_mhlp($playlistc).$pldata;
=cut

}




#############################################################
# Create the mhits (File index)
sub build_mhits {
my($quickhash) = @_;
my $length = 0;
my $nhod = undef;
#We are now able to build the 'DB' part
#We have to sort the IDs here.. the iPod wouldn't like
#random input here.... Stupid thing..
  foreach my $key (sort {$a <=> $b} keys(%{$quickhash})) {
   my $href = ${$quickhash}{$key};
    my ($cmhod, $cmhod_count) = undef;
     foreach (keys(%{$href})) {
      next unless ${$href}{$_};
      $nhod = GNUpod::iTunesDB::mk_mhod($_, ${$href}{$_});
      $cmhod .= $nhod;
      $cmhod_count++ if defined $nhod;
     }
     #Ok, we created the mhod's for this item, now we have to create an mhit
     my $mhit = GNUpod::iTunesDB::mk_mhit(length($cmhod), $cmhod_count, %{$href}).$cmhod;
     $itb{mhit}{_data_} .= $mhit;
     $length += length($mhit);
     $itb{INFO}{FILES}++;

  }
 return $length;
}









sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: mktunes.pl [-h] [-m directory | -i iTunesDB | -x GNUtunesDB]

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --itunes=iTunesDB  : Specify an alternate iTunesDB
   -x, --xml=file         : GNUtunesDB (XML File)

EOF
}






