NULL =
BUILT_SOURCES =
CLEANFILES =
EXTRA_DIST =

bin_PROGRAMS = \
  libunity-tool

libunity_tool_CPPFLAGS = \
  -DG_LOG_DOMAIN=\"libunity-tool\" \
  -I$(srcdir) \
  -I$(top_builddir)/src \
  -I$(top_builddir)/protocol \
  $(LIBUNITY_CFLAGS) \
  $(UNITYTOOL_CFLAGS)

if !ENABLE_C_WARNINGS
  libunity_tool_CPPFLAGS += -w
endif

if ENABLE_TRACE_LOG
  libunity_tool_CPPFLAGS += -DENABLE_UNITY_TRACE_LOG
endif

libunity_tool_LDADD = \
  $(top_builddir)/src/libunity.la \
  $(top_builddir)/protocol/libunity-protocol-private.la \
  $(LIBUNITY_LIBS) \
  $(UNITYTOOL_LIBS)

libunity_tool_VALAFLAGS = \
  -C \
  --vapidir $(top_srcdir)/vapi \
  --vapidir=$(top_builddir)/protocol \
  --vapidir=$(top_builddir)/src \
  --pkg config \
  --pkg gtk+-3.0 \
  --pkg gmodule-2.0 \
  --pkg unity-internal \
  --pkg unity-protocol \
  $(LIBUNITY_PACKAGES) \
  $(MAINTAINER_VALAFLAGS)

libunity_tool_VALASOURCES = \
  unity-tool.vala \
  unity-tool-dbus-util.vala \
  unity-tool-ui.vala \
  preview-renderer.vala \
  music-track-model-renderer.vala \
  $(NULL)

libunity_tool_UISOURCES = unity-tool-res.gresource.xml unity-tool.ui dbus-scope-connect.ui

unity-tool-res.c: $(libunity_tool_UISOURCES)
	$(AM_V_GEN)$(GLIB_RESCOMPILE) --sourcedir $(srcdir) --target=$@ --generate-source $(filter %.xml,$^)

nodist_libunity_tool_SOURCES = \
  $(libunity_tool_VALASOURCES:.vala=.c) \
  unity-tool-res.c \
  $(NULL)

BUILT_SOURCES += unity-tool-res.c unity_tool_vala.stamp
EXTRA_DIST += \
  $(libunity_tool_VALASOURCES) \
  $(libunity_tool_UISOURCES) \
  $(NULL)

unity_tool_vala.stamp: $(libunity_tool_VALASOURCES)
	$(AM_V_GEN) $(VALAC) $(libunity_tool_VALAFLAGS) $^
	@touch $@

CLEANFILES += \
  unity_tool_vala.stamp \
  unity-tool-res.c \
  $(libunity_tool_VALASOURCES:.vala=.c) \
  $(NULL)

