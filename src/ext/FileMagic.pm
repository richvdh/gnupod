package GNUpod::FileMagic;
use MP3::Info qw(:all :utf8);
#use GNUpod::QTparser;

BEGIN {
 MP3::Info::use_winamp_genres();
 MP3::Info::use_mp3_utf8(TRUE);
}
#Try to discover the file format (mp3 or QT (AAC) )
sub wtf_is {

 my($file) = @_;
 print "FooBar: $file\n";
  if(my $h = __is_mp3($file)) {
   print "--> MP3 detected\n";
   return $h;
  }
  elsif(__is_qt($file)) {
   print "--> QT File (AAC) Detected\n";
  }
  else {
   print "Unknown file type: $file\n";
  }
  return undef;
}

sub __is_qt {
 my($file) = @_;
 print "FIXME\n";
 return undef;
}

# Read mp3 tags, return undef if file is not an mp3
sub __is_mp3 {
 my($file) = @_;
 my %rh = ();
 my $h = MP3::Info::get_mp3info($file);
 
 return undef unless $h; #No mp3
 


 $rh{bitrate} = $h->{BITRATE};
 $rh{filesize} = $h->{SIZE};
 $rh{time}     = int($h->{SECS}*1000);
 $rh{fdesc}    = "MPEG ${$h}{VERSION} layer ${$h}{LAYER} file";
 $h = MP3::Info::get_mp3tag($file);
 $hs = MP3::Info::get_mp3tag($file); #Get the IDv2 tag
 
  foreach(keys %$h) {
   printf "%s => %s\n", $_, $h->{$_};
  }
 print "22222\n";
  foreach(keys %$hs) {
   printf "%s => %s\n", $_, $hs->{$_};
  }
  
 print STDERR "FIXME: UTF8 sux?\n"; 
 print STDERR "Fixme: We need to split POS/SET in songnum!\n";
   # $rh{songs}
     $rh{songnum} =  $hs->{TRCK} || $h->{TRACKNUM} || 0;
   # $rh{cdnum}
   # $rh{cds}
     $rh{year} =     $hs->{TYER} || $h->{YEAR} || 0;
     $rh{title} =    $hs->{TPE2} || $h->{TITLE} || $file || "";
     $rh{album} =    $hs->{TALB} || $h->{ALBUM} || "";
     $rh{artist} =   $hs->{TPE1} || $h->{ARTIST}  || "";
     $rh{genre} =                   $h->{GENRE}   || "";
     $rh{comment} =  $hs->{COMM} || $h->{COMMENT} || "";
     $rh{composer} =  $hs->{TCOM} || "";
     $rh{playcount}=  int($hs->{PCNT}) || 0;
foreach(keys %rh) {
 print "RET: $_ -> ".Unicode::String::utf8($rh{$_})."\n";
}

print "Fixme: we need to handle id3v2 better!\n";

 return \%rh;
}
1;
