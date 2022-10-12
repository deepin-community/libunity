/*
 * Copyright (C) 2011-2012 Canonical, Ltd.
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
 *             Michal Hruby <michal.hruby@canonical.com>
 */

using GLib;
using Dee;

namespace Unity.Protocol {

/* The raw structs that get's passed over DBus to/from the parent Lens */
public struct ActivationReplyRaw
{
  public string uri;
  public uint handled;
  public HashTable<string, Variant> hints;
}

public enum HandledType
{
  NOT_HANDLED,
  SHOW_DASH,
  HIDE_DASH,
  GOTO_DASH_URI,
  SHOW_PREVIEW,
  PERFORM_SEARCH
}

public enum ActionType
{
  ACTIVATE_RESULT,
  PREVIEW_RESULT,
  PREVIEW_ACTION,
  PREVIEW_BUILTIN_ACTION
}

public enum ViewType
{
  HIDDEN,
  HOME_VIEW,
  LENS_VIEW
}

public enum ChannelType
{
  DEFAULT,
  GLOBAL
}

[Flags]
public enum ChannelFlags
{
  NONE = 0,
  PRIVATE,
  NO_FILTERING,
  DIFF_CHANGES;

  public static ChannelFlags from_hints (HashTable<string, Variant> hints)
  {
    ChannelFlags flags = 0;
    if (CHANNEL_PRIVATE_HINT in hints &&
        hints[CHANNEL_PRIVATE_HINT].get_boolean ())
    {
      flags |= ChannelFlags.PRIVATE;
    }
    if (CHANNEL_DIFF_MODEL_HINT in hints &&
        hints[CHANNEL_DIFF_MODEL_HINT].get_boolean ())
    {
      flags |= ChannelFlags.DIFF_CHANGES;
    }
    return flags;
  }
}

/* The error types that can be thrown from DBus methods */
[DBus (name = "com.canonical.Unity.ScopeError")]
public errordomain ScopeError
{
  REQUEST_FAILED,
  DATA_MISMATCH,
  INVALID_CHANNEL,
  SEARCH_CANCELLED,
  DISABLED_CONTENT,
  UNKNOWN
}

public const string CHANNEL_PRIVATE_HINT = "private-channel";
public const string CHANNEL_DIFF_MODEL_HINT = "diff-model";
public const string CHANNEL_SWARM_NAME_HINT = "model-swarm-name";

/**
 * ScopeService:
 *
 * The Scope interface exported on DBus
 */
[DBus (name = "com.canonical.Unity.Scope")]
public interface ScopeService : GLib.Object
{
  public const string INTERFACE_NAME = "com.canonical.Unity.Scope";

  /* Methods */
  public abstract async ActivationReplyRaw activate (
      string channel_id,
      Variant[] result_arr,
      uint action_type,
      HashTable<string, Variant> hints,
      Cancellable? cancellable = null) throws IOError, ScopeError;

  public abstract async HashTable<string, Variant> search (
      string channel_id,
      string search_string,
      HashTable<string, Variant> hints,
      Cancellable? cancellable = null) throws IOError, ScopeError;

  public abstract async string open_channel (
      uint channel_type,
      HashTable<string, Variant> hints,
      Cancellable? cancellable = null,
      BusName? sender = null,
      out HashTable<string, Variant> out_hints) throws IOError;

  public abstract async void close_channel (
      string channel_id,
      HashTable<string, Variant> hints,
      Cancellable? cancellable = null) throws IOError, ScopeError;

  public abstract async HashTable<string, Variant> push_results (
      string channel_id,
      string search_string,
      string source_scope_id,
      Variant result_variant,
      string[] categories,
      Cancellable? cancellable = null) throws IOError, ScopeError;

  /* do we still need this? */
  public abstract async void set_view_type (uint view_type) throws IOError;

  /* Signals */
  public signal void category_order_changed (
      string channel_id, uint32[] new_order);

  public signal void filter_settings_changed (
      string channel_id,
      [DBus (signature = "a(ssssa{sv}bbb)")] Variant filter_rows);

  public signal void results_invalidated (uint channel_type);

  /* Properties */
  public abstract int protocol_version { get; }
  public abstract bool visible { get; }
  public abstract bool is_master { get; }
  public abstract string search_hint { owned get; }
  public abstract HashTable<string, string> metadata { owned get; }
  public abstract HashTable<string, string> optional_metadata { owned get; }
  public abstract Variant categories { owned get; }
  public abstract Variant filters { owned get; }
  public abstract HashTable<string, Variant> hints { owned get; }
}

} /* namespace unity */
