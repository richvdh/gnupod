package GNUpod::XMLhelper;
#  Copyright (C) 2002-2003 Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://www.gnu.org/software/gnupod/
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# iTunes and iPod are trademarks of Apple
#
# This product is not supported/written/published by Apple!

use strict;
use XML::Parser;
use Unicode::String;


## Release 20030927

my $cpn = undef; #Current PlaylistName
my @idpub = ();
my @plorder = ();
my $xid = 1;
use vars qw($XDAT);

##############################################
# Convert an ipod path to unix
sub realpath {
 my($mountp, $ipath) = @_;
 $ipath =~ tr/:/\//;
return "$mountp/$ipath";
}

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


################################################################
# Escape chars
sub xescaped {
 my ($ret) = @_;
$ret =~ s/&/&amp;/g;
$ret =~ s/"/&quot;/g;
$ret =~ s/</&lt;/g;
$ret =~ s/>/&gt;/g;
$ret =~ s/'/&apos;/g;

return $ret;
}




###############################################################
# Create a new child (for playlists or file)
sub mkfile {
 my($hr, $magic) = @_;
 my $r = undef;
  foreach my $base (keys %$hr) {
   $r .= "<".xescaped($base)." ";
     foreach (keys %{$hr->{$base}}) {
      $r .= xescaped($_)."=\"".xescaped($hr->{$base}->{$_})."\" ";
     }
     if($magic->{addid} && !$hr->{$base}->{id}) {
      while($idpub[$xid]) { $xid++; }
      $r .= "id=\"$xid\" ";
      $idpub[$xid] = 1;
     }
   $r .= "/>";
  }

  if($magic->{plname}) { #Create a playlist item
   push(@{$XDAT->{playlists}->{data}->{$magic->{plname}}}, $r);
  }
  elsif($magic->{splname}) { #Create a smartplaylist item
   push(@{$XDAT->{spls}->{data}->{$magic->{splname}}}, $r);
  }
  else { #No playlist item? has to be a file
   push(@{$XDAT->{files}}, $r);
  }
}

##############################################################
# Add a playlist to output
sub addpl {
 push(@plorder, $_[0]);
}

##############################################################
# Add a SmartPlaylist to output
sub addspl {
 my($name, $opt) = @_;
 push(@plorder, $name);
 $opt->{name} = $name;
 $XDAT->{spls}->{pref}->{$name} = $opt;
}


##############################################################
#Get all playlists
sub getpl_names {
 return @plorder;
}


##############################################################
# Call events
sub eventer {
 my($href, $el, @it) = @_;
 return undef unless $href->{Context}[0] eq "gnuPod";
  if($href->{Context}[1] eq "files") {
    #add(s)pl() call done before we got all files? that's bad!
    warn "** XMLhelper: Found <file ../> item *after* a <playlist ..>, that's bad\n" if getpl_names();
    my $xh = mkh($el,@it);         #Create a hash
    @idpub[$xh->{file}->{id}] = 1; #Promote ID
    main::newfile($xh);            #call sub
  } 
  elsif($href->{Context}[1] eq "" && $el eq "playlist") {
    $cpn = mkh($el,@it)->{$el}->{name}; #Update current name
    addpl($cpn); #Add this playlist
  }
  elsif($href->{Context}[1] eq "playlist") {
   die "Fatal XML Error: playlist without name found!\n" if $cpn eq "";
   main::newpl(mkh($el, @it), $cpn, "pl"); #call sub
  }
  elsif($href->{Context}[1] eq "" && $el eq "smartplaylist") {
    my $xh = mkh($el,@it);     #Create a hash
    $cpn = $xh->{$el}->{name}; #Get current plname
    addspl($cpn,$xh->{$el});   #add the pl
  }
  elsif($href->{Context}[1] eq "smartplaylist") {
   die "Fatal XML Error: smartplaylist without name found!\n" if $cpn eq "";
   main::newpl(mkh($el, @it), $cpn,"spl"); #Call sub  
  }
 # else {
 #  print "?? $href->{Context}[0] // $href->{Context}[1] // $href->{Context}[2] // $el\n";
 # }
}


##############################################################
# Create a hash
sub mkh {
 my($base, @content) = @_;
 my $href = ();
  for(my $i=0;$i<int(@content);$i+=2) {
   $href->{$base}->{$content[$i]} = Unicode::String::utf8($content[$i+1])->utf8;
  }
  return $href;
}



#############################################################
# Parses the XML File and do events
sub doxml {
 my($xmlin, %opts) = @_;
return undef unless (-r $xmlin);
my $p = new XML::Parser(Handlers=>{Start=>\&eventer});
   $p->parsefile($xmlin);
return $p;
}



######################################################
# Write the XML File
sub writexml {
 my($out) = @_;
 open(OUT, ">$out") or die "Could not write to $out : $!\n";
 binmode(OUT);

 print OUT "<?xml version='1.0' standalone='yes'?>\n";
 print OUT "<gnuPod>\n <files>\n";
#Do file part
 foreach(@{$XDAT->{files}}) {
  print OUT "  $_\n";
 }
 print OUT " </files>\n";
#End file part

#Print all playlists
 foreach(@plorder) {
  #addspl() will create {pref}->{$_}->{name} .. so this 'if' is safe
  if(my $shr = $XDAT->{spls}->{pref}->{$_}) { #prefs present = is a spl
      print OUT "\n <smartplaylist ";
         foreach(keys(%$shr)) { print OUT "$_=\"$shr->{$_}\" "; }
      print OUT ">\n";    
       ### items
        foreach my $sahr (@{$XDAT->{spls}->{data}->{$_}}) {
         print OUT "   $sahr\n";
        }
       ###
      print OUT " </smartplaylist>\n";
  }
  else { #No prefs -> normal playlist
      print OUT "\n <playlist name=\"$_\">\n";
       foreach(@{$XDAT->{playlists}->{data}->{$_}}) {
        print OUT "   $_\n";
       }
      print OUT " </playlist>\n";
  }
 }
print OUT "</gnuPod>\n";
close(OUT);
}

1;
