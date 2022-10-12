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
 * Note: Yes, this pretty much copies unity-scope-dbus-impl.vala, but
 *       there are tiny differences and we'll get rid of this file soon
 */

using Dee;
using Unity;
using Unity.Protocol;

namespace Unity.Internal {

private interface DeprecatedScopeDBusImpl : ScopeDBusImpl
{
  public abstract void set_categories (List<unowned Category> categories);
  public abstract void set_filters (List<unowned Filter> filters);
}
/*
 * The private implementation of the Scope. This makes sure that none of the 
 * implementation details leak out into the public interface.
 */
private class DeprecatedScopeImpl : GLib.Object, ScopeService, ScopeDBusImpl, DeprecatedScopeDBusImpl
{
  private const string SOURCES_FILTER_ID = "unity-sources";

  public unowned DeprecatedScope owner { private get; construct; }
  private HashTable<string, ScopeChannel> _channels;
  private uint _dbus_id;
  private DBusConnection? _dbus_connection;
  private HashTable<string, PreviewAction> _action_map;
  private Rand _rand;

  public Dee.SerializableModel categories_model { get; set; }
  public Dee.SerializableModel filters_model { get; set; }

  /* we need notifications on this property */
  public ViewType view_type { get; set; }

  public DeprecatedScopeImpl (DeprecatedScope owner)
  {
    Object (owner: owner);
  }

  static bool measure_requests;
  static construct
  {
    measure_requests =
      Environment.get_variable (VAR_MEASURED_SEARCHES) != null;
  }

