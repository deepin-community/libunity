
AM_CPPFLAGS = \
  -I$(top_srcdir) \
  -I$(top_builddir)/protocol \
  -I$(top_builddir)/src \
  $(LIBUNITY_CFLAGS)

AM_VALAFLAGS = \
  --vapidir=$(top_builddir)/src \
  --pkg unity \
  $(LIBUNITY_PACKAGES)

bin_PROGRAMS = unity-scope-loader

unity_scope_loader_VALASOURCES = \
  scope-loader.vala
unity_scope_loader_SOURCES = $(unity_scope_loader_VALASOURCES:.vala=.c)

unity_scope_loader_LDADD = \
  $(top_builddir)/src/libunity.la \
  $(top_builddir)/protocol/libunity-protocol-private.la \
  $(LIBUNITY_LIBS) \
  $(GMODULE_LIBS)

BUILT_SOURCES = \
  unity-scope-loader.vala.stamp

unity-scope-loader.vala.stamp: $(unity_scope_loader_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

EXTRA_DIST = \
  $(unity_scope_loader_VALASOURCES)
CLEANFILES = $(unity_scope_loader_SOURCES) $(BUILT_SOURCES)
