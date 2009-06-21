###__PERLBIN__###
#  Copyright (C) 2002-2007 Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://www.gnu.org/software/gnupod/
#
#    GNUpod is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    GNUpod is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.#
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use GNUpod::iTunesDB;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;
use Data::Dumper;

use constant MODE_SONGS => 1;
use constant MODE_OLDPL => 2;
use constant MODE_NEWPL => 3;

use vars qw(%opts);
$| = 1;

my $xml_files_parsed=0;
my $gtdb = {};

print "tunes2pod.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

GetOptions(\%opts, "version", "force", "help|h", "mount|m=s");
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', force=>'b', model=>'s', low_ram_attr=>'s'}, "tunes2pod");


usage() if $opts{help};
version() if $opts{version};

convert();


sub convert {
	$opts{_no_sync} = 1;
	my $con = GNUpod::FooBar::connect(\%opts);
	usage("$con->{status}\n") if $con->{status};
	
	#We disabled all autosyncing (_no_sync set to 1), so we do a test
	#ourself
	if(!$opts{force} && !(GNUpod::FooBar::ItunesDBNeedsSync($con))) {
		print "I don't think that you have to run tunes2pod.pl\n";
		print "The GNUtunesDB looks up-to-date\n";
		print "\n";
		print "If you think i'm wrong, use '$0 --force'\n";
		exit(1);
	}
	
	if($opts{'low_ram_attr'}) {
		print "> Parsing XML document...\n";
		GNUpod::XMLhelper::doxml($con->{xml}) or usage("Could not read $con->{xml}, did you run gnupod_INIT.pl ?");
		GNUpod::XMLhelper::resetxml;
		print "\r> ".$xml_files_parsed." files parsed, converting iTunesDB...\n";
	}

	open(ITUNES, $con->{itunesdb}) or usage("Could not open $con->{itunesdb}");
	
	while(<ITUNES>) {}; sysseek(ITUNES,0,0); # the iPod is a sloooow mass-storage device, slurp it into the fs-cache
	
	my $self = { ctx => {}, mode => 0, playlist => {}, pc_playlist => {}, count_songs_done => 0, count_songs_total => 0 };
	bless($self,__PACKAGE__);
	$self->ResetPlaylists;
	
	# Define callbacks
	my $obj = { offset => 0, childs => 1, fd=>*ITUNES,
	               callback => {
	                              PACKAGE=>$self, mhod => { item => 'MhodItem' }, mhit => { start => 'MhitStart', end => 'MhitEnd' },
	                              mhsd => { start => 'MhsdStart' },               mhip => { item => 'MhipItem' }, 
	                              mhyp => { item => 'MhypItem', end=>'MhypEnd' }, mhlt => { item => 'MhltItem' },
	                            }
	           };
	GNUpod::iTunesDB::ParseiTunesDB($obj,0);    # Parses the iTunesDB
	GNUpod::XMLhelper::writexml($con);          # Writes out the new XML file
	
	GNUpod::FooBar::SetItunesDBAsInSync($con);     # GNUtunesDB.xml is in-sync with iTunesDB
	GNUpod::FooBar::SetOnTheGoAsValid($con);       # ..and so is the OnTheGo data
	
	#The iTunes is now set to clean .. maybe we have to
	#update the otg..
	$opts{_no_sync}   = 0;
	$opts{_no_cstest} = 1;
	GNUpod::FooBar::connect(\%opts);
	
	print "\n Done\n";
	close(ITUNES) or die "Failed to close filehandle of $con->{itunesdb} : $!\n";
	exit(0);
}

#######################################################################
# Cleans current playlist buffer
sub ResetPlaylists {
	my($self) = @_;
	$self->{playlist}    = { name => 'Lost and Found', plid => 0, mpl => 0, podcast => 0, content => [], spl => {} };
	$self->{pc_playlist} = { index => 0, lists => {} };
}

#######################################################################
# Set name of current playlist
sub SetPlaylistName {
	my($self,$arg) = @_;
	$self->{playlist}->{name} = $arg if length($arg) != 0;
}

#######################################################################
# Set SmartPlaylists preferences for current playlist
sub SetSplPreferences {
	my($self,$ref) = @_;
	$self->{playlist}->{spl}->{preferences} = $ref;
}

#######################################################################
# Sets content of current SmartPlaylist
sub SetSplData {
	my($self,$ref) = @_;
	$self->{playlist}->{spl}->{data} = $ref;
}

#######################################################################
# Sets Matchrule for current SmartPlaylist
sub SetSplMatchrule {
	my($self,$ref) = @_;
	$self->{playlist}->{spl}->{matchrule} = $ref;
}

