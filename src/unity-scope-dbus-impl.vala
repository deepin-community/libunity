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

using Dee;
using Unity.Protocol;

namespace Unity.Internal {

private static int PROCESS_TIMEOUT_SEC = 45;

internal void update_process_timeout (int new_timeout)
{
  if (PROCESS_TIMEOUT_SEC < 0) return;
  if (new_timeout < 0)
  {
    PROCESS_TIMEOUT_SEC = -1;
    return;
  }
  PROCESS_TIMEOUT_SEC = int.max (PROCESS_TIMEOUT_SEC, new_timeout);
}

private interface ScopeDBusImpl : ScopeService
{
  public abstract void export () throws Error;
  public abstract void unexport ();

  public abstract void queue_property_notification (string prop_name,
                                                    Variant prop_value);

  public abstract Dee.SerializableModel categories_model { get; set; }
  // careful with the filter model - it's defined globally yet the state 
  // is per-channel
  public abstract Dee.SerializableModel filters_model { get; set; }
}
/*
 * The private implementation of the Scope. This makes sure that none of the 
 * implementation details leak out into the public interface.
 */
private class DefaultScopeDBusImpl : GLib.Object, ScopeService, ScopeDBusImpl
{
  private const string SOURCES_FILTER_ID = "unity-sources";

  public unowned AbstractScope owner { private get; construct; }
  private HashTable<string, ScopeChannel> _channels;
  private uint _dbus_id;
  private string _dbus_name;
  private DBusConnection? _dbus_connection;
  private Rand _rand;
  private uint _inactivity_timeout_source_id;
  private uint _unexport_timeout_source_id;
  private ulong _scope_results_invalidated_id;
  private bool _query_happened;

  public Dee.SerializableModel categories_model { get; set; }
  public Dee.SerializableModel filters_model { get; set; }

  /* we need notifications on this property */
  public ViewType view_type { get; set; }

  public signal void on_timeout_reached ();
  public signal void on_unexport_timeout_reached ();

  public DefaultScopeDBusImpl (AbstractScope owner)
  {
    Object (owner: owner);
  }

  protected override void dispose ()
  {
    if (_inactivity_timeout_source_id != 0)
    {
      Source.remove (_inactivity_timeout_source_id);
      _inactivity_timeout_source_id = 0;
    }

    if (_unexport_timeout_source_id != 0)
    {
      Source.remove (_unexport_timeout_source_id);
      _unexport_timeout_source_id = 0;
    }
  }

  static bool force_sync_requests;
  static bool measure_requests;
  static string default_locale;
  static construct
  {
    force_sync_requests =
      Environment.get_variable (VAR_SYNC_DBUS_SEARCHES) != null;
    measure_requests =
      Environment.get_variable (VAR_MEASURED_SEARCHES) != null;

    unowned string[] langs = Intl.get_language_names ();
    default_locale = langs[0];
  }

  construct
  {
    _rand = new Rand ();
    _channels = new HashTable<string, ScopeChannel> (str_hash, str_equal);
    create_models ();
  }
  
  /* Create usable name prefix for the models */
  private string create_dbus_name ()
  {
    /* We randomize the names to avoid conflicts to ensure that we always
     * have a clean start (no processes hanging around that would cause
     * our models to not be the leaders)
     */
    var t = get_monotonic_time ();
    const string format_string = "com.canonical.Unity.Scope.%s.T%" + int64.FORMAT + "%d";
    var dbus_name = format_string.printf (
        Path.get_basename (_dbus_name),
        t, _rand.int_range (0, 10000));
    return dbus_name;
  }

  private void create_models ()
  {
    /* Schema definitions come from the Lens specification */
    categories_model = new Dee.SequenceModel ();
    categories_model.set_schema_full (CATEGORIES_SCHEMA);

    filters_model = new Dee.SequenceModel ();
    filters_model.set_schema_full (FILTERS_SCHEMA);
  }

