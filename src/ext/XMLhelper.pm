package GNUpod::XMLhelper;

use strict;
use XML::Simple;


##
## (C) 2003 Adrian Ulrich
## Release 20030525
## -----------------------------------------------
##
##

###############################################
# Get an iPod-safe path for filename
sub getpath {
 my($mountp, $filename) = @_;
 
 my ($i, $path) = undef; 
 my $name = (split(/\//, $filename))[-1];
 $name =~ tr/a-zA-Z0-9./_/c;
for($path = sprintf("$mountp/iPod_Control/Music/F%02d/%d_$name", int(rand(20)), $i);(-e $path);$i++) 
  {}
#Remove mountpoint from $path
$path =~ s/^$mountp(.+)/$1/;

#Convert /'s to :'s
$path =~ tr/\//:/;
return $path;
}

#############################################################
# Parses the XML File
sub parsexml {
 my($xmlin) = @_;
 my $xls = XML::Simple->new();
 my $doc = $xls->XMLin($xmlin, keeproot => 1, keyattr => [], forcearray=>1);
return $doc;
}

######################################################################
# Same as quickhash, but for playlist items
sub build_plarr {
 my($xmldoc) = @_;
 my @ra = ();
  foreach my $gnupod (@{$xmldoc->{gnuPod}}) {
   if($gnupod->{playlist}) {
    push(@ra, @{$gnupod->{playlist}});
   }
  }
  return @ra;
}

######################################################################
# Create an easy to use hash with some usefull information
sub build_quickhash {
my($xmldoc) = @_;
my %rhash = ();

 
  foreach my $gnupod (@{$xmldoc->{gnuPod}}) {
    foreach my $files (@{$gnupod->{files}}) {
      foreach my $file (@{$files->{file}}) {
         #Now we get EVERY file element, even if someone did
	 #a weird XML File with many <gnuPod> parts and such idiotic
	 #stuff..
	  my %thash = (); #clean the TempHash
	   foreach my $el (keys(%{$file})) {
	     $thash{$el} = ${$file}{$el};
	   }
	   unless(defined($thash{id})) {
	    die "FATAL XML ERROR: 'file' element without 'id' found!\n";
           }
	   $rhash{$thash{id}} = \%thash;
      }
    }
  }

return \%rhash; 
}



1;
