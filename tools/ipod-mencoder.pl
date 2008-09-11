#!/usr/bin/perl
use strict;
use Getopt::Long;

# ffmpeg with divx:
# ffmpeg -i input  -s 320x240 -vcodec mpeg4 -vtag XVID -b 500kb -mbd rd -flags +4mv+trell+aic -cmp 2 -subcmp 2 -g 300 -r 29.97 -acodec copy -ac 2 -async 1 out.avi

my %opts = ();

GetOptions(\%opts, "out|o=s", "aid=i", "sid=i", "rate=i", "divx");
$opts{rate} ||= 1250;



if(!defined($opts{out}) or !(-d $opts{out})) {
	die "Usage: $0 --out=outdir [--aid 0 --sid 0 --rate 500] [--divx]\n";
}

my @ITEMS = ();
if(int(@ARGV) == 1 && $ARGV[0] eq '-') {
	while(<STDIN>) { chomp; push(@ITEMS,$_); }
}
else {
	@ITEMS = @ARGV;
}

foreach my $cfile (@ITEMS) {
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
	
	if($opts{divx}) {
		#well...
		my $xout = substr($args->{output},0,-3)."avi";
		@cmdline = ("mencoder", $args->{input}, "-oac", "mp3lame", "-ovc", "lavc", "-lavcopts",
	               "vcodec=mpeg4:v4mv:mbd=2:trell:aic=2:cmp=2:subcmp=2:vbitrate=$args->{vbitrate}",
	               "-vf", "scale=320:240", "-lameopts", "vbr=3",
	               "-o", $xout);
	}
	
	push(@cmdline, ("-aid", $args->{aid})) if defined($args->{aid});
	push(@cmdline, ("-sid", $args->{sid})) if defined($args->{sid});
	return @cmdline;
}

