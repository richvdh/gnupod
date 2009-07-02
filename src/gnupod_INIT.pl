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
use GNUpod::FooBar;
use GNUpod::XMLhelper;
use Getopt::Long;
use vars qw(%opts);


print "gnupod_INIT.pl ###__VERSION__### (C) Adrian Ulrich\n";

$opts{mount} = $ENV{IPOD_MOUNTPOINT};
#Don't add xml and itunes opts.. we *NEED* the mount opt to be set..
GetOptions(\%opts, "version", "help|h", "mount|m=s", "disable-convert|d", "france|f", "noask", "model=s", "fwguid|g=s");
GNUpod::FooBar::GetConfig(\%opts, {model=>'s'}, "gnupod_INIT");
#gnupod_INIT does not read configuration files!


usage() if $opts{help};
version() if $opts{version};

go();


sub go {
 #Disable autosync
 $opts{_no_sync} = 1;
 my $con = GNUpod::FooBar::connect(\%opts);
 usage("$con->{status}\n") if $con->{status};

## Ask the user, if he still knows what he/she's doing..
print << "EOF";

Your iPod is mounted at $opts{mount}, ok ?
*********************************************************
This tool creates the default directory tree on your iPod
and creates an *empty* GNUtunesDB (..or convert your old
iTunesDB to a new GNUtunesDB).

You only have to use this command if
    -> You never used GNUpod with this iPod
 or -> You did an 'rm -rf' on your iPod

btw: use 'gnupod_addsong -m $opts{mount} --restore'
     if you lost your songs on the iPod after using
     gnupod_INIT.pl (..but this won't happen, because
     this tool has no bugs ;) )
*********************************************************

Hit ENTER to continue or CTRL+C to abort

EOF
##

<STDIN> unless $opts{noask};
 
 print "Creating directory structure on $opts{mount}\n\n";
 print "> AppFolders:\n";
 
 foreach( ($con->{rootdir}, $con->{musicdir},
             $con->{itunesdir}, $con->{etc}) ) {
   my $path = $_;
   next if -d $path;
   mkdir("$path") or die "Could not create $path ($!)\n";
   print "+$path\n";
 }
 
 print "> Music folders:\n";
 for(0..19) {
   my $path = sprintf($con->{musicdir}."/F%02d", $_);
   next if -d $path;
   mkdir("$path") or die "Could not create $path ($!)\n";
   print "+$path\n";
 }

 if($opts{france}) {
  print "> Creating 'Limit' file (because you used --france)\n";
  mkdir("$con->{rootdir}/Device");
  open(LIMIT, ">$con->{rootdir}/Device/Limit") or die "Failed: $!\n";
   print LIMIT "216\n"; #Why?
  close(LIMIT);
 }
 elsif(-e "$con->{rootdir}/Device/Limit") {
  print "> Removing 'Limit' file (because you didn't use --france)\n";
  unlink("$con->{rootdir}/Device/Limit");
 }
 else {
  print "> No 'Limit' file created or deleted..\n";
 }
 
 print "> Creating dummy files\n";
 
 GNUpod::XMLhelper::writexml($con);

 my $t2pfail = 0;
 if(-e $con->{itunesdb} && !$opts{'disable-convert'}) {
 #We have an iTunesDB, call tunes2pod.pl
  print "Found *existing* iTunesDB, running tunes2pod.pl\n";
  $t2pfail = system("$con->{bindir}/tunes2pod.pl", "--force", "-m", $opts{mount});
 }
 else {
 #No iTunesDB, run mktunes.pl
  print "No iTunesDB found, running mktunes.pl\n";
  my @mktunescmd = ("$con->{bindir}/mktunes.pl", "-m" ,"$opts{mount}");
  if ($opts{'fwguid'}) { push @mktunescmd, "-g", "$opts{fwguid}"; } 
  $t2pfail = system(@mktunescmd);
 }
 
 if($t2pfail) {
  print "\n Done\n ..Looks like something went wrong :-/\n";
 }
 else {
  print "\n Done\n   Your iPod is now ready for GNUpod :)\n";
 }
 
}



###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
die << "EOF";
$rtxt
Usage: gnupod_INIT.pl [-h] [-m directory]

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
   -d, --disable-convert   Don't try to convert an existing iTunesDB
   -g, --fwguid=HEXVAL     FirewireGuid / Serial of connected iPod (passed to mktunes.pl)
   -f, --france            Limit volume to 100dB (For French-Law/People)
                           Maximal-volume without this is ~104dB (VERY LOUD)
                           *WARNING* This works only for iPods running
                           Firmware 1.x (1st & 2nd generation)
                           You can also use mktunes.pl '--volume PERCENT'
                           to adjust the volume (Works with Firmware 1.x AND 2.x)
       --noask             Do not wait for any user input

Report bugs to <bug-gnupod\@nongnu.org>
EOF
}

sub version {
die << "EOF";
gnupod_INIT.pl (gnupod) ###__VERSION__###
Copyright (C) Adrian Ulrich 2002-2004

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}

=head1 NAME

gnupod_INIT.pl - Initialize iPod for the usage with gnupod.

=head1 SYNOPSIS

B<gnupod_INIT.pl> [OPTION]...

=head1 DESCRIPTION

gnupod_INIT.pl prepares a 'virgin' iPod for GNUpod by creating missing
directories that your iPod needs, translating an existing
iTunesDB (via L<tunes2pod.pl>) to a L<GNUtunes.xml> and/or creating
a missing iTunesDB (via L<mktunes.pl>).

=head1 OPTIONS

=over 4

=item -h, --help

Display usage help and exit

=item     --version

Output version information and exit

=item -m, --mount=directory

iPod mountpoint, default is C<$IPOD_MOUNTPOINT>

=item -d, --disable-convert

Don't try to convert an existing iTunesDB

=item -g, --fwguid=HEXVAL

FirewireGuid of connected iPod (passed to mktunes.pl).
See L<mktunes.pl> for details.

=item -f, --france

Limit volume to 100dB (For French-Law/People)

Maximal-volume without this is ~104dB (VERY LOUD)

B<WARNING> This works only for iPods running Firmware 1.x (1st & 2nd generation).
You can also use mktunes.pl '--volume PERCENT' to adjust the volume (Works with Firmware 1.x AND 2.x)

=item     --noask

Do not wait for any user input. Assume YES.

=back

###___PODINSERT man/general-tools.pod___###

=head1 AUTHORS

Adrian Ulrich <pab at blinkenlights dot ch> - Main author of GNUpod

=head1 COPYRIGHT

Copyright (C) Adrian Ulrich

###___PODINSERT man/footer.pod___###
