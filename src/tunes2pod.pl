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
use GNUpod::iTunesDB;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;

use vars qw(%opts);
$| = 1;


print "tunes2pod.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "version", "force", "help|h", "mount|m=s");
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', force=>'b', anapodworkaround=>'b'}, "tunes2pod");


usage() if $opts{help};
version() if $opts{version};



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
my @itinfo = GNUpod::iTunesDB::get_starts();

if(!defined(@itinfo)) {
  warn "File '$con->{itunesdb}' is not an iTunesDB, wrong magic in header!\n";
  exit(1);
}

#Start of Tracklist
my $tracklist_pos   = $itinfo[1]->{start};
my $tracklist_childs = $itinfo[1]->{childs};

#Start of Playlist
my $pl_pos   =  $itinfo[2]->{start};
my $pl_childs = $itinfo[2]->{childs};


print "> Has $tracklist_childs songs";

#Get all files
my $href= undef;
my $ff = 0;
my %hout = ();
for(my $i=0;$i<$tracklist_childs;$i++) {
	#get the mhit + all child mhods
	($tracklist_pos,$href) = GNUpod::iTunesDB::get_mhits($tracklist_pos);
	#Seek failed.. this shouldn't happen..  
	if($tracklist_pos == -1) {
		print STDERR "\n*** FATAL: Expected to find $tracklist_childs files,\n";
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
print STDOUT "> Found ".($pl_childs-1)." playlists:\n";
for(my $i=0;$i<$pl_childs;$i++) {
  ($pl_pos, $href) = GNUpod::iTunesDB::get_pl($pl_pos, {nomplskip=> $opts{anapodworkaround} }); #Get an mhyp + all child mhods
  if($pl_pos == -1) {
   print STDERR "*** FATAL: Expected to find $pl_childs playlists,\n";
   print STDERR "*** but i failed to get nr. $i\n";
   print STDERR "*** Your iTunesDB maybe corrupt or you found\n";
   print STDERR "*** a bug in GNUpod. Please send this\n";
   print STDERR "*** iTunesDB to pab\@blinkenlights.ch\n\n";
   print STDERR "!!! If you are an 'Anapod' user, try to set\n";
   print STDERR "!!!   tunes2pod.anapodworkaround=1\n";
   print STDERR "!!! inside ~/.gnupodrc and re-run the command.\n";
   exit(1);
  }
  next if $href->{type}; #Don't list the MPL
  $href->{name} = "NONAME" unless($href->{name}); #Don't create an empty pl
  if(ref($href->{splpref}) eq "HASH" && ref($href->{spldata}) eq "ARRAY") { #SPL Data present
    print ">> Smart-Playlist '$href->{name}' found\n";
    render_spl($href->{name},$href->{splpref}, $href->{spldata}, $href->{matchrule},
               $href->{content}, $href->{plid});
  }
  else { #Normal playlist  
    print ">> Playlist '$href->{name}' with ".int(@{$href->{content}})." songs\n";
    GNUpod::XMLhelper::addpl($href->{name}, {plid=>$href->{plid}});
    foreach(@{$href->{content}}) {
     my $plfh = ();
     $plfh->{add}->{id} = $_;
     GNUpod::XMLhelper::mkfile($plfh,{plname=>$href->{name}});
    }
  }


}




GNUpod::XMLhelper::writexml($con);
GNUpod::FooBar::setsync_itunesdb($con);
GNUpod::FooBar::setvalid_otgdata($con);

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
 my($name, $pref, $data, $mr, $content, $plid) = @_;
 my $of = undef;
 $of->{liveupdate} = $pref->{live};
 $of->{moselected} = $pref->{mos};
 $of->{matchany}   = $mr;
 $of->{limitsort} = $pref->{isort};
 $of->{limitval}  = $pref->{value};
 $of->{limititem} = $pref->{iitem};
 $of->{checkrule} = $pref->{checkrule};
 $of->{plid}       = $plid;
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
Usage: tunes2pod.pl [-h] [-m directory]

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
       --force             Disable 'sync' checking

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

sub version {
die << "EOF";
tunes2pod.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2004

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}




