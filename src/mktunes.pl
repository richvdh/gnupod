#!/usr/bin/perl

use strict;
use GNUpod::XMLhelper;
use GNUpod::iTunesDB;

use vars qw($xmldoc %itb);


print "mktunes.pl Version 0.9-rc0 (C) 2002-2003 Adrian Ulrich\n";
print "------------------------------------------------------\n";
print "This program may be copied only under the terms of the\n";
print "GNU General Public License v2 or later.\n";
print "------------------------------------------------------\n\n";



startup();






sub startup {
$| = 1;
($xmldoc) = GNUpod::XMLhelper::parsexml('/mnt/ipod/iPod_Control/.gnupod/GNUtunesDB');
 my $quickhash = GNUpod::XMLhelper::build_quickhash($xmldoc);

## FILE STUFF
print "> Creating File Database...\n";
# Create mhits (File index stuff)
 $itb{mhit}{_len_} = build_mhits($quickhash);

# Create header for mhits
 $itb{mhlt}{_data_}   = GNUpod::iTunesDB::mk_mhlt($itb{INFO}{FILES});
 $itb{mhlt}{_len_}    = length($itb{mhlt}{_data_});

# Create header for the mhit header (doh!)
 $itb{mhsd_1}{_data_} = GNUpod::iTunesDB::mk_mhsd($itb{mhit}{_len_}+$itb{mhlt}{_len_}, 1);
 $itb{mhsd_1}{_len_} = length($itb{mhsd_1}{_data_});

# get a nice playlist array..

print "> Creating playlists:\n";
my @xpl = GNUpod::XMLhelper::build_plarr($xmldoc);
# Build the playlists...

 $itb{playlist}{_data_} = genpldata($quickhash, @xpl);
 $itb{playlist}{_len_}  = length($itb{playlist}{_data_});

print "GD\n";

# Create headers for the playlist part..
 $itb{mhsd_2}{_data_} = GNUpod::iTunesDB::mk_mhsd($itb{playlist}{_len_}, 2);
 $itb{mhsd_2}{_len_}  = length($itb{mhsd_2}{_data_});


#Calculate filesize from buffered calculations.. wow, that's very ugly :)
my $fl = 0;
foreach my $xk (keys(%itb)) {
 foreach my $xx (keys(%{$itb{$xk}})) {
  next if $xx ne "_len_";
  $fl += $itb{$xk}{_len_};
 }
}

print "> Writing file...\n";
open(ITB, ">iTunesDB") or die "Sorry: Could not write iTunesDB: $!\n";
 binmode(ITB); #Maybe this helps win32? ;)
 print ITB GNUpod::iTunesDB::mk_mhbd($fl);  #Main header
 print ITB $itb{mhsd_1}{_data_};            #Header for FILE part
 print ITB $itb{mhlt}{_data_};              #mhlt stuff
 print ITB $itb{mhit}{_data_};              #..now the mhit stuff

 print ITB $itb{mhsd_2}{_data_};            #Header for PLAYLIST part
 print ITB $itb{playlist}{_data_};          #Playlist content
close(ITB);

print "You can now umount your iPod. [Files: $itb{INFO}{FILES}]\n";
print " - May the iPod be with you!\n\n";

}






#############################################################
# Create the default playlist
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
my ($quickhash, @xpl) = @_;


#Create default playlist
my $pldata = dflt_plgen($quickhash);
#Set playlistc to 1 , because we got one (dflt_plgen)
my $playlistc = 1;


#..now do the ones specified..
foreach my $cpl (@xpl) {
 #Hu.. we have to create a new playlist
 my %pldata = ();


   #########################################################################################
   ## MATCH Routines.. this is very ugly and we could speedup many things..
   ## But it works as it should.. send me a patch if you like :)
   
  foreach my $cadd(@{$cpl->{add}}) {
    ## New element ##
    my %matchkey = (); #Clean matchkey
    my $smc = 0;
    foreach my $key (keys(%{$cadd})) {
     $smc++; #We have to match every item..

     if($key eq "id" && int(keys(%{$cadd})) == 1) { #Do a FastMatch
      $matchkey{${$cadd}{$key}} = $smc;
     }
     else { #Slow matching

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
}




#############################################################
# Create the mhits (File index)
sub build_mhits {
my($quickhash) = @_;
my $length = 0;
my $nhod = undef;
my @ico = ('-', '\\', '|', '/');
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


