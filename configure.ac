AC_INIT(GNUpod, 0.95, bug-gnupod@nongnu.org)
AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)

if test $PERL; then
echo "GNUpod will use $PERL"
else
echo "** Unable to find an usable Perl binary"
echo "** Please install Perl 5.6 or a newer version"
exit 1
fi

dnl Basic modules
ALL_MODULES="Digest::MD5 XML::Parser Unicode::String MP3::Info File::Copy Audio::FLAC"


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


AC_SUBST(PERL)
AC_OUTPUT(Makefile)

echo
echo "Looks fine.."
echo
echo "Settings:"
echo
echo    "Release:        $PACKAGE_NAME $PACKAGE_VERSION"
echo    "Prefix:         $prefix";
echo -n "Perl Version:   "
echo "print \$]" | $PERL
echo

echo
echo "-> use 'make install' to install $PACKAGE_NAME"
echo "-> use 'make uninstall' to remove $PACKAGE_NAME from $prefix"
