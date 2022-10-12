NULL=

#############################################################
# GSettings schemas
#############################################################
gsettings_SCHEMAS = com.canonical.Unity.Lenses.gschema.xml

PKGDATADIR=$(datadir)/unity

@GSETTINGS_RULES@

@INTLTOOL_XML_NOMERGE_RULE@

EXTRA_DIST = \
  client-scopes.json \
  client-scopes-phone.json \
  com.canonical.Unity.Lenses.gschema.xml.in.in \
  $(NULL)

jsonscopedir = $(PKGDATADIR)
jsonscope_DATA = client-scopes.json client-scopes-phone.json

CLEANFILES = \
  gschemas.compiled \
  $(gsettings_SCHEMAS)

