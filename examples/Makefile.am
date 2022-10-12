AM_CPPFLAGS = \
  -I$(top_srcdir) \
  -I$(top_builddir)/protocol \
  -I$(top_builddir)/src \
  $(LIBUNITY_CFLAGS) \
  $(GMODULE_CFLAGS)

AM_VALAFLAGS = \
  --vapidir=$(top_builddir)/src \
  --pkg unity \
  $(LIBUNITY_PACKAGES)

unitylibdir = $(libdir)/unity

noinst_LTLIBRARIES = scope1.la scope2.la
noinst_PROGRAMS = launcher

scope1_la_VALASOURCES = scope1.vala
scope1_la_SOURCES = $(scope1_la_VALASOURCES:.vala=.c)
scope1_la_LDFLAGS = -shared -module -no-undefined -rpath $(unitylibdir)
scope1_la_LIBADD = \
  $(top_builddir)/src/libunity.la \
  $(LIBUNITY_LIBS)

scope2_la_VALASOURCES = scope2.vala
scope2_la_SOURCES = $(scope2_la_VALASOURCES:.vala=.c)
scope2_la_LDFLAGS = -shared -module -no-undefined -rpath $(unitylibdir)
scope2_la_LIBADD = \
  $(top_builddir)/src/libunity.la \
  $(LIBUNITY_LIBS)

launcher_VALASOURCES = launcher.vala
launcher_SOURCES = $(launcher_VALASOURCES:.vala=.c)
launcher_LDFLAGS = -shared -module -no-undefined -rpath $(unitylibdir)
launcher_LDADD = \
  $(top_builddir)/src/libunity.la \
  $(LIBUNITY_LIBS)

BUILT_SOURCES = \
  scope1.vala.stamp \
  scope2.vala.stamp \
  launcher.vala.stamp

scope1.vala.stamp: $(scope1_la_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

scope2.vala.stamp: $(scope2_la_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

launcher.vala.stamp: $(launcher_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

EXTRA_DIST = \
  $(scope1_la_VALASOURCES) \
  $(scope2_la_VALASOURCES) \
  $(launcher_VALASOURCES) \
  launcher.py

CLEANFILES = $(scope1_la_SOURCES) $(scope2_la_SOURCES) $(BUILT_SOURCES)

