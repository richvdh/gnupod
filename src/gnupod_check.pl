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
use warnings;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;
use File::Glob ':glob';

use vars qw(%opts %TRACKER);

#Get maximal Pathlength from XMLHelper constant
my $xmlhelper_maxpathlen = GNUpod::XMLhelper::MAX_PATHLENGTH;

print "gnupod_check.pl Version ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "version", "help|h", "mount|m=s", "fixit");
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', 'automktunes'=>'b', model=>'s'}, "gnupod_check");

usage() if $opts{help};
version() if $opts{version};

# Need this global :-(
my $con = GNUpod::FooBar::connect(\%opts);
go();

####################################################
# Worker
sub go {
	usage($con->{status}."\n") if $con->{status};
	
	%TRACKER=( GLOBFILES => 0, ITFILES => 0, TIME => 0, SIZE => 0, ERR => 0, FIXED => 0 );
	print "Pass 1: Checking Files in the GNUtunesDB.xml...\n";
	GNUpod::XMLhelper::doxml($con->{xml}) or usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

	print "Pass 2: Checking Files on the iPod...\n";
	checkGNUtunes($con);

	print   "..finished\n\n";
	print   "  Total playtime : ".int($TRACKER{TIME}/1000/60/60)." h\n";
	printf ("  Total filesize : %.2f GB",( $TRACKER{SIZE}/1024/1024/1024 )); print " ($TRACKER{SIZE} Bytes) \n";
	print   "  iPod files     : $TRACKER{GLOBFILES}\n";
	print   "  GNUpod files   : $TRACKER{ITFILES}\n";

	if($opts{fixit}) {
		if($TRACKER{FIXED}) {
			print " -> Writing new GNUtunesDB.xml, i fixed $TRACKER{FIXED} Errors.\n";
			print "    You may have to re-run $0\n";
			GNUpod::XMLhelper::writexml($con, {automktunes=>$opts{automktunes}});
		}
		else {
			print " -> Nothing fixed, no need to rewrite the GNUtunesDB.xml\n";
		}
	}
	else {
		if($TRACKER{GLOBFILES} == $TRACKER{ITFILES} && $TRACKER{ERR} == 0) {
			print " -> Everything is fine :)\n";
		}
		elsif($TRACKER{GLOBFILES} != $TRACKER{ITFILES}) {
			print " -> The GNUtunesDB.xml is inconsistent. Please try to fix the errors or run $0 --fixit\n";
			print "    (Note: --fixit removes 'stale' files on the iPod)\n";
		}
		
		if($TRACKER{ERR} > 25) {
			print " -> I found MANY ($TRACKER{ERR}) errors. Maybe you should run\n";
			print "    '$0 --fixit' to let me fix this errors. If it still doesn't help, run\n";
			print "    'gnupod_addsong.pl --restore'. This would wipe all your Playlists\n";
			print "    but would cure your iPod for sure.\n";
		}
  }
}

############################################
# Glob all files
sub checkGNUtunes {
	my($c) = @_;
	foreach my $file (bsd_glob($c->{musicdir}."/*/*", GLOB_NOSORT)) {
	next if -d $file;
	$TRACKER{GLOBFILES}++;
		unless($TRACKER{PATH}{lc($file)}) { #Hmpf.. file maybe not in the GNUtunesDB
			print "  Stale file '$file' found. Remove the file, it wastes space...\n"; 
			$TRACKER{ERR}++;
			if($opts{fixit}) {
				print " fixit: Removing $file\n";
				unlink($file) or warn "Could not unlink $file, $!\n";
				$TRACKER{FIXED}++;
			}
		}
	}
}

