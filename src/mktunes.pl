###__PERLBIN__###
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
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use GNUpod::Mktunes;
use GNUpod::Hash58;
use GNUpod::SysInfo;
use GNUpod::ArtworkDB;
use Getopt::Long;


$| = 1;

my $mktunes = undef;
my %opts    = ();


print "mktunes.pl ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
GetOptions(\%opts, "version", "help|h", "ipod-name|n=s", "mount|m=s", "volume|v=i", "energy|e", "fwguid|g=s");
GNUpod::FooBar::GetConfig(\%opts, {'ipod-name'=>'s', mount=>'s', volume=>'i', energy=>'b', fwguid=>'s', model=>'s', low_ram_attr=>'s'}, "mktunes");
$opts{'ipod-name'} ||= "GNUpod ###__VERSION__###";


usage()   if $opts{help};
version() if $opts{version};
main();

#########################################################################
# main() :-)
sub main {
	my $con = GNUpod::FooBar::connect(\%opts);
	usage("$con->{status}\n") if $con->{status};
	
	my $sysinfo = GNUpod::SysInfo::GetDeviceInformation(Connection=>$con, NoDeviceSearch=>(defined($opts{fwguid}) ? 1 : 0 ) );
	my $fwguid  = (defined($opts{fwguid}) ? $opts{fwguid} : $sysinfo->{FirewireGuid}); # Always prefer fwguid. may be 0 to disable search
	
	print "> Loading ArtworkDB...";
	my $AWDB  = GNUpod::ArtworkDB->new(Connection=>$con, DropUnseen=>0);
	$AWDB->LoadArtworkDb;
	print "done\n";
	
	$mktunes = GNUpod::Mktunes->new(Connection=>$con, iPodName=>$opts{'ipod-name'}, Artwork=>$AWDB);
	
	print "> Parsing XML document...\n";
	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Could not read $con->{xml}, did you run gnupod_INIT.pl ?");
	
	print "\r> ".$mktunes->GetFileCount." files parsed, assembling iTunesDB...\n";

	my $keep = {};
	if ($opts{'low_ram_attr'}) {
		foreach(split(/[ ,]+/,$opts{'low_ram_attr'})) {
			$keep->{$_}++;
		}
		print "> Low ram option active. GNUpod will only add a limited\n";
		print "> number of attributes to preserve RAM on the iPod:\n";
		print "> ".join(" ", sort(keys(%{$keep})))."\n";
	}
	$mktunes->WriteItunesDB(keep=>$keep);
	
	if($fwguid) {
		my $k = GNUpod::Hash58::HashItunesDB(FirewireId=>$fwguid, iTunesDB=>$con->{itunesdb});
	}
	else {
		print "> iPod-GUID not detected. You can force the GUID using --fwguid\n";
	}
	
	print "> Writing new iTunesShuffle DB\n";
	$mktunes->WriteItunesSD;
	
	print "> Updating Sync-Status\n";
	GNUpod::FooBar::SetItunesDBAsInSync($con);   # iTunesDB is in sync with GNUtunesDB.xml
	GNUpod::FooBar::SetOnTheGoAsValid($con);     # ..and we can now, again, trust OnTheGo data
	GNUpod::FooBar::WipeShuffleStat($con);       # Forces reshuffling of iPod-Shuffle
	print "\nYou can now umount your iPod. [Files: ".$mktunes->GetFileCount."]\n";
	print " - May the iPod be with you!\n\n";

}


#########################################################################
# Called by doxml if it finds a new <file tag
sub newfile {
	my($item) = @_;
	
	if($opts{energy}) {
		# Crop title if requested. Note: Cropping it here affects regexps! 
		# But ... this had only a visible effect on 1st-gen ipods
		# and didn't work well with iTunes anyway..
		$item->{file}->{title} = Unicode::String::utf8($item->{file}->{title})->substr(0,18)->utf8;
	}
	
	#Volume adjust
	if($opts{volume}) {
		$item->{file}->{volume} += int($opts{volume});
		if(abs($item->{file}->{volume}) > 100) {
			print "\n** Warning: volume=\"$item->{file}->{volume}\" out of range: Volume set to ";
			$item->{file}->{volume} = ($item->{file}->{volume}/abs($item->{file}->{volume})*100);
			print "$item->{file}->{volume}% for id $item->{file}->{id}\n";
		}
	}

	my $id = $mktunes->AddFile($item->{file});
	print "\r> $id files parsed" if $id % 96 == 0;
}

