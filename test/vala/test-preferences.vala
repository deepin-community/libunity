/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
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
 * Authored by Didier Roche <didrocks@ubuntu.com>
 *
 */
using Unity;

namespace Unity.Test
{
  public class PreferencesSuite
  {
    public PreferencesSuite ()
    {
      GLib.Test.add_data_func ("/Unit/Preferences/GsettingsLoad",
                               test_loading_remote_search_preference);
      GLib.Test.add_data_func ("/Unit/Preferences/AlwaysSearch",
                               test_always_search_preference);
      GLib.Test.add_data_func ("/Unit/Preferences/Singleton",
                               test_singleton);
    }

    internal static void test_loading_remote_search_preference ()
    {
      var p = Unity.PreferencesManager.get_default ();
      assert (p.remote_content_search == Unity.PreferencesManager.RemoteContent.NONE);

      var gp_settings = new Settings ("com.canonical.Unity.Lenses");
      gp_settings.set_string ("remote-content-search", "all");

      assert (p.remote_content_search == Unity.PreferencesManager.RemoteContent.ALL);

    }

    internal static void test_always_search_preference ()
    {
      var p = Unity.PreferencesManager.get_default ();
      assert (p.always_search.length == 4);

      string reference [4] = new string [] {"applications.scope","music.scope","videos.scope","files.scope"};
      for (int i=0; i<reference.length; i++)
      {
        assert (p.always_search[i] == reference[i]);
      }
    }

    internal static void test_singleton ()
    {
      var p1 = Unity.PreferencesManager.get_default ();
      var p2 = Unity.PreferencesManager.get_default ();

      assert (p1 == p2);
    }

  }
}
