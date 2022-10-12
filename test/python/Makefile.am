include $(top_srcdir)/Makefile.decl

TESTS = bug-1062331.py extras.py container-ownership.py scope-result.py
TEST_EXTENSIONS = .py

# gtester doesn't care about our TESTS_ENVIRONMENT, so can't use it
#TEST_PROGS = $(TESTS)

TESTS_ENVIRONMENT = \
	GI_TYPELIB_PATH=$(top_builddir)/src:$(top_builddir)/extras:$$GI_TYPELIB_PATH; \
	export GI_TYPELIB_PATH; \
	LD_LIBRARY_PATH=$(top_builddir)/src/.libs:$(top_builddir)/extras/.libs:$$LD_LIBRARY_PATH; \
	export LD_LIBRARY_PATH; \
	$(NULL)
PY_LOG_COMPILER = $(PYTHON)
AM_PY_LOG_FLAGS =

