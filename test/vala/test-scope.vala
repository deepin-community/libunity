/*
 * Copyright (C) 2011-2012 Canonical Ltd
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

using Unity.Protocol;
using Unity.Test;

public class Main
{
  const string DBUS_NAME = "com.canonical.Unity.Scope.Test";
  const string DBUS_PATH = "/com/canonical/Unity/Scope/Test";

  const string MASTER_SCOPE_DBUS_PATH = "/com/canonical/Unity/MasterScope/Test";
  const string HOME_SCOPE_DBUS_PATH = "/com/canonical/Unity/HomeScope/Test";

  const string ACTIVATE_TEST_URI = "file:///test_uri";
  const string PREVIEW_TEST_ACTION = "action_id1";

  public static int main (string[] args)
  {
    string gsettings_schema_dir = Config.BUILDDIR+"/data";

    Environment.set_variable ("XDG_DATA_DIRS", Config.TESTDIR+"/data", true);
    Environment.set_variable ("XDG_DATA_HOME", Config.TESTDIR+"/data", true);
    Environment.set_variable ("LIBUNITY_LENS_DIRECTORY", Config.TESTDIR, true);
    Environment.set_variable ("GSETTINGS_SCHEMA_DIR", gsettings_schema_dir, true);
    Environment.set_variable ("GSETTINGS_BACKEND", "memory", true);
    try {
      Process.spawn_command_line_sync ("glib-compile-schemas " + gsettings_schema_dir);
    } catch (SpawnError e) {
      stderr.printf ("%s\n", e.message);
      return 1;
    }

    Test.init (ref args);

    Test.add_data_func ("/Unit/Scope/Export",
        Fixture.create<ScopeInitTester> (ScopeInitTester.test_scope_export));
    Test.add_data_func ("/Unit/Scope/ExportTwoScopes",
        Fixture.create<ScopeInitTester> (ScopeInitTester.test_scope_export_two_scopes));
    Test.add_data_func ("/Unit/Scope/ProxyConnection",
        Fixture.create<ScopeInitTester> (ScopeInitTester.test_scope_proxy));
    Test.add_data_func ("/Unit/Scope/OpenChannel",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_open_channel));
    Test.add_data_func ("/Unit/Scope/CloseChannel",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_open_close_channel));
    Test.add_data_func ("/Unit/Scope/Metadata",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_metadata));
    Test.add_data_func ("/Unit/Scope/Search",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_search));
    Test.add_data_func ("/Unit/Scope/Activation",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_activation));
    Test.add_data_func ("/Unit/Scope/Preview",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_preview));
    Test.add_data_func ("/Unit/Scope/PreviewAction",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_preview_action));
    Test.add_data_func ("/Unit/Scope/Filters",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_filters));
    Test.add_data_func ("/Unit/Scope/FormFactor",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_form_factor));
    Test.add_data_func ("/Unit/Scope/ResultsInvalidated",
        Fixture.create<ScopeTester> (ScopeTester.test_scope_results_invalidated));


    Test.add_data_func ("/Unit/SimpleScope/Search",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_search));
    Test.add_data_func ("/Unit/SimpleScope/SearchAsync",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_search_async));
    Test.add_data_func ("/Unit/SimpleScope/SearchWithFlush",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_search_with_flush));
    Test.add_data_func ("/Unit/SimpleScope/DiffSearch",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_diff_search));
    Test.add_data_func ("/Unit/SimpleScope/NoDiffSearch",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_no_diff_search));
    Test.add_data_func ("/Unit/SimpleScope/Activation",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_activation));
    Test.add_data_func ("/Unit/SimpleScope/Preview",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_preview));
    Test.add_data_func ("/Unit/SimpleScope/PreviewAsync",
        Fixture.create<SimpleScopeTester> (SimpleScopeTester.test_simple_preview_async));

    Test.add_data_func ("/Unit/MasterScope/OpenChannel",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_open_channel));
    Test.add_data_func ("/Unit/MasterScope/CloseChannel",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_open_close_channel));
    Test.add_data_func ("/Unit/MasterScope/Search",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_search));
    Test.add_data_func ("/Unit/MasterScope/MultiSearch",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_multi_search));
    Test.add_data_func ("/Unit/MasterScope/GlobalSearch",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_global_search));
    Test.add_data_func ("/Unit/MasterScope/MultipleChannels",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_multiple_channels));
    Test.add_data_func ("/Unit/MasterScope/SearchOnMultipleChannels",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_search_multiple_channels));
    Test.add_data_func ("/Unit/MasterScope/NoContentHint",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_no_content));
    Test.add_data_func ("/Unit/MasterScope/ResultsInvalidated",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_results_invalidated));
    Test.add_data_func ("/Unit/MasterScope/Activation",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_activation));
    Test.add_data_func ("/Unit/MasterScope/OverriddenGotoUri",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_overridden_goto_uri));
    Test.add_data_func ("/Unit/MasterScope/Sorting/Ascending",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_sorting_asc));
    Test.add_data_func ("/Unit/MasterScope/Sorting/Descending",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_sorting_desc));
    Test.add_data_func ("/Unit/MasterScope/SortingOptionalFields/Ascending",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_sorting_optional_asc));
    Test.add_data_func ("/Unit/MasterScope/SortingOptionalFields/Descending",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_sorting_optional_desc));
    Test.add_data_func ("/Unit/MasterScope/Dedup/RequiredFields",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_deduplication));
    Test.add_data_func ("/Unit/MasterScope/Dedup/RequiredFields/PerCategory",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_deduplication_per_category));
    Test.add_data_func ("/Unit/MasterScope/Filters",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_master_filters));
    Test.add_data_func ("/Unit/MasterScope/SubscopesFilterHint",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_subscopes_filter_hint));
    Test.add_data_func ("/Unit/MasterScope/PushResults",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_push_results));
    Test.add_data_func ("/Unit/MasterScope/PushAndSearch",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_push_results_and_search));
    Test.add_data_func ("/Unit/MasterScope/SubscopesSearch",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_subscopes_search));
    Test.add_data_func ("/Unit/MasterScope/OverriddenSubscopes",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_overridden_subscopes));
    Test.add_data_func ("/Unit/MasterScope/ProgressSourceProperty",
        Fixture.create<MasterScopeTester> (MasterScopeTester.test_progress_source_property));
    Test.add_data_func ("/Unit/AggregatorScope/CategoryOrderSignal",
        Fixture.create<AggregatorScopeTester> (AggregatorScopeTester.test_scope_category_order_signal));
    Test.add_data_func ("/Unit/AggregatorScope/Activation",
        Fixture.create<AggregatorScopeTester> (AggregatorScopeTester.test_scope_activation_handler));
    Test.add_data_func ("/Unity/ScopeLoader/LoadScope",
        Fixture.create<ScopeLoaderTester> (ScopeLoaderTester.test_load_scope));
    Test.add_data_func ("/Unity/ScopeLoader/LoadGroup",
        Fixture.create<ScopeLoaderTester> (ScopeLoaderTester.test_load_group));
    Test.add_data_func ("/Unity/ScopeLoader/LoadModule",
        Fixture.create<ScopeLoaderTester> (ScopeLoaderTester.test_load_module));

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

  class TestSearcher: Unity.ScopeSearchBase
  {
    public unowned TestScope owner { get; set; }

    public TestSearcher (TestScope scope)
    {
      Object (owner: scope);
    }

    public override void run ()
    {
      // careful this is running in separate thread
      owner.search (this);
    }
  }

  class TestPreviewer: Unity.ResultPreviewer
  {
    public unowned TestScope owner { get; set; }

    public TestPreviewer (TestScope scope)
    {
      Object (owner: scope);
    }

    public override Unity.AbstractPreview? run ()
    {
      // careful this is running in separate thread
      var preview = owner.preview (this);
      return preview;
    }
  }

  class TestScope: Unity.AbstractScope
  {
    public string dbus_name { get; construct set; }
    public string dbus_path { get; construct set; }

    public TestScope (string dbus_name, string dbus_path)
    {
      Object (dbus_name: dbus_name, dbus_path: dbus_path);
    }

    public override Unity.ScopeSearchBase create_search_for_query (Unity.SearchContext ctx)
    {
      var searcher = new TestSearcher (this);
      assert (ctx.search_metadata.locale != null);
      searcher.set_search_context (ctx);

      return searcher;
    }

    public signal void search (Unity.ScopeSearchBase search_ctx);

    public signal Unity.AbstractPreview? preview (Unity.ResultPreviewer previewer);
    public signal Unity.ActivationResponse? activate_uri (string uri);
    public signal Unity.ActivationResponse? activate_action (Unity.ScopeResult result, string action_id);

    public override Unity.ResultPreviewer create_previewer (Unity.ScopeResult result, Unity.SearchMetadata metadata)
    {
      var previewer = new TestPreviewer (this);
      previewer.set_scope_result (result);
      previewer.set_search_metadata (metadata);
      assert (metadata.locale != null);

      return previewer;
    }

    public override Unity.ActivationResponse? activate (Unity.ScopeResult result, Unity.SearchMetadata metadata, string? action_id)
    {
      if (action_id == null)
        return activate_uri (result.uri);
      else
        return activate_action (result, action_id);
    }

    public override Unity.CategorySet get_categories ()
    {
      return new Unity.CategorySet ();
    }

    public override Unity.FilterSet get_filters ()
    {
      var filters = new Unity.FilterSet ();
      filters.add (ScopeTester.create_filter ());

      return filters;
    }

    public override Unity.Schema get_schema ()
    {
      var schema = new Unity.Schema ();
      schema.add_field ("required_string", "s", Unity.Schema.FieldType.REQUIRED);
      schema.add_field ("required_int", "i", Unity.Schema.FieldType.REQUIRED);
      schema.add_field ("optional_string", "s", Unity.Schema.FieldType.OPTIONAL);

      return schema;
    }

    public override string get_group_name ()
    {
      return dbus_name;
    }

    public override string get_unique_name ()
    {
      return dbus_path;
    }

    public override string get_search_hint ()
    {
      return "Search hint";
    }
  }

  class ScopeInitTester: Object, Fixture
  {
    public TestScope scope;
    public Unity.ScopeDBusConnector connector;

    public static ScopeProxy? acquire_test_proxy (string path = DBUS_PATH,
                                                  string name = DBUS_NAME)
    {
      var ml = new MainLoop ();
      ScopeProxy? proxy = null;
      ScopeProxy.new_from_dbus.begin (name, path, null, (obj, res) =>
      {
        try
        {
          proxy = ScopeProxy.new_from_dbus.end (res);
        }
        catch (Error e) {}
        ml.quit ();
      });
      assert (run_with_timeout (ml));
      return proxy;
    }

    public static bool acquire_names ()
    {
      var ml = new MainLoop ();
      var manager = Unity.Internal.ScopeDBusNameManager.get_default ();
      bool success = false;
      manager.acquire_names.begin ((obj, result) =>
        {
          success = manager.acquire_names.end (result);
          ml.quit();
        });
      ml.run ();
      return success;
    }

    private void setup ()
    {
    }

    private void teardown ()
    {
      if (connector != null)
      {
        connector.unexport ();
      }
    }

    public void export_scope () throws Error
    {
      assert (scope != null);
      assert (connector == null);
      connector = new Unity.ScopeDBusConnector (scope);
      connector.export ();
    }

    public void test_scope_export ()
    {
      scope = new TestScope (DBUS_NAME, DBUS_PATH);
      try
      {
        export_scope ();
      }
      catch (Error err) { assert_not_reached (); }

      assert (acquire_names ());
    }

    public void test_scope_export_two_scopes ()
    {
      scope = new TestScope (DBUS_NAME, DBUS_PATH);
      try
      {
        export_scope ();
      }
      catch (Error err) { assert_not_reached (); }

      // Export a second scope using the same D-Bus name
      var scope2 = new TestScope (DBUS_NAME, "/second/scope/path");
      var connector2 = new Unity.ScopeDBusConnector (scope2);
      try
      {
        connector2.export ();
      }
      catch (Error err) { assert_not_reached (); }
      finally
      {
        connector2.unexport ();
      }
      assert (acquire_names ());
    }

    public void test_scope_proxy ()
    {
      scope = new TestScope (DBUS_NAME, DBUS_PATH);
      try
      {
        export_scope ();
      }
      catch (Error err) { assert_not_reached (); }
      assert (acquire_names ());

      var proxy = acquire_test_proxy ();
      assert (proxy != null);

      assert (proxy.search_hint == "Search hint");

      ensure_destruction ((owned) proxy);
    }
  }

  class ScopeTester: ScopeInitTester, Fixture
  {
    private ScopeProxy proxy;

    private void setup ()
    {
      base.setup ();

      scope = new TestScope (DBUS_NAME, DBUS_PATH);

      try
      {
        export_scope ();
      }
      catch (Error err) { assert_not_reached (); }
      assert (acquire_names ());

      proxy = ScopeInitTester.acquire_test_proxy ();
      assert (proxy != null);
    }

    private void teardown ()
    {
      ensure_destruction ((owned) proxy);
      connector.unexport ();
      ensure_destruction ((owned) connector);
      ensure_destruction ((owned) scope);

      base.teardown ();
    }

    public static Variant[] scope_result_to_variant (Unity.ScopeResult result)
    {
      var v = new Variant[9];
      v[0] = result.uri;
      v[1] = result.icon_hint;
      v[2] = result.category;
      v[3] = (uint) result.result_type;
      v[4] = result.mimetype;
      v[5] = result.title;
      v[6] = result.comment;
      v[7] = result.dnd_uri;
      v[8] = result.metadata;

      return v;
    }

    public static Unity.Filter create_filter ()
    {
      var check_option_filter = new Unity.CheckOptionFilter ("check-options",
                                                             "Check options",
                                                             null,
                                                             true);
      check_option_filter.add_option ("option1", "Option #1", null);
      check_option_filter.add_option ("option2", "Option #2", null);
      check_option_filter.add_option ("option3", "Option #3", null);
      return check_option_filter;
    }

    public static void wait_for_synchronization (Dee.Model model)
    {
      var shared_model = model as Dee.SharedModel;
      if (shared_model == null) return;

      if (shared_model.is_synchronized ()) return;
      SignalWrapper[] signals = {};
      var ml = new MainLoop ();

      signals += new SignalWrapper (shared_model, 
        shared_model.notify["synchronized"].connect (() =>
      {
        ml.quit ();
      }));

      run_with_timeout (ml);
    }

    public static string open_channel (ScopeProxy proxy,
                                       ChannelType channel_type,
                                       out Dee.SerializableModel model,
                                       bool wait_for_sync = false,
                                       ChannelFlags flags = 0)
    {
      string? channel_id = null;
      Dee.Model? real_model = null;
      var ml = new MainLoop ();
      /* Need to use PRIVATE channel, cause standard SharedModel won't
       * synchronize properly when trying to connect to the model
       * from the same process (/bus address) */
      proxy.open_channel.begin (channel_type,
                                flags | ChannelFlags.PRIVATE,
                                null,
                                (obj, res) =>
      {
        try
        {
          channel_id = proxy.open_channel.end (res, out real_model);
          if (wait_for_sync)
          {
            wait_for_synchronization (real_model);
          }
          ml.quit ();
        }
        catch (Error err)
        {
          ml.quit ();
        }
      });

      assert (run_with_timeout (ml));
      assert (channel_id != null);
      model = real_model as Dee.SerializableModel;
      return channel_id;
    }

    public static void close_channel (ScopeProxy proxy, string channel_id)
    {
      var ml = new MainLoop ();
      proxy.close_channel.begin (channel_id, null,
                                 (obj, res) =>
      {
        try
        {
          proxy.close_channel.end (res);
        }
        catch (Error err) { /* silently ignore */ }
        ml.quit ();
      });

      assert (run_with_timeout (ml));
    }

    public static HashTable<string, Variant> perform_search (
        ScopeProxy proxy, string channel_id, string query,
        HashTable<string, Variant>? hints = null,
        Dee.SerializableModel? model = null,
        TestScope? target_scope = null,
        Func<Unity.SearchContext?>? add_results_cb = null)
    {
      SignalWrapper[] signals = {};
      var ml = new MainLoop ();
      HashTable<string, Variant>? reply_dict = null;
      proxy.search.begin (channel_id, query,
                          hints ?? new HashTable<string, Variant> (null, null),
                          null,
                          (obj, res) =>
      {
        try
        {
          reply_dict = proxy.search.end (res);
        }
        catch (Error err) {}
        ml.quit ();
      });

      bool got_search_signal = false;
      if (target_scope != null)
      {
        signals += new SignalWrapper (
            target_scope, target_scope.search.connect ((search) =>
        {
          got_search_signal = true;
          if (add_results_cb != null) add_results_cb (search.search_context);
        }));
      }

      assert (run_with_timeout (ml, 10000));
      assert (reply_dict != null);
      if (target_scope != null) assert (got_search_signal);

      // wait for the model to synchronize
      var variant = reply_dict[Unity.Internal.SEARCH_SEQNUM_HINT];
      if (variant != null && model != null)
      {
        uint64 desired_seqnum = variant.get_uint64 ();
        if (desired_seqnum > model.get_seqnum ())
        {
          ml = new MainLoop ();
          var shared_model = model as Dee.SharedModel;
          signals += new SignalWrapper (shared_model,
            shared_model.end_transaction.connect ((seqnum1, seqnum2) =>
          {
            if (seqnum2 >= desired_seqnum)
              Idle.add (() => { ml.quit (); return false; });
          }));
          run_with_timeout (ml, 10000);
        }
      }
      signals = {};
      return reply_dict;
    }

    public static HashTable<string, Variant> push_results (
        ScopeProxy proxy, string channel_id, string query,
        string source_scope_id, Dee.SerializableModel pushed_model,
        string[] categories, Dee.SerializableModel? model = null)
    {
      SignalWrapper[] signals = {};
      var ml = new MainLoop ();
      HashTable<string, Variant>? reply_dict = null;
      proxy.push_results.begin (channel_id, query, source_scope_id,
                                pushed_model, categories, null,
                                (obj, res) =>
      {
        try
        {
          reply_dict = proxy.push_results.end (res);
        }
        catch (Error err) {}
        ml.quit ();
      });

      assert (run_with_timeout (ml));
      assert (reply_dict != null);

      // wait for the model to synchronize
      var variant = reply_dict[Unity.Internal.SEARCH_SEQNUM_HINT];
      if (variant != null && model != null)
      {
        uint64 desired_seqnum = variant.get_uint64 ();
        if (desired_seqnum > model.get_seqnum ())
        {
          ml = new MainLoop ();
          var shared_model = model as Dee.SharedModel;
          signals += new SignalWrapper (shared_model,
            shared_model.end_transaction.connect ((seqnum1, seqnum2) =>
          {
            if (seqnum2 >= desired_seqnum)
              Idle.add (() => { ml.quit (); return false; });
          }));
          run_with_timeout (ml);
        }
      }
      return reply_dict;
    }

    public static ActivationReplyRaw? activate (
        ScopeProxy proxy, string channel_id,
        Unity.Protocol.ActionType action_type,
        Unity.ScopeResult result,
        HashTable<string, Variant> hints)
    {
      var ml = new MainLoop ();
      var result_arr = scope_result_to_variant (result);
      Unity.Protocol.ActivationReplyRaw? activation_reply = null;
      proxy.activate.begin (channel_id, result_arr,
                            action_type,
                            hints,
                            null,
                            (obj, res) =>
      {
        try
        {
          activation_reply = proxy.activate.end (res);
        }
        catch (Error err) { warning ("%s", err.message); }
        ml.quit ();
      });

      assert (run_with_timeout (ml));
      return activation_reply;
    }

    public static ActivationReplyRaw? activate_result (
        ScopeProxy proxy, string channel_id, Unity.ScopeResult result,
        TestScope? target_scope = null)
    {
      return activate (proxy, channel_id, Unity.Protocol.ActionType.ACTIVATE_RESULT,
                       result,
                       new HashTable<string, Variant> (null, null));
    }

    public static HashTable<string, Variant> preview_result (
        ScopeProxy proxy, string channel_id, Unity.ScopeResult result,
        TestScope? target_scope = null,
        Unity.Preview? result_preview = null)
    {
      SignalWrapper[] signals = {};
      var ml = new MainLoop ();
      HashTable<string, Variant>? reply_dict = null;
      var result_arr = scope_result_to_variant (result);
      proxy.activate.begin (channel_id, result_arr,
                            Unity.Protocol.ActionType.PREVIEW_RESULT,
                            new HashTable<string, Variant> (null, null),
                            null,
                            (obj, res) =>
      {
        try
        {
          var reply = proxy.activate.end (res);
          reply_dict = reply.hints;
        }
        catch (Error err) { warning ("%s", err.message); }
        ml.quit ();
      });

      bool got_preview_signal = false;
      if (target_scope != null)
      {
        signals += new SignalWrapper (
            target_scope, target_scope.preview.connect ((search) =>
        {
          got_preview_signal = true;
          return result_preview;
        }));
      }

      assert (run_with_timeout (ml));
      assert (reply_dict != null);
      if (target_scope != null) assert (got_preview_signal);

      signals = {};
      return reply_dict;
    }

    public void test_scope_open_channel ()
    {
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);
    }

    public void test_scope_open_close_channel ()
    {
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);
      close_channel (proxy, channel_id);
    }

    public void test_scope_metadata ()
    {
      Dee.Model model;
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, out model, true);
      assert (channel_id != null);

      assert (model.get_column_names () != null);
      assert (model.get_field_schema ("required_string", null) == "s");
      assert (model.get_field_schema ("required_int", null) == "i");
      assert (model.get_field_schema ("optional_string", null) == "s");
    }

    public void test_scope_search ()
    {
      // we need channel first
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null,
                                                   null, scope, (search) =>
      {
        Unity.ScopeResult result = Unity.ScopeResult ();
        result.uri = "test:uri";
        result.icon_hint = "";
        result.category = 0;
        result.result_type = Unity.ResultType.DEFAULT;
        result.mimetype = "inode/folder";
        result.title = "Title";
        result.comment = "";
        result.dnd_uri = "test::uri";
        result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
        result.metadata["required_int"] = 5;
        result.metadata["required_string"] = "foo";
        search.result_set.add_result (result);
      });

      assert (reply_dict != null);
    }

    public void test_scope_preview ()
    {
      // we need channel first
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = "test:uri";
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "test:uri";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
      result.metadata["required_int"] = 5;
      result.metadata["required_string"] = "foo";

      var preview = new Unity.GenericPreview ("test:uri", "subtitle", null);

      var reply_dict = ScopeTester.preview_result (proxy, channel_id, result,
                                                   scope, preview);
      assert (reply_dict != null);
      var preview_v = reply_dict["preview"];
      assert (preview_v != null);

      var reconstructed = Unity.Protocol.Preview.parse (preview_v);
      assert (reconstructed.title == preview.title);
    }

    public void test_scope_preview_action ()
    {
      // we need channel first
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = ACTIVATE_TEST_URI;
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "file:///";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
      result.metadata["required_int"] = 5;
      result.metadata["required_string"] = "foo";

      bool got_activate_signal = false;
      scope.activate_action.connect ((result, action_id) =>
      {
        got_activate_signal = true;
        assert (action_id == PREVIEW_TEST_ACTION);
        return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
      });

      var ml = new MainLoop ();
      Unity.Protocol.ActivationReplyRaw? activation_reply = null;
      var hints = new HashTable<string, Variant> (str_hash, str_equal);
      hints[Unity.Internal.ACTIVATE_PREVIEW_ACTION_HINT] = PREVIEW_TEST_ACTION;
      proxy.activate.begin (channel_id, scope_result_to_variant (result),
                            Unity.Protocol.ActionType.PREVIEW_ACTION,
                            hints, null,
                            (obj, res) =>
      {
        try
        {
          activation_reply = proxy.activate.end (res);
        }
        catch (Error e) {}
        ml.quit ();
      });

      assert (run_with_timeout (ml));
      assert (activation_reply != null);
      assert (activation_reply.handled == Unity.HandledType.NOT_HANDLED);
      assert (got_activate_signal == true);
    }

    public void test_scope_activation ()
    {
      // we need channel first
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = ACTIVATE_TEST_URI;
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "file:///";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
      result.metadata["required_int"] = 5;
      result.metadata["required_string"] = "foo";

      perform_search (proxy, channel_id, "", null, null, scope, (search) =>
      {
        search.result_set.add_result (result);
      });

      bool got_activate_signal = false;
      scope.activate_uri.connect ((obj, uri/*, hints*/) =>
      {
        got_activate_signal = true;
        assert (uri == ACTIVATE_TEST_URI);
        return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
      });

      ActivationReplyRaw? activation_reply =
        ScopeTester.activate_result (proxy, channel_id, result);

      assert (activation_reply != null);
      assert (activation_reply.handled == Unity.HandledType.NOT_HANDLED);
      assert (got_activate_signal == true);
    }

    public void test_scope_filters ()
    {
      SignalWrapper[] signals = {};
      // we need channel first
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      bool got_search_signal = false;
      signals += new SignalWrapper (scope, scope.search.connect ((search) =>
      {
        got_search_signal = true;

        var filter = search.search_context.filter_state.get_filter_by_id ("check-options") as Unity.OptionsFilter;
        assert (filter.get_option ("option1").active == false);
        assert (filter.get_option ("option2").active == true);
        assert (filter.get_option ("option3").active == false);
      }));

      var state = new HashTable<string, Variant> (str_hash, str_equal);
      var filter = create_filter () as Unity.OptionsFilter;
      filter.get_option ("option2").active = true;
      state[Unity.Internal.SEARCH_FILTER_ROW_HINT] = filter.serialize ();
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", state);

      assert (reply_dict != null);
      assert (got_search_signal);
    }

    public void test_scope_form_factor ()
    {
      // we need channel first
      var channel_id = open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      string form_factor = null;

      // form_factor is taken from the hints dictionary
      var hints = new HashTable<string, Variant?> (str_hash, str_equal);
      hints["form-factor"] = new Variant.string ("phone");
      ScopeTester.perform_search (proxy, channel_id, "", hints,
                                  null, scope, (search) =>
      {
        form_factor = search.search_metadata.form_factor;
      });
      assert (form_factor == "phone");
    }

    public void test_scope_results_invalidated ()
    {
      var ml = new MainLoop ();
      bool got_signal = false;
      ChannelType channel_type = 0;
      proxy.results_invalidated.connect ((type) =>
        {
          got_signal = true;
          channel_type = type;
          ml.quit ();
        });
      scope.results_invalidated (Unity.SearchType.GLOBAL);

      // Ensure that the test does not hang
      assert (run_with_timeout (ml));
      assert (got_signal = true);
      assert (channel_type == ChannelType.GLOBAL);
    }
  }

  class SimpleScopeTester: Object, Fixture
  {
    private Unity.SimpleScope simple;
    private Unity.ScopeDBusConnector connector;
    private Dee.SerializableModel model;
    private ScopeProxy proxy;
    private string channel_id;

    private void setup ()
    {
      simple = new Unity.SimpleScope ();
      simple.group_name = DBUS_NAME;
      simple.unique_name = DBUS_PATH;

      var category_set = new Unity.CategorySet ();
      category_set.add (new Unity.Category ("cat1", "Category 1",
                                            new ThemedIcon ("unknown")));
      simple.category_set = category_set;
      // no filters, no schema

      connector = new Unity.ScopeDBusConnector (simple);
      try
      {
        connector.export ();
      }
      catch (Error err) { assert_not_reached (); }
      assert (ScopeInitTester.acquire_names ());

      proxy = ScopeInitTester.acquire_test_proxy ();
      assert (proxy != null);
    }

    private void teardown ()
    {
      // this will ensure race-free destruction
      ScopeTester.wait_for_synchronization (model);
      ScopeTester.close_channel (proxy, channel_id);
      ensure_destruction ((owned) proxy);
      connector.unexport ();
      ensure_destruction ((owned) connector);
      ensure_destruction ((owned) simple);
    }

    public HashTable<string, Variant> perform_search (string search_query,
                                                      ChannelFlags flags = 0)
    {
      // we need a channel
      if (channel_id == null)
      {
        channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                               out model, false, flags);
        assert (channel_id != null);
      }

      return ScopeTester.perform_search (proxy, channel_id, search_query,
                                         null, model);
    }

    public void test_simple_search ()
    {
      int search_invoked = 0;
      // invoked in separate thread
      simple.set_search_func ((search) =>
      {
        search_invoked++;

        Unity.ScopeResult result = Unity.ScopeResult ();
        result.uri = "test:uri";
        result.icon_hint = "";
        result.category = 0;
        result.result_type = Unity.ResultType.DEFAULT;
        result.mimetype = "inode/folder";
        result.title = "Title";
        result.comment = "";
        result.dnd_uri = "test::uri";
        result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
        search.search_context.result_set.add_result (result);
      });

      var reply_dict = perform_search ("");
      assert (reply_dict != null);

      assert (search_invoked == 1);
      assert (model.get_n_rows () == 1);
      var iter = model.get_first_iter ();
      assert (model.get_string (iter, 0) == "test:uri");
    }

    public void test_simple_search_async ()
    {
      int search_invoked = 0;
      bool search_func_called = false;
      simple.set_search_async_func ((search, cb) =>
      {
        search_invoked++;

        Unity.ScopeResult result = Unity.ScopeResult ();
        result.uri = "test:uri";
        result.icon_hint = "";
        result.category = 0;
        result.result_type = Unity.ResultType.DEFAULT;
        result.mimetype = "inode/folder";
        result.title = "Title";
        result.comment = "";
        result.dnd_uri = "test::uri";
        result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
        search.search_context.result_set.add_result (result);

        Idle.add (() => { cb (search); return false; });
      });
      // shouldn't get called
      simple.set_search_func (() => { search_func_called = true; });

      var reply_dict = perform_search ("");
      assert (reply_dict != null);

      assert (search_invoked == 1);
      // by overriding run_async, run will not be called by default
      assert (search_func_called == false);

      assert (model.get_n_rows () == 1);
      var iter = model.get_first_iter ();
      assert (model.get_string (iter, 0) == "test:uri");
    }

    public void test_simple_search_with_flush ()
    {
      int search_invoked = 0;
      // invoked in separate thread
      simple.set_search_func ((search) =>
      {
        search_invoked++;

        for (int i = 0; i <= 1; i++)
        {
          add_search_result (search, i);
          search.search_context.result_set.flush ();
        }
      });

      var reply_dict = perform_search ("");
      assert (reply_dict != null);

      assert (search_invoked == 1);
      assert (model.get_n_rows () == 2);
      var iter = model.get_first_iter ();
      assert (model.get_string (iter, 0) == "test:uri");
    }

    public static void add_search_result (Unity.ScopeSearchBase search, int state = 0)
    {
      Unity.ScopeResult result = Unity.ScopeResult ();
      switch (state)
      {
        case 0:
          result.uri = "test:uri";
          result.icon_hint = "";
          result.category = 0;
          result.result_type = Unity.ResultType.DEFAULT;
          result.mimetype = "inode/folder";
          result.title = "Title";
          result.comment = "";
          result.dnd_uri = "test::uri";
          result.metadata = null;
          search.search_context.result_set.add_result (result);
          break;
        case 1:
          result.uri = "test:uri2";
          result.icon_hint = "";
          result.category = 0;
          result.result_type = Unity.ResultType.DEFAULT;
          result.mimetype = "inode/folder";
          result.title = "Title";
          result.comment = "";
          result.dnd_uri = "test::uri";
          result.metadata = null;
          search.search_context.result_set.add_result (result);
          break;
        default: break;
      }
    }

    public void test_simple_diff_search ()
    {
      int search_state = 1;
      simple.set_search_func ((search) =>
      {
        add_search_result (search, 0);
        if (search_state == 1)
          add_search_result (search, 1);
      });

      var reply_dict = perform_search ("foo", ChannelFlags.DIFF_CHANGES);
      assert (reply_dict != null);
      assert (model.get_n_rows () == 2);

      int rows_added = 0;
      int rows_removed = 0;
      model.row_added.connect (() => { rows_added++; });
      model.row_removed.connect (() => { rows_removed++; });

      // check that the diff models work
      search_state = 0;
      reply_dict = perform_search ("qoo", ChannelFlags.DIFF_CHANGES);
      assert (model.get_n_rows () == 1);
      assert (rows_added == 0);
      assert (rows_removed == 1);
    }

    public void test_simple_no_diff_search ()
    {
      int search_state = 1;
      simple.set_search_func ((search) =>
      {
        add_search_result (search, 0);
        if (search_state == 1)
          add_search_result (search, 1);
      });

      var reply_dict = perform_search ("foo");
      assert (reply_dict != null);
      assert (model.get_n_rows () == 2);

      int rows_added = 0;
      int rows_removed = 0;
      model.row_added.connect (() => { rows_added++; });
      model.row_removed.connect (() => { rows_removed++; });

      // check that the regular model just removes everything, and re-adds
      search_state = 0;
      reply_dict = perform_search ("qoo");
      assert (model.get_n_rows () == 1);
      assert (rows_added == 1);
      assert (rows_removed == 2);
    }

    public void test_simple_activation ()
    {
      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = ACTIVATE_TEST_URI;
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "file:///";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);

      bool got_activate_signal = false;
      simple.set_activate_func ((act_result, metadata, action_id) =>
      {
        assert (action_id == null);
        assert (act_result.uri == ACTIVATE_TEST_URI);

        got_activate_signal = true;
        return new Unity.ActivationResponse (Unity.HandledType.SHOW_DASH);
      });

      channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                             out model, false);
      assert (channel_id != null);
      ActivationReplyRaw? activation_reply = 
        ScopeTester.activate_result (proxy, channel_id, result);

      assert (activation_reply != null);
      assert (activation_reply.handled == Unity.HandledType.SHOW_DASH);
      assert (got_activate_signal == true);
    }

    public void test_simple_preview ()
    {
      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = "test:uri";
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "test:uri";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);

      int preview_invoked = 0;

      simple.set_preview_func ((previewer) =>
      {
        assert (previewer.result.uri == "test:uri");
        preview_invoked++;
        return new Unity.GenericPreview ("test:uri", "subtitle", null);
      });

      channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                             out model, false);
      assert (channel_id != null);
      var reply_dict = ScopeTester.preview_result (proxy, channel_id, result);
      assert (reply_dict != null);
      assert (preview_invoked == 1);
      var preview_v = reply_dict["preview"];
      assert (preview_v != null);

      var reconstructed = Unity.Protocol.Preview.parse (preview_v);
      assert (reconstructed.title == "test:uri");
    }

    public void test_simple_preview_async ()
    {
      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = "test:uri";
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "test:uri";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);

      int preview_invoked = 0;
      bool preview_func_called = false;

      simple.set_preview_async_func ((previewer, cb) =>
      {
        assert (previewer.result.uri == "test:uri");
        preview_invoked++;
        var preview = new Unity.GenericPreview ("test:uri", "subtitle", null);
        Idle.add (() =>
        {
          cb (previewer, preview);
          return false;
        });
      });
      // shouldn't get called
      simple.set_preview_func (() =>
      {
        preview_func_called = true;
        return null;
      });

      channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                             out model, false);
      assert (channel_id != null);
      var reply_dict = ScopeTester.preview_result (proxy, channel_id, result);
      assert (reply_dict != null);
      assert (preview_invoked == 1);
      // by overriding run_async, run will not be called by default
      assert (preview_func_called == false);
      var preview_v = reply_dict["preview"];
      assert (preview_v != null);

      var reconstructed = Unity.Protocol.Preview.parse (preview_v);
      assert (reconstructed.title == "test:uri");
    }
  }

  class MasterScopeTester: Object, Fixture
  {
    class ChildScope: Unity.SimpleScope
    {
      public string scope_id { get; construct set; }

      public ChildScope (string dbus_path, string id)
      {
        Object (unique_name: dbus_path, scope_id: id, group_name: DBUS_NAME);
      }

      protected override void constructed ()
      {
        base.constructed ();

        var schema = new Unity.Schema ();
        schema.add_field ("required_string", "s", Unity.Schema.FieldType.REQUIRED);
        schema.add_field ("required_int", "i", Unity.Schema.FieldType.REQUIRED);
        schema.add_field ("optional_string", "s", Unity.Schema.FieldType.OPTIONAL);
        this.schema = schema;
        
        var cats = new Unity.CategorySet ();
        var cat1 = new Unity.Category ("1211", "A Category", new GLib.ThemedIcon ("text"));
        cat1.add_metadata_provider (new Unity.ProgressSourceProvider ("a1", "a2"));
        cats.add (cat1);
        var cat2 = new Unity.Category ("1991", "Unused category", new GLib.ThemedIcon ("text"));
        cat2.add_metadata_provider (new Unity.ProgressSourceProvider ("b1", "b2"));
        cats.add (cat2);
        this.category_set = cats;

        this.set_search_async_func ((search, cb) =>
        {
          perform_search (search.search_context);
          // simulate a bit of asynchronicity
          Idle.add (() => { cb (search); return false; });
        });
      }

      public signal void perform_search (Unity.SearchContext? search);
    }

    private uint owning_id;
    private Unity.MasterScope master_scope;
    private ScopeProxy proxy;
    private ChildScope[] child_scopes = {};
    private Unity.ScopeDBusConnector[] connectors = {};
    private Rand random = new Rand ();
    private uint results_per_scope = 1;
    private int random_range_end = 1000000000;
    private bool randomize_categories = false;

    private string[] child_searches = {};
    private int search_handler_invocations
    {
      get
      {
        return child_searches.length;
      }
    }
    private string[] active_filters = {};

    private void child_search_handler (ChildScope scope,
                                       Unity.SearchContext? search)
    {
      child_searches += scope.scope_id;

      var filter = search.filter_state.get_filter_by_id ("check-options");
      if (filter != null)
      {
          foreach (var opt in (filter as Unity.CheckOptionFilter).options)
          {
              if (opt.active == true)
                  active_filters += opt.id;
          }
      }

      var uri = "file:///" + scope.scope_id;
      for (uint i = 0; i < results_per_scope; i++)
      {
        uint category_index = 0;
        if (randomize_categories) category_index = random.boolean () ? 1 : 0;
        var rand_int = random.int_range (0, random_range_end);
        Unity.ScopeResult result = Unity.ScopeResult ();
        if (random.boolean ())
        {
          result.uri = uri;
          result.icon_hint = "";
          result.category = category_index;
          result.result_type = Unity.ResultType.DEFAULT;
          result.mimetype = "inode/folder";
          result.title = "Title";
          result.comment = scope.scope_id;
          result.dnd_uri = "file:///";
          result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
          result.metadata["required_int"] = rand_int;
          result.metadata["required_string"] = "qoo";
        }
        else
        {
          var opt_field = random.next_int ().to_string ();
          result.uri = uri;
          result.icon_hint = "";
          result.category = category_index;
          result.result_type = Unity.ResultType.DEFAULT;
          result.mimetype = "inode/folder";
          result.title = "Title";
          result.comment = scope.scope_id;
          result.dnd_uri = "file:///";
          result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
          result.metadata["required_int"] = rand_int;
          result.metadata["required_string"] = "qoo";
          result.metadata["optional_string"] = opt_field;
        }
        search.result_set.add_result (result);
      }
    }

    public static uint own_bus_name (string name = DBUS_NAME)
    {
      bool dbus_name_owned = false;
      uint owning_id;
      var ml = new MainLoop ();
      // register us a name on the bus
      owning_id = Bus.own_name (BusType.SESSION, name, 0,
                                () => {},
                                () => { dbus_name_owned = true; ml.quit (); },
                                () => { ml.quit (); });
      ml.run ();
      assert (dbus_name_owned == true);
      return owning_id;
    }

    private void setup ()
    {
      owning_id = own_bus_name ();
      master_scope = new Unity.MasterScope (MASTER_SCOPE_DBUS_PATH,
                                            "test_masterscope.scope");
      master_scope.search_hint = "Master search hint";
      var schema = new Unity.Schema ();
      schema.add_field ("required_string", "s", Unity.Schema.FieldType.REQUIRED);
      schema.add_field ("required_int", "i", Unity.Schema.FieldType.REQUIRED);
      schema.add_field ("optional_string", "s", Unity.Schema.FieldType.OPTIONAL);
      master_scope.schema = schema;

      var filters = new Unity.FilterSet ();
      filters.add (ScopeTester.create_filter ());
      master_scope.filters = filters;

      var cats = new Unity.CategorySet ();
      cats.add (new Unity.Category ("1991", "Unused category", new GLib.ThemedIcon ("text")));
      cats.add (new Unity.Category ("1211", "A Category", new GLib.ThemedIcon ("text")));
      master_scope.categories = cats;
 
      try
      {
        master_scope.export ();

        // init child scopes
        ChildScope child_scope;
        child_scope = new ChildScope ("/com/canonical/unity/scope/childscope_1",
                                      "test_masterscope-childscope_1.scope");
        child_scope.filter_set = filters; // set filters for one child scope
        child_scope.perform_search.connect (child_search_handler);
        connectors += new Unity.ScopeDBusConnector (child_scope);
        connectors[connectors.length-1].export ();
        child_scopes += child_scope;

        child_scope = new ChildScope ("/com/canonical/unity/scope/childscope_2",
                                      "test_masterscope-childscope_2.scope");
        child_scope.perform_search.connect (child_search_handler);
        connectors += new Unity.ScopeDBusConnector (child_scope);
        connectors[connectors.length-1].export ();
        child_scopes += child_scope;

        // this one has GlobalSearches=false
        child_scope = new ChildScope ("/com/canonical/unity/scope/childscope_3",
                                      "test_masterscope-childscope_3.scope");
        child_scope.perform_search.connect (child_search_handler);
        connectors += new Unity.ScopeDBusConnector (child_scope);
        connectors[connectors.length-1].export ();
        child_scopes += child_scope;
      }
      catch (Error err) { assert_not_reached (); }

      proxy = ScopeInitTester.acquire_test_proxy (MASTER_SCOPE_DBUS_PATH);
      assert (proxy != null);
    }

    private void teardown ()
    {
      ensure_destruction ((owned) proxy);
      master_scope.unexport ();
      ensure_destruction ((owned) master_scope);
      foreach (var connector in connectors) connector.unexport ();
      connectors = {};
      child_scopes = {};
      if (owning_id != 0) Bus.unown_name (owning_id);
    }

    public void test_master_open_channel ()
    {
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);
    }

    public void test_master_open_close_channel ()
    {
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);
      ScopeTester.close_channel (proxy, channel_id);
    }

    public void test_master_search ()
    {
      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);

      assert (search_handler_invocations == child_scopes.length);
      assert (reply_dict != null);
      assert (model.get_n_rows () > 0);
    }

    public void test_master_multi_search ()
    {
      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                                   null, model);

      assert (search_handler_invocations == child_scopes.length);
      assert (reply_dict != null);
      assert (model.get_n_rows () > 0);

      // perform the same search, should be optimized to not query the scopes
      // again
      reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                               null, model);

      assert (search_handler_invocations == child_scopes.length);

      child_scopes[0].results_invalidated (Unity.SearchType.DEFAULT);

      // and one more time but this time one scope should be queried
      reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                               null, model);

      assert (search_handler_invocations == child_scopes.length + 1);
    }

    public void test_master_global_search ()
    {
      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.GLOBAL,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                                   null, model);

      assert (!("test_masterscope-childscope_3.scope" in child_searches));
      assert (search_handler_invocations == child_scopes.length - 1);
      assert (reply_dict != null);
      assert (model.get_n_rows () > 0);
    }

    public void test_master_no_content ()
    {
      const string MSG = "There's no content...";
      const string HINT = Unity.Internal.SEARCH_NO_RESULTS_HINT;

      master_scope.no_content_hint = MSG;
      results_per_scope = 0;

      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);

      assert (search_handler_invocations == child_scopes.length);
      assert (reply_dict != null);
      assert (HINT in reply_dict);
      assert (reply_dict[HINT].get_string () == MSG);
    }

    public void test_master_results_invalidated ()
    {
      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);

      var ml = new MainLoop ();
      bool master_results_invalidated = false;
      ChannelType channel_type = ChannelType.GLOBAL;
      proxy.results_invalidated.connect ((type) =>
      {
        master_results_invalidated = true;
        channel_type = type;
        ml.quit ();
      });

      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (search_handler_invocations == child_scopes.length);
      assert (reply_dict != null);

      child_scopes[1].results_invalidated (Unity.SearchType.DEFAULT);

      assert (run_with_timeout (ml));
      assert (master_results_invalidated == true);
      assert (channel_type == ChannelType.DEFAULT);

      // repeat the search again and see if the scope search is performed
      // on the invalidated scope
      reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (search_handler_invocations == child_scopes.length + 1);
      assert (reply_dict != null);
    }

    public void test_master_multiple_channels ()
    {
      // we need channel first
      Dee.SerializableModel model1;
      var channel_id1 = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                  out model1);
      assert (channel_id1 != null);

      Dee.SerializableModel model2;
      var channel_id2 = ScopeTester.open_channel (proxy, ChannelType.GLOBAL,
                                                  out model2);
      assert (channel_id2 != null);

      var reply_dict = ScopeTester.perform_search (proxy, channel_id1, "foo",
                                                   null, model1);

      assert ("test_masterscope-childscope_3.scope" in child_searches);
      assert (search_handler_invocations == child_scopes.length);
      assert (reply_dict != null);
      assert (model1.get_n_rows () > 0);

      child_searches = {}; // resets search_handler_invocations
      reply_dict = ScopeTester.perform_search (proxy, channel_id2, "foo",
                                               null, model2);

      // test_masterscope-childscope_3.scope shouldn't perform GlobalSearches
      assert (!("test_masterscope-childscope_3.scope" in child_searches));
      assert (search_handler_invocations == child_scopes.length - 1);
      assert (reply_dict != null);
      assert (model2.get_n_rows () > 0);
    }

    public void test_master_search_multiple_channels ()
    {
      // we need channel first
      Dee.SerializableModel model1;
      var channel_id1 = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                  out model1);
      assert (channel_id1 != null);

      var reply_dict = ScopeTester.perform_search (proxy, channel_id1, "foo",
                                                   null, model1);
      assert (reply_dict != null);
      assert (search_handler_invocations == child_scopes.length);

      child_searches = {}; // resets search_handler_invocations

      Dee.SerializableModel model2;
      var channel_id2 = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                  out model2);
      assert (channel_id2 != null);

      reply_dict = ScopeTester.perform_search (proxy, channel_id2, "foo",
                                               null, model2);
      assert (reply_dict != null);
      assert (search_handler_invocations == child_scopes.length);

      assert (model1.get_n_rows () == model2.get_n_rows ());
    }

    public void test_master_activation ()
    {
      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (model.get_n_rows () == 3);

      // NOTE: the order of the results is not defined, so result1 will not
      // necesarily belong to child_scopes[0]
      var iter = model.get_first_iter ();
      var result1 = model.get_row (iter, null);
      iter = model.next (iter);
      var result2 = model.get_row (iter, null);
      iter = model.next (iter);
      var result3 = model.get_row (iter, null);

      string[] activated_scopes = {};

      child_scopes[0].set_activate_func ((result, metadata, action_id) =>
      {
        var uri = result.uri;
        assert (uri.has_prefix ("file:///") && "childscope_1" in uri);
        activated_scopes += "childscope_1";
        return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
      });

      child_scopes[1].set_activate_func ((result, metadata, action_id) =>
      {
        var uri = result.uri;
        assert (uri.has_prefix ("file:///") && "childscope_2" in uri);
        activated_scopes += "childscope_2";
        return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
      });

      child_scopes[2].set_activate_func ((result, metadata, action_id) =>
      {
        var uri = result.uri;
        assert (uri.has_prefix ("file:///") && "childscope_3" in uri);
        activated_scopes += "childscope_3";
        return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED);
      });

      var ml = new MainLoop ();
      proxy.activate.begin (channel_id, result1,
                            Unity.Protocol.ActionType.ACTIVATE_RESULT,
                            new HashTable<string, Variant> (null, null), null,
                            (obj, res) =>
      {
        ml.quit ();
      });
      assert (run_with_timeout (ml));

      // one of the scope should have received the signal
      assert (activated_scopes.length == 1);

      // activate the second scope
      ml = new MainLoop ();
      proxy.activate.begin (channel_id, result2,
                            Unity.Protocol.ActionType.ACTIVATE_RESULT,
                            new HashTable<string, Variant> (null, null), null,
                            (obj, res) =>
      {
        ml.quit ();
      });
      assert (run_with_timeout (ml));
      assert (activated_scopes.length == 2);

      // and the third one
      ml = new MainLoop ();
      proxy.activate.begin (channel_id, result3,
                            Unity.Protocol.ActionType.ACTIVATE_RESULT,
                            new HashTable<string, Variant> (null, null), null,
                            (obj, res) =>
      {
        ml.quit ();
      });
      assert (run_with_timeout (ml));
      assert (activated_scopes.length == 3);
    }

    public void test_master_overridden_goto_uri ()
    {
      // we need channel first
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (model.get_n_rows () == 3);

      // NOTE: the order of the results is not defined, so result1 will not
      // necesarily belong to child_scopes[0]
      var iter = model.get_first_iter ();
      var result = model.get_row (iter, null);
      var uri = result[Unity.Internal.ResultColumn.URI].get_string ();
      int scope_index = "childscope_1" in uri ? 0 : ("childscope_2" in uri ? 1 : 2);
      child_scopes[scope_index].set_activate_func((result, metadata, act_id) =>
      {
        return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED,
                                             "test://overridden_uri");
      });

      var ml = new MainLoop ();
      ActivationReplyRaw? reply = null;
      proxy.activate.begin (channel_id, result,
                            Unity.Protocol.ActionType.ACTIVATE_RESULT,
                            new HashTable<string, Variant> (null, null), null,
                            (obj, res) =>
      {
        try
        {
          reply = proxy.activate.end (res);
        }
        catch (Error err) { assert_not_reached (); }
        ml.quit ();
      });
      assert (run_with_timeout (ml));

      assert (reply != null);
      assert (reply.uri == "test://overridden_uri");
    }

    public void test_master_sorting_asc ()
    {
      results_per_scope = 100;
      master_scope.add_sorter (1, "required_int", Unity.AggregatorScope.SortFlags.ASCENDING);
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);
      assert (model.get_n_rows () > 0);

      // only results with one cat were added, check the monotonicity
      bool is_monotonic = true;
      int last_val = int.MIN;
      var iter = model.get_first_iter ();
      var end_iter = model.get_last_iter ();
      while (iter != end_iter)
      {
        var primary_dict = model.get_value (iter, Unity.Internal.ResultColumn.METADATA);
        var content = primary_dict.lookup_value ("content", VariantType.VARDICT);
        int val = content.lookup_value ("required_int", VariantType.INT32).get_int32 ();
        is_monotonic &= val >= last_val;
        last_val = val;
        iter = model.next (iter);
      }

      assert (is_monotonic);
    }

    public void test_master_sorting_desc ()
    {
      results_per_scope = 100;
      master_scope.add_sorter (1, "required_int", Unity.AggregatorScope.SortFlags.DESCENDING);
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);
      assert (model.get_n_rows () > 0);

      // only results with one cat were added, check the monotonicity
      bool is_monotonic = true;
      int last_val = int.MAX;
      var iter = model.get_first_iter ();
      var end_iter = model.get_last_iter ();
      while (iter != end_iter)
      {
        var primary_dict = model.get_value (iter, Unity.Internal.ResultColumn.METADATA);
        var content = primary_dict.lookup_value ("content", VariantType.VARDICT);
        int val = content.lookup_value ("required_int", VariantType.INT32).get_int32 ();
        is_monotonic &= val <= last_val;
        last_val = val;
        iter = model.next (iter);
      }

      assert (is_monotonic);
    }

    public void test_master_sorting_optional_asc ()
    {
      results_per_scope = 100;
      master_scope.add_sorter (1, "optional_string", Unity.AggregatorScope.SortFlags.ASCENDING);
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);

      assert (search_handler_invocations == child_scopes.length);
      assert (model.get_n_rows () > 0);

      // only results with one cat were added, check the monotonicity
      bool is_monotonic = true;
      var iter = model.get_first_iter ();
      var end_iter = model.get_last_iter ();
      // this would spit a critical if first result didn't have the field
      var last_val = model.get_value (iter, Unity.Internal.ResultColumn.METADATA).lookup_value ("content", VariantType.VARDICT).lookup_value ("optional_string", null).get_string ();
      iter = model.next (iter);
      while (iter != end_iter)
      {
        var primary_dict = model.get_value (iter, Unity.Internal.ResultColumn.METADATA);
        var content = primary_dict.lookup_value ("content", VariantType.VARDICT);
        var opt_variant = content.lookup_value ("optional_string", null);
        unowned string val = opt_variant != null ? opt_variant.get_string () : null;
        is_monotonic &= val == null || strcmp (val, last_val) >= 0;
        last_val = val;
        iter = model.next (iter);
      }

      assert (is_monotonic);
    }

    public void test_master_sorting_optional_desc ()
    {
      results_per_scope = 100;
      master_scope.add_sorter (1, "optional_string", Unity.AggregatorScope.SortFlags.DESCENDING);
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);

      assert (search_handler_invocations == child_scopes.length);
      assert (model.get_n_rows () > 0);

      // only results with one cat were added, check the monotonicity
      bool is_monotonic = true;
      var iter = model.get_first_iter ();
      var end_iter = model.get_last_iter ();
      // this would spit a critical if first result didn't have the field
      var last_val = model.get_value (iter, Unity.Internal.ResultColumn.METADATA).lookup_value ("content", VariantType.VARDICT).lookup_value ("optional_string", null).get_string ();
      iter = model.next (iter);
      while (iter != end_iter)
      {
        var primary_dict = model.get_value (iter, Unity.Internal.ResultColumn.METADATA);
        var content = primary_dict.lookup_value ("content", VariantType.VARDICT);
        var opt_variant = content.lookup_value ("optional_string", null);
        unowned string val = opt_variant != null ? opt_variant.get_string () : null;
        is_monotonic &= val == null || strcmp (val, last_val) <= 0;
        last_val = val;
        iter = model.next (iter);
      }

      assert (is_monotonic);
    }

    public void test_master_deduplication ()
    {
      results_per_scope = 100;
      random_range_end = 2;
      master_scope.add_constraint (-1, "required_int");
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);

      assert (search_handler_invocations == child_scopes.length);
      // constraining to only unique values of "required_int" and there are
      // only two of those, even though we tried to add 200 results
      assert (model.get_n_rows () == 2);
    }

    public void test_master_deduplication_per_category ()
    {
      results_per_scope = 100;
      random_range_end = 2;
      randomize_categories = true;

      master_scope.add_constraint (0, "required_int");
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);

      assert (search_handler_invocations == child_scopes.length);
      var counts = new HashTable<uint, uint> (direct_hash, direct_equal);
      var iter = model.get_first_iter ();
      var end_iter = model.get_last_iter ();
      while (iter != end_iter)
      {
        var category = model.get_uint32 (iter, Unity.Internal.ResultColumn.CATEGORY);
        counts[category] = counts[category] + 1;
        iter = model.next (iter);
      }

      // category 0 should have just 2 results (all other are dupes)
      // category 1 should have ~100 (depending on random generator)
      assert (counts[0] == 2);
      assert (counts[1] > 2);
    }

    public void test_master_filters ()
    {
      var expected_error = new ErrorHandler ();
      expected_error.ignore_message ("libunity", LogLevelFlags.LEVEL_WARNING);
      // initialize channel
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT,
                                                 out model);
      assert (channel_id != null);

      var state = new HashTable<string, Variant> (str_hash, str_equal);
      var filter = ScopeTester.create_filter () as Unity.OptionsFilter;
      filter.get_option ("option2").active = true;
      state["changed-filter-row"] = filter.serialize ();
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", state, model);

      assert (reply_dict != null);
      // at least one scope should ignore the search
      assert (search_handler_invocations < child_scopes.length);
      assert (model.get_n_rows () > 0);
      assert (active_filters.length == 1);
      assert (active_filters[0] == "option2");
    }

    public void test_subscopes_filter_hint ()
    {
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, out model);
      assert (channel_id != null);

      var hints = new HashTable<string, Variant> (str_hash, str_equal);
      string[] subscopes = {"test_masterscope-childscope_1.scope"};
      hints [Unity.Internal.SEARCH_SUBSCOPES_HINT] = new GLib.Variant.strv (subscopes);

      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", hints, model);
      assert (reply_dict != null);

      assert (search_handler_invocations == 1);
      assert (child_searches[0] =="test_masterscope-childscope_1.scope");
    }

    public void test_push_results ()
    {
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, out model);
      assert (channel_id != null);

      var pushed_model = new Dee.SequenceModel ();
      pushed_model.set_schema ("s", "s", "u", "u", "s", "s", "s", "s", "a{sv}");
      var metadata = new HashTable<string, Variant> (str_hash, str_equal);
      metadata["required_int"] = new Variant.int32 (6);
      metadata["required_string"] = new Variant.string ("qoo");
      Variant metadata_var = metadata;
      pushed_model.append ("remote:foo", "", 0, 0, "text/plain", "Title", "",
                           "file:///", metadata_var);

      var reply_dict = ScopeTester.push_results (proxy, channel_id, "foo", "test_masterscope-pushed.scope", pushed_model, {"1211"}, model);

      assert (reply_dict != null);
      assert (model.get_n_rows () == 1);
      var iter = model.get_first_iter ();
      assert (model.get_string (iter, 0) == "remote:foo");
    }

    public void test_push_results_and_search ()
    {
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, out model);
      assert (channel_id != null);

      const string PUSHED_URI = "remote:foo";
      var pushed_model = new Dee.SequenceModel ();
      pushed_model.set_schema ("s", "s", "u", "u", "s", "s", "s", "s", "a{sv}");
      var metadata = new HashTable<string, Variant> (str_hash, str_equal);
      metadata["required_int"] = new Variant.int32 (6);
      metadata["required_string"] = new Variant.string ("qoo");
      Variant metadata_var = metadata;
      pushed_model.append (PUSHED_URI, "", 0, 0, "text/plain", "Title", "",
                           "file:///", metadata_var);

      var reply_dict = ScopeTester.push_results (proxy, channel_id, "foo", "test_masterscope-pushed.scope", pushed_model, {"1211"}, model);

      assert (model.get_n_rows () == 1);
      var iter = model.get_first_iter ();
      assert (model.get_string (iter, 0) == PUSHED_URI);

      // perform a search with the same string as the push
      reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                               new HashTable<string, Variant> (null, null), model);

      assert (reply_dict != null);
      assert (search_handler_invocations == child_scopes.length);
      assert (model.get_n_rows () > 1);

      var pushed_result_found = false;
      iter = model.get_first_iter ();
      var end_iter = model.get_last_iter ();
      while (iter != end_iter)
      {
        if (model.get_string (iter, 0) == PUSHED_URI)
        {
          pushed_result_found = true;
        }
        iter = model.next (iter);
      }
      assert (pushed_result_found);
    }

    public void test_subscopes_search ()
    {
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, out model);
      assert (channel_id != null);

      var hints = new HashTable<string, Variant> (str_hash, str_equal);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                                   hints, model);

      assert (reply_dict != null);
      // standard search, should invoke all subscopes
      assert (search_handler_invocations == child_scopes.length);
      assert (model.get_n_rows () == child_scopes.length);

      string[] subscopes = {"test_masterscope-childscope_1.scope"};
      hints [Unity.Internal.SEARCH_SUBSCOPES_HINT] = new GLib.Variant.strv (subscopes);

      // even though search string didn't change, this shouldn't just serve
      // the last resultset
      reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                               hints, model);

      assert (reply_dict != null);
      assert (model.get_n_rows () == 1);
    }

    public void test_overridden_subscopes ()
    {
      const string MASTER_C_DBUS_NAME = "com.canonical.Unity.Scope.MasterC";
      const string MASTER_C_DBUS_PATH = "/com/canonical/unity/scope/masterc";
      // this master scope will query the one that was prepared in this.setup()
      // which in turn just queries the ChildScopes, so it's one level up from
      // all the other master scope tests
      uint master_own_id = own_bus_name (MASTER_C_DBUS_NAME);
      var master_c = new Unity.MasterScope (MASTER_C_DBUS_PATH,
                                            "masterscope_c.scope");
      master_c.search_hint = "Master search hint";

      var cats = new Unity.CategorySet ();
      cats.add (new Unity.Category ("1991", "Unused category", new GLib.ThemedIcon ("text")));
      cats.add (new Unity.Category ("1211", "A Category", new GLib.ThemedIcon ("text")));
      master_c.categories = cats;
 
      try
      {
        master_c.export ();
      }
      catch (Error err) { assert_not_reached (); }

      var proxy_c = ScopeInitTester.acquire_test_proxy (MASTER_C_DBUS_PATH, MASTER_C_DBUS_NAME);

      // setup finished
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy_c, ChannelType.DEFAULT, out model);
      assert (channel_id != null);

      var hints = new HashTable<string, Variant> (str_hash, str_equal);
      var reply_dict = ScopeTester.perform_search (proxy_c, channel_id, "foo",
                                                   hints, model);

      assert (reply_dict != null);
      // standard search, should invoke all subscopes
      assert (search_handler_invocations == child_scopes.length);
      assert (model.get_n_rows () == child_scopes.length);

      master_c.unexport ();
      if (master_own_id != 0) Bus.unown_name (master_own_id);
    }

    public void test_progress_source_property ()
    {
      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, out model);
      assert (channel_id != null);

      var hints = new HashTable<string, Variant> (str_hash, str_equal);
      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "foo",
                                                   hints, model);

      assert (reply_dict != null);

      assert (proxy.categories_model.get_n_rows () == 2);
      var iter = proxy.categories_model.get_first_iter ();
      var cat_id = proxy.categories_model.get_string (iter, Unity.Internal.CategoryColumn.ID);
      var cat_hints = proxy.categories_model.get_value (iter, Unity.Internal.CategoryColumn.HINTS);
      var psarr = cat_hints.lookup_value ("progress-source", null);

      assert (cat_id == "1991");
      assert (psarr != null);
      assert (psarr.n_children () == 1); // progress-source array contains only one value
      var ps = psarr.get_child_value (0);
      assert (ps.get_string () == "b1:b2");

      iter = proxy.categories_model.next (iter);
      cat_id = proxy.categories_model.get_string (iter, Unity.Internal.CategoryColumn.ID);
      cat_hints = proxy.categories_model.get_value (iter, Unity.Internal.CategoryColumn.HINTS);
      psarr = cat_hints.lookup_value ("progress-source", null);
      
      assert (cat_id == "1211");
      assert (psarr != null);
      assert (psarr.n_children () == 1); // progress-source array contains only one value
      ps = psarr.get_child_value (0);
      assert (ps.get_string () == "a1:a2");
    }
  }

  class AggregatorScopeTester: Object, Fixture
  {
    class AggScope: Unity.AggregatorScope
    {
      public signal Unity.ActivationResponse? activation_response_hook (Unity.AggregatorActivation activation);

      public AggScope (string dbus_path, string id)
      {
        Object (dbus_path: dbus_path, id: id, is_master: true, merge_mode: Unity.AggregatorScope.MergeMode.OWNER_SCOPE);   
      }

      protected override void constructed ()
      {
        base.constructed ();

        search_hint = "Home search hint";

        var fi = new Unity.FilterSet ();
        fi.add (ScopeTester.create_filter ());
        filters = fi;

        var cats = new Unity.CategorySet ();
        cats.add (new Unity.Category ("test_masterscope.scope", "Masterscope 1", new GLib.ThemedIcon ("text")));
        cats.add (new Unity.Category ("test_fooobar.scope", "Masterscope 2", new GLib.ThemedIcon ("text")));
        categories = cats;
      }

      public override int category_index_for_scope_id (string scope_id)
      {
        return 0;
      }

      public override async Unity.ActivationResponse? activate (Unity.AggregatorActivation activation)
      {
        return activation_response_hook (activation);
      }

      public override async void search (Unity.AggregatedScopeSearch scope_search)
      {
        var order = new uint32[] {1,0};
        scope_search.category_order_changed (order);
      }
    }

    private AggScope agg_scope;
    private ScopeProxy proxy;
    private uint owning_id;

    private void setup ()
    {
      owning_id = MasterScopeTester.own_bus_name ();
      // setup Home Scope
      agg_scope = new AggScope (HOME_SCOPE_DBUS_PATH, "test_homescope.scope");
      try
      {
        agg_scope.export ();
      }
      catch (Error err) { assert_not_reached (); }

      proxy = ScopeInitTester.acquire_test_proxy (HOME_SCOPE_DBUS_PATH);
      assert (proxy != null);
    }

    private void teardown ()
    {
      ensure_destruction ((owned) proxy);
      agg_scope.unexport ();
      ensure_destruction ((owned) agg_scope);
      if (owning_id != 0) Bus.unown_name (owning_id);
    }

    public void test_scope_category_order_signal ()
    {
      assert (proxy != null);
      SignalWrapper[] signals = {};
      bool got_order_changed = false;

      signals += new SignalWrapper (proxy, proxy.category_order_changed.connect ((channel, order) =>
      {
        got_order_changed = true;
        assert (order.length == 2);
        assert (order[0] == 1 && order[1] == 0);
      }));

      Dee.SerializableModel model;
      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, out model);
      assert (channel_id != null);
      assert (got_order_changed == false);

      var reply_dict = ScopeTester.perform_search (proxy, channel_id, "", null, model);
      assert (reply_dict != null);
      assert (got_order_changed == true);
    }

    public void test_scope_activation_handler ()
    {
      Unity.AggregatorActivation? got_activate = null;
  
      assert (proxy != null);

      var channel_id = ScopeTester.open_channel (proxy, ChannelType.DEFAULT, null);
      assert (channel_id != null);

      Unity.ScopeResult result = Unity.ScopeResult ();
      result.uri = "file:///foo";
      result.icon_hint = "";
      result.category = 0;
      result.result_type = Unity.ResultType.DEFAULT;
      result.mimetype = "inode/folder";
      result.title = "Title";
      result.comment = "";
      result.dnd_uri = "file:///";
      result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
      result.metadata["scope-id"] = new Variant.string ("foo.scope");
      result.metadata["content"] = new HashTable<string, Variant> (str_hash, str_equal);

      var hints = new HashTable<string, Variant>(str_hash, str_equal);
      hints[Unity.Internal.ACTIVATE_PREVIEW_ACTION_HINT] = new Variant.string ("id1");
      hints["foo"] = new Variant.string ("bar");

      agg_scope.activation_response_hook.connect ((aggactivation) => {
          got_activate = aggactivation;
          return new Unity.ActivationResponse (Unity.HandledType.NOT_HANDLED, "http://ubuntu.com");
      });

      ActivationReplyRaw? activation_reply = ScopeTester.activate (proxy, channel_id, Unity.Protocol.ActionType.PREVIEW_ACTION, result, hints);

      assert (got_activate != null);
      assert (activation_reply != null);
      assert (activation_reply.handled == Unity.HandledType.NOT_HANDLED);
      assert (activation_reply.uri == "http://ubuntu.com");
      assert (got_activate.channel_id == channel_id);
      assert (got_activate.hints != null);
      assert (got_activate.hints[Unity.Internal.ACTIVATE_PREVIEW_ACTION_HINT].get_string () == "id1");
      assert (got_activate.hints["foo"].get_string () == "bar");
    }
  }

  class TestScopeLoader: Unity.ScopeLoader
  {
    public List<string> requested_modules;

    public override List<Unity.AbstractScope> get_scopes (string module, string? module_type) throws Error
    {
      requested_modules.append(module);
      return new List<Unity.AbstractScope> ();
    }
  }

  class ScopeLoaderTester: Object, Fixture
  {
    public void test_load_scope ()
    {
      var loader = new TestScopeLoader ();
      try
      {
        loader.load_scope ("test_masterscope/childscope_1.scope");
      }
      catch (Error err) { assert_not_reached (); }
      assert (loader.requested_modules != null);
      assert (loader.requested_modules.data == "childscope_1.so");
    }

    public void test_load_group ()
    {
      var loader = new TestScopeLoader ();
      var file_name = Config.TESTDIR + "/data/test-group.group";
      try
      {
        loader.load_group (file_name);
      }
      catch (Error err) { assert_not_reached (); }

      assert (loader.requested_modules.data == "childscope_1.so");
      assert (loader.requested_modules.next.data == "childscope_2.so");
      assert (loader.requested_modules.next.next.data == "childscope_3.so");
    }

    public void test_load_module ()
    {
      var loader = new TestScopeLoader ();
      try
      {
        loader.load_module ("foo.so", "type");
      }
      catch (Error err) { assert_not_reached (); }
      assert (loader.requested_modules != null);
      assert (loader.requested_modules.data == "foo.so");
    }
  }

}
