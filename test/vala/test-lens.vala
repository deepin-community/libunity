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

using Unity.Test;

public class Main
{
  static bool remote_scope_test = false;
  public static int main (string[] args)
  {
    if ("--with-remote-scope" in args) remote_scope_test = true;

    if (remote_scope_test)
    {
      Environment.set_variable ("LIBUNITY_LENS_DIRECTORY",
                                Config.TESTDIR + "/data", true);
    }
    else
    {
      Environment.set_variable ("LIBUNITY_LENS_DIRECTORY",
                                Config.TESTDIR, true);
    }

    Test.init (ref args);

    Test.add_data_func ("/Unit/Lens/Export", test_lens_export);
    if (remote_scope_test)
    {
      Test.add_data_func ("/Integration/RemoteScope/Initialize", test_remote_scope_init);
    }
    Test.add_data_func ("/Unit/LocalScope/Initialize", test_local_scope_init);
    Test.add_data_func ("/Unit/LocalScope/SearchOnView", test_local_scope_search_on_first_view);
    Test.add_data_func ("/Unit/Lens/Search", test_lens_search);
    Test.add_data_func ("/Unit/LocalScope/MergeStrategy", test_merge_strategy);
    Test.add_data_func ("/Unit/Lens/ReturnAfterScopeFinish", test_lens_return_after_scope_finish);
    Test.add_data_func ("/Unit/Lens/SuccessiveSearches", test_lens_successive_searches);
    Test.add_data_func ("/Unit/Lens/TwoSearches", test_lens_two_searches);
    Test.add_data_func ("/Unit/Lens/ModelSync", test_lens_model_sync);
    Test.add_data_func ("/Unit/Lens/ReplyHint", test_lens_reply_hint);
    Test.add_data_func ("/Unit/Lens/Sources", test_lens_sources);
    Test.add_data_func ("/Unit/Lens/Activation", test_lens_activation);
    Test.add_data_func ("/Unit/Lens/InvalidActivation", test_lens_invalid_activation);
    Test.add_data_func ("/Unit/Lens/Preview", test_lens_preview);
    Test.add_data_func ("/Unit/Lens/Preview/Async", test_lens_preview_async);
    Test.add_data_func ("/Unit/Lens/Preview/AsyncWithNull", test_lens_preview_async_with_null);
    Test.add_data_func ("/Unit/Lens/Preview/Signal", test_lens_preview_signal);
    Test.add_data_func ("/Unit/Lens/Preview/ClosedSignal", test_lens_preview_closed_signal);
    Test.add_data_func ("/Unit/Lens/Preview/ActionWithHints", test_lens_preview_action_with_hint);
    Test.add_data_func ("/Unit/Lens/PrivateContentFlag", test_lens_private_content_flag);
    Test.add_data_func ("/Unit/Lens/HomeLensDefaultName", test_lens_home_lens_default_name);

    Test.run ();

    return 0;
  }

  // this will auto-disconnect signals when it goes out of scope
  public class SignalWrapper
  {
    unowned Object obj;
    ulong sig_id;

    public SignalWrapper (Object o, ulong signal_id)
    {
      obj = o;
      sig_id = signal_id;
    }

    ~SignalWrapper ()
    {
      SignalHandler.disconnect (obj, sig_id);
    }
  }

  static Unity.Lens exported_lens;
  static bool name_owned = false;

  public static void test_lens_export ()
  {
    // register us a name on the bus
    Bus.own_name (BusType.SESSION, "com.canonical.Unity.Lens.Test", 0,
                  () => {}, () => { name_owned = true; },
                  () => { debug ("Name lost"); assert_not_reached (); });

    ensure_lens ();
  }

  public static void ensure_lens ()
  {
    if (exported_lens != null) return;

    var lens = new Unity.Lens ("/com/canonical/Unity/Lens/Test",
                               "unity_lens_test");
    lens.search_in_global = false;
    lens.search_hint = "Search hint";
    lens.export ();

    exported_lens = lens;
    assert (exported_lens != null);
  }

  static Unity.Scope local_scope;

  public static void ensure_scope ()
  {
    if (local_scope != null) return;
    ensure_lens ();

    var scope = new Unity.Scope ("/com/canonical/Unity/LocalScope/Test");

    local_scope = scope;
    assert (local_scope != null);

    exported_lens.add_local_scope (scope);
  }

  public static void test_local_scope_init ()
  {
    ensure_scope ();
  }

