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
use GNUpod::iTunesDB;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;

use vars qw(%opts);
$| = 1;
print "tunes2pod.pl Version 0.94 (C) 2002-2003 Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "force", "help|h", "xml|x=s", "itunes|i=s", "mount|m=s");


usage() if $opts{help};

#Normal operation
converter();

sub converter {
$opts{_no_sync} = 1;
my $con = GNUpod::FooBar::connect(\%opts);
usage("$con->{status}\n") if $con->{status};

#We disabled all autosyncing (_no_sync set to 1), so we do a test
#ourself
if(!$opts{force} && !(GNUpod::FooBar::_itb_needs_sync($con))) {
 print "I don't think that you have to run tunes2pod.pl\n";
 print "The GNUtunesDB looks up-to-date\n";
 print "\n";
 print "If you think i'm wrong, use '$0 --force'\n";
 exit(1);
}



GNUpod::iTunesDB::open_itunesdb($con->{itunesdb}) or usage("Could not open $con->{itunesdb}\n");


#Check where the FILES and PLAYLIST part starts..
#..and how many files are in this iTunesDB
my $itinfo = GNUpod::iTunesDB::get_starts();
#This 2 will change while running..
my $pos = $itinfo->{position};
my $pdi = $itinfo->{pdi};

print "> Has $itinfo->{songs} songs";

#Get all files
my $href= undef;
my $ff = 0;
my %hout = ();
 for(my $i=0;$i<$itinfo->{songs};$i++) {
  ($pos,$href) = GNUpod::iTunesDB::get_mhits($pos); #get the mhit + all child mhods
  #Seek failed.. this shouldn't happen..  
  if($pos == -1) {
   print STDERR "\n*** FATAL: Expected to find $itinfo->{songs} files,\n";
   print STDERR "*** but i failed to get nr. $i\n";
   print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
   print STDERR "*** a bug in GNUpod. Please send this\n";
   print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
   exit(1);
  }
  GNUpod::XMLhelper::mkfile({file=>$href});  
  $ff++;
 }


#<files> part built
print STDOUT "\r> Found $ff files, ok\n";


#Now get each playlist
print STDOUT "> Found ".($itinfo->{playlists}-1)." playlists:\n";
for(my $i=0;$i<$itinfo->{playlists};$i++) {
  ($pdi, $href) = GNUpod::iTunesDB::get_pl($pdi); #Get an mhyp + all child mhods
  if($pdi == -1) {
   print STDERR "*** FATAL: Expected to find $itinfo->{playlists} playlists,\n";
   print STDERR "*** but i failed to get nr. $i\n";
   print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
   print STDERR "*** a bug in GNUpod. Please send this\n";
   print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
   exit(1);
  }
  next if $href->{type}; #Don't list the MPL
  $href->{name} = "NONAME" unless($href->{name}); #Don't create an empty pl
  if(ref($href->{splpref}) eq "HASH" && ref($href->{spldata}) eq "ARRAY") { #SPL Data present
    print ">> Smart-Playlist '$href->{name}' found\n";
    render_spl($href->{name},$href->{splpref}, $href->{spldata}, $href->{matchrule}, $href->{content});
  }
  else { #Normal playlist  
    print ">> Playlist '$href->{name}' with ".int(@{$href->{content}})." songs\n";
    GNUpod::XMLhelper::addpl($href->{name});
    foreach(@{$href->{content}}) {
     my $plfh = ();
     $plfh->{add}->{id} = $_;
     GNUpod::XMLhelper::mkfile($plfh,{plname=>$href->{name}});
    }
  }


}




GNUpod::XMLhelper::writexml($con->{xml});
GNUpod::FooBar::setsync($con);

#The iTunes is now set to clean .. maybe we have to
#update the otg..
$opts{_no_sync} = 0;
GNUpod::FooBar::connect(\%opts);

print STDOUT "\n Done\n";
exit(0);
}



#######################################################
# create a spl
sub render_spl {
 my($name, $pref, $data, $mr, $content) = @_;
 my $of = undef;
 $of->{liveupdate} = $pref->{live};
 $of->{moselected} = $pref->{mos};
 $of->{matchany}   = $mr;
 $of->{limitsort} = $pref->{isort};
 $of->{limitval}  = $pref->{value};
 $of->{limititem} = $pref->{iitem};
 $of->{checkrule} = $pref->{checkrule};
#create this playlist
GNUpod::XMLhelper::addspl($name, $of);

  foreach my $xr (@{$data}) { #Add spldata
    GNUpod::XMLhelper::mkfile({spl=>$xr}, {splname=>$name});
  }
  foreach my $cont(@{$content}) { #Add (old?) content
    GNUpod::XMLhelper::mkfile({splcont=>{id=>$cont}}, {splname=>$name});
  }

}





sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: tunes2pod.pl [-h] [-m directory | -i iTunesDB | -x GNUtunesDB]

   -h, --help             : This ;)
   -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -i, --itunes=iTunesDB  : Specify an alternate iTunesDB
   -x, --xml=file         : GNUtunesDB (XML File)
       --force            : Disable 'sync' checking

EOF
}




