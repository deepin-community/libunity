/*
 * Copyright (C) 2011 Canonical Ltd
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

/*
 * Despite the relative simplicity of this API we still need to relegate it
 * to the integration tests suite because it depends on the GSettings schema
 * from Unity.
 */

public class Main
{
  public const string LAUNCHER_SCHEMA_NAME = "com.canonical.Unity.Launcher";

  public static bool schema_exists (string schema)
  {
    return SettingsSchemaSource.get_default().lookup (schema, false) != null;
  }

  public static int main (string[] args)
  {
    /* Prepend test search path for XDG_DATA_DIRS so we can find
     * our sample .desktop files */
    var datadirs = Environment.get_variable ("XDG_DATA_DIRS");
    if (datadirs != null)
      datadirs = Config.TESTDIR + "/data:" + datadirs;
    else
      datadirs = Config.TESTDIR + "/data";
    Environment.set_variable ("XDG_DATA_DIRS", datadirs, true);
    
    /* Make sure we don't hose the user env with our tests... */
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);

    if (!schema_exists (LAUNCHER_SCHEMA_NAME))
    {
      warning ("Schema \"%s\" is not installed, skipping LauncherFavorites tests", LAUNCHER_SCHEMA_NAME);
      return 0;
    }

    Test.init (ref args);

    Test.add_data_func ("/Integration/Launcher/Favorites/UnknownApps",
                         test_has_unknown_apps);
    
    Test.add_data_func ("/Integration/Launcher/Favorites/HasSampleApps",
                         test_has_sample_apps);
    
    Test.add_data_func ("/Integration/Launcher/Favorites/Lookup",
                         test_lookup);
    
    Test.add_data_func ("/Integration/Launcher/Favorites/EnumerateIds",
                         test_enumerate_ids);
    
    Test.add_data_func ("/Integration/Launcher/Favorites/EnumerateAppInfos",
                         test_enumerate_app_infos);
    
    Test.add_data_func ("/Integration/Launcher/Favorites/Changes",
                         test_changes);

    Test.run ();

    return 0;
  }
  
  internal static void set_up () {  
    assert ("memory" == Environment.get_variable ("GSETTINGS_BACKEND"));
    var settings = new Settings (LAUNCHER_SCHEMA_NAME);
    
    string[] faves = { "rhythmbox.desktop", "file://testapp1.desktop",
                       "application://ubuntu-about.desktop",
                       "unity://special-uri" };
    settings.set_strv ("favorites", faves);
  }
  
  internal static void test_has_unknown_apps ()
  {
    set_up ();
    
    var faves = Unity.LauncherFavorites.get_default ();
    assert (!faves.has_app_id ("hulabaloola"));
    
    var appinfo = new DesktopAppInfo ("asdasdasd.desktop");
    assert (appinfo != null);
    assert (!faves.has_app_info (appinfo));
  }
  
  internal static void test_has_sample_apps ()
  {
    set_up ();
    
    var faves = Unity.LauncherFavorites.get_default ();
    assert (faves.has_app_id ("rhythmbox.desktop"));
    assert (faves.has_app_id ("testapp1.desktop"));
    assert (faves.has_app_id ("ubuntu-about.desktop"));
    
    var appinfo = new DesktopAppInfo ("rhythmbox.desktop");
    assert (faves.has_app_info (appinfo));
    appinfo = new DesktopAppInfo ("testapp1.desktop");
    assert (faves.has_app_info (appinfo));
    appinfo = new DesktopAppInfo ("ubuntu-about.desktop");
    assert (faves.has_app_info (appinfo));
  }
  
  internal static void test_lookup ()
  {
    set_up ();
    
    var faves = Unity.LauncherFavorites.get_default ();
    var appinfo = faves.lookup ("rhythmbox.desktop");
    assert (appinfo.get_name () == "Rhythmbox");
    
    appinfo = faves.lookup ("testapp1.desktop");
    assert (appinfo.get_name () == "libunity test app 1");
    
    appinfo = faves.lookup ("ubuntu-about.desktop");
    assert (appinfo.get_name () == "About Ubuntu");
    
    appinfo = faves.lookup ("pakupachupikamachu.desktop");
    assert (appinfo == null);
  }
  
  internal static void test_enumerate_ids ()
  {
    set_up ();
    
    var faves = Unity.LauncherFavorites.get_default ();
    var ids = faves.enumerate_ids ();
    
    assert (ids.length == 3);
    assert (ids[0] == "rhythmbox.desktop");
    assert (ids[1] == "testapp1.desktop");
    assert (ids[2] == "ubuntu-about.desktop");
  }

  internal static void test_enumerate_app_infos ()
  {
    set_up ();
    
    var faves = Unity.LauncherFavorites.get_default ();
    var infos = faves.enumerate_app_infos ();
    
    assert (infos.length == 3);
    assert (infos[0].get_name() == "Rhythmbox");
    assert (infos[1].get_name() == "libunity test app 1");
    assert (infos[2].get_name() == "About Ubuntu");
  }
  
 internal static void test_changes ()
  {
    set_up ();
    
    var faves = Unity.LauncherFavorites.get_default ();
    bool was_changed = false;
    
    faves.changed.connect ( () => {
      was_changed = true;
    });
    
    /* Change the faves */
    var settings = new Settings (LAUNCHER_SCHEMA_NAME);
    string[] new_faves = { "rhythmbox.desktop" };
    settings.set_strv ("favorites", new_faves);
    
    /* Wait for updates */
    var ml = new MainLoop ();
    Idle.add (() => { ml.quit(); return false; });
    ml.run ();
    
    assert (was_changed == true);
    assert (faves.enumerate_ids().length == 1);
    assert (faves.enumerate_ids()[0] == "rhythmbox.desktop");
  }
  
   

}
