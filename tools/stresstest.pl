#!/usr/bin/perl

use strict;

my $to = $ARGV[0] or die "Usage: $0 TO > out.xml\n";

print << "EOF";
<?xml version='1.0' standalone='yes'?>
<gnuPod>
 <files>
EOF

for(0..$to) {
 print "<file id=\"$_\" title=\"bla $_\" path=\"undef\" />\n";
}


print << "FOE";
 </files>
</gnuPod>
FOE