#######################################################################
# Sets current podcast index
sub SetPodcastIndex {
	my($self,$index) = @_;
	return if $index == 0;
	$self->{pc_playlist}->{index} = $index;
	$self->{pc_playlist}->{lists}->{$index} = { name => 'Lost and Found', content => [] };
}

#######################################################################
sub SetPodcastName {
	my($self,$name) = @_;
	my $index = $self->{pc_playlist}->{index};
	return if $index == 0;
	$self->{pc_playlist}->{lists}->{$index}->{name} = $name if length($name) != 0;
}

#######################################################################
# Append item to podcast playlist
sub AppendPodcastItem {
	my($self,$index,$item) = @_;
	my $index = $self->{pc_playlist}->{index};
	return if $index == 0;
	push(@{$self->{pc_playlist}->{lists}->{$index}->{content}},$item);
}


#######################################################################
# Dumps object content
sub Dumpit {
	my($self,%args) = @_;
	print Data::Dumper::Dumper(\%args);
}

#######################################################################
# Switch to current mhsd mode
sub MhsdStart {
	my($self,%args) = @_;
	my $type = int($args{ref}->{type});
	my $old  = $self->{mode};
	$self->{mode} = $type;
	
	if($old == MODE_SONGS) { print "\r> $self->{count_songs_done} of $self->{count_songs_total} files found, searching playlists\n" }
}

#######################################################################
# A mhit, holds information about size, length.. etc.. Should have a
# mhod as child
sub MhitStart {
	my($self, %args) = @_;
	if($self->{mode} == MODE_SONGS) {
		$self->{ctx} = $args{ref}->{ref};                                 # Swallow-in mhit reference
	}
	else {
		warn "unknown mode: $self->{mode}\n";
	}
}

#######################################################################
# We've seen all mhit childs, so we can write the <file /> item itself
sub MhitEnd {
	my($self, %args) = @_;
	if($self->{mode} == MODE_SONGS) {
		GNUpod::XMLhelper::mkfile({file=>MergeGtdbCtx($self->{ctx})});    # Add <file element to xml
		$self->{ctx} = ();                                                # And drop this buffer
		my $i = ++$self->{count_songs_done};
		if($i % 32 == 0) {
			printf("\r> %d files left, %d%% done    ", $self->{count_songs_total}-$i, ($i/(1+$self->{count_songs_total})*100));
		}
	}
	else {
		warn "unknown mode: $self->{mode}\n";
	}
}

sub MhltItem {
	my($self, %args) = @_;
	$self->{count_songs_total} = $args{ref}->{childs};
}

#######################################################################
# A DataObject
sub MhodItem {
	my($self, %args) = @_;
	
	if($self->{mode} == MODE_SONGS) {
		# -> Songs mode, just add string to current context
		my $key = $args{ref}->{type_string};
		if(length($key)) {
			$self->{ctx}->{$key} = $args{ref}->{string}; # Add mhod item
		}
		else {
			warn "$0: skipping unknown entry of type '$args{ref}->{type}'\n";
		}
	}
	elsif($self->{mode} == MODE_OLDPL) {
		# Legacy playlist
		if($args{ref}->{type_string} eq 'title') {
			# -> Set title of playlist following
			$self->SetPlaylistName($args{ref}->{string});
		}
		elsif($args{ref}->{type} == 50) {
			# -> Remember spl preferences
			$self->SetSplPreferences($args{ref}->{splpref});
		}
		elsif($args{ref}->{type} == 51) {
			# -> Remember spl data
			$self->SetSplData($args{ref}->{spldata});
			$self->SetSplMatchrule($args{ref}->{matchrule});
		}
	}
	elsif($self->{mode} == MODE_NEWPL) {
		# -> Newstyle playlist
		if($args{ref}->{type_string} eq 'title' && $self->{playlist}->{podcast}) {
			# Title of playlist: create it
			$self->SetPodcastName($args{ref}->{string});
		}
	}
}


#######################################################################
# Playlist item
sub MhipItem {
	my($self, %args) = @_;
	if($self->{mode} == MODE_OLDPL) {
		# -> Old playlist. Add SongID to current content container
		push(@{$self->{playlist}->{content}}, $args{ref}->{sid});
	}
	elsif($self->{mode} == MODE_NEWPL && $self->{playlist}->{podcast}) {
		# Only read podcasts in this mode (we do normal playlists in MODE_OLDPL)
		if($args{ref}->{podcast_group} == 256 && $args{ref}->{podcast_group_ref} == 0) {
			# -> Podcast index found
			$self->SetPodcastIndex($args{ref}->{plid});
		}
		elsif($args{ref}->{podcast_group} == 0 && $args{ref}->{podcast_group_ref} != 0) {
			# -> New item for an index found, add it
			$self->AppendPodcastItem($args{ref}->{podcast_group_ref}, $args{ref}->{sid});
		}
	}
}

