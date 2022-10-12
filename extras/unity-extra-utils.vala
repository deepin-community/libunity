/*
 * Copyright (C) 2012 Canonical Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 */

[CCode (gir_namespace = "UnityExtras", gir_version = "1.0")]
namespace Unity.Extras
{
  private static const string FILE_MANAGER_DBUS_NAME = "org.freedesktop.FileManager1";
  private static const string FILE_MANAGER_DBUS_PATH = "/org/freedesktop/FileManager1";

  public delegate void CreateScopeCallback ();

  [DBus (name = "org.freedesktop.FileManager1")]
  internal interface FileManagerInterface: GLib.Object
  {
    public abstract async void show_items (string[] uris, string startup_id) throws Error;
    /* These methods are currently unused
    public abstract async void show_folders (string[] uris, string startup_id) throws Error;
    public abstract async void show_item_properties (string[] uris, string startup_id) throws Error;*/
  }

  /**
   * Opens file manager showing given uri in its parent folder.
   * It tries to activate file manager using org.freedesktop.FileManager1 interface first and if it fails,
   * uses GLib.AppInfo.launch_default_for_uri.
   */
  public async void show_in_folder (string uri) throws Error
  {
    string[] uris = {uri};

    var file = File.new_for_uri (uri);
    if (file != null)
    {
      File? parent_dir = file.get_parent ();
      if (parent_dir != null)
      {
        // try to launch file manager via dbus interface first
        try
        {
          FileManagerInterface service = yield Bus.get_proxy (BusType.SESSION, FILE_MANAGER_DBUS_NAME, FILE_MANAGER_DBUS_PATH);
          yield service.show_items (uris, "");
          return;
        }
        catch (GLib.Error e)
        {
          warning ("Failed to activate file manager via dbus: '%s', uri '%s'", e.message, uri);
        }

        // fallback
        GLib.AppInfo.launch_default_for_uri (parent_dir.get_uri (), null); // may throw
        return;
      }
      else
      {
        throw new GLib.IOError.FAILED ("Failed to get parent dir for uri: '%s'".printf (uri));
      }
    }
    else
    {
      throw new GLib.IOError.FAILED ("Failed to create file object for uri: '%s'".printf (uri));
    }
  }

  /**
   * Check if a given well known DBus is owned. Failure (exception) means ownership couldn't be determined.
   * WARNING: This does sync IO!
   *
   * @param name DBus name to test for availability
   * @return true if name is available
   */
  public static bool dbus_name_has_owner (string name) throws Error
  {
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
  }

  /**
   * Attempts to own DBus name (calls dbus_name_has_owner first). CreateScopeCallback should create Lens/Scope object -
   * it will be called after initial dbus name availability check, but before acquiring the name, so this function may
   * still fail even after executing the callback.
   *
   * @param name DBus name to own
   * @param scope_creation_cb callback that creates Lens/Scope object
   * @return application instance (on success)
   */
  public static GLib.Application? dbus_own_name (string name, CreateScopeCallback scope_creation_cb) throws Error
  {
    GLib.Application? app = null;
    if (!dbus_name_has_owner (name))
    {
      scope_creation_cb ();

      app = new Application (name, ApplicationFlags.IS_SERVICE);
      app.register ();
      if (app.get_is_remote ())
      {
        app = null;
      }
      else
      {
        /* Hold()ing the app makes sure the GApplication doesn't exit */
        app.hold ();
      }
    }
    return app;
  }
}
