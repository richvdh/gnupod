AC_INIT(GNUpod, 0.99.9, bug-gnupod@nongnu.org)

printf "%s" $PACKAGE_VERSION > .gnupod_version

if test -d .git -o -d CVS; then
 printf "%s\n" " *** THIS IS A DEVELOPMENT VERSION OF GNUPOD ***"
 printf "%s\n" " *** REMEMBER TO ALWAYS BACKUP YOUR DATA :-) ***"
 printf "%s" "-DEVEL" >> .gnupod_version
fi

AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)
AC_PATH_PROGS(PODMAN, pod2man)

if test $PERL; then
printf "%s\n" "GNUpod will use $PERL"
else
printf "%s\n" "** Unable to find an usable Perl binary"
printf "%s\n" "** Please install Perl 5.6 or a newer version"
exit 1
fi

if test $PODMAN; then
printf "%s\n" "man page will be generated using $PODMAN"
else
printf "%s\n" "** Unable to find a usable pod2man binary"
printf "%s\n" "** Please install perldoc"
exit 1
fi

dnl Basic modules
ALL_MODULES="Digest::MD5 Digest::SHA1 XML::Parser Unicode::String MP3::Info File::Copy Date::Parse Date::Format Data::Dumper"
OPT_MODULES="Audio::FLAC::Header Ogg::Vorbis::Header::PurePerl Date::Manip"

dnl Ugly check for modules
###IFS=" " Not needed with new autoconf?!
for i in $ALL_MODULES
do

 printf "%s" "checking for $i..."
 $PERL -e "use $i" 2> /dev/null
 if test $? = 0; then
  printf "%s\n" " ok"
 else
  printf "%s\n" " failed!"
  printf "%s\n" "** You need to install $i"
  printf "%s\n" "** Visit <http://search.cpan.org> to get the module"
  printf "%s\n" "** Or try this:"
  printf "%s\n" "# perl -MCPAN -e 'install $i'"
  exit 1
 fi
done

for i in $OPT_MODULES
do

 printf "%s" "checking for optional $i..."
 $PERL -e "use $i" 2> /dev/null
 if test $? = 0; then
  printf "%s\n" " ok"
 else
  printf "%s\n" " failed!"
  printf "%s\n" "** $i not found. You can install it using this command:"
  printf "%s\n" "** # perl -MCPAN -e 'install $i'"
  printf "%s\n" "** ..but GNUpod will also work without $i"
  printf "\n"
 fi
done

#Test if user installed both
 $PERL -e "use Audio::FLAC" 2> /dev/null
 if test $? = 0; then
   printf "%s\n" "NOTE: 'Audio::FLAC' is installed, looks like this module is"
   printf "%s\n" "      depricated and got renamed into 'Audio::FLAC::Header'"
   printf "%s\n" "      GNUpod still works with 'Audio::FLAC' but maybe it would"
   printf "%s\n" "      be a good idea to replace the 'Audio::FLAC' installation"
   printf "%s\n" "      with 'Audio::FLAC::Header'"
 fi



$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.01); exit(0);"
 if test $? = 0; then
printf "%s\n" "installed version of MP3::Info looks good for utf8 support"
 else
  printf "%s\n" " ** PLEASE UPGRADE MP3::Info TO VERSION 1.01 OR NEWER **"
  printf "%s\n" " ** UTF8 SUPPORT FOR MP3 FILES WILL BE BROKEN !       **"
 fi


$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.20); exit(0);"
 if test $? = 0; then
printf "%s\n" "installed version of MP3::Info looks good for APE tag and RVA2 support"
 else
  printf "%s\n" " ** PLEASE UPGRADE MP3::Info TO VERSION 1.20 OR NEWER       **"
  printf "%s\n" " ** APE TAG AND RVA2 SUPPORT FOR MP3 FILES WILL BE BROKEN ! **"
 fi


#Check De/Encoders on system
#Do NOT add a check for 'mac', because Solaris ships
#with something different in /usr/bin/mac

ENCS="wav" #aka pcm
printf "%s" "checking installed encoders..."
ALLENCODERS="lame faac"
for i in $ALLENCODERS
do
 $i > /dev/null 2>&1
 if test $? = 1; then
  ENCS="$i $ENCS"
 else
  ENCS="(disabled $i: Binary not found) $ENCS"
 fi
done
printf "%s\n" " done"

DECS=""
printf "%s" "checking installed decoders..."
ALLDECODERS="oggdec flac timidity"
for i in $ALLDECODERS
do
 $i > /dev/null 2>&1
 if test $? -lt 2; then
  DECS="$i $DECS"
 else
  DECS="(disabled $i: Binary not found) $DECS"
 fi
done
printf "%s\n" " done"


printf "%s" "checking for ffmpeg with AAC support... "
ffmpeg -formats 2>&1|egrep " aac" > /dev/null
 if test $? = 0; then
  printf "%s\n" "found!"
  ENCS="mpeg4 $ENCS"
 else
  printf "%s\n" "not found, --decode=video won't work"
  ENCS="(mpeg4/no ffmpeg with aac support found) $ENCS"
 fi


printf "%s" "checking for ImageMagick..."
convert --version > /dev/null 2>&1
 if test $? = 0; then
  printf "%s\n" "found!"
  IMAGIC="Yes"
 else
  printf "%s\n" "not found, --artwork won't work"
  IMAGIC="No  (ImageMagick is not installed)"
 fi



## Whoops: We dont check for 'mac' because solaris has an /usr/bin/mac .. and that's not what we are searching


AC_SUBST(PERL)
AC_OUTPUT(Makefile)

printf "\n"
printf "\n"
printf "%s\n" "Settings:"
printf "%s\n" "---------"
printf "\n"
printf "%s" "Release         : "
 cat .gnupod_version
printf "\n"

printf "%s" "Perl Version    : "
 $PERL tools/getVERSION.pl
printf "\n"


printf "%s\n"    "Prefix          : $prefix";

printf "%s" "Perl INC        : "
 $PERL tools/getINC.pl
 XPINC=`$PERL tools/getINC.pl`;
printf "\n"

printf "%s\n" "Encoders        : $ENCS"
printf "%s\n" "Decoders        : $DECS"
printf "%s\n" "Artwork Support : $IMAGIC";


printf "\n"
printf "%s\n" "-> use 'make install' to install $PACKAGE_NAME"
printf "%s\n" "-> use 'info $PACKAGE_NAME' to read the documentation after you installed $PACKAGE_NAME"
printf "%s\n" "-> use 'make uninstall' to remove $PACKAGE_NAME from $prefix"