  public void export () throws Error
  {
    FilterSet filters = owner.get_filters ();
    CategorySet categories = owner.get_categories ();

    set_filters (filters.get_filters ());
    set_categories (categories.get_categories ());

    _dbus_name = owner.get_unique_name ();
    if (_dbus_name == null || _dbus_name == "")
    {
      critical ("Scope cannot be exported, unique name was not set");
      throw new ScopeError.UNKNOWN ("Unable to export scope, unique name not set");
    }
    _dbus_connection = Bus.get_sync (BusType.SESSION);
    _dbus_id = _dbus_connection.register_object (_dbus_name,
                                                 this as ScopeService);

    _scope_results_invalidated_id = owner.results_invalidated_internal.connect(
      on_scope_results_invalidated);
  }

  public void unexport ()
  {
    if (_scope_results_invalidated_id != 0)
    {
      owner.disconnect (_scope_results_invalidated_id);
    }

    if (_dbus_id != 0)
    {
      _dbus_connection.unregister_object (_dbus_id);
      _dbus_id = 0;
      _dbus_connection = null;
    }
  }

  public void start_unexport_timer ()
  {
    if (_unexport_timeout_source_id != 0)
      Source.remove (_unexport_timeout_source_id);

    _unexport_timeout_source_id =
      Timeout.add_seconds_full (Priority.DEFAULT_IDLE, 30, () =>
      {
        this.on_unexport_timeout_reached ();
        _unexport_timeout_source_id = 0;
        return false;
      });
  }

  private VariantBuilder? changed_props;

