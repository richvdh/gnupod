#!/usr/bin/perl -w
# Do some tests to check if your GNUpod installation looks fine..

# This script is licensed under the same terms as GNUpod (The GNU GPL v.2 or later...)
# <pab at blinkenlights.ch>

use strict;

die "Don't call me like this!\n" if !$ARGV[0];

print "Starting basic tests..\n";
testscripts($ARGV[0]);
print "No tests.. this is just a dummy script\n";
cleanup();


sub testscripts {
 my($perlbin) = @_;
 die "** Your perl isn't useable..!\n" if system("$perlbin -e \"exit(0);\" 2> /dev/null");
 
 my $id = $$.int(rand(3333));
 my $testdir = "/tmp/GNUpod_TEST_$id"; 
 
 print "Using $testdir..\n";
 die "** Failed to create testdir: $!\n" if system("mkdir $testdir 2> /dev/null");
 
 
}



sub cleanup {
 my($testdir) = @_;
 die "** Could not unlink $testdir..\n" if system("rmdir $testdir 2> /dev/null");
 print "Unlinked $testdir\n";
}
