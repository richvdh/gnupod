package GNUpod::XMLhelper;

use strict;

use XML::Simple;
$XML::Simple::PREFERRED_PARSER = "XML::Parser";

##
## (C) 2003 Adrian Ulrich
## Release 20030823
## -----------------------------------------------
##
##

my @idpub;
my $xid = 1; #The ipod doesn't like ID 0


#We need todo some 'workarounds' on non-perl 5.8

###############################################
# Get an iPod-safe path for filename
sub getpath {
 my($mountp, $filename, %opts) = @_;
my $path = undef;

if($opts{keepfile}) { #Don't create a new filename..
  $path = $filename;
 }
else { #Default action.. new filename to create 
 my $name = (split(/\//, $filename))[-1];
 my $i = 0;
 $name =~ tr/a-zA-Z0-9\./_/c; 
#Search a place for the MP3 file
  while($path = sprintf("$mountp/iPod_Control/Music/F%02d/%d_$name", int(rand(20)), $i++)) {
   last unless(-e $path);
  }
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
 my($xmlin, %opts) = @_;
 my $doc = undef;
if($opts{cleanit}) { #We create a clean XML file
  $doc->{gnuPod}->[0]->{files} = ();
}
elsif(-r $xmlin) { #Parse the oldone..
 $doc = XML::Simple::XMLin($xmlin, keeproot => 1, keyattr => [], forcearray=>1); 
 cleandoc($doc);
 
 #Create the IDPUB (Free IDs)
  foreach(@{$doc->{gnuPod}->[0]->{files}->[0]->{file}}) {
   $idpub[$_->{id}]++;
  }
}
else { #XML does not exist?
 return undef;
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
	    print STDERR "FATAL XML ERROR: 'file' element without 'id' found! ($thash{path})\n";
            print STDERR "Please remove this file (from your iPod and the GNUtunesDB) and\n";
	    print STDERR "try again... This shouldn't happen :-/\n";
	    exit(2);
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
 my($out, $href, %opts) = @_;

 open(OUT, ">$out") or die "Could not write to $out : $!\n";
 binmode(OUT);
 print OUT XML::Simple::XMLout($href,keeproot=>1);
 close(OUT);
}


######################################################
# XML::Parser on perl 5.8 seems to have a bug:
# SOMETIMES, it returns latin1 stuff.. SOMETIMES utf8
# -> We go to the doctree and convert latin1 to utf8
#   if XML::Parser freaked out..
#  ..yes: this is slow.. but better than fu*king up the doc
sub cleandoc {
 my ($r, $base, $xref) = @_;
 if(ref($r) eq "HASH") {
  foreach(keys(%$r)) {
    cleandoc(${$r}{$_}, $_, $r);
  }
 }
 elsif(ref($r) eq "ARRAY") {
  foreach(@$r) {
   cleandoc($_);
  }
 }
 elsif(ref($r) eq "") {
  if($r =~ /ö|ä|ü|Ö|Ä|Ü|é|è|à|Ô|Â|Ê|Û|â|ê|û|ô/) { #Broken input
   print "ICONV:: $r ->";
    my $us = Unicode::String->new($r);
    $r = $us->as_string;
   print "$r ** FIXME: This is *BROKEN*\n";
  }
  $xref->{$base} = $r;
 }
 else {
  die "Bug in cleandoc: i can't handle ".ref($r)."\n";
 }
}


1;