  public void queue_property_notification (string prop_name, Variant prop_value)
  {
    if (_dbus_id == 0) return;

    bool schedule_emit = changed_props == null;
    if (changed_props == null)
      changed_props = new VariantBuilder (new VariantType ("a{sv}"));

    changed_props.add ("{sv}", prop_name, prop_value);

    if (schedule_emit)
    {
      Idle.add (() =>
      {
        var invalidated = new Variant.array (new VariantType ("s"), {});
        try
        {
          _dbus_connection.emit_signal (null, _dbus_name,
                                        "org.freedesktop.DBus.Properties",
                                        "PropertiesChanged",
                                        new Variant ("(sa{sv}@as)",
                                                     ScopeService.INTERFACE_NAME,
                                                     changed_props,
                                                     invalidated));
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
        changed_props = null;
        return false;
      });
    }
  }

  public void set_categories (List<unowned Category> categories)
  {
    bool categories_model_empty = categories_model.get_n_rows () == 0;
    if (!categories_model_empty)
    {
      // we support only appending new categories, no changes/deletes
      unowned List<unowned Category> cats = categories;
      uint cats_length = categories.length ();
      bool data_matches = cats_length >= categories_model.get_n_rows ();
      
      var iter = categories_model.get_first_iter ();
      var end_iter = categories_model.get_last_iter ();
      while (data_matches && iter != end_iter)
      {
        data_matches &= cats.data.id == categories_model.get_string (iter, 0);
        // FIXME: emit row-changed if other props changed
        iter = categories_model.next (iter);
        cats = cats.next;
      }

      if (!data_matches)
      {
        warning ("Categories can only be added, ignoring request");
        return;
      }
      else
      {
        categories = cats;
      }
    }

    foreach (unowned Category category in categories)
    {
      string icon_hint = Utils.icon_to_string (category.icon_hint);
      categories_model.append (category.id,
                               category.name,
                               icon_hint,
                               category.renderer,
                               Utils.hash_table_to_asv (category.get_hints ()));
    }

    queue_property_notification ("Categories",
                                 new Variant.variant (this.categories));
  }

  public void set_filters (List<unowned Filter> filters)
  {
    filters_model.clear ();

    foreach (unowned Filter filter in filters)
    {
      filter.changed.connect (on_filter_option_changed);
    }

    Variant data[8];
    foreach (unowned Filter filter in filters)
    {
      var serialized_filter = filter.serialize ();
      for (size_t i = 0; i < serialized_filter.n_children (); i++)
        data[i] = serialized_filter.get_child_value (i);

      filters_model.append_row (data);
    }
  }

  private void on_filter_option_changed (Filter filter)
  {
    bool found_iter = false;
    var iter = filters_model.get_first_iter ();
    while (iter != filters_model.get_last_iter ())
    {
      if (filters_model.get_string (iter, FilterColumn.ID) == filter.id)
      {
        string icon_hint = Utils.icon_to_string (filter.icon_hint);
        filters_model.set (iter,
                           filter.id,
                           filter.display_name,
                           icon_hint,
                           FilterRenderer.to_string (filter.renderer),
                           Utils.hash_table_to_asv (filter.get_hints ()),
                           filter.visible,
                           filter.collapsed,
                           filter.filtering);
        found_iter = true;
      }
      iter = filters_model.next (iter);
    }

    if (found_iter) this.notify_property ("filters");
  }

  private void on_scope_results_invalidated (SearchType search_type)
  {
    ChannelType channel_type = search_type == SearchType.DEFAULT ?
      ChannelType.DEFAULT : ChannelType.GLOBAL;

    foreach (var channel in _channels.get_values ())
    {
      if (channel.channel_type == channel_type)
      {
        channel.last_search = null;
      }
    }
    this.results_invalidated (channel_type);
  }

  private SearchMetadata create_search_metadata (HashTable<string, Variant> hints)
  {
    var metadata_hints = new HashTable<string, Variant> (str_hash, str_equal);
    hints.foreach ((k, v) => { metadata_hints[k] = v; });
    if (!("locale" in hints))
    {
      metadata_hints["locale"] = new Variant.string (default_locale);
    }
    return SearchMetadata.create (metadata_hints);
  }

  private bool timeout_reached ()
  {
    if (_query_happened)
    {
      _query_happened = false;
      return true;
    }
    else if (PROCESS_TIMEOUT_SEC > 0)
    {
      _inactivity_timeout_source_id = 0;
      on_timeout_reached ();
      return false;
    }

    _inactivity_timeout_source_id = 0;
    return false;
  }


  /*
   * DBus Interface Implementation
   */
  public async ActivationReplyRaw activate (
      string channel_id,
      Variant[] result_arr,
      uint action_type,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws IOError, ScopeError
  {
    var reply = ActivationReplyRaw ();
    ActivationResponse? response = null;
    Preview? preview = null;

    if (result_arr.length != RESULTS_SCHEMA.length)
      throw new ScopeError.REQUEST_FAILED ("Invalid result array");

    _query_happened = true;

    ScopeResult scope_result = ScopeResult ();
    scope_result.uri = result_arr[ResultColumn.URI].get_string ();
    scope_result.icon_hint = result_arr[ResultColumn.ICON_HINT].get_string ();
    scope_result.category = result_arr[ResultColumn.CATEGORY].get_uint32 ();
    scope_result.result_type = (ResultType) result_arr[ResultColumn.RESULT_TYPE].get_uint32 ();
    scope_result.mimetype = result_arr[ResultColumn.MIMETYPE].get_string ();
    scope_result.title = result_arr[ResultColumn.TITLE].get_string ();
    scope_result.comment = result_arr[ResultColumn.COMMENT].get_string ();
    scope_result.dnd_uri = result_arr[ResultColumn.DND_URI].get_string ();
    if (result_arr[ResultColumn.METADATA].get_type ().equal (VariantType.VARDICT))
    {
      scope_result.metadata = (HashTable<string, Variant>) result_arr[ResultColumn.METADATA];
    }

    ActionType action = (ActionType) action_type;
    SearchMetadata metadata = create_search_metadata (hints);
    switch (action)
    {
      case ActionType.ACTIVATE_RESULT:
        response = owner.activate (scope_result, metadata, null);
        break;
      case ActionType.PREVIEW_RESULT:
        preview = yield preview_internal (scope_result, metadata);
        break;
      case ActionType.PREVIEW_ACTION:
        Variant act_id_v = hints[ACTIVATE_PREVIEW_ACTION_HINT];
        if (act_id_v == null || !act_id_v.get_type ().equal (VariantType.STRING))
        {
          throw new ScopeError.REQUEST_FAILED ("Invoking preview action requires '%s' hint".printf (ACTIVATE_PREVIEW_ACTION_HINT));
        }
        response = owner.activate (scope_result, metadata,
                                   act_id_v.get_string ());
        break;
      default:
        warning ("Unknown activation ActionType: %u", action_type);
        break;
    }

    _query_happened = true;

    if (response != null && response.handled == HandledType.SHOW_PREVIEW)
    {
      if (response.get_preview () == null)
      {
        // recurse to emit preview-uri if ActivationResponse was created
        // without a preview
        var new_uri = response.goto_uri;
        if (new_uri != null) result_arr[ResultColumn.URI] = new_uri;
        reply = yield activate (channel_id, result_arr,
                                ActionType.PREVIEW_RESULT,
                                hints, cancellable);
        return reply;
      }
      else if (preview == null)
      {
        preview = response.get_preview ();
      }
    }

    if (preview != null)
    {
      response = new ActivationResponse.with_preview (preview);
    }

    if (response == null)
      response = new ActivationResponse (HandledType.NOT_HANDLED);

    reply.uri = scope_result.uri;
    if (response.goto_uri != null)
    {
      var stripped = response.goto_uri.strip ();
      if (stripped != "") reply.uri = stripped;
    }
    reply.handled = response.handled;
    reply.hints = response.get_hints ();

    if (cancellable != null) cancellable.set_error_if_cancelled ();
    return reply;
  }

  private async HashTable<string, Variant> search_internal (
      string search_string, HashTable<string, Variant> hints,
      ScopeChannel channel) throws ScopeError
  {
    // Point of this is to always do just one active search per channel.
    // Therefore we keep last_search in the Channel class and here it will
    // be cancelled if it didn't finish yet, or we'll wait for it in case
    // the dbus peer called Search("foo") multiple times.

    HashTable<string, Variant> result =
        new HashTable<string, Variant> (str_hash, str_equal);
    var search_type = channel.get_search_type ();

    // if filters changed, invalidate last search
    unowned Variant filter_row_variant = hints[SEARCH_FILTER_ROW_HINT];
    if (filter_row_variant != null)
    {
      update_filter_state (channel, filter_row_variant);

      if (channel.last_search != null)
        channel.last_search.search_context.cancellable.cancel ();
      channel.last_search = null;
    }

    var normalized_query = owner.normalize_search_query (search_string);
    if (normalized_query == null) normalized_query = search_string;

    // did the search really change?
    ScopeSearchBase? last_search = channel.last_search;
    if (last_search != null)
    {
      if (last_search.search_context.search_query == normalized_query)
      {
        // did the search finish?
        if (channel.is_search_running ())
        {
          // wait for the previous search to finish and then return
          yield channel.wait_for_search ();
        }
        result[SEARCH_SEQNUM_HINT] = new Variant.uint64 (channel.get_last_seqnum ());
        return result;
      }
      else
      {
        last_search.search_context.cancellable.cancel ();
      }
    }

    // TODO: add locale and location to the hints if not present

    // prepare new ScopeSearch instance
    var cancellable = new Internal.GLibCancellable ();
    SearchContext search_context = SearchContext ();
    search_context.search_query = normalized_query;
    search_context.search_type = search_type;
    search_context.filter_state = channel.filters;
    search_context.search_metadata = create_search_metadata (hints);
    // careful here, we could be sharing one DeeModel to multiple threads,
    // although keeping just one search active at a time, to make it "safe"
    var result_set = new DeeResultSet.with_model (channel.backend_model);
    result_set.ttl = -1;
    search_context.result_set = result_set;
    search_context.cancellable = cancellable;

    var search = owner.create_search_for_query (search_context);
    if (search == null)
    {
      var msg = "DBus connector requires instance of ScopeSearchBase!";
      warning ("%s", msg);
      throw new ScopeError.REQUEST_FAILED (msg);
    }

    channel.last_search = search;

    // wait for the search to finish... careful, might be running in a thread
    // should we save the MainContext?
    try
    {
      if (!channel.model_lock.try_lock ()) yield channel.model_lock.lock ();
      channel.set_state (ChannelState.SEARCH_ACTIVE);
      channel.backend_model.clear ();

      // wait for idle, so requests that came after this one can cancel this
      // before we even run it
      Idle.add_full (Priority.LOW, search_internal.callback);
      yield;

      if (cancellable.is_cancelled ())
      {
        throw new ScopeError.SEARCH_CANCELLED ("Search '%s' was cancelled",
                                               normalized_query);
      }

      result_set.flush_model = channel.transfer_model;

      int64 search_start_time = 0;
      if (measure_requests) search_start_time = get_monotonic_time ();
      int64 search_end_time = search_start_time;

      Unity.Trace.tracepoint ("search:start::scope=%s;query=%s", _dbus_name, normalized_query);

      if (force_sync_requests)
      {
        // this is really just a debug option
        search.run ();
        if (measure_requests) search_end_time = get_monotonic_time ();
      }
      else
      {
        /* NOTE: careful here, the default implementation will spawn
         * a new thread and invoke run() from it, if the run() method
         * is implemented in python, it might barf cause the interpreter
         * state for that thread will be undefined.
         */
        search.run_async (() =>
        {
          if (measure_requests) search_end_time = get_monotonic_time ();
          Idle.add_full (Priority.DEFAULT, search_internal.callback);
        });

        yield;
      }

      Unity.Trace.tracepoint ("search:end::scope=%s;query=%s", _dbus_name, normalized_query);

      // FIXME: handle no-reply-hint etc!
      if (!cancellable.is_cancelled ())
      {
        result_set.flush ();
        result[SEARCH_SEQNUM_HINT] = new Variant.uint64 (channel.get_last_seqnum ());
      }
      if (measure_requests)
      {
        int64 delta_us = search_end_time - search_start_time;
        double delta = delta_us / 1000000.0;
        result[SEARCH_TIME_HINT] = new Variant.double (delta);
      }
    }
    finally
    {
      channel.set_state (ChannelState.IDLE);
      channel.model_lock.unlock ();
    }

    if (cancellable.is_cancelled ())
    {
      throw new ScopeError.SEARCH_CANCELLED ("Search '%s' was cancelled",
                                             normalized_query);
    }

    return result;
  }

  public async HashTable<string, Variant> search (
      string channel_id,
      string search_string,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws IOError, ScopeError
  {
    _query_happened = true;
    HashTable<string, Variant> result;

    var channel = get_channel_by_id (channel_id);
    result = yield search_internal (search_string, hints, channel);

    if (PROCESS_TIMEOUT_SEC > 0)
    {
      // after first search request, a timeout is started and if no activity
      // happens while the timeout runs, the on_timeout_reached signal
      // will be emitted, which might end up quitting this process
      if (_inactivity_timeout_source_id == 0)
      {
        _inactivity_timeout_source_id =
          Timeout.add_seconds_full (Priority.DEFAULT_IDLE,
                                    (uint) PROCESS_TIMEOUT_SEC,
                                    timeout_reached);
      }
      _query_happened = true;
    }

    return result;
  }

  public async Preview preview_internal (ScopeResult scope_result, SearchMetadata metadata)
  {
    ResultPreviewer previewer = owner.create_previewer (scope_result, metadata);

    Preview? response = null;
    /* NOTE: careful here, the default implementation will spawn
     * a new thread and invoke run() from it, if the run() method
     * is implemented in python, it might barf cause the interpreter
     * state for that thread will be undefined.
     */
    if (previewer is ResultPreviewer)
    {
      previewer.run_async ((obj, preview) =>
      {
        // FIXME: join AbstractPreview and Preview classes?
        //   (preview is abstract anyway)
        response = preview as Preview;
        Idle.add_full (Priority.DEFAULT, preview_internal.callback);
      });

      yield;
    }

    if (response == null)
    {
      response = GenericPreview.empty ();
      response.title = scope_result.title;
      response.description_markup = Markup.escape_text (scope_result.comment);

      var icon = ContentType.get_icon (scope_result.mimetype);
      response.image = icon;
    }

    return response;
  }

  private void update_filter_state (ScopeChannel channel,
                                    Variant changed_row) throws ScopeError
  {
    if (changed_row.get_type_string () != "(ssssa{sv}bbb)")
    {
      throw new ScopeError.REQUEST_FAILED ("Incorrect signature of filter-state (got '%s')".printf (changed_row.get_type_string ()));
    }

    string filter_id;
    changed_row.get_child (FilterColumn.ID, "s", out filter_id);
    var filter = channel.get_filter_by_id (filter_id);

    if (filter == null)
    {
      throw new ScopeError.REQUEST_FAILED ("Unable to find filter with id '%s'".printf (filter_id));
    }
    // update() will just update the hints, need to handle base props

    bool state;
    changed_row.get_child (FilterColumn.FILTERING, "b", out state);
    filter.filtering = state;
    changed_row.get_child (FilterColumn.COLLAPSED, "b", out state);
    filter.collapsed = state;
    filter.update (changed_row.get_child_value (FilterColumn.RENDERER_STATE));
  }

  public async string open_channel (
      uint channel_type,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable,
      BusName? sender,
      out HashTable<string, Variant> out_hints) throws IOError
  {
    ChannelFlags flags = ChannelFlags.from_hints (hints);
    var channel = new ScopeChannel ((ChannelType) channel_type);

    var schema = owner.get_schema ();
    var required_schema = new HashTable<string, string> (str_hash, str_equal);
    var optional_schema = new HashTable<string, string> (str_hash, str_equal);
    foreach (unowned Unity.Schema.FieldInfo? field in schema.get_fields ())
    {
      if (field.type == Schema.FieldType.REQUIRED)
        required_schema[field.name] = field.schema;
      else
        optional_schema[field.name] = field.schema;
    }
    var model_name = channel.create_channel (create_dbus_name (),
                                             required_schema,
                                             optional_schema,
                                             filters_model,
                                             flags);

    if (channel.transfer_model != null)
    {
      yield Internal.Utils.wait_for_model_synchronization (channel.transfer_model);
      if (sender != null)
      {
        channel.watch_owner (_dbus_connection, sender);
        channel.owner_lost.connect (this.channel_owner_lost);
      }
    }

    _channels[channel.id] = channel;

    out_hints = new HashTable<string, Variant> (str_hash, str_equal);
    out_hints[CHANNEL_SWARM_NAME_HINT] = new Variant.string (model_name);

    return channel.id;
  }

  private ScopeChannel get_channel_by_id (string channel_id) 
    throws ScopeError
  {
    unowned ScopeChannel channel = _channels[channel_id];
    if (channel == null)
      throw new ScopeError.INVALID_CHANNEL ("Invalid channel ID!");

    return channel;
  }

  private void channel_owner_lost (ScopeChannel channel)
  {
    var empty = new HashTable<string, Variant> (str_hash, str_equal);
    close_channel.begin (channel.id, empty, null);
  }

  public async void close_channel (
      string channel_id,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws IOError, ScopeError
  {
    if (_channels.remove (channel_id) == false)
      throw new ScopeError.INVALID_CHANNEL ("Invalid channel ID!");
  }

  public async void set_view_type (uint view_type_id) throws IOError
  {
    ViewType view_type = (ViewType) view_type_id;
    this.view_type = view_type;
  }

  public async void set_active_sources (
      string channel_id, string[] sources,
      GLib.Cancellable? cancellable) throws IOError
  {
  }

  public async HashTable<string, Variant> push_results (
      string channel_id,
      string search_string,
      string source_scope_id,
      Variant result,
      string[] categories,
      GLib.Cancellable? cancellable = null) throws IOError, ScopeError
  {
    throw new ScopeError.REQUEST_FAILED ("Regular scopes don't support results pushing");
  }
 
  /* DBus properties */
  public int protocol_version { get { return 1; } }
  // FIXME: we shouldn't hardcode these two
  public bool visible { get { return true; } }
  public bool is_master { get { return false; } }
  public string search_hint
  {
    owned get { return owner.get_search_hint () ?? ""; }
  }
  public HashTable<string, string> metadata
  {
    owned get
    {
      var schema = owner.get_schema ();
      var required_schema = new HashTable<string, string> (str_hash, str_equal);
      foreach (unowned Unity.Schema.FieldInfo? field in schema.get_fields ())
      {
        if (field.type == Schema.FieldType.REQUIRED)
          required_schema[field.name] = field.schema;
      }
      return required_schema;
    }
  }
  public HashTable<string, string> optional_metadata
  {
    owned get
    {
      var schema = owner.get_schema ();
      var optional_schema = new HashTable<string, string> (str_hash, str_equal);
      foreach (unowned Unity.Schema.FieldInfo? field in schema.get_fields ())
      {
        if (field.type == Schema.FieldType.OPTIONAL)
          optional_schema[field.name] = field.schema;
      }
      return optional_schema;
    }
  }
  public Variant categories
  {
    owned get { return categories_model.serialize (); }
  }
  public Variant filters
  {
    owned get { return filters_model.serialize (); }
  }
  public HashTable<string, Variant> hints
  {
    owned get { return new HashTable<string, Variant> (null, null); }
  }
}

private struct OwnedName {
  public int ref_count;
  public uint bus_name_own_handle;
}

private class ScopeDBusNameManager : Object
{
  private HashTable<string,OwnedName?> owned_names;

  private ScopeDBusNameManager ()
  {
    owned_names = new HashTable<string,OwnedName?> (str_hash, str_equal);
  }

  static ScopeDBusNameManager? name_manager;
  public static ScopeDBusNameManager get_default ()
  {
    if (name_manager == null)
    {
      name_manager = new ScopeDBusNameManager ();
    }
    return name_manager;
  }

  public void own_name (string dbus_name)
  {
    unowned OwnedName? info = owned_names.get (dbus_name);
    if (info != null)
    {
      info.ref_count += 1;
    }
    else
    {
      owned_names.insert (dbus_name, {1, 0});
    }
  }

  [Signal (detailed=true)]
  public signal void name_unowned ();

  public void unown_name (string dbus_name)
  {
    unowned Internal.OwnedName? info = owned_names.get (dbus_name);
    if (info != null)
    {
      info.ref_count -= 1;
      // Ref count dropped to zero => release the name if it has been acquired
      if (info.ref_count <= 0)
      {
        if (info.bus_name_own_handle != 0)
        {
          Bus.unown_name (info.bus_name_own_handle);
          Signal.emit_by_name (this, "name_unowned::" + dbus_name, typeof (void));
        }
        owned_names.remove (dbus_name);
      }
    }
  }

  public async bool acquire_names ()
  {
    var count = 0;
    var failures = 0;
    owned_names.for_each ((dbus_name, info) =>
      {
        if (info.bus_name_own_handle != 0)
        {
          // The name has already been requested.
          return;
        }
        count += 1;
        info.bus_name_own_handle = Bus.own_name (
          BusType.SESSION, dbus_name, BusNameOwnerFlags.NONE, null,
          () => {
            count -= 1;
            if (count <= 0)
            {
              Idle.add_full (Priority.DEFAULT, acquire_names.callback);
            }
          },
          () => {
            failures += 1;
            warning (@"Unable to own DBus name '$dbus_name'");
            count -= 1;
            if (count <= 0)
            {
              Idle.add_full (Priority.DEFAULT, acquire_names.callback);
            }
          }
          );
      });
    yield;
    return failures == 0;
  }

}

} /* namespace */
