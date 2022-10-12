# When releasing also remember to update the soname as instructed below
AC_INIT(libunity, 7.1.4)

AM_INIT_AUTOMAKE(AC_PACKAGE_NAME, AC_PACKAGE_VERSION)
AM_CONFIG_HEADER(config.h)
AM_MAINTAINER_MODE

m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])
AC_CONFIG_MACRO_DIR([m4])

CFLAGS="$CFLAGS"

# Before making a release, the LIBUNITY_LT_VERSION string should be updated.
# The string is of the form C:R:A.
# - If interfaces have been changed or added, but binary compatibility has
#   been preserved, change to C+1:0:A+1
# - If binary compatibility has been broken (eg removed or changed interfaces)
#   change to C+1:0:0
# - If the interface is the same as the previous version, change to C:R+1:A
LIBUNITY_LT_CURRENT=9
LIBUNITY_LT_REV=2
LIBUNITY_LT_AGE=0
LIBUNITY_LT_VERSION="$LIBUNITY_LT_CURRENT:$LIBUNITY_LT_REV:$LIBUNITY_LT_AGE"
# There's some autoconf weirdness which causes loss of [] characters,
# therefore they're doubled, the regex is to exclude unity_internal_.*
# symbols, it's so strange cause there's no lookahead support.
LIBUNITY_LT_LDFLAGS="-version-info $LIBUNITY_LT_VERSION -export-symbols-regex '^unity_([[^i]]|i[[^n]]|in[[^t]]|int[[^e]]).*'"

AC_SUBST(LIBUNITY_LT_CURRENT)
AC_SUBST(LIBUNITY_LT_VERSION)
AC_SUBST(LIBUNITY_LT_LDFLAGS)

LIBUNITY_EXTRAS_LT_CURRENT=$LIBUNITY_LT_CURRENT
LIBUNITY_EXTRAS_LT_REV=$LIBUNITY_LT_REV
LIBUNITY_EXTRAS_LT_AGE=$LIBUNITY_LT_AGE
LIBUNITY_EXTRAS_LT_VERSION="$LIBUNITY_EXTRAS_LT_CURRENT:$LIBUNITY_EXTRAS_LT_REV:$LIBUNITY_EXTRAS_LT_AGE"
LIBUNITY_EXTRAS_LT_LDFLAGS="-version-info $LIBUNITY_EXTRAS_LT_VERSION -export-symbols-regex '^unity_extras_.*'"

AC_SUBST(LIBUNITY_EXTRAS_LT_CURRENT)
AC_SUBST(LIBUNITY_EXTRAS_LT_VERSION)
AC_SUBST(LIBUNITY_EXTRAS_LT_LDFLAGS)

LIBPROTOCOL_LT_CURRENT=0
LIBPROTOCOL_LT_REV=0
LIBPROTOCOL_LT_AGE=0
LIBPROTOCOL_LT_VERSION="$LIBPROTOCOL_LT_CURRENT:$LIBPROTOCOL_LT_REV:$LIBPROTOCOL_LT_AGE"
LIBPROTOCOL_LT_LDFLAGS="-version-info $LIBPROTOCOL_LT_VERSION -export-symbols-regex '^unity_protocol_.*'"

AC_SUBST(LIBPROTOCOL_LT_CURRENT)
AC_SUBST(LIBPROTOCOL_LT_VERSION)
AC_SUBST(LIBPROTOCOL_LT_LDFLAGS)

GIR_MAJOR=7
GIR_MINOR=0
AC_SUBST([GIR_VERSION],[$GIR_MAJOR.$GIR_MINOR])
AC_DEFINE_UNQUOTED(GIR_VERSION, [$GIR_VERSION], [GIR version])

###################################################################
# Check essential build programs
###################################################################
AC_ISC_POSIX
AC_PROG_CC
AM_PROG_CC_STDC
AC_HEADER_STDC
AM_PROG_LIBTOOL
AM_PROG_VALAC([0.31.1])
AS_IF([test -z "$VALAC"], [AC_MSG_ERROR(["Can't find suitable vala compiler."])])

