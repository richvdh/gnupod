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
use vars qw(%opts @keeper $ratingref);


$opts{mount} = $ENV{IPOD_MOUNTPOINT};

#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "top4secret");

if($opts{top4secret}) {
 go();
}
else {
 usage("$0 isn't for humans :-)\nGNUpod::FooBar.pm has to execute me\n");
}

####################################################
# Worker
sub go {
 #Disable auto-run of tunes2pod or gnupod_otgsync.pl
 $opts{_no_sync} = 1;
 my $con = GNUpod::FooBar::connect(\%opts);
 usage($con->{status}."\n") if $con->{status};

 if(GNUpod::FooBar::_itb_needs_sync($con)) {
  die "gnupod_otgsync.pl: Bug detected! You need to run tunes2pod.pl -> Sync broken!\n";
 }



#Read on The Go list written by the iPod
my @xotg    = GNUpod::iTunesDB::readOTG($con->{onthego});

#ratingref is used by newfile()
#so we have to call this before doxml()
$ratingref  = GNUpod::iTunesDB::readPLC($con->{playcounts});


 #Add dummy entry, we start to count at 1, not at 0
 if(int(@xotg) || $ratingref) { #We have to modify
  push(@keeper, -1);
  #First, we parse the old xml document and create the keeper
  GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}\n");
  mkotg(@xotg) if int(@xotg);
  GNUpod::XMLhelper::writexml($con->{xml});
  unlink($con->{onthego});
 }
 
 #OnTheGo and playcounts is now ok, set sync for it to true
 GNUpod::FooBar::setsync_playcounts($rr);
 
}

#############################################
# Add onthego contents to XML
sub mkotg {
my(@xotg) = @_;
 #Get all old playlists and create a new name
 my $otggen = 1;
 foreach(GNUpod::XMLhelper::getpl_names()) {
   if($_ =~ /^On-The-Go (\d+)/) {
    $otggen = ($1+1) if $otggen<=$1;
   }
 }
 
 GNUpod::XMLhelper::addpl("On-The-Go $otggen");
 foreach(@xotg) {
  my $otgid = $_+1;
  my $plfh = ();
  $plfh->{add}->{id} = $keeper[$otgid];
  next unless $plfh->{add}->{id};
  GNUpod::XMLhelper::mkfile($plfh,{"plname"=>"On-The-Go $otggen"});
 }
}

#############################################
# Eventhandler for FILE items
sub newfile {
 my($el) =  @_;
 push(@keeper, int($el->{file}->{id}));
 #Adjust rating
 $el->{file}->{rating} = $ratingref->{int(@keeper)-1} if $ratingref;
   GNUpod::XMLhelper::mkfile($el);
}

############################################
# Eventhandler for PLAYLIST items
sub newpl {
 my($el,$name,$plt) = @_;
  GNUpod::XMLhelper::mkfile($el,{$plt."name"=>$name});
}

############################################
# Die with status
sub usage {
 die "$_[0]";
}

