#!/usr/bin/python2
from gi.repository import Unity, GLib

class TestResultSet(Unity.ResultSet):
    def __init__(self):
        Unity.ResultSet.__init__(self)
        self.results = []

    def do_add_result(self, result):
        assert(result.uri == "file:///foo")
        assert(result.title == "Title")
        assert(len(result.metadata) > 0)
        assert("whatever" in result.metadata)
        # bug in pygi? copy() shouldn't be needed
        self.results.append(result.copy())

rs = TestResultSet()
# overrides are not installed when running tests, so don't use add_result
variant = GLib.Variant('(ssuussssa{sv})', ("file:///foo", "file:///", 0, 0,
                                           "text/plain", "Title", "",
                                           "file:///foo", {'whatever': GLib.Variant("s", "foo")}))
rs.add_result_from_variant(variant)

saved_result = rs.results[0]
assert(saved_result.uri == "file:///foo")
assert(saved_result.title == "Title")
assert(len(saved_result.metadata) > 0)
assert("whatever" in saved_result.metadata)
