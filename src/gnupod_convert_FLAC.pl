#!/usr/bin/perl

use strict;



my $file  = $ARGV[0] or exit(1);
my $gimme = $ARGV[1];


if($gimme eq "GET_META") {
 my $ftag = undef;
 ## This is a UGLY trick to cheat perl!
 ## 1. Create a string
 my $nocompile = "use Audio::FLAC; \$ftag = Audio::FLAC->new( \$file )->tags();";
 eval $nocompile; #2. eval it!
 ## 3. = no errors without Audio::FLAC! :)
 if($@ || ref($ftag) ne "HASH") {
   warn "FileMagic.pm: Could not read FLAC-Metadata from $file\n";
   warn "FileMagic.pm: Maybe Audio::FLAC is not installed?\n";
   warn "Error: $@\n";
   exit(1);
 }
print "_ARTIST:$ftag->{ARTIST}\n";
print "_ALBUM:$ftag->{ALBUM}\n";
print "_TITLE:$ftag->{TITLE}\n";
print "_GENRE:$ftag->{GENRE}\n";
print "_TRACKNUM:$ftag->{TRACKNUMBER}\n";
print "_COMMENT:$ftag->{COMMENT}\n";
print "_VENDOR:$ftag->{VENDOR}\n";
print "FORMAT: FLAC\n";
}
elsif($gimme eq "GET_PCM") {
  my $tmpout = get_u_path("/tmp/gnupod_pcm", "wav");

  my $status = system("flac", "-d", "-s", "$file", "-o", $tmpout);
  
  if($status) {
   warn "flac exited with $status, $!\n";
   exit(1);
  }
  
  print "PATH:$tmpout\n";
  
}
elsif($gimme eq "GET_MP3") {
  #Open a secure flac pipe and open anotherone for lame
  #On errors, we'll get a BrokenPipe to stout
  my $tmpout = get_u_path("/tmp/gnupod_mp3", "mp3");
  open(FLACOUT, "-|") or exec("flac", "-d", "-s", "-c", "$file") or die "Could not exec flac: $!\n";
  open(LAMEIN , "|-") or exec("lame", "--silent", "--preset","extreme", "-", $tmpout) or die "Could not exec lame: $!\n";
   while(<FLACOUT>) {
    print LAMEIN $_;
   }
  close(FLACOUT);
  close(LAMEIN);
  print "PATH:$tmpout\n";
}
elsif($gimme eq "GET_AAC") {
 #Yeah! FAAC is broken and can't write to stdout..
 
  my $tmpout = get_u_path("/tmp/gnupod_faac", "m4a");
  open(FLACOUT, "-|") or exec("flac", "-d", "-s", "-c", "$file") or die "Could not exec flac: $!\n";
  open(FAACIN , "|-") or exec("faac", "-w", "-q", "120", "-o", $tmpout, "-") or die "Could not exec faac: $!\n";
   while(<FLACOUT>) { #Feed faac
    print FAACIN $_;
   }

  close(FLACOUT);
  close(FAACIN);

  print "PATH:$tmpout\n";
}
else {
 warn "$0 can't encode into $gimme\n";
 exit(1);
}

exit(0);

#############################################
# Get Unique path
sub get_u_path {
 my($prefix, $ext) = @_;
 my $dst = undef;
 while($dst = sprintf("%s_%d_%d.$ext",$prefix, time(), int(rand(99999)))) {
  last unless -e $dst;
 }
 return $dst;
}
