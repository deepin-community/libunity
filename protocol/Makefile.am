NULL =
BUILT_SOURCES =
CLEANFILES =
EXTRA_DIST =
EXTRA_FLAGS = -g

protolibdir = $(libdir)/libunity
protolib_LTLIBRARIES = \
  libunity-protocol-private.la

##
# Headers, vapi, and gir
##
unityincludedir = $(includedir)/unity/unity
nodist_unityinclude_HEADERS = unity-protocol.h

unityvapidir = $(datadir)/vala/vapi
nodist_unityvapi_DATA = \
  unity-protocol.vapi \
  $(NULL)

if !ENABLE_C_WARNINGS
  EXTRA_FLAGS += -w
endif

if ENABLE_TRACE_LOG
  EXTRA_FLAGS += -DENABLE_UNITY_TRACE_LOG
endif

#libunity-protocol
libunity_protocol_private_la_CPPFLAGS = \
  -DG_LOG_DOMAIN=\"libunity-protocol-private\" \
  -DPKGDATADIR=\"$(PKGDATADIR)\" \
  -DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
  -DDATADIR=\"$(DATADIR)\" \
  -I$(srcdir) \
  $(EXTRA_FLAGS) \
  $(LIBUNITY_CFLAGS) \
  $(COVERAGE_CFLAGS) \
  $(NULL)

libunity_protocol_private_la_LIBADD = \
  $(LIBUNITY_LIBS) -lm

libunity_protocol_private_la_LDFLAGS = \
  $(LIBPROTOCOL_LT_LDFLAGS) \
  $(COVERAGE_LDFLAGS) \
  $(NULL)

libunity_protocol_private_la_VALAFLAGS = \
  -C \
  -H unity-protocol.h -d . \
  --library unity-protocol \
  --vapi unity-protocol.vapi \
  --thread \
  --vapidir $(top_srcdir)/vapi \
  --pkg config \
  $(LIBUNITY_PACKAGES) \
  $(MAINTAINER_VALAFLAGS)

nodist_libunity_protocol_private_la_SOURCES = \
  $(libunity_protocol_private_la_VALASOURCES:.vala=.c) \
  $(NULL)

libunity_protocol_private_la_VALASOURCES = \
  protocol-icon.vala \
  protocol-scope-interface.vala \
  protocol-previews.vala \
  protocol-scope-discovery.vala \
  protocol-preview-player.vala \
  unity-scope-proxy.vala \
  unity-scope-proxy-remote.vala \
  $(NULL)

libunity_protocol_private_la_GENERATED = \
  unity-protocol.h \
  unity-protocol.vapi \
  $(NULL)

$(libunity_protocol_private_la_GENERATED): libunity_protocol_private_la_vala.stamp

libunity_protocol_private_la_vala.stamp: $(libunity_protocol_private_la_VALASOURCES)
	$(AM_V_GEN) $(VALAC) $(libunity_protocol_private_la_VALAFLAGS) $^
	@touch $@

BUILT_SOURCES += libunity_protocol_private_la_vala.stamp
EXTRA_DIST += \
  $(libunity_protocol_private_la_VALASOURCES) \
  $(NULL)

CLEANFILES += \
  *.stamp \
  $(libunity_protocol_private_la_GENERATED) \
  $(libunity_protocol_private_la_VALASOURCES:.vala=.c) \
  $(NULL)