#############################################
# Eventhandler for FILE items
sub newfile {
	my($el) =  @_;

	#Add song to xml?
	my $call_mkfile = $opts{fixit};
	
	my $rp = GNUpod::XMLhelper::realpath($opts{mount},$el->{file}->{path});
	my $id = $el->{file}->{id};
	
	my $HINT = "Run 'gnupod_check.pl --fixit' to wipe this zombie";
	
	$TRACKER{SIZE}+=int($el->{file}->{filesize});
	$TRACKER{TIME}+=int($el->{file}->{time});

	$TRACKER{ID}{int($id)}++;
	$TRACKER{PATH}{lc($rp)}++; #FAT32 is caseInsensitive.. HFS+ should also be caseInsensitive (ON THE IPOD)
	$TRACKER{ITFILES}++;

	if($TRACKER{ID}{int($id)} != 1) {
		print "  ID $id is used ".int($TRACKER{ID}{int($id)})." times!\n";
		$TRACKER{ERR}++;
		if($opts{fixit}) {
			print " fixit: Removing this file from XML, re-run $0 to get rid of the stale file!\n";
			$call_mkfile = undef;
			$TRACKER{FIXED}++;
		}
	}

	if(int($id) < 1) {
		print "  ID $id is < 1 .. You shouldn't do this!\n";
		$TRACKER{ERR}++;
		if($opts{fixit}) {
			print " fixit: Removing this file from XML, re-run $0 to get rid of the stale file!\n";
			$call_mkfile = undef;
			$TRACKER{FIXED}++;
		}
	}

	if(length($el->{file}->{path}) > $xmlhelper_maxpathlen) {
		print "  ID $id has a long filename. Some iPods may refuse to play this file with recent firmware! Run $0 --fixit\n";
		$TRACKER{ERR}++;
		if($opts{fixit}) {
			my($ipod_path, $real_path) = GNUpod::XMLhelper::getpath($con,$rp);
			if($ipod_path) {
				print " fixit: Renaming $rp into $real_path\n";
				my $rename_result = rename($rp,$real_path);
				if($rename_result) {
					$el->{file}->{path} = $ipod_path;
					$TRACKER{PATH}{lc($rp)}--;
					$TRACKER{PATH}{lc($real_path)}++;
					$rp = $real_path;
				}
				else {
					print " fixit: Ouch, rename failed: $!\n";
				}
			}
			else {
				print " fixit: Ouch, no new path found for $rp, removing from xml\n";
				$call_mkfile = undef;
			}
			$TRACKER{FIXED}++;
		}
	}
 
	if(!-e $rp) {
		print "  ID $id vanished! ($rp) -> $HINT\n";
		$TRACKER{ERR}++;
		if($opts{fixit}) {
			print " fixit: Removing $id from XML Database\n";
			$call_mkfile = undef;
			$TRACKER{FIXED}++;
		}
	}
	elsif(-d $rp) {
		print "  ID $id is a DIRECTORY?! ($rp)\n";
		if($opts{fixit}) {
			print " fixit: Removing $id from XML Database\n";
			$call_mkfile = undef;
			$TRACKER{FIXED}++;
		}
	}
	elsif(-s $rp < 1) {
		print "  ID $id has zero size! ($rp) -> $HINT\n";
		$TRACKER{ERR}++;
		if($opts{fixit}) {
			print " fixit: Removing $id from XML Database, please re-run $0 to get rid of the stale file!\n";
			$call_mkfile = undef;
			$TRACKER{FIXED}++;
		}
	}

	GNUpod::XMLhelper::mkfile($el) if $call_mkfile;
}

############################################
# Eventhandler for PLAYLIST items
sub newpl {
my($el, $name, $plt) = @_;
#Do something with $el - holds playlist stuff :)
GNUpod::XMLhelper::mkfile($el,{$plt."name"=>$name}); 
}



###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_check.pl [-h] [-m directory]
gnupod_check.pl checks for 'lost' files

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
       --fixit             Try to fixup some errors (may delete 'lost' files)

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}



sub version {
die << "EOF";
gnupod_check.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2004

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

=head1 NAME

gnupod_check.pl - Check for lost/zombie files on the iPod

=head1 SYNOPSIS

B<gnupod_check.pl> [OPTION]...

=head1 DESCRIPTION

Use this tool if your OS crashed while uploading songs to the iPod or if you have too much time ;)

=head1 OPTIONS

=over 4

=item -h, --help

Display usage help and exit

=item     --version

Output version information and exit

=item -m, --mount=directory

iPod mountpoint, default is C<$IPOD_MOUNTPOINT>

=item     --fixit

Try to fixup some errors (may delete 'lost' files)

=back

###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

=head1 COPYRIGHT

Copyright (C) Adrian Ulrich

###___PODINSERT man/footer.pod___###
