/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2013 Canonical Ltd
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
 * Authored by James Henstridge
 *
 */
using Unity;

namespace Unity.Test
{
  public class ScopeGroupTestSuite
  {
    public ScopeGroupTestSuite ()
    {
      GLib.Environment.set_variable ("XDG_DATA_DIRS", Config.TESTDIR + "/data", true);

      GLib.Test.add_data_func ("/Unit/ScopeGroup/Constructor",
                               test_constructor);
      GLib.Test.add_data_func ("/Unit/ScopeGroup/FileNotFound",
                               test_not_found);
    }

    internal static void test_constructor ()
    {
      var file_name = Config.TESTDIR + "/data/test-group.group";
      var config = new Protocol.ScopeGroupConfig (file_name);

      assert (config.timeout == 30);
      assert (config.scopes.length () == 3);

      var scope1 = config.scopes.data;
      assert (scope1.scope_id == "test_masterscope/childscope_1.scope");
      assert (scope1.dbus_name == "com.canonical.Unity.Scope.Test");
      assert (scope1.dbus_path == "/com/canonical/unity/scope/childscope_1");
      assert (scope1.module == "childscope_1.so");
      assert (scope1.module_type == "type");

      var scope2 = config.scopes.next.data;
      assert (scope2.scope_id == "test_masterscope/childscope_2.scope");
      assert (scope2.dbus_name == "com.canonical.Unity.Scope.Test");
      assert (scope2.dbus_path == "/com/canonical/unity/scope/childscope_2");
      assert (scope2.module == "childscope_2.so");

      var scope3 = config.scopes.next.next.data;
      assert (scope3.scope_id == "test_masterscope/childscope_3.scope");
      assert (scope3.dbus_name == "com.canonical.Unity.Scope.Test");
      assert (scope3.dbus_path == "/com/canonical/unity/scope/childscope_3");
      assert (scope3.module == "childscope_3.so");

    }

    internal static void test_not_found ()
    {
      try {
        new Protocol.ScopeGroupConfig ("no-such-file.group");
        assert_not_reached ();
      } catch (GLib.FileError.NOENT error) {
        /* expected */
      }
    }

  }
}
