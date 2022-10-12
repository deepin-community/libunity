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

namespace Unity {

  /**
   * Destroy an object.
   *
   * Unreferences object returned by one of unity_*_new constructors.
   */
  public static void object_unref (void* object)
  {
    Object* o_ptr = (Object*) object;
    // we don't want people using unity_object_unref for non Unity classes
    if (o_ptr is Object && o_ptr->get_type ().name ().has_prefix ("Unity"))
    {
      delete o_ptr;
    }
    else
    {
      critical ("Unable to unref object, invalid object type");
    }
  }

namespace Internal {

/* Cateories: [id, display_name, icon, renderer_name, hints] */
internal const string[] CATEGORIES_SCHEMA = {"s", "s", "s", "s", "a{sv}"};

internal enum CategoryColumn
{
  ID,
  DISPLAY_NAME,
  ICON_HINT,
  RENDERER_NAME,
  HINTS,

  N_COLUMNS
}

/* Filters: [id, display_name, icon, renderer_name, hints,
             visible, collapsed, filtering] */
internal const string[] FILTERS_SCHEMA = {"s", "s", "s", "s", "a{sv}",
                                          "b", "b", "b"};

internal enum FilterColumn
{
  ID,
  DISPLAY_NAME,
  ICON_HINT,
  RENDERER_NAME,
  RENDERER_STATE,
  VISIBLE,
  COLLAPSED,
  FILTERING,

  N_COLUMNS
}

/* Results: [uri, icon, category, result_type, mimetype,
             title, comment, dnd_uri, metadata] */
internal const string[] RESULTS_SCHEMA = {"s", "s", "u", "u", "s",
                                          "s", "s", "s", "a{sv}"};
internal const string[] RESULTS_COLUMN_NAMES = {
  "uri", "icon_hint", "category", "result_type", "mimetype",
  "title", "comment", "dnd_uri",  "metadata"};

internal enum ResultColumn
{
  URI,
  ICON_HINT,
  CATEGORY,
  RESULT_TYPE,
  MIMETYPE,
  TITLE,
  COMMENT,
  DND_URI,
  METADATA,

  N_COLUMNS
}

internal const string VAR_MEASURED_SEARCHES = "LIBUNITY_TIME_SEARCHES";
internal const string VAR_SYNC_DBUS_SEARCHES = "LIBUNITY_SYNC_DBUS";

internal const string SEARCH_FILTER_ROW_HINT = "changed-filter-row";
internal const string SEARCH_SEQNUM_HINT = "model-seqnum";
internal const string SEARCH_TIME_HINT = "search-time";
internal const string SEARCH_SUBSCOPES_HINT = "subscopes-filter";
internal const string SEARCH_NO_RESULTS_HINT = "no-results-hint";

internal const string ACTIVATE_PREVIEW_ACTION_HINT = "preview-action-id";

namespace Utils
{
  [Compact]
  private class DelegateWrapper
  {
    public SourceFunc callback;

    public DelegateWrapper (owned SourceFunc cb)
    {
      callback = (owned) cb;
    }
  }

  internal class AsyncOnce<G>
  {
    private enum OperationState
    {
      NOT_STARTED,
      IN_PROGRESS,
      DONE
    }

    private G inner;

    private OperationState state;
    private DelegateWrapper[] callbacks = {};

    public AsyncOnce ()
    {
      state = OperationState.NOT_STARTED;
    }

    public unowned G get_data ()
    {
      return inner;
    }

    public bool is_initialized ()
    {
      return state == OperationState.DONE;
    }

    public async bool enter ()
    {
      if (state == OperationState.NOT_STARTED)
      {
        state = OperationState.IN_PROGRESS;
        return true;
      }
      else if (state == OperationState.IN_PROGRESS)
      {
        yield wait_async ();
      }

      return false;
    }

    public void leave (G result)
    {
      if (state != OperationState.IN_PROGRESS)
      {
        warning ("Incorrect usage of AsyncOnce");
        return;
      }
      state = OperationState.DONE;
      inner = result;
      notify_all ();
    }

