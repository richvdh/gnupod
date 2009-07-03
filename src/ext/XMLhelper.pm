package GNUpod::XMLhelper;
#  Copyright (C) 2002-2007 Adrian Ulrich <pab at blinkenlights.ch>
#  Part of the gnupod-tools collection
#
#  URL: http://www.gnu.org/software/gnupod/
#
#    GNUpod is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    GNUpod is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.#
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
use constant MAX_PATHLOOP => 2048;

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


##############################################
# Finds a filename on the iPod
sub getpath {
	my($xconn, $source, $opts) = @_;
	my $destination = undef;
	
	if($opts->{keepfile}) {
		$destination = $source;  # Keep source path
	}
	else {
		my $clean_filename      = (split(/\//,$source))[-1];               # Extracts the filename
		my ($current_extension) = $clean_filename =~ /\.([^.]*)$/;         # Current file extension
		   $clean_filename      =~ tr/a-zA-Z0-9/_/c;                     # Remove bad chars
		my $requested_ext       = ($opts->{extension} || $opts->{format}); # Checks if existing extension matches regexp
		my @aviable_targets     = bsd_glob($xconn->{musicdir}."/*", $xconn->{autotest}?GLOB_NOCASE:GLOB_NOSORT);
		
		unless(int(@aviable_targets)) {
			warn "No iPod folders found at $xconn->{mountpoint}, did you run gnupod_INIT.pl ?\n";
			return undef;
		}
		if(length($current_extension) != 0) {
			# -> Removes extension
			$clean_filename = substr($clean_filename,0,(1+length($current_extension))*-1);
		}
		if($opts->{format} && $requested_ext && $current_extension !~ /$requested_ext/i) {
			if(length($current_extension) != 0) {
				# Only warn if file HAD an extension before
				warn "Warning: $source has a wrong extension [$current_extension], changed extension to $opts->{format}\n";
			}
			$current_extension = $opts->{format};
		}
		
		for(my $i = 0; $i < MAX_PATHLOOP; $i++) {
			my $dp_prefix  = sprintf("g%x_",$i);
			my $dp_target  = $aviable_targets[$xconn->{autotest}?0:int(rand(@aviable_targets))];
			my $dp_path    = $dp_target."/".$dp_prefix;
			my $dp_chrleft = MAX_PATHLENGTH - length($dp_path) + length($xconn->{mountpoint});
			my $dp_ext     = ".$current_extension";
			my $dp_extlen  = length($dp_ext);
			next if $dp_chrleft < $dp_extlen; # No space for extension, checkout something else
			$dp_path .= substr($clean_filename,($dp_chrleft-$dp_extlen)*-1).$dp_ext;
			if(!(-e $dp_path) && open(TEST, ">", $dp_path)) {
				close(TEST);
				unlink($dp_path) or die "FATAL: Unable to unlink $dp_path : $!\n";
				$destination = $dp_path;
				last;
			}
		}
	}
	
	
	my $ipod_dest =  $destination;
	   $ipod_dest =~ s/^$xconn->{mountpoint}(.+)/$1/;
	   $ipod_dest =~ tr/\//:/;
	return ($ipod_dest, $destination);
}



################################################################
# Escape chars
sub xescaped {
	use bytes;
	my ($ret) = @_;
	
	$ret =~ s/&/&amp;/g;
	$ret =~ s/"/&quot;/g;
	$ret =~ s/\'/&apos;/g;
	$ret =~ s/</&lt;/g;
	$ret =~ s/>/&gt;/g;
	# newline normalization
	$ret =~ s/\x0D\x0A/\x0A/g;
	$ret =~ s/\x0D/\x0A/g;
	$ret =~ s/\x0A/&#x0a;/g;
	# BOM removal
	$ret =~ s/\xEF\xBB\xBF//g; # real BOM got converted to a "utf8.BOM" and isn't needed anymore
	# strip other control characters
	$ret =~ tr/\000-\037//d;
	#convert to XML encoded unicode
	$ret =~ s/([\xC2-\xDF])([\x80-\xBF])/"&#x".sprintf("%x", ((ord($1) & 31) <<  6) +  (ord($2) & 63) ).";"/eg;
	$ret =~ s/([\xE0-\xEF])([\x80-\xBF])([\x80-\xBF])/"&#x".sprintf("%x", ((ord($1) & 15) << 12) + ((ord($2) & 63) <<  6) +  (ord($3) & 63) ).";"/eg;
	$ret =~ s/([\xF0-\xF4])([\x80-\xBF])([\x80-\xBF])([\x80-\xBF])/"&#x".sprintf("%x", ((ord($1) &  7) << 18) + ((ord($2) & 63) << 12) + ((ord($3) & 63) <<  6) + (ord($4) & 63) ).";"/eg;
	# now everything left above 0x7f is illegal
	my $in = $ret;
	$ret =~ tr/\x80-\xff//d;
	$ret =~ s/&#xfffe;//g; # inverted BOM that somehow slipped through
	if ($in ne $ret) {
		use Data::Dumper;
		print "Something fishy was removed from your XML data. Here's the before/after data:\n";
		print Dumper($in);
		print Dumper($ret);
	}
	return $ret;
}


###############################################################
# Create a new child (for playlists or file)
# This is XML-Safe -> XDAT->{foo}->{data} or XDAT->{files}
# is XML ENCODED UTF8 DATA
sub mkfile {
	my($hr, $magic) = @_;
	my $r = undef;

	foreach my $base (keys %$hr) {
		$r .= "<$base "; # can be file/add or such things. No need to escape it
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
			$r .= "$_=\"".xescaped($hcopy{$_})."\" ";
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
# Reset some stuff if we do a second run
sub resetxml {
	$cpn = undef; #Current PlaylistName
	@idpub = ();
	@plorder = ();
	$xid = 1;
	$XDAT = undef;
}


#############################################################
# Parses the XML File and do events
sub doxml {
	my($xmlin, %opts) = @_;
	return undef unless (-r $xmlin);
	resetxml();
	my $p;
	my $ref = eval {
		$p = new XML::Parser(ErrorContext => 0, Handlers=>{Start=>\&eventer});
		$p->parsefile($xmlin);
	};
	if($@) {
		die "An error occurred reading $xmlin :\n", $@ ;
	}
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
			if (defined(@{$XDAT->{playlists}->{data}->{$current_plname}})) { #the playlist is not empty
				print OUT "\n ".mkfile({playlist=>$phr}, {return=>1,noend=>1})."\n";
				foreach(@{$XDAT->{playlists}->{data}->{$current_plname}}) {
					print OUT "   $_\n";
				}
				print OUT " </playlist>\n";
			} else {
				warn "XMLhelper.pm: Dropping empty playlist '$current_plname'!\n";
			}
		}
		else {
			warn "XMLhelper.pm: bug found: unhandled plitem $_ inside $current_plname\n";
		}
	}

	
	print (OUT "</gnuPod>\n") or die "Unable to write to $tmp_out : $!\n"; # Hits Out-Of-Space condition
 
	if(close(OUT)) {
		if(-e $out) { #Backup old out file
			rename($out, $out.".old") or warn "Could not move $out to $out.old\n";
		}
		rename($tmp_out, $out) or warn "Could not move $tmp_out to $out\n";
	}
	else {
		die "FATAL: Unable to close filehandle for $tmp_out : $!\n";
	}
	
	# Don't trust OnTheGo data now (until mktunes has run)
	GNUpod::FooBar::SetOnTheGoAsInvalid($rr);
	
	if($opts->{automktunes}) {
		print "> Creating new iTunesDB\n";
		GNUpod::FooBar::StartAutoMkTunes($rr);
	}

}

1;
