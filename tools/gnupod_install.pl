#!/usr/bin/perl -w

# We use your own install script because we need to 'fixup' the scrips
# before installing them (adding paths and maybe workarounds..)
# This script is licensed under the same terms as GNUpod (The GNU GPL v.2 or later...)
# <pab at blinkenlights.ch>

use strict; #of course :)

my %opts = ();
$opts{perlbin}      = $ARGV[0];
$opts{bindir}       = $ARGV[1];
$opts{infodir}      = $ARGV[2];
$opts{mandir}       = $ARGV[3];
$opts{skip_contrib} = $ARGV[4];

die "Expected 5 arguments, got ".int(@ARGV)."\n make will run me, not you! stupid human!" if !$opts{skip_contrib} || $ARGV[5];

#ok, we are still alive, let's blow up the system ;)
print "Installing GNUpod-base using gnupod_install 0.21\n";
install_scripts("../src/*.pl", $opts{bindir}, $opts{perlbin});

if($opts{skip_contrib} eq "no") {
print "Installing contrib\n";
install_scripts("../src/ext/*.pl", $opts{bindir}, $opts{perlbin});
install_pm("../src/ext/*.pm", $opts{perlbin});
}
install_docs("../doc/gnupod.info", $opts{infodir});

print "done!\n";






sub install_docs {
my($file, $infodir) = @_;
print "Installing documentation\n";
if(system("install-info --info-dir=$infodir $file")) {
 print "** install-info failed, documentation *NOT* installed\n";
 print "** See 'doc/gnupod.html' for an HTML version...\n";
}
else {

 ncp($file, $infodir."/".fof($file));
 print " Installed info file, use 'info gnupod' to read the documentation.\n";
}

}


# native (or naive? ;) ) copy
sub ncp {
my($source, $dest) = @_;

open(SOURCE, "$source") or die "Could not read $source: $!\n";
open(TARGET, ">$dest") or die "Could not write $dest: $!\n";
 while(<SOURCE>) {
  print TARGET $_;
 }
close(SOURCE); close(TARGET);
return undef;
}



sub install_pm {
my($glob, $perlbin) = @_;
my $file = undef;
die "Strange Perl installation, no \@INC! Can't install Perl-Module(s), killing myself..\n" if !$INC[0];
  foreach(glob($glob)) 
  {
   $file = fof($_);
    print "Installing $INC[0]/$file\n";
    ncp($_, "$INC[0]/$file");
    chmod 0444, "$INC[0]/$file";
    chown 0, 0, "$INC[0]/$file";
  }
}


sub install_scripts {
my ($glob, $dest, $perlbin) = @_;
my $file = undef;

 foreach(glob($glob)) 
 {
  $file = fof($_);
  print " writing $file\n";
  
   open(SOURCE, "$_") or die "Could not open $_: $!\n aborting installation\n";
   open(TARGET, ">$dest/$file") or die "Unable to write $dest/$file: $!\n aborting installation\n";
   print TARGET "\#!$perlbin\n";
   while(<SOURCE>) {
    print TARGET $_;
   }
   close(SOURCE); close(TARGET);
   #'fix' premissions...
   chmod 0755, "$dest/$file";
   # root shall be the owner (or whoever has uid/gid 0)
   chown 0, 0, "$dest/$file";
 }

}



sub fof
{
 my($path) = @_;
 my(@dull) = split(/\//, $path);
 return $dull[int(@dull)-1];
}
