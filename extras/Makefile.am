NULL =
BUILT_SOURCES =
CLEANFILES =
EXTRA_FLAGS =

lib_LTLIBRARIES = libunity-extras.la

extrasvapidir = $(datadir)/vala/vapi
nodist_extrasvapi_DATA = \
  unity-extras.vapi \
  $(NULL)

extrasgirdir = $(datadir)/gir-1.0
extrasgir_DATA = UnityExtras-@GIR_VERSION@.gir

unity_extras_includedir = $(includedir)/unity/unity
nodist_unity_extras_include_HEADERS = unity-extras.h

libunity_extras_la_VALAFLAGS = \
  -C \
  -d . \
  -H unity-extras.h \
  --gir=UnityExtras-@GIR_VERSION@.gir \
  --library unity-extras \
  --internal-vapi=unity-extras-internal.vapi \
  --internal-header=unity-extras-internal.h \
  --shared-library=libunity-extras.so.9 \
  --thread \
  --use-header \
  --vapidir $(top_srcdir)/vapi \
  --vapidir $(top_builddir)/src \
  --vapidir $(top_builddir)/protocol \
  --pkg unity-protocol \
  --pkg config \
  --pkg unity-trace \
  --pkg unity \
  $(LIBUNITY_PACKAGES) \
  $(MAINTAINER_VALAFLAGS)

nodist_libunity_extras_la_SOURCES = \
  $(libunity_extras_la_VALASOURCES:.vala=.c) \
  $(NULL)

$(nodist_libunity_extras_la_SOURCES): libunity_extras_la_vala.stamp

libunity_extras_la_VALASOURCES = \
	unity-extra-preview-player-client.vala \
	unity-extra-utils.vala \
	$(NULL)

if !ENABLE_C_WARNINGS
  EXTRA_FLAGS += -w
endif

libunity_extras_la_CPPFLAGS = \
  -DG_LOG_DOMAIN=\"libunity-extras\" \
  -DPKGDATADIR=\"$(PKGDATADIR)\" \
  -DDATADIR=\"$(DATADIR)\" \
  -I$(srcdir) \
  -I$(top_builddir)/protocol \
  -I$(top_builddir)/src \
  $(EXTRA_FLAGS) \
  $(LIBUNITY_CFLAGS)

libunity_extras_la_LIBADD = \
  $(LIBUNITY_LIBS) $(top_builddir)/src/libunity.la

libunity_extras_la_LDFLAGS = \
  $(LIBUNITY_EXTRAS_LT_LDFLAGS) \
  $(COVERAGE_LDFLAGS)

libunity_extras_la_GENERATED = \
  unity-extras.vapi \
  UnityExtras-@GIR_VERSION@.gir \
  unity-extras-internal.h \
  unity-extras-internal.vapi \
  $(NULL)

# Used by tests
noinst_DATA = unity-extras-internal.h unity-extras-internal.vapi

$(libunity_la_GENERATED): libunity_la_vala.stamp

libunity_extras_la_vala.stamp: $(libunity_extras_la_VALASOURCES)
	$(AM_V_GEN) $(VALAC) $(libunity_extras_la_VALAFLAGS) $^
	@sed -i -e 's/"Extras/"/g;s/"extras_/"/' UnityExtras-@GIR_VERSION@.gir
	@sed -i -e 's/<parameter name="scope_creation_cb" transfer-ownership="none"/<parameter name="scope_creation_cb" transfer-ownership="none" scope="call"/' UnityExtras-@GIR_VERSION@.gir
	@touch $@

BUILT_SOURCES += libunity_extras_la_vala.stamp

CLEANFILES += \
  *.stamp \
  $(NULL)

##
# Compile .typelib from .gir
##
if HAVE_INTROSPECTION
typelibdir = $(libdir)/girepository-1.0
typelib_DATA = $(extrasgir_DATA:.gir=.typelib)

# Extract dlname from libunity.la
# This is what g-ir-scanner does.
libunity_extra_dlname = \
	`$(SED) -nE "s/^dlname='([A-Za-z0-9.+-]+)'/\1/p" libunity-extras.la`
INTROSPECTION_COMPILER_ARGS= \
	--includedir=$(srcdir) \
	-l $(libunity_extra_dlname)
$(extrasgir_DATA): libunity_extras_la_vala.stamp
$(typelib_DATA): $(extrasgir_DATA) libunity-extras.la
	@INTROSPECTION_COMPILER@ $(INTROSPECTION_COMPILER_ARGS) -o $@ $^

CLEANFILES += $(typelib_DATA)
endif
