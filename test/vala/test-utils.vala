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
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */
using Unity;

namespace Unity.Test
{
  public class UtilsTestSuite
  {
    public UtilsTestSuite ()
    {
      GLib.Test.add_data_func ("/Unit/Utils/DbusNameHasOwner", UtilsTestSuite.test_dbus_name_has_owner);
      GLib.Test.add_data_func ("/Unit/Utils/DbusOwnName", UtilsTestSuite.test_dbus_own_name);
    }

    internal static void test_dbus_name_has_owner ()
    {
      assert (Unity.Extras.dbus_name_has_owner ("foo.bar.1231231") == false);

      string name = "com.canonical.Unity.Lens.UtilsTest";
      var ml = new MainLoop ();
      Bus.own_name (BusType.SESSION, name, 0,
                    () => {},
                    () => { ml.quit (); },
                    () => {});
      run_with_timeout (ml);
      assert (Unity.Extras.dbus_name_has_owner (name) == true);
    }

    internal static void test_dbus_own_name ()
    {
      string name = "com.canonical.Unity.Lens.UtilsTest2";

      var ml = new MainLoop ();

      bool cb_called = false;
      var app = Unity.Extras.dbus_own_name (name, () => { cb_called = true; });
      assert (app != null);
      assert (cb_called == true);

      Idle.add (() => { ml.quit (); return false; });
      run_with_timeout (ml);

      cb_called = false;
      var app2 = Unity.Extras.dbus_own_name (name, () => { cb_called = true; });
      assert (app2 == null);
      assert (cb_called == false);
    }
  }
}
