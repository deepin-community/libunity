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
 *
 */

using Unity.Protocol;

namespace Unity {

public class MasterScope : AggregatorScope
{
  const int COALESCE_TIME_MS = 150;

  public MasterScope (string dbus_path_, string id_)
  {
    Object (dbus_path: dbus_path_, id: id_, is_master: true,
            merge_mode: AggregatorScope.MergeMode.CATEGORY_ID,
            proxy_filter_hints: true, automatic_flushing: false);
  }

  public string no_content_hint { get; set; }

  private Internal.Utils.AsyncOnce<ScopeRegistry> registry_once;

  construct
  {
    registry_once = new Internal.Utils.AsyncOnce<ScopeRegistry> ();
  }

  private bool metadata_matches (ScopeRegistry.ScopeMetadata metadata)
  {
    var dict = new HashTable<string, string> (str_hash, str_equal);
    foreach (unowned Schema.FieldInfo? info in schema.get_fields ())
    {
      if (info.type == Schema.FieldType.REQUIRED)
        dict[info.name] = info.schema;
    }
    if (dict.size () == 0) return true;
    if (metadata.required_metadata == null) return false;

    var child_dict = metadata.required_metadata.as_hash_table ();
    unowned string field_name;
    unowned string schema;
    var iter = HashTableIter<string, string> (dict);
    while (iter.next (out field_name, out schema))
    {
      if (child_dict[field_name] != schema) return false;
    }

    return true;
  }

  private async void wait_for_registry ()
  {
    if (yield registry_once.enter ())
    {
      ScopeRegistry? registry = null;
      try
      {
        registry = yield ScopeRegistry.find_scopes_for_id (this.id);
      }
      catch (Error err)
      {
        warning ("Unable to initialize ScopeRegistry: '%s'", err.message);
      }
      registry_once.leave (registry);
    }
  }

  /**
   * Not really used for merge mode = DISPLAY_NAME
   */
  public override int category_index_for_scope_id (string scope_id)
  {
    return -1;
  }

  protected override async void search (AggregatedScopeSearch scope_search)
  {
    if (!registry_once.is_initialized ()) yield wait_for_registry ();

    var registry = registry_once.get_data ();
    if (registry == null) return;

    uint total_searches = 0;
    uint running_searches = 0;
    uint timer_source_id = 0;

    AsyncReadyCallback cb = (obj, res) =>
    {
      var agg_search = obj as AggregatedScopeSearch;
      try
      {
        agg_search.search_scope.end (res);
      }
      catch (Error err)
      {
        if (!(err is IOError.CANCELLED))
          warning ("Unable to search scope: '%s'", err.message);
      }
      if (--running_searches == 0) search.callback ();
    };

    string[] search_subscopes = {};

    var filter_variant = scope_search.hints[Internal.SEARCH_SUBSCOPES_HINT];
    if (filter_variant != null && filter_variant.get_type_string () == "as")
    {
      search_subscopes = (string[]) filter_variant;
    }

    ulong sig_id;
    sig_id = scope_search.transaction_complete.connect ((agg_scope_search, scope_id) =>
    {
      // if we're searching multiple scopes, try to coalesce the changes,
      // otherwise flush the changes immediately
      if (total_searches <= 1)
      {
        agg_scope_search.search_context.result_set.flush ();
      }
      else
      {
        // TODO: do this only if this channel is "visible" (opened by the dash)
        if (timer_source_id != 0) return;
        timer_source_id = Timeout.add (COALESCE_TIME_MS, () =>
        {
          if (!agg_scope_search.search_context.cancellable.is_cancelled ())
          {
            agg_scope_search.search_context.result_set.flush ();
          }
          timer_source_id = 0;
          return false;
        });
      }
    });

    foreach (var scope_node in registry.scopes)
    {
      if (search_subscopes.length > 0 && !(scope_node.scope_info.id in search_subscopes))
        continue;

      if (metadata_matches (scope_node.scope_info))
      {
        total_searches++;
        running_searches++;
        scope_search.search_scope.begin (scope_node.scope_info.id,
                                         scope_search.search_string,
                                         scope_search.search_type,
                                         null, cb);
      }
      else
      {
        warning ("Metadata for '%s' doesn't match the master scope",
                 scope_node.scope_info.id);
      }
    }

    if (running_searches > 0) yield;

    SignalHandler.disconnect (scope_search, sig_id);
    if (timer_source_id != 0)
    {
      Source.remove (timer_source_id);
      scope_search.search_context.result_set.flush ();
    }

    if (scope_search.results_model.get_n_rows () == 0
      && scope_search.search_context.search_query.strip () == ""
      && no_content_hint != null)
    {
      scope_search.set_reply_hint (Internal.SEARCH_NO_RESULTS_HINT,
                                   new Variant.string (no_content_hint));
    }
  }
}

} /* namespace */
