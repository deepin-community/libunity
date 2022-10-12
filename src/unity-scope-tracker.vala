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

[Flags]
private enum ChannelUpdateFlags
{
  NONE = 0,
  DEFAULT,
  GLOBAL
}

private class ScopeTracker : Object
{
  public static Quark DEDUP_MODEL_QUARK = Quark.from_string ("unity-dedup-model");
  const int MODEL_UPDATE_TIMEOUT_SECS = 30;

  private GenericArray<ScopeProxy> scope_proxy_arr;
  // scope_id -> ScopeProxy
  private HashTable<string, Utils.AsyncOnce<ScopeProxy>> scope_proxies;
  // channel_key (proxy + master_channel_id) -> scope channel_id
  private HashTable<string, Utils.AsyncOnce<string>> scope_channel_ids;
  // channel_key (proxy + master_channel_id) -> Dee.Model
  private HashTable<string, Dee.SerializableModel> scope_models;
  // master_channel_id -> ResultsSynchronizer
  private HashTable<string, ResultsSynchronizer> synchronizers;
  // update_key (proxy + channel_type) -> ChannelUpdateFlags
  private HashTable<string, ChannelUpdateFlags> master_update_flags;
  // scope_id -> ScopeMetadata
  private HashTable<string, ScopeRegistry.ScopeMetadata> scope_metadata;
  // binary name -> present on the system
  private HashTable<string, bool> binary_present;

  public ScopeTracker ()
  {
    scope_proxy_arr = new GenericArray<ScopeProxy> ();
    scope_proxies = new HashTable<string, Utils.AsyncOnce<ScopeProxy>> (str_hash, str_equal);
    scope_channel_ids = new HashTable<string, Utils.AsyncOnce<string>> (str_hash, str_equal);
    scope_models = new HashTable<string, Dee.SerializableModel> (str_hash, str_equal);
    synchronizers = new HashTable<string, ResultsSynchronizer> (str_hash, str_equal);
    master_update_flags = new HashTable<string, ChannelUpdateFlags> (str_hash, str_equal);
    scope_metadata = new HashTable<string, ScopeRegistry.ScopeMetadata> (str_hash, str_equal);
    binary_present = new HashTable<string, bool> (str_hash, str_equal);
  }

  public List<weak string> scope_ids_for_proxies ()
  {
    return scope_proxies.get_keys ();
  }

  public unowned ScopeProxy? get_proxy_for_scope_id (string scope_id)
  {
    var proxy_once = get_proxy_once (scope_id);
    if (!proxy_once.is_initialized ())
    {
      return null;
    }

    return proxy_once.get_data ();
  }

  /* Careful, this could be expensive... O(n) */
  public string? get_scope_id_for_proxy (ScopeProxy proxy)
  {
    var iter = HashTableIter<string, Utils.AsyncOnce<ScopeProxy>> (scope_proxies);
    unowned string scope_id;
    unowned Utils.AsyncOnce<ScopeProxy> val;
    while (iter.next (out scope_id, out val))
    {
      if (val.get_data () == proxy) return scope_id;
    }

    return null;
  }

  public unowned ResultsSynchronizer? get_synchronizer (string channel_id)
  {
    return synchronizers.lookup (channel_id);
  }

  private bool content_enabled (ScopeRegistry.ScopeMetadata metadata)
  {
    var pref_man = PreferencesManager.get_default ();
    if (metadata.remote_content && pref_man.remote_content_search == PreferencesManager.RemoteContent.NONE)
    {
      return false;
    }
    return true;
  }

  private void perform_checks (ScopeRegistry.ScopeMetadata metadata,
                               ChannelType requested_channel_type)
    throws ScopeError
  {
    // check remote content vs user preference
    if (!content_enabled (metadata))
    {
      throw new ScopeError.DISABLED_CONTENT ("Requested content disabled");
    }
    // check global search flag
    if (!metadata.global_searches && requested_channel_type == ChannelType.GLOBAL)
    {
      throw new ScopeError.DISABLED_CONTENT ("Global search is disabled");
    }
    // check if the required binary is installed
    if (metadata.query_binary != null && metadata.query_binary != "")
    {
      if (!(metadata.query_binary in binary_present))
      {
        binary_present[metadata.query_binary] = Environment.find_program_in_path (metadata.query_binary) != null;
      }
      if (!binary_present[metadata.query_binary])
      {
        throw new ScopeError.DISABLED_CONTENT ("Required application isn't installed");
      }
    }
  }

