package GNUpod::ArtworkDB;
use strict;
use GNUpod::iTunesDB;
use Carp;
use Digest::MD5;
use Data::Dumper;

use constant MAX_ITHMB_SIZE => 268435456; # Create new itumb file after reaching ~ 256 mb
	
	# Artwork profiles:
	my $profiles = { 'Nano_3G' => [ { height=>320, width=>320, dbi=>1060, bpp=>16, size=>204800 }, { height=>128, width=>128, dbi=>1055, bpp=>16, size=>32768 }, ],
	                 'Nano'    => [ { height=>100, width=>100, dbi=>1027, bpp=>16, size=>20000 },  { height=> 42, width=> 42, dbi=>1031, bpp=>16, size=>3528  }, ],
	                 'Video'   => [ { height=>200, width=>200, dbi=>1029, bpp=>16, size=>80000  }, { height=>100, width=>100, dbi=>1028, bpp=>16, size=>20000 }, ],
	               };

	####################################################################
	# Create new object and start parsing the ArtworkDB
	sub new {
		my($class,$con) = @_;
		
		my $self = { a_storages => [], storages => {}, a_images => [], images => {}, artworkdb => $con->{artworkdb}, artworkdir => $con->{artworkdir},
		             last_id_seen => 100, images_count => 0, ctx => '', _mhni_buff => {}, dirty=>1 };
		bless($self, $class);
		
		if(!(-d $self->{artworkdir}) && !mkdir($self->{artworkdir})) {
			warn "$0: Unable to create directory $self->{artworkdir} : $!\n";
			return undef;
		}
		
		open(AWDB, "<", $self->{artworkdb}) or return $self;
		my $obj = { offset => 0, childs => 1, fd=>*AWDB, awdb => 1,
		               callback => {
		                              PACKAGE=>$self, mhod => { item  => '_MhodItem'    },
		                                              mhii => { start => '_MhiiStart'  },
		                                              mhni => { start => '_MhniStart', },
		                            }
		          };
		GNUpod::iTunesDB::ParseiTunesDB($obj,0);
		$self->{dirty} = 0; # InMemory is the same as stored version
		close(AWDB);
		return $self;
	}
	
	
	sub InjectImage {
		my($self, $file) = @_;
		
		my $imgid   = '';
		my $srcsize = 0;
		
		open(TOHASH, "<", $file) or return undef;
		my $md5 = Digest::MD5->new;
		$md5->addfile(*TOHASH);
		$imgid   = substr($md5->hexdigest,0,16);
		$srcsize = tell(*TOHASH);
		close(TOHASH);
		
		
		if(!defined($self->GetImage($imgid))) {
			$self->RegisterNewImage(ref => {id=>0, dbid=>$imgid, source_size=>$srcsize});
			my $mode = $profiles->{'Nano_3G'};
			foreach my $mr (@$mode) {
				my $buff = '';
				open(IM, "-|") || exec("convert", "-resize", "$mr->{height}x$mr->{width}!",
				                         "-filter", "sinc", "-depth", 8, "--", $file, "RGB:-");
				while(<IM>) { $buff .= $_  }
				close(IM);
				
				my $conv = GNUpod::ArtworkDB::RGB->new;
				   $conv->SetData(Data=>$buff, Width=>$mr->{width}, Height=>$mr->{height});
				
				my $rgb565  = $conv->RGB888ToRGB565;
				my $outlen  = length($rgb565);
				
				if($mr->{size} != $outlen) {
					warn "$0: Could not inject $file to $mr->{height}x$mr->{width}: expected $mr->{size} bytes but got only $outlen bytes\n";
					next;
				}
				my $imgs = $self->StoreImage(Data=>$rgb565, Dbid=>$mr->{dbi});
				$self->RegisterSubImage(id=>$mr->{dbi}, imgsize=>$mr->{size}, path=>':'.$imgs->{filename}, offset=>$imgs->{start}, height=>$mr->{height}, width=>$mr->{width});
			}
		}
		else {
			print "$imgid did exist\n";
		}
		return $imgid;
	}
	
	
	
	####################################################################
	# Frees unused storage space, does NOT 'defrag' data
	sub CleanupIthumb {
		my($self) = @_;
		my $dir = $self->{artworkdir};
		foreach my $id ($self->GetStorageIds) {
		print "-> cleanup $id\n";
			while(my($fnam,$fsiz) = each(%{$self->GetStorage($id)->{ithmb}})) {
				my $fpath = $dir."/".substr($fnam,1); # kill's the :
				my @stat  = stat($fpath);
				print "Checking $fpath\n";
				if($fsiz == 0) {
					print "# unlink\n";
					unlink($fpath); # Don't bark if file doesn't exist
				}
				elsif($fsiz < $stat[7]) {
					print "# truncate\n";
					truncate($fpath,$fsiz); # Errors are non-fatal here
				}
			}
		}
	}
	
	sub WriteArtworkDb {
		my($self) = @_;
		
		my $tmp = $self->{artworkdb}."$$";
		my $dst = $self->{artworkdb};
		my $bak = $self->{artworkdb}.".old";
		
		open(AD, "+>", $tmp) or die "Unable to write $self->{artworkdb} : $!\n";
		my $fd = *AD;
		
		my $mhfd_fixup = tell($fd);
		print $fd GNUpod::iTunesDB::mk_mhfd({}); #
		my $mhfd_size = tell($fd);
		
		# -> Write out mhii's
		my $mhsd_mhii_fixup = tell($fd);
		print $fd GNUpod::iTunesDB::mk_mhsd({});
		my $mhsd_mhii_size  = tell($fd);
		
		print $fd GNUpod::iTunesDB::mk_mhxx({childs=>int($self->GetImageIds), name=>'mhli'});
		foreach my $imgid ($self->GetImageIds) {
			my $imgobj  = $self->GetImage($imgid);
			my $subimgs = $self->GetSubImages($imgobj);
			my $mhii_child_payload = '';
			foreach my $subref (@$subimgs) {
				$subref->{payload}  = GNUpod::iTunesDB::mk_awdb_mhod({type=>0x03, payload=>$subref->{path}});
				$subref->{childs}   = 1; # We will always write one child
				$mhii_child_payload .= GNUpod::iTunesDB::mk_awdb_mhod({type=>0x02, payload=>GNUpod::iTunesDB::mk_mhni($subref)});
			}
			print $fd GNUpod::iTunesDB::mk_mhii({dbid=>$imgobj->{dbid}, childs=>int(@$subimgs), payload=>$mhii_child_payload,
			                                     id=>$imgobj->{id}, rating=>$imgobj->{rating}, source_size=>$imgobj->{source_size}});
		}
		$mhsd_mhii_size = tell($fd)-$mhsd_mhii_size;
		
		# Unused mhsd with mhla child
		my $fake_mhla = GNUpod::iTunesDB::mk_mhxx({childs=>0, name=>'mhla'});
		print $fd GNUpod::iTunesDB::mk_mhsd({type=>0x02, size=>length($fake_mhla)});
		print $fd $fake_mhla;
		
		# Write out mhif's (= what image size to expect in storage)
		my $mhsd_mhif_fixup = tell($fd);
		print $fd GNUpod::iTunesDB::mk_mhsd({type=>0xff}); # Write a fake mhsd
		my $mhsd_mhif_size  = tell($fd);
		
		print $fd GNUpod::iTunesDB::mk_mhxx({childs=>int($self->GetStorageIds), name=>'mhlf'});
		foreach my $stid ($self->GetStorageIds) {
			print $fd GNUpod::iTunesDB::mk_mhif({childs=>0, payload=>'', id=>$stid, imgsize=>$self->GetStorage($stid)->{imgsize}});
		}
		$mhsd_mhif_size = tell($fd)-$mhsd_mhif_size;
		$mhfd_size      = tell($fd)-$mhfd_size;
		
		_Fixup($fd,$mhsd_mhif_fixup,GNUpod::iTunesDB::mk_mhsd({type=>0x03, size=>$mhsd_mhif_size}));
		_Fixup($fd,$mhsd_mhii_fixup,GNUpod::iTunesDB::mk_mhsd({type=>0x01, size=>$mhsd_mhii_size}));
		_Fixup($fd,0               ,GNUpod::iTunesDB::mk_mhfd({next_id=>$self->{last_id_seen}+1, childs=>0x03, size=>$mhfd_size}));
		close(AD);
		# We rename the file because otherwise we may mess up the artworkdb.. that would be bad.
		unlink($bak);      # may fail  -> no backup
		rename($dst,$bak); # may also fail -> no $dst
		rename($tmp,$dst) or die "Unable to move $tmp to $dst : $!\n";
	}
	
	
	sub StoreImage {
		my($self, %args) = @_;
		
		my $f_prefix = "F".$args{Dbid}."_";
		my $f_ext    = ".ithmb";
		my $fnam     = '';
		my $fpath    = '';
		my $start    = 0;
		my $end      = 0;
		for(my $i=1; $i<=500;$i++) {
			$fnam  = $f_prefix.$i.$f_ext;
			$fpath = $self->{artworkdir}."/$fnam";
			last if ((stat($fpath))[7]) < MAX_ITHMB_SIZE;
		}
		
		warn "# Writing to $fpath\n";
		
		open(ITHMB, ">>", $fpath) or die "Unable to write to $fpath : $!\n";
		$start = tell(ITHMB);
		print ITHMB $args{Data};
		$end   = tell(ITHMB);
		close(ITHMB);
		return({filename=>$fnam, start=>$start, end=>$end});
	}
	
	
	####################################################################
	# Registers a new ImageID
	sub RegisterNewImage {
		my($self, %args) = @_;
		my %h = %{$args{ref}};
		
		$h{id} ||= $self->{last_id_seen}+1;
		
		$self->{dirty}++;
		push(@{$self->{a_images}},$h{dbid}) if !exists($self->{images}->{$h{dbid}});
		$self->{images}->{$h{dbid}} = { dbid => $h{dbid}, source_size => $h{source_size}, id=>$h{id}, subimages => [] };
		$self->{ctx}                = $h{dbid}; # Set context
		$self->{images_count}++;                # Increment image count
		$self->{last_id_seen}       = $h{id} if $self->{last_id_seen} < $h{id};
	}
	
	####################################################################
	# Returns given image object
	sub GetImage {
		my($self, $id) = @_;
		return $self->{images}->{$id};
	}
	
	####################################################################
	# Returns all image ids
	sub GetImageIds {
		my($self) = @_;
		return @{$self->{a_images}};
	}
	
	####################################################################
	# Adds a new image version to the dbid
	sub RegisterSubImage {
		my($self, %args) = @_;
		$self->{dirty}++;
		push(@{$self->{images}->{$self->{ctx}}->{subimages}}, \%args);
		$self->RegisterStorage(id=>$args{id}, imgsize=>$args{imgsize}, path=>$args{path}, used=>$args{offset}+$args{imgsize});
	}
	
	####################################################################
	# Returns all subimages of image object
	sub GetSubImages {
		my($self,$obj) = @_;
		return $obj->{subimages};
	}

	####################################################################
	# 'Registers' a new storage chunk
	sub RegisterStorage {
		my($self, %args) = @_;
		unless(exists $self->{storages}->{$args{id}}) {
			$self->{storages}->{$args{id}} = { ithmb => {}, imgsize=>$args{imgsize} };
			push(@{$self->{a_storages}},$args{id});
		}
		
		my $itr = $self->{storages}->{$args{id}}->{ithmb};
		$itr->{$args{path}} = $args{used} if $args{used} >= $itr->{$args{path}};
		
	}

	####################################################################
	# Returns given storage object
	sub GetStorage {
		my($self,$id) = @_;
		return $self->{storages}->{$id};
	}
	
	####################################################################
	# Returns all known storage ids
	sub GetStorageIds {
		my($self) = @_;
		return @{$self->{a_storages}};
	}
	
	
	
	####################################################################
	# Handler for MHNIs
	sub _MhniStart {
		my($self, %args) = @_;
		# We will care about this on mhod-type-3
		$self->{_mhni_buff} = $args{ref}; 
	}
	
	####################################################################
	# Handler for mhii
	sub _MhiiStart {
		my($self, %args) = @_;
		$self->RegisterNewImage(%args);
	}
	
	####################################################################
	# Handler for mhods
	sub _MhodItem {
		my($self, %args) = @_;
		my %h = %{$args{ref}};
		if($h{type} == 0x03) {
			$self->{_mhni_buff}->{path} = $h{string};
			$self->RegisterSubImage(%{$self->{_mhni_buff}});
		}
	}