###################################################################
# Check for Python - we need to know where to install overrides
###################################################################
AM_PATH_PYTHON

AC_ARG_WITH([pygi_overrides_dir],
            AC_HELP_STRING([--with-pygi-overrides-dir], [Path to pygobject overrides directory]))

AC_MSG_CHECKING(for pygobject overrides directory)
if test "x$with_pygi_overrides_dir" = "x" ; then
        overrides_dir="`$PYTHON -c 'import gi; print(gi._overridesdir)' 2>/dev/null`"
    # fallback if the previous failed
	if test "x$overrides_dir" = "x" ; then
	    overrides_dir="${pyexecdir}/gi/overrides"
	fi
else
	overrides_dir="$with_pygi_overrides_dir"
fi

PYGI_OVERRIDES_DIR="$overrides_dir"
AC_SUBST(PYGI_OVERRIDES_DIR)
AC_MSG_RESULT($PYGI_OVERRIDES_DIR)

####################################################################
# Compiler generate debug code
####################################################################
AC_ARG_ENABLE([debug],
              AC_HELP_STRING([--enable-debug=@<:@no/yes@:>@], [build with debug symbols @<:@default=no@:>@]),,
              [enable_debug=no])

if test "x$enable_debug" = "xyes"; then
	CFLAGS="-ggdb $CFLAGS"
	AC_DEFINE(ENABLE_DEBUG, 1, [build with extra debug information])
fi

AM_CONDITIONAL(ENABLE_DEBUG, test "$enable_debug" = "yes")

####################################################################
# Integration tests
####################################################################
AC_ARG_ENABLE([integration-tests],
              AC_HELP_STRING([--enable-integration-tests=@<:@no/yes@:>@], [run the integration test suite @<:@default=no@:>@]),,
              [enable_integration_tests=no])

if test "x$enable_integration_tests" = "xyes"; then
	AC_DEFINE(ENABLE_INTEGRATION_TESTS, 1, [enable integration tests])
fi

AM_CONDITIONAL(ENABLE_INTEGRATION_TESTS, test "$enable_integration_tests" = "yes")

####################################################################
# Trace logging and LTTNG instrumentation
####################################################################
AC_ARG_ENABLE([lttng],
        AC_HELP_STRING([--enable-lttng=@<:@no/yes@:>@], [compile with lttng trace statements (implies trace-log=yes) @<:@default=no@:>@]),,
        [enable_lttng=no])

AM_CONDITIONAL(ENABLE_LTTNG, test "$enable_lttng" = "yes")

AC_ARG_ENABLE([trace-log],
              AC_HELP_STRING([--enable-trace-log=@<:@no/yes@:>@], [compile with trace logging statements @<:@default=no@:>@]),,
              [enable_trace_log=no])

# if LTTNG is enabled, enable trace-log automatically
if test "x$enable_lttng" = "xyes"; then
    enable_trace_log="yes"
    AC_DEFINE(ENABLE_LTTNG, 1, [enable lttng])
fi

if test "x$enable_trace_log" = "xyes"; then
   AC_DEFINE(ENABLE_TRACE_LOG, 1, [enable trace logging])
fi

AM_CONDITIONAL(ENABLE_TRACE_LOG, test "$enable_trace_log" = "yes")

####################################################################
# C compiler warnings
####################################################################
AC_ARG_ENABLE([c-warnings],
              AC_HELP_STRING([--enable-c-warnings=@<:@no/yes@:>@], [show warnings from the C compiler @<:@default=no@:>@]),,
              [enable_c_warnings=no])

if test "x$enable_c_warnings" = "xyes"; then
	AC_DEFINE(ENABLE_C_WARNINGS, 1, [show warnings from the C compiler])
fi

