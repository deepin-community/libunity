/*
 * Copyright (C) 2011 Canonical, Ltd.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Authored by Mikkel Kamstrup Erlandsen <mikkel.kamstrup@canonical.com>
 *
 */

/*
 * IMPLEMENTATION NOTE:
 * We want the generated C API to be nice and not too Vala-ish. We must
 * anticipate that libunity consumers will be written in both Vala , C,
 * and through GObject Introspection
 *
 */
 
using GLib;
 
namespace Unity {

  /**
   * The Unity.Inspector is a singleton that can be used to inspect the
   * state of Unity.
   *
   * One of the most basic and most useful applications of the inspector
   * is to check if Unity is running or not.
   *
   */
  public class Inspector : Object
  {
    /**
     * Boolean property determining whether Unity is running or not. You
     * can use this property to determine whether Unity is running or not.
     */
    public bool unity_running { get { return _unity_running; } }
    private bool _unity_running = false;
    
    /**
     * Property holding the unique DBus name of the Unity process if
     * Unity is running, or null otherwise.
     */
    public string? unity_bus_name { get { return _unity_bus_name; }  }
    private string? _unity_bus_name = null;
    
    private DBusConnection    bus;
    private uint              unity_watcher;
    private static Inspector? singleton = null;
    
    /**
     * Get the default singleton Unity.Inspector instance, creating it
     * dynamically if necessary.
     *
     * @return The singleton Unity.Inspector. If calling from C do not
     *         free this instance.
     *
     */
    public static unowned Inspector get_default ()
    {
      if (singleton == null)
        singleton = new Inspector ();
        
      return singleton;
    }
    
    /* Constructor is private to bar 3rd parties from creating instances */
    private Inspector ()
    {
      try {
        bus = Bus.get_sync (BusType.SESSION);
        unity_watcher = Bus.watch_name_on_connection (bus, "com.canonical.Unity",
                                                      BusNameWatcherFlags.NONE,
                                                      on_unity_appeared,
                                                      on_unity_vanished);
        var is_running = bus.call_sync ("org.freedesktop.DBus",
                                        "/org/freedesktop/dbus",
                                        "org.freedesktop.DBus",
                                        "NameHasOwner",
                                        new Variant ("(s)", "com.canonical.Unity"),
                                        new VariantType ("(b)"),
                                        DBusCallFlags.NONE,
                                        -1);
        is_running.get ("(b)", out _unity_running);
      } catch (Error e) {
        critical ("Unable to connect to session bus: %s", e.message);
      }
      
    }
    
    private void on_unity_appeared (DBusConnection conn,
                                    string         name,
                                    string         name_owner)
    {
      if (name != "com.canonical.Unity")
        {
          critical ("Internal error in libunity: Got name owner notification " +
                    "from '%s'. Expected 'com.canonical.Unity'", name);
          return;
        }
    
      _unity_running = true;
      _unity_bus_name = name_owner;
      notify_property ("unity-running");
      notify_property ("unity-bus-name");
    }
    
    private void on_unity_vanished (DBusConnection conn,
                                    string         name)
    {
      _unity_running = false;
      _unity_bus_name = null;
      notify_property ("unity-running");
      notify_property ("unity-bus-name");
    }
    
  } /* class Unity.Inspector */
  

} /* namespace */
