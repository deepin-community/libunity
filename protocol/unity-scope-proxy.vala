/*
 * Copyright (C) 2012 Canonical, Ltd.
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
 * Authored by Michal Hruby <michal.hruby@canonical.com>
 *
 */

using GLib;
using Unity.Protocol;

namespace Unity.Protocol {

/*
 * Proxies a Scope from DBus
 */

public abstract interface ScopeProxy : GLib.Object
{
  public abstract bool visible { get; }
  public abstract bool is_master { get; }
  public abstract bool connected { get; }
  public abstract string search_hint { get; }
  public abstract ViewType view_type { get; set; }
  public abstract Dee.SerializableModel filters_model { get; }
  public abstract Dee.SerializableModel categories_model { get; }
  /* no access to Filter class in proto lib */
  public abstract Variant sources { get; }
  public abstract HashTable<string, string> metadata { get; }
  public abstract HashTable<string, string> optional_metadata { get; }

  public signal void category_order_changed (
      string channel_id, uint32[] new_order);

  public signal void filter_settings_changed (
      string channel_id, Variant filter_rows);

  public signal void results_invalidated (ChannelType channel_type);

  public abstract async ActivationReplyRaw activate (
      string channel_id,
      Variant[] result_arr,
      ActionType action_type,
      HashTable<string, Variant> hints,
      Cancellable? cancellable = null) throws Error;

  public abstract async HashTable<string, Variant> search (
      string channel_id,
      string search_string,
      HashTable<string, Variant> hints,
      Cancellable? cancellable = null) throws Error;

  public abstract async string open_channel (
      ChannelType channel_type,
      ChannelFlags channel_flags,
      Cancellable? cancellable = null,
      out Dee.SerializableModel results_model) throws Error;

  public abstract async void close_channel (
      string channel_id,
      Cancellable? cancellable = null) throws Error;

  public signal void channels_invalidated ();

  public abstract async void set_active_sources (
      string channel_id,
      string[] sources,
      Cancellable? cancellable = null) throws Error;

  public abstract async HashTable<string, Variant> push_results (
      string channel_id,
      string search_string,
      string source_scope_id,
      Dee.SerializableModel model,
      string[] categories,
      GLib.Cancellable? cancellable = null) throws Error;
 
  public static async ScopeProxy new_for_id (
      string id, Cancellable? cancellable = null) throws Error
  {
    throw new IOError.FAILED ("Unimplemented!");
  }

  public static async ScopeProxy new_from_dbus (
      string dbus_name, string dbus_path,
      Cancellable? cancellable = null) throws Error
  {
    var proxy = yield ScopeProxyRemote.create (dbus_name, dbus_path, cancellable);
    return proxy;
  }

  public static async ScopeProxy new_from_metadata (
      ScopeRegistry.ScopeMetadata metadata,
      Cancellable? cancellable = null) throws Error
  {
    // FIXME: this is a place where we could use local proxies too
    var proxy = yield ScopeProxyRemote.create (metadata.dbus_name, metadata.dbus_path, cancellable);
    return proxy;
  }
}

} /* namespace */
