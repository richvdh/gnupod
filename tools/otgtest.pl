use strict;
use GNUpod::iTunesDB;
use GNUpod::XMLhelper;
use GNUpod::FooBar;
use Getopt::Long;
use vars qw(%opts @keeper $plcref);


$opts{mount} = "/mnt/ipod";



 go();

####################################################
# Worker
sub go {
 #Disable auto-run of tunes2pod or gnupod_otgsync.pl
 $opts{_no_sync} = 1;
 my $con = GNUpod::FooBar::connect(\%opts);
 usage($con->{status}."\n") if $con->{status};

print "********** readOTG() *************\n";
#Read on The Go list written by the iPod
my @xotg    = GNUpod::iTunesDB::readOTG($con->{onthego});

foreach(@xotg) {
 print "(100)OTGC: $_\n";
}


print "********** readPLC() *************\n";
#plcref is used by newfile()
#so we have to call this before doxml()
$plcref  = GNUpod::iTunesDB::readPLC($con->{playcounts});

}



sub newfile {
 my($el) = @_;
 push(@keeper, int($el->{file}->{id}));
}

sub newpl {}

############################################
# Die with status
sub usage {
 die "died: $_[0]\n";
}