AM_CONDITIONAL(ENABLE_C_WARNINGS, test "$enable_c_warnings" = "yes")

####################################################################
# GObject Introspection
# (we get .gir for free with Vala, but needed for the .typelib)
####################################################################
AC_MSG_CHECKING([for gobject-introspection m4 macros])
m4_ifdef([GOBJECT_INTROSPECTION_CHECK], , AC_MSG_FAILURE([failed. Please install the package 'gobject-introspection' in order to compile libunity]))
AC_MSG_RESULT([yes])

GOBJECT_INTROSPECTION_CHECK([0.10.0])

#############################################
# Gettext
#############################################
IT_PROG_INTLTOOL([0.40.0])
GETTEXT_PACKAGE="$PACKAGE"
AC_SUBST(GETTEXT_PACKAGE)

#################################################
# Docs
#################################################

AC_ARG_ENABLE([docs],
    AS_HELP_STRING([--enable-docs], [Enable documentation generation]),
    [enable_docs=$enableval], [enable_docs="no"])

found_valadoc=no
AS_IF([test "x$enable_docs" != "xno"], [
    AC_PATH_PROG(VALADOC, valadoc, :)
    AS_IF([test -x "$VALADOC"], [
        found_valadoc=yes
        AC_SUBST(VALADOC)
        # FIXME: remove once we have valadoc >=0.3.3
        AS_IF([$VALAC --version | grep -q 0.16],
              VALADOC_DRIVER=0.16.x,
              [$VALAC --version | grep -q '0.17\|0.18'],
              VALADOC_DRIVER=0.18.x,
              VALADOC_DRIVER="`$VALAC --version`")
        AC_SUBST(VALADOC_DRIVER)
    ], [
        AS_IF([test "x$enable_docs" == "xyes"], AC_MSG_ERROR([Unable to find valadoc]))
    ])
])

AM_CONDITIONAL(ENABLE_DOCS, test "x$found_valadoc" = "xyes")

####################################################################
# Headless tests
####################################################################
AC_ARG_ENABLE([headless-tests],
              AS_HELP_STRING([--enable-headless-tests=@<:@no/yes@:>@],[enable headless test suite (requires Xvfb) @<:@default=no@:>@]),,
              [enable_headless_tests=yes])

AM_CONDITIONAL([ENABLE_HEADLESS_TESTS],[test "x$enable_headless_tests" != "xno"])

if test "x$enable_headless_tests" = "xyes"; then
  AC_PATH_PROG([XVFB],[xvfb-run])
  AC_PATH_PROG([DBUS_LAUNCH],[dbus-run-session])
fi

###########################
# gcov coverage reporting
###########################
m4_include([m4/gcov.m4])
AC_TDD_GCOV
AM_CONDITIONAL([HAVE_GCOV], [test "x$ac_cv_check_gcov" = xyes])
AM_CONDITIONAL([HAVE_LCOV], [test "x$ac_cv_check_lcov" = xyes])
AM_CONDITIONAL([HAVE_GCOVR], [test "x$ac_cv_check_gcovr" = xyes])
AC_SUBST(COVERAGE_CFLAGS)
AC_SUBST(COVERAGE_LDFLAGS)

####################################################################
# Check library deps
####################################################################
GLIB_REQUIRED=2.32
PKG_CHECK_MODULES(GLIB2, [glib-2.0 >= $GLIB_REQUIRED ])
PKG_CHECK_MODULES(GOBJECT2, [gobject-2.0 >= $GLIB_REQUIRED ])
PKG_CHECK_MODULES(GIO2, [gio-2.0 >= $GLIB_REQUIRED ])
PKG_CHECK_MODULES(GIO_UNIX2, [gio-unix-2.0])
PKG_CHECK_MODULES(DEE, [dee-1.0 >= 1.2.5])
PKG_CHECK_MODULES(DBUSMENU, [dbusmenu-glib-0.4 >= 0.3.93])
PKG_CHECK_MODULES(GTK3, [gtk+-3.0 >= 3.4.1])
PKG_CHECK_MODULES(GMODULE, [gmodule-2.0 >= 2.32.1])
PKG_CHECK_MODULES(LTTNG, [lttng-ust], HAVE_LTTNG="yes", HAVE_LTTNG="no")