    /* Once probably shouldn't have this, but it's useful */
    public void reset ()
    {
      state = OperationState.NOT_STARTED;
      inner = null;
    }

    private void notify_all ()
    {
      foreach (unowned DelegateWrapper wrapper in callbacks)
      {
        wrapper.callback ();
      }
      callbacks = {};
    }

    private async void wait_async ()
    {
      callbacks += new DelegateWrapper (wait_async.callback);
      yield;
    }
  }

  internal class AsyncMutex
  {
    private bool is_locked;
    private GLib.Queue<DelegateWrapper?> callbacks;

    public AsyncMutex ()
    {
      callbacks = new GLib.Queue<DelegateWrapper?> ();
      is_locked = false;
    }

    public bool try_lock ()
    {
      if (!is_locked)
      {
        is_locked = true;
        return true;
      }
      return false;
    }

    public async void lock ()
    {
      if (!is_locked)
      {
        is_locked = true;
        return;
      }
      yield wait_async ();
      is_locked = true;
    }

    public void unlock ()
    {
      if (!is_locked)
      {
        warning ("Unlock failed: AsyncMutex was already unlocked");
        return;
      }
      is_locked = false;
      notify ();
    }

    private void notify ()
    {
      if (callbacks.is_empty ()) return;
      DelegateWrapper? cb = callbacks.pop_head ();
      cb.callback ();
    }

    private async void wait_async ()
    {
      callbacks.push_tail (new DelegateWrapper (wait_async.callback));
      yield;
    }
  }

  internal static async void wait_for_model_synchronization (Dee.SharedModel model)
  {
    if (model.is_synchronized ()) return;

    var sig_id = model.notify["synchronized"].connect (() =>
    {
      if (model.is_synchronized ())
      {
        wait_for_model_synchronization.callback ();
      }
    });

    if (sig_id == 0)
    {
      critical ("Internal error, unable to wait for synchronization");
      return;
    }

    yield;
    SignalHandler.disconnect (model, sig_id);
  }

  internal static Variant hash_table_to_asv (HashTable<string, Variant> hash)
  {
    var b = new VariantBuilder (new VariantType ("a{sv}"));

    var iter = HashTableIter<string, Variant> (hash);
    
    string key;
    Variant val;
    while (iter.next (out key, out val))
    {
      b.add ("{sv}", key, val);
    }

    return b.end ();
  }

  internal static string icon_to_string (Icon? icon)
  {
    return icon != null ? icon.to_string () : "";
  }

  namespace Diff
  {
    internal delegate bool ResultSetCompareFunc (int index_a, int index_b);

    private struct Context
    {
      // Lengths of the analyzed sets
      int x_length;
      int y_length;
      // Buffer for finding the minimal edit path, contains space for both
      // forwards and backwards paths
      int[] real_diag;
      // Buffer for finding forwards edit path, indexed from (-y_length-1)
      // to (x_length+1)
      int* f_diag;
      // Buffer for finding backwards edit path, indexed from (-y_length-1)
      // to (x_length+1)
      int* b_diag;
      // Maximum cost, finding the optimal one is often too costly
      int max_cost;
      // Buffer combining the x and y change buffers
      uint8[] real_changes;
      // Buffer for recording which items in the original set were removed
      uint8* x_changes;
      // Buffer for recording which items in the target set were added
      uint8* y_changes;

      Context (int x_set_length, int y_set_length)
      {
        x_length = x_set_length;
        y_length = y_set_length;
        int diags = (x_set_length + 1 + y_set_length + 1) + 1;

        // allocate one big buffer for the forward and backward vectors
        real_diag = new int[diags * 2];
        // offset the pointers, cause we're sharing the same mem block,
        // plus the indices can be negative
        f_diag = real_diag;
        f_diag += y_set_length + 1;
        b_diag = real_diag;
        b_diag += diags;
        b_diag += y_set_length + 1;

        // another one big buffer to record the changes
        real_changes = new uint8[diags];
        x_changes = real_changes;
        y_changes = real_changes;
        y_changes += x_set_length + 1;

        // finding the optimal solution could be too expensive, use suboptimal
        // if the cost is getting too high
        max_cost = 1;
        // fast sqrt(diags) approximation
        while (diags != 0)
        {
          diags /= 4;
          max_cost *= 2;
        }
        max_cost = int.max (max_cost, 256);
      }
    }

