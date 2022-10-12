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
using Dee;

namespace Unity.Protocol {

private class ScopeProxyRemote : GLib.Object, ScopeProxy
{
  const int REQUIRED_PROTOCOL_VERSION = 1;

  public string dbus_name { get; construct; }
  public string dbus_path { get; construct; }
  public bool auto_reconnect { get; set; default = true; }

  // really Vala? no "private set;" when inheriting from interface?
  public bool visible { get { return _visible; } }
  public bool is_master { get { return _is_master; } }
  public bool connected { get { return _is_connected; } }
  public Variant sources { get { return _sources; } }
  public string search_hint { get { return _search_hint; } }
  public Dee.SerializableModel filters_model { get { return _filters_model; } }
  public Dee.SerializableModel categories_model { get { return _categories_model; } }
  public HashTable<string, string> metadata { get { return _metadata; } }
  public HashTable<string, string> optional_metadata { get { return _optional_metadata; } }

  public ViewType view_type {
    // FIXME: ehm?!
    get { return _view_type; }
    // make sure we do dbus calls only on changes
    set { if (_view_type != value) set_view_type.begin (value); }
  }

  private bool _visible;
  private bool _is_master;
  private bool _is_connected;
  private Variant _sources;
  private string _search_hint;
  private Dee.SerializableModel _filters_model;
  private Dee.SerializableModel _categories_model;
  private HashTable<string, string> _metadata;
  private HashTable<string, string> _optional_metadata;
  private ViewType _view_type;
  private DBusConnection _bus;

  private ScopeService _service;
  private bool _connecting_to_proxy;

  private uint _reconnection_id = 0;
  private int64 _last_scope_crash = 0;
  private uint _scope_crashes = 0;
  private ulong _cat_sig_id = 0;
  private ulong _filters_sig_id = 0;
  private ulong _results_invalidated_sig_id = 0;

  private ScopeProxyRemote (string dbus_name_, string dbus_path_)
  {
    Object (dbus_name:dbus_name_, dbus_path:dbus_path_);
  }

  /* Vala increments reference count on objects that are associated with
   * the callbacks in watch_name, therefore this object serves as a proxy, so
   * that the ScopeProxyRemote instance can be safely reference counted */
  private class NameWatcher
  {
    private uint watch_id;
    unowned ScopeProxyRemote owner;

    public NameWatcher (DBusConnection bus, string dbus_name,
                        ScopeProxyRemote parent, bool auto_start)
    {
      owner = parent;
      var flags = auto_start ?
        BusNameWatcherFlags.AUTO_START : BusNameWatcherFlags.NONE;
      watch_id =
        Bus.watch_name_on_connection (bus, dbus_name, flags,
                                      () => { owner.on_scope_appeared (); },
                                      () => { owner.on_scope_vanished (); });
    }

    public void unwatch ()
    {
      if (watch_id != 0)
      {
        Bus.unwatch_name (watch_id);
        watch_id = 0;
      }
    }
  }

  private NameWatcher _watcher;

  construct
  {
    try {
      _bus = Bus.get_sync (BusType.SESSION);
      // auto starting the service here
      _watcher = new NameWatcher (_bus, dbus_name, this, true);
    } catch (Error e) {
      critical ("Unable to connect to session bus: %s", e.message);
    }
  }

  ~ScopeProxyRemote ()
  {
    _watcher.unwatch ();
  }

  // poor man's AsyncInitable
  public static async ScopeProxyRemote create (
      string dbus_name, string dbus_path,
      Cancellable? cancellable = null) throws Error
  {
    // this will always return a valid object, even if the proxy is invalid
    // (well unless you cancel the request)
    var proxy = new ScopeProxyRemote (dbus_name, dbus_path);
    yield proxy.wait_for_proxy ();

    if (cancellable != null) cancellable.set_error_if_cancelled ();
    return proxy;
  }

  private signal void proxy_initialized ();

  private async void wait_for_proxy ()
  {
    if (_service == null)
    {
      var sig_id = this.proxy_initialized.connect (() =>
      {
        wait_for_proxy.callback ();
      });

      yield;

      SignalHandler.disconnect (this, sig_id);
    }
  }

