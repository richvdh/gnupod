package GNUpod::Mktunes;
	use GNUpod::iTunesDB;
	use constant MODE_ADDFILE      => 1;
	use constant MODE_ADDPL        => 2;
	use constant PLAYLIST_HIDDEN   => 1;
	use constant PLAYLIST_VISIBLE  => 0;
	use constant MPL_UID           => 1234567890;
	use constant IPODNAME_FALLBACK => "GNUpod ###__VERSION__###";
	#########################################################################
	# Creats a new mktunes object
	sub new {
		my($class,%args) = @_;
		
		my $self = { Connection=>$args{Connection}, Mode=>MODE_ADDFILE, Artwork=>$args{Artwork},
		             ArrayFiles => [], CountFiles => 0, Sequence => 0, SequenceJumped => 0, iPodName => $args{iPodName},
		             MasterPlaylist => [], Playlists => {}, SmartPlaylists => {},
		             FuzzyDb_Normal => {}, FuzzyDb_Lowercase => {} };
		bless($self,$class);
	}
	
	sub WriteItunesSD {
		my($self) = @_;
		open(ITS, ">", $self->GetConnection->{itunessd}) or die "*** Unable to write the iTunesDB: $!, did you run gnupod_INIT.pl ?\n";
		binmode(ITS);
		print ITS GNUpod::iTunesDB::mk_itunes_sd_header({files=>$self->GetFileCount});
		foreach my $item (@{$self->GetFiles}) {
			print ITS GNUpod::iTunesDB::mk_itunes_sd_file($item);
		}
		close(ITS) or die "Failed to close filehandle of ".$self->GetConnection->{itunessd}." : $!\n";
	}
	
	
	
	#########################################################################
	# Create and write the iTunesDB file
	sub WriteItunesDB {
		my($self,%args) = @_;
		
		my $mhbd_size = 0;
		my $mhsd_size = 0;
		my $mhsd_pos  = 0;
		
		my $outfile = $self->GetConnection->{itunesdb};
		my $tmpfile = $outfile.".$$";
		
		open(ITUNES, ">", $tmpfile) or die "*** Unable to write the iTunesDB: $!, did you run gnupod_INIT.pl ?\n";
		binmode(ITUNES);
		print ITUNES GNUpod::iTunesDB::mk_mhbd({});
			$mhbd_size = tell(ITUNES);
			$mhsd_pos  = tell(ITUNES);
		print ITUNES GNUpod::iTunesDB::mk_mhsd({});
			$mhsd_size = tell(ITUNES);
		print ITUNES GNUpod::iTunesDB::mk_mhlt({songs=>$self->GetFileCount});
		foreach my $item (@{$self->GetFiles}) {
			print ITUNES $self->AssembleMhit(object=>$item, keep=>$args{keep});
			print "\r> $i files assembled " if ($i++ % 96 == 0);
		}
			$mhsd_size = tell(ITUNES)-$mhsd_size;
		
		print "\r> Creating iPod playlists...\n";
		
		my   $playlists = $self->CreateAllPlaylists;
		
		print ITUNES GNUpod::iTunesDB::mk_mhsd({type=>3, size=>length(GNUpod::iTunesDB::mk_mhlp({}).$playlists->{newstyle})});
		print ITUNES GNUpod::iTunesDB::mk_mhlp({playlists=>$playlists->{count_newstyle}});
		print ITUNES $playlists->{newstyle};
		
		print ITUNES GNUpod::iTunesDB::mk_mhsd({type=>2, size=>length(GNUpod::iTunesDB::mk_mhlp({}).$playlists->{legacy})});
		print ITUNES GNUpod::iTunesDB::mk_mhlp({playlists=>$playlists->{count_legacy}});
		print ITUNES $playlists->{legacy};
			$mhbd_size = tell(ITUNES)-$mhbd_size;
		
		# Fixup some things:
		GNUpod::FooBar::SeekFix(*ITUNES,0        ,GNUpod::iTunesDB::mk_mhbd({size=>$mhbd_size, childs=>3}));
		GNUpod::FooBar::SeekFix(*ITUNES,$mhsd_pos,GNUpod::iTunesDB::mk_mhsd({size=>$mhsd_size, type=>1}));
		close(ITUNES) or die "Failed to close filehandle of $tmpfile : $!\n";
		
		unlink($outfile); # can fail
		rename($tmpfile,$outfile) or die "*** Unable to move $tmpfile to $outfile : $!\n";
	}
	
	
	
	
	
	
	
	# Increments file counter
	sub IncrementFileCount  { my($self) = @_; return $self->{CountFiles}++;  }
	# Returns the file count
	sub GetFileCount        { my($self) = @_; return $self->{CountFiles};    }
	# Increments Sequence counter
	sub GetNextId           { my($self) = @_; return ++$self->{Sequence};    }
	# Dispatch connector
	sub GetConnection       { my($self) = @_; return $self->{Connection}     }
	# Returns array to files
	sub GetFiles            { my($self) = @_; return $self->{ArrayFiles}     }
	# Returns the Master Playlist
	sub GetMasterPlaylist   { my($self) = @_; return $self->{MasterPlaylist} }
	# Returns given playlist
	sub GetPlaylist         { my($self,$name) = @_; return ($self->{Playlists}->{$name} || [])}
	# Returns given smartplaylist
	sub GetSmartPlaylist    { my($self,$name) = @_; return ($self->{SmartPlaylists}->{$name} || [])}
	# Adds an entry to the MPL
	
	#########################################################################
	# Add new id to master playlist
	sub _AddToMasterPlaylist {
		my($self,$e) = @_;
		push(@{$self->{MasterPlaylist}},$e);
	}
	
	#########################################################################
	# Add new id to given playlist
	sub _AddToPlaylist {
		my($self, %args) = @_;
		push(@{$self->{Playlists}->{$args{Name}}},$args{Id});
	}
	
	#########################################################################
	# Add new item to given SmartPlaylist
	sub _AddToSmartPlaylist {
		my($self, %args) = @_;
		push(@{$self->{SmartPlaylists}->{$args{Name}}},$args{Item});
	}
	
	#########################################################################
	# This subroutine assembles all playlists
	sub CreateAllPlaylists {
		my($self) = @_;
		my $mpl_name         = Unicode::String::utf8($self->{iPodName} || IPODNAME_FALLBACK)->utf8;
		my $master_playlist  = $self->CreateSinglePlaylist(Name=>$mpl_name, Type=>PLAYLIST_HIDDEN, Content=>$self->GetMasterPlaylist, PlaylistId=>MPL_UID)->{payload};
		my $playlist_buff    = ''; # Buffer for the normal playlist
		my $legacy_pc_buff   = ''; # Buffer for legacy podcast playlist
		my $new_pc_buff      = ''; # Buffer for newstyle-podcast playlist
		my $playlist_count_o = 1;  # Old/Legacy playlist count: MasterPlaylist + N-Other                         = 1+x
		my $playlist_count_n = 2;  # New playlist count       : MasterPlaylist + PodcastPlaylistHeader + N-Other = 2+x
		my $podcast_id       = 1;  # First podcast-id to use
		my @podcast_playlist = (); # Holds items we are going to slap into the legacy podcast playlist
		my $podcast_childs   = 0;
		
		
		foreach my $plref (GNUpod::XMLhelper::getpl_attribs()) {
			my $splh = GNUpod::XMLhelper::get_splpref($plref->{name}); #Get SPL Prefs
			my $plh  = GNUpod::XMLhelper::get_plpref($plref->{name});  #Get normal-pl preferences
			
			my $playlist = ();
			
			if($plh->{podcast} == 1) {
				# -> Playlist is a podcast
				
				# Add items for legacy creator
				push(@podcast_playlist, @{$self->GetPlaylist($plref->{name})});
				# Create the newstyle-podcast chunk
				$playlist = $self->CreateSinglePlaylist(Name=>$plref->{name}, Type=>PLAYLIST_VISIBLE, PodcastContent=>$self->GetPlaylist($plref->{name}),
				                                        PlaylistId=>$plref->{plid}, Sortby=>$plref->{sort}, Podcast=>1, PodcastId=>$podcast_id, SeperateHeader=>1);
				$new_pc_buff    .= $playlist->{payload}; # Add new child to buffer
				$podcast_childs += $playlist->{childs}; # Increment child count
				$podcast_id     += $playlist->{childs}; # Set next podcast id (iTunes way..)
			}
			else {
				# Normal playlist:
				$playlist = $self->CreateSinglePlaylist(Name=>$plref->{name}, Type=>PLAYLIST_VISIBLE, Content=>$self->GetPlaylist($plref->{name}),
				                                      PlaylistId=>$plref->{plid}, SplContent=>$splh, Sortby=>$plref->{sort});
				$playlist_buff   .= $playlist->{payload};
				$playlist_count_n++; # Increment NewstylePlaylist counter
				$playlist_count_o++; # Increment OldstylePlaylist counter
			}
			
			my $pl_type = ($playlist->{smartplaylist} ? 'Smart-' : ( $playlist->{podcastplaylist} ? 'Podcast-' : '' ) );
			
			print ">> Created ".$pl_type."Playlist '$plref->{name}' with $playlist->{songs} files\n";
		}
		
		if($podcast_childs) {
			# -> We need to create a legacy list:
			$legacy_pc_buff = $self->CreateSinglePlaylist(Name=>'Podcasts', Type=>PLAYLIST_VISIBLE, Content=>\@podcast_playlist, Podcast=>1, Sortby=>'releasedate')->{payload};
			$playlist_count_o++;
		}
		
		$new_pc_buff = GNUpod::iTunesDB::mk_mhyp({size=>length($new_pc_buff),name=>'Podcasts', type=>0,files=>$podcast_childs, podcast=>1}).$new_pc_buff;
		
		return {legacy=>$master_playlist.$playlist_buff.$legacy_pc_buff, count_legacy=>$playlist_count_o,
		        newstyle=>$master_playlist.$playlist_buff.$new_pc_buff, count_newstyle=>$playlist_count_n};
	}
	
	
	
	#########################################################################
	# Assembles a single playlist
	sub CreateSinglePlaylist {
		my($self, %args) = @_;
		
		my $name          = $args{Name};           # Name of this playlist
		my $type          = $args{Type};           # Type (PLAYLIST_HIDDEN or PLAYLIST_VISIBLE)
		my $cont          = $args{Content};        # Content of a normal playlist
		my $cspl          = $args{SplContent};     # SplContent of the smart-playlist part
		my $plid          = $args{PlaylistId};     # PlaylistId to use
		my $sort          = $args{Sortby};         # How shall we sort?
		my $pcast         = $args{Podcast};        # Mark playlist as podcast (used by new and oldstyle)
		my $pcont         = $args{PodcastContent}; # Content for newstyle podcasts (also needs PodcastId to be non-null)
		my $pcid          = $args{PodcastId};      # Podcast id to use
		my $seperate_hdr  = $args{SeperateHeader}; # Do not include the header in our payload but drop it into the 'header' field
		my $buff_playlist = '';                    # Payload buffer
		my $mhod_count    = 0;                     # Mhods we created
		my $spl_mhod_count= 0;                     # SmartPlaylist mhods
		my $child_count   = 0;                     # Childs we created (may be == mhod_count if no spl is there)
		my $songs_count   = 0;                     # Number of songs
		my $podcast_list  = 0;
		
		if($pcid) {
			$self->SortPlaylist(Sortby=>$sort, Playlist=>$pcont) if $sort;
			my $pcplid = 1 + $pcid;
			my $current_mhod = GNUpod::iTunesDB::mk_mhod({stype=>'title', string=>$name});
			my $current_mhip = GNUpod::iTunesDB::mk_mhip({childs=>1,podcast_group=>256,plid=>$pcid, size=>length($current_mhod)}); # 256 .. apple magic
			$buff_playlist .= $current_mhip.$current_mhod;
			$child_count++;
			$podcast_list = 1;
			foreach my $fqid (@{$pcont}) {
				$child_count++;
				$songs_count++;
				$pcplid++;
				my $x_mhod = GNUpod::iTunesDB::mk_mhod({fqid=>0});
				my $x_mhip = GNUpod::iTunesDB::mk_mhip({childs=>1,sid=>$fqid, plid=>$pcplid, podcast_group_ref=>$pcid, size=>length($x_mhod)});
				$buff_playlist .= $x_mhip.$x_mhod;
			}
		}
		else {
		$self->SortPlaylist(Sortby=>$sort, Playlist=>$cont) if $sort;
			if(ref($cspl) eq "HASH") {
				# -> Create SPL header for given playlist
				$buff_playlist .= GNUpod::iTunesDB::mk_splprefmhod({item=>$cspl->{limititem},sort=>$cspl->{limitsort},mos=>$cspl->{moselected}
				                                                  ,liveupdate=>$cspl->{liveupdate},value=>$cspl->{limitval},
				                                                   checkrule=>$cspl->{checkrule}}) || die "Failed to create splprefmhod\n";
				
				$buff_playlist .= GNUpod::iTunesDB::mk_spldatamhod({anymatch=>$cspl->{matchany} ,data=>$self->GetSmartPlaylist($name)}) || die "Failed to create spldatamhod\n";
				$mhod_count += 2;
				$spl_mhod_count++;
			}
			
			
			foreach my $fqid (@{$cont}) {
				if (! $self->{SequenceJumped} ) { my $i=1<<15; while ($i < $self->{Sequence}) { $i<<=1;};  $self->{Sequence} = $i; $self->{SequenceJumped}=1; };
				my $current_id = $self->GetNextId;
				my $current_mhod = GNUpod::iTunesDB::mk_mhod({fqid=>$fqid});
				my $current_mhip = GNUpod::iTunesDB::mk_mhip({childs => 1, plid => $current_id, sid=>$fqid, size=>length($current_mhod)});
				next unless (defined($current_mhod) && defined($current_mhip));
				$child_count++;
				$songs_count++;
				$buff_playlist .= $current_mhip.$current_mhod;
			}
		}
		
		my $mhyp = GNUpod::iTunesDB::mk_mhyp({size=>length($buff_playlist), name=>$name, type=>$type, files=>$child_count,
		                                     stringmhods=>$spl_mhod_count, mhods=>$mhod_count, plid=>$plid, podcast=>$pcast});
		if(!$seperate_hdr) {
			# -> Merge the header into the payload
			$buff_playlist = $mhyp.$buff_playlist;
			$mhyp          = '';
		}
		
		return({header=>$mhyp, payload=>$buff_playlist, childs=>$child_count, mhods=>$mhod_count, songs=>$songs_count,
		        smartplaylist=>int($spl_mhod_count != 0), podcastplaylist=>$podcast_list});
		
	}
	
	
	#########################################################################
	# Builds a single mhit with mhod childs
	sub AssembleMhit {
		my($self, %args) = @_;
		my $object      = $args{object};
		my $keep        = $args{keep};
		my $mhit        = ''; # Buffer for the new mhit
		my $mhod_chunks = ''; # Buffer for the childs (mhods)
		my $mhod_count  = 0;  # Child counter
		
		foreach my $key (sort keys(%$object)) {
			my $value = $object->{$key};
			next unless $value; # Do not write empty values
			next if (scalar keys %$keep && !$keep->{$key}); # Only keep specific mhods
			my $new_mhod = GNUpod::iTunesDB::mk_mhod({stype=>$key, string=>$value});
			next unless $new_mhod; # Something went wrong
			$mhod_chunks .= $new_mhod;
			$mhod_count++;
		}
		$mhit = GNUpod::iTunesDB::mk_mhit({size=>length($mhod_chunks), count=>$mhod_count, fh=>$object, artwork=>$self->{Artwork} });
		return $mhit.$mhod_chunks;
	}
	
	
	#########################################################################
	# Add entry to FuzzyDb .. beware of bad syntax
	sub Fuzzyfy {
		my($self,$a,$b,$c) = @_;
		$self->{FuzzyDb_Normal}->{$a}->{$b} .= $c." ";
		$self->{FuzzyDb_Lowercase}->{$a}->{lc($b)} .= $c." ";
	}
	
	
	#########################################################################
	# 'Registers' a new file
	sub AddFile {
		my($self,$item) = @_;
		
		$self->IncrementFileCount;                 # Increment file counter
		my $current_id = $self->GetNextId;         # And get a new 'sequence' number
		$self->_AddToMasterPlaylist($current_id);  # Add id to master-playlist
		
		foreach(keys(%{$item})) {                  # Add to FuzzyDb
			$self->Fuzzyfy($_,$item->{$_},$current_id);
		}
		
		$item->{id} = $current_id;                 # The iTunesDB will use the sequence id, not the id from the XML file
		push(@{$self->{ArrayFiles}},$item);        # Add the object
		return $current_id;
	}
	
	
	#########################################################################
	# Register new SmartPlaylist item
	sub AddSmartPlaylistItem {
	my($self, %args) = @_;
		my $name  = $args{Name};
		my $item  = $args{Item};
		my $mpref = GNUpod::XMLhelper::get_splpref($name)->{matchany};
		
		#Is spl data, add it
		if(my $xr = $item->{spl}) {
			$self->_AddToSmartPlaylist(Name=>$name, Item=>$xr);
		} 
		
		unless(GNUpod::XMLhelper::get_splpref($name)->{liveupdate}) {
			warn "mktunes.pl: warning: (pl: $name) Liveupdate disabled. Please set liveupdate=\"1\" if you don't want an empty playlist\n";
		}
	
		if(my $id = $item->{splcont}->{id}) { #We found an old id with disabled liveupdate, add it like a normal playlist:
			foreach(sort {$a <=> $b} split(/ /,$self->{FuzzyDb_Normal}->{id}->{$id})) { $self->_AddToPlaylist(Name=>$name, Id=>$_); }
		}
	}
	
	
	#########################################################################
	# Register a normal playlist item
	sub AddNormalPlaylistItem {
		my($self,%args) = @_;
		my $name = $args{Name};
		my $item = $args{Item};
		
		foreach my $action (keys(%$item)) {
			if($action eq "add") {
				my $ntm;
				my %mk;
				foreach my $xrn (keys(%{$item->{$action}})) {
					foreach(split(/ /,$self->{FuzzyDb_Lowercase}->{$xrn}->{lc($item->{$action}->{$xrn})})) {
						$mk{$_}++;
					}
					$ntm++;
				}
				foreach(sort {$a <=> $b} keys(%mk)) {
					$self->_AddToPlaylist(Name=>$name, Id=>$_) if $mk{$_} == $ntm;
				}
			}
			elsif($action eq "regex" || $action eq "iregex") {
				my $ntm;
				my %mk;
				foreach my $xrn (keys(%{$item->{$action}})) {
					$ntm++;
					my $regex = $item->{$action}->{$xrn};
					foreach my $val (keys(%{$self->{FuzzyDb_Normal}->{$xrn}})) {
						my $mval;
						if($val =~ /$regex/) {
							$mval = $val;
						}
						elsif($action eq "iregex" && $val =~ /$regex/i) {
							$mval = $val;
						}
						##get the keys
						foreach(split(/ /,$self->{FuzzyDb_Normal}->{$xrn}->{$mval})) {
							$mk{$_}++;
						}
					}
				}
				foreach(sort {$a <=> $b} keys(%mk)) {
					$self->_AddToPlaylist(Name=>$name, Id=>$_) if $mk{$_} == $ntm;
				}
			}
		}
		
	}
	
	
	#########################################################################
	# Sort given Playlist reference by Sortby
	sub SortPlaylist {
		my($self,%args) = @_;
		my $sortby   = lc($args{Sortby});  # How we are going to sort
		my $playlist = $args{Playlist};    # Playlist to use
		my $reverse  = 0;                  # Reverse sort? default is NO
		my %xidhash  = ();                 # Temp. Storage
		my %sortme   = ();                 # Temp. Storage
		my $sortsub  = sub {};             # Subroutine to use
		
		if($sortby =~ /reverse.(.+)/) {
			# magic keyword 'reverse' found -> enable reverse sort
			$sortby=$1;
			$reverse=1;
		}
		
		if($GNUpod::iTunesDB::SPLREDEF{field}{lc($sortby)}) {
			# -> Sort as INT
			$sortsub = sub { $a <=> $b }; #Num
			$sortsub = sub { $b <=> $a } if $reverse; #Reverse num
		}
		else {
			# -> Sort as STRING
			$sortsub = sub { uc($a) cmp uc($b)};              #String
			$sortsub = sub { uc($b) cmp uc($a)} if $reverse;  #Reversed String
		}
	
		%xidhash = map { $_ => 1} @{$playlist}; # Map id's into hash
		@$playlist = ();                        # ..and clear the reference
	
		# Search the fuzzydb
		foreach my $cmval (keys(%{$self->{FuzzyDb_Lowercase}->{$sortby}})) {
			foreach(split(/ /,$self->{FuzzyDb_Lowercase}->{$sortby}->{$cmval})) {
				next unless $xidhash{$_}; #Nope, we don't search for this
				delete($xidhash{$_});     #We found the item, delete it from here
				$sortme{$cmval} .= "$_ "; #Add it..
			}
		}
		
		# .. add them:
		foreach(sort $sortsub keys(%sortme)) {
			foreach(split(/ /,$sortme{$_})) {
				push(@$playlist,$_);
			}
		}
	
		#Maybe something didn't have a $sortby value?
		#We know them: Everything still in %xidhash..
		#-> Append them to the end (i think the beginning isn't good)
		foreach(keys(%xidhash)) {
			push(@$playlist,$_);
		}
	
		#No need to return anything.. We modify the hashref directly
	}
	
1;
