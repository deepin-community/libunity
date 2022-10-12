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

public abstract class DeprecatedScopeBase : GLib.Object
{
  public string id { get; construct; }
  public string dbus_path { get; construct; }

  public bool search_in_global { get; set; default = false; }
  public bool visible { get; set; default = true; }
  public bool is_master { get; construct; default = false; }
  public string search_hint { get; set; }
  public OptionsFilter sources { get; internal set; }
  public CategorySet categories
  {
    get { return _categories; }
    set 
    {
      _categories = value;
      _pimpl.set_categories (value.get_categories ());
    }
  }
  public FilterSet filters
  {
    get { return _filters; }
    set
    {
      _filters = value;
      _pimpl.set_filters (value.get_filters ());
    }
  }

  public Schema schema { get; set; }

  public signal void active_sources_changed (string[] active_ids);

  private Internal.DeprecatedScopeDBusImpl _pimpl;
  private bool exported = false;
  private bool is_local = false;
  internal CategorySet _categories;
  internal FilterSet _filters;
   
  protected DeprecatedScopeBase (string dbus_path_, string id_)
  {
    Object (dbus_path: dbus_path_, id: id_);
  }

  construct
  {
    schema = new Schema ();
    sources = new CheckOptionFilter ("unity-sources", "Sources", null, true);
  }

  protected override void constructed ()
  {
    _pimpl = create_impl () as Internal.DeprecatedScopeDBusImpl;
  }

  internal abstract Object create_impl ();

  internal unowned Object get_impl ()
  {
    return _pimpl;
  }

  public void export () throws Error
  {
    if (!exported && !is_local)
    {
      _pimpl.export ();
      exported = true;
    }
  }

  public void unexport ()
  {
    if (exported)
    {
      _pimpl.unexport ();
      exported = false;
    }
  }

  /*
   * For our private implmentation
   */
  internal void set_view_type_internal (Protocol.ViewType view_type)
  {
    // FIXME: should be channel-specific, right?
    //_pimpl.view_type = view_type;
  }

  internal void set_active_sources_internal (string[] active_sources_)
  {
    foreach (var filter_option in sources.options)
    {
      filter_option.active = filter_option.id in active_sources_;
    }

    this.active_sources_changed (active_sources_);
  }

  /*
   * For local Scope implementations, only used internally
   */
  internal async HashTable<string, Variant> handle_search (
      string channel_id,
      string search_string,
      HashTable<string, Variant> hints) throws Error
  {
    var result = yield _pimpl.search (channel_id, search_string, hints);
    return result;
  }
}

public class DeprecatedScope : DeprecatedScopeBase
{
  public signal ActivationResponse? activate_uri (string uri);
  public signal Preview? preview_uri (string uri);
  [Signal (detailed = true)]
  public signal string generate_search_key (DeprecatedScopeSearch search);
  public signal void search_changed (DeprecatedScopeSearch search,
                                     SearchType search_type,
                                     GLib.Cancellable cancellable);

  public virtual async Preview? preview_result (ScopeResult result)
  {
    // by default we'll emit the preview_uri signal
    var preview = preview_uri (result.uri);
    return preview;
  }

  public virtual async ActivationResponse? activate_result (ScopeResult result)
  {
    // by default we'll emit the activate_uri signal
    var response = activate_uri (result.uri);
    return response;
  }

  public DeprecatedScope (string dbus_path_, string id_)
  {
    Object (dbus_path: dbus_path_, id: id_);
  }
  
  internal override Object create_impl ()
  {
    return new Internal.DeprecatedScopeImpl (this);
  }
  
  /**
   * Invalidates current search and queues new search.
   *
   * This method will invalidate (and cancel) last search and queue a new
   * search (with the same search_string). The {@link DeprecatedScope.search_changed}
   * signal will be emitted immediately in case the Lens managing this scope
   * is active, or as soon as it becomes active.
   *
   * @param search_type Type of search to queue.
   */
  public void queue_search_changed (SearchType search_type)
    requires (search_type < SearchType.N_TYPES)
  {
    // Note: this queues search for all channels!
    var pimpl = get_impl () as Internal.DeprecatedScopeImpl;
    pimpl.queue_search_for_type (search_type);
  }
}

} /* namespace */
