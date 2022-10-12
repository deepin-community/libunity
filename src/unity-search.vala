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

namespace Unity {

namespace Internal {

internal class GLibCancellable : Unity.Cancellable
{
  private GLib.Cancellable canc = new GLib.Cancellable ();

  public override void cancel () { canc.cancel (); }
  public override bool is_cancelled () { return canc.is_cancelled (); }
  public override GLib.Cancellable? get_gcancellable () { return canc; }
}

} /* namespace Unity.Internal */

/**
 * Internal transitioning class, note that it will disappear from the public
 * API as soon as possible and therefore shouldn't be used.
 */
public class DeprecatedScopeSearch : ScopeSearchBase
{
  public string channel_id { get; construct; }
  public string search_string { get { return search_context.search_query; } }
  public SearchType search_type { get { return search_context.search_type; } }
  public HashTable<string, Variant> hints { get; construct; }
  public Dee.SerializableModel results_model { get; construct; }
  public unowned DeprecatedScopeBase owner { get; construct; }

  public signal void finished ();

  private HashTable<string, Variant>? _reply_hints = null;

  internal DeprecatedScopeSearch (DeprecatedScope owner,
                                  string channel_id,
                                  HashTable<string, Variant> hints,
                                  Dee.SerializableModel results_model)
  {
    Object (owner:owner, channel_id:channel_id, hints:hints,
            results_model:results_model);
  }

  public void set_reply_hint (string key, Variant variant)
  {
    if (_reply_hints == null)
    {
      _reply_hints = new HashTable<string, Variant> (str_hash, str_equal);
    }

    _reply_hints.insert (key, variant);
  }

  internal HashTable<string, Variant>? get_reply_hints ()
  {
    return _reply_hints;
  }

  public unowned Filter? get_filter (string filter_id)
  {
    return this.search_context.filter_state.get_filter_by_id (filter_id);
  }

  public bool equals (DeprecatedScopeSearch other)
  {
    if (other == null ||
        search_string != other.search_string)
      return false;

    return true;
  }

  protected override void run ()
  {
    var ml = new MainLoop ();
    run_async (() => { ml.quit (); });
    ml.run ();
  }

  private async void real_async_run ()
  {
    bool waiting = false;
    bool search_finished = false;
    // emit search_changed and wait for finished signal
    ulong finished_sig_id = 0;
    finished_sig_id = finished.connect (() =>
    {
      search_finished = true;
      if (waiting) real_async_run.callback ();
    });

    if (finished_sig_id == 0)
    {
      critical ("Unexpected error ocurred");
      return;
    }

    // we can't resume this method as soon as the cancellable is cancelled,
    // cause the search might be still running and adding results to the result
    // set backed by a single Dee model which is shared among multiple searches

    var depr_scope = owner as DeprecatedScope;
    if (depr_scope != null)
    {
      var canc = search_context.cancellable.get_gcancellable ();
      depr_scope.search_changed (this, search_type, canc);

      waiting = true;
      if (!search_finished) yield;
    }
    else
    {
      warning ("Unable to perform search, expected DeprecatedScope");
    }

    // NOTE: perhaps add a timeout and log a warning if the search takes too
    //  long?

    SignalHandler.disconnect (this, finished_sig_id);
  }

  protected override void run_async (ScopeSearchBaseCallback cb)
  {
    // emit search_changed and wait for finished signal
    real_async_run.begin ((obj, res) =>
    {
      real_async_run.end (res);
      cb (this);
    });
  }
}

public class AggregatedScopeSearch : DeprecatedScopeSearch
{
  public AggregatedScopeSearch (AggregatorScope owner,
                                string channel_id,
                                HashTable<string, Variant> hints,
                                Dee.SerializableModel results_model)
  {
    Object (owner:owner, channel_id:channel_id, hints:hints,
            results_model:results_model);
  }

  public signal void transaction_complete (string origin_scope_id);

  public signal void category_order_changed (uint32[] category_indices);

  public async HashTable<string, Variant> search_scope (string scope_id,
      string search_string, SearchType search_type,
      HashTable<string, Variant>? hints) throws Error
  {
    if (search_context.cancellable.is_cancelled ())
    {
      throw new IOError.CANCELLED ("Cancelled");
    }
    var agg_scope = owner as AggregatorScope;
    var canc = search_context.cancellable.get_gcancellable ();
    Unity.Trace.tracepoint ("subsearch:start::scope=%s;target=%s;query=%s", agg_scope.id, scope_id, search_string);
    var res = yield agg_scope.search_scope (this, scope_id, search_string,
                                            search_type, hints, canc);
    Unity.Trace.tracepoint ("subsearch:end::scope=%s;target=%s;query=%s", agg_scope.id, scope_id, search_string);
    return res;
  }

  public async void push_results (string scope_id,
                                  Dee.SerializableModel results_model,
                                  string[] category_ids)
  {
    if (search_context.cancellable.is_cancelled ()) return;
    var agg_scope = owner as AggregatorScope;
    var canc = search_context.cancellable.get_gcancellable ();
    yield agg_scope.push_results (channel_id, search_string,
                                  scope_id, results_model,
                                  category_ids, canc);
  }

  public void push_filter_settings (FilterSet filters)
  {
    if (search_context.cancellable.is_cancelled ()) return;
    var agg_scope = owner as AggregatorScope;
    agg_scope.push_filter_settings (channel_id, filters);
  }

  protected override void run ()
  {
    var ml = new MainLoop ();
    run_async (() => { ml.quit (); });
    ml.run ();
  }

  private async void real_async_run ()
  {
    var agg_scope = owner as AggregatorScope;
    yield agg_scope.search (this);
  }

  protected override void run_async (ScopeSearchBaseCallback cb)
  {
    // emit search_changed and wait for finished signal
    real_async_run.begin ((obj, res) =>
    {
      real_async_run.end (res);
      cb (this);
    });
  }
}

} /* namespace */
