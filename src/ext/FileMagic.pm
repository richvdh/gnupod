package GNUpod::FileMagic;
use MP3::Info qw(:all :utf8);
#use GNUpod::QTparser;

BEGIN {
 MP3::Info::use_winamp_genres();
# MP3::Info::use_utf8(1);
}
#Try to discover the file format (mp3 or QT (AAC) )
sub wtf_is {
 my($file) = @_;
 print "FooBar: $file\n";
  if(__is_mp3($file)) {
   print "--> MP3 detected\n";
  }
  elsif(__is_qt($file)) {
   print "--> QT File (AAC) Detected\n";
  }
  else {
   print "Unknown file type: $file\n";
  }
}

sub __is_qt {
 my($file) = @_;
 print "FIXME\n";
 return undef;
}

# Read mp3 tags, return undef if file is not an mp3
sub __is_mp3 {
 my($file) = @_;
 my $h = MP3::Info::get_mp3info($file);
 
 return undef unless $h; #No mp3
 
 foreach(keys(%{$h})) {
  print "INF: $_ ${$h}{$_}\n";
 }
 
    $h = MP3::Info::get_mp3tag($file);
 foreach(keys(%{$h})) {
  print "TAG: $_ ${$h}{$_}\n";
 }
 return("foo", "bar");
}
1;