#######################################################################
# Playlist 'uberblock'
sub MhypItem {
	my($self, %args) = @_;
	$self->{playlist}->{plid}    = $args{ref}->{plid};
	$self->{playlist}->{mpl}     = ($args{ref}->{is_mpl} != 0 ? 1 : 0 );
	$self->{playlist}->{podcast} = ($args{ref}->{podcast} != 0 ? 1 : 0);
}

#######################################################################
# Write out whole playlist
sub MhypEnd {
	my($self, %args) = @_;
	if($self->{mode} == MODE_OLDPL) {
		if($self->{playlist}->{mpl} == 0 && $self->{playlist}->{podcast} == 0) {
			# -> 'Old' non-podcast playlist
			my $plname = $self->{playlist}->{name};
			
			if(ref($self->{playlist}->{spl}->{preferences}) eq "HASH" && ref($self->{playlist}->{spl}->{data}) eq "ARRAY") {
				# -> Handle this as a smart-playlist
				print ">> Smart-Playlist '$plname'";
				my $pref = $self->{playlist}->{spl}->{preferences};
				my $ns   = 0;
				my $nr   = 0;
				GNUpod::XMLhelper::addspl($plname, { liveupdate => $pref->{live}, moselected => $pref->{mos}, limititem=>$pref->{iitem},
				                                      limitsort=>$pref->{isort}, limitval=>$pref->{value},
				                                      matchany=>$self->{playlist}->{spl}->{matchrule},
				                                      checkrule=>$pref->{checkrule}, plid=>$self->{playlist}->{plid} } );
				foreach my $splitem (@{$self->{playlist}->{spl}->{data}}) {
					GNUpod::XMLhelper::mkfile({spl=>$splitem}, {splname=> $plname});
					$nr++;
				}
				foreach my $id (@{$self->{playlist}->{content}}) {
					GNUpod::XMLhelper::mkfile({splcont=>{id=>$id}}, {splname=>$plname});
					$ns++;
				}
				print " with $nr rules and $ns songs\n";
			}
			else {
				# -> This is a normal playlist
				print ">> Playlist '$plname'";
				my $ns = 0;
				GNUpod::XMLhelper::addpl($plname, {plid=>$self->{playlist}->{plid}});
				foreach my $id (@{$self->{playlist}->{content}}) {
					GNUpod::XMLhelper::mkfile({add => { id => $id } },{plname=>$self->{playlist}->{name}});
					$ns++;
				}
				print " with $ns songs\n";
			}
		}
	}
	elsif($self->{mode} == MODE_NEWPL) {
		# -> We are supposed to have a complete podcasts list here..
		foreach my $pci (sort keys(%{$self->{pc_playlist}->{lists}})) {
			my $cl = $self->{pc_playlist}->{lists}->{$pci};
			my $ns = 0;
			print ">> Podcast-Playlist '$cl->{name}'";
			GNUpod::XMLhelper::addpl($cl->{name}, {podcast=>1});
			foreach my $i (@{$cl->{content}}) {
				GNUpod::XMLhelper::mkfile({add => { id => $i } }, {plname=>$cl->{name}});
				$ns ++;
			}
			print " with $ns songs\n";
		}
	}
	$self->ResetPlaylists; # Resets podcast and normal playlist data
}

#########################################################################
# Merge GNUtunesDB with ctx
sub MergeGtdbCtx {
	my($Ctx) = @_;
	return $Ctx unless $Ctx->{path} && $gtdb->{$Ctx->{path}};
	return {%{$gtdb->{$Ctx->{path}}}, %$Ctx};
}

#########################################################################
# Called by doxml if it finds a new <file tag
sub newfile {
	my($item) = @_;
	my $file  = $item->{file};
	my $path  = $file->{path};

	$xml_files_parsed++;
	print "\r> ".$xml_files_parsed." files parsed" if $xml_files_parsed % 96 == 0;

	return unless $path;
	$gtdb->{$path} = {};
	foreach(keys(%$file)){
		$gtdb->{$path}->{$_}=$file->{$_};
	}
}
		
#########################################################################
# Called by doxml if it a new <playlist.. has been found
	sub newpl {
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
Copyright (C) Adrian Ulrich 2002-2007

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}




