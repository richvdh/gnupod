use strict;
use MP3::Info qw(:all);
use File::Copy;
use XML::Parser;
use Getopt::Mixed qw(nextOption);
use Unicode::String qw(latin1 utf8) ;

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

use vars qw($out $max_id @duphelper %opts);

print "gnupod addsong 0.8-rc1 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool copies files to your iPod and updates the GNUtunesDB\n\n";




$opts{m} = $ENV{IPOD_MOUNTPOINT};
Getopt::Mixed::init("help h>help gui g>gui debug d>debug\
                     mount=s m>mount rebuild r>rebuild nocheck n>nocheck\
		     quiet q>quiet");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
#A Rebuild shouldn't check for dups..
$opts{n} = 1 if $opts{r};

Getopt::Mixed::cleanup();
&chck_opts;
&stdtest;


if(!$opts{g})
{
 
 if($opts{r}) {
  print "This action would *rebuild* the GNUtunesDB from scratch..\n";
  print "**NOTE** You *have* to run gnupod_INIT.pl before running this\n";
  print "         command to get a *clean* GNUtunesDB (You won't lose any\n";
  print "         MP3 files when running gnupod_INIT.pl.. just your playlists..)\n";
 }
 else {
  print "This action would add ".int(@ARGV)." Song(s)\n";
 }
 print "\nHit ENTER to continue, CTRL+C to abort\n";
 <STDIN>;
}




use_winamp_genres(); #add more generes
go("$opts{m}/iPod_Control/.gnupod/GNUtunesDB");



sub go
{
$|++;
my($file, $rnum, $entry, $clp, $transfered);
($file) = @_;

print "> Parsing old GNUtunesDB (time to pray!)\n";
my $parser = new XML::Parser(ErrorContext => 2);
$parser->setHandlers(Start => \&start_handler);
$parser->parsefile($file) if !$opts{r};
$max_id = int($max_id); #fixup
print "> Done, last used id was $max_id\n";

print "> Reading files...\n"; 

if($opts{r}) {
print "Rebuilding GNUtunesDB.. this may take some time..\n";
 foreach(glob("$opts{m}/iPod_Control/Music/*/*")) {
  $transfered += each_file($_);
 }

}
elsif($ARGV[0] ne "-") { #not from stdin
 for(my $i=0;$i<int(@ARGV);$i++) {
   $transfered += each_file($ARGV[$i]);
 }
}
else { #stdin code is from Scott Savarese
print "reading from STDIN..\n";
  while(<STDIN>) {
   chomp($_);
   $transfered += each_file($_);
  }
}


print "done, updating GNUtunesDB\n";
 write_gnudb($out);
print "-> done, added ".int($transfered)." file(s)\n";
print "-> NOTE: run 'mktunes.pl' *BEFORE* unmounting your iPod!\n";

}

sub each_file {
my ($transfered) = 0;
my ($filetoadd) = @_;

      if(-r $filetoadd && !(-d $filetoadd))
      {
        # print "File $filetoadd should be added\n";
	 my ($entry, $rnum, $hash, $clp) = mk_entry($filetoadd, $max_id); 
	 if($entry)
	{
	    $hash =~ s/(\\|\^|\$|\||\(|\)|\[|\]|\*|\+|\?|\{|\})/\\\1/g;
	    if(!$opts{n} && grep(/$hash/, @duphelper)) #duplicate
	    {
	      print "- Skipped $filetoadd - duplicate\n";
	    }
	    else
	    {
	       #we don't copy in 'rebuild' mode..
	       if(!$opts{r} && !copy("$filetoadd", "$opts{m}/iPod_Control/Music/F$rnum/$clp")) #copy failed, bad
	       {
	         print "--  FATAL  -- Failed to copy $filetoadd\n $!\nfile not addet to playlist\n";
	       }
	       else #copy ok, add file to playlist
	       {
	         print "+ $filetoadd\n" if !$opts{q};
	         $out = $out.$entry;
	         push(@duphelper, $hash); #valid mp3, add it		 
		 $transfered++; 
	       }
	    }
	 }
	 else
	 {
           print "**  ERROR  ** Not a mp3 or to many duplicates: skipped '$filetoadd'\n";
	 }
      }
      else #a dir or not readable, skip this file
      {
        print "- Skipped $filetoadd (Not a readable File)\n";
      }

return $transfered;
}



