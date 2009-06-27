#!/usr/bin/perl -w

# We use your own install script because we need to 'fixup' the scrips
# before installing them (adding paths and maybe workarounds..)
# This script is licensed under the same terms as GNUpod (The GNU GPL v.2 or later...)
# <pab at blinkenlights.ch>

use strict; #of course :)

my %opts = ();

my $DST             = $ARGV[6] || "/";  #DESTDIR
$opts{MODE}         = $ARGV[0];  #INSTALL MKPGK or REMOVE
$opts{perlbin}      = $ARGV[1];  #Path to perl
$opts{podmanbin}    = $ARGV[2];  #Path to perldoc
$opts{bindir}       = $ARGV[3];  #Bindir
$opts{infodir}      = $ARGV[4];  #Infodir
$opts{mandir}       = $ARGV[5];  #Mandir


my $VINSTALL = `cat .gnupod_version`; #Version of this release

#Check if everything looks okay..
die "File .gnupod_version does not exist, did you run configure?\n" unless $VINSTALL;
die "Expected 5 arguments, got ".int(@ARGV)."\n make will run me, not you! stupid human!" if !$opts{mandir} || $ARGV[7];
die "Strange Perl installation, no \@INC! Can't install Perl-Module(s), killing myself..\n" if !$INC[0];

if($opts{MODE} eq "INSTALL") {
 #ok, we are still alive, let's blow up the system ;)
 print "Installing GNUpod $VINSTALL using gnupod_install 0.26\n";
 install_scripts("build/bin/*.pl", $DST.$opts{bindir});
 install_pm("build/bin/GNUpod", "GNUpod", $opts{perlbin}, $DST);
 install_man("build/man/*.gz", $DST.$opts{mandir}."/man1");
 install_info("build/info/gnupod.info", $DST.$opts{infodir});
 print "done!\n";
}
elsif($opts{MODE} eq "BUILD") {
 print "Building GNUpod $VINSTALL...\n";
 install_scripts("src/*.pl", "build/bin");
 install_scripts("src/ext/*.pm", "build/bin/GNUpod");
 extract_man("build/bin/*.pl", "build/man");
 install_scripts("doc/gnupod.info", "build/info");
}
elsif($opts{MODE} eq "REMOVE") {
 print "Removing GNUpod $VINSTALL...\n";
 remove_scripts("build/bin/*.pl", $opts{bindir});
 remove_pm("build/bin/GNUpod/*.pm", "GNUpod");
 remove_mandocs("build/man/*.gz", $opts{mandir}."/man1");
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
    print " Could not remove $file, $!\n";
   }
 }
 else {
  print " file $file did not exist\n";
 }
}

##########################
#Install Docs
sub install_info {
my($file, $infodir) = @_;

$infodir = _recmkdir($infodir);#create info directory
print "Installing info-documentation ($infodir)\n";
if(system("install-info" ,"--info-dir=$infodir", $file)) {
 print "** install-info failed, documentation *NOT* installed\n";
 print "** See 'doc/gnupod.html' for an HTML version...\n";
}
else {

 ncp($file, $infodir."/".fof($file));
 print " Installed info file, use 'info gnupod' to read the documentation.\n";
}

}

###################################
# extract man pages from perldoc
sub extract_man {
 my($glob, $dest) = @_;
 foreach(glob($glob)) 
 {
  my $file = fof($_);
  print " > $_ --> $dest/$file.1\n";
   # here and now generate man pages from the ncp'ed scripts
   # and put them into our own man dir so they get copied later
   system($opts{podmanbin}, "--center", "User commands" , "$_", "$dest/$file.1");
   #or die("Failed to create man pages from script $file."); 
 }

}

######################################
# Install manual pages
sub install_man {
 my($glob, $dest) = @_;
 my $file = undef;
 print "Installing manual pages\n";
 foreach(glob($glob)) {
  $file = fof($_);
  my $destfile = "$dest/$file";
  print " > $_ --> $destfile\n";
  ncp($_, $destfile);
  chmod 0644, $destfile;
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


sub remove_mandocs {
 my($glob, $mandir) = @_;
 
 foreach(glob($glob)) {
  my $file = fof($_);
  my $xkill = "$mandir/$file";
  print "   -> Removing $xkill  ";
  killold($xkill);
 }
 print " > Manualpages removed\n";
}

##########################
#Uninstall scripts
sub remove_scripts {
 my($globme, $bindir) = @_;
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
  $_ =~ s/###__PERLBIN__###/#!$opts{perlbin}/;
  $_ =~ s/###__VERSION__###/$VINSTALL/;
  if (/^###___PODINSERT (.*?)___###/) {
   open(INSERT, "$1") or die "Could not read podinsert $1: $!\n";
   while (<INSERT>) {
    print TARGET $_;
   }
  } else {
   print TARGET $_;
  }
 }
close(SOURCE); close(TARGET);
return undef;
}


########################################################
# Install Perl modules
sub install_pm {
my($basedir, $modi, $perlbin, $pfix) = @_;

my $fullINCdir = "$pfix"."$INC[0]/$modi";
my $stepINC    = _recmkdir($fullINCdir);

print "Installing Modules at $stepINC\n";

 foreach my $file (glob("$basedir/*.pm")) {
  my $dest = $stepINC.fof($file);
  print " > $file --> $dest\n";
  ncp($file, $dest);
  chmod 0444, $dest; #Try to chown and chmod .. root should be owner of this modules..
  chown 0, 0, $dest;
 }
}

########################################################
# Install source from src/*
sub install_scripts {
 my ($glob, $dest) = @_;
 my $file = undef;

 foreach(glob($glob)) 
 {
  $file = fof($_);
  print " > $_ --> $dest/$file\n";
   ncp($_,"$dest/$file");
   #'fix' premissions...
   chmod 0755, "$dest/$file";
   #Try to chown 0:0 .. just try
   chown 0, 0, "$dest/$file";
 }

}



sub fof
{
 my($path) = @_;
 my(@dull) = split(/\//, $path);
 return $dull[int(@dull)-1];
}

sub _recmkdir {
	my($dir) = @_;
	my $step = undef;
	foreach(split(/\//,$dir)) {
		$step .= $_."/";
		next if -e $step;
		mkdir($step, 0755) or die "_recmkdir($dir): Failed to create $step: $!\n";
	}
	return $step;
}
