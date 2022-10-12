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
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */

using Unity.Test;

public class Main
{
  public static int main (string[] args)
  {
    UtilsTestSuite utils_suite;
    PreviewPlayerIfaceTestSuite preview_player_suite;

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

    /* Extra-utils test suite */
    utils_suite = new UtilsTestSuite ();

    /* Preview player interface test suite */
    preview_player_suite = new PreviewPlayerIfaceTestSuite ();

    Test.run ();

    return 0;
  }
}
