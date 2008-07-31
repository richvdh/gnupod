#!/usr/bin/perl
use strict;

use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::ArtworkDB;
use Getopt::Long;
use Data::Dumper;

my %opts = ();
$opts{mount} = $ENV{IPOD_MOUNTPOINT};
GetOptions(\%opts, "version", "help|h", "mount|m=s", "outdir|o=s", "match=s", "unique|u");
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "extract_artwork");

usage()   if $opts{help};
usage()   if (length($opts{outdir}) == 0 || !(-d $opts{outdir}));
version() if $opts{version};


my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};
my $AWDB = GNUpod::ArtworkDB->new(Connection=>$connection, DropUnseen=>0);

$AWDB->LoadArtworkDb;
GNUpod::XMLhelper::doxml($connection->{xml}) or usage("Failed to parse $connection->{xml}, did you run gnupod_INIT.pl?\n");

#print Data::Dumper::Dumper($AWDB);


my %unique=();

sub newfile {
	my($el) = @_;
	
	if(exists($el->{file}->{dbid_1})) {
		my $awref = $AWDB->GetImage($el->{file}->{dbid_1});
		
		foreach my $awobj (@{$awref->{subimages}}) {
			if ($opts{unique} && defined ($unique{$awobj->{path}.$awobj->{offset}})) { 
				next;
			} else {
				$unique{$awobj->{path}.$awobj->{offset}}=1;
			}
			my $awdb_path = $connection->{artworkdir}.'/'.SaveName($awobj->{path});
			my $artist    = (SaveName($el->{file}->{artist}) || 'NoArtist');
			my $album     = (SaveName($el->{file}->{album}) || 'NoAlbum');
			my $title     = (SaveName($el->{file}->{title}) || 'NoTitle');
			my $xfile     = "$artist - $album - $title ($awobj->{width}x$awobj->{height}).bmp";
			my $outfile   = $opts{outdir}."/".$xfile;
			my $buff      = '';
			
			next if $xfile !~ /$opts{match}/gi;
			
			print "Extracting $awobj->{width}x$awobj->{height} version of $artist - $album - $title\n";
			open(ITHMB, "<", $awdb_path) or die "Unable to open $awdb_path: $!\n";
			binmode(ITHMB);
			seek(ITHMB,$awobj->{offset},0) or die "seek($awobj->{offset}) failed: $!\n";
			sysread(ITHMB,$buff,$awobj->{imgsize});
			close(ITHMB);
			
			my $rgb = GNUpod::ArtworkDB::RGB->new;
			$rgb->SetData(Data=>$buff, Height=>$awobj->{height}, Width=>$awobj->{width});
			my $bitmapdata = $rgb->RGB565ToBitmap;
			if ($opts{unique}) {
				use Digest::MD5;
				my $bitmaphash = Digest::MD5::md5_hex($bitmapdata);
				if (defined ($unique{$bitmaphash})) {
					print "Skipping due to MD5 hash.\n";
					next;
				} else {
					$unique{$bitmaphash}=1;
				}
			}
			open(OUT, ">", $outfile) or die "Unable to write to $outfile : $!\n";
			print OUT $bitmapdata;
			close(OUT);
		}
		
	}
}

sub newpl   {}


sub SaveName {
	my($in) = @_;
	$in =~ tr/A-Za-z0-9\._//cd;
	return $in;
}

###############################################################
# Display usage
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: extractArtwork.pl [-m directory] [-u] --outdir /path/to/outdir

   -h, --help              display this help and exit
   -u, --unique            Try to avoid exporting duplicate images.
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
       --match=regexp      Only extract if output filename matches regexp
   -o, --outdir=directory  Drop extracted images into given directory

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

###############################################################
# Display version
sub version {
die << "EOF";
extractArtwork.pl (gnupod) 20080107
Copyright (C) Adrian Ulrich 2008

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}


