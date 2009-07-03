AC_INIT(GNUpod, 0.99.9, bug-gnupod@nongnu.org)

$as_echo_n $PACKAGE_VERSION > .gnupod_version

if test -d .git -o -d CVS; then
 $as_echo " *** THIS IS A DEVELOPMENT VERSION OF GNUPOD ***"
 $as_echo " *** REMEMBER TO ALWAYS BACKUP YOUR DATA :-) ***"
 $as_echo_n "-DEVEL" >> .gnupod_version
fi

AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)
AC_PATH_PROGS(PODMAN, pod2man)

if test $PERL; then
$as_echo "GNUpod will use $PERL"
else
$as_echo "** Unable to find an usable Perl binary"
$as_echo "** Please install Perl 5.6 or a newer version"
exit 1
fi

if test $PODMAN; then
$as_echo "man page will be generated using $PODMAN"
else
$as_echo "** Unable to find a usable pod2man binary"
$as_echo "** Please install perldoc"
exit 1
fi

dnl Basic modules
ALL_MODULES="Digest::MD5 Digest::SHA1 XML::Parser Unicode::String MP3::Info File::Copy Date::Parse Date::Format Data::Dumper"
OPT_MODULES="Audio::FLAC::Header Ogg::Vorbis::Header::PurePerl Date::Manip"

dnl Ugly check for modules
###IFS=" " Not needed with new autoconf?!
for i in $ALL_MODULES
do

 $as_echo_n "checking for $i..."
 $PERL -e "use $i" 2> /dev/null
 if test $? = 0; then
  $as_echo " ok"
 else
  $as_echo " failed!"
  $as_echo "** You need to install $i"
  $as_echo "** Visit <http://search.cpan.org> to get the module"
  $as_echo "** Or try this:"
  $as_echo "# perl -MCPAN -e 'install $i'"
  exit 1
 fi
done

for i in $OPT_MODULES
do

 $as_echo_n "checking for optional $i..."
 $PERL -e "use $i" 2> /dev/null
 if test $? = 0; then
  $as_echo " ok"
 else
  $as_echo " failed!"
  $as_echo "** $i not found. You can install it using this command:"
  $as_echo "** # perl -MCPAN -e 'install $i'"
  $as_echo "** ..but GNUpod will also work without $i"
  echo
 fi
done

#Test if user installed both
 $PERL -e "use Audio::FLAC" 2> /dev/null
 if test $? = 0; then
   $as_echo "NOTE: 'Audio::FLAC' is installed, looks like this module is"
   $as_echo "      depricated and got renamed into 'Audio::FLAC::Header'"
   $as_echo "      GNUpod still works with 'Audio::FLAC' but maybe it would"
   $as_echo "      be a good idea to replace the 'Audio::FLAC' installation"
   $as_echo "      with 'Audio::FLAC::Header'"
 fi



$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.01); exit(0);"
 if test $? = 0; then
$as_echo "installed version of MP3::Info looks good for utf8 support"
 else
  $as_echo " ** PLEASE UPGRADE MP3::Info TO VERSION 1.01 OR NEWER **"
  $as_echo " ** UTF8 SUPPORT FOR MP3 FILES WILL BE BROKEN !       **"
 fi


$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.20); exit(0);"
 if test $? = 0; then
$as_echo "installed version of MP3::Info looks good for APE tag and RVA2 support"
 else
  $as_echo " ** PLEASE UPGRADE MP3::Info TO VERSION 1.20 OR NEWER       **"
  $as_echo " ** APE TAG AND RVA2 SUPPORT FOR MP3 FILES WILL BE BROKEN ! **"
 fi


#Check De/Encoders on system
#Do NOT add a check for 'mac', because Solaris ships
#with something different in /usr/bin/mac

ENCS="wav" #aka pcm
$as_echo_n "checking installed encoders..."
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
$as_echo " done"

DECS=""
$as_echo_n "checking installed decoders..."
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
$as_echo " done"


$as_echo_n "checking for ffmpeg with AAC support... "
ffmpeg -formats 2>&1|egrep " aac" > /dev/null
 if test $? = 0; then
  $as_echo "found!"
  ENCS="mpeg4 $ENCS"
 else
  $as_echo "not found, --decode=video won't work"
  ENCS="(mpeg4/no ffmpeg with aac support found) $ENCS"
 fi


$as_echo_n "checking for ImageMagick..."
convert --version > /dev/null 2>&1
 if test $? = 0; then
  $as_echo "found!"
  IMAGIC="Yes"
 else
  $as_echo "not found, --artwork won't work"
  IMAGIC="No  (ImageMagick is not installed)"
 fi



## Whoops: We dont check for 'mac' because solaris has an /usr/bin/mac .. and that's not what we are searching


AC_SUBST(PERL)
AC_OUTPUT(Makefile)

$as_echo
$as_echo
$as_echo "Settings:"
$as_echo "---------"
$as_echo
$as_echo_n "Release         : "
 cat .gnupod_version
$as_echo

$as_echo_n "Perl Version    : "
 $PERL tools/getVERSION.pl
$as_echo


$as_echo    "Prefix          : $prefix";

$as_echo_n "Perl INC        : "
 $PERL tools/getINC.pl
 XPINC=`$PERL tools/getINC.pl`;
$as_echo

$as_echo "Encoders        : $ENCS"
$as_echo "Decoders        : $DECS"
$as_echo "Artwork Support : $IMAGIC";


$as_echo
$as_echo "-> use 'make install' to install $PACKAGE_NAME"
$as_echo "-> use 'info $PACKAGE_NAME' to read the documentation after you installed $PACKAGE_NAME"
$as_echo "-> use 'make uninstall' to remove $PACKAGE_NAME from $prefix"
