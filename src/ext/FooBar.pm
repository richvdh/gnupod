package GNUpod::FooBar;

sub connect {
 my($opth) = @_;
 my %h = %{$opth};
 
 my($mp, $itb, $xml) = undef;
 my $stat = "No mountpoint defined / missing in and out file";
 
unless(!$h{mount} && (!$h{itunes} || !$h{xml})) {
  $itb = $h{itunes} || $h{mount}."/iPod_Control/iTunes/iTunesDB";
  $xml = $h{xml} || $h{mount}."/iPod_Control/.gnupod/GNUtunesDB";
  $mp = $h{mount};
  $stat = undef;
}
 
 return ($stat, $itb, $xml, $mp);
}

1;
