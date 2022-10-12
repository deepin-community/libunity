/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2011 Canonical Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by Michal Hruby <michal.hruby@canonical.com>
 *
 */
using Unity.Internal;
using Unity.Internal.Utils.Diff;

namespace Unity.Test
{
  public class DiffSuite
  {
    public DiffSuite ()
    {
      GLib.Test.add_data_func ("/Unit/Diff/Empty",
        Fixture.create<DiffTester> (DiffTester.test_empty_diff));
      GLib.Test.add_data_func ("/Unit/Diff/Populate",
        Fixture.create<DiffTester> (DiffTester.test_populate));
      GLib.Test.add_data_func ("/Unit/Diff/Identical",
        Fixture.create<DiffTester> (DiffTester.test_identical));
      GLib.Test.add_data_func ("/Unit/Diff/Appends",
        Fixture.create<DiffTester> (DiffTester.test_appends));
      GLib.Test.add_data_func ("/Unit/Diff/Prepends",
        Fixture.create<DiffTester> (DiffTester.test_prepends));
      GLib.Test.add_data_func ("/Unit/Diff/Inserts",
        Fixture.create<DiffTester> (DiffTester.test_inserts));
      GLib.Test.add_data_func ("/Unit/Diff/MoveToMiddle",
        Fixture.create<DiffTester> (DiffTester.test_move_to_middle));
      GLib.Test.add_data_func ("/Unit/Diff/RemoveBegin",
        Fixture.create<DiffTester> (DiffTester.test_remove_begin));
      GLib.Test.add_data_func ("/Unit/Diff/RemoveEnd",
        Fixture.create<DiffTester> (DiffTester.test_remove_end));
      GLib.Test.add_data_func ("/Unit/Diff/RemoveMid",
        Fixture.create<DiffTester> (DiffTester.test_remove_mid));
      GLib.Test.add_data_func ("/Unit/Diff/Mixed",
        Fixture.create<DiffTester> (DiffTester.test_mixed));

      GLib.Test.add_data_func ("/Unit/DiffModel/Populate",
        Fixture.create<DiffModelTester0> (DiffModelTester0.test_populate));
      GLib.Test.add_data_func ("/Unit/DiffModel/Clear",
        Fixture.create<DiffModelTester1> (DiffModelTester1.test_clear));
      GLib.Test.add_data_func ("/Unit/DiffModel/Mixed",
        Fixture.create<DiffModelTester2> (DiffModelTester2.test_mixed));
      GLib.Test.add_data_func ("/Unit/DiffModel/ChangedMetadata",
        Fixture.create<DiffModelTester3> (DiffModelTester3.test_metadata));
    }

    class DiffTester: Object, Fixture
    {
      private void setup ()
      {
      }

      private void teardown ()
      {
      }

      private SList<Change?> run_diff (string[] x, string[] y)
      {
        var script = run (x.length, y.length, (a, b) =>
        {
          return x[a] == y[b];
        });
        script.reverse ();
        return script;
      }

      public void test_empty_diff ()
      {
        string[] x_results = {};
        string[] y_results = {};

        var script = run_diff (x_results, y_results);

        assert (script.length () == 0);
      }

      public void test_populate ()
      {
        string[] x_results = {};
        string[] y_results = {};
        y_results += "Line #1";
        y_results += "Line #2";
        y_results += "Line #3";
        y_results += "Line #4";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 1);
        var change = script.nth_data (0);
        assert (change.x_offset == 0);
        assert (change.y_offset == 0);
        assert (change.inserted == 4);
        assert (change.deleted == 0);
      }

