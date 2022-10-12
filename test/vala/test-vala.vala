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
 * Authored by Neil Jagdish Patel <neil.patel@canonical.com>
 *
 */

using Unity.Test;

public class Main
{
  public static int main (string[] args)
  {
    IOSuite io;
    AppInfoManagerSuite appinfo_manager;
    LauncherSuite launcher;
    FilterSuite filter_suite;
    PreferencesSuite preferences_suite;
    PreviewSuite preview_suite;
    ScopeSuite scope_suite;
    DiffSuite diff_suite;
    ScopeDiscoveryTestSuite scope_discovery;
    ResultsSynchronizerTestSuite synchronizer_suite;
    ScopeGroupTestSuite scope_group;

    string gsettings_schema_dir = Config.BUILDDIR+"/data";

    Environment.set_variable ("XDG_DATA_HOME", Config.TESTDIR+"/data", true);
    Environment.set_variable ("GSETTINGS_SCHEMA_DIR", gsettings_schema_dir, true);
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    try {
      Process.spawn_command_line_sync ("glib-compile-schemas " + gsettings_schema_dir);
    } catch (SpawnError e) {
      stderr.printf ("%s\n", e.message);
      return 1;
    }
    Test.init (ref args);

    /* IO utility tests */
    io = new IOSuite ();
    appinfo_manager = new AppInfoManagerSuite ();

    launcher = new LauncherSuite ();

    /* Lens Filters */
    filter_suite = new FilterSuite ();

    /* Lens Preferences */
    preferences_suite = new PreferencesSuite ();

    /* Preview test suite */
    preview_suite = new PreviewSuite ();

    /* Scope test suite */
    scope_suite = new ScopeSuite ();

    /* Diff test suite */
    diff_suite = new DiffSuite ();

    /* Scope discovery test suite */
    scope_discovery = new ScopeDiscoveryTestSuite ();

    /* Scope group test suite */
    scope_group = new ScopeGroupTestSuite ();

    synchronizer_suite = new ResultsSynchronizerTestSuite ();
      
    Test.run ();

    return 0;
  }
}
