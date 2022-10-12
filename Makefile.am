SUBDIRS =	\
  data \
  protocol \
  src \
  extras \
  loader \
  bindings \
  tools \
  doc \
  examples \
  test \
  vapi \
  po

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = unity.pc unity-protocol-private.pc unity-extras.pc

EXTRA_DIST = \
	autogen.sh \
	unity.pc.in \
	unity-extras.pc.in \
	unity-protocol-private.pc.in

DISTCLEANFILES =

DISTCHECK_CONFIGURE_FLAGS = --enable-introspection

include $(top_srcdir)/Makefile.am.coverage