  public async ScopeProxy? create_proxy (ScopeRegistry.ScopeMetadata metadata)
    throws Error
  {
    var proxy = yield ScopeProxy.new_from_metadata (metadata);
    dynamic ScopeProxy remote_proxy = proxy;
    remote_proxy.auto_reconnect = false;
    // check that the proxy props match the metadata,
    // will throw an error if it doesn't
    check_proxy_vs_metadata (proxy, metadata);

    scope_proxy_arr.add (proxy);

    proxy.channels_invalidated.connect (channels_invalidated);
    proxy.results_invalidated.connect (on_results_invalidated);

    return proxy;
  }

  private void channels_invalidated (ScopeProxy proxy)
  {
    // we're not removing the results that were associated with this proxy
    // and are still living in the associated ResultsSynchronizer,
    // cause scope quitting after a while is an excepted part of scope
    // lifecycle, plus activating a result will try to respawn the scope

    // invalidate all associated containers
    string[] invalid_keys = {};
    string prefix = "%p::".printf (proxy);
    
    debug ("Invalidating channels for %s", prefix);

    foreach (unowned string channel_key in scope_channel_ids.get_keys ())
    {
      if (channel_key.has_prefix (prefix)) invalid_keys += channel_key;
    }

    foreach (unowned string channel_key in invalid_keys)
    {
      scope_channel_ids.remove (channel_key);
      scope_models.remove (channel_key);
    }
  }

  public signal void results_invalidated (ChannelUpdateFlags update_flags);

  private void on_results_invalidated (ScopeProxy proxy,
                                       ChannelType channel_type)
  {
    var flags = master_update_flags[get_update_key (proxy, channel_type)];
    if (flags == ChannelUpdateFlags.NONE) return;
    this.results_invalidated (flags);
  }

  private void check_proxy_vs_metadata (
      ScopeProxy proxy,
      ScopeRegistry.ScopeMetadata metadata) throws Error
  {
    if (proxy.is_master != metadata.is_master)
      throw new ScopeError.DATA_MISMATCH ("Scope file info for '%s' doesn't match on IsMaster key".printf (metadata.id));

    if (metadata.required_metadata != null)
    {
      var dict = metadata.required_metadata.as_hash_table ();
      unowned string field_name;
      unowned string schema;
      var iter = HashTableIter<string, string> (dict);
      while (iter.next (out field_name, out schema))
      {
        if (proxy.metadata[field_name] != schema)
          throw new ScopeError.DATA_MISMATCH ("Scope file info for '%s' doesn't match on RequiredMetadata key".printf (metadata.id));
      }
    }
  }

  private string get_channel_key (string master_channel_id, ScopeProxy proxy)
  {
    return "%p::%s".printf (proxy, master_channel_id);
  }

  private string get_update_key (ScopeProxy proxy, ChannelType channel_type)
  {
    return "%p::%d".printf (proxy, (int) channel_type);
  }

  public void register_channel (string owner_scope_id,
                                string master_channel_id,
                                Dee.SerializableModel model,
                                MergeStrategy merge_strategy)
  {
    // create new synchronizer for this channel
    var synchronizer = new ResultsSynchronizer (model, owner_scope_id);
    synchronizer.merge_strategy = merge_strategy;
    synchronizers[master_channel_id] = synchronizer;
  }