  public static void test_remote_scope_init ()
  {
    ensure_scope ();

    bool scope_up = false;

    // the remote scope doesn't have a dbus service file installed, so we
    // expect that something (dbus-test-runner) started it already
    var ml = new MainLoop ();
    uint watch_id = Bus.watch_name (BusType.SESSION,
                                    "com.canonical.Unity.Scope0.Test", 0,
                                    () => { scope_up = true; ml.quit (); },
                                    () => { scope_up = false; });

    run_with_timeout (ml, 2000);

    assert (scope_up == true);

    flush_bus ();
    // we need to wait a bit more to connect to the proxy
    // FIXME: find a better way to do this
    run_with_timeout (new MainLoop (), 500);

    Bus.unwatch_name (watch_id);
    // should be still up
    assert (scope_up == true);
  }

  private static void call_lens_method (string method_name,
                                        Variant? parameters,
                                        Func<Variant?>? cb,
                                        Func<Error?>? error_cb = null)
  {
    DBusConnection? bus = null;
    try
    {
      bus = Bus.get_sync (BusType.SESSION);
    }
    catch (Error e) { }

    bus.call.begin ("com.canonical.Unity.Lens.Test",
                    "/com/canonical/Unity/Lens/Test",
                    "com.canonical.Unity.Lens",
                    method_name,
                    parameters,
                    null,
                    0,
                    -1,
                    null,
                    (obj, res) =>
    {
      try
      {
        var reply = bus.call.end (res);
        if (cb != null) cb (reply);
      }
      catch (Error err)
      {
        if (error_cb != null)
          error_cb (err);
        else
          warning ("%s", err.message);
      }
    });
  }

  private static void call_lens_search (string search_string,
                                        Func<Variant?>? cb = null,
                                        Func<Error?>? error_cb = null)
  {
    var vb = new VariantBuilder (new VariantType ("(sa{sv})"));
    vb.add ("s", search_string);
    vb.open (new VariantType ("a{sv}"));
    vb.close ();

    call_lens_method ("Search", vb.end (), cb, error_cb);
  }

  private static void call_lens_activate (string uri,
                                          Unity.Protocol.ActionType action_type,
                                          Func<Variant?>? cb = null,
                                          Func<Error?>? error_cb = null)
  {
    call_lens_activate_with_hints (uri, action_type,
                                   new HashTable<string, Variant> (null, null),
                                   cb, error_cb);
  }

  private static void call_lens_activate_with_hints (
      string uri, Unity.Protocol.ActionType action_type,
      HashTable<string, Variant> hints,
      Func<Variant?>? cb = null,
      Func<Error?>? error_cb = null)
  {
    Variant parameters;
    // let's make sure we test both variants, since we have to support them
    if (hints.size () > 0)
    {
      Variant ht = hints;
      parameters = new Variant ("(su@a{sv})", uri, action_type, ht);

      call_lens_method ("ActivateWithHints", parameters, cb, error_cb);
    }
    else
    {
      parameters = new Variant ("(su)", uri, action_type);

      call_lens_method ("Activate", parameters, cb, error_cb);
    }
  }

  private static void call_lens_update_preview_property (string uri, HashTable<string, Variant> props,
                                                         Func<Variant?>? cb = null,
                                                         Func<Error?>? error_cb = null)
  {
    var vb = new VariantBuilder (new VariantType ("(sa{sv})"));
    vb.add ("s", uri);
    vb.add_value (props);

    call_lens_method ("UpdatePreviewProperty", vb.end(), cb, error_cb);
  }

  public static void test_lens_search ()
  {
    var ml = new MainLoop ();
    // make sure we got response from own_name, so we can send ourselves
    // a dbus method call
    Idle.add (() =>
    {
      if (name_owned) ml.quit ();
      return !name_owned;
    });

    ml.run ();

    call_lens_search ("foo");

    SignalWrapper[] signals = null;
    ensure_scope ();

    ml = new MainLoop ();
    bool got_search_changed = false;
    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search) =>
    {
      assert (lens_search.search_string == "foo");
      got_search_changed = true;
      lens_search.finished ();
      ml.quit ();
    }));

    // wait for the signal or timeout
    run_with_timeout (ml, 1000);

    assert (got_search_changed == true);
  }

  public static void test_local_scope_search_on_first_view ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();
    bool got_global_search = false;
    bool got_lens_search = false;
    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search, search_type) =>
    {
      assert (lens_search.search_string == "");
      if (search_type == Unity.SearchType.GLOBAL) got_global_search = true;
      else got_lens_search = true;
      lens_search.finished ();
      ml.quit ();
    }));

    local_scope.set_view_type_internal (Unity.Protocol.ViewType.HOME_VIEW);
    // wait for the signal or timeout
    run_with_timeout (ml, 1000);

    assert (got_global_search == true);

    // reset back
    local_scope.set_view_type_internal (Unity.Protocol.ViewType.HIDDEN);
  }

  private class TestMergeStrategy : Unity.MergeStrategy, GLib.Object
  {
    public int n_rows = 0;

    public unowned Dee.ModelIter? merge_result (Dee.Model target, Variant[] row)
    {
      n_rows++;
      assert (row.length == 7);
      assert (row[0].get_string().has_suffix ("uri"));
      assert (row[1].get_string() == "icon");
      assert (row[2].get_uint32() == 0);
      assert (row[3].get_string() == "mimetype");
      assert (row[4].get_string() == "display-name");
      assert (row[5].get_string() == "comment");
      assert (row[6].get_string() == "dnd-uri");

      /* Since this method returns null,
       * no rows should ever go in the results model*/
      assert (target.get_n_rows () == 0);

      return null;
    }
  }

  public static void test_merge_strategy ()
  {
    ensure_scope ();

    /* Since test cases are not completely isolated we need
     * to instantate the default merge strategy when done */
    var old_merge_strategy = exported_lens.merge_strategy;
    local_scope.results_model.clear ();

    var merge_strategy = new TestMergeStrategy ();
    exported_lens.merge_strategy = merge_strategy;

    local_scope.results_model.append ("uri", "icon", 0, "mimetype",
                                      "display-name", "comment", "dnd-uri");
    local_scope.results_model.append ("uri", "icon", 0, "mimetype",
                                      "display-name", "comment", "dnd-uri");

    assert (merge_strategy.n_rows == 2);

    exported_lens.merge_strategy = old_merge_strategy;
  }

  private static void flush_bus ()
  {
    try
    {
      var bus = Bus.get_sync (BusType.SESSION);
      bus.flush_sync ();
    }
    catch (Error e) { }

    var ml = new MainLoop ();
    Idle.add (() => { ml.quit (); return false; });
    ml.run ();
    // this should flush the dbus method calls
  }

  public static void test_lens_return_after_scope_finish ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();
    bool got_search_changed = false;
    bool finish_called = false;

    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search) =>
    {
      got_search_changed = true;
      Timeout.add (750, () =>
      {
        finish_called = true;
        lens_search.finished ();
        return false;
      });
    }));

    // we want to make sure the Search DBus call doesn't return before we
    // call finished on the LensSearch instance
    call_lens_search ("qoo", () => { ml.quit (); });
    run_with_timeout (ml, 5000);

    assert (got_search_changed == true);
    assert (finish_called == true);
  }

  public static void test_lens_successive_searches ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();
    bool got_search_changed = false;
    bool finish_called = false;

    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search) =>
    {
      got_search_changed = true;
      Timeout.add (750, () =>
      {
        lens_search.results_model.clear ();
        lens_search.results_model.append ("", "", 0, "", "", "", "");
        lens_search.finished ();
        finish_called = true;
        return false;
      });
    }));

    // we want to make sure the Search DBus call doesn't return before we
    // call finished on the LensSearch instance
    Variant? result1 = null;
    Variant? result2 = null;
    call_lens_search ("successive-searches", (result) =>
    {
      result1 = result;
    });
    // and another search with the same search string, it shouldn't return first
    call_lens_search ("successive-searches", (result) =>
    {
      result2 = result;
      ml.quit ();
    });

    run_with_timeout (ml, 5000);

    assert (got_search_changed == true);
    assert (finish_called == true);
    assert (result1.equal (result2));
  }

  public static void test_lens_two_searches ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();
    Cancellable? canc1 = null;
    Cancellable? canc2 = null;
    bool got_search_changed = false;
    uint finish_calls = 0;

    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      got_search_changed = true;
      switch (lens_search.search_string)
      {
        case "foo1": canc1 = cancellable; break;
        case "foo2": canc2 = cancellable; break;
        default: assert_not_reached ();
      }

      Timeout.add (1000, () =>
      {
        finish_calls++;
        lens_search.finished ();

        if (finish_calls == 2) ml.quit ();
        return false;
      });

      ml.quit ();
    }));

    string order = "";
    var reply_ml = new MainLoop ();
    int replies = 0;
    Func<Variant?> foo1_finished_cb = () =>
    {
      order += "1";
      if (++replies == 2) reply_ml.quit ();
    };
    Func<Variant?> foo2_finished_cb = () =>
    {
      order += "2";
      if (++replies == 2) reply_ml.quit ();
    };

    // we dont want to wait indefinitely
    var bad_timer = Timeout.add (2000, () => { assert_not_reached (); });
    call_lens_search ("foo1", foo1_finished_cb);
    ml.run ();
    flush_bus ();
    ml = new MainLoop ();
    call_lens_search ("foo2", foo2_finished_cb);
    ml.run ();

    Source.remove (bad_timer);

    assert (canc1 != null);
    assert (canc2 != null);

    assert (canc1.is_cancelled () == true);
    assert (canc2.is_cancelled () == false);

    flush_bus ();

    // the timers are still running and we need to wait for the replies
    reply_ml.run ();

    // make sure the first search finished earlier that the second
    assert (order == "12");
  }

  public static void test_lens_model_sync ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    bool got_search_changed = false;
    var ml = new MainLoop ();
    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      assert (lens_search.search_string == "model-sync");
      got_search_changed = true;

      Timeout.add (300, () =>
      {
        var model = lens_search.results_model;
        model.append ("uri", "icon", 0, "mimetype", "display-name",
                      "comment", "dnd-uri");
        lens_search.finished ();
        return false;
      });
    }));

    uint64 seqnum = 0;
    call_lens_search ("model-sync", (reply) =>
    {
      assert (reply != null);
      HashTable<string, Variant> ht = (HashTable<string, Variant>) reply.get_child_value (0);
      unowned Variant? seqnum_v = ht.lookup ("model-seqnum");
      assert (seqnum_v != null);
      seqnum = seqnum_v.get_uint64 ();
      ml.quit ();
    });

    run_with_timeout (ml, 3000);
    // libunity will emit warnings if the models are out-of-sync, those would
    // fail this test

    assert (got_search_changed == true);
    // FIXME: not too great test if previous tests did something with the model
    assert (seqnum > 0);
  }

  public static void test_lens_reply_hint ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    bool got_search_changed = false;
    var ml = new MainLoop ();
    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search, search_type, cancellable) =>
    {
      assert (lens_search.search_string == "reply-hint");
      got_search_changed = true;

      Timeout.add (10, () =>
      {
        var model = lens_search.results_model;
        model.append ("uri", "icon", 0, "mimetype", "display-name",
                      "comment", "dnd-uri");
        lens_search.set_reply_hint ("test-reply-hint",
                                    new Variant.string ("value"));
        lens_search.finished ();
        return false;
      });
    }));

    string? hint_reply = null;
    call_lens_search ("reply-hint", (reply) =>
    {
      assert (reply != null);
      HashTable<string, Variant> ht = (HashTable<string, Variant>) reply.get_child_value (0);
      unowned Variant? hint_v = ht.lookup ("test-reply-hint");
      assert (hint_v != null);
      hint_reply = hint_v.get_string ();
      ml.quit ();
    });

    run_with_timeout (ml, 3000);

    assert (got_search_changed == true);
    // FIXME: not too great test if previous tests did something with the model
    assert (hint_reply == "value");
  }

  public static void test_lens_sources ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    local_scope.sources.add_option ("id1", "Source1", null);
    local_scope.sources.add_option ("id2", "Source2", null);

    var ml = new MainLoop ();
    // wait a bit for the model to update
    Idle.add (() => { ml.quit (); return false; });
    ml.run ();
    ml = new MainLoop ();

    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search) =>
    {
      assert (lens_search.search_string.has_prefix ("sources-test"));
      lens_search.finished ();
    }));
    // do a search, so we can sync with the remote scope
    call_lens_search ("sources-test", () => { ml.quit (); });
    ml.run ();
    ml = new MainLoop ();
    // after this the sources *have* to be updated
    Idle.add (() => { ml.quit (); return false; });
    ml.run ();

    bool found1 = false;
    bool found2 = false;
    bool remote1 = false;
    bool remote2 = false;
    foreach (var filter_option in exported_lens.get_sources_internal ().options)
    {
      if (filter_option.id.has_suffix ("id1") && filter_option.id != "id1")
        found1 = true;
      else if (filter_option.id.has_suffix ("id2") && filter_option.id != "id2")
        found2 = true;
      else if (filter_option.id.has_suffix ("id1-remote"))
        remote1 = true;
      else if (filter_option.id.has_suffix ("id2-remote"))
        remote2 = true;
    }

    assert (found1);
    assert (found2);
    if (remote_scope_test)
    {
      assert (remote1);
      assert (remote2);
    }

    // =============== PART 2 of the test =============== //
    // we'll now remove one source
    local_scope.sources.remove_option ("id1");

    ml = new MainLoop ();
    // wait a bit for the model to update
    Idle.add (() => { ml.quit (); return false; });
    ml.run ();
    ml = new MainLoop ();
    // do another search to synchronize
    call_lens_search ("sources-test-2", () => { ml.quit (); });
    ml.run ();
    ml = new MainLoop ();
    // after this the sources *have* to be updated
    Idle.add (() => { ml.quit (); return false; });
    ml.run ();

    found1 = false;
    found2 = false;
    remote1 = false;
    remote2 = false;
    foreach (var filter_option in exported_lens.get_sources_internal ().options)
    {
      if (filter_option.id.has_suffix ("id1") && filter_option.id != "id1")
        found1 = true;
      else if (filter_option.id.has_suffix ("id2") && filter_option.id != "id2")
        found2 = true;
      else if (filter_option.id.has_suffix ("id1-remote"))
        remote1 = true;
      else if (filter_option.id.has_suffix ("id2-remote"))
        remote2 = true;
    }

    // make the the id1 sources are gone
    assert (found1 == false);
    assert (found2);
    if (remote_scope_test)
    {
      assert (remote1 == false);
      assert (remote2);
    }
  }

  public static void test_lens_activation ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    signals += new SignalWrapper (local_scope,
      local_scope.search_changed.connect ((lens_search) =>
    {
      assert (lens_search.search_string.has_prefix ("activation-test"));
      var model = lens_search.results_model;
      model.clear ();
      model.append ("scheme://local/", "icon", 0, "mimetype", "display-name",
                    "comment", "dnd-uri");
      lens_search.finished ();
    }));

    uint64 seqnum = 0;
    call_lens_search ("activation-test", (search_ret) =>
    {
      HashTable<string, Variant> ht = (HashTable<string, Variant>) search_ret.get_child_value (0);
      seqnum = ht["model-seqnum"].get_uint64 ();
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    bool got_activate_uri_signal = false;
    signals += new SignalWrapper (local_scope,
      local_scope.activate_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_activate_uri_signal = true;
      return null;
    }));

    ml = new MainLoop ();
    var action = Unity.Protocol.ActionType.ACTIVATE_RESULT;
    call_lens_activate (mangled_uri, action, () =>
    {
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (got_activate_uri_signal);
  }

  public static void test_lens_invalid_activation ()
  {
    // ignore warnings
    Test.log_set_fatal_handler (() => { return false; });
    Unity.Protocol.ActionType action;
    var ml = new MainLoop ();

    Func<Error?> err_cb = (err) =>
    {
      assert (err is Unity.Protocol.LensError);
      ml.quit ();
    };
    action = Unity.Protocol.ActionType.ACTIVATE_RESULT;
    call_lens_activate ("", action, null, err_cb);
    assert (run_with_timeout (ml, 5000));

    ml = new MainLoop ();
    action = Unity.Protocol.ActionType.PREVIEW_RESULT;
    call_lens_activate (":", action, null, err_cb);
    assert (run_with_timeout (ml, 5000));
  }

  public static void test_lens_preview ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    bool got_activate_uri_signal = false;
    bool got_preview_uri_signal = false;
    Unity.PreviewAction? action = null;

    signals += new SignalWrapper (local_scope,
      local_scope.activate_uri.connect ((uri) =>
    {
      got_activate_uri_signal = true;
      return null;
    }));

    signals += new SignalWrapper (local_scope,
      local_scope.preview_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_preview_uri_signal = true;
      var p = new Unity.GenericPreview ("An item", "description", null);
      action = new Unity.PreviewAction ("button1", "Do stuff!", null);
      p.add_action (action);
      return p;
    }));

    ml = new MainLoop ();
    Unity.Protocol.Preview? reconstructed = null;
    var action_type = Unity.Protocol.ActionType.PREVIEW_RESULT;
    call_lens_activate (mangled_uri, action_type, (reply) =>
    {
      var v = reply.get_child_value (0);
      Unity.Protocol.ActivationReplyRaw reply_struct =
        (Unity.Protocol.ActivationReplyRaw) v;
      reconstructed = Unity.Protocol.Preview.parse (reply_struct.hints["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (reconstructed != null);
    assert (action != null);
    assert (got_preview_uri_signal);
    assert (!got_activate_uri_signal);

    bool got_action_activated_signal = false;
    action.activated.connect (() =>
    {
      got_action_activated_signal = true;
      return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
    });

    // expecting button_id:scope_uid:uri
    ml = new MainLoop ();
    action_type = Unity.Protocol.ActionType.PREVIEW_ACTION;
    var activate_uri = "%s:%s".printf (action.id, mangled_uri);
    call_lens_activate (activate_uri, action_type, (reply) =>
    {
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (got_action_activated_signal);
  }

  public static void test_lens_preview_async ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    bool got_activate_uri_signal = false;
    bool got_preview_uri_signal = false;
    Unity.PreviewAction? action = null;

    signals += new SignalWrapper (local_scope,
      local_scope.activate_uri.connect ((uri) =>
    {
      got_activate_uri_signal = true;
      return null;
    }));

    signals += new SignalWrapper (local_scope,
      local_scope.preview_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_preview_uri_signal = true;
      var async_preview = new Unity.AsyncPreview ();

      Timeout.add (100, () =>
      {
        var p = new Unity.ApplicationPreview ("App title", "Subtitle",
                                              "Description",
                                              new ThemedIcon ("internet"),
                                              null);
        action = new Unity.PreviewAction ("button1", "Do stuff!", null);
        p.add_action (action);
        async_preview.preview_ready (p);
        return false;
      });
      return async_preview;
    }));

    ml = new MainLoop ();
    Unity.Protocol.Preview? reconstructed = null;
    var action_type = Unity.Protocol.ActionType.PREVIEW_RESULT;
    call_lens_activate (mangled_uri, action_type, (reply) =>
    {
      var v = reply.get_child_value (0);
      Unity.Protocol.ActivationReplyRaw reply_struct =
        (Unity.Protocol.ActivationReplyRaw) v;
      reconstructed = Unity.Protocol.Preview.parse (reply_struct.hints["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (reconstructed != null);
    assert (reconstructed is Unity.Protocol.ApplicationPreview);
    assert (reconstructed.title == "App title");
    assert (action != null);
    assert (got_preview_uri_signal);
    assert (!got_activate_uri_signal);

    bool got_action_activated_signal = false;
    action.activated.connect (() =>
    {
      got_action_activated_signal = true;
      return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
    });

    // expecting button_id:scope_uid:uri
    ml = new MainLoop ();
    action_type = Unity.Protocol.ActionType.PREVIEW_ACTION;
    var activate_uri = "%s:%s".printf (action.id, mangled_uri);
    call_lens_activate (activate_uri, action_type, (reply) =>
    {
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (got_action_activated_signal);
  }

  public static void test_lens_preview_async_with_null ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    bool got_preview_uri_signal = false;
    bool got_activate_uri_signal = false;

    signals += new SignalWrapper (local_scope,
      local_scope.activate_uri.connect ((uri) =>
    {
      got_activate_uri_signal = true;
      return null;
    }));

    signals += new SignalWrapper (local_scope,
      local_scope.preview_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_preview_uri_signal = true;
      var async_preview = new Unity.AsyncPreview ();

      Idle.add (() =>
      {
        async_preview.preview_ready (null);
        return false;
      });
      return async_preview;
    }));

    ml = new MainLoop ();
    Unity.Protocol.Preview? reconstructed = null;
    var action = Unity.Protocol.ActionType.PREVIEW_RESULT;
    call_lens_activate (mangled_uri, action, (reply) =>
    {
      var v = reply.get_child_value (0);
      Unity.Protocol.ActivationReplyRaw reply_struct =
        (Unity.Protocol.ActivationReplyRaw) v;
      reconstructed = Unity.Protocol.Preview.parse (reply_struct.hints["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (reconstructed != null);
    assert (reconstructed is Unity.Protocol.GenericPreview);
    assert (reconstructed.title == "");
    assert (reconstructed.description == "");
    assert (got_preview_uri_signal);
    assert (!got_activate_uri_signal);
  }

  public static void test_lens_preview_signal ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    bool got_activate_uri_signal = false;
    bool got_preview_uri_signal = false;
    string? request_item_signal_uri = null;
    int request_item_signal_count = 0;

    signals += new SignalWrapper (local_scope,
      local_scope.activate_uri.connect ((uri) =>
    {
      got_activate_uri_signal = true;
      return null;
    }));

    var item1 = new Unity.SeriesItem ("file:///series_item_1.jpg", "Item #1", null);
    var item2 = new Unity.SeriesItem ("file:///series_item_2.jpg", "Item #2", null);
    var series_preview = new Unity.SeriesPreview ({item1, item2}, "file:///series_item_1.jpg");

    signals += new SignalWrapper (series_preview,
      series_preview.request_item_preview.connect ((uri) =>
    {
      request_item_signal_count++;
      request_item_signal_uri = uri;
      return new Unity.GenericPreview ("child preview",
                                       "this is a child preview",
                                       null);
    }));

    signals += new SignalWrapper (local_scope,
      local_scope.preview_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_preview_uri_signal = true;
      return series_preview;
    }));

    ml = new MainLoop ();
    Unity.Protocol.SeriesPreview? sp_reconstructed = null;
    call_lens_activate (mangled_uri, Unity.Protocol.ActionType.PREVIEW_RESULT, (reply) =>
    {
      var v = reply.get_child_value (0);
      Unity.Protocol.ActivationReplyRaw reply_struct =
        (Unity.Protocol.ActivationReplyRaw) v;
      sp_reconstructed = (Unity.Protocol.SeriesPreview?)Unity.Protocol.Preview.parse (reply_struct.hints["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (sp_reconstructed != null);
    assert (sp_reconstructed.selected_item == 0);
    assert (got_preview_uri_signal);
    assert (!got_activate_uri_signal);

    sp_reconstructed.begin_updates();
    sp_reconstructed.selected_item = 1; // this should result in series-active-index property update
    var updates = sp_reconstructed.end_updates_as_hashtable();

    assert (updates != null);
    assert (updates.size() == 1);
    assert (updates.contains("series-active-index"));
    assert (updates["series-active-index"].get_int32() == 1);

    Unity.Protocol.GenericPreview? gp_reconstructed = null;

    ml = new MainLoop ();
    //
    // select 1st series item - send update of series-active-index property
    call_lens_update_preview_property (mangled_uri, updates, (reply) =>
    {
      HashTable<string, Variant> ht = (HashTable<string, Variant>) reply.get_child_value (0);
      assert (ht.contains("preview"));
      gp_reconstructed = (Unity.Protocol.GenericPreview?)Unity.Protocol.Preview.parse (ht["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (gp_reconstructed != null);
    assert (request_item_signal_uri == item2.uri);
    assert (request_item_signal_count > 1);

    ml = new MainLoop ();
    request_item_signal_count = 0;

    sp_reconstructed.begin_updates();
    sp_reconstructed.selected_item = 1;
    Variant updates_var = sp_reconstructed.end_updates();
    updates = (HashTable<string, Variant>)updates_var;

    // sending update for unchanged selected_item property return preview as well, but no signal is emitted
    call_lens_update_preview_property (mangled_uri, updates, (reply) =>
    {
      HashTable<string, Variant> ht = (HashTable<string, Variant>) reply.get_child_value (0);
      assert (ht.contains("preview") == true);
      gp_reconstructed = (Unity.Protocol.GenericPreview?)Unity.Protocol.Preview.parse (ht["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (gp_reconstructed != null);
    assert (request_item_signal_uri == item2.uri);
    assert (request_item_signal_count == 0);
  }

  public static void test_lens_preview_closed_signal ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    bool got_preview_uri_signal = false;
    int got_closed_signal = 0;

    var preview = new Unity.GenericPreview ("title", "description", null);

    // this signal handler gets called when we updates are sent in the last step of the test
    signals += new SignalWrapper (preview,
      preview.closed.connect (() =>
    {
      got_closed_signal++;
    }));

    // this signal handler gets called when activate is called with PREVIEW_RESULT
    signals += new SignalWrapper (local_scope,
      local_scope.preview_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_preview_uri_signal = true;
      return preview;
    }));

    ml = new MainLoop ();

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    Unity.Protocol.GenericPreview? reconstructed = null;
    var action = Unity.Protocol.ActionType.PREVIEW_RESULT;
    call_lens_activate (mangled_uri, action, (reply) =>
    {
      var v = reply.get_child_value (0);
      Unity.Protocol.ActivationReplyRaw reply_struct =
        (Unity.Protocol.ActivationReplyRaw) v;
      reconstructed = (Unity.Protocol.GenericPreview?)Unity.Protocol.Preview.parse (reply_struct.hints["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (reconstructed != null);
    assert (got_closed_signal == 0);

    // send preview_closed "signal"; this will result in setting action=close in the updates hashtable.
    reconstructed.begin_updates();
    reconstructed.preview_closed();
    var updates = reconstructed.end_updates_as_hashtable();

    assert (updates != null);
    assert (updates.size() == 1);
    assert (updates.contains("base-preview-action"));
    assert (updates["base-preview-action"].get_string() == "closed");

    ml = new MainLoop ();

    // send 'closed' signal
    call_lens_update_preview_property (mangled_uri, updates, (reply) =>
    {
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (got_closed_signal == 1);
  }

  public static void test_lens_preview_action_with_hint ()
  {
    SignalWrapper[] signals = null;
    ensure_scope ();

    var ml = new MainLoop ();

    bool got_preview_uri_signal = false;
    bool got_activated_signal = false;

    var preview = new Unity.GenericPreview ("title", "description", null);
    var action = new Unity.PreviewAction ("button1", "Do stuff!", null);
    preview.add_action (action);

    signals += new SignalWrapper (action,
      action.activated.connect ((uri) =>
    {
      got_activated_signal = true;
      assert (action.hints["passing-extra-info"].get_boolean () == true);
      return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
    }));

    // this signal handler gets called when activate is called with PREVIEW_RESULT
    signals += new SignalWrapper (local_scope,
      local_scope.preview_uri.connect ((uri) =>
    {
      assert (uri == "scheme://local/");
      got_preview_uri_signal = true;
      return preview;
    }));

    ml = new MainLoop ();

    var lens_results_model =
      exported_lens.get_model_internal (0) as Dee.SharedModel;
    var iter = lens_results_model.get_first_iter ();
    var mangled_uri = lens_results_model.get_string (iter, 0);

    Unity.Protocol.Preview? reconstructed = null;
    var action_type = Unity.Protocol.ActionType.PREVIEW_RESULT;
    call_lens_activate (mangled_uri, action_type, (reply) =>
    {
      var v = reply.get_child_value (0);
      Unity.Protocol.ActivationReplyRaw reply_struct =
        (Unity.Protocol.ActivationReplyRaw) v;
      reconstructed = Unity.Protocol.Preview.parse (reply_struct.hints["preview"]);
      ml.quit ();
    });
    run_with_timeout (ml, 5000);

    assert (reconstructed != null);

    ml = new MainLoop ();

    // activate the action, check that hints are passed to it
    var hints = new HashTable<string, Variant> (str_hash, str_equal);
    hints["passing-extra-info"] = new Variant.boolean (true);
    call_lens_activate_with_hints ("%s:%s".printf (action.id, mangled_uri), Unity.Protocol.ActionType.PREVIEW_ACTION, hints, (reply) =>
    {
      ml.quit ();
    });

    run_with_timeout (ml, 5000);

    assert (got_activated_signal);
  }

  public static void test_lens_private_content_flag ()
  {
    ensure_scope ();
    var ml = new MainLoop ();

    Unity.Protocol.LensInfo? info = null;

    var bus = Bus.get_sync (BusType.SESSION);
    var sig_id = bus.signal_subscribe (null,
                                       "com.canonical.Unity.Lens",
                                       "Changed",
                                       "/com/canonical/Unity/Lens/Test",
                                       null,
                                       0,
                                       (conn, sender, obj_path, ifc_name, sig_name, parameters) =>
                                       {
                                         info = (Unity.Protocol.LensInfo) parameters.get_child_value (0);
                                         ml.quit ();
                                       });

    // check default value of provides_personal_content
    info = null;
    call_lens_method ("InfoRequest", null, null);

    run_with_timeout (ml, 5000);

    assert (info != null);
    assert (info.hints.contains ("provides-personal-content"));
    assert (info.hints["provides-personal-content"].get_boolean () == false);

    info = null;
    local_scope.provides_personal_content = true;

    run_with_timeout (ml, 5000);

    assert (info != null);
    assert (info.hints.contains ("provides-personal-content"));
    assert (info.hints["provides-personal-content"].get_boolean () == true);

    bus.signal_unsubscribe (sig_id);
  }

  public static void test_lens_home_lens_default_name ()
  {
    assert (exported_lens != null);
    var ml = new MainLoop ();

    // check default value of home_lens_default_name
    Unity.Protocol.LensInfo? info = null;

    var bus = Bus.get_sync (BusType.SESSION);
    var sig_id = bus.signal_subscribe (null,
                                       "com.canonical.Unity.Lens",
                                       "Changed",
                                       "/com/canonical/Unity/Lens/Test",
                                       null,
                                       0,
                                       (conn, sender, obj_path, ifc_name, sig_name, parameters) =>
                                       {
                                         info = (Unity.Protocol.LensInfo) parameters.get_child_value (0);
                                         ml.quit ();
                                       });

    call_lens_method ("InfoRequest", null, null);

    run_with_timeout (ml, 5000);
    assert (info != null);
    assert (info.hints.contains ("home-lens-default-name") == false);

    info = null;
    exported_lens.home_lens_default_name = null;
    run_with_timeout (ml, 5000);

    assert (info != null);
    assert (info.hints.contains ("home-lens-default-name") == false);

    info = null;
    exported_lens.home_lens_default_name = "Foo Bar";
    run_with_timeout (ml, 5000);

    assert (info != null);
    assert (info.hints.contains ("home-lens-default-name"));
    assert (info.hints["home-lens-default-name"].get_string () == "Foo Bar");

    bus.signal_unsubscribe (sig_id);
  }
}
