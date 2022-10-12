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

using GLib;
using Dee;

namespace Unity.Internal {

internal class DeeResultSet: ResultSet
{
  public DeeResultSet ()
  {
    Object ();
  }

  public DeeResultSet.with_model (Dee.SerializableModel model)
  {
    Object (results_model: model);
  }

  private unowned Thread<void*> origin_thread;
  private unowned MainContext origin_context;
  private GenericArray<Variant> results;

  construct
  {
    origin_thread = Thread.self<void*> ();
    origin_context = MainContext.get_thread_default ();
    if (origin_context == null) origin_context = MainContext.default ();
    results = new GenericArray<Variant> ();
  }

  public override void constructed ()
  {
    if (results_model == null)
    {
      results_model = new Dee.SequenceModel ();
      results_model.set_schema_full (Internal.RESULTS_SCHEMA);
      results_model.set_column_names_full (Internal.RESULTS_COLUMN_NAMES);
    }
  }

  public Dee.SerializableModel results_model { get; construct set; }

  public override void add_result (ScopeResult result)
  {
    // ensure this matches the schema!
    Variant metadata_v;
    if (result.metadata != null)
    {
      metadata_v = result.metadata;
    }
    else
    {
      metadata_v = new Variant.array (VariantType.VARDICT.element (), {});
    }

    Variant v = new Variant ("(ssuussss@a{sv})", result.uri, result.icon_hint,
      result.category, result.result_type, result.mimetype, result.title,
      result.comment, result.dnd_uri, metadata_v);
    results.add ((owned) v);
  }

  public override void add_result_from_variant (Variant variant)
  {
    const string EXPECTED_TYPE_STRING = "(ssuussssa{sv})";
    if (variant.get_type_string () != EXPECTED_TYPE_STRING)
    {
      warning ("Incorrect signature for %s, expected %s, but got %s",
        Log.METHOD, EXPECTED_TYPE_STRING, variant.get_type_string ());
      return;
    }

    results.add (variant);
  }

  public Dee.SerializableModel flush_model { get; set; }

  private void do_flush_locked ()
  {
    uint results_len = (uint) results.length;
    for (uint i = 0; i < results_len; i++)
    {
      Variant variant = (owned) results.data[i];
      Variant row_buf[9];
      variant.get ("(@s@s@u@u@s@s@s@s@a{sv})",
                   out row_buf[0], out row_buf[1],
                   out row_buf[2], out row_buf[3],
                   out row_buf[4], out row_buf[5],
                   out row_buf[6], out row_buf[7],
                   out row_buf[8]);
      results_model.append_row (row_buf);
    }
    // clear the results array
    results.length = 0;

    var diff_model = flush_model as DiffModel;
    if (diff_model != null)
    {
      diff_model.commit_changes ();
    }
    var sm = flush_model as Dee.SharedModel;
    if (sm != null)
    {
      Unity.Trace.tracepoint ("flush::%s", sm.get_swarm_name ());
      sm.flush_revision_queue ();
    }
  }

  /* Note that this method can either be called from inside the search thread
   * (while the search is in progress), or from the main thread BUT only after
   * the search finished (if search is run in main thread it's safe always). */
  public override void flush ()
  {
    // check which thread is this running in
    unowned Thread<void*> current_thread = Thread.self<void*> ();
    if (current_thread == origin_thread)
    {
      // no locking needed
      do_flush_locked ();
    }
    else
    {
      // can't use Mutex and Cond directly, vala does scary copying of structs
      var queue = new AsyncQueue<bool> ();
      var idle = new IdleSource ();
      idle.set_callback (() =>
      {
        do_flush_locked ();

        queue.push (true);

        return false;
      });
      idle.attach (origin_context);

      // wait for the idle to get processed
      queue.pop ();
    }
  }
}

internal class DiffModel: Dee.SharedModel
{
  public DiffModel (Dee.Peer peer, Dee.Model target)
  {
    var model = new Dee.SequenceModel ();
    Object (peer: peer, back_end: model, target_model: target,
            access_mode: Dee.SharedModelAccessMode.LEADER_WRITABLE);
  }

  public Dee.Model target_model { get; construct set; }

  public void commit_changes ()
  {
    uint this_rows = this.get_n_rows ();
    uint target_rows = target_model.get_n_rows ();

    // a few short-circuits
    if (target_rows == 0)
    {
      clear ();
      return;
    }
    else if (this_rows == 0)
    {
      // diff model is empty, copy everything from target_model
      Variant row_buf[9];
      var iter = target_model.get_first_iter ();
      var end_iter = target_model.get_last_iter ();
      while (iter != end_iter)
      {
        // vala doesn't know we're changing the array, so need to clear it
        for (int i = 0; i < row_buf.length; i++) row_buf[i] = null;
        target_model.get_row_static (iter, row_buf);
        this.append_row (row_buf);
        iter = target_model.next (iter);
      }
      return;
    }

    Unity.Trace.tracepoint ("diff:start::%s", get_swarm_name ());
    var script = Utils.Diff.run ((int) this_rows, (int) target_rows,
                                 (index_a, index_b) =>
    {
      var this_iter = this.get_iter_at_row (index_a);
      var target_iter = target_model.get_iter_at_row (index_b);

      // check categories first
      if (get_uint32 (this_iter, ResultColumn.CATEGORY) !=
          target_model.get_uint32 (target_iter, ResultColumn.CATEGORY))
      {
        return false;
      }

      // consider uris + metadata primary key
      if (this.get_string (this_iter, ResultColumn.URI) !=
          target_model.get_string (target_iter, ResultColumn.URI))
      {
        return false;
      }

      Variant om = target_model.get_value (target_iter, ResultColumn.METADATA);
      return this.get_value (this_iter, ResultColumn.METADATA).equal (om);
    });

    // the script is reversed, so no need to worry about decrementing indices
    // after a deletion
    foreach (unowned Utils.Diff.Change? change in script)
    {
      int to_delete = change.deleted;
      var iter = this.get_iter_at_row (change.x_offset);
      while (to_delete > 0)
      {
        var rm_iter = iter;
        iter = this.next (iter);
        this.remove (rm_iter);
        to_delete--;
      }
      if (change.inserted > 0)
      {
        Variant row_buf[9];
        int to_insert = change.inserted;
        int inserted = 0;
        var target_iter = target_model.get_iter_at_row (change.y_offset);
        while (inserted < to_insert)
        {
          for (int i = 0; i < row_buf.length; i++) row_buf[i] = null;
          target_model.get_row_static (target_iter, row_buf);
          this.insert_row (change.x_offset + inserted, row_buf);
          // advance positions
          target_iter = target_model.next (target_iter);
          inserted++;
        }
      }
    }
    Unity.Trace.tracepoint ("diff:end::%s", get_swarm_name ());

    assert (get_n_rows () == target_model.get_n_rows ());
  }
}

} /* namespace Unity.Internal */

