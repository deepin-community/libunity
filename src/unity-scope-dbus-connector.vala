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
 * Authored by Neil Jagdish Patel <neil.patel@canonical.com>
 *
 */

using GLib;

namespace Unity {

public class ScopeDBusConnector : Object
{
  public AbstractScope scope { get; construct; }

  public ScopeDBusConnector (AbstractScope scope)
  {
    Object (scope: scope);
  }

  ~ScopeDBusConnector ()
  {
    unexport ();
    if (pimpl != null) pimpl.dispose ();
  }

  private Internal.DefaultScopeDBusImpl pimpl;
  private bool exported;
  private bool name_owned;
  private ulong name_unowned_id;

  private static int proxy_usage_count = 0;

  public void export () throws Error
  {
    if (!exported) // && can_export ()
    {
      if (pimpl == null) pimpl = new Internal.DefaultScopeDBusImpl (scope);
      pimpl.on_timeout_reached.connect (on_inactivity_timeout_reached);
      pimpl.on_unexport_timeout_reached.connect (on_unexport_timeout_reached);
      pimpl.export ();
      exported = true;
      own_name ();

      proxy_usage_count++;
    }
  }

  public void unexport ()
  {
    if (exported)
    {
      pimpl.unexport ();
      exported = false;
      unown_name ();

      proxy_usage_count--;
    }
  }

  private void on_inactivity_timeout_reached ()
  {
    // there were no requests to this for a while, prepare to exit
    unown_name ();
  }

  private void on_unexport_timeout_reached ()
  {
    unexport ();
    if (proxy_usage_count == 0) quit ();
  }

  private void on_name_unowned ()
  {
    // not starting a timer here, cause it would keep this object alive
    pimpl.start_unexport_timer ();
  }

  private void own_name ()
  {
    var manager = Internal.ScopeDBusNameManager.get_default ();
    var dbus_name = scope.get_group_name ();
    manager.own_name (dbus_name);
    name_owned = true;

    if (name_unowned_id == 0)
    {
      name_unowned_id = manager.name_unowned[dbus_name].connect (
        this.on_name_unowned);
    }
  }

  private void unown_name ()
  {
    if (name_owned)
    {
      var manager = Internal.ScopeDBusNameManager.get_default ();
      var dbus_name = scope.get_group_name ();
      manager.unown_name (dbus_name);
      name_owned = false;
    }
  }

  private static MainLoop primary_loop;

  public static void run ()
  {
    if (primary_loop == null) primary_loop = new MainLoop ();

    var manager = Internal.ScopeDBusNameManager.get_default ();
    manager.acquire_names.begin ((obj, result) =>
      {
        if (!manager.acquire_names.end (result))
        {
          warning ("Failed to acquire all required D-Bus names");
          primary_loop.quit ();
        }
      });

    primary_loop.run ();
  }

  public static void quit ()
  {
    if (primary_loop != null) primary_loop.quit ();
  }
}

} /* namespace */
