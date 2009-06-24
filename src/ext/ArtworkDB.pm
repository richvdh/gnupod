package GNUpod::ArtworkDB;
#  Copyright (C) 2007 Adrian Ulrich <pab at blinkenlights.ch>
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
#    along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use GNUpod::iTunesDB;
use Carp;
use Digest::MD5;
use Data::Dumper;

use constant MAX_ITHMB_SIZE => 268435456; # Create new itumb file after reaching ~ 256 mb
use constant SHARED_STORAGE => 1;         # Share same offset across multiple items, this breaks iTunes but who cares?!

use constant MODE_UNPARSED  => 100;
use constant MODE_PARSING   => 200;
use constant MODE_PARSED    => 300;

	# Artwork profiles:
	my $profiles = { 'nano_4g' => [ { height=>128, width=>128, storage_id=>1055, bpp=>16,  }, { height=>128, width=>128, storage_id=>1068, bpp=>16,  },
	                                { height=>240, width=>240, storage_id=>1071, bpp=>16,  }, { height=>50,  width=>50,  storage_id=>1074, bpp=>16,  },
	                                { height=>80,  width=>80,  storage_id=>1078, bpp=>16,  }, { height=>240, width=>240, storage_id=>1084, bpp=>16,  },  ],
	                 'nano_3g' => [ { height=>320, width=>320, storage_id=>1060, bpp=>16,  }, { height=>128, width=>128, storage_id=>1055, bpp=>16,  },
	                                { height=>56,  width=>56,  storage_id=>1061, bpp=>16, drop=>112}                                                     ],
	                 'classic' => [ { height=>320, width=>320, storage_id=>1060, bpp=>16,  },  { height=>128, width=>128, storage_id=>1055, bpp=>16, },
	                                { height=>56,  width=>56,  storage_id=>1061, bpp=>16, drop=>112}                                                     ],
	                 'nano'    => [ { height=>100, width=>100, storage_id=>1027, bpp=>16,  },  { height=> 42, width=> 42, storage_id=>1031, bpp=>16, },  ],
	                 'video'   => [ { height=>200, width=>200, storage_id=>1029, bpp=>16,  },  { height=>100, width=>100, storage_id=>1028, bpp=>16,  }, ],
	               };

	####################################################################
	# Create new object
	sub new {
		my($class,%args) = @_;
		
		my $self = { storages => {},  images => {},        fbimg => {},         _mhni_buff => {}, drop_unseen => $args{DropUnseen},
		             db_dirty => 0,   last_id_seen => 100, last_dbid_seen => 0, ctx => undef, storagecache => {}, mode => MODE_UNPARSED,
		             artworkdb => $args{Connection}->{artworkdb}, artworkdir => $args{Connection}->{artworkdir},
		           };
		bless($self, $class);
		return $self;
	}
	
	
	
	####################################################################
	# Starts parsing the database and creates internal structure
	sub LoadArtworkDb {
		my($self) = @_;
		if(!(-d $self->{artworkdir}) && !mkdir($self->{artworkdir})) {
			warn "$0: Unable to create directory $self->{artworkdir} : $!\n";
			return undef;
		}
		
		unless (open(AWDB, "<", $self->{artworkdb}) ) {
			$self->{mode} = MODE_PARSED; # Fake
			return $self;
		}
		
		binmode(AWDB);
		
		my $obj = { offset => 0, childs => 1, fd=>*AWDB, awdb => 1,
		               callback => {
		                              PACKAGE=>$self, mhod => { item  => '_MhodItem'  },
		                                              mhii => { start => '_MhiiStart' },
		                                              mhni => { start => '_MhniStart' },
		                            }
		          };
		
		$self->{mode} = MODE_PARSING;
		GNUpod::iTunesDB::ParseiTunesDB($obj,0);
		$self->{mode} = MODE_PARSED;
		
		#my $foo = delete($self->{fbimg});
		#print Data::Dumper::Dumper($self);
		#$self->{fbimg} = $foo;
		
		close(AWDB);
		return $self;
	}
	
	sub KeepImage {
		my($self,$id) = @_;
		my $u64 = GNUpod::Ugly64->new($id);
		my $clean_id = $u64->GetHex;
		if(exists($self->{images}->{$clean_id})) {
			$self->{images}->{$clean_id}->{seen}++;
		}
	}
	
	sub _WipeLostImages {
		my($self) = @_;
		if($self->{drop_unseen}) {
			foreach my $id ($self->_GetImageIds) {
				if($self->GetImage($id)->{seen} == 0) {
					$self->_DeleteImage($id) or die "Failed to delete image # $id : Did not exist in db?!\n";
					$self->{db_dirty}++;
				}
			}
		}
	}
	
	####################################################################
	# Returns next (unseen) dbid
	sub GetNextDbid {
		my($self) = @_;
		my $dbid = GNUpod::Ugly64->new($self->{last_dbid_seen})->Increment->GetHex;
		my $lids = $self->_RegisterDbid($dbid);
		Carp::confess("Assert $dbid eq $lids failed") if $dbid ne $lids;
		return $dbid;
	}
	
	####################################################################
	# Mark id as seen
	sub _RegisterDbid {
		my($self,$dbid) = @_;
		$self->{last_dbid_seen} = $dbid unless GNUpod::Ugly64->new($dbid)->ThisIsBigger($self->{last_dbid_seen});
		return $self->{last_dbid_seen};
	}
	
	####################################################################
	# Really write an image into the storage and register it
	sub InjectImage {
		my($self) = @_;
		Carp::confess("InjectImage($self) called in wrong mode: $self->{mode}") if $self->{mode} != MODE_PARSED;
		my $imgid = $self->GetNextDbid;  # Get next, free id
		$self->_RegisterNewImage(ref => { id=> 0, dbid=>$imgid, source_size=>$self->{fbimg}->{source_size} });
		$self->KeepImage($imgid);
		foreach my $fbimg (@{$self->{fbimg}->{cache}}) {
			my $dbinfo = undef;
			if(SHARED_STORAGE && defined($self->{storagecache}->{$fbimg->{storage_id}})) {
				$dbinfo = $self->{storagecache}->{$fbimg->{storage_id}};
			}
			else {
				$dbinfo = $self->_WriteImageToDatabase(Data=>$fbimg->{data}, StorageId=>$fbimg->{storage_id});
				$self->{storagecache}->{$fbimg->{storage_id}} = $dbinfo;
			}
			$self->_RegisterSubImage(storage_id=>$fbimg->{storage_id}, imgsize=>$fbimg->{imgsize}, path=>':'.$dbinfo->{filename}, offset=>$dbinfo->{start},
			                         height=>$fbimg->{height}, width=>$fbimg->{width});
		}
		$self->{db_dirty}++;
		return $imgid;
	}
	
	
	####################################################################
	# Converts given image and caches the result
	sub PrepareImage {
		my($self,%args) = @_;
		Carp::confess("PrepareImage($self) called in wrong mode: $self->{mode}") if $self->{mode} != MODE_UNPARSED;
		my $file   = $args{File};
		my $model  = lc($args{Model});
		   $model  =~ tr/a-z0-9_//cd; # relax
		my $mode   = $profiles->{$model} || $profiles->{video};  # select model or use the default (video)
		my $count  = 0;
		$self->{fbimg}->{source_size} = (-s $file) or return 0; # no thanks
		foreach my $mr (@$mode) {
			my $buff = '';
			open(IM, "-|") || exec("convert", "-resize", "$mr->{height}x$mr->{width}", "-background","white","-gravity","center","-extent","$mr->{height}x$mr->{width}", "-depth", "8", $file, "RGB:-");
			binmode(IM);
			while(<IM>) { $buff .= $_  }
			close(IM);
			
			my $conv = GNUpod::ArtworkDB::RGB->new;
			   $conv->SetData(Data=>$buff, Width=>$mr->{width}, Height=>$mr->{height});
			my $size    = ($mr->{height}*$mr->{width}*$mr->{bpp}/8)-$mr->{drop};
			my $rgb565  = substr($conv->RGB888ToRGB565,0,$size);
			my $outlen  = length($rgb565);
			if( $size != $outlen) {
				warn "$0: Could not convert $file to $mr->{height}x$mr->{width}: image should be $size bytes but imagemagick provided $outlen bytes.\n";
				next;
			}
			push(@{$self->{fbimg}->{cache}}, { data => $rgb565, storage_id=>$mr->{storage_id}, imgsize=>$size, height=>$mr->{height}, width=>$mr->{width}, store=>undef} );
			$count++;
		}
		return $count;
	}
	
	
	####################################################################
	# Injects image into ithmb file
	sub _WriteImageToDatabase {
		my($self, %args) = @_;
		Carp::confess("_WriteImageToDatabase($self) called in wrong mode: $self->{mode}") if $self->{mode} != MODE_PARSED;
		my $f_prefix = "F".$args{StorageId}."_"; # Database prefix
		my $f_ext    = ".ithmb";            # Extension
		my $fnam     = '';                  # Holds filename, such as F1006_1.ithmb
		my $fpath    = '';                  # Full path
		my $end      = 0;                   # End of write
		my $start    = ($self->{storages}->{$args{StorageId}}->{last_offset_used} || 0); # Offset we are going to write
		my $i        = ($self->{storages}->{$args{StorageId}}->{last_index_used}  || 1); # Image-Id index (F????_X.ithmb)
		my $len      = length($args{Data}) or Carp::confess("Datalen cannot be null");
		
#		print "-> $args{StorageId} ; starting at $start \@ $i\n";
		for( ; ; $start += $len) {
			$fnam  = $f_prefix.$i.$f_ext;
			if($self->{storages}->{$args{StorageId}}->{ithmb}->{":".$fnam}->{$start} == 0) {
#				print "$fnam : Writing $len bytes \@ $start\n";
				last;
			}
			elsif($start >= MAX_ITHMB_SIZE) {
				$start = -1*$len; # uargs
				$i++;
			}
		}
		
		$self->{storages}->{$args{StorageId}}->{last_index_used}  = $i;
		$self->{storages}->{$args{StorageId}}->{last_offset_used} = $start;
		
		$fpath = $self->{artworkdir}."/".$fnam;
		
		if(! open(ITHMB, "+<", $fpath) ) {
			open(ITHMB, ">", $fpath) or die "Unable to write to $fpath : $!\n";
		}
		binmode(ITHMB);
		seek(ITHMB,$start,0) or die "Unable to seek to $start at $fnam\n";
		print ITHMB $args{Data};
		$end   = tell(ITHMB);
		close(ITHMB);
		return({filename=>$fnam, start=>$start, end=>$end});
	}
	

	
	sub WriteArtworkDb {
		my($self) = @_;
		
		
		$self->_WipeLostImages;
		return undef if $self->{db_dirty} == 0;
		
		# We shouldn't get here with unparsed data
		Carp::confess("WriteArtworkDb($self) called in wrong mode: $self->{mode}") if $self->{mode} != MODE_PARSED;
		
		print "> Updating ArtworkDB\n";
		
		my $tmp = $self->{artworkdb}."$$";
		my $dst = $self->{artworkdb};
		my $bak = $self->{artworkdb}.".old";
		
		open(AD, "+>", $tmp) or die "Unable to write $self->{artworkdb} : $!\n";
		binmode(AD);
		my $fd = *AD;
		
		my $mhfd_fixup = tell($fd);
		print $fd GNUpod::iTunesDB::mk_mhfd({}); #
		my $mhfd_size = tell($fd);
		
		# -> Write out mhii's
		my $mhsd_mhii_fixup = tell($fd);
		print $fd GNUpod::iTunesDB::mk_mhsd({});
		my $mhsd_mhii_size  = tell($fd);
		
		print $fd GNUpod::iTunesDB::mk_mhxx({childs=>int($self->_GetImageIds), name=>'mhli'});
		foreach my $imgid ($self->_GetImageIds) {
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
		
		GNUpod::FooBar::SeekFix($fd,$mhsd_mhif_fixup,GNUpod::iTunesDB::mk_mhsd({type=>0x03, size=>$mhsd_mhif_size}));
		GNUpod::FooBar::SeekFix($fd,$mhsd_mhii_fixup,GNUpod::iTunesDB::mk_mhsd({type=>0x01, size=>$mhsd_mhii_size}));
		GNUpod::FooBar::SeekFix($fd,0               ,GNUpod::iTunesDB::mk_mhfd({next_id=>$self->{last_id_seen}+1, childs=>0x03, size=>$mhfd_size}));
		close(AD) or die "Failed to close filehandle of $tmp : $!\n";
		# We rename the file because otherwise we may mess up the artworkdb.. that would be bad.
		unlink($bak);      # may fail  -> no backup
		rename($dst,$bak); # may also fail -> no $dst
		rename($tmp,$dst) or die "Unable to move $tmp to $dst : $!\n";
	}
	
	
	
	####################################################################
	# Registers a new ImageID
	sub _RegisterNewImage {
		my($self, %args) = @_;
		my %h = %{$args{ref}};
		Carp::confess("_RegisterNewImage($self) called in wrong mode: $self->{mode}") if $self->{mode} == MODE_UNPARSED;
		$self->{ctx} = undef;
		
		if($self->{images}->{$h{dbid}}) {
			warn "$0: $h{dbid} is registered, looks like your ArtworkDB is corrupted?!\n";
		}
		else {
			$h{id} ||= $self->{last_id_seen}+1;     # Create new id if none specified
			$self->{images}->{$h{dbid}} = { dbid => $h{dbid}, source_size => $h{source_size}, id=>$h{id}, subimages => [], seen=>0 };
			$self->{ctx}                = $h{dbid}; # Set context
			$self->{last_id_seen}       = $h{id}       if     $self->{last_id_seen} < $h{id};                                       # Remember latest id we saw
			$self->_RegisterDbid($h{dbid}); # 'Register' ID
		}
	}
	
	####################################################################
	# Returns given image object
	sub GetImage {
		my($self, $id) = @_;
		return $self->{images}->{$id};
	}
	
	sub _DeleteImage {
		my($self,$id) = @_;
		return delete($self->{images}->{$id});
	}
	
	####################################################################
	# Returns all image ids
	sub _GetImageIds {
		my($self) = @_;
		return keys(%{$self->{images}});
	}
	
	####################################################################
	# Adds a new image version to the dbid
	sub _RegisterSubImage {
		my($self, %args) = @_;
		if(defined($self->{ctx})) {
			push(@{$self->{images}->{$self->{ctx}}->{subimages}}, \%args);
			$self->RegisterStorage(storage_id=>$args{storage_id}, imgsize=>$args{imgsize}, path=>$args{path}, used=>$args{offset});
		}
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
		unless(exists $self->{storages}->{$args{storage_id}}) {
			$self->{storages}->{$args{storage_id}} = { ithmb => {}, imgsize=>$args{imgsize} };
		}
		
		my $itr = $self->{storages}->{$args{storage_id}}->{ithmb};
		$itr->{$args{path}}->{$args{used}} += 1;            # Mark this beginning block as used
		
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
		return keys(%{$self->{storages}});
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
		$self->_RegisterNewImage(%args);
	}
	
	####################################################################
	# Handler for mhods
	sub _MhodItem {
		my($self, %args) = @_;
		my %h = %{$args{ref}};
		if($h{type} == 0x03) {
			$self->{_mhni_buff}->{path} = $h{string};
			$self->_RegisterSubImage(%{$self->{_mhni_buff}});
		}
	}


1;

####################################################################
# Ugly pseudo-64bit hack
package GNUpod::Ugly64;
	use constant U64_OVERFLOW => 0xFFFFFFFF;
	use constant U64_LOWEST   => 0x00000000;
	
	sub new {
		my($class, $num) = @_;
		my $self = { };
		bless($self,$class);
		$self->{num} = $self->_voodoo($num);
		return $self;
	}
	
	sub _voodoo {
		my($self,$hex) = @_;
		my $hex = (pack("H16",$hex));
		my $a = unpack("V",substr($hex,0,4));
		my $b = unpack("V",substr($hex,4,4));
		return([$a,$b]);
	}
	
	sub GetHex {
		my($self) = @_;
		return unpack("H8",pack("V",$self->{num}->[0])).unpack("H8",pack("V",$self->{num}->[1]));
	}
	
	sub ThisIsBigger {
		my($self,$this) = @_;
		my $a_this = $self->_voodoo($this);
		for(my $i = 1; $i >= 0; $i--) {
			return 1 if $a_this->[$i] > $self->{num}->[$i];
			return 0 if $a_this->[$i] < $self->{num}->[$i];
		}
		return 0; # ==
	}
	
	sub Increment {
		my($self) = @_;
		my $roll = 0;
		if($self->{num}->[0] == U64_OVERFLOW) {
			$self->{num}->[0] = 0;
			$roll             = 1;
		}
		else {
			$self->{num}->[0]++;
		}
		
		if($roll && $self->{num}->[1] == U64_OVERFLOW) {
			warn "$0: 64-bit integer overflowed, returning zero\n";
			$self->{num} = [U64_LOWEST, U64_LOWEST];
		}
		elsif($roll) {
			$self->{num}->[1]++;
		}
		return $self;
	}

1;


package GNUpod::ArtworkDB::RGB;
	use strict;
	
	use constant BMP_HEADERSIZE => 54;
	use constant R565_B_R       => 5;
	use constant R565_B_G       => 6;
	use constant R565_B_B       => 5;
	use constant R565_BYTE      => 8;
	use constant R565_B_T       => R565_BYTE*2;

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
		binmode(F);
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
				my @A      = ();
				for(my $i=0; $i < $bpp; $i++) {
					$A[$i] = unpack("C",substr($self->{data},$offset+$i,1));
				}
				
				$A[0] >>= R565_BYTE - R565_B_R;                        # Drop 3 bits
				$A[1] >>= R565_BYTE - R565_B_G;                        # Drop 2 bits
				$A[2] >>= R565_BYTE - R565_B_B;                        # Drop 3 bits
				$A[0] <<= (R565_B_T - R565_B_R                      );
				$A[1] <<= (R565_B_T - R565_B_R - R565_B_G           );
				$A[2] <<= (R565_B_T - R565_B_R - R565_B_G - R565_B_B);
				$out .= pack("v" , ($A[0] | $A[1] | $A[2] ));
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