  public void unregister_channel (string master_channel_id)
  {
    var synchronizer = synchronizers[master_channel_id];
    if (synchronizer != null)
    {
      // break the circular reference
      synchronizer.receiver.set_qdata<Dee.Model?> (DEDUP_MODEL_QUARK, null);
      synchronizers.remove (master_channel_id);
    }

    // close child scopes' channels
    var channel_keys_to_close = new HashTable<string, ScopeProxy> (str_hash, str_equal);
    // get all channel_ids associated with this master_channel_id
    for (int i = 0; i < scope_proxy_arr.length; i++)
    {
      var channel_key = get_channel_key (master_channel_id, scope_proxy_arr[i]);
      if (channel_key in scope_channel_ids)
      {
        if (scope_channel_ids[channel_key].get_data () != null)
        {
          channel_keys_to_close[channel_key] = scope_proxy_arr[i];
        }
      }
    }

    var iter = HashTableIter<string, ScopeProxy> (channel_keys_to_close);
    unowned string channel_key;
    unowned ScopeProxy proxy;

    while (iter.next (out channel_key, out proxy))
    {
      var child_channel_id = scope_channel_ids[channel_key].get_data ();
      if (child_channel_id == null) continue;
      proxy.close_channel.begin (child_channel_id, null);
      scope_channel_ids.remove (channel_key);
      scope_models.remove (channel_key);
    }
  }

  private async void wait_for_seqnum (Dee.SharedModel model, uint64 seqnum)
    throws Error
  {
    if (model.get_seqnum () >= seqnum) return;

    var update_sig_id = model.end_transaction.connect ((m, begin_seqnum, end_seqnum) =>
    {
      if (end_seqnum < seqnum) return;

      wait_for_seqnum.callback ();
    });

    // make sure we don't wait indefinitely
    uint src_id = 0;
    src_id = Timeout.add_seconds (MODEL_UPDATE_TIMEOUT_SECS, () =>
    {
      src_id = 0;
      wait_for_seqnum.callback ();
      return false;
    });

    yield;

    SignalHandler.disconnect (model, update_sig_id);
    if (src_id != 0)
    {
      Source.remove (src_id);
    }
    else
    {
      // timeout was reached
      throw new DBusError.TIMEOUT ("Timed out waiting for model update");
    }
  }

  private Utils.AsyncOnce<ScopeProxy> get_proxy_once (string scope_id)
  {
    var proxy_once = scope_proxies[scope_id];
    if (proxy_once == null)
    {
      proxy_once = new Utils.AsyncOnce<ScopeProxy> ();
      scope_proxies[scope_id] = proxy_once;
    }

    return proxy_once;
  }

  private Utils.AsyncOnce<string> get_channel_id_once (string channel_key)
  {
    var channel_id_once = scope_channel_ids[channel_key];
    if (channel_id_once == null)
    {
      channel_id_once = new Utils.AsyncOnce<string> ();
      scope_channel_ids[channel_key] = channel_id_once;
    }

    return channel_id_once;
  }

  private unowned string? get_channel_id (string master_channel_id,
                                          string scope_id,
                                          out ScopeProxy? proxy) throws Error
  {
    var proxy_once = get_proxy_once (scope_id);
    if (!proxy_once.is_initialized ())
    {
      proxy = null;
      return null;
    }

    if (proxy_once.get_data () == null)
      throw new ScopeError.REQUEST_FAILED ("Unable to create proxy");

    proxy = proxy_once.get_data ();

    var channel_key = get_channel_key (master_channel_id, proxy);
    var channel_id_once = get_channel_id_once (channel_key);
    if (!channel_id_once.is_initialized ()) return null;
    return channel_id_once.get_data ();
  }

