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
 *
 */

using GLib;
using Dee;
using Unity;
using Unity.Protocol;

namespace Unity.Internal {

internal enum ChannelState
{
  IDLE,
  SEARCH_ACTIVE
}

internal class ScopeChannel : Object
{
  private const uint METADATA_COLUMN = 8;

  public Utils.AsyncMutex model_lock;
  /* transfer_model must be a Dee.SharedModel */
  public Dee.SharedModel? transfer_model;
  /* backing model for the transfer_model (ie SequenceModel or FilterModel) */
  public Dee.SerializableModel backend_model;

  public FilterSet filters;

  public ChannelType channel_type;
  public string id;

  public ScopeSearchBase? last_search;
  public uint last_search_tag;

  private ChannelState state;
  private Utils.DelegateWrapper[] callbacks = {};

  private string last_push_search_string;
  private GLib.List<Dee.SerializableModel> pushed_models = new GLib.List<Dee.SerializableModel> ();
  private OwnerWatcher? watcher;

  public signal void owner_lost ();

  public ScopeChannel (ChannelType channel_type_)
  {
    channel_type = channel_type_;
    id = "%p".printf (this);
    filters = new FilterSet ();
    model_lock = new Utils.AsyncMutex ();
  }

  ~ScopeChannel ()
  {
    if (watcher != null)
    {
      watcher.unwatch ();
    }
  }

  public SearchType get_search_type ()
  {
    SearchType search_type = channel_type == ChannelType.DEFAULT ?
      SearchType.DEFAULT : SearchType.GLOBAL;
    return search_type;
  }

  private static Dee.SerializableModel create_filter_model (
      Dee.Model backend, HashTable<string, string> metadata_schema)
  {
    var types = new HashTable<string, VariantType> (str_hash, str_equal);
    metadata_schema.for_each ((field, schema) =>
    {
      types[field] = new VariantType (schema);
    });

    var model = new Dee.FilterModel (
      backend, Dee.Filter.new (
        () => {}, // no need for map func, the model is empty on creation
        (orig_model, iter, filter_model) =>
        {
          // check that the row contains all required metadata
          var metadata = orig_model.get_value (iter, METADATA_COLUMN);
          unowned string field_name;
          unowned VariantType schema;
          var ht_iter = HashTableIter<string, VariantType> (types);
          while (ht_iter.next (out field_name, out schema))
          {
            var field = metadata.lookup_value (field_name, schema);
            if (field == null)
            {
              warning ("Row doesn't contain required data: missing '%s'",
                       field_name);
              return false;
            }
          }

          filter_model.insert_iter_with_original_order (iter);
          return true;
        }));
    return model;
  }

  private Dee.SerializableModel create_backend_model (
      HashTable<string, string> metadata_schema,
      bool no_filtering,
      out Dee.SerializableModel real_backend)
  {
    var backend = new Dee.SequenceModel ();
    real_backend = backend;
    if (no_filtering || metadata_schema.size () == 0) return backend;

    return create_filter_model (backend, metadata_schema);
  }

  public string create_channel (string swarm_name,
                                HashTable<string, string> metadata_schema,
                                HashTable<string, string> optional_metadata,
                                Dee.SerializableModel filter_model,
                                ChannelFlags flags = 0)
  {
    unowned string field_name;
    unowned string schema;

    var vardict_schema =
      new HashTable<unowned string, unowned string> (str_hash, str_equal);
    var iter = HashTableIter<string, string> (optional_metadata);
    while (iter.next (out field_name, out schema))
    {
      vardict_schema[field_name] = schema;
    }
    /* ensure required metadata have higher prio */
    iter = HashTableIter<string, string> (metadata_schema);
    while (iter.next (out field_name, out schema))
    {
      vardict_schema[field_name] = schema;
    }

    var peer_type = ChannelFlags.PRIVATE in flags ?
      typeof (Dee.Server) : typeof (Dee.Peer);
    Dee.Peer peer = Object.new (peer_type,
                                "swarm-name", swarm_name,
                                "swarm-owner", true) as Dee.Peer;

    /* If NO_FILTERING is not specified, create_backend_model () will return
     * a FilterModel which will ensure that all required fields
     * from the schema are present, otherwise the row will be ignored.
     *
     * backend_model will then point to a simple SequenceModel which is used
     * as a backend for the FilterModel.
     */
    Dee.Model backend = create_backend_model (
      metadata_schema, ChannelFlags.NO_FILTERING in flags,
      out backend_model);

    /* Careful about using DiffModel, the ResultsSynchronizer doesn't play
     * nice with it, as the synchronized model gets cleared and listens
     * only to additions, if the provider model for the synchronizer only
     * removes a couple of results, and leaves the rest there,
     * the synchronizer will think that there are no results (cause there
     * were no additions).
     * Therefore AggregatorScopes can't use DiffModels. */
    if (ChannelFlags.DIFF_CHANGES in flags)
    {
      var sm = new DiffModel (peer, backend);
      sm.flush_mode = Dee.SharedModelFlushMode.MANUAL;
      sm.set_schema_full (RESULTS_SCHEMA);
      sm.set_column_names_full (RESULTS_COLUMN_NAMES);
      sm.register_vardict_schema (METADATA_COLUMN, (HashTable<string, string>) vardict_schema);
      transfer_model = sm;
    }
    else
    {
      var mode_flag = Dee.SharedModelAccessMode.LEADER_WRITABLE;
      var sm = Object.new (typeof (Dee.SharedModel),
                           "peer", peer,
                           "back-end", backend,
                           "access-mode", mode_flag) as Dee.SharedModel;
      sm.flush_mode = Dee.SharedModelFlushMode.MANUAL;
      transfer_model = sm;
    }

    backend_model.set_schema_full (RESULTS_SCHEMA);
    backend_model.set_column_names_full (RESULTS_COLUMN_NAMES);
    backend_model.register_vardict_schema (METADATA_COLUMN, (HashTable<string, string>) vardict_schema);

    set_filter_base (filter_model);

    return swarm_name;
  }

