AC_INIT(gnupod, 0.29-rc1, bug-gnupod@nongnu.org)
AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)
SKIP_CONTRIB="no"

if test $PERL; then
echo "GNUpod will use $PERL"
else
echo "** Unable to find an usable Perl binary"
echo "** Please install Perl 5.6 or a newer version"
exit 1
fi

dnl Basic modules
PERL_NEED="MP3::Info File::Copy XML::Parser Getopt::Mixed Unicode::String"
dnl Modules for extensions
ALL_MODULES="$PERL_NEED XML::Simple"

AC_ARG_ENABLE(contrib,
[  --disable-contrib       Do not install search/list and renumber],
 [if test x$enableval != xyes; then
    ALL_MODULES=$PERL_NEED
    SKIP_CONTRIB="all"
 fi])


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
  exit 1
 fi

done


AC_SUBST(SKIP_CONTRIB)
AC_SUBST(PERL)
AC_OUTPUT(Makefile)

echo
echo "I'm happy :)"
echo "use 'make install' to install GNUpod"