  private async unowned string init_channel (ScopeChannel master_channel,
                                             string scope_id,
                                             ChannelType channel_type,
                                             out ScopeProxy proxy)
    throws Error
  {
    // init ScopeProxy
    var proxy_once = get_proxy_once (scope_id);
    Error? failure = null;

    // short-circuit evaluation
    if (scope_id in scope_metadata)
    {
      // will throw if checks fail
      perform_checks (scope_metadata[scope_id], channel_type);
    }

    if (!proxy_once.is_initialized ())
    {
      if (yield proxy_once.enter ())
      {
        ScopeProxy? actual_proxy = null;
        try
        {
          if (!(scope_id in scope_metadata))
          {
            scope_metadata[scope_id] = ScopeRegistry.ScopeMetadata.for_id (scope_id);
          }
          var metadata = scope_metadata[scope_id];
          // don't even create the proxy if one of the checks fail
          perform_checks (metadata, channel_type);
          actual_proxy = yield create_proxy (metadata);

          if (actual_proxy.categories_model != null)
          {
            proxy_category_model_changed (scope_id, actual_proxy);
          }
          actual_proxy.notify["categories-model"].connect ((obj, pspec) =>
          {
            ScopeProxy the_proxy = obj as ScopeProxy;
            string? id = get_scope_id_for_proxy (the_proxy);
            if (id != null)
            {
              proxy_category_model_changed (id, the_proxy);
            }
          });
        }
        catch (Error e)
        {
          failure = e;
        }
        finally
        {
          proxy_once.leave (actual_proxy);
        }
      }
    }

    proxy = proxy_once.get_data ();
    if (proxy == null)
    {
      if (failure != null && failure is ScopeError.DISABLED_CONTENT)
      {
        // retry next time
        proxy_once.reset ();
        throw failure;
      }
      var msg = "Unable to create scope proxy for \"%s\": %s".printf (
        scope_id, failure != null ? failure.message : "(unknown)");
      throw new ScopeError.REQUEST_FAILED (msg);
    }

    // open a channel
    var channel_key = get_channel_key (master_channel.id, proxy);
    var channel_id_once = get_channel_id_once (channel_key);

    if (!channel_id_once.is_initialized ())
    {
      if (yield channel_id_once.enter ())
      {
        Dee.SerializableModel model;
        string? chan_id = null;
        try
        {
          chan_id = yield proxy.open_channel (channel_type,
                                              ChannelFlags.PRIVATE,
                                              null,
                                              out model);
          scope_models[channel_key] = model;
          // register as receiver
          var synchronizer = synchronizers[master_channel.id];
          if (synchronizer != null)
          {
            synchronizer.add_provider (model, scope_id);
          }
          else
          {
            warning ("Unable to find ResultsSynchronizer for channel %s",
                     master_channel.id);
          }
          // a mapping for on_results_invalidated
          var flag = master_channel.channel_type == ChannelType.DEFAULT ?
            ChannelUpdateFlags.DEFAULT : ChannelUpdateFlags.GLOBAL;
          // note that the hash table key contains the channel_type of the just
          // opened channel, while the flag depends on master channel type
          master_update_flags[get_update_key (proxy, channel_type)] |= flag;
        }
        finally
        {
          channel_id_once.leave (chan_id);
        }
      }
    }

    unowned string scope_channel_id = channel_id_once.get_data ();
    if (scope_channel_id == null)
    {
      // uh oh, couldn't open a channel, try again next time
      channel_id_once.reset ();
    }
    return scope_channel_id;
  }