  public void set_filter_base (Dee.SerializableModel filter_model)
  {
    filters = new FilterSet ();

    // make a copy of filter_model, and handle the filter state there
    var fm_iter = filter_model.get_first_iter ();
    var end_iter = filter_model.get_last_iter ();
    while (fm_iter != end_iter)
    {
      var filter = Filter.for_filter_model_row (filter_model, fm_iter);
      if (filter != null) filters.add (filter);
      fm_iter = filter_model.next (fm_iter);
    }
  }

  public unowned Filter? get_filter_by_id (string filter_id)
  {
    return filters.get_filter_by_id (filter_id);
  }

  public async void wait_for_search ()
  {
    if (last_search == null) return;

    callbacks += new Utils.DelegateWrapper (wait_for_search.callback);
    yield;
  }

  public void set_state (ChannelState new_state)
  {
    if (new_state == state)
    {
      warning ("channel \"%s\", trying to change state to %s", id, new_state.to_string ());
      return;
    }

    var old_state = state;
    state = new_state;
    if (new_state == ChannelState.IDLE && old_state == ChannelState.SEARCH_ACTIVE)
    {
      // resume wait_for_search calls
      foreach (unowned Utils.DelegateWrapper wrapper in callbacks)
      {
        wrapper.callback ();
      }
      callbacks = {};
    }
  }

  public bool is_search_running ()
  {
    return state == ChannelState.SEARCH_ACTIVE;
  }

  public uint64 get_last_seqnum ()
  {
    if (transfer_model != null)
    {
      if (transfer_model is DiffModel)
      {
        (transfer_model as DiffModel).commit_changes ();
      }
      return transfer_model.get_seqnum ();
    }

    return backend_model.get_seqnum ();
  }

  public void register_pushed_model (string search_string,
                                     Dee.SerializableModel model)
  {
    if (search_string != last_push_search_string)
    {
      last_push_search_string = search_string;
      pushed_models = new GLib.List<Dee.SerializableModel> ();
    }

    pushed_models.append (model);
  }

  public GLib.List<unowned Dee.SerializableModel> get_pushed_models (string search_string)
  {
    if (last_push_search_string != search_string)
    {
      return new GLib.List<unowned Dee.SerializableModel> ();
    }

    return pushed_models.copy ();
  }

  /* Separate class to ensure we don't have reference cycles */
  private class OwnerWatcher
  {
    private uint owner_changed_signal_id;
    private unowned ScopeChannel owner_channel;
    private DBusConnection dbus_connection;
    
    public OwnerWatcher (ScopeChannel channel, DBusConnection connection, BusName owner)
    {
      owner_channel = channel;
      dbus_connection = connection;
      owner_changed_signal_id = dbus_connection.signal_subscribe (null,
          "org.freedesktop.DBus", "NameOwnerChanged", null, owner,
          DBusSignalFlags.NONE, this.owner_changed);
    }

    private void owner_changed (DBusConnection con, string? sender_name,
                                string obj_path, string ifc_name,
                                string sig_name, Variant parameters)
    {
      string new_owner = parameters.get_child_value (2).get_string ();
      if (new_owner == "")
      {
        owner_channel.owner_lost ();
      }
    }

    public void unwatch ()
    {
      if (owner_changed_signal_id != 0)
      {
        dbus_connection.signal_unsubscribe (owner_changed_signal_id);
        owner_changed_signal_id = 0;
      }
    }
  }

  public void watch_owner (DBusConnection connection, BusName owner)
  {
    if (watcher != null) watcher.unwatch ();
    watcher = new OwnerWatcher (this, connection, owner);
  }
}

} /* namespace Unity.Internal */
