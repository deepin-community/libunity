#!/usr/bin/python2
from gi.repository import Unity, Gio

category_set = Unity.CategorySet.new()
cat = Unity.Category.new("example", "Example", Gio.ThemedIcon.new("test"), Unity.CategoryRenderer.DEFAULT)
category_set.add(cat)
cat = Unity.Category.new("another", "Another", Gio.ThemedIcon.new("test"), Unity.CategoryRenderer.GRID)
category_set.add(cat)
cat_list = category_set.get_categories()
#if the binding is broken there'll be double free
del cat_list
del category_set