#########################################################################
# Called by doxml if it a new <playlist.. has been found
sub newpl {
	my($item, $name, $type) = @_;
	if($type eq "pl") {
		$mktunes->AddNormalPlaylistItem(Name=>$name, Item=>$item);
	}
	elsif($type eq "spl") {
		$mktunes->AddSmartPlaylistItem(Name=>$name, Item=>$item);
	}
	else {
		warn "$0: unknown playlist type '$type' skipped\n";
	}
}



#########################################################################
# Usage information
sub usage {
	my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: mktunes.pl [-h] [-m directory] [-v VALUE]

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -n, --ipod-name=NAME    iPod Name (For unlabeled iPods)
   -v, --volume=VALUE      Adjust volume +-VALUE% (example: -v -20)
                            (Works with Firmware 1.x and 2.x!)
   -e, --energy            Save energy (= Disable scrolling title)
   -g, --fwguid=HEXVAL     FirewireGuid of connected iPod:

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

#########################################################################
# Displays current version
sub version {
die << "EOF";
mktunes.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2007

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

=head1 NAME

mktunes.pl - Create an iTunesDB.

=head1 SYNOPSIS

B<mktunes.pl> [OPTION]...

=head1 DESCRIPTION

Convert GNUpod's GNUtunesDB.xml into iTunesDB format. The iPod will read all
information about the available songs and playlists from the iTunesDB file.
So it is essential that you run mktunes.pl after adding changing or removing
songs/playlists. Also other software like gtkpod will read (and write) the
iTunesDB file to find out what's on your iPod.

Note: The iPod shuffle models will read a file called 'iTunesSD' which differs
in format and usually contains a lot less information than the iTunesDB file.
mktunes.pl will also create the iTunesSD file.

=head1 OPTIONS

=over 4

=item -h, --help

Display usage help and exit

=item     --version

Output version information and exit

=item -m, --mount=directory

iPod mountpoint, default is C<$IPOD_MOUNTPOINT>

=item -n, --ipod-name=NAME

Set the iPod Name (For unlabeled iPods). iTunes displays this name, not the label.

=item -v, --volume=VALUE

Adjust volume +-VALUE% (example: -v -20)

(Works with Firmware 1.x and 2.x!)

=item -e, --energy

Save energy (= Disable scrolling title)

=item -g, --fwguid=HEXVAL

Set the FirewireGuid of connected iPod. 

Use this switch to set the fwguid if the autodetection somehow fails to find the correct  serial number of your iPod. You can also specify the value in your configuration file (~/.gnupodrc) as C<mktunes.fwguid = 000ba3100310abcf>.

NOTE: iPod models from late 2007 and onwards (3rd and later generation Nano,
Classic, Touch) refuse to work unless the iTunesDB has been signed with a
sha1 hash. This hash helps to detect corrupted databases, prevents sharing
an iTunesDB between multiple iPods and locks out non-apple software. GNUpod
is able to create the required hash value if it knows the iPods serial
number (not the one printed on the device but an internal one), this is a 16 chars
long hex value such as: `000ba3100310abcf' and should be auto-detected on
GNU/Linux (via `/sbin/udevadm info') and Solaris (via `prtconf -v').
If GNUpod somehow fails to find the correct
fwguid/serial number of your iPod (as it can with recent versions of Ubuntu)
you'll have to specify the correct value using the `--fwguid' switch of
`mktunes.pl'.

=back

=head1 TROUBLESHOOTING

=head2 mktunes.pl failed

If C<mktunes.pl> fails (perhaps you hit ctrl-c because it was taking too
long) then the iTunes database may be left corrupted.  If you unmount at
this point, your iPod may appear to have no files at all.

If you are using Ubuntu 9.04 or above, and you found C<mktunes.pl> was
taking too long, you can either tell GNUpod your iPod's ID directly:

	mktunes.pl -m /mnt/ipod --fwguid 0123456789abc...

or upgrade your version of the GNUpod tools in order for C<mktunes.pl> to work again.
You can do that with the following commands:

	sudo su -
	apt-get remove gnupod-tools
	apt-get -y install cvs
	apt-get -y install autoconf
	cvs -z3 -d:pserver:anonymous@cvs.savannah.gnu.org:/sources/gnupod co gnupod
	cd gnupod
	autoconf
	./configure
	make install

In any case, remount your iPod, run C<mktunes.pl> again and unmount.  That
should fix the problem.

###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

=head1 COPYRIGHT

Copyright (C) Adrian Ulrich

###___PODINSERT man/footer.pod___###
