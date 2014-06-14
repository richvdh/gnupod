###__PERLBIN__###
#
# find songs which have faulty IDs, and give them new ids.

use strict;
use warnings;
use GNUpod::XMLhelper;
use Getopt::Long;

my $programName = "gnupod_fix_ids.pl";

my $fullversionstring = "$programName Version ###__VERSION__###";

use vars qw(%opts);

$opts{mount} = $ENV{IPOD_MOUNTPOINT};

my $getoptres = GetOptions(\%opts, "version", "help|h", "mount|m=s",
);

# take model and mountpoint from gnupod_search preferences
GNUpod::FooBar::GetConfig(\%opts, {mount=>'s', model=>'s'}, "gnupod_fix_ids");

usage()   if ($opts{help} || !$getoptres );
version() if $opts{version};

my $pass = 0;

my $connection = GNUpod::FooBar::connect(\%opts);
usage($connection->{status}."\n") if $connection->{status};

main($connection);

exit 0;

sub main {
	my($con) = @_;

	# pass one, just to get id map
	GNUpod::XMLhelper::doxml($con->{xml}) or 
		usage("Failed to parse $con->{xml}, did you run gnupod_INIT.pl?\n");

	# pass two: fix up ids, and insert into new XML
	$pass++;
	GNUpod::XMLhelper::doxml($con->{xml}) or 
		usage("Failed to parse $con->{xml}\n");

	GNUpod::XMLhelper::writexml($con);
}

sub newfile {
	my ($el) = @_;
	if($pass != 1) {
		return;
	}

	my $id = $el->{file}->{id};
	if ($id == 0) {
		my $newid = GNUpod::XMLhelper::get_new_id();
		warn "Fixing id $id -> $newid";
		$el->{file}->{id}=$newid
	}

	GNUpod::XMLhelper::mkfile($el);
}

sub newpl {
	my($el, $name, $plt) = @_;
	if($pass != 1) {
		return;
	}
	GNUpod::XMLhelper::mkfile($el,{$plt."name"=>$name}); 
}


###############################################################
# Basic help
sub usage {
my($rtxt) = @_;
$rtxt = "" if (! defined($rtxt));
die << "EOF";
$fullversionstring
$rtxt
Usage: $programName ...

   -h, --help              display this help and exit
       --version           output version information and exit
   -m, --mount=directory   iPod mountpoint, default is \$IPOD_MOUNTPOINT
Report bugs to <bug-gnupod\@nongnu.org>
EOF
}


sub version {
die << "EOF";
$fullversionstring

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

EOF
}
