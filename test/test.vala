// valac --pkg glib-2.0 --pkg unity --pkg gtk+-3.0 ./test.vala -o test

using Unity;
using GLib;

/* Check if a given well known DBus is owned.
 * WARNING: This does sync IO!  */
public static bool dbus_name_has_owner (string name)
{
  try {
    bool has_owner;
    DBusConnection bus = Bus.get_sync (BusType.SESSION);
    Variant result = bus.call_sync ("org.freedesktop.DBus",
                                    "/org/freedesktop/dbus",
                                    "org.freedesktop.DBus",
                                    "NameHasOwner",
                                    new Variant ("(s)", name),
                                    new VariantType ("(b)"),
                                    DBusCallFlags.NO_AUTO_START,
                                    -1);
    result.get ("(b)", out has_owner);
    return has_owner;
  } catch (IOError e) {
    warning ("Unable to decide whether '%s' is running: %s", name, e.message);
  }
  
  return false;
}

static int main (string[] args)
{
  if (dbus_name_has_owner ("com.canonical.Unity.Lens.Applications"))
  {
    print ("Another instance of the Unity Applications Daemon " +
           "already appears to be running.\nBailing out.\n");
    return 2;
  }

  var lens = new Unity.Lens ("/com/canonical/unity/lens/applications",
                             "applications");
  {
    lens.search_hint = "Search Tests";
    lens.visible = true;
    lens.search_in_global = true;
    
    Category[] categories = {};

    var cat = new Category ("Test 1", "gtk-cancel");
    categories += cat;

    cat = new Category ("Test 2", "gtk-add", CategoryRenderer.HORIZONTAL_TILE);
    categories += cat;

    cat = new Category ("Test 3", "gtk-apply", CategoryRenderer.FLOW);
    categories += cat;

    lens.categories = categories;

    Filter[] filters = {};

    var filter = new RatingsFilter("ratings", "Ratings");
    filters += filter;

    var filter2 = new RadioOptionFilter("installed", "Installed", "");
    filter2.add_option("today", "Today");
    filter2.add_option("this-week", "This Week");
    filter2.add_option("this-year", "This Year");
    filters += filter2;

    lens.filters = filters;

    try {
      lens.export ();
    } catch (IOError e) {
      error ("Unable to export Lens: %s", e.message);
    }

    lens.notify["active"].connect (() =>
    {
      debug ("Lens is %s", lens.active ? "active" : "not active");
    });

    Timeout.add_seconds (5, ()=>
    {
      lens.search_in_global = false;
      lens.search_hint = "Search in Timeout!";
      return false;
    });
  }

  var scope = new Unity.Scope ("/com/canonical/unity/scope/apt");
  {
    scope.sources = { "Installed", "Available" };
    scope.search_in_global = true;
    lens.add_local_scope (scope);

    scope.notify["active"].connect (() =>
    {
      debug ("Scope is %s", scope.active ? "active" : "not active");
    });

    scope.notify["active-search"].connect ((search) =>
    {
      debug ("Search changed: %s", scope.active_search.search_string);
    });

    Timeout.add_seconds (5, ()=>
    {
      scope.search_in_global = false;
      return false;
    });
  }

  var app = new Application ("com.canonical.Unity.Lens.Applications",
                             ApplicationFlags.IS_SERVICE);
  try {
    app.register ();
  } catch (Error e) {
    /* FIXME: We get this error if another daemon is already running,
     * but it uses a generic error so we can't detect this reliably... */
    print ("Failed to start applications daemon: %s\n", e.message);
    return 1;
  }
  
  if (app.get_is_remote ())
  {
    print ("Another instance of the Unity Applications Daemon " +
           "already appears to be running.\nBailing out.\n");
    return 2;
   }

  app.hold ();

  return app.run ();
}