sub write_gnudb
{
my($new_content) = @_;
my($old, $i);
 open(GPH, "$opts{m}/iPod_Control/.gnupod/GNUtunesDB") or die "Could not open gnutunesdb!\nYou got zombies!\n";
  while(defined($i=<GPH>))
  {
   $old = $old.$i;
  }
  close(GPH);
  $new_content .= "</files>";
  
  #We are going to write UTF8 data.. 
  $new_content = utf8($new_content);
  
  #Replace XML header.. maybe other encoding is defined..
  #This is an ugly hack.. and will be replaced. FIXME
  $old =~ s/<\?xml[^>]+>/<?xml version="1.0"?>/m;
  $old = utf8($old);
  
  
  $old =~ s/<\/files>/$new_content/m;
  open(GPH, "> $opts{m}/iPod_Control/.gnupod/GNUtunesDB") or die "Could not open gnutunesdb! (W)\nYou got zombies!\n";
   print GPH $old;
  close (GPH);
  
}


sub start_handler()
{
my($p, @el) = @_;
my ($parent) = $p->current_element;
my($size, $time, $name, $valid);

if($el[0] eq "file" && $parent eq "files")
{
  for(my $i=1;$i<=scalar(@el)-1;$i+=2)
  {
    if($el[$i] eq "id")
     {
       if($el[$i+1] > $max_id)
        {
	 $max_id = $el[$i+1];
	}
	$valid = 1;
     }
     elsif($el[$i] eq "filesize")
     {
      $size = $el[$i+1];
     }
     elsif($el[$i] eq "time")
     {
      $time = $el[$i+1];
     }
     elsif($el[$i] eq "title")
     {
      $name = $el[$i+1];
     }
     
     
  }
  
  
  #create a entry in our duphelper
  if($valid)
  {
   my($hash) = new Unicode::String("$size/$time/$name");
   $hash = $hash->latin1();
   push(@duphelper, $hash);
  }

}

}


