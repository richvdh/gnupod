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

die "Expected 4 arguments, got ".int(@ARGV)."\n make will run me, not you! stupid human!" if !$opts{mandir} || $ARGV[5];

#ok, we are still alive, let's blow up the system ;)
print "Installing GNUpod-base using gnupod_install 0.23\n";

install_scripts("src/*.pl", $opts{bindir}, $opts{perlbin});
install_pm("src/ext", "GNUpod", $opts{perlbin});
install_docs("doc/gnupod.info", $opts{infodir});
killold("$opts{bindir}/gnupod_delete.pl");
print "done!\n";




sub killold {
 my($file) = @_;
 if(-x "$file") {
  print "Unlinking $file (obsolente)\n";
  unlink("$file") or warn "ERROR: Deleting $file failed: $!\n";
 }
}


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
my($basedir, $modi, $perlbin) = @_;
die "Strange Perl installation, no \@INC! Can't install Perl-Module(s), killing myself..\n" if !$INC[0];

mkdir("$INC[0]/$modi");
chmod 0755, "$INC[0]/$modi";
print "Installing Modules at $INC[0]/$modi\n";

 foreach my $file (glob("$basedir/*.pm")) {
  my $dest = "$INC[0]/$modi/".fof($file);
  print " > $file --> $dest\n";
  ncp($file, $dest);
  chmod 0444, $dest;
  chown 0, 0, $dest;
 }
}


sub install_scripts {
my ($glob, $dest, $perlbin) = @_;
my $file = undef;

 foreach(glob($glob)) 
 {
  $file = fof($_);
  print " > $_ --> $dest/$file\n";
  
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
