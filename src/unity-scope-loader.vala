/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2013 Canonical, Ltd.
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
 * Authored by James Henstridge <james.henstridge@canonical.com>
 *
 */

namespace Unity
{

[CCode (has_target = false)]
private delegate List<Unity.AbstractScope> LoadScopesFunction () throws Error;
[CCode (has_target = false)]
private delegate int GetVersionFunction ();

public class ScopeLoader : Object
{
  private List<ScopeDBusConnector> connectors;
  private HashTable<string,int> loaded_modules;

  public ScopeLoader ()
  {
  }

  public virtual List<Unity.AbstractScope> get_scopes (string module_name, string? module_type) throws Error
  {
    var module = GLib.Module.open (module_name, ModuleFlags.BIND_LAZY);
    if (module == null)
    {
      throw new GLib.IOError.FAILED ("Could not load module '%s': %s", module_name, GLib.Module.error());
    }

    void *function;
    if (!module.symbol ("unity_scope_module_get_version", out function))
    {
      throw new GLib.IOError.FAILED (@"Could not find 'get_version' symbol in '$module_name'");
    }
    var get_version = (GetVersionFunction)function;
    if (get_version () != Unity.SCOPE_API_VERSION)
    {
      throw new GLib.IOError.FAILED (@"Plugin '$module_name' is for wrong Scope API version");
    }

    if (!module.symbol ("unity_scope_module_load_scopes", out function))
    {
      throw new GLib.IOError.FAILED (@"Could not find 'load_scopes' symbol in '$module_name'");
    }

    // Since we're executing code within the module at this point, it
    // should not be unloaded.
    module.make_resident ();
    var load_scopes = (LoadScopesFunction)function;
    return load_scopes ();
  }

  public virtual void export_scopes (List<Unity.AbstractScope> scopes) throws Error
  {
    foreach (var scope in scopes)
    {
      var connector = new ScopeDBusConnector (scope);
      connector.export ();
      this.connectors.prepend (connector);
    }
  }

  private void load_and_export (string module, string? module_type) throws Error
  {
    // We've already loaded this particular module
    if (this.loaded_modules == null)
      this.loaded_modules = new HashTable<string,int> (str_hash, str_equal);
    if (this.loaded_modules.contains (module))
      return;

    var module_scopes = get_scopes (module, module_type);
    export_scopes (module_scopes);
    // Record this module as having been loaded to avoid a second attempt.
    this.loaded_modules[module] = 1;
  }

  public void load_group (string group_name) throws Error
  {
    var config = new Protocol.ScopeGroupConfig (group_name);
    // ignoring individual scope timeouts, using only group timeout
    Unity.Internal.update_process_timeout (config.timeout);
    foreach (var info in config.scopes)
    {
      load_and_export (info.module, info.module_type);
    }
  }

  public void load_scope (string scope_id) throws Error
  {
    var metadata = Protocol.ScopeRegistry.ScopeMetadata.for_id (scope_id);
    Unity.Internal.update_process_timeout (metadata.timeout);
    load_and_export (metadata.module, metadata.module_type);
  }

  public void load_module (string module, string? module_type) throws Error
  {
    load_and_export (module, module_type);
  }
}

}
