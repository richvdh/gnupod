#!/usr/bin/perl -w

# We use your own install script because we need to 'fixup' the scrips
# before installing them (adding paths and maybe workarounds..)
# This script is licensed under the same terms as GNUpod (The GNU GPL v.2 or later...)
# <pab at blinkenlights.ch>

use strict; #of course :)

my %opts = ();
$opts{MODE}         = $ARGV[0];
$opts{perlbin}      = $ARGV[1];
$opts{bindir}       = $ARGV[2];
$opts{infodir}      = $ARGV[3];
$opts{mandir}       = $ARGV[4];

die "Expected 5 arguments, got ".int(@ARGV)."\n make will run me, not you! stupid human!" if !$opts{mandir} || $ARGV[5];
die "Strange Perl installation, no \@INC! Can't install Perl-Module(s), killing myself..\n" if !$INC[0];

if($opts{MODE} eq "INSTALL") {
 #ok, we are still alive, let's blow up the system ;)
 print "Installing GNUpod-base using gnupod_install 0.24\n";
 install_scripts("src/*.pl", $opts{bindir}, $opts{perlbin});
 install_pm("src/ext", "GNUpod", $opts{perlbin});
 install_docs("doc/gnupod.info", $opts{infodir});
 killold("$opts{bindir}/gnupod_delete.pl") if -e "$opts{bindir}/gnupod_delete.pl";
 print "done!\n";
}
elsif($opts{MODE} eq "REMOVE") {
 remove_scripts("src/*.pl", $opts{bindir});
 remove_pm("src/ext/*.pm", "GNUpod");
 remove_docs("gnupod", $opts{infodir});
}
else {
 die "Unknown mode: $opts{MODE}\n";
}



##########################
# Unlink files
sub killold {
 my($file) = @_;
 if(-e "$file") {
#  print "Unlinking $file\n";
   if(unlink("$file")) {
    print " done\n";
   }
   else {
    print " Could not remofe $file, $!\n";
   }
 }
 else {
  print " file $file did not exist\n";
 }
}

##########################
#Install Docs
sub install_docs {
my($file, $infodir) = @_;
print "Installing documentation\n";
if(system("install-info" ,"--info-dir=$infodir", $file)) {
 print "** install-info failed, documentation *NOT* installed\n";
 print "** See 'doc/gnupod.html' for an HTML version...\n";
}
else {

 ncp($file, $infodir."/".fof($file));
 print " Installed info file, use 'info gnupod' to read the documentation.\n";
}

}

##########################
#Uninstall docs
sub remove_docs {
 my($file, $infodir) = @_;
 print "Removing $file from $infodir\n";
 if(system("install-info", "--dir-file=$infodir/dir", "--delete",$file)) {
  print " > Could not remove documentation, maybe you didn't install the docs ;)\n";
 }
 else {
  print " > Removing stale infofile ";
  killold($infodir."/".$file.".info");
  print " > Documentation removed\n"; 
  
 }
}

##########################
#Uninstall scripts
sub remove_scripts {
 my($globme, $bindir) = @_;
 print "Removing GNUpod, please wait...\n";
 print " > Removing Scripts...\n";
 foreach (glob($globme)) {
  my $rmme = $bindir."/".fof($_);
  print "   -> Removing $rmme  ";
   killold($rmme);
 }
}

##########################
#Uninstall Modules
sub remove_pm {
 my($globme, $modi) = @_;
 print " > Removing Modules at $INC[0]/$modi\n";
 foreach (glob($globme)) {
  my $rmme = $INC[0]."/$modi/".fof($_);
  print "   -> Removing $rmme  ";
   killold($rmme);
 }
 rmdir($INC[0]."/$modi") or print "Could not remove $INC[0]/$modi: $!\n";
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

mkdir("$INC[0]/$modi", 0755);
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
