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

  private const string APP_PREFIX = "application://";
  private const string FILE_PREFIX = "file://";

  /* Private class to wire up the DBus stuff. Private so that we don't
   * leak DBus implementation details into the public API */
  [DBus (name = "com.canonical.Unity.LauncherEntry")]
  private class LauncherEntryDBusImpl : Object
  {
    
    public weak LauncherEntry? owner;
    
    public LauncherEntryDBusImpl (DBusConnection conn,
                                  ObjectPath     object_path,
                                  LauncherEntry  owner)
    {
      try {
        conn.register_object (object_path, this);
      } catch (IOError e) {
        warning ("Unable to connecto to session bus. Unable to control " +
                 "LauncherEntry for %s", object_path);
      }
      
      this.owner = owner;
    }

    public signal void update (string app_uri,
                               HashTable<string,Variant> properties);
    
    public HashTable<string,Variant> query ()
    {
      /*var props = new HashTable<string,Variant>(str_hash, str_equal);
      
      if (owner == null)
        return props;
      
      props.insert ("count", owner.count);
      props.insert ("count-visible", owner.count_visible);
      props.insert ("progress", owner.progress);
      props.insert ("progress-visible", owner.progress_visible);
      
      if (owner.quicklist != null)
        props.insert ("quicklist", owner._object_path);
      
      return props;*/
      if (owner == null)
        return new HashTable<string,Variant>(str_hash, str_equal);
      
      return collect_launcher_entry_properties (owner);
    }
  }

  /**
   * This class represents your control point for your application's icon
   * in the Unity Launcher. You can control properties such as a counter,
   * progress, or emblem that will be overlaid on your application's launcher
   * icon. You can also set a quicklist on it by setting the "quicklist"
   * property to point at the Dbusmenu.Menuitem which is the root of your
   * quicklist.
   *
   * Create a LauncherEntry by giving your desktop file id to the constructor
   * (eg. "myapp.desktop").
   */
  public class LauncherEntry : Dee.Serializable, Object
  {
    public string app_uri {get; set construct; }
    
    public int64 count { get; set; default = 0; }
    public bool count_visible { get; set; default = false; }
    
    public double progress { get; set; default = 0.0; }
    public bool progress_visible { get; set; default = false; }
    
    public bool urgent { get; set; default = false; }
    
    private Dbusmenu.Menuitem? _quicklist;
    public Dbusmenu.Menuitem? quicklist {
      get { return _quicklist; }
      set {
        _quicklist = value;
        if (_quicklist != null) {
          _quicklist_server = new Dbusmenu.Server (_object_path);
          _quicklist_server.root_node = _quicklist;
        }
      }
    }
        
    private HashTable<string,Variant> _queued_properties;
    private Dbusmenu.Server?          _quicklist_server;
    private uint                      _property_source_id;
    private DBusConnection            _bus;
    private LauncherEntryDBusImpl     _dbus_impl;
    internal ObjectPath                _object_path;
    
    /* Global map of LauncherEntries indexed by their application:// URIs.
     * We use this to avoid having more than one instance of a LauncherEntry
     * for the same app per process. That could give some confusing results :-)
     */
    private static HashTable<string, LauncherEntry> global_entries_map = null;     
    
    static construct {
    	Dee.Serializable.register_parser (typeof (LauncherEntry),
    	                                  new VariantType ("(sa{sv})"),
    	                                  LauncherEntry.parse_serializable);
    }
  
    construct
    {     
      _queued_properties = new HashTable<string,Variant>(str_hash, str_equal);
      _quicklist_server = null;
      _property_source_id = 0;
     
     try {       
        _bus = Bus.get_sync (BusType.SESSION);
        _object_path = new ObjectPath (@"/com/canonical/unity/launcherentry/$(app_uri.hash())");
        _dbus_impl = new LauncherEntryDBusImpl (_bus, _object_path, this);
      
        var inspector = Inspector.get_default();
        inspector.notify["unity-running"].connect (on_unity_running_changed);
      
        /* Only start queueing property change notifications if we've acquired
         * a connection to the bus (above code guaratees that). Witout a bus
         * connection things would go boom later on otherwise */
        this.notify.connect (queue_property_notification);
      } catch (IOError e) {
        critical ("Unable to connect to session bus: %s", e.message);
      }
      
    }
  
    /**
     * Create a new LauncherEntry for the desktop file id of your application.
     *
     * This constructor is private because consumers should create instances
     * via the static getter methods on this class to avoid duplicate entries
     * for the same application.
     *
     * The desktop file id is defined as the basename of your application's
     * .desktop file (including the extension), eg. myapp.desktop.
     */
    private LauncherEntry(string app_uri)
    {
      Object (app_uri : app_uri);
    }

    public static LauncherEntry get_for_app_uri (string app_uri)
    {
      if (global_entries_map == null)
        global_entries_map =
                new HashTable<string, LauncherEntry> (str_hash, str_equal);

      string real_app_uri = app_uri;
      unowned string snap_path = Environment.get_variable ("SNAP");
      unowned string snap_name = Environment.get_variable ("SNAP_NAME");

      if (snap_path != null && snap_name != null)
        {
          debug (@"App is running into a snap container ($snap_name)");
          string app = app_uri.substring (APP_PREFIX.length);

          if (app[0] == '/')
            {
              if (!FileUtils.test (app, FileTest.IS_REGULAR))
                {
                  real_app_uri = APP_PREFIX + snap_path + app;
                  debug (@"Impossible to read file $app, trying with snap namespace: $real_app_uri");
                }
            }
          else
            {
              string snap_app_prefix = snap_name + "_";

              if (!app.has_prefix (snap_app_prefix))
                {
                  real_app_uri = APP_PREFIX + snap_app_prefix + app;
                  debug (@"App uri does not contain the snap prefix, fixed: '$real_app_uri'");
                }
            }
        }

      LauncherEntry? entry = global_entries_map.lookup (real_app_uri);
      if (entry != null)
        {
          return entry;
        }

      entry = new LauncherEntry (real_app_uri);
      global_entries_map.insert (real_app_uri, entry);
      return entry;
    }

    public static LauncherEntry get_for_desktop_id (string desktop_id)
    {
      return LauncherEntry.get_for_app_uri (APP_PREFIX + desktop_id);
    }
    
    public static LauncherEntry get_for_desktop_file (string desktop_file)
    {
      return LauncherEntry.get_for_desktop_id (Path.get_basename (desktop_file));
    }
    
    /* Implement interface Dee.Serializable */
    public Variant serialize ()
    {
      /* Vala will automagically marhshal the properties into a 'a{sv}' Variant */
      HashTable<string,Variant> hash = collect_launcher_entry_properties (this);
      Variant props = hash;
      Variant _app_uri = new Variant.string (app_uri);
      return new Variant.tuple(new Variant[2]{_app_uri, props});
    }
    
    private static Object parse_serializable (Variant data)
    {
      /* Dee guarantees that data has signature "(sa{sv})" as we registered */
      string app_uri = data.get_child_value(0).get_string();
      Variant props = data.get_child_value(1);
      
      var self = LauncherEntry.get_for_app_uri (app_uri);
      
      int64 count;
      if (props.lookup("count", "x", out count))
        self.count = count;
      
      bool visible;
      if (props.lookup("count-visible", "b", out visible))
        self.count_visible = visible;
      
      double progress;
      if (props.lookup("count-visible", "d", out progress))
        self.progress = progress;
      
      if (props.lookup("progress-visible", "b", out visible))
        self.progress_visible = visible;
      
      bool urgent;
      if (props.lookup("urgent", "b", out urgent))
        self.urgent = urgent;
      
      string quicklist_path;
	  if (props.lookup("quicklist", "s", out quicklist_path))
	    {
	      if (quicklist_path != "")
          	self._object_path = new ObjectPath (quicklist_path);
        }
      
      return self;
    }
    
    private void queue_property_notification (Object self, ParamSpec pspec)
    {
      Variant? v;
      string object_path;
      
      switch (pspec.name)
      {
        case "count":
          v = this.count;
          break;
        case "count-visible":
          v = this.count_visible;
          break;
        case "progress":
          v = this.progress;
          break;
        case "progress-visible":
          v = this.progress_visible;
          break;
        case "urgent":
          v = this.urgent;
          break;
        case "quicklist":
          if (_quicklist_server != null)
            {
              _quicklist_server.get ("dbus-object", out object_path);
              v = object_path;
            }
          else
            {
              v = "";
            }
          break;
        default:
          /* Assume that this is a property we want to ignore wrt DBus */
          v = null;
          break;
      }
      
      if (v != null)
        {
          _queued_properties.insert (pspec.name, v);
        }
      
      if (_property_source_id == 0)
        {
          _property_source_id = Idle.add (dispatch_property_notification);
        }
    }
    
    private bool dispatch_property_notification ()
    {
      /* Emit DBus signal with our changes if Unity is running.
       * If it's not running at this point we'll sync all our state
       * when it gets up */
      if (Inspector.get_default().unity_running)
        _dbus_impl.update (app_uri, _queued_properties);

      /* Reset state */
      _property_source_id = 0;
      _queued_properties.remove_all ();
      
      return false;
    }
    
    /* Callback for when Unity comes or goes */
    private void on_unity_running_changed (Object _inspector, ParamSpec pspec)
    {
      Inspector inspector = _inspector as Inspector;
      
      /* If Unity has just come online sync all out props to it */
      if (inspector.unity_running)
        {
          try{
            _bus.emit_signal (null, _object_path,
                              "com.canonical.Unity.LauncherEntry",
                              "Update", this.serialize ());
          } catch (Error e) {
            warning ("Failed to emit com.canonical.Unity.LauncherEntry.Update on the session bus: %s", e.message);
          }
        }
    }
    
  } /* class Unity.LauncherEntry */

  private static HashTable<string,Variant> collect_launcher_entry_properties (LauncherEntry l)
  {
    var props = new HashTable<string,Variant>(str_hash, str_equal);
    
    props.insert ("count", l.count);
    props.insert ("count-visible", l.count_visible);
    props.insert ("progress", l.progress);
    props.insert ("progress-visible", l.progress_visible);
    props.insert ("urgent", l.urgent);
    
    if (l.quicklist != null)
      props.insert ("quicklist", l._object_path);
    
    return props;
  }
  
  public class LauncherFavorites : Object
  {
    public signal void changed ();
  
    private const string LAUNCHER_SCHEMA_NAME = "com.canonical.Unity.Launcher";
    private static LauncherFavorites? singleton = null;
    private Settings settings;
    
    /* We keep both a map and a list in order to have the correct sorting */
    private HashTable<string,AppInfo?> fav_cache;
    private string[] fav_list;

    private LauncherFavorites ()
    {
      fav_cache = new HashTable<string,AppInfo?> (str_hash, str_equal);
      var schema_src = SettingsSchemaSource.get_default().lookup (LAUNCHER_SCHEMA_NAME, false);

      if (schema_src != null)
      {
        settings = new Settings.full (schema_src, null, null);
        reset_fav_cache ();

        settings.changed["favorites"].connect (reset_fav_cache);
      }
      else
      {
        warning ("Schema \"%s\" is not installed!", LAUNCHER_SCHEMA_NAME);
      }
    }

    private void reset_fav_cache ()
    {
      fav_cache.remove_all ();
      fav_list = {};

      foreach (string id in settings.get_strv ("favorites"))
      {
        if (id.has_prefix (APP_PREFIX))
          id = id.substring (APP_PREFIX.length);
        else if (id.has_prefix (FILE_PREFIX))
          id = id.substring (FILE_PREFIX.length);
        else if (id.index_of ("://") != -1)
          continue;

        fav_list += id;
        fav_cache.insert (id, null);
      }

      changed ();
    }

    /**
     * Get the default singleton Unity.LauncherFavorites instance, creating it
     * dynamically if necessary.
     *
     * @return The singleton Unity.LauncherFavorites.
     *         If calling from C do not free this instance.
     *
     */
    public static unowned LauncherFavorites get_default ()
    {
      if (singleton == null)
        singleton = new LauncherFavorites ();
        
      return singleton;
    }
    
    public bool has_app_info (AppInfo appinfo) {
      if (appinfo.get_id () == null)
        {
          critical ("Can not look up favorite for AppInfo with NULL id");
          return false;
        }
      
      return has_app_id (appinfo.get_id ());
    }
    
    public bool has_app_id (string app_id)
    {
      return fav_cache.lookup_extended (app_id, null, null);
    }
    
    public AppInfo? lookup (string app_id)
    {
      AppInfo? appinfo;
      bool has_id = fav_cache.lookup_extended (app_id, null, out appinfo);
      
      /* If we don't have the appinfo cached, pull it out of the
       * AppInfoManager and cache it */
      if (has_id)
        {
          if (appinfo != null)
            return appinfo;
          
          var appman = AppInfoManager.get_default ();
          appinfo = appman.lookup (app_id);
          fav_cache.insert (app_id, appinfo);
          
          // FIXME: We really should return a dummy AppInfo for faves
          //        where we can't find the .desktop file...
          if (appinfo == null)
            {
              critical ("Can't find AppInfo for favorite '%s'", app_id);
              return null;
            }
          
          return appinfo;
        }
      return null;
    }
    
    public string[] enumerate_ids ()
    {
      return fav_list;
    }
    
    public AppInfo[] enumerate_app_infos ()
    {
      int i = 0;
      var infos = new AppInfo[fav_cache.size ()];
      
      foreach (string id in fav_list)
      {
        var appinfo = lookup (id);
        infos[i] = appinfo;
        i++;
      }
      
      return infos;
    }
  }
  
} /* namespace */