sub _Fixup {
	my($fd,$at,$string) = @_;
	my $now = tell($fd);
	seek($fd,$at,0) or die "Unable to seek to $at in $fd : $!\n";
	print $fd $string;
	seek($fd,$now,0) or die "Unable to seek to $now in $fd : $!\n";
}

1;

package GNUpod::ArtworkDB::RGB;
	use strict;
	
	use constant BMP_HEADERSIZE => 54;
	
	sub new {
		my($class,%args) = @_;
		my $self = { data => '', dimH => 0, dimW => 0};
		bless($self,$class);
		return $self;
	}
	
	sub SetData {
		my($self,%args) = @_;
		$self->{data} = $args{Data};
		$self->{dimW} = $args{Width};
		$self->{dimH} = $args{Height};
	}
	
	sub LoadFile {
		my($self,%args) = @_;
		my $buff = '';
		open(F, "<", $args{File}) or return undef;
		while(<F>) { $buff .= $_; }
		close(F);
		$self->SetData(Data=>$buff, Width=>$args{Width}, Height=>$args{Height});
	}
	
	sub RGB888ToRGB565 {
		my($self) = @_;
		
		my $size = length($self->{data});
		my $pixl = $self->{dimH} * $self->{dimW};
		my $bpp  = int($size/$pixl);
		my $out  = '';
		
		for(my $h = 0; $h < $self->{dimH}; $h++) {
			for(my $w = 0; $w < $self->{dimW}; $w++) {
				my $offset = (($h*$self->{dimW}) + $w)*$bpp;
				my @A = ();
				for(my $i=0; $i < $bpp; $i++) {
					$A[$i] = substr($self->{data},$offset+$i,1);
				}
				
				my $pa = substr(unpack("B*",$A[0]),0,5);
				my $pb = substr(unpack("B*",$A[1]),0,6);
				my $pc = substr(unpack("B*",$A[2]),0,5);
				
				$out .= pack("v",unpack("n",pack("B16", $pa.$pb.$pc)));
			}
		}
		return $out;
	}
	
	sub RGB565ToBitmap {
		my($self) = @_;
		my $size = length($self->{data});
		my $pixl = $self->{dimH} * $self->{dimW};
		my $bpp  = int($size/$pixl);
		my $out  = '';
		
		# Creates a fake bitmap header
		$out .= pack("H*", "424d");
		$out .= pack("V", BMP_HEADERSIZE+$pixl*3);
		$out .= pack("H*","00000000360000002800");
		$out .= pack("v", 0);
		$out .= pack("v", $self->{dimW});
		$out .= pack("v",0);
		$out .= pack("v", $self->{dimH});
		$out .= pack("H*", "0000010018000000");
		$out .= pack("H*", "0000c0d40100130b0000130b00000000000000000000");
		
		print "Data is $size bytes and has $pixl pixels: bpp : $bpp\n";
		
		for(my $h = $self->{dimH}; $h > 0; $h--) {
			my $line = '';
			for(my $w = 0; $w < $self->{dimW}; $w++) {
				my $buff = pack("v",unpack("n",substr($self->{data}, (($h*$self->{dimW})+$w)*$bpp,$bpp)));
				my $dump = unpack("B16",$buff);
				my $pa   = pack("B8",substr($dump,0,5));
				my $pb   = pack("B8",substr($dump,5,6));
				my $pc   = pack("B8",substr($dump,11,5));
				$line .= $pc.$pb.$pa;
			}
			$out .= $line;
		}
		return $out;
	}
	
1;
