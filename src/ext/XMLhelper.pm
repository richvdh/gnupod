package GNUpod::XMLhelper;
#  Copyright (C) 2002-2005 Adrian Ulrich <pab at blinkenlights.ch>
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
use GNUpod::FooBar;
use File::Glob ':glob';

#Maximal length of a path
#64 for ipod photo
#55 for ipod mini
#who cares, but don't go below 31! it would break getpath
use constant MAX_PATHLENGTH => 49;
#Try X times to find a path
use constant MAX_PATHLOOP => 1024;

## Release 20050203

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
	return $mountp.$ipath;
}

###############################################
# Get an iPod-safe path for filename
sub getpath {
	my($mountp, $filename, $opts) = @_;
	my $path = undef;

	if($opts->{keepfile}) { #Don't create a new filename..
		$path = $filename;
	}
	else { #Default action.. new filename to create 
		my $test_extension = $opts->{extension} || $opts->{format}; #Test extension
		my $name = (split(/\//, $filename))[-1];                    #Name
		my $i = 0;                                                  #Count
		my $mountpoint_length = length($mountp);                    #Length of the mountpoint
		$name =~ tr/a-zA-Z0-9\./_/c;                                #CleanName for dumb Filesystems

		#Hups, current filename has a wrong extension...
		if($opts->{format} && $test_extension && ($name !~ /\.($test_extension)$/i)) {
			my($ext) = $name =~ /\.([^.]*)$/;          #Get the current extension (maybe null)
			#Warn IF the old file HAD an extension. We are silent if it didn't have one.. (It's unix :) )
			warn "Warning: File '$name' has a wrong extension [$ext], changed extension to $opts->{format}\n" if $ext;
			$name =~ s/\.?$ext$/.$opts->{format}/;  #Replace current extension with newone
		}
 
		#### #Search a place for the MP3 file ####
		# 1. Glob to find all dirs
		## We don't cache this, we do a glob for each new file..
		## Shouldn't be a waste if time.. We belive in the Cacheing of the OS ;)
		my @aviable_targets = bsd_glob("$mountp/iPod_Control/Music/*", GLOB_NOSORT);
		# 2. Paranoia check..
		unless(@aviable_targets) {
			warn "No folders found, did you run gnupod_INIT.pl ?\n";
			return undef;
		}

		# 3. Search
		while(++$i) {
		
			if($i > MAX_PATHLOOP) { #Abort
				warn "getpath() : No path for $name found, giving up!\n";
				return undef;
			}
			
			#Prefix for the filename
			my $pdiff = $i."_";
			#Target (including mountpoint)
			my $target = $aviable_targets[int(rand(@aviable_targets))];
			#-> $ipod_mountpoint/musicdir/$pdiff
			my $tmp_ipodpath = $target."/".$pdiff;
			#How many chars are left for the filename?
			my $chars_left = MAX_PATHLENGTH - length($tmp_ipodpath) + $mountpoint_length;
			next if $chars_left < 6; #We would like to get more than 6 chars for the filename (XXX.mp3)
			#Note: Chars needs to be positive for this substr call!
			$path = $tmp_ipodpath.substr($name,$chars_left*-1);
			
			if( !(-e $path) && open(TESTFILE,">",$path) ) { #This is false if we would write to a globed file :)
				close(TESTFILE);
				unlink($path); #Maybe it's a dup.. we don't create empty files
				last;
			}
		}
	} ## End default action

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
	#$ret =~ s/^\s*-+//g;
	my $xutf = Unicode::String::utf8($ret)->utf8;
	#Remove 0x00 - 0x1f chars (we don't need them)
	$xutf =~ tr/\000-\037//d;
	
	return $xutf;
}




###############################################################
# Create a new child (for playlists or file)
# This is XML-Safe -> XDAT->{foo}->{data} or XDAT->{files}
# is XML ENCODED UTF8 DATA
sub mkfile {
	my($hr, $magic) = @_;
	my $r = undef;

	foreach my $base (keys %$hr) {
		$r .= "<".xescaped($base)." ";
		#Copy the hash, because we do something to it
		my %hcopy = %{$hr->{$base}};

		#Create the id item if requested
		if($magic->{addid} && int($hcopy{id}) < 1) {
			while($idpub[$xid]) { $xid++; }
			$hcopy{id} = $xid;
			$idpub[$xid] = 1;
		}

		#Build $r
		foreach (sort(keys %hcopy)) {
			$r .= xescaped($_)."=\"".xescaped($hcopy{$_})."\" ";
		}

		if($magic->{noend}) { $r .= ">" }
		else                { $r .= "/>"}
	}
  
	if($magic->{return}) { 
		return $r; 
	}
	elsif($magic->{plname}) { #Create a playlist item
		push(@{$XDAT->{playlists}->{data}->{$magic->{plname}}}, $r);
	}
	elsif($magic->{splname}) { #Create a smartplaylist item
		push(@{$XDAT->{spls}->{data}->{$magic->{splname}}}, $r);
	}
	else { #No playlist item? has to be a file
		push(@{$XDAT->{files}}, $r);
	}
	return $xid; #Return current XID
}

##############################################################
# Add a playlist to output (Called by eventer or tunes2pod.pl)
# This thing doesn't create xml-encoded output!
sub addpl {
	my($name, $opt) = @_;
	if(ref($XDAT->{playlists}->{pref}->{$name}) eq "HASH") {
		warn "XMLhelper.pm: No need to create '$name', playlist exists already!\n";
		return;
	}

	my %rh = ();
	   %rh = %{$opt} if ref($opt) eq "HASH"; #Copy if we got data 
	$rh{name} = $name;            #Force the name
	$rh{plid} ||= int(rand(99999)); #We create our own id
	push(@plorder, {name=>$name,plid=>$rh{plid},sort=>$rh{sort}});
 
	$XDAT->{playlists}->{pref}->{$name} = \%rh;
}

##############################################################
# Add a SmartPlaylist to output (Called by eventer or tunes2pod.pl)
# Like addpl(), 'output' isn't xml-encoded
sub addspl {
	my($name, $opt) = @_;
 
	if(ref($XDAT->{spls}->{pref}->{$name}) eq "HASH") {
		warn "XMLhelper.pm: No need to create '$name', smartplaylist exists already!\n";
		return;
	}


	my %rh = ();
	   %rh = %{$opt} if ref($opt) eq "HASH"; #Copy if we got data 
	$rh{name} = $name;              #Force the name
	$rh{plid} ||= int(rand(99999)); #We create our own id
	push(@plorder, {name=>$name,plid=>$rh{plid}});
	$XDAT->{spls}->{pref}->{$name} = \%rh;
}


##############################################################
#Get all playlists {name, plid}
sub getpl_attribs {
	return @plorder;
}

##############################################################
#Get Playlist content
sub getpl_content {
	my($plname) = @_;
	return @{$XDAT->{playlists}->{data}->{$plname}} if ref($XDAT->{playlists}->{data}->{$plname}) eq "ARRAY";
	return (); #Dummy fallback
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
		warn "** XMLhelper: Found <file ../> item *after* a <playlist ..>, that's bad\n" if getpl_attribs();
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
	my($rr, $opts) = @_;
	my $out = $rr->{xml};
	my $tmp_out = $out."_tmp_".int(time());

	open(OUT, ">$tmp_out") or die "Could not write to '$tmp_out' : $!\n";
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
	foreach(getpl_attribs()) {
		my $current_plname = $_->{name};
		
		if(my $shr = get_splpref($current_plname)) { #xmlheader present
			print OUT "\n ".mkfile({smartplaylist=>$shr}, {return=>1,noend=>1})."\n";
			### items
			foreach my $sahr (@{$XDAT->{spls}->{data}->{$current_plname}}) {
				print OUT "   $sahr\n";
			}
			###
			print OUT " </smartplaylist>\n";
		}
		elsif(my $phr = get_plpref($current_plname)) { #plprefs found..
			print OUT "\n ".mkfile({playlist=>$phr}, {return=>1,noend=>1})."\n";
			foreach(@{$XDAT->{playlists}->{data}->{$current_plname}}) {
				print OUT "   $_\n";
			}
			print OUT " </playlist>\n";
		}
		else {
			warn "XMLhelper.pm: bug found: unhandled plitem $_ inside $current_plname\n";
		}
	}

	
	print OUT "</gnuPod>\n";
 
	if(close(OUT)) {
		if(-e $out) { #Backup old out file
			rename($out, $out.".old") or warn "Could not move $out to $out.old\n";
		}
		rename($tmp_out, $out) or warn "Could not move $tmp_out to $out\n";
	}
	GNUpod::FooBar::setINvalid_otgdata($rr);
	
	if($opts->{automktunes}) {
		print "> Creating new iTunesDB\n";
		GNUpod::FooBar::do_automktunes($rr);
	}
	
}

1;