AS_IF([test "x$enable_lttng" != "xno"], [
    AS_IF([test "x$HAVE_LTTNG" != "xyes"], AC_MSG_ERROR([LTTNG is missing]))
])

LIBUNITY_CFLAGS="$GLIB2_CFLAGS $GMODULE_CFLAGS $GOBJECT2_CFLAGS $GIO2_CFLAGS $GIO_UNIX2_CFLAGS $DEE_CFLAGS $DBUSMENU_CFLAGS $LTTNG_CFLAGS"
LIBUNITY_LIBS="$GLIB2_LIBS $GMODULE_LIBS $GOBJECT2_LIBS $GIO2_LIBS $GIO_UNIX2_LIBS $DEE_LIBS $DBUSMENU_LIBS $LTTNG_LIBS"
LIBUNITY_PACKAGES="--pkg glib-2.0 --pkg gmodule-2.0 --pkg gobject-2.0 --pkg gio-2.0 --pkg gio-unix-2.0 --pkg dee-1.0 --pkg Dbusmenu-0.4"
AC_SUBST(LIBUNITY_CFLAGS)
AC_SUBST(LIBUNITY_LIBS)
AC_SUBST(LIBUNITY_PACKAGES)

LIBUNITY_DEPS_PACKAGES="gobject-2.0 gio-2.0 dee-1.0 Dbusmenu-0.4"
AC_SUBST(LIBUNITY_DEPS_PACKAGES)

UNITYTOOL_CFLAGS="$GTK3_CFLAGS $GMODULE_CFLAGS"
UNITYTOOL_LIBS="$GTK3_LIBS $GMODULE_LIBS"
AC_SUBST(UNITYTOOL_CFLAGS)
AC_SUBST(UNITYTOOL_LIBS)

AC_PATH_PROG(GLIB_RESCOMPILE, glib-compile-resources)
AC_SUBST(GLIB_MKENUMS)

AC_PATH_PROG(GLIB_MKENUMS, glib-mkenums)
AC_SUBST(GLIB_MKENUMS)

AC_PATH_PROG(GLIB_GENMARSHAL, glib-genmarshal)
AC_SUBST(GLIB_GENMARSHAL)

#############################################
# GSettings macros
#############################################

GLIB_GSETTINGS

######################################################################
# Send directory information
######################################################################
AC_DEFINE_UNQUOTED(DATADIR, "${prefix}/share",[Data directory])

AC_OUTPUT([
unity.pc
unity-protocol-private.pc
unity-extras.pc
Makefile
bindings/Makefile
bindings/python/Makefile
data/com.canonical.Unity.Lenses.gschema.xml.in
data/Makefile
doc/Makefile
doc/reference/Makefile
examples/Makefile
po/Makefile.in
protocol/Makefile
src/Makefile
extras/Makefile
loader/Makefile
tools/Makefile
test/Makefile
test/C/Makefile
test/vala/Makefile
test/python/Makefile
vapi/Makefile
])

AC_MSG_NOTICE([

  libunity v$VERSION (soname $LIBUNITY_LT_VERSION)
         (protocol soname $LIBPROTOCOL_LT_VERSION)
  ------------------------------

  Build environment
    Prefix             : ${prefix}
    Build GI typelib   : ${enable_introspection}
    Documentation      : ${enable_docs}
    C warnings         : ${enable_c_warnings}
    Trace logging      : ${enable_trace_log}
    LTTNG tracepoints  : ${enable_lttng}

  Testing
    Integration tests  : ${enable_integration_tests}
    Headless tests     : ${enable_headless_tests}
    Coverage reporting : ${use_gcov}
])
