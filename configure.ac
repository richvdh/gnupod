AC_INIT(gnupod, 0.91, bug-gnupod@nongnu.org)
AC_PATH_PROGS(PERL, perl-5.8 perl-5.6 perl)

if test $PERL; then
echo "GNUpod will use $PERL"
else
echo "** Unable to find an usable Perl binary"
echo "** Please install Perl 5.6 or a newer version"
exit 1
fi

dnl Basic modules
dnl We need XML::Parser because we force XML::Simple to use it (no XML::SAX)
ALL_MODULES="XML::Parser XML::Simple Unicode::String"


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


AC_SUBST(PERL)
AC_OUTPUT(Makefile)

echo
echo "I'm happy :)"
echo "use 'make install' to install GNUpod"
