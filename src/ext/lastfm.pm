package GNUpod::lastfm;

use strict;
use Digest::MD5;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;

use constant SUBMISSION_SERVER => 'post.audioscrobbler.com:80';
use constant CLIENT_NAME => 'tst';
use constant CLIENT_BUILD=> 1;
use constant BATCHMAX => 8;



###################################################################
# All-in-one submission handler
sub dosubmission {
	my($h) = @_;
	my $user = $h->{user};
	my $pass = $h->{password};
	my $data = $h->{tosubmit};
	my $rq   = int(@$data);
	return undef if $rq < 1; #Nothing to submit, no login to do
	my $batches = _batcher($data,BATCHMAX);
	my $handshake_result = startlogin($user);
	if(defined $handshake_result->{ERROR}) {
		warn "! Login to last.fm for user '$user' failed. Response from server: $handshake_result->{ERROR}\n";
		return 1;
	}
	
	print "> last.fm: Handshake started, submitting data to last.fm service ...\n";
	
	my $naptime = int($handshake_result->{interval});
	
	foreach my $cdata (@$batches) {
		sleep($naptime);
		my $xpr = _xpost({postat=>$handshake_result->{postat}, user=>$user, password=>$pass, challenge=>$handshake_result->{challenge}, data=>$cdata});
		if($xpr->{" 0"} eq "OK") {
			$naptime = $xpr->{"INTERVAL"};
			print "> last.fm: Batch uploaded, next batch follows in $naptime seconds\n";
		}
		else {
			print "! last.fm: Failed.. aborting (Server error: ".$xpr->{" 0"}.")\n";
			return 2;
		}

	}
	return undef;
}


###################################################################
# Start Handshake to last.fm service
# Returns ERROR if we failed or
# {postat, interval, challenge} if everything was okay so far..
sub startlogin {
	my($username) = @_;
	my $r = _simple_http_get({server=>SUBMISSION_SERVER, path=>'/', args=>{hs=>'true', p=>1.1, c=>CLIENT_NAME, v=>CLIENT_BUILD, u=>$username}});

	if( (defined($r->{UPDATE}) or defined($r->{UPTODATE})) ) {
		return({postat=>$r->{" 2"}, interval=>$r->{"INTERVAL"}, challenge=>$r->{" 1"}});
	}
	else {
		return({ERROR=>($r->{" 0"} || '')});
	}
}

###################################################################
# Post data to last.fm service after the handshake completed.
sub _xpost {
	my($h) = @_;
	
	my $uri = $h->{postat};
	my $user = $h->{user};
	my $pass = $h->{password};
	my $chal = $h->{challenge};
	my $data = $h->{data};
	
	my $mdpwd  = Digest::MD5::md5_hex($pass);
	my $hashed = Digest::MD5::md5_hex($mdpwd.$chal);
	
	print "======== POST REQUEST TO $h->{postat} ($hashed)\n";
	
	my $postdata = "u="._ue($user)."&s="._ue($hashed);
	
	
	my $run = 0;
	my $mapping = { 'a' => 'artist', 't' => 'title', 'b' => 'album', 'm' => 'mbrainid', 'l' => 'length', 'i' => 'xplaydate' };
	foreach my $xhash (@$data) {
		foreach my $fmv (keys(%$mapping)) {
			my $value = $xhash->{$mapping->{$fmv}};
			$postdata .= "&".$fmv."[".int($run)."]="._ue($value)."";
		}
		$run++;
	}
	
	my $ua = LWP::UserAgent->new;
	$ua->agent("GNUpod/2006");
	my $req = HTTP::Request->new(POST => $h->{postat});
	$req->content_type('application/x-www-form-urlencoded');
	$req->content($postdata);
	
	my $res = $ua->request($req);
	
	my $resp = _fmparse($res->content);
	return $resp;

}

###################################################################
# HTTP-GET request, return _fmparse hash
sub _simple_http_get {
	my($h) = @_;

	#Assemble URL
	my $uri = $h->{path}."?";
	foreach(keys(%{$h->{args}})) {
		$uri.= $_."=".$h->{args}{$_}."&";
	}
	chop($uri); #Crop last & char
	
	my $uri = "http://".SUBMISSION_SERVER."/$uri";
	
	my $ua = LWP::UserAgent->new;
	   $ua->agent("GNUpod/2006");
	my $req = HTTP::Request->new(GET => $uri);
	my $res = $ua->request($req);
	my $fmh = _fmparse($res->content);
	return $fmh;
}

###################################################################
# Parse response from last.fm webserver and returns a hash
#
# An example:
#  => Response from server:
#
# FOO BAR
# ZORK
#
# => you'll get such a hash back:
# {'FOO' => 'BAR', ZORK => '', ' 1' => 'FOO', ' 2', => ZORK }
#
# The ' NUM' stuff is needed because the server sends non
# key\sval responses. (-> ZORK)
#
sub _fmparse {
	my($sock) = @_;
	my %ref = ();
	my $item = 0;
	foreach(split(/\n/,$sock)) {
		chomp($_);
			if(my($k,$v) = $_ =~ /^(\S+)(\s(.+))?$/) {
			$ref{$k} = $v;
			$ref{" ".$item++} = $k || "";
		}
	}
	return \%ref;
}

###################################################################
# urlencode an utf8 string
sub _ue {
	my($string) = @_;
	$string =~ s/([^0-9A-Za-z_ ])/'%'.unpack('H2',$1)/ge;
	$string =~ s/\s/+/g;
	return $string;
}

###################################################################
# Split arrayref into pieces
sub _batcher {
	my($source,$maxbatch) = @_;
	my $rq = int(@$source);
	my @ret = ();
	for(my $i = 0; $i < $rq; $i+= $maxbatch) {
		my $to = $i + $maxbatch -1;
		my $aref = ();
		for($i..$to) {
			my $ref = @$source[$_];
			next unless ref($ref) eq "HASH";
			push(@$aref, $ref);
		}
		push(@ret,$aref);
	}
	return \@ret;
}

###################################################################
# Dump stuff into FH
sub simple_lastfm_dump {
	my($fh, $ref) = @_;
	foreach my $r (@$ref) {
		foreach(keys(%$r)) {
			print $fh "$_\t$r->{$_}\n";
		}
		print $fh "\n";
	}
}

###################################################################
# Restore stuff from FH
sub simple_lastfm_restore {
	my($fh) = @_;
	my @ret = ();
	my $h   = ();
	while(<$fh>) {
		chomp($_);
		if($_ =~ /^$/) {
			push(@ret, $h);
			$h = ();
		}
		elsif($_ =~ /^([^\t]+)\t(.*)$/) {
			$h->{$1} = $2;
		}
		else {
			warn "Unhandled line: $_\n";
		}
	}
	return \@ret;
}



1;