    private struct Partition
    {
      // find the midpoints where we need to split the two sets
      int x_mid;
      int y_mid;
      // is the upper and lower part of the edit path optimal?
      bool lo_minimal;
      bool hi_minimal;
    }

    internal struct Change
    {
      int x_offset;
      int y_offset;
      int inserted;
      int deleted;
    }

    internal static SList<Change?> run (int x_set_length, int y_set_length,
                                        ResultSetCompareFunc cmp_func)
    {
      Context ctx = Context (x_set_length, y_set_length);

      compare_sequences (0, x_set_length, 0, y_set_length,
                         false, ref ctx, cmp_func);

      return build_edit_script (ref ctx);
    }

    // Note that this produces changeset in reversed order
    private static SList<Change?> build_edit_script (ref Context ctx)
    {
      SList<Change?> script = new SList<Change?> ();
      int x_length = ctx.x_length;
      int y_length = ctx.y_length;
      uint8* x_changes = ctx.x_changes;
      uint8* y_changes = ctx.y_changes;
      int x = 0;
      int y = 0;
      // find continous change sets and record them, so we're able 
      // to transform the first set into the second
      while (x < x_length || y < y_length)
      {
        if ((x_changes[x] | y_changes[y]) != 0)
        {
          int xx = x;
          int yy = y;
          while (x_changes[x] != 0) x++;
          while (y_changes[y] != 0) y++;

          script.prepend ({xx, yy, y - yy, x - xx});
        }

        x++;
        y++;
      }

      return script;
    }

