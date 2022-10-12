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
  public class LauncherSuite
  {
    public LauncherSuite ()
    {
      GLib.Test.add_data_func ("/Unit/Launcher/EmptyEntry",
                               LauncherSuite.test_empty_launcher_entry);
      GLib.Test.add_data_func ("/Unit/Launcher/SingletonEntry",
                               LauncherSuite.test_singleton_entry);
      GLib.Test.add_data_func ("/Unit/Launcher/Serializable",
                               LauncherSuite.test_serializable_entry);
    }

    internal static void test_empty_launcher_entry ()
    {
      var l = Unity.LauncherEntry.get_for_desktop_id ("foo.desktop");
      assert (l is LauncherEntry);
      assert (l.app_uri == "application://foo.desktop");
      
      assert (l.count == 0);
      assert (l.count_visible == false);
      
      assert (l.progress == 0.0);
      assert (l.progress_visible == false);
      
      assert (l.urgent == false);
      
      assert (l.quicklist == null);
    }
    
    internal static void test_singleton_entry ()
    {
      var l1 = Unity.LauncherEntry.get_for_desktop_id ("foo.desktop");
      var l2 = Unity.LauncherEntry.get_for_desktop_id ("foo.desktop");
      var l3 = Unity.LauncherEntry.get_for_app_uri ("application://foo.desktop");
      var l4 = Unity.LauncherEntry.get_for_desktop_file ("/usr/share/applications/foo.desktop");
      
      assert (l1 == l2);
      assert (l2 == l3);
      assert (l3 == l4);
    }
    
    internal static void test_serializable_entry ()
    {
      var orig = Unity.LauncherEntry.get_for_desktop_id ("foo.desktop");
      orig.count = 27;
      orig.count_visible = true;
      orig.progress = 1.0;
      orig.progress_visible = true;
      orig.urgent = true;
      
      Variant data = orig.externalize ();
      
      var copy = Dee.Serializable.parse_external (data) as Unity.LauncherEntry;
      
      assert (orig.count == copy.count);
      assert (orig.count_visible == copy.count_visible);
      assert (orig.progress > copy.progress - 0.01 &&
              orig.progress < copy.progress + 0.01);
      assert (orig.progress_visible == copy.progress_visible);
      assert (orig.urgent == copy.urgent);
      
      // FIXME: We're not testing the quicklist here, that's a bit tricky
    }
    
  }
}
