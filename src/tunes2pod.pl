
use Getopt::Mixed qw(nextOption);
use Unicode::String qw(utf8 utf16 byteswap2);

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

# code is from the old iFish-tool (doesn't exist anymore in gnuPod)
# ... it's a mess... but it works (sometimes)
# FIXME: rewrite this ugly piece of code

use strict;
use vars qw(@mhod_id $ipodmagic %opts);

## iTunesDB id list
$mhod_id[1] = "title";
$mhod_id[2] = "path";
$mhod_id[3] = "album";
$mhod_id[4] = "artist";
$mhod_id[5] = "genre";
$mhod_id[6] = "fdesc";
$mhod_id[8] = "comment";
$mhod_id[12] = "composer";

# header of a valid iTunesDB
$ipodmagic = "6d 68 62 64 68 00 00 00";


print "tunes2pod 0.8-rc1 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool converts a iTunesDB to a GNUpodDB file\n\n";

$opts{m} = $ENV{IPOD_MOUNTPOINT};
Getopt::Mixed::init("help h>help gui g>gui debug d>debug mount=s m>mount force f>force");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();


chck_opts(); #check getopts
&stdtest;

if(!$opts{g})
{
 print "Ready to convert your iTunesDB to a GNUpodDB?\n";
 print "\nHit ENTER to continue, CTRL+C to abort\n";
 <STDIN>;
}

#start the parser
parsomatic();
print "done\n";
exit(0);




sub parsomatic {
my($now, $qq, $c, $mpl, $cont, $plname);



	open(FILE,"$opts{m}/iPod_Control/iTunes/iTunesDB") or die "Could not open old iTunesDB: $!\n"; 
	binmode(FILE); #for Non-Unix systems..
	
	#check the header
	if(getfoo(0, (length($ipodmagic)+2)/3) ne $ipodmagic)
	{
	  die "** ERROR ** : Could open your iTunesDB, but: Wrong Header found..\n";
	}

	
	open(GNUTUNES, "> $opts{m}/iPod_Control/.gnupod/GNUtunesDB") or die "Could not write to GNUtunesDB: $!\n";

   $now = (time()-1);
   utime ($now, $now, "$opts{m}/iPod_Control/iTunes/iTunesDB"); #touch the iTunesDB, it has to be older than the gnuPod file
	    
# gnutunes header
print GNUTUNES "<?xml version=\"1.0\"?>\n<gnuPod>\n<files>\n";


$qq = 292; #the HARDCODED start of the first mhit #FIXME .. shouldn't be hardcooded...
# get every <file entry
while($qq != -1) {
 $qq = get_nod_a($qq); #get_nod_a returns wher it's guessing the next MHIT, if it fails, it returns '-1'
 $c++;
}

print GNUTUNES "</files>\n\n";

## search PL start
$qq = getshoe(112, 4)+292;

#get every playlist (no items)
while($qq != -1) {
 ($qq, $mpl, $cont, $plname) = get_pl($qq); #get_nod_a returns wher it's guessing the next MHIT, if it fails, it returns '-1'
 $c++;
 print "Got a MPL, ignoring\n" if $opts{d} && $mpl;
 print GNUTUNES "<playlist name=\"$plname\">\n$cont</playlist>\n\n" if(!$mpl && $plname);
}

#end of gnutunes file
print GNUTUNES "</gnuPod>";
close(FILE);
close(GNUTUNES);
}




#The new *super* rewritten get_pl code..
#Gets a whole playlist.. you'll only have to tell it where it can find a PL :-p
sub get_pl
{
my($offset) = @_;
my($is_mpl, $oid, $mht, $plname, $px, $ret) = undef;
  if(getstr($offset,4) eq "mhyp") {
   $is_mpl = getshoe($offset+20, 4);
   $offset+=getshoe($offset+4, 4);
    
    #Get the name of the playlist...
    #You would think that a playlist only has one name.. forget it!
    #Ehpod does funny things here and writes the playlist name two times.. *plenk*
    #MusicMatch does also funny things here (Like writing *no* plname for the MPL)
      
     while($oid != -1) {
      $offset+=$oid;
      ($oid, $mht, $px) = get_mhod($offset);
      $plname = xmlstring($px) if $mht == 1;
     }
     
     #Now get the PL items..
      $oid = undef;
     while($oid != -1) {
      $offset+=$oid;
      ($oid, $px) = get_mhip($offset);
      $ret .= "  <add id=\"$px\" />\n" if $px;
     }
    return ($offset, $is_mpl, $ret, $plname);
  }
 return -1;
}



# get an mhip entry
sub get_mhip {
 my($sum) = @_;
 if(getfoo($sum, 4) eq "6d 68 69 70") {
  my $oof = getshoe($sum+4, 4);
  my($oid, $mht, $txt) = get_mhod($sum+$oof);
  return -1 if $oid == -1; #fatal error..
  my $px = getshoe($sum+$oof-52, 4);
  return ($oid+$oof, $px);
 }

#we are lost
 return -1;
}


