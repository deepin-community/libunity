/*
 * Copyright (C) 2010 Canonical, Ltd.
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
 * We want the generatedd C API to be nice and not too Vala-ish. We must
 * anticipate that place daemons consuming libunity will be written in
 * both Vala and C.
 *
 */

using Unity.Internal;

namespace Unity {

  /* This is a wrapper for a string[]. This is because the Vala compiler
   * doesn't work very well with maps with type <string,string[]>.
   * If we encapsulate the string[] in an object we have ref counting
   * and map generics working again */
  [Compact]
  private class StringArrayWrapper
  {
    public string[] strings;

    public void take_strings (owned string[] str_arr)
    {
      strings = (owned) str_arr;
    }
  }

  /**
   * A singleton class that caches GLib.AppInfo objects.
   * Singletons are evil, yes, but this on slightly less
   * so because the exposed API is immutable.
   *
   * To detect when any of the managed AppInfo objects changes, appears,
   * or goes away listen for the 'changed' signal.
   */
  public class AppInfoManager : Object
  {
    private static AppInfoManager singleton = null;
    
    private HashTable<string,AppInfo?> appinfo_by_id; /* id or path -> AppInfo */
    private HashTable<string,FileMonitor> monitors; /* parent uri -> monitor */
    private HashTable<string, StringArrayWrapper> categories_by_id; /* desktop id or path -> xdg cats */
    private HashTable<string, StringArrayWrapper> keywords_by_id; /* desktop id or path -> X-GNOME-Keywords and X-AppInstall-Keywords */
    private HashTable<string,string?> paths_by_id; /* desktop id -> full path to desktop file */
    private List<uint> timeout_handlers;

    private AppInfoManager ()
    {
      appinfo_by_id = new HashTable<string,AppInfo?> (str_hash, str_equal);
      categories_by_id = new HashTable<string,StringArrayWrapper> (str_hash, str_equal);
      keywords_by_id = new HashTable<string,StringArrayWrapper> (str_hash, str_equal);
      paths_by_id = new HashTable<string,string?> (str_hash, str_equal);
      timeout_handlers = new List<uint> ();

      monitors = new HashTable<string,FileMonitor> (str_hash, str_equal);
      
      foreach (string path in IO.get_system_data_dirs())
        {
          var dir = File.new_for_path (
                                 Path.build_filename (path, "applications"));
          try {            
            var monitor = dir.monitor_directory (FileMonitorFlags.NONE);
            monitor.changed.connect (on_dir_changed);
            monitors.insert (dir.get_uri(), monitor);
          } catch (IOError e) {
            warning ("Error setting up directory monitor on '%s': %s",
                     dir.get_uri (), e.message);
          }
        }
    }

    ~AppInfoManager ()
    {
      timeout_handlers.foreach ((id) =>
        {
          Source.remove (id);
        });
    }

    [Version (deprecated = true, replacement = "AppInfoManager.get_default")]
    public static AppInfoManager get_instance ()
    {
      return AppInfoManager.get_default ();
    }
    
    /**
     * Get a ref to the singleton AppInfoManager
     */
    public static AppInfoManager get_default ()
    {
      if (AppInfoManager.singleton == null)
        AppInfoManager.singleton = new AppInfoManager();      
      
      return AppInfoManager.singleton;
    }
    
    /**
     * Emitted whenever an AppInfo in any of the monitored paths change.
     * Note that @new_appinfo may be null in case it has been removed.
     */
    public signal void changed (string id, AppInfo? new_appinfo);
    
    /* Whenever something happens to a monitored file,
     * we remove it from the cache */
    private void on_dir_changed (FileMonitor mon, File file, File? other_file, FileMonitorEvent e)
    {
      uint timeout_handler = 0;

      timeout_handler = Timeout.add_seconds (2, () =>
      {
        var desktop_id = file.get_basename ();
        var path = file.get_path ();
        AppInfo? appinfo;

        if (appinfo_by_id.remove (desktop_id))
          {
            appinfo = lookup (desktop_id);
            changed (desktop_id, appinfo);
          }
      
        if (appinfo_by_id.remove (path))
          {
            appinfo = lookup (path);
            changed (path, appinfo);
          }

        timeout_handlers.remove (timeout_handler);
        return false;
      });

      timeout_handlers.append (timeout_handler);
    }
    