#creates a line in gnuPodfile format.. 
sub mk_entry
{
my($file, $inf, $info, $tag, $ret, $rand, $i, $clp, $size, $time);
($file) = @_;

$info = get_mp3info($file);
$tag  = get_mp3tag($file); 
print ">>".$tag->{GENRE}."\n" if $opts{d};
return 0 if (!$info); #$tag can fail -> in this case, we simulate a tag
print "-- WARNING --  no id3tag found for file:\n $file\nPlacing as UNKNOWN ARTIST\n" if (!$tag); #..but we warn the user

if($opts{r}) { #We are REBUILDING! No need to create a new songname..
 my @path_el = split(/\//, $file);
 
 $clp = $path_el[-1]; #The CLeanPath.. we don't have to clean it up, because the file *is* already
                      #on the iPod FS and must have a good name..
 $rand = substr($path_el[-2], 1); #Get the random foldernumber back
}
else { #Normal operation
 $clp = cleanname($file);
 $i=0; #we use random numbers to seed the files (itunes does also something like that, .. i think)
 for($rand=sprintf("%02d",int(rand(20)));(-e "$opts{m}/iPod_Control/Music/F$rand/$clp");$rand=sprintf("%02d",int(rand(20)))) #damd ugly :)
 {
  $i++;
  if($i > 40)
   {
    print "--  OUCH   -- Don't know where i could save this file to get an\nunique filename (looped $i times)\n"; #this shouldn't happen with dupchecking
    return 0;
   }
 }
}

$ret = "<file id=\"".($max_id+1)."\" ";
# if we are here, we should get name, bitrate, size and length without any problems
$ret = $ret."path=\":iPod_Control:Music:F$rand:$clp\" "; #ipod filename
$ret = $ret."bitrate=\"".$info->{BITRATE}."\" ";          #bitrate

$time = int(($info->{SECS}*1000));
$size = ((stat($file))[7]);
$ret = $ret."time=\"$time\" "; #length
$ret = $ret."filesize=\"$size\" ";        #filesize

#ID3tag checks
if($tag->{TITLE})
 { $ret = $ret."title=\"".xmlstring($tag->{TITLE})."\" "; }
else 
 { $ret = $ret."title=\"".xmlstring($clp)."\" "; } #set filename as name
 
 if($tag->{ARTIST})
 { $ret = $ret."artist=\"".xmlstring($tag->{ARTIST})."\" "; }
 else
 { $ret = $ret."artist=\"UNKNOWN\" "; }
 
if($tag->{ALBUM})
 { $ret = $ret."album=\"".xmlstring($tag->{ALBUM})."\" "; }
 else
 { $ret = $ret."album=\"UNKNOWN\" "; }


if($tag->{GENRE})
 { $ret = $ret."genre=\"".xmlstring($tag->{GENRE})."\" "; }
 
 if($tag->{YEAR})
 { $ret = $ret."year=\"".xmlstring($tag->{YEAR})."\" "; }
 if($tag->{TRACKNUM})
 { $ret = $ret."songnum=\"".xmlstring($tag->{TRACKNUM})."\" "; }
 if($tag->{COMMENT})
 { $ret = $ret."comment=\"".xmlstring($tag->{COMMENT})."\" "; }
 if($tag->{COMPOSER})
 { $ret = $ret."composer=\"".xmlstring($tag->{COMPOSER})."\" "; }
$max_id++;

#create a hashentry, but dunno push!

   my($hash) = "$size/$time/".$tag->{TITLE};



return $ret."/>\n", $rand, $hash, $clp;
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


#create a name for the file for the ipod
# -> remove bad chars
# -> limit name to 32.3 chars
sub cleanname
{
my($path, @ta, $cname, $noext, $ext, $random);
($path) = @_;
@ta = split(/\//, $path);
$cname = (@ta[int(@ta)-1]);
 $cname =~ tr/A-Za-z0-9./_/c;
 ($ext, $noext) = split(/\./, reverse($cname), 2);
 $ext = substr($ext, 0, 3);
 $noext = reverse($noext); $ext = reverse($ext);
 $noext = substr($noext, 0, 56); #limit to 56 + $random (3) . (1) + $ext (max 3) -> 64 chars
 $random = sprintf("%03d", int(rand(1000)));
 return "$noext$random.$ext";
}



sub stdtest
{
if(!(-w "$opts{m}/iPod_Control/.gnupod/GNUtunesDB"))
{
 print "Error: Cant write to your gnuPod-file\ndid you run 'gnupod_INITpod.pl' ?\n";
 exit(1);
}
if(!(-w "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: Cant write to your iTunesDB\ndid you run 'gnupod_INITpod.pl' ?\n";
 exit(1);
}

if ((-M "$opts{m}/iPod_Control/.gnupod/GNUtunesDB") > (-M "$opts{m}/iPod_Control/iTunes/iTunesDB"))
{
 print "Error: your gnuPod-file is older than your iTunesDB! (Last update not done with gnuPod?)\n";
 print "Please run this command to correct this problem:\n";
 print "tunes2pod.pl -m \$IPOD_MOUNTPOINT\n\n";
 print "This command will update your current gnuPodfile with the contents of your (newer) iTunesDB\n";
 exit(1);
}

return 0;
}





###################################################

sub chck_opts
{
	if(!$opts{r} && ($opts{h} || !(@ARGV))) #help switch
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

    usage: $0 [-hg] [-m directory] Files

     -h  --help             : displays this help message
     -g  --gui              : run as GUI slave
     -n  --nocheck          : do *not* check for duplicate files
     -r  --rebuild          : Rebuild GNUtunesDB file from scratch (EXPERTS)
     -q  --quiet            : Be less verbose
     -d  --debug            : display debug messages
     -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
}

###################################################


