use strict;

use XML::Parser;
use Getopt::Mixed qw(nextOption);

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



use vars qw(%opts %dull_helper %mem_eater %plists %paratt %ids);


print "gnupod_mkm3u 0.6 (C) 2002-2003 Adrian Ulrich\n";
print "Part of the gnupod-tools collection\n";
print "This tool converts your GNUtunesDB to an M3U file (useable for xmms and co.) (EXPERIMENTAL)\n\n";



$opts{m} = $ENV{IPOD_MOUNTPOINT};
$opts{o} = "./";
Getopt::Mixed::init("help h>help debug d>debug\
                     mount=s m>mount odir=s o>odir");

while(my($goption, $gvalue)=nextOption()) {
 $gvalue = 1 if !$gvalue;
 $opts{substr($goption, 0,1)} = $gvalue;
}
Getopt::Mixed::cleanup();


chck_opts(); #check getopts
go("$opts{m}/iPod_Control/.gnupod/GNUtunesDB");




sub go
{
my($file) = @_;

$| = 1;


print "\r> Parsing '$file'\n";
my $parser = new XML::Parser(ErrorContext => 2);
$parser->setHandlers(Start => \&start_handler, End => \&end_handler);
$parser->parsefile($file);
mkmpl();
print "done!\n";
exit(0);
}



sub start_handler
{
print "\r$dull_helper{files}" if $opts{s};
my($p, @el) = @_;
my ($parent) = $p->current_element;

#<files></files> has to start BEFORE <playlist>... test if we found </files> when a <playlist> starts
if($el[0] eq "playlist"){
 die "FATAL ERROR: <playlist> Element found, but no </files> was found!\n -> Correct your GNUtunesDB!\n" if !$dull_helper{files_end_found};
}
if($el[0] eq "file" && $parent eq "files")
{
  new_ipod_file(@el);
}
elsif($el[0] eq "add" && $parent eq "playlist")
 {
  new_pl_item(@el);
 }
else 
{
 print "* Ignoring element $el[0] with parent *$parent*\n" if $opts{d};
}

#set some parent info for next element

# ..hmm.. there should be a better way to
# do this.. maybe i should buy a book
# about XML::Parser

  for(my $j=1;$j<=int(@el)-1;$j+=2)
  {
   $paratt{$el[$j]} = $el[$j+1];
  }

}

sub mkmpl {
open(PL, ">$opts{o}/ALL_SONGS.m3u") or die "Could not write $opts{o}/ALL_SONGS.m3u: $!\n";
 foreach(values(%ids)) {
  print PL "$_\n";
 }
close(PL);

 foreach(keys(%plists)) {
 my $name = $_;
 print "**$name**\n";
    my @elements = split(/ /, $plists{$name});
  $name =~ tr/A-Za-z0-9\./_/c;
   open(PL, ">$opts{o}/$name.m3u") or warn "Failed to write pl $_\n";
    foreach(@elements) {
     print PL "$ids{$_}\n";
    }
   close(PL);
 }
}


sub new_ipod_file
{
 my(@el) = @_;
 my(%file_hash) = ();

# fill array with content of a <file /> line
 for(my $i=1;$i<=int(@el)-1;$i+=2)
        {
	 $file_hash{$el[$i]} = $el[$i+1]; 
	}
 die "Syntax error, aborting (need id and path)\n" if !$file_hash{path} || !$file_hash{id};
 $file_hash{path} =~ tr/:/\//;
 $file_hash{path} = $opts{m}.$file_hash{path};
 # fill array for extended PL support with information 
 foreach (keys(%file_hash))
 {
  $mem_eater{$_}{"\L$file_hash{$_}"} .= int($file_hash{id})." ";
 }
  $ids{$file_hash{id}} = $file_hash{path}
}




sub new_pl_item
{
my(@el) = @_;
my(%pl_elements, $i);


for($i=1;$i<int(@el);$i+=2) { #get every element
my @left = split(/ /, $mem_eater{$el[$i]}{"\L$el[$i+1]"});
 foreach(@left) {
  $pl_elements{$_}++; #found element with this attrib
 }
}

$i = ($i-1)/2; #reuse $i
 foreach(keys(%pl_elements)) {
 print "T[$i] $_ -> $pl_elements{$_}\n" if $opts{d};
 #add element to PL if it matched each criteria
 $plists{$paratt{name}} .= $_." " if ($pl_elements{$_} == $i);
}

print "-------\n" if $opts{d};
}





# XML parser - handler for end tags (</foo>)
sub end_handler {
 if (@_[int(@_)-1] eq "files") {
   $dull_helper{files_end_found} = 1;
 }
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

    usage: $0 [-hd] [-m directory] [-o directory]

     -h  --help             : displays this help message
     -o  --odir=directory   : output directory, default is current directory
     -d  --debug            : display debug messages
     -m, --mount=directory  : iPod mountpoint, default is \$IPOD_MOUNTPOINT

EOF
}

###################################################



