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
 * Authored by Michal Hruby <michal.hruby@canonical.com>
 *             Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */

using Unity.Protocol;

namespace Unity {

public abstract class AggregatorScope : DeprecatedScopeBase
{
  public enum SortFlags
  {
    ASCENDING,
    DESCENDING,

    CASE_INSENSITIVE = 1 << 10
  }

  public enum MergeMode
  {
    CATEGORY_ID,
    OWNER_SCOPE
  }

  public MergeMode merge_mode { get; set; }

  public bool proxy_filter_hints { get; set; }

  public bool automatic_flushing { get; set; default = true; }

  /**
   * Maps scope ids to associated category index, needed if merge mode is OWNER_SCOPE.
   * A dummy implementation may be provided for merge mode = DISPLAY_NAME.
   */
  public abstract int category_index_for_scope_id (string scope_id);

  protected AggregatorScope (string dbus_path_, string id_, MergeMode merge_mode = AggregatorScope.MergeMode.OWNER_SCOPE, bool proxy_filter_hints = false)
  {
    Object (dbus_path: dbus_path_, id: id_, is_master: true,
            merge_mode: merge_mode, proxy_filter_hints: proxy_filter_hints);
  }

  /**
   * Sort data in a given category by values of 'field'.
   *
   * Aggregating results from multiple scopes often needs a clear way to sort
   * the results, to do that you can define category-specific sorting rules.
   * As an example, a category displaying recent items might be sorted using
   * a "timestamp" field (which would be defined as either a required or 
   * optional metadata field {@link Unity.Scope.metadata_schema}).
   * For categories that don't have any obvious order it is recommended to sort
   * them according to the "title" field.
   *
   * @param category_index Index of the sorted category
   * @param field Name of the field the order will be based on
   * @param flags The way sorting is performed
   */
  public void add_sorter (uint category_index, string field, SortFlags flags)
  {
    var pimpl = get_impl () as Internal.AggregatorScopeImpl;
    pimpl.add_sorter (category_index, field, flags);
  }

  /**
   * Constraint data to be unique according to value of 'field'.
   *
   * This method allows de-duplication of results from multiple scopes
   * by only allowing unique values for the given field.
   * As an example, a scope that is aggregating results from different local
   * music databases could simply constraint the results on values of the "uri"
   * field, which would ensure that songs with the same uri are displayed only
   * once.
   * 
   * @param category_index Index of the constrained category,
   *                       or -1 to constraint all categories
   * @param field Name of the constrained field
   */
  public void add_constraint (int category_index, string field)
  {
    var pimpl = get_impl () as Internal.AggregatorScopeImpl;
    pimpl.add_constraint (category_index, field);
  }

  public abstract async void search (Unity.AggregatedScopeSearch scope_search);

  public virtual async ActivationResponse? activate (Unity.AggregatorActivation activation)
  {
    return null;
  }

  internal async HashTable<string, Variant> search_scope (
      Unity.AggregatedScopeSearch search,
      string scope_id,
      string search_query,
      SearchType search_type,
      HashTable<string, Variant>? hints,
      GLib.Cancellable? cancellable) throws Error
  {
    var pimpl = get_impl () as Internal.AggregatorScopeImpl;
    try
    {
      var res = yield pimpl.search_scope (search, scope_id, search_query,
                                          search_type, hints, cancellable);
      return res;
    }
    catch (ScopeError.DISABLED_CONTENT scope_error)
    {
      // not really an error
      return new HashTable<string, Variant> (str_hash, str_equal);
    }
  }

  internal async void push_results (string channel_id, string search_string,
                                    string scope_id,
                                    Dee.SerializableModel results_model,
                                    string[] category_ids,
                                    GLib.Cancellable? cancellable)
  {
    var pimpl = get_impl () as Internal.AggregatorScopeImpl;
    try
    {
      yield pimpl.push_results_to_scope (channel_id, search_string,
                                         scope_id, results_model,
                                         category_ids, cancellable);
    }
    catch (Error err)
    {
      warning ("%s", err.message);
    }
  }

  internal void push_filter_settings (string channel_id, FilterSet filters)
  {
    var pimpl = get_impl () as Internal.AggregatorScopeImpl;
    pimpl.push_filter_settings (channel_id, filters);
  }

  internal override Object create_impl ()
  {
    return new Internal.AggregatorScopeImpl (this);
  }
}

} /* namespace */