  construct
  {
    _rand = new Rand ();
    _action_map = new HashTable<string, PreviewAction> (str_hash, str_equal);
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
    var dbus_name = format_string.printf (Path.get_basename (owner.dbus_path),
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
    _dbus_connection = Bus.get_sync (BusType.SESSION);
    _dbus_id = _dbus_connection.register_object (owner.dbus_path,
                                                 this as ScopeService);
  }

  public void unexport ()
  {
    if (_dbus_id != 0)
    {
      _dbus_connection.unregister_object (_dbus_id);
      _dbus_id = 0;
      _dbus_connection = null;
    }
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
          _dbus_connection.emit_signal (null, owner.dbus_path,
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

    if (_dbus_id != 0)
    {
      queue_property_notification ("Categories",
                                   new Variant.variant (this.categories));
    }
  }

  public void set_filters (List<unowned Filter> filters)
  {
    filters_model.clear ();

    foreach (unowned Filter filter in filters)
    {
      filter.changed.connect (on_filter_option_changed);
    }

    List<unowned Filter> filters_and_sources = filters.copy ();
    if (owner.sources.options.length () > 0)
      filters_and_sources.append (owner.sources);

    Variant data[8];
    foreach (unowned Filter filter in filters_and_sources)
    {
      var serialized_filter = filter.serialize ();
      for (size_t i = 0; i < serialized_filter.n_children (); i++)
        data[i] = serialized_filter.get_child_value (i);

      filters_model.append_row (data);
    }

    if (_dbus_id != 0)
    {
      queue_property_notification ("Filters",
                                   new Variant.variant (this.filters));
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
    switch (action)
    {
      case ActionType.ACTIVATE_RESULT:
        response = yield owner.activate_result (scope_result);
        break;
      case ActionType.PREVIEW_RESULT:
        preview = yield owner.preview_result (scope_result);
        if (preview == null)
        {
          preview = GenericPreview.empty ();
          preview.title = scope_result.title;
          preview.description_markup = Markup.escape_text (scope_result.comment);

          var icon = ContentType.get_icon (scope_result.mimetype);
          preview.image = icon;
        }
        break;
      case ActionType.PREVIEW_ACTION:
        Variant act_id_v = hints[ACTIVATE_PREVIEW_ACTION_HINT];
        if (act_id_v == null || !act_id_v.get_type ().equal (VariantType.STRING))
        {
          throw new ScopeError.REQUEST_FAILED ("Invoking preview action requires '%s' hint".printf (ACTIVATE_PREVIEW_ACTION_HINT));
        }
        string action_id = act_id_v.get_string ();
        response = activate_action (action_id, scope_result.uri, hints);
        break;
      default:
        warning ("Unknown activation ActionType: %u", action_type);
        break;
    }

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
      /* FIXME: we can't keep doing this, needs to be changed */
      /* Make sure the actions are registered. */
      var actions = preview.get_actions ();
      for (uint i = 0; i < actions.length; i++)
      {
        unowned PreviewAction preview_action = actions[i];
        _action_map[preview_action.id] = preview_action;
      }

      response = new ActivationResponse.with_preview (preview);
    }

    if (response == null)
      response = new ActivationResponse (HandledType.NOT_HANDLED);

    // FIXME: pass goto_uri ?
    reply.uri = scope_result.uri;
    reply.handled = response.handled;
    reply.hints = response.get_hints ();

    if (cancellable != null) cancellable.set_error_if_cancelled ();
    return reply;
  }

  private string? get_search_key (DeprecatedScopeSearch search)
  {
    var search_type = search.search_context.search_type;
    string? search_key = search_type == SearchType.DEFAULT ?
        owner.generate_search_key["default"] (search) :
        owner.generate_search_key["global"] (search);

    return search_key;
  }

  public void queue_search_for_type (SearchType search_type)
    requires (search_type < SearchType.N_TYPES)
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

    // if filters changed, invalidate last search
    unowned Variant filter_row_variant = hints[SEARCH_FILTER_ROW_HINT];
    if (filter_row_variant != null)
    {
      update_filter_state (channel, filter_row_variant);

      if (channel.last_search != null)
        channel.last_search.search_context.cancellable.cancel ();
      channel.last_search = null;
    }
    // FIXME: handle sources filter here as well

    var cancellable = Unity.Cancellable.create ();
    SearchContext search_context = SearchContext ();
    search_context.search_query = search_string;
    search_context.search_type = channel.get_search_type ();
    search_context.filter_state = channel.filters;
    search_context.search_metadata = SearchMetadata.create (hints);
    var result_set = new DeeResultSet.with_model (channel.backend_model);
    result_set.ttl = -1;
    search_context.result_set = result_set;
    search_context.cancellable = cancellable;

    // prepare new ScopeSearch instance
    var new_search = new DeprecatedScopeSearch (owner, channel.id,
                                                hints, channel.backend_model);
    new_search.set_search_context (search_context);
    // two ways to add results, yey!
    var normalized_query = get_search_key (new_search);
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
        var last_depr_search = last_search as DeprecatedScopeSearch;
        var last_hints = last_depr_search.get_reply_hints ();
        if (last_hints != null)
        {
          if (SEARCH_NO_RESULTS_HINT in last_hints)
            result[SEARCH_NO_RESULTS_HINT] = last_hints[SEARCH_NO_RESULTS_HINT];
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
    channel.last_search = new_search;

    // wait for the search to finish... careful, might be running in a thread
    // should we save the MainContext?
    try
    {
      if (!channel.model_lock.try_lock ()) yield channel.model_lock.lock ();
      channel.set_state (ChannelState.SEARCH_ACTIVE);
      // don't clear the model, the deprecated scopes do that themselves
      //channel.backend_model.clear ();

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

      Unity.Trace.tracepoint ("search:start::scope=%s", owner.id);

      new_search.run_async (() =>
      {
        if (measure_requests) search_end_time = get_monotonic_time ();
        Idle.add_full (Priority.DEFAULT, search_internal.callback);
      });
      yield;

      if (!cancellable.is_cancelled ())
      {
        result_set.flush ();
        result[SEARCH_SEQNUM_HINT] = new Variant.uint64 (channel.get_last_seqnum ());
      }

      Unity.Trace.tracepoint ("search:end::scope=%s", owner.id);

      if (measure_requests)
      {
        int64 delta_us = search_end_time - search_start_time;
        double delta = delta_us / 1000000.0;
        result[SEARCH_TIME_HINT] = new Variant.double (delta);
      }

      // handle hints
      var reply_hints = new_search.get_reply_hints ();
      if (reply_hints != null)
      {
        if (SEARCH_NO_RESULTS_HINT in reply_hints)
          result[SEARCH_NO_RESULTS_HINT] = reply_hints[SEARCH_NO_RESULTS_HINT];
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
    HashTable<string, Variant> result;

    var channel = get_channel_by_id (channel_id);
    result = yield search_internal (search_string, hints, channel);

    return result;
  }

  public ActivationResponse? activate_action (string action_id, string uri,
                                              HashTable<string, Variant> hints)
  {
    ActivationResponse? response = null;
    var action = _action_map[action_id];
    if (action != null)
    {
      var action_hints = action.hints;
      action_hints.remove_all ();
      if (hints.size () > 0)
      {
        HashTableIter<string, Variant> iter = HashTableIter<string, Variant> (hints);
        unowned string key;
        unowned Variant value;
        while (iter.next (out key, out value))
        {
          action_hints[key] = value;
        }
      }
      response = action.activated (uri);
    }
    else
      warning ("Cannot find PreviewAction with id: %s", action_id);

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

    var schema = owner.schema;
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
      // force AUTOMATIC flushing for the deprecated scopes as they don't
      // expect the ResultSet to have a separate flush() method
      channel.transfer_model.flush_mode = Dee.SharedModelFlushMode.AUTOMATIC;
      yield Internal.Utils.wait_for_model_synchronization (channel.transfer_model);
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
    owner.set_active_sources_internal (sources);
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
  public bool visible { get { return owner.visible; } }
  public bool is_master { get { return owner.is_master; } }
  public string search_hint { owned get { return owner.search_hint ?? ""; } }
  public HashTable<string, string> metadata
  {
    owned get
    {
      var schema = owner.schema;
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
      var schema = owner.schema;
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

} /* namespace Unity.Internal */
