NULL =

if ENABLE_DOCS

FILES = \
	$(wildcard $(top_srcdir)/src/*.vala) \
	$(wildcard $(top_srcdir)/extras/*.vala) \
	$(NULL)

# earlier versions of valadoc 0.3.2 don't support the valac --version properly
# (yes valadoc 0.3.2 was 0.3.2 for far too long)
DRIVER_VERSION = $(VALADOC_DRIVER)

VALADOC_FLAGS = \
	--force \
	--target-glib=2.32 \
	--driver "$(DRIVER_VERSION)" \
	$(LIBUNITY_PACKAGES) \
	--vapidir $(top_builddir)/protocol \
	--vapidir $(top_srcdir)/vapi \
	--vapidir $(top_srcdir)/src \
	--vapidir $(top_srcdir)/extras \
	--pkg unity-protocol \
	--pkg config \
	--pkg unity-trace \
	--basedir $(top_srcdir)/src \
	--package-name unity \
	--package-version $(PACKAGE_VERSION) \
	$(FILES) \
	$(NULL)

LIBUNITY_SO_FILE = $(top_builddir)/src/.libs/libunity.so
LIBUNITY_EXTRAS_SO_FILE = $(top_builddir)/extras/.libs/libunity-extras.so

# the so isn't really a dep, but it's good for making sure the docs are fresh
valadoc: Makefile $(LIBUNITY_SO_FILE) $(LIBUNITY_EXTRAS_SO_FILE)
	$(VALADOC) \
		-o valadoc \
		$(VALADOC_FLAGS) \
		$(NULL)

# valadoc doesn't support multiple -l flags; needs to be fixed upstream.
gtkdoc: Makefile $(LIBUNITY_SO_FILE) $(LIBUNITY_EXTRAS_SO_FILE)
	$(VALADOC) \
		-X $(top_builddir)/src/unity.h \
		-X $(top_builddir)/extras/unity-extras.h \
		-X -l -X $(LIBUNITY_EXTRAS_SO_FILE) \
		-X -l -X $(LIBUNITY_SO_FILE) \
		-o gtkdoc \
		--doclet gtkdoc \
		$(VALADOC_FLAGS) \
		$(NULL)

clean-local:
	rm -rf valadoc gtkdoc

uninstall-hook:
	rm -rf $(DESTDIR)$(datadir)/gtk-doc/html/libunity

# The chmod corrects the directory permissions so that distcheck can remove the installed files.
install-data-hook: gtkdoc
	$(MKDIR_P) $(DESTDIR)$(datadir)/gtk-doc/html/libunity
	cp -d -R $(builddir)/gtkdoc/html $(DESTDIR)$(datadir)/gtk-doc/html/libunity
	chmod -R u+w $(DESTDIR)$(datadir)/gtk-doc/html/libunity

all: valadoc gtkdoc

EXTRA_DIST = gtkdoc valadoc

endif