    /**
     * Look up an AppInfo given its desktop id or absolute path. The desktop id
     * is the base filename of the .desktop file for the application including
     * the .desktop extension.
     *
     * If the AppInfo is not already cached this method will do synchronous
     * IO to look it up.
     */
    public AppInfo? lookup (string id)
    {
      /* Check the cache. Note that null is a legal value since it means that
       * the files doesn't exist  */
      if (appinfo_by_id.lookup_extended (id, null, null))
        return appinfo_by_id.lookup (id);
    
      /* Look up by path or by desktop id */
      AppInfo? appinfo;
      KeyFile? keyfile = new KeyFile ();
      if (id.has_prefix("/"))
        {
          paths_by_id.insert (id, id);
          try {
            keyfile.load_from_file (id, KeyFileFlags.NONE);
          } catch (Error e) {
            keyfile = null;
            if (!(e is IOError.NOT_FOUND || e is KeyFileError.NOT_FOUND))
              warning ("Error loading '%s': %s", id, e.message);            
          }
          var dir = File.new_for_path (id).get_parent ();
          var dir_uri = dir.get_uri ();
          if (monitors.lookup (dir_uri) == null)
            {
              try {
                var monitor = dir.monitor_directory (FileMonitorFlags.NONE);
                monitor.changed.connect (on_dir_changed);
                monitors.insert (dir_uri, monitor);
                Trace.log_object (this, "Monitoring extra app directory: %s", dir_uri);
              } catch (IOError ioe) {
                warning ("Error setting up extra app directory monitor on '%s': %s",
                         dir_uri, ioe.message);
              }
            }
        }
      else
        {
          string path = Path.build_filename ("applications", id, null);
          string full_path = null;
          try {
            keyfile.load_from_data_dirs (path, out full_path, KeyFileFlags.NONE);
          } catch (Error e) {
            keyfile = null;
            if (!(e is IOError.NOT_FOUND || e is KeyFileError.NOT_FOUND))
                warning ("Error loading '%s': %s", id, e.message);
          }
          
          if (full_path != null) 
            {
              var file = File.new_for_path (full_path);
              file = file.resolve_relative_path(file.get_path());
              paths_by_id.insert(id, file.get_path());
            }
          else
              paths_by_id.insert(id, null);
            
        }
      
      /* If keyfile is null we had an error loading it */
      if (keyfile != null)
        {
          appinfo = new DesktopAppInfo.from_keyfile (keyfile);
          
          register_categories (id, keyfile);
          register_keywords (id, keyfile);
        }
      else
        appinfo = null;      

      /* If we don't find the file, we also cache that fact since we'll store
       * a null AppInfo in that case */
      appinfo_by_id.insert (id, appinfo);
      
      return appinfo;
    }
    
    /**
     * Look up XDG categories for for desktop id or file path @id.
     * Returns null if id is not found.
     * This method will do sync IO if the desktop file for @id is not
     * already cached. So if you are living in an async world you must first
     * do an async call to lookup_async(id) before calling this method, in which
     * case no sync io will be done.
     */
    public unowned string[]? get_categories (string id)
    {
      /* Make sure we have loaded the relevant .desktop file: */
      AppInfo? appinfo = lookup (id);
      
      if (appinfo == null)
        return null;

      unowned StringArrayWrapper result = categories_by_id[id];
      return result != null ? result.strings : null;
    }
    
    /**
     * Look up keywords for for desktop id or file path @id. The keywords will
     * be an amalgamation of the X-GNOME-Keywords and X-AppInstall-Keywords
     * fields from the .desktopfile.
     * Returns null if id is not found.
     * This method will do sync IO if the desktop file for @id is not
     * already cached. So if you are living in an async world you must first
     * do an async call to lookup_async(id) before calling this method, in which
     * case no sync io will be done.
     */
    public unowned string[]? get_keywords (string id)
    {
      /* Make sure we have loaded the relevant .desktop file: */
      AppInfo? appinfo = lookup (id);
      
      if (appinfo == null)
        return null;

      unowned StringArrayWrapper result = keywords_by_id[id];
      return result != null ? result.strings : null;
    }
	
    /**
     * Look up the full path to the desktop file for desktop id @id.
     * Returns null if @id is not found.
     * This method will do sync IO if the desktop file for @id is not
     * already cached. So if you are living in an async world you must
     * first do an async call to lookup_async(id) before calling this 
     * method, in which case no sync io will be done.
     */
     public string? get_path (string id)
     {
       AppInfo? appinfo = lookup (id);
	  
       if (appinfo == null)
         return null;
	  
         return paths_by_id.lookup (id);
     }
    
