###__PERLBIN__###
#  Copyright (C) 2002-2005 Adrian Ulrich <pab at blinkenlights.ch>
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
#itb         = buffer for iTunesDB
#its         = buffer for iTunesSD
#MPLcontent  = MasterPlaylist content (all songs)
#              Note: if you don't add ALL songs to MPLcontent,
#                    you'd break OTG and Rating AND the iPod
#                    wouldn't boot if it finds a hidden-id in the
#                    OTGPlaylist!!


use constant MPL_UID => 1234567890; #This is the MasterPlaylist ID

print "mktunes.pl ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "version", "help|h", "ipod-name|n=s", "mount|m=s", "volume|v=i", "energy|e");
GNUpod::FooBar::GetConfig(\%opts, {'ipod-name'=>'s', mount=>'s', volume=>'i', energy=>'b'}, "mktunes");

$opts{'ipod-name'} ||= "GNUpod ###__VERSION__###";


usage()   if $opts{help};
version() if $opts{version};

startup();




sub startup {
	my $con = GNUpod::FooBar::connect(\%opts);
	usage("$con->{status}\n") if $con->{status};
	print "! Volume-adjust set to $opts{volume} percent\n" if defined($opts{volume});

	#Open the iTunesSD and write a dummy header
	open(ITS, ">$con->{itunessd}") or die "*** Sorry: Could not write your iTunesSD: $!\n";
	syswrite(ITS,GNUpod::iTunesDB::mk_itunes_sd_header());
	
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
	
	## Write the iTunesDB
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

	#Fix iTunesSD .. Seek to beginning and write a correct header
	print "> Fixing iTunesSD...\n";
	sysseek(ITS,0,0);
	syswrite(ITS,GNUpod::iTunesDB::mk_itunes_sd_header({files=>$itb{INFO}{FILES}}));
	close(ITS);

	print "> Updating Sync-Status\n";
	GNUpod::FooBar::setsync_itunesdb($con);
	GNUpod::FooBar::setvalid_otgdata($con);

	print "You can now umount your iPod. [Files: ".int($itb{INFO}{FILES})."]\n";
	print " - May the iPod be with you!\n\n";
}






#########################################################################
# Create a single playlist
sub r_mpl {
	my($name, $type, $xidref, $spl, $plid, $sortby) = @_;

	my $pl           = undef;
	my $fc           = 0;
	my $mhp          = 0;
	my $reverse_sort = 0;

	if(ref($spl) eq "HASH") { #We got splpref!
		$pl .= GNUpod::iTunesDB::mk_splprefmhod({item=>$spl->{limititem},sort=>$spl->{limitsort},mos=>$spl->{moselected}
		                                         ,liveupdate=>$spl->{liveupdate},value=>$spl->{limitval},
		                                         checkrule=>$spl->{checkrule}}) || return undef;

		$pl .= GNUpod::iTunesDB::mk_spldatamhod({anymatch=>$spl->{matchany},data=>$spldb{$name}}) || return undef;
		$mhp=2; #Add a mhod
	}


	##Check, if user want's sorted stuff
	if($sortby) {
		$sortby=lc($sortby); #LC
		if($sortby =~ /reverse.(.+)/) {
			$reverse_sort = 1;
			$sortby=$1;
		}
		sort_playlist_by({sortby=>lc($sortby), plref=>$xidref, reverse=>$reverse_sort});
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

		#Note: sort isn't aviable for spl's.. hack addspl()
		my($pl, $xc) = r_mpl($plref->{name}, 0, $pldb{$plref->{name}}, 
		                     $splh, $plref->{plid}, $plref->{sort}); #Kick Playlist creator

		if($pl) { #r_mpl got data, we can create a playlist..
			$plc++;         #INC Playlist count
			$pldata .= $pl; #Append data
			#GUI Stuff
			my $plxt = "Smart-" if $splh;
			print ">> Created $plxt"."Playlist '$plref->{name}' with $xc file"; print "s" if $xc !=1;
			print " (sort by '$plref->{sort}')" if $plref->{sort};
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

	foreach my $def (keys(%chr)) {
		next unless $chr{$def}; #Dont create empty fields

		#Crop title if enabled
		$chr{$def} = Unicode::String::utf8($chr{$def})->substr(0,18)->utf8 if $def eq "title" && $opts{energy};

		$nhod = GNUpod::iTunesDB::mk_mhod({stype=>$def, string=>$chr{$def}});
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
	$itb{INFO}{FILES}++; #Count all files (Needed for iTunesDB header (first part))

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

	#Append to iTunesSD
	syswrite(ITS,GNUpod::iTunesDB::mk_itunes_sd_file({path=>$el->{file}->{path},
	                                                  volume=>$el->{file}->{volume}}));
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
		warn "mktunes.pl: unknown pltype '$pltype', skipped\n";
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

	if(my $id = $el->{splcont}->{id}) { #We found an old id with disabled liveupdate
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

#######################################################################
#Sort a playlist ($xidref) by $sortby
#
#Only used for full playlists atm.. and could need a speedup!
#
sub sort_playlist_by {
	my($hr) = @_;
	my $sortby = lc($hr->{sortby});  #SortBy
	my $xidref = $hr->{plref};       #Playlist Reference
	my $reverse= $hr->{reverse};     #Reverse?
	my $isInt  = 0;                  #String by default

	my %sortbuff = ();
	my %xidhash  = ();
	my %sortme   = ();
	my $sortsub  = sub {};

	#Check if $sortby is a string
	$isInt = $GNUpod::iTunesDB::SPLREDEF{field}{lc($sortby)};


	#Create a sub for this search type:
	if($isInt) {
		$sortsub = sub { $a <=> $b }; #Num
		$sortsub = sub { $b <=> $a } if $reverse; #Reverse num
	}
	else {
		$sortsub = sub { uc($a) cmp uc($b)};              #String
		$sortsub = sub { uc($b) cmp uc($a)} if $reverse;  #Reversed String
	}


	#Map array into hash
	%xidhash = map { $_ => 1} @{$xidref};
	@$xidref = (); #Cleanup (do not use undef!)

	#Walk cmeat... cmeat looks like this:
	#$cmeat{'year'}{'2014'} = "13 14 15 16 33 ";
	#We got the value and the 1. key (year) .. now we search all
	#second keys with matching values.. sounds ugly? it is...
	foreach my $cmval (keys(%{$cmeat{$sortby}})) {
		foreach(split(/ /,$cmeat{$sortby}{$cmval})) {
			next unless $xidhash{$_}; #Nope, we don't search for this
			delete($xidhash{$_});     #We found the item, delete it from here
			$sortme{$cmval} .= "$_ "; #Add it..
		}
	}


	foreach(sort $sortsub keys(%sortme)) {
		foreach(split(/ /,$sortme{$_})) {
			push(@$xidref,$_);
		}
	}

	#Maybe something didn't have a $sortby value?
	#We know them: Everything still in %xidhash..
	#-> Append them to the end (i think the beginning isn't good)
	foreach(keys(%xidhash)) {
		push(@$xidref,$_);
	}

	#No need to return anything.. We modify the hashref directly
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