      public void test_identical ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #1";
        y_results += "Line #2";
        y_results += "Line #3";
        y_results += "Line #4";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 0);
      }

      public void test_appends ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #1";
        y_results += "Line #2";
        y_results += "Line #3";
        y_results += "Line #4";
        y_results += "Line #5";
        y_results += "Line #6";
        y_results += "Line #7";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 1);
        var change = script.nth_data (0);
        assert (change.x_offset == 4);
        assert (change.y_offset == 4);
        assert (change.inserted == 3);
        assert (change.deleted == 0);
      }

      public void test_prepends ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #5";
        y_results += "Line #6";
        y_results += "Line #7";
        y_results += "Line #1";
        y_results += "Line #2";
        y_results += "Line #3";
        y_results += "Line #4";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 1);
        var change = script.nth_data (0);
        assert (change.x_offset == 0);
        assert (change.y_offset == 0);
        assert (change.inserted == 3);
        assert (change.deleted == 0);
      }
      
      public void test_inserts ()
      {
        string[] x_results = {};
        x_results += "Line #2";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #1";
        y_results += "Line #2";
        y_results += "Line #3";
        y_results += "Line #4";
        y_results += "Line #5";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 3);
        var change = script.nth_data (0);
        assert (change.x_offset == 0);
        assert (change.y_offset == 0);
        assert (change.inserted == 1);
        assert (change.deleted == 0);
        change = script.nth_data (1);
        assert (change.x_offset == 1);
        assert (change.y_offset == 2);
        assert (change.inserted == 1);
        assert (change.deleted == 0);
        change = script.nth_data (2);
        assert (change.x_offset == 2);
        assert (change.y_offset == 4);
        assert (change.inserted == 1);
        assert (change.deleted == 0);
      }

      public void test_move_to_middle ()
      {
        string[] x_results = {};
        x_results += "Original";
        string[] y_results = {};
        for (int i = 0; i < 86; i++)
        {
          if (i == 40) y_results += "Original";
          else y_results += "Line #%d".printf (i);
        }

        var script = run_diff (x_results, y_results);

        assert (script.length () == 2);
        var change = script.nth_data (0);
        assert (change.inserted == 40);
        change = script.nth_data (1);
        assert (change.inserted == 45);
      }

      public void test_remove_begin ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #3";
        y_results += "Line #4";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 1);
        var change = script.nth_data (0);
        assert (change.x_offset == 0);
        assert (change.y_offset == 0);
        assert (change.inserted == 0);
        assert (change.deleted == 2);
      }

      public void test_remove_end ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #1";
        y_results += "Line #2";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 1);
        var change = script.nth_data (0);
        assert (change.x_offset == 2);
        assert (change.y_offset == 2);
        assert (change.inserted == 0);
        assert (change.deleted == 2);
      }

      public void test_remove_mid ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        string[] y_results = {};
        y_results += "Line #1";
        y_results += "Line #4";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 1);
        var change = script.nth_data (0);
        assert (change.x_offset == 1);
        assert (change.y_offset == 1);
        assert (change.inserted == 0);
        assert (change.deleted == 2);
      }
      
      public void test_mixed ()
      {
        string[] x_results = {};
        x_results += "Line #1";
        x_results += "Line #2";
        x_results += "Line #3";
        x_results += "Line #4";
        x_results += "Line #5";
        x_results += "Line #6";
        x_results += "Line #7";
        x_results += "Line #8";
        x_results += "Line #9";
        x_results += "Line #10";
        string[] y_results = {};
        y_results += "Line #3";
        y_results += "Line #4";
        y_results += "Line #5";
        y_results += "Line #6";
        y_results += "Line #7";
        y_results += "Added #1";
        y_results += "Added #2";
        y_results += "Line #8";
        y_results += "Line #9";
        y_results += "Line #12";
        y_results += "Line #14";

        var script = run_diff (x_results, y_results);

        assert (script.length () == 3);
        var change = script.nth_data (0);
        assert (change.x_offset == 0);
        assert (change.y_offset == 0);
        assert (change.inserted == 0);
        assert (change.deleted == 2);
        change = script.nth_data (1);
        assert (change.x_offset == 7);
        assert (change.y_offset == 5);
        assert (change.inserted == 2);
        assert (change.deleted == 0);
        change = script.nth_data (2);
        assert (change.x_offset == 9);
        assert (change.y_offset == 9);
        assert (change.inserted == 2);
        assert (change.deleted == 1);
      }
    }

    class DiffModelTester0: Object, Fixture
    {
      private Unity.Internal.DiffModel? model;
      private Dee.SequenceModel? backend_model;
      private uint rows_added;
      private uint rows_removed;

      private void setup ()
      {
        backend_model = new Dee.SequenceModel ();
        backend_model.set_schema_full (RESULTS_SCHEMA);
        backend_model.set_column_names_full (RESULTS_COLUMN_NAMES);

        var peer = new Dee.Server ("com.canonical.Libunity.Test0");
        model = new Unity.Internal.DiffModel (peer, backend_model);
        model.set_schema_full (RESULTS_SCHEMA);
        model.set_column_names_full (RESULTS_COLUMN_NAMES);
        model.row_added.connect (() => { rows_added++; });
        model.row_removed.connect (() => { rows_removed++; });

        var ml = new MainLoop ();
        Utils.wait_for_model_synchronization (model, (obj, res) =>
        {
          ml.quit ();
        });
        assert (run_with_timeout (ml));
      }

      private void teardown ()
      {
        model = null;
        backend_model = null;
      }

      private void add_sample_result (
          string uri,
          uint category,
          HashTable<string, Variant>? metadata = null)
      {
        Variant metadata_v = metadata != null ?
          metadata : new Variant.array (VariantType.VARDICT.element (), {});
        backend_model.append (uri, "icon", category, 0, "text/plain",
                              Path.get_basename (uri), "", uri, metadata_v);
      }

      public void test_populate ()
      {
        assert (backend_model.get_n_rows () == 0);
        assert (model.get_n_rows () == 0);
        assert (model.target_model.get_n_rows () == 0);

        add_sample_result ("file:///test1", 0);
        add_sample_result ("file:///test2", 0);
        add_sample_result ("file:///test9", 1);
        add_sample_result ("file:///test2", 1);

        assert (backend_model.get_n_rows () == 4);
        assert (model.target_model.get_n_rows () == 4);
        assert (model.get_n_rows () == 0);
        assert (rows_added == 0);
        assert (rows_removed == 0);

        model.commit_changes ();
        assert (model.get_n_rows () == 4);
        assert (rows_added == 4);
        assert (rows_removed == 0);
      }
    }

    class DiffModelTester1: Object, Fixture
    {
      private Unity.Internal.DiffModel? model;
      private Dee.SequenceModel? backend_model;
      private uint rows_added;
      private uint rows_removed;

      private void setup ()
      {
        backend_model = new Dee.SequenceModel ();
        backend_model.set_schema_full (RESULTS_SCHEMA);
        backend_model.set_column_names_full (RESULTS_COLUMN_NAMES);
        var peer = new Dee.Server ("com.canonical.Libunity.Test1");
        model = new Unity.Internal.DiffModel (peer, backend_model);
        model.set_schema_full (RESULTS_SCHEMA);
        model.set_column_names_full (RESULTS_COLUMN_NAMES);
        model.row_added.connect (() => { rows_added++; });
        model.row_removed.connect (() => { rows_removed++; });

        var ml = new MainLoop ();
        Utils.wait_for_model_synchronization (model, (obj, res) =>
        {
          ml.quit ();
        });
        assert (run_with_timeout (ml));
      }

      private void teardown ()
      {
        model = null;
        backend_model = null;
      }

      private void add_sample_result (
          string uri,
          uint category,
          HashTable<string, Variant>? metadata = null)
      {
        Variant metadata_v = metadata != null ?
          metadata : new Variant.array (VariantType.VARDICT.element (), {});
        backend_model.append (uri, "icon", category, 0, "text/plain",
                              Path.get_basename (uri), "", uri, metadata_v);
      }

      public void test_clear ()
      {
        add_sample_result ("file:///test1", 0);
        add_sample_result ("file:///test2", 0);
        add_sample_result ("file:///test3", 0);
        add_sample_result ("file:///test9", 1);
        add_sample_result ("file:///test2", 1);
        add_sample_result ("file:///test5", 4);

        model.commit_changes ();
        assert (model.get_n_rows () == backend_model.get_n_rows ());
        assert (rows_added == backend_model.get_n_rows ());
        assert (rows_removed == 0);

        backend_model.clear ();

        rows_added = 0;
        rows_removed = 0;
        model.commit_changes ();
        assert (model.get_n_rows () == backend_model.get_n_rows ());
        assert (rows_added == 0);
        assert (rows_removed == 6);
      }
    }

    class DiffModelTester2: Object, Fixture
    {
      private Unity.Internal.DiffModel? model;
      private Dee.SequenceModel? backend_model;
      private uint rows_added;
      private uint rows_removed;

      private void setup ()
      {
        backend_model = new Dee.SequenceModel ();
        backend_model.set_schema_full (RESULTS_SCHEMA);
        backend_model.set_column_names_full (RESULTS_COLUMN_NAMES);

        var peer = new Dee.Server ("com.canonical.Libunity.Test2");
        model = new Unity.Internal.DiffModel (peer, backend_model);
        model.set_schema_full (RESULTS_SCHEMA);
        model.set_column_names_full (RESULTS_COLUMN_NAMES);
        model.row_added.connect (() => { rows_added++; });
        model.row_removed.connect (() => { rows_removed++; });

        var ml = new MainLoop ();
        Utils.wait_for_model_synchronization (model, (obj, res) =>
        {
          ml.quit ();
        });
        assert (run_with_timeout (ml));
      }

      private void teardown ()
      {
        model = null;
        backend_model = null;
      }

      private void add_sample_result (
          string uri,
          uint category,
          HashTable<string, Variant>? metadata = null)
      {
        Variant metadata_v = metadata != null ?
          metadata : new Variant.array (VariantType.VARDICT.element (), {});
        backend_model.append (uri, "icon", category, 0, "text/plain",
                              Path.get_basename (uri), "", uri, metadata_v);
      }

      public void test_mixed ()
      {
        add_sample_result ("file:///test1", 0);
        add_sample_result ("file:///test2", 0);
        add_sample_result ("file:///test3", 0);
        add_sample_result ("file:///test9", 1);
        add_sample_result ("file:///test2", 1);
        add_sample_result ("file:///test5", 4);

        model.commit_changes ();
        assert (model.get_n_rows () == backend_model.get_n_rows ());
        assert (rows_added == backend_model.get_n_rows ());
        assert (rows_removed == 0);

        backend_model.clear ();
        add_sample_result ("file:///test1", 0);
        add_sample_result ("file:///test3", 0);
        add_sample_result ("file:///test9", 1);
        add_sample_result ("file:///test2", 1);
        add_sample_result ("file:///test5", 4);
        add_sample_result ("file:///test2", 4);
        add_sample_result ("file:///test1", 4);

        rows_added = 0;
        rows_removed = 0;
        model.commit_changes ();
        assert (model.get_n_rows () == backend_model.get_n_rows ());
        assert (rows_added == 2);
        assert (rows_removed == 1);
        // compare the actual values and their ordering
        for (uint i = 0; i < model.get_n_rows (); i++)
        {
          var row = model.get_row (model.get_iter_at_row (i));
          var orig_row = backend_model.get_row (backend_model.get_iter_at_row (i));
          assert (row[ResultColumn.URI].equal (orig_row[ResultColumn.URI]));
          assert (row[ResultColumn.CATEGORY].equal (orig_row[ResultColumn.CATEGORY]));
        }
      }
    }

    class DiffModelTester3: Object, Fixture
    {
      private Unity.Internal.DiffModel? model;
      private Dee.SequenceModel? backend_model;
      private uint rows_added;
      private uint rows_removed;

      private void setup ()
      {
        backend_model = new Dee.SequenceModel ();
        backend_model.set_schema_full (RESULTS_SCHEMA);
        backend_model.set_column_names_full (RESULTS_COLUMN_NAMES);

        var peer = new Dee.Server ("com.canonical.Libunity.Test3");
        model = new Unity.Internal.DiffModel (peer, backend_model);
        model.set_schema_full (RESULTS_SCHEMA);
        model.set_column_names_full (RESULTS_COLUMN_NAMES);
        model.row_added.connect (() => { rows_added++; });
        model.row_removed.connect (() => { rows_removed++; });

        var ml = new MainLoop ();
        Utils.wait_for_model_synchronization (model, (obj, res) =>
        {
          ml.quit ();
        });
        assert (run_with_timeout (ml));
      }

      private void teardown ()
      {
        model = null;
        backend_model = null;
      }

      private void add_sample_result (
          string uri,
          uint category,
          HashTable<string, Variant>? metadata = null)
      {
        Variant metadata_v = metadata != null ?
          metadata : new Variant.array (VariantType.VARDICT.element (), {});
        backend_model.append (uri, "icon", category, 0, "text/plain",
                              Path.get_basename (uri), "", uri, metadata_v);
      }
      
      public void test_metadata ()
      {
        var metadata = new HashTable<string, Variant> (str_hash, str_equal);
        add_sample_result ("file:///test1", 0, metadata);

        model.commit_changes ();
        assert (model.get_n_rows () == backend_model.get_n_rows ());
        assert (rows_added == backend_model.get_n_rows ());
        assert (rows_removed == 0);

        backend_model.clear ();
        // change in metadata will count as completely different result
        metadata["test"] = new Variant.int32 (43);
        add_sample_result ("file:///test1", 0, metadata);

        rows_added = 0;
        rows_removed = 0;
        model.commit_changes ();
        assert (model.get_n_rows () == backend_model.get_n_rows ());
        assert (rows_added == 1);
        assert (rows_removed == 1);
        // compare the actual values and their ordering
        for (uint i = 0; i < model.get_n_rows (); i++)
        {
          var row = model.get_row (model.get_iter_at_row (i));
          var orig_row = backend_model.get_row (backend_model.get_iter_at_row (i));
          assert (row[ResultColumn.URI].equal (orig_row[ResultColumn.URI]));
          assert (row[ResultColumn.CATEGORY].equal (orig_row[ResultColumn.CATEGORY]));
          assert (row[ResultColumn.METADATA].equal (orig_row[ResultColumn.METADATA]));
        }
      }
    }
  }
}