  private async void connect_to_scope ()
  {
    if (_connecting_to_proxy) return; // can't call this multiple times
    try
    {
      _connecting_to_proxy = true;
      _service = yield _bus.get_proxy (dbus_name, dbus_path);
      // FIXME: do we need to connect to any property changes?
      DBusProxy proxy = _service as DBusProxy;
      _is_connected = proxy.g_name_owner != null;
      if (_is_connected)
      {
        if (_service.protocol_version < REQUIRED_PROTOCOL_VERSION)
          throw new ScopeError.UNKNOWN ("Unsupported scope proxy");
        _is_master = _service.is_master;
        _visible = _service.visible;
        _search_hint = _service.search_hint;
        _metadata = _service.metadata;
        _optional_metadata = _service.optional_metadata;
        _categories_model = Dee.Serializable.parse (_service.categories, typeof (Dee.SequenceModel)) as Dee.SerializableModel;
        _filters_model = Dee.Serializable.parse (_service.filters, typeof (Dee.SequenceModel)) as Dee.SerializableModel;
        _cat_sig_id = _service.category_order_changed.connect (on_category_order_changed);
        _filters_sig_id = _service.filter_settings_changed.connect (on_filter_settings_changed);
        _results_invalidated_sig_id = _service.results_invalidated.connect (on_results_invalidated);
        // do we need hints?
      }
      proxy.g_properties_changed.connect (properties_changed);
    } catch (Error e) {
      _is_connected = false;
      warning ("Unable to connect to Scope (%s @ %s): %s",
               dbus_path, dbus_name, e.message);
    }
    _connecting_to_proxy = false;
    notify_property ("connected");

    proxy_initialized ();
  }

  private void properties_changed (DBusProxy proxy,
                                   Variant changed_properties,
                                   [CCode (array_length = false, array_null_terminated = true)] string[] invalidated_properties)
  {
    var iter = new VariantIter (changed_properties);
    unowned string prop_name;
    Variant prop_value;
    while (iter.next ("{&sv}", out prop_name, out prop_value))
    {
      if (prop_name == "Filters")
      {
        _filters_model = Dee.Serializable.parse (_service.filters, typeof (Dee.SequenceModel)) as Dee.SerializableModel;
        this.notify_property ("filters-model");
      }
      else if (prop_name == "Categories")
      {
        _categories_model = Dee.Serializable.parse (_service.categories, typeof (Dee.SequenceModel)) as Dee.SerializableModel;
        this.notify_property ("categories-model");
      }
    }
  }
 
  private void on_category_order_changed (string channel_id, uint32[] new_order)
  {
    category_order_changed (channel_id, new_order);
  }

  private void on_filter_settings_changed (string channel_id, Variant filter_rows)
  {
    filter_settings_changed (channel_id, filter_rows);
  }

  private void on_results_invalidated (uint channel_type)
  {
    results_invalidated ((ChannelType) channel_type);
  }

  public void on_scope_appeared ()
  {
    if (_reconnection_id != 0)
      Source.remove (_reconnection_id);
    connect_to_scope.begin ();
  }

  public void on_scope_vanished ()
  {
    //sources = new CheckOptionFilter ("sources", "Sources", null, true);

    /* No need to clear the filters model, it's read-only for the scope and
     * it would just cause warnings from filters synchronizer */
    _filters_model = null;

    if (_service != null)
    {
      if (_cat_sig_id > 0)
      {
        SignalHandler.disconnect (_service, _cat_sig_id);
        _cat_sig_id = 0;
      }

      if (_filters_sig_id > 0)
      {
        SignalHandler.disconnect (_service, _filters_sig_id);
        _filters_sig_id = 0;
      }

      if (_results_invalidated_sig_id > 0)
      {
        SignalHandler.disconnect (_service, _results_invalidated_sig_id);
        _results_invalidated_sig_id = 0;
      }

      /* Here comes the protected-restarting logic - the scope will be
       * restarted unless it crashed more than 10 times during the past
       * 15 minutes */
      _scope_crashes++;
      var cur_time = get_monotonic_time ();
      var time_since_last_crash = cur_time - _last_scope_crash;

      if (time_since_last_crash >= 15*60000000) // 15 minutes
      {
        _last_scope_crash = cur_time;
        // reset crash counter, it's not that bad
        _scope_crashes = 1;
      }
      else if (_scope_crashes >= 10)
      {
        // more than 10 crashes in the past 15 minutes
        warning ("Scope %s is crashing too often, disabling it", dbus_name);
        return;
      }

      start_reconnection_timeout ();
    }
    else
    {
      start_reconnection_timeout ();
    }

    _is_connected = false;
    // notify users that all associated channels are no longer valid
    channels_invalidated ();
    notify_property ("connected");
  }

