#!/usr/bin/perl
use strict;
use Getopt::Long;


my %opts = ();

GetOptions(\%opts, "out|o=s", "aid=i", "sid=i", "rate=i");
$opts{rate} ||= 1250;



if(!defined($opts{out}) or !(-d $opts{out})) {
	die "Usage: $0 --out=outdir [--aid 0 --sid 0 --rate 500]\n";
}

foreach my $cfile (@ARGV) {
	my $outfile = get_outfile($cfile);
	print "Transcoding $cfile -> $outfile\n";
	if(-e $outfile) {
		warn "Skipping $outfile: file does exist\n";
		next;
	}
	
	system(transcode({input=>$cfile, output=>$outfile, vbitrate=>$opts{rate}, aid=>$opts{aid}, sid=>$opts{sid}}));
	
}


###################################################
# Create output filename
sub get_outfile {
	my($string) = @_;
	my ($out) = $string =~ /([^\/]+)\.([^\.]+)$/;
	$out ||= int(rand(0xFFFF)).int(time());
	$out .= ".m4v";
	return $opts{out}."/".$out;
}


sub transcode {
	my($args) = @_;
	
	my @cmdline = ("mencoder", $args->{input}, "-oac", "lavc", "-ovc", "lavc", "-lavcopts",
	               "vcodec=mpeg4:v4mv:mbd=2:trell:aic=2:cmp=2:subcmp=2:acodec=aac:vglobal=1:aglobal=1:vbitrate=$args->{vbitrate}:abitrate=128",
	               "-vf", "scale=320:-3", "-of", "lavf", "-lavfopts", "i_certify_that_my_video_stream_does_not_use_b_frames:format=mp4",
	               "-o", $args->{output});
	push(@cmdline, ("-aid", $args->{aid})) if defined($args->{aid});
	push(@cmdline, ("-sid", $args->{sid})) if defined($args->{sid});
	return @cmdline;
}

