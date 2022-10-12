include $(top_srcdir)/Makefile.decl

DISTCHECK_CONFIGURE_FLAGS = --enable-integration-tests=no

check_PROGRAMS = test-vala test-scope test-blacklist-crash test-extras

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_builddir)/protocol \
	-I$(top_builddir)/extras \
	-I$(top_builddir)/src \
	-DBUILDDIR=\"$(top_builddir)\" \
	-DTESTDIR=\"$(top_srcdir)/test\" \
	-DTESTVALADIR=\"$(top_srcdir)/test/vala\" \
	-DG_SETTINGS_ENABLE_BACKEND \
	-ggdb \
	$(LIBUNITY_CFLAGS) \
	$(LIBUNITY_LIBS)

if !ENABLE_C_WARNINGS
AM_CPPFLAGS += -w
endif

if ENABLE_TRACE_LOG
AM_CPPFLAGS += -DENABLE_UNITY_TRACE_LOG
endif

AM_VALAFLAGS = \
	--vapidir=$(top_builddir)/src \
	--vapidir=$(top_builddir)/protocol \
	--vapidir=$(top_builddir)/extras \
	--vapidir=$(top_srcdir)/test/vala \
	--pkg unity-protocol \
	--pkg unity-internal \
	--pkg config \
	$(LIBUNITY_PACKAGES) \
	$(MAINTAINER_VALAFLAGS) \
	$(NULL)

test_extras_AM_VALAFLAGS = \
	--vapidir=$(top_builddir)/src \
	--vapidir=$(top_builddir)/extras \
	--vapidir=$(top_srcdir)/test/vala \
	--pkg unity \
	--pkg unity-extras-internal \
	--pkg config \
	$(LIBUNITY_PACKAGES) \
	$(MAINTAINER_VALAFLAGS) \
	$(NULL)

test_libs = \
	$(top_builddir)/src/libunity.la \
	$(top_builddir)/protocol/libunity-protocol-private.la \
	$(top_builddir)/extras/libunity-extras.la \
	$(LIBUNITY_LIBS) \
	$(NULL)

if ENABLE_LTTNG
test_libs += -lurcu-bp
endif

TEST_PROGS += test-vala test-scope test-blacklist-crash test-extras

test_vala_LDADD = $(test_libs)
test_vala_LDFLAGS = -static

test_vala_VALASOURCES = \
	common.vala \
	test-appinfo-manager.vala \
	test-diff.vala \
	test-filters.vala \
	test-io.vala \
	test-launcher.vala \
	test-preferences.vala \
	test-previews.vala \
	test-scope-base.vala \
	test-scope-discovery.vala \
	test-scope-group.vala \
	test-vala.vala \
	test-results-synchronizer.vala \
	$(NULL)
nodist_test_vala_SOURCES = $(test_vala_VALASOURCES:.vala=.c)

test_scope_LDADD = $(test_libs)
test_scope_LDFLAGS = -static
test_scope_VALASOURCES = common.vala test-scope.vala
nodist_test_scope_SOURCES = $(test_scope_VALASOURCES:.vala=.c)

test_blacklist_crash_LDADD = $(test_libs)
test_blacklist_crash_VALASOURCES = blacklist-crash-1029949-test-case.vala
nodist_test_blacklist_crash_SOURCES = $(test_blacklist_crash_VALASOURCES:.vala=.c)

test_extras_LDADD = $(test_libs)
test_extras_LDFLAGS = -static

test_extras_VALASOURCES = \
	test-preview-player-iface.vala \
	test-utils.vala \
	common.vala \
	test-extras.vala \
	$(NULL)

nodist_test_extras_SOURCES = $(test_extras_VALASOURCES:.vala=.c)

BUILT_SOURCES = \
	test-vala.vala.stamp \
	test-scope.vala.stamp \
	test-blacklist-crash.vala.stamp \
	test-extras.vala.stamp \
	$(NULL)

test-vala.vala.stamp: $(test_vala_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

test-scope.vala.stamp: $(test_scope_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

test-blacklist-crash.vala.stamp: $(test_blacklist_crash_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

test-extras.vala.stamp: $(test_extras_VALASOURCES)
	$(AM_V_GEN)$(VALAC) -C $(test_extras_AM_VALAFLAGS) $(VALAFLAGS) $^
	@touch $@

include Makefile.integration_tests

EXTRA_DIST += \
	$(test_vala_VALASOURCES) \
	$(test_scope_VALASOURCES) \
	$(test_blacklist_crash_VALASOURCES) \
	$(test_extras_VALASOURCES) \
	config.vapi \
	$(NULL)

CLEANFILES = \
	*.stamp \
	$(test_vala_VALASOURCES:.vala=.c) \
	$(test_scope_VALASOURCES:.vala=.c) \
	$(test_blacklist_crash_VALASOURCES:.vala=.c) \
	$(test_extras_VALASOURCES:.vala=.c) \
	$(NULL)
