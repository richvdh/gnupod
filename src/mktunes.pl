#!/usr/bin/perl

use strict;
use GNUpod::XMLhelper;
use GNUpod::iTunesDB;

use vars qw($xmldoc %itb);

startup();

sub startup {
($xmldoc) = GNUpod::XMLhelper::parsexml('/mnt/ipod/iPod_Control/.gnupod/GNUtunesDB');
 my $quickhash = GNUpod::XMLhelper::build_quickhash($xmldoc);

## FILE STUFF
 
# Create mhits (File index stuff)
 $itb{mhit}{_len_} = build_mhits($quickhash);


# Create header for mhits
 $itb{mhlt}{_data_}   = GNUpod::iTunesDB::mk_mhlt($itb{INFO}{FILES});
 $itb{mhlt}{_len_}    = length($itb{mhlt}{_data_});

# Create header for the mhit header (doh!)
 $itb{mhsd_1}{_data_} = GNUpod::iTunesDB::mk_mhsd($itb{mhit}{_len_}+$itb{mhlt}{_len_}, 1);
 $itb{mhsd_1}{_len_} = length($itb{mhsd_1}{_data_});


 ## create mhsd_2
my @xpl = GNUpod::XMLhelper::build_plarr($xmldoc);
 my $pldata = genpldata($quickhash, @xpl);
# my $pldata = dflt_plgen($quickhash);
 my $pl_len = length($pldata);


 $itb{mhsd_2}{_data_} = GNUpod::iTunesDB::mk_mhsd($pl_len, 2);
 $itb{mhsd_2}{_len_}  = length($itb{mhsd_2}{_data_});


my $fl = 0;
foreach my $xk (keys(%itb)) {
print "!$xk\n";
 foreach my $xx (keys(%{$itb{$xk}})) {
  next if $xx ne "_len_";
  $fl += $itb{$xk}{_len_};
 }
}
$fl += $pl_len;
print "** $fl **\n";
my $w =  $itb{mhsd_1}{_data_};
   $w .= $itb{mhlt}{_data_};
   $w .= $itb{mhit}{_data_};
   $w .= $itb{mhsd_2}{_data_};
   $w .= $pldata;
print STDERR GNUpod::iTunesDB::mk_mhbd($fl);
print STDERR $w;
print "*** ".length($w)." ** /should be the same as above!!!\n";
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

# return GNUpod::iTunesDB::mk_mhlp(1).GNUpod::iTunesDB::mk_mhyp($plSize, "gnuPod", 1, $itb{INFO}{FILES}).$pl;
}


#############################################################
# Parses playlist stuff
sub genpldata {
my ($quickhash, @xpl) = @_;

my $playlistc = 1;
#Create default playlist
my $pldata = dflt_plgen($quickhash);

#my $drag = GNUpod::iTunesDB::mk_mhip(2).GNUpod::iTunesDB::mk_mhod(undef, undef, 2);
#$pldata = $pldata . GNUpod::iTunesDB::mk_mhyp(length($drag), "DEBUG", 0, 1) . $drag;
#$playlistc++;

#..now do the ones specified..
foreach my $cpl (@xpl) {
 my %pldata = ();
  foreach my $cadd(@{$cpl->{add}}) {
    ## New element ##
    my %matchkey = (); #Clean matchkey
    my $smc = 0;
    foreach my $key (keys(%{$cadd})) {
     $smc++; #$xid would always be int, so this is save...
        foreach my $xid (keys(%{$quickhash})) {
	  foreach my $xkey (keys(%{${$quickhash}{$xid}})) {
	    next if $xkey ne $key;
	    next if lc(${$quickhash}{$xid}{$xkey}) ne lc((${$cadd}{$key}));
	     #If we are still here, it did match!
	     $matchkey{$xid}++;
	  }
	}
    }
    ## End new add element
     #Promote matched items..
     foreach(keys(%matchkey)) {
       $pldata{$_} = 1 if($matchkey{$_} == $smc);
     }
     
  }
  
 ### CREATE A NEW PLAYLIST ###    
    my $pltemp = undef;
    my $plfc  = 0;
     foreach(keys(%pldata)) {
      $pltemp .= GNUpod::iTunesDB::mk_mhip($_);
       $pltemp .= GNUpod::iTunesDB::mk_mhod(undef, undef, $_);
       $plfc++;
     #  print "------> $cpl->{name} ++ $_\n";
     }
      #Add header for $pltemp;
      $pldata .= GNUpod::iTunesDB::mk_mhyp(length($pltemp), $cpl->{name}, 0, $plfc).$pltemp;
      print ">>Addeing Playlist '$cpl->{name}' with $plfc item";
      print "s" if $plfc != 1; print "\n";
  
  $playlistc++;
}
print "PLCOUNT IS AT $playlistc\n";
 return GNUpod::iTunesDB::mk_mhlp($playlistc).$pldata;
}

#############################################################
# Create the mhits (File index)
sub build_mhits {
my($quickhash) = @_;
my $length = 0;
my $nhod = undef;
#We are now able to build the 'DB' part

#We have to sort the IDs here.. the iPod wouldn't like
#random input here...
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