  private void start_reconnection_timeout ()
  {
    if (_reconnection_id != 0)
      Source.remove (_reconnection_id);

    if (!auto_reconnect) return;

    _reconnection_id = Timeout.add_seconds (2, () =>
    {
      if (_service == null)
        connect_to_scope.begin ();
      else if ((_service as DBusProxy).g_name_owner == null)
        close_channel.begin (""); // ping the service to autostart it

      _reconnection_id = 0;
      return false;
    });
  }

  private void check_proxy () throws Error
  {
    // we have NameWatcher and will try to reconnect once the name appears 
    if (_service == null)
      throw new DBusError.SERVICE_UNKNOWN ("Unable to connect to service");
  }

  /*
   * Implementation of the ScopeService interface
   */
  public async ActivationReplyRaw activate (
      string channel_id,
      Variant[] result_arr, ActionType action_type,
      HashTable<string, Variant> hints,
      Cancellable? cancellable) throws Error
  {
    check_proxy ();
    var raw = yield _service.activate (channel_id, result_arr,
                                       (uint) action_type, hints,
                                       cancellable);
    return raw;
  }

  public async HashTable<string, Variant> search (
      string channel_id, string search_string,
      HashTable<string, Variant> hints,
      Cancellable? cancellable) throws Error
  {
    check_proxy ();
    var ht = yield _service.search (channel_id, search_string, hints,
                                    cancellable);
    return ht;
  }

  public async string open_channel (
      ChannelType channel_type,
      ChannelFlags channel_flags,
      Cancellable? cancellable,
      out Dee.SerializableModel results_model) throws Error
  {
    check_proxy ();
    var hints = new HashTable<string, Variant> (str_hash, str_equal);
    bool private_channel = ChannelFlags.PRIVATE in channel_flags;
    bool diff_model = ChannelFlags.DIFF_CHANGES in channel_flags;
    if (private_channel)
      hints[CHANNEL_PRIVATE_HINT] = new Variant.boolean (true);
    if (diff_model)
      hints[CHANNEL_DIFF_MODEL_HINT] = new Variant.boolean (true);

    HashTable<string, Variant> out_hints;
    var channel_id = yield _service.open_channel ((uint) channel_type, hints,
                                                  cancellable,
                                                  null,
                                                  out out_hints);
    Dee.Peer peer = private_channel ?
      new Dee.Client (out_hints[CHANNEL_SWARM_NAME_HINT].get_string ()) :
      new Dee.Peer (out_hints[CHANNEL_SWARM_NAME_HINT].get_string ());
    var model = new Dee.SharedModel.for_peer (peer);
    results_model = model;

    return channel_id;
  }

  public async void close_channel (
      string channel_id,
      Cancellable? cancellable) throws Error
  {
    check_proxy ();
    var hints = new HashTable<string, Variant> (str_hash, str_equal);
    yield _service.close_channel (channel_id, hints, cancellable);
  }

  public async void set_view_type (ViewType view_type)
  {
    _view_type = view_type;
    try {
      check_proxy ();
      // FIXME: no need to set HOME_VIEW if !search_in_global
      yield _service.set_view_type (view_type);
    } catch (Error e) {
      warning (@"Unable to set_active ($dbus_path): $(e.message)");
    }
  }

  public async void set_active_sources (
      string channel_id,
      string[] sources,
      Cancellable? cancellable) throws Error
  {
    check_proxy ();
    // FIXME: remove from ScopeProxy?
    if (cancellable != null) cancellable.set_error_if_cancelled ();
  }
  
  public async HashTable<string, Variant> push_results (
      string channel_id,
      string search_string,
      string source_scope_id,
      Dee.SerializableModel model,
      string[] categories,
      GLib.Cancellable? cancellable = null) throws Error
  {
    check_proxy ();
    return yield _service.push_results (channel_id, search_string,
                                        source_scope_id, model.serialize (),
                                        categories, cancellable);
  }
}

} /* Namespace */
