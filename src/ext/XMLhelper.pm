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


## Release 20030930

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

return Unicode::String::utf8($ret)->utf8;
}




###############################################################
# Create a new child (for playlists or file)
# This is XML-Safe -> XDAT->{foo}->{data} or XDAT->{files}
# is XML ENCODED UTF8 DATA !!!!!!!!!!!!
sub mkfile {
 my($hr, $magic) = @_;
 my $r = undef;
  foreach my $base (keys %$hr) {
   $r .= "<".xescaped($base)." ";
   
   #Copy the has, because we do something to it
   my %hcopy = %{$hr->{$base}};
   
   #Create the id item if requested
   if($magic->{addid} && int($hcopy{id}) < 1) {
     while($idpub[$xid]) { $xid++; }
     $hcopy{id} = $xid;
     $idpub[$xid] = 1;
   }
     foreach (sort(keys %hcopy)) {
      $r .= xescaped($_)."=\"".xescaped($hcopy{$_})."\" ";
     }

    if($magic->{noend}) { $r .= ">" }
    else                { $r .= "/>"}
  }
  
  if($magic->{return}) { return $r; }
  elsif($magic->{plname}) { #Create a playlist item
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
# Add a playlist to output (Called by eventer or tunes2pod.pl)
# This thing doesn't create xml-encoded output!
sub addpl {
 my($name, $opt) = @_;
 if(ref($XDAT->{playlists}->{pref}->{$name}) eq "HASH") {
  warn "XMLhelper.pm: Playlist '$name' is a duplicate, skipping addpl()\n";
  return;
 }
 push(@plorder, $name);

 #Escape the prefs
 my %rh = ();
 $rh{name} = $name;
 #Create the hash and the xml header
  foreach (keys(%$opt)) {
   $rh{$_} = $opt->{$_};
  }
 $XDAT->{playlists}->{pref}->{$name} = \%rh;
}

##############################################################
# Add a SmartPlaylist to output (Called by eventer or tunes2pod.pl)
# Like addpl(), 'output' isn't xml-encoded
sub addspl {
 my($name, $opt) = @_;
 if(ref($XDAT->{spls}->{pref}->{$name}) eq "HASH") {
  warn "XMLhelper.pm: Playlist '$name' is a duplicate, skipping addspl()\n";
  return;
 }

 push(@plorder, $name);
 my %rh = ();
 $rh{name} = $name;
 #Create the hash and the xml header
  foreach (keys(%$opt)) {
   $rh{$_} = $opt->{$_};
  }
  
 $XDAT->{spls}->{pref}->{$name} = \%rh;
}


##############################################################
#Get all playlists
sub getpl_names {
 return @plorder;
}

##############################################################
# Get SPL Prefs
sub get_splpref {
 return $XDAT->{spls}->{pref}->{$_[0]};
}

##############################################################
# Get PL prefs
sub get_plpref {
 return $XDAT->{playlists}->{pref}->{$_[0]};
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
    my $xh = mkh($el, @it); #Create hash
    $xh->{$el}->{name} = "NONAME" unless $xh->{$el}->{name};
    $cpn = $xh->{$el}->{name}; #Get current name
    addpl($cpn,$xh->{$el}); #Add this playlist
  }
  elsif($href->{Context}[1] eq "playlist") {
   main::newpl(mkh($el, @it), $cpn, "pl"); #call sub
  }
  elsif($href->{Context}[1] eq "" && $el eq "smartplaylist") {
    my $xh = mkh($el,@it);     #Create a hash
    $xh->{$el}->{name} = "NONAME" unless $xh->{$el}->{name};
    $cpn = $xh->{$el}->{name}; #Get current plname
    addspl($cpn,$xh->{$el});   #add the pl
  }
  elsif($href->{Context}[1] eq "smartplaylist") {
   main::newpl(mkh($el, @it), $cpn,"spl"); #Call sub  
  }
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
 open(OUT, ">$out") or die "Could not write to '$out' : $!\n";
 binmode(OUT);

 print OUT "<?xml version='1.0' standalone='yes'?>\n";
 print OUT "<gnuPod>\n <files>\n";
#Do file part, it's present as XML
 foreach(@{$XDAT->{files}}) {
  print OUT "  $_\n";
 }
 print OUT " </files>\n";
#End file part

#Print all playlists
 foreach(@plorder) {
  if(my $shr = get_splpref($_)) { #xmlheader present
      print OUT "\n ".mkfile({smartplaylist=>$shr}, {return=>1,noend=>1})."\n";
       ### items
        foreach my $sahr (@{$XDAT->{spls}->{data}->{$_}}) {
         print OUT "   $sahr\n";
        }
       ###
      print OUT " </smartplaylist>\n";
  }
  elsif(my $phr = get_plpref($_)) { #plprefs found..
      print OUT "\n ".mkfile({playlist=>$phr}, {return=>1,noend=>1})."\n";
       foreach(@{$XDAT->{playlists}->{data}->{$_}}) {
        print OUT "   $_\n";
       }
      print OUT " </playlist>\n";
  }
  else {
   warn "XMLhelper.pm: bug found: unhandled plitem $_\n";
  }
 }
print OUT "</gnuPod>\n";
close(OUT);
}

1;
