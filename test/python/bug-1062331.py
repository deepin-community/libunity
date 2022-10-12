#!/usr/bin/python2

# no longer testing the bug from the filename
from gi.repository import Unity

generic_preview = Unity.GenericPreview.new("Title", "Description", None)
generic_preview.serialize()
