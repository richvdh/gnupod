AC_INIT(GNUpod, 0.96rc1, bug-gnupod@nongnu.org)

echo $ECHO_N $PACKAGE_VERSION > .gnupod_version

if test -d CVS; then
 echo " *** THIS IS A CVS VERSION OF GNUPOD ***"
 echo $ECHO_N "-CVS" >> .gnupod_version
fi

AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)


if test $PERL; then
echo "GNUpod will use $PERL"
else
echo "** Unable to find an usable Perl binary"
echo "** Please install Perl 5.6 or a newer version"
exit 1
fi

dnl Basic modules
ALL_MODULES="Digest::MD5 XML::Parser Unicode::String MP3::Info File::Copy"
OPT_MODULES="Audio::FLAC Ogg::Vorbis::Header::PurePerl"

dnl Ugly check for modules
IFS=" "
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
  echo " failed! (this module is OPTIONAL, GNUpod works without $i"
  echo "** $i not found. You can install it using this command:"
  echo "# perl -MCPAN -e 'install $i'"
  echo "** ..but GNUpod will also work without $i"
 fi
done


$PERL -e "use MP3::Info; exit(1) if(\$MP3::Info::VERSION < 1.01); exit(0);"
 if test $? = 0; then
echo "installed version of MP3::Info looks good"
 else
  echo " ** PLEASE UPGRADE MP3::Info TO VERSION 1.01 OR NEWER ** "
  echo " ** YOU CAN USE GNUPOD WITH YOUR CURRENT VERSION BUT  ** "
  echo " ** UTF8 SUPPORT FOR MP3 FILES WILL BE BROKEN !       **"
 fi

AC_SUBST(PERL)
AC_OUTPUT(Makefile)

echo
echo
echo "Settings:"
echo
echo $ECHO_N "Release:        "
 cat .gnupod_version
echo

echo $ECHO_N "Perl Version:   "
 $PERL tools/getVERSION.pl
echo


echo    "Prefix:         $prefix";

echo $ECHO_N "Perl INC:       "
 $PERL tools/getINC.pl
 XPINC=`$PERL tools/getINC.pl`;
echo


echo
echo "-> use 'make install' to install $PACKAGE_NAME"
echo "-> use 'make uninstall' to remove $PACKAGE_NAME from $prefix"