    /* Find the midpoint of the shortest edit script for a given subset
       of the two vectors */
    private static void find_diag (int x_offset, int x_limit,
                                   int y_offset, int y_limit,
                                   ResultSetCompareFunc equal_func,
                                   ref Context ctx,
                                   ref Partition partition)
    {
      int d_min = x_offset - y_limit;
      int d_max = x_limit - y_offset;
      int f_mid = x_offset - y_offset;
      int b_mid = x_limit - y_limit;

      int f_min = f_mid;
      int f_max = f_mid;
      int b_min = b_mid;
      int b_max = b_mid;

      int cost;
      bool is_odd = ((f_mid - b_mid) & 1) != 0;

      int* f_diag = ctx.f_diag;
      int* b_diag = ctx.b_diag;
      f_diag[f_mid] = x_offset;
      b_diag[b_mid] = x_limit;

      for (cost = 1; ; cost++)
      {
        int d;

        // extend the forwards search by an edit step in each diagonal
        if (f_min > d_min) f_diag[--f_min - 1] = -1;
        else ++f_min;

        if (f_max < d_max) f_diag[++f_max + 1] = -1;
        else --f_max;

        for (d = f_max; d >= f_min; d -= 2)
        {
          int x, y;
          int t_lo = f_diag[d - 1];
          int t_hi = f_diag[d + 1];
          int x0 = t_lo < t_hi ? t_hi : t_lo + 1;

          for (x = x0, y = x0 - d; 
               x < x_limit && y < y_limit && equal_func (x, y);
               x++, y++)
          {
            continue;
          }

          f_diag[d] = x;
          if (is_odd && b_min <= d && d <= b_max && b_diag[d] <= x)
          {
            partition.x_mid = x;
            partition.y_mid = y;
            partition.lo_minimal = partition.hi_minimal = true;
            return;
          }
        }

        // and extend the backwards search
        if (b_min > d_min) b_diag[--b_min - 1] = int.MAX;
        else ++b_min;

        if (b_max < d_max) b_diag[++b_max + 1] = int.MAX;
        else --b_max;

        for (d = b_max; d >= b_min; d -= 2)
        {
          int x, y;
          int t_lo = b_diag[d - 1];
          int t_hi = b_diag[d + 1];
          int x0 = t_lo < t_hi ? t_lo : t_hi - 1;

          for (x = x0, y = x0 - d; 
               x_offset < x && y_offset < y && equal_func (x-1, y-1);
               x--, y--)
          {
            continue;
          }

          b_diag[d] = x;
          if (!is_odd && f_min <= d && d <= f_max && x <= f_diag[d])
          {
            partition.x_mid = x;
            partition.y_mid = y;
            partition.lo_minimal = partition.hi_minimal = true;
            return;
          }
        }
        // Chance to implement heuristic to speed things up at the cost
        // of loosing optimal path

        // If cost is too high, give up and report halfway between best results
        if (cost >= ctx.max_cost)
        {
          int fxy_best, bxy_best;
          int fx_best = 0;
          int bx_best = 0;

          fxy_best = -1;
          for (d = f_max; d >= f_min; d -= 2)
          {
            int x = int.min (f_diag[d], x_limit);
            int y = x - d;
            if (y_limit < y)
            {
              x = y_limit + d;
              y = y_limit;
            }
            if (fxy_best < x + y)
            {
              fxy_best = x + y;
              fx_best = x;
            }
          }

          bxy_best = int.MAX;
          for (d = b_max; d >= b_min; d -= 2)
          {
            int x = int.max (x_offset, b_diag[d]);
            int y = x - d;
            if (y < y_offset)
            {
              x = y_offset + d;
              y = y_offset;
            }
            if (x + y < bxy_best)
            {
              bxy_best = x + y;
              bx_best = x;
            }
          }

          if ((x_limit + y_limit) - bxy_best < fxy_best - (x_offset + y_offset))
          {
            partition.x_mid = fx_best;
            partition.y_mid = fxy_best - fx_best;
            partition.lo_minimal = true;
            partition.hi_minimal = false;
          }
          else
          {
            partition.x_mid = bx_best;
            partition.y_mid = bxy_best - bx_best;
            partition.lo_minimal = false;
            partition.hi_minimal = true;
          }
          return;
        }
      }
    }

    /* Compare contigous sequences of two sets.
     *
     * Return true if terminated through early abort, false otherwise.
     */
    private static bool compare_sequences (int x_offset, int x_limit,
                                           int y_offset, int y_limit,
                                           bool find_minimal, ref Context ctx,
                                           ResultSetCompareFunc equal_func)
    {
      // slide down the bottom diagonal in the forwards path
      while (x_offset < x_limit && y_offset < y_limit && equal_func (x_offset, y_offset))
      {
        x_offset++;
        y_offset++;
      }

      // and slide up the top diagonal in the backwards path
      while (x_offset < x_limit && y_offset < y_limit && equal_func (x_limit-1, y_limit-1))
      {
        x_limit--;
        y_limit--;
      }

      if (x_offset == x_limit)
      {
        // these items were added to the target set
        while (y_offset < y_limit)
        {
          ctx.y_changes[y_offset] = 1;
          y_offset++;
        }
      }
      else if (y_offset == y_limit)
      {
        // these items were removed from the original set
        while (x_offset < x_limit)
        {
          ctx.x_changes[x_offset] = 1;
          x_offset++;
        }
      }
      else
      {
        Partition partition = { 0, 0, false, false };

        // split into two subproblems
        find_diag (x_offset, x_limit, y_offset, y_limit,
                   equal_func, ref ctx, ref partition);

        if (compare_sequences (x_offset, partition.x_mid,
                               y_offset, partition.y_mid,
                               partition.lo_minimal,
                               ref ctx, equal_func))
          return true;
        if (compare_sequences (partition.x_mid, x_limit,
                               partition.y_mid, y_limit,
                               partition.hi_minimal,
                               ref ctx, equal_func))
          return true;
      }

      return false;
    }
  } /* namespace Unity.Internal.Utils.Diff */
}

} /* namespace Unity.Internal */
} /* namespace Unity */