    /**
     * Look up an AppInfo given its desktop id or absolute path.
     * The desktop id is the base filename of the .desktop file for the
     * application including the .desktop extension.
     *
     * If the AppInfo is not already cached this method will do asynchronous
     * IO to look it up.
     */
    public async AppInfo? lookup_async (string id) throws Error
    {    
      /* Check the cache. Note that null is a legal value since it means that
       * the files doesn't exist  */
      if (appinfo_by_id.lookup_extended (id, null, null))
        return appinfo_by_id.lookup (id);
      
      /* Load it async */            
      size_t data_size;
      uint8[] data;
      FileInputStream input;
      
      /* Open from path or by desktop id */
      if (id.has_prefix ("/"))
        {
          var f = File.new_for_path (id);
          input = yield f.read_async (Priority.DEFAULT, null);
          var dir = f.get_parent ();
          var dir_uri = dir.get_uri ();
          if (monitors.lookup (dir_uri) == null)
            {
              try {
                var monitor = dir.monitor_directory (FileMonitorFlags.NONE);
                monitor.changed.connect (on_dir_changed);
                monitors.insert (dir_uri, monitor);
                Trace.log_object (this, "Monitoring extra app directory: %s", dir_uri);
              } catch (IOError ioe) {
                warning ("Error setting up extra app directory monitor on '%s': %s",
                         dir_uri, ioe.message);
              }
            }
        }
      else
        {
          string path = Path.build_filename ("applications", id, null);
          input = yield IO.open_from_data_dirs (path);
        }
      
      /* If we don't find the file, we also cache that fact by caching a
       * null value for that id  */
      if (input == null)
        {
          appinfo_by_id.insert (id, null);
          return null;
        }
      
      try
        {
          /* Note that we must manually free 'data' */
          yield IO.read_stream_async (input,
                                      Priority.LOW, null,
                                      out data, out data_size);
        }
      catch (Error e)
        {
          warning ("Error reading '%s': %s", id, e.message);
          return null;
        }
      
      var keyfile = new KeyFile ();
      try
        {
          keyfile.load_from_data ((string) data, data_size, KeyFileFlags.NONE);
        }
      catch (Error ee)
        {
          warning ("Error parsing '%s': %s", id, ee.message);
          return null;
        }
      
      /* Create the appinfo and cache it */
      var appinfo = new DesktopAppInfo.from_keyfile (keyfile);
      appinfo_by_id.insert (id, appinfo);
      register_categories (id, keyfile);
      register_keywords (id, keyfile);
      
      return appinfo;
    }
    
    /* Clear all cached AppInfos */
    public void clear ()
    {
      appinfo_by_id.remove_all ();
      categories_by_id.remove_all ();
      keywords_by_id.remove_all ();
	    paths_by_id.remove_all ();
      // We don't tear down fs monitors... Dunno if we should...
    }
    
    private void register_categories (string id, KeyFile keyfile)
    {
      try {
        string[] categories = keyfile.get_string_list ("Desktop Entry",
                                                       "Categories");

        var wrapper = new StringArrayWrapper ();
        wrapper.take_strings ((owned) categories);
        categories_by_id[id] = (owned) wrapper;
      } catch (KeyFileError eee) {
        /* Unknown key or group. This app has no XDG Catories */
      }
    }
    
    private void register_keywords (string id, KeyFile keyfile)
    {
      string[] gkeywords;
      string[] akeywords;
      string[] xdgkeywords;
      
      try {
        gkeywords = keyfile.get_locale_string_list ("Desktop Entry",
                                                    "X-GNOME-Keywords");
      } catch (KeyFileError e) {
        /* Unknown key or group. This app has no X-GNOME-Keywords */
        gkeywords = new string[0];
      }
      try {
        akeywords = keyfile.get_locale_string_list ("Desktop Entry",
                                                    "X-AppInstall-Keywords");
      } catch (KeyFileError e) {
        /* Unknown key or group. This app has no X-GNOME-Keywords */
        akeywords = new string[0];
      }
      try {
        xdgkeywords = keyfile.get_locale_string_list ("Desktop Entry",
                                                      "Keywords");
      } catch (KeyFileError e) {
        /* Unknown key or group. This app has no standard Keywords */
        xdgkeywords = new string[0];
      }
          
      /* Copy the two keyword types into one 'keyword' array */
      string[] keywords = new string[gkeywords.length + akeywords.length + xdgkeywords.length];
      for (int i = 0; i < gkeywords.length; i++)
      {
        keywords[i] = gkeywords[i];
      }
      for (int i = 0; i < akeywords.length; i++)
      {
        keywords[gkeywords.length + i] = akeywords[i];
      }
      for (int i = 0; i < xdgkeywords.length; i++)
      {
        keywords[gkeywords.length + akeywords.length + i] = xdgkeywords[i];
      }
          
      var wrapper = new StringArrayWrapper();
      wrapper.take_strings ((owned) keywords);
      keywords_by_id[id] = (owned) wrapper;
    }
  
  } /* class AppInfoManager */

} /* namespace */