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

public class Main
{
  public static int main (string[] args)
  {
    Environment.set_variable ("LIBUNITY_LENS_DIRECTORY",
                              Config.TESTDIR + "/data", true);
    Test.init (ref args);

    Test.add_data_func ("/Integration/Scope/Export", test_scope_export);
    Test.add_data_func ("/Integration/Scope/Search", test_scope_search);
    Test.add_data_func ("/Integration/Scope/Search2", test_scope_search2);
    Test.add_data_func ("/Integration/Scope/SuccessiveSearches", test_scope_successive_searches);
    Test.add_data_func ("/Integration/Scope/TwoSearches", test_scope_two_searches);
    Test.add_data_func ("/Integration/Scope/ModelSync", test_scope_model_sync);
    Test.add_data_func ("/Integration/Scope/ReplyHint", test_scope_reply_hint);
    Test.add_data_func ("/Integration/Scope/Sources", test_scope_sources);
    Test.add_data_func ("/Integration/Scope/Finalize", test_scope_finalize);

    Test.run ();

    return 0;
  }

  static Unity.Scope exported_scope;

  public static void test_scope_export ()
  {
    Bus.own_name (BusType.SESSION, "com.canonical.Unity.Scope0.Test", 0,
                  () => {}, () => {},
                  () => { debug ("Name lost"); assert_not_reached (); });

    var scope = new Unity.Scope ("/com/canonical/Unity/Scope0/Test",
                                 "test-scope-0");

    scope.export ();

    exported_scope = scope;
  }

  public static void test_scope_search ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();
    bool got_search_changed = false;

    ulong sig_id = exported_scope.search_changed.connect ((lens_search) =>
    {
      assert (lens_search.search_string == "foo");
      got_search_changed = true;
      lens_search.finished ();
      ml.quit ();
    });

    Timeout.add (2000, () => { ml.quit (); return false; });
    ml.run ();

    assert (got_search_changed == true);

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }
  
  public static void test_scope_search2 ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();
    bool got_search_changed = false;

    ulong sig_id = exported_scope.search_changed.connect ((lens_search) =>
    {
      assert (lens_search.search_string == "qoo");
      got_search_changed = true;
      // wait a while to emit the finished signal
      Timeout.add (400, () =>
      {
        lens_search.finished ();
        ml.quit ();
        return false;
      });
    });

    Timeout.add (2000, () => { ml.quit (); return false; });
    ml.run ();

    assert (got_search_changed == true);

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }

  public static void test_scope_successive_searches ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();
    bool got_search_changed = false;

    ulong sig_id = exported_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      assert (lens_search.search_string == "successive-searches");
      got_search_changed = true;
      // wait a while to emit the finished signal
      Timeout.add (500, () =>
      {
        lens_search.finished ();
        ml.quit ();
        return false;
      });
    });

    Timeout.add (2000, () => { ml.quit (); return false; });
    ml.run ();

    // earlier searches need to cancelled if there's a newer search
    assert (got_search_changed == true);

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }

  public static void test_scope_two_searches ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();
    bool got_search_changed = false;
    Cancellable? canc1 = null;
    Cancellable? canc2 = null;
    uint num_searches = 0;

    ulong sig_id = exported_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      switch (lens_search.search_string)
      {
        case "foo1": canc1 = cancellable; break;
        case "foo2": canc2 = cancellable; break;
        default: assert_not_reached (); break;
      }
      got_search_changed = true;
      // wait a while to emit the finished signal
      Timeout.add (500, () =>
      {
        lens_search.finished ();
        if (++num_searches == 2) ml.quit ();
        return false;
      });
    });

    Timeout.add (2000, () => { ml.quit (); return false; });
    ml.run ();

    // earlier searches need to cancelled if there's a newer search
    assert (got_search_changed == true);
    assert (canc1 != null);
    assert (canc2 != null);
    assert (canc1.is_cancelled () == true);
    assert (canc2.is_cancelled () == false);

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }

  public static void test_scope_model_sync ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();
    bool got_search_changed = false;

    ulong sig_id = exported_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      assert (lens_search.search_string == "model-sync");
      got_search_changed = true;
      // wait a while to emit the finished signal
      Timeout.add (500, () =>
      {
        var model = lens_search.results_model;
        model.append ("uri", "icon", 0, "mimetype", "display-name",
                      "comment", "dnd-uri");
        lens_search.finished ();
        ml.quit ();
        return false;
      });
    });

    Timeout.add (2000, () => { assert_not_reached (); });
    ml.run ();

    assert (got_search_changed == true);

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }

  public static void test_scope_reply_hint ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();
    bool got_search_changed = false;

    ulong sig_id = exported_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      assert (lens_search.search_string == "reply-hint");
      got_search_changed = true;
      // wait a while to emit the finished signal
      Timeout.add (100, () =>
      {
        var model = lens_search.results_model;
        model.append ("uri", "icon", 0, "mimetype", "display-name",
                      "comment", "dnd-uri");
        lens_search.set_reply_hint ("test-reply-hint", new Variant.string ("value"));
        lens_search.finished ();
        ml.quit ();
        return false;
      });
    });

    Timeout.add (2000, () => { assert_not_reached (); });
    ml.run ();

    assert (got_search_changed == true);

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }

  public static void test_scope_sources ()
  {
    // we expect that the lens will call the search method
    assert (exported_scope != null);

    var ml = new MainLoop ();

    exported_scope.sources.add_option ("id1-remote", "Remote 1", null);
    exported_scope.sources.add_option ("id2-remote", "Remote 2", null);

    bool remove_option = false;
    // we're using the search for synchronization
    ulong sig_id = exported_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      assert (lens_search.search_string.has_prefix ("sources-test"));
      if (remove_option)
      {
        exported_scope.sources.remove_option ("id1-remote");
      }
      // wait a while to emit the finished signal (so the info_changed
      // is emitted)
      Idle.add (() => { lens_search.finished (); ml.quit (); return false; });
    });

    Timeout.add (2000, () => { assert_not_reached (); });
    ml.run ();

    // first part of the test passed, now let's try to remove a source

    remove_option = true;
    // waiting for another search to finish
    ml = new MainLoop ();
    Timeout.add (2000, () => { assert_not_reached (); });
    ml.run ();

    SignalHandler.disconnect (exported_scope, sig_id);

    var bus = Bus.get_sync (BusType.SESSION);
    bus.flush_sync ();
  }

  public static void test_scope_finalize ()
  {
    // wait for the lens to vanish
    var ml = new MainLoop ();
    uint watch_id = Bus.watch_name (BusType.SESSION,
                                    "com.canonical.Unity.Lens.Test", 0,
                                    () => {},
                                    () => { ml.quit (); });

    ml.run ();
    Bus.unwatch_name (watch_id);
  }
}