  public async ActivationReplyRaw activate_wrapper (
      ScopeChannel master_channel,
      string scope_id,
      owned Variant[] result_arr,
      uint action_type,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws Error
  {
    ScopeProxy proxy;
    unowned string scope_channel_id;
    scope_channel_id = get_channel_id (master_channel.id, scope_id, out proxy);
    if (scope_channel_id == null)
      scope_channel_id = yield init_channel (master_channel, scope_id,
                                             master_channel.channel_type,
                                             out proxy);

    cancellable.set_error_if_cancelled ();

    var action = (Unity.Protocol.ActionType) action_type;
    return yield proxy.activate (scope_channel_id, result_arr,
                                 action, hints, cancellable);
  }

  public async HashTable<string, Variant> search_wrapper (
      ScopeChannel master_channel,
      ChannelType channel_type,
      string search_string,
      HashTable<string, Variant> hints,
      string scope_id,
      GLib.Cancellable? cancellable) throws Error
  {
    ScopeProxy proxy;
    unowned string scope_channel_id;
    scope_channel_id = get_channel_id (master_channel.id, scope_id, out proxy);
    if (scope_channel_id == null)
      scope_channel_id = yield init_channel (master_channel, scope_id,
                                             channel_type, out proxy);

    cancellable.set_error_if_cancelled ();

    var reply_hints = new HashTable<string, Variant> (str_hash, str_equal);

    if (!content_enabled (scope_metadata[scope_id])
        || scope_channel_id == null)
    {
      return reply_hints;
    }

    var channel_key = get_channel_key (master_channel.id, proxy);
    var last_seq_num = scope_models[channel_key].get_seqnum ();

    var sync = synchronizers[master_channel.id];
    sync.enable_provider (scope_id);

    var reply_dict = yield proxy.search (scope_channel_id, search_string,
                                         hints, cancellable);

    var iter = HashTableIter<string, Variant> (reply_dict);
    unowned string key;
    unowned Variant variant;

    while (iter.next (out key, out variant))
    {
      if (key == SEARCH_SEQNUM_HINT)
      {
        uint64 seqnum = variant.get_uint64 ();
        var model = scope_models[channel_key];
        if (model.get_seqnum () < seqnum)
          yield wait_for_seqnum (model as Dee.SharedModel, seqnum);

        // if the proxy was disconnected and its channels invalidated, this
        // model is no longer merged, check if that's the case
        if (scope_models[channel_key] != model)
          return reply_hints;

        if (seqnum == last_seq_num)
        {
          debug ("Model seqnum for channel key %s not changed, copying", channel_key);
          var synchronizer = get_synchronizer (master_channel.id);
          if (synchronizer != null)
            synchronizer.copy_model (model);
          else
            warning ("No synchronizer for master channel %s", master_channel.id);
        }
      }
      else if (key == SEARCH_TIME_HINT)
      {
        reply_hints["%s:%s".printf (SEARCH_TIME_HINT, scope_id)] = variant;
      }
      else
      {
        reply_hints[key] = variant; // pass up
      }
    }

    cancellable.set_error_if_cancelled ();
    // don't disable the provider if this search got cancelled, new search
    // might expect it to be enabled
    sync.disable_provider (scope_id);

    return reply_hints;
  }

  public async void push_wrapper (
      ScopeChannel parent_channel,
      string search_string,
      ChannelType channel_type,
      string master_scope_id,
      string scope_id,
      Dee.SerializableModel results_model,
      owned string[] categories,
      GLib.Cancellable? cancellable) throws Error
  {
    ScopeProxy proxy;
    unowned string scope_channel_id;
    scope_channel_id = get_channel_id (parent_channel.id, master_scope_id, out proxy);
    if (scope_channel_id == null)
      scope_channel_id = yield init_channel (parent_channel,
                                             master_scope_id,
                                             channel_type, out proxy);

    if (scope_channel_id == null)
    {
      return; // shouldn't be reached really
    }

    cancellable.set_error_if_cancelled ();

    var channel_key = get_channel_key (parent_channel.id, proxy);
    var sync = synchronizers[parent_channel.id];
    sync.enable_provider (master_scope_id);

    var reply_dict = yield proxy.push_results (scope_channel_id,
                                               search_string,
                                               scope_id,
                                               results_model,
                                               categories, cancellable);

    var iter = HashTableIter<string, Variant> (reply_dict);
    unowned string key;
    unowned Variant variant;

    while (iter.next (out key, out variant))
    {
      if (key == SEARCH_SEQNUM_HINT)
      {
        uint64 seqnum = variant.get_uint64 ();
        var model = scope_models[channel_key];
        if (model.get_seqnum () < seqnum)
          yield wait_for_seqnum (model as Dee.SharedModel, seqnum);
      }
    }

    cancellable.set_error_if_cancelled ();
    // don't disable the provider if this search got cancelled, new search
    // might expect it to be enabled
    sync.disable_provider (master_scope_id);
  }

  public signal void proxy_category_model_changed (string scope_id,
                                                   ScopeProxy scope_proxy);
}

} /* namespace Unity.Internal */
