/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2010 Canonical Ltd
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
 * Authored by Mikkel Kamstrup Erlandsen <mikkel.kamstrup@canonical.com>
 *
 */
using Unity;

namespace Unity.Test
{
  public class AppInfoManagerSuite
  {
    
    public AppInfoManagerSuite ()
    {
      GLib.Test.add_data_func ("/Unit/AppInfoManager/Allocation",
                               AppInfoManagerSuite.test_allocation);
      GLib.Test.add_data_func ("/Unit/AppInfoManager/ClearEmpty",
                               AppInfoManagerSuite.test_clear_empty);
      GLib.Test.add_data_func ("/Unit/AppInfoManager/SyncLookupMissing",
                               AppInfoManagerSuite.test_sync_lookup_missing);
      GLib.Test.add_data_func ("/Unit/AppInfoManager/AsyncLookupMissing",
                               AppInfoManagerSuite.test_async_lookup_missing);
      GLib.Test.add_data_func ("/Unit/AppInfoManager/SyncLookupOk",
                               AppInfoManagerSuite.test_sync_lookup_ok);
      GLib.Test.add_data_func ("/Unit/AppInfoManager/AsyncLookupOk",
                               AppInfoManagerSuite.test_async_lookup_ok);
    }

    /* Test that we can even get a valid ref to the manager */
    internal static void test_allocation()
    {
      var manager = AppInfoManager.get_default();
      assert (manager is AppInfoManager);
    }

    /* Test that we can clear an empty manager */
    internal static void test_clear_empty()
    {
      var manager = AppInfoManager.get_default();
      manager.clear ();
      manager.clear ();
    }

    /* Test that we can clear an empty manager */
    internal static void test_sync_lookup_missing()
    {
      var manager = AppInfoManager.get_default();
      assert (manager.lookup ("_foobar.desktop") == null);
      assert (manager.get_categories ("_foobar.desktop") == null);
      assert (manager.get_keywords ("_foobar.desktop") == null);
      assert (manager.get_path ("_foobar.desktop") == null);
    }

    internal static void test_async_lookup_missing()
    {
      MainLoop mainloop = new MainLoop();
      do_test_async_lookup_missing.begin(mainloop);
      mainloop.run ();
    }
    
    internal static async void do_test_async_lookup_missing (MainLoop mainloop)
    {
      var manager = AppInfoManager.get_default();
      
      try {
        AppInfo? appinfo = yield manager.lookup_async ("_foobar.desktop");
        assert (appinfo == null);
        assert (manager.get_categories ("_foobar.desktop") == null);
        assert (manager.get_keywords ("_foobar.desktop") == null);
        assert (manager.get_path ("_foobar.desktop") == null);
      } catch (Error e) {
        error ("Error reading desktop file: %s", e.message);
      }
      
      mainloop.quit ();
    }
    
    /* Test that we can lookup something which is indeed there */
    internal static void test_sync_lookup_ok()
    {
      var manager = AppInfoManager.get_default();      
      
      var info = manager.lookup ("ubuntu-about.desktop");
      assert (info != null);
      assert (info is AppInfo);
      assert ("About Ubuntu" == info.get_name ());
      
      string[]? categories = manager.get_categories ("ubuntu-about.desktop");
      assert (categories != null);
      assert (categories.length == 3);
      assert (categories[0] == "GNOME");
      assert (categories[1] == "Application");
      assert (categories[2] == "Core");
      
      string[]? keywords = manager.get_keywords ("ubuntu-about.desktop");
      assert (keywords != null);
      assert (keywords.length == 6);
      assert (keywords[0] == "about");
      assert (keywords[1] == "ubuntu");
      assert (keywords[2] == "help");
      assert (keywords[3] == "testkeyword");
      assert (keywords[4] == "thisisnotthekeywordsyourelookingfor");
      assert (keywords[5] == "neitheristhis");
      
      string path = manager.get_path ("ubuntu-about.desktop");
      string abs_path = File.new_for_path(Config.TESTDIR).resolve_relative_path("data/applications/ubuntu-about.desktop").get_path();
      assert (path == abs_path);
    }

    internal static void test_async_lookup_ok()
    {
      MainLoop mainloop = new MainLoop();
      do_test_async_lookup_ok.begin(mainloop);
      mainloop.run ();
    }
    
    internal static async void do_test_async_lookup_ok (MainLoop mainloop)
    {
      var manager = AppInfoManager.get_default();
      
      try{
        var info = yield manager.lookup_async ("ubuntu-about.desktop");
        assert (info is AppInfo);
        assert ("About Ubuntu" == info.get_name ());
      } catch (Error e) {
        error ("Error reading desktop file: %s", e.message);
      }
      
      string[]? categories = manager.get_categories ("ubuntu-about.desktop");
      assert (categories != null);
      assert (categories.length == 3);
      assert (categories[0] == "GNOME");
      assert (categories[1] == "Application");
      assert (categories[2] == "Core");
      
      string[]? keywords = manager.get_keywords ("ubuntu-about.desktop");
      assert (keywords != null);
      assert (keywords.length == 6);
      assert (keywords[0] == "about");
      assert (keywords[1] == "ubuntu");
      assert (keywords[2] == "help");
      assert (keywords[3] == "testkeyword");
      assert (keywords[4] == "thisisnotthekeywordsyourelookingfor");
      assert (keywords[5] == "neitheristhis");

      string path = manager.get_path ("ubuntu-about.desktop");
      string abs_path = File.new_for_path(Config.TESTDIR).resolve_relative_path("data/applications/ubuntu-about.desktop").get_path();
      assert (path == abs_path);
      
      mainloop.quit ();
    }
        
  }
}
