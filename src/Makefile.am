NULL =
BUILT_SOURCES =
CLEANFILES =
EXTRA_DIST =
EXTRA_FLAGS = -g

lib_LTLIBRARIES = \
  libunity.la \
  $(NULL)

##
# Headers, vapi, and gir
##
unityincludedir = $(includedir)/unity/unity
nodist_unityinclude_HEADERS = unity.h lttng-component-provider.h
dist_unityinclude_HEADERS = unity-trace.h

unityvapidir = $(datadir)/vala/vapi
nodist_unityvapi_DATA = \
  unity.vapi \
  unity.deps \
  $(NULL)
dist_unityvapi_DATA = \
  unity-trace.vapi \
  unity-trace.deps \
  $(NULL)

unity.deps:
	$(AM_V_GEN)echo "$(LIBUNITY_DEPS_PACKAGES)" | sed 's/ /\n/g' | sed '/^$$/d' > $@

unitygirdir = $(datadir)/gir-1.0
unitygir_DATA = Unity-@GIR_VERSION@.gir

# these are used in tests
noinst_DATA = unity-internal.h unity-internal.vapi

if !ENABLE_C_WARNINGS
  EXTRA_FLAGS += -w
endif

if ENABLE_TRACE_LOG
  EXTRA_FLAGS += -DENABLE_UNITY_TRACE_LOG
endif

if ENABLE_LTTNG
  EXTRA_FLAGS += -DENABLE_LTTNG
endif

##
# libunity
##
PKGDATADIR=$(datadir)/unity

libunity_la_CPPFLAGS = \
  -DG_LOG_DOMAIN=\"libunity\" \
  -DPKGDATADIR=\"$(PKGDATADIR)\" \
  -DDATADIR=\"$(DATADIR)\" \
  -I$(top_builddir)/protocol \
  -I$(srcdir) \
  $(EXTRA_FLAGS) \
  $(LIBUNITY_CFLAGS) \
  $(COVERAGE_CFLAGS)

libunity_la_LIBADD = \
  $(LIBUNITY_LIBS) $(top_builddir)/protocol/libunity-protocol-private.la

libunity_la_LDFLAGS = \
  $(LIBUNITY_LT_LDFLAGS) \
  $(COVERAGE_LDFLAGS)

libunity_la_VALAFLAGS = \
  -C \
  -H unity.h -d . \
  --gir=Unity-@GIR_VERSION@.gir \
  --library unity \
  --internal-vapi=unity-internal.vapi \
  --internal-header=unity-internal.h \
  --shared-library=libunity.so.9 \
  --target-glib=2.32 \
  --thread \
  --use-header \
  --vapidir $(top_srcdir)/vapi \
  --vapidir $(top_builddir)/protocol \
  --vapidir $(srcdir) \
  --pkg unity-protocol \
  --pkg config \
  --pkg unity-trace \
  $(LIBUNITY_PACKAGES) \
  $(MAINTAINER_VALAFLAGS)

nodist_libunity_la_SOURCES = $(libunity_la_VALASOURCES:.vala=.c)
dist_libunity_la_SOURCES = \
  unity-trace.c \
  unity-trace.h \
  lttng-component-provider.h

libunity_la_VALASOURCES = \
  unity-appinfo-manager.vala \
  unity-icon.vala \
  unity-inspector.vala \
  unity-io.vala \
  unity-launcher.vala \
  unity-category.vala \
  unity-filters.vala \
  unity-preferences-manager.vala \
  unity-merge-strategy.vala \
  unity-models.vala \
  unity-search.vala \
  unity-synchronizer.vala \
  unity-previews.vala \
  unity-result-activation.vala \
  unity-scope-interface.vala \
  unity-scope-dbus-connector.vala \
  unity-scope-dbus-impl.vala \
  unity-scope-channel.vala \
  unity-deprecated-scope.vala \
  unity-deprecated-scope-impl.vala \
  unity-aggregator-scope.vala \
  unity-aggregator-scope-private.vala \
  unity-master-scope.vala \
  unity-simple-scope.vala \
  unity-scope-loader.vala \
  unity-scope-tracker.vala \
  unity-sound-menu.vala \
  unity-sound-menu-mpris.vala \
  unity-utils.vala \
  $(NULL)

libunity_la_GENERATED = \
  unity.h \
  unity.vapi \
  Unity-@GIR_VERSION@.gir \
  unity-internal.h \
  unity-internal.vapi \
  $(NULL)

$(libunity_la_GENERATED): libunity_la_vala.stamp

libunity_la_vala.stamp: $(libunity_la_VALASOURCES)
	$(AM_V_GEN) $(VALAC) $(libunity_la_VALAFLAGS) $^
	@touch $@

BUILT_SOURCES += libunity_la_vala.stamp
EXTRA_DIST += \
  $(libunity_la_VALASOURCES) \
  unity-trace.deps \
  unity-trace.vapi \
  $(NULL)

CLEANFILES += \
  *.stamp \
  $(libunity_la_GENERATED) \
  $(libunity_la_VALASOURCES:.vala=.c) \
  unity.deps

##
# Compile .typelib from .gir
##
if HAVE_INTROSPECTION
typelibdir = $(libdir)/girepository-1.0
typelib_DATA = $(unitygir_DATA:.gir=.typelib)

# Extract dlname from libunity.la
# This is what g-ir-scanner does.
libunity_dlname = \
	`$(SED) -nE "s/^dlname='([A-Za-z0-9.+-]+)'/\1/p" libunity.la`
INTROSPECTION_COMPILER_ARGS= \
	--includedir=$(srcdir) \
	-l $(libunity_dlname)
$(unitygir_DATA): libunity_la_vala.stamp
$(typelib_DATA): $(unitygir_DATA) libunity.la
	@INTROSPECTION_COMPILER@ $(INTROSPECTION_COMPILER_ARGS) -o $@ $^

CLEANFILES += $(typelib_DATA)
endif