#get a mhod entry
#
# get_nod_a(START) - Get mhits..
sub get_nod_a {
my(@jerk, $sum, $zip, $state, $sa, $sl, $sb, $sid, $cdnum, $cdanz, $songnum, $songanz, $year);
my($sbr, $oid, $otxt);
($sum) = @_;
if(getfoo($sum, 4) eq "6d 68 69 74") #aren't we lost?
{

$sid = getshoe($sum+16 , 4);
$sa = getshoe($sum+36 , 4);
$sl = getshoe($sum+40,4);
$cdnum = getshoe($sum+92,4);   #cd nr
$cdanz = getshoe($sum+96,4);   #cd nr of..
$songnum = getshoe($sum+44,4); #song number
$songanz = getshoe($sum+48,4); #song num of..
$year = getshoe($sum+52,4); #year


$sbr = getshoe($sum+56,4);

  $sum += 156;                 #1st mhod starts here!
    while($zip != -1) {
     $sum = $zip+$sum; 
     ($zip, $oid, $otxt) = get_mhod($sum);    #returns the number where its guessing the next mhod, -1 if it's failed
      $jerk[$oid] = xmlstring($otxt);
    }


print GNUTUNES "  <file id=\"$sid\" bitrate=\"$sbr\" time=\"$sl\" filesize=\"$sa\" ";
print GNUTUNES "songnum=\"$songnum\" " if $songnum;
print GNUTUNES "songs=\"$songanz\" " if $songanz;
print GNUTUNES "cdnum=\"$cdnum\" " if $cdnum;
print GNUTUNES "cds=\"$cdanz\" " if $cdanz;
print GNUTUNES "year=\"$year\" " if $year;


for(my $i=1;$i<=int(@jerk)-1;$i++)
{
 print GNUTUNES "$mhod_id[$i]=\"$jerk[$i]\" " if $jerk[$i] && $mhod_id[$i];
}
print GNUTUNES "/>\n";

return ($sum-$zip-1);          #black magic
}

  else {
  return "-1";
  }


}




sub xmlstring
{
my($ret) = @_;
$ret =~ s/&/&amp;/g;
$ret =~ s/"/&quot;/g;
$ret =~ s/</&lt;/g;
$ret =~ s/>/&gt;/g;
$ret =~ s/'/&apos;/g;
return $ret;
}



#get a SINGLE mhod entry:
#
# get_mhod(START_OF_MHOD);
#
# return+seek = new_mhod should be there
sub get_mhod() {
my($seek, $xl, $ml, $mty, $foo, $id, $dbg);
($seek, $dbg) = @_;

$id = getfoo($seek, 4);                    #are we lost?

$ml = getshoe($seek+8, 4);
$mty = getshoe($seek+12, 4);         #genre number
$xl = getshoe($seek+28,4);           #Entrylength


  if($id ne "6d 68 6f 64") { $ml = -1;} #is the id INcorrect?? 
  else {
  #get the TYPE of the DB-Entry
  $foo = getstr($seek+40, $xl); #string of the entry
  
  #$foo is now UTF16 (Swapped), but we need an utf8
  $foo = byteswap2($foo);
  $foo = utf16($foo)->utf8;

  return ($ml, $mty, $foo);
 }
}



sub getfoo {
#reads $anz chars from FILE and returns HEX values!
my($anz, $buffer, $xx, $xr, $start, $noseek);
($start, $anz, $noseek) = @_;
# paranoia checks
if(!$start) { $start = 0; }
if(!$anz) { $anz = "1"; }

#seek to the given position

seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);
  foreach(split(//, $buffer)) {
    $xx = sprintf("%02x ", ord($_));
   $xr = "$xr$xx";
  }
 chop($xr);# no whitespace at end
 
 return $xr;
}





sub getshoe {
#reads $anz chars from FILE and returns int 
my($anz, $buffer, $xx, $xr, $start, $noseek, $xxt);
($start, $anz, $noseek) = @_;
# paranoia checks
if(!$start) { $start = 0; }
if(!$anz) { $anz = "1"; }

#seek to the given position

seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);
   foreach(split(//, $buffer)) {
    $xx = sprintf("%02X", ord($_));
   $xr = "$xx$xr";
  }
  $xr = oct("0x".$xr);
 return $xr;
}



sub getstr {
#reads $anz chars from FILE and returns a string!
my($anz, $buffer, $xx, $xr, $start, $noseek);
($start, $anz, $noseek) = @_;
# paranoia checks
if(!$start) { $start = 0; }
if(!$anz) { $anz = "1"; }

#seek to the given position
#if 3th ARG isn't defined

seek(FILE, $start, 0);
#start reading
read(FILE, $buffer, $anz);

 return $buffer;
}



sub stdtest
{
if(!(-w "$opts{m}/iPod_Control/.gnupod/GNUtunesDB"))
{
 print "Error: Cant write to your gnuPod-file\ndid you run 'gnupod_INITpod.pl -m $opts{m}' ?\n";
 exit(1);
}
if(!(-w "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: Cant write to your iTunesDB\n";
 exit(1);
}


if ((-M "$opts{m}/iPod_Control/.gnupod/GNUtunesDB") < (-M "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: your iTunesDB is older than the GNUtunesDB.. it doesn't look like you have to run\n";
 print "tunes2pod.pl (you may want to run mktunes.pl?).\n\n";
 
  if($opts{f}) {
   print "Operation forced\n";
  }
  else {
   print "use '$0 -f -m $opts{m}' to force operation..\n exiting\n";
   exit(1);
  }
 
}

return 0;
}


###################################################

sub chck_opts
{
	if($opts{h}) #help switch
	{
		usage();
	}
	elsif(!"$opts{m}") #no ipod MP
	{
print STDERR << "EOF";
 
 Do not know where the iPod is mounted,
 please set \$IPOD_MOUNTPOINT or use
 the '-m' switch.
 
EOF
	usage();
	}
	else
	{
	return 0;
	}
}

sub usage
{
die << "EOF";

    usage: $0 [-hgfd] [-m directory]

     -h  --help             : displays this help message
     -g  --gui              : run as GUI slave
     -f  --force            : do not check timestamps
     -d  --debug            : display debug messages
     -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
}

###################################################



