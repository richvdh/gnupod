package GNUpod::XMLhelper;

use strict;
use XML::Simple;


##
## (C) 2003 Adrian Ulrich
## Release 20030525
## -----------------------------------------------
##
##

my @idpub;
my $xid = 0;
###############################################
# Get an iPod-safe path for filename
sub getpath {
 my($mountp, $filename) = @_;
 
 my ($i, $path) = undef; 
 my $name = (split(/\//, $filename))[-1];
 $name =~ tr/a-zA-Z0-9\./_/c;
 
#Search a place for the MP3 file
  while($path = sprintf("$mountp/iPod_Control/Music/F%02d/%d_$name", int(rand(20)), $i++)) {
   last unless(-e $path);
  }
 
#Remove mountpoint from $path
my $ipath = $path;
$ipath =~ s/^$mountp(.+)/$1/;

#Convert /'s to :'s
$ipath =~ tr/\//:/;
return ($ipath, $path);
}

#############################################################
# Parses the XML File
sub parsexml {
 my($xmlin) = @_;
 my $xls = XML::Simple->new();
 my $doc = $xls->XMLin($xmlin, keeproot => 1, keyattr => [], forcearray=>1);
 
 #Create the IDPUB (Free IDs)
  foreach(@{$doc->{gnuPod}->[0]->{files}->[0]->{file}}) {
   $idpub[$_->{id}]++;
  }

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

#####################################################
# Add a file hash
sub addfile {
 my($xmldoc, $fh) = @_;
#Request a free ID
 while($idpub[$xid]) { $xid++; }
     $fh->{id} = $xid;
     $idpub[$xid] = 1;
     
     push(@{$xmldoc->{gnuPod}->[0]->{files}->[0]->{file}}, $fh);
}


######################################################
# Write the XML File
sub write_xml {
 my($out, $href) = @_;
 open(OUT, ">$out") or die "Could not write to $out, $!\n";
  print OUT XML::Simple::XMLout($href,keeproot=>1,xmldecl=>1);
 close(OUT);
}

1;
