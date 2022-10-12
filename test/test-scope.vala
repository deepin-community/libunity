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
  if (dbus_name_has_owner ("com.canonical.Unity.Scope.Chromium"))
  {
    print ("Another instance of the Unity Applications Daemon " +
           "already appears to be running.\nBailing out.\n");
    return 2;
  }
 
  var scope = new Unity.Scope ("/com/canonical/unity/scope/chromium");

  scope.sources = { "Installed", "Available" };
  scope.search_in_global = true;
  try {
  scope.export ();
  } catch (IOError e) {
    error ("Unable to export Scope: $(e.message)");
  }

  scope.notify["active"].connect (() =>
  {
    debug ("Scope is %s", scope.active ? "active" : "not active");
  });

  scope.notify["active-search"].connect (() =>
  {
    debug ("Search changed: %s", scope.active_search.search_string);
    scope.active_search.finished();
  });

  scope.preview_uri.connect ((uri) =>
  {
    return new TrackPreview (1, "Animus Vox", "The Glitch Mob", "Drink The Sea", 404, {}, "http://", "Play", "", "play://", "play://", "pause://");
  });

  Timeout.add_seconds (5, ()=>
  {
    scope.search_in_global = false;
    return false;
  });

  var app = new Application ("com.canonical.Unity.Scope.Chromium",
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
