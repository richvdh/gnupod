

# gnupod-utils: utilities for GnuPod tunes database
# Copyright (C) 2002  Eric C. Cooper <ecc@cmu.edu>
# Released under the GNU General Public License
# Some changes mady by Adrian Ulrich

use strict;
use iPod;
use Getopt::Mixed qw(nextOption);

my %opt = ();
$opt{m} = $ENV{IPOD_MOUNTPOINT}; #defaulting


Getopt::Mixed::init("mount=s m>mount help h>help");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opt{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();


if (!$opt{m} || $opt{h}) {
print "Usage: $0 [h] [-m directory]\n";
print "Renumber (cleanup) GnuPod tunes database.\n\n";
print "  -m, --mount  : iPod mountpoint, default is \$IPOD_MOUNTPOINT\n";
print "  -h, --help   : print this summary and exit\n";
exit(1);
}
iPod::read_xml("$opt{m}/iPod_Control/.gnupod/GNUtunesDB");

my %renumber = ();

# renumber songs

my $n = 1;
for my $s (@{$iPod::songs}) {
    $renumber{$s->{id}} = $n;
    $s->{id} = $n;
    $n++;
}

# renumber playlist entries

for my $p (@{$iPod::playlists}) {
    for my $e (@{$p->{add}}) {
	my $old_id = $e->{id};
	next unless defined $old_id;
	my $new_id = $renumber{$old_id};
	unless (defined $new_id) {
	    my $name = $p->{name};
	    die "$0: non-existent entry $old_id in playlist '$name'\n";
	}
	$e->{id} = $new_id;
    }
}

iPod::write_xml();
