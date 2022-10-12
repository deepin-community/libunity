from gi.repository import Unity, Gio, GObject, Dbusmenu

loop = GObject.MainLoop()

# Pretend to be evolution for the sake of the example 
launcher = Unity.LauncherEntry.get_for_desktop_id ("firefox.desktop")

# Show a count of 124 on the icon
launcher.set_property("count", 124)
launcher.set_property("count_visible", True)

# Set progress to 42% done 
launcher.set_property("progress", 0.42)
launcher.set_property("progress_visible", True)

# Set us as urgent. Quickly! Go! Go! Go! Now! Now!
launcher.set_property("urgent", True)

# We also want a quicklist 
ql = Dbusmenu.Menuitem.new ()
item1 = Dbusmenu.Menuitem.new ()
item1.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Item 1")
item1.property_set_bool (Dbusmenu.MENUITEM_PROP_VISIBLE, True)
item2 = Dbusmenu.Menuitem.new ()
item2.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Item 2")
item2.property_set_bool (Dbusmenu.MENUITEM_PROP_VISIBLE, True)
ql.child_append (item1)
ql.child_append (item2)
launcher.set_property("quicklist", ql)

loop.run()
