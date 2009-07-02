AC_INIT(GNUpod, 0.99.9, bug-gnupod@nongnu.org)

echo $ECHO_N $PACKAGE_VERSION > .gnupod_version

if test -d .git -o -d CVS; then
 echo " *** THIS IS A DEVELOPMENT VERSION OF GNUPOD ***"
 echo " *** REMEMBER TO ALWAYS BACKUP YOUR DATA :-) ***"
 echo $ECHO_N "-DEVEL" >> .gnupod_version
fi

AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)
AC_PATH_PROGS(PODMAN, pod2man)

if test $PERL; then
echo "GNUpod will use $PERL"
else
echo "** Unable to find an usable Perl binary"
echo "** Please install Perl 5.6 or a newer version"
exit 1
fi

if test $PODMAN; then
echo "man page will be generated using $PODMAN"
else
echo "** Unable to find a usable pod2man binary"
echo "** Please install perldoc"
exit 1
fi

dnl Basic modules
ALL_MODULES="Digest::MD5 Digest::SHA1 XML::Parser Unicode::String MP3::Info File::Copy Date::Parse Date::Format Data::Dumper"
OPT_MODULES="Audio::FLAC::Header Ogg::Vorbis::Header::PurePerl Date::Manip"

dnl Ugly check for modules
###IFS=" " Not needed with new autoconf?!
for i in $ALL_MODULES
do

 echo -n "checking for $i..."
 $PERL -e "use $i" 2> /dev/null
 if test $? = 0; then
  echo " ok"
 else
  echo " failed!"
  echo "** You need to install $i"
  echo "** Visit <http://search.cpan.org> to get the module"
  echo "** Or try this:"
  echo "# perl -MCPAN -e 'install $i'"
  exit 1
 fi
done

for i in $OPT_MODULES
do

 echo -n "checking for optional $i..."
 $PERL -e "use $i" 2> /dev/null
 if test $? = 0; then
  echo " ok"
 else
  echo " failed!"
  echo "** $i not found. You can install it using this command:"
  echo "** # perl -MCPAN -e 'install $i'"
  echo "** ..but GNUpod will also work without $i"
  echo
 fi
done

#Test if user installed both
 $PERL -e "use Audio::FLAC" 2> /dev/null
 if test $? = 0; then
   echo "NOTE: 'Audio::FLAC' is installed, looks like this module is"
   echo "      depricated and got renamed into 'Audio::FLAC::Header'"
   echo "      GNUpod still works with 'Audio::FLAC' but maybe it would"
   echo "      be a good idea to replace the 'Audio::FLAC' installation"
   echo "      with 'Audio::FLAC::Header'"
 fi



$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.01); exit(0);"
 if test $? = 0; then
echo "installed version of MP3::Info looks good for utf8 support"
 else
  echo " ** PLEASE UPGRADE MP3::Info TO VERSION 1.01 OR NEWER **"
  echo " ** UTF8 SUPPORT FOR MP3 FILES WILL BE BROKEN !       **"
 fi


$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.20); exit(0);"
 if test $? = 0; then
echo "installed version of MP3::Info looks good for APE tag and RVA2 support"
 else
  echo " ** PLEASE UPGRADE MP3::Info TO VERSION 1.20 OR NEWER       **"
  echo " ** APE TAG AND RVA2 SUPPORT FOR MP3 FILES WILL BE BROKEN ! **"
 fi


#Check De/Encoders on system
#Do NOT add a check for 'mac', because Solaris ships
#with something different in /usr/bin/mac

ENCS="wav" #aka pcm
echo $ECHO_N "checking installed encoders..."
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
echo " done"

DECS=""
echo $ECHO_N "checking installed decoders..."
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
echo " done"


echo $ECHO_N "checking for ffmpeg with AAC support... "
ffmpeg -formats 2>&1|egrep " aac" > /dev/null
 if test $? = 0; then
  echo "found!"
  ENCS="mpeg4 $ENCS"
 else
  echo "not found, --decode=video won't work"
  ENCS="(mpeg4/no ffmpeg with aac support found) $ENCS"
 fi


echo $ECHO_N "checking for ImageMagick..."
convert --version > /dev/null 2>&1
 if test $? = 0; then
  echo "found!"
  IMAGIC="Yes"
 else
  echo "not found, --artwork won't work"
  IMAGIC="No  (ImageMagick is not installed)"
 fi



## Whoops: We dont check for 'mac' because solaris has an /usr/bin/mac .. and that's not what we are searching


AC_SUBST(PERL)
AC_OUTPUT(Makefile)

echo
echo
echo "Settings:"
echo "---------"
echo
echo $ECHO_N "Release         : "
 cat .gnupod_version
echo

echo $ECHO_N "Perl Version    : "
 $PERL tools/getVERSION.pl
echo


echo    "Prefix          : $prefix";

echo $ECHO_N "Perl INC        : "
 $PERL tools/getINC.pl
 XPINC=`$PERL tools/getINC.pl`;
echo

echo "Encoders        : $ENCS"
echo "Decoders        : $DECS"
echo "Artwork Support : $IMAGIC";


echo
echo "-> use 'make install' to install $PACKAGE_NAME"
echo "-> use 'info $PACKAGE_NAME' to read the documentation after you installed $PACKAGE_NAME"
echo "-> use 'make uninstall' to remove $PACKAGE_NAME from $prefix"
