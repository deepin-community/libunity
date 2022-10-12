/*
 * Copyright (C) 2012 Canonical Ltd
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
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */
using Unity;

// a small hack for a bunch of internal protolib functions, that are useful
public extern void unity_protocol_scope_registry_scope_metadata_update_hidden_scope_ids ();
public extern void unity_protocol_scope_registry_init_scope_directories ();
public extern void unity_protocol_scope_registry_init_scope_file_prefixes ();

namespace Unity.Test
{
  public class ScopeDiscoveryTestSuite
  {
    public static const string SCOPES_ROOT = Config.TESTDIR + "/data/unity/scopes";
    const string PROTO_DOMAIN = "libunity-protocol-private";

    const int NUM_TOP_LEVEL_TEST_SCOPES = 4;

    public ScopeDiscoveryTestSuite ()
    {
      GLib.Environment.set_variable ("XDG_DATA_DIRS", Config.TESTDIR + "/data", true);
      GLib.Environment.set_variable ("LIBUNITY_SCOPE_DIRECTORIES", Config.TESTDIR + "/data/unity/scopes", true);

      GLib.Test.add_data_func ("/Unit/ScopeMetadata/LoadScopeById", ScopeDiscoveryTestSuite.test_metadata_load_by_scope_id);
      GLib.Test.add_data_func ("/Unit/ScopeMetadata/LoadMasterscope", ScopeDiscoveryTestSuite.test_metadata_load_masterscope);
      GLib.Test.add_data_func ("/Unit/ScopeDiscovery/FindScopes", ScopeDiscoveryTestSuite.test_find_all_scopes);
      GLib.Test.add_data_func ("/Unit/ScopeDiscovery/FindScopesInXdg", ScopeDiscoveryTestSuite.test_find_all_scopes_xdg);
      GLib.Test.add_data_func ("/Unit/ScopeDiscovery/FindScopesWithHidden", ScopeDiscoveryTestSuite.test_find_all_scopes_with_hidden_scopes);
      GLib.Test.add_data_func ("/Unit/ScopeDiscovery/FindSpecificScopes", ScopeDiscoveryTestSuite.test_find_specific_scope);
      GLib.Test.add_data_func ("/Unit/ScopeDiscovery/FindScopeById", ScopeDiscoveryTestSuite.test_find_scope_by_id);
      GLib.Test.add_data_func ("/Unit/ScopeDiscovery/FindOverriddenScopeById", ScopeDiscoveryTestSuite.test_find_overridden_scope_by_id);
    }

    internal static void check_scope_b_subscopes (Protocol.ScopeRegistry.ScopeRegistryNode node)
    {
      bool got_subscope1 = false;
      bool got_subscope2 = false;

      assert (node.sub_scopes != null);
      assert (node.sub_scopes.length () == 2);

      foreach (var subscope in node.sub_scopes)
      {
        if (subscope.name == "Sample subscope 1")
        {
          got_subscope1 = true;
          assert (subscope.id == "masterscope_b-subscope1.scope");
          assert (subscope.dbus_name == "com.canonical.Unity.Scope.Subscope1");
          assert (subscope.dbus_path == "/com/canonical/unity/scope/subscope1");
          assert (subscope.is_master == false);
          assert (subscope.icon == "/usr/share/unity/6/icon-sub1.svg");
          assert (subscope.required_metadata.columns.length == 1);
          unowned Protocol.MetaDataColumnInfo col = subscope.required_metadata.columns[0];
          assert (col.name == "bid");
          assert (col.type_id == "s");
          assert (subscope.optional_metadata != null);
          assert (subscope.optional_metadata.columns.length == 0);
          assert (subscope.keywords.length () == 1);
          assert (subscope.keywords.nth_data (0) == "misc");
          assert (subscope.type == "varia");
          assert (subscope.query_pattern == "^@");
          assert (subscope.description == "Find various stuff subscope 1");
          assert (subscope.search_hint == "Search stuff subscope 1");
        }
        else if (subscope.name == "Sample subscope 2")
        {
          got_subscope2 = true;
          assert (subscope.id == "masterscope_b-subscope2.scope");
          assert (subscope.dbus_name == "com.canonical.Unity.Scope.Subscope2");
          assert (subscope.dbus_path == "/com/canonical/unity/scope/subscope2");
          assert (subscope.is_master == false);
          assert (subscope.icon == "/usr/share/unity/6/icon-sub2.svg");
          assert (subscope.keywords.length () == 1);
          assert (subscope.keywords.nth_data (0) == "pooh");
          assert (subscope.type == "various");
          assert (subscope.query_pattern == "^~");
          assert (subscope.description == "Find various stuff subscope 2");
          assert (subscope.search_hint == "Search stuff subscope 2");
        }
      }
    }

    internal static void test_find_all_scopes ()
    {
      // ignore warnings
      var error_handler = new ErrorHandler ();
      error_handler.ignore_message (PROTO_DOMAIN, LogLevelFlags.LEVEL_WARNING);

      Protocol.ScopeRegistry reg = null;

      var ml = new MainLoop ();
      Protocol.ScopeRegistry.find_scopes.begin (SCOPES_ROOT, (obj, res) =>
      {
        reg = Protocol.ScopeRegistry.find_scopes.end (res);
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (reg != null);
      assert (reg.scopes != null);
      assert (reg.scopes.length () == NUM_TOP_LEVEL_TEST_SCOPES);

      bool got_masterscope_1 = false;
      bool got_masterscope_2 = false;
      bool got_masterscope_3 = false;

      foreach (var node in reg.scopes)
      {
        assert (node != null);
        var inf = node.scope_info;
        if (inf.name == "Sample Master Scope 1")
        {
          assert (inf.id == "masterscope_a.scope");
          assert (inf.dbus_name == "com.canonical.Unity.Scope.MasterA");
          assert (inf.dbus_path == "/com/canonical/unity/scope/mastera");
          assert (inf.is_master == true);
          assert (inf.icon == "/usr/share/unity/6/icon1.svg");
          assert (inf.required_metadata.columns.length == 3);
          var col = inf.required_metadata.columns[0];
          assert (col.name == "some_id");
          assert (col.type_id == "s");
          col = inf.required_metadata.columns[1];
          assert (col.name == "foo");
          assert (col.type_id == "s");
          col = inf.required_metadata.columns[2];
          assert (col.name == "bar");
          assert (col.type_id == "y");
          assert (inf.optional_metadata != null);
          assert (inf.optional_metadata.columns.length == 1);
          col = inf.optional_metadata.columns[0];
          assert (col.name == "baz");
          assert (col.type_id == "u");
          assert (inf.keywords.length () == 1);
          assert (inf.type == "varia");
          assert (inf.query_pattern == "");
          assert (inf.description == "Find various stuff");
          assert (inf.search_hint == "Search stuff");
          assert (node.sub_scopes == null);

          got_masterscope_1 = true;
        }
        else if (inf.name == "Sample Master Scope 2")
        {
          assert (inf.id == "masterscope_b.scope");
          assert (inf.dbus_name == "com.canonical.Unity.Scope.MasterB");
          assert (inf.dbus_path == "/com/canonical/unity/scope/masterb");
          assert (inf.is_master == true);
          assert (inf.icon == "/usr/share/unity/6/icon2.svg");
          assert (inf.keywords.length () == 2);
          assert (inf.keywords.nth_data (0) == "misc");
          assert (inf.keywords.nth_data (1) == "booze");
          assert (inf.type == "booze");
          assert (inf.query_pattern == "^(");
          assert (inf.description == "Find even more stuff");
          assert (inf.search_hint == "Search things");

          check_scope_b_subscopes (node);

          got_masterscope_2 = true;
        }
        else if (inf.name == "Sample Master Scope 3")
        {
          assert (inf.id == "masterscope_c.scope");

          assert (node.sub_scopes.length () == 1);
          assert (node.sub_scopes.nth_data (0).id == "test_masterscope.scope");
          got_masterscope_3 = true;
        }
      }

      assert (got_masterscope_1 == true);
      assert (got_masterscope_2 == true);
      assert (got_masterscope_3 == true);
    }

    internal static void test_find_all_scopes_xdg ()
    {
      // ignore warnings
      var error_handler = new ErrorHandler ();
      error_handler.ignore_message (PROTO_DOMAIN, LogLevelFlags.LEVEL_WARNING);

      Protocol.ScopeRegistry reg = null;

      var ml = new MainLoop ();
      Protocol.ScopeRegistry.find_scopes.begin (null, (obj, res) =>
      {
        reg = Protocol.ScopeRegistry.find_scopes.end (res);
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (reg != null);
      assert (reg.scopes != null);
      assert (reg.scopes.length () == NUM_TOP_LEVEL_TEST_SCOPES);

      bool got_masterscope_1 = false;
      bool got_masterscope_2 = false;
      bool got_masterscope_3 = false;

      foreach (var node in reg.scopes)
      {
        assert (node != null);
        var inf = node.scope_info;
        if (inf.name == "Sample Master Scope 1")
        {
          assert (inf.id == "masterscope_a.scope");
          assert (inf.dbus_name == "com.canonical.Unity.Scope.MasterA");
          assert (inf.dbus_path == "/com/canonical/unity/scope/mastera");
          assert (inf.is_master == true);
          assert (inf.icon == "/usr/share/unity/6/icon1.svg");
          assert (inf.required_metadata.columns.length == 3);
          var col = inf.required_metadata.columns[0];
          assert (col.name == "some_id");
          assert (col.type_id == "s");
          col = inf.required_metadata.columns[1];
          assert (col.name == "foo");
          assert (col.type_id == "s");
          col = inf.required_metadata.columns[2];
          assert (col.name == "bar");
          assert (col.type_id == "y");
          assert (inf.optional_metadata != null);
          assert (inf.optional_metadata.columns.length == 1);
          col = inf.optional_metadata.columns[0];
          assert (col.name == "baz");
          assert (col.type_id == "u");
          assert (inf.keywords.length () == 1);
          assert (inf.type == "varia");
          assert (inf.query_pattern == "");
          assert (inf.description == "Find various stuff");
          assert (inf.search_hint == "Search stuff");
          assert (node.sub_scopes == null);

          got_masterscope_1 = true;
        }
        else if (inf.name == "Sample Master Scope 2")
        {
          assert (inf.id == "masterscope_b.scope");
          assert (inf.dbus_name == "com.canonical.Unity.Scope.MasterB");
          assert (inf.dbus_path == "/com/canonical/unity/scope/masterb");
          assert (inf.is_master == true);
          assert (inf.icon == "/usr/share/unity/6/icon2.svg");
          assert (inf.keywords.length () == 2);
          assert (inf.keywords.nth_data (0) == "misc");
          assert (inf.keywords.nth_data (1) == "booze");
          assert (inf.type == "booze");
          assert (inf.query_pattern == "^(");
          assert (inf.description == "Find even more stuff");
          assert (inf.search_hint == "Search things");

          check_scope_b_subscopes (node);

          got_masterscope_2 = true;
        }
        else if (inf.name == "Sample Master Scope 3")
        {
          assert (inf.id == "masterscope_c.scope");

          assert (node.sub_scopes.length () == 1);
          assert (node.sub_scopes.nth_data (0).id == "test_masterscope.scope");
          got_masterscope_3 = true;
        }
      }

      assert (got_masterscope_1 == true);
      assert (got_masterscope_2 == true);
      assert (got_masterscope_3 == true);
    }

    internal static void test_find_all_scopes_with_hidden_scopes ()
    {
      var settings = new Settings ("com.canonical.Unity.Lenses");
      settings.set_strv ("hidden-scopes",
                         {"masterscope_a.scope", "test_masterscope.scope"});
      unity_protocol_scope_registry_scope_metadata_update_hidden_scope_ids ();
      // ignore warnings
      var error_handler = new ErrorHandler ();
      error_handler.ignore_message (PROTO_DOMAIN, LogLevelFlags.LEVEL_WARNING);

      Protocol.ScopeRegistry reg = null;

      var ml = new MainLoop ();
      Protocol.ScopeRegistry.find_scopes.begin (null, (obj, res) =>
      {
        reg = Protocol.ScopeRegistry.find_scopes.end (res);
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (reg != null);
      assert (reg.scopes != null);
      // there are exactly 4 top-level scopes (master scopes) - 2 disabled
      assert (reg.scopes.length () == NUM_TOP_LEVEL_TEST_SCOPES - 2);

      bool got_masterscope_1 = false;
      bool got_masterscope_2 = false;
      bool got_masterscope_3 = false;

      foreach (var node in reg.scopes)
      {
        assert (node != null);
        var inf = node.scope_info;
        if (inf.name == "Sample Master Scope 1")
        {
          assert (inf.id == "masterscope_a.scope");
          got_masterscope_1 = true;
        }
        else if (inf.name == "Sample Master Scope 2")
        {
          assert (inf.id == "masterscope_b.scope");
          assert (inf.dbus_name == "com.canonical.Unity.Scope.MasterB");
          assert (inf.dbus_path == "/com/canonical/unity/scope/masterb");
          assert (inf.is_master == true);
          assert (inf.icon == "/usr/share/unity/6/icon2.svg");
          assert (inf.keywords.length () == 2);
          assert (inf.keywords.nth_data (0) == "misc");
          assert (inf.keywords.nth_data (1) == "booze");
          assert (inf.type == "booze");
          assert (inf.query_pattern == "^(");
          assert (inf.description == "Find even more stuff");
          assert (inf.search_hint == "Search things");

          check_scope_b_subscopes (node);

          got_masterscope_2 = true;
        }
        else if (inf.name == "Sample Master Scope 3")
        {
          assert (inf.id == "masterscope_c.scope");

          // the child in this one is disabled, there should be 0 subscopes
          assert (node.sub_scopes.length () == 0);
          got_masterscope_3 = true;
        }
      }

      assert (got_masterscope_1 == false);
      assert (got_masterscope_2 == true);
      assert (got_masterscope_3 == true);

      // cleanup
      settings.set_strv ("hidden-scopes", {});
      unity_protocol_scope_registry_scope_metadata_update_hidden_scope_ids ();
    }

    internal static void test_find_specific_scope ()
    {
      // ignore warnings
      var error_handler = new ErrorHandler ();
      error_handler.ignore_message (PROTO_DOMAIN, LogLevelFlags.LEVEL_WARNING);

      Protocol.ScopeRegistry reg = null;

      var ml = new MainLoop ();
      Protocol.ScopeRegistry.find_scopes.begin (SCOPES_ROOT + "/masterscope_b.scope",
      (obj, res) =>
      {
        reg = Protocol.ScopeRegistry.find_scopes.end (res);
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (reg != null);
      assert (reg.scopes != null);
      assert (reg.scopes.length () == 1); // there are exactly 1 top-level scope (master scope)

      var node = reg.scopes.nth_data (0);
      assert (node != null);
      check_scope_b_subscopes (node);

      // failure on non-exising scope
      bool got_excp = false;
      Protocol.ScopeRegistry.find_scopes.begin (SCOPES_ROOT + "/nonexistingscope.scope",
      (obj, res) =>
      {
        try
        {
          reg = Protocol.ScopeRegistry.find_scopes.end (res);
        }
        catch (Error e)
        {
          got_excp = true;
        }
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (got_excp == true);
    }

    internal static void test_find_scope_by_id ()
    {
      // ignore warnings, because there's broken scope in the dir
      var error_handler = new ErrorHandler ();
      error_handler.ignore_message (PROTO_DOMAIN, LogLevelFlags.LEVEL_WARNING);

      Protocol.ScopeRegistry reg = null;

      var ml = new MainLoop ();
      Protocol.ScopeRegistry.find_scopes_for_id.begin ("masterscope_b.scope", null, (obj, res) =>
      {
        try
        {
          reg = Protocol.ScopeRegistry.find_scopes_for_id.end (res);
        }
        catch (Error e) { assert_not_reached (); }
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (reg != null);
      assert (reg.scopes != null);
      assert (reg.scopes.length () == 2); // there are exactly 2 scopes (sub-scopes of masterscope_b)

      var node = reg.scopes.nth_data (0);
      assert (node != null);
    }

    internal static void test_find_overridden_scope_by_id ()
    {
      string[] extra_dirs = {
        Config.TESTDIR + "/data/unity/customized_scopes",
        Config.TESTDIR + "/data/non_existant",
        Config.TESTDIR + "/data/unity/scopes",
      };
      string dirs = string.joinv (":", extra_dirs);
      Environment.set_variable ("LIBUNITY_SCOPE_DIRECTORIES", dirs, true);
      unity_protocol_scope_registry_init_scope_directories ();
      unity_protocol_scope_registry_init_scope_file_prefixes ();

      // ignore warnings, because there's broken scope in the dir
      var error_handler = new ErrorHandler ();
      error_handler.ignore_message (PROTO_DOMAIN, LogLevelFlags.LEVEL_WARNING);

      Protocol.ScopeRegistry reg = null;

      var ml = new MainLoop ();
      Protocol.ScopeRegistry.find_scopes_for_id.begin ("masterscope_b.scope", null, (obj, res) =>
      {
        try
        {
          reg = Protocol.ScopeRegistry.find_scopes_for_id.end (res);
        }
        catch (Error e) { assert_not_reached (); }
        ml.quit ();
      });

      run_with_timeout (ml, 5000);

      assert (reg != null);
      assert (reg.scopes != null);
      assert (reg.scopes.length () == 3); // there are exactly 3 scopes (sub-scopes of masterscope_b)

      bool found_subscope1 = false;
      bool found_subscope2 = false;
      bool found_override = false;
      foreach (var node in reg.scopes)
      {
        switch (node.scope_info.id)
        {
          case "masterscope_b-subscope1.scope": found_subscope1 = true;
            break;
          case "masterscope_b-subscope2.scope": found_subscope2 = true;
            break;
          case "masterscope_b-subscope-custom.scope": found_override = true;
            break;
          default: warning ("Found unknown subscope: %s", node.scope_info.id);
            break;
        }
      }

      assert (found_subscope1);
      assert (found_subscope2);
      assert (found_override);

      // cleanup
      Environment.set_variable ("LIBUNITY_SCOPE_DIRECTORIES",
        "%s/data/unity/scopes".printf (Config.TESTDIR), true);
      unity_protocol_scope_registry_init_scope_directories ();
      unity_protocol_scope_registry_init_scope_file_prefixes ();
    }

    internal static void test_metadata_load_by_scope_id ()
    {
      var metadata = Protocol.ScopeRegistry.ScopeMetadata.for_id ("masterscope_a.scope");
      assert (metadata.dbus_name == "com.canonical.Unity.Scope.MasterA");
      assert (metadata.dbus_path == "/com/canonical/unity/scope/mastera");
      assert (metadata.is_master == true);
      assert (metadata.icon == "/usr/share/unity/6/icon1.svg");
      assert (metadata.required_metadata.columns.length == 3);
      var col = metadata.required_metadata.columns[0];
      assert (col.name == "some_id");
      assert (col.type_id == "s");
      col = metadata.required_metadata.columns[1];
      assert (col.name == "foo");
      assert (col.type_id == "s");
      col = metadata.required_metadata.columns[2];
      assert (col.name == "bar");
      assert (col.type_id == "y");
      assert (metadata.optional_metadata != null);
      assert (metadata.optional_metadata.columns.length == 1);
      col = metadata.optional_metadata.columns[0];
      assert (col.name == "baz");
      assert (col.type_id == "u");
      assert (metadata.keywords.length () == 1);
      assert (metadata.type == "varia");
      assert (metadata.query_pattern == "");
      assert (metadata.description == "Find various stuff");
      assert (metadata.search_hint == "Search stuff");

      try
      {
        metadata = Protocol.ScopeRegistry.ScopeMetadata.for_id ("nonexistingscope.scope");
        assert_not_reached ();
      }
      catch (Error err) {}
    }

    private static void test_metadata_load_masterscope ()
    {
      var metadata = Protocol.ScopeRegistry.ScopeMetadata.for_id ("masterscope_b.scope");
      assert (metadata.dbus_name == "com.canonical.Unity.Scope.MasterB");
      assert (metadata.dbus_path == "/com/canonical/unity/scope/masterb");
      assert (metadata.is_master == true);
      assert (metadata.no_content_hint == "Sorry to make you a sad panda, but there's nothing here.");

      var categories = metadata.get_categories ();
      assert (categories != null);
      assert (categories.length == 2);

      var category = categories[0];
      assert (category.id == "cat1");
      assert (category.name == "Category #1");
      assert (category.icon == "/usr/share/unity/category1_icon.svg");
      assert (category.dedup_field == "uri");
      assert (category.sort_field == null);
      assert (category.renderer == null);
      assert (category.content_type == null);
      assert (category.renderer_hint == null);

      category = categories[1];
      assert (category.id == "cat2");
      assert (category.name == "Category #2");
      assert (category.icon == "/usr/share/unity/category2_icon.svg");
      assert (category.dedup_field == null);
      assert (category.sort_field == "title");
      assert (category.renderer == "list");
      assert (category.content_type == "music");
      assert (category.renderer_hint == "compact");

      var filters = metadata.get_filters ();
      assert (filters != null);
      assert (filters.length == 2);

      var filter = filters[0];
      assert (filter.id == "genre");
      assert (filter.name == "Genre");
      assert (filter.filter_type == "check-options");
      assert (filter.get_option_ids ().length == 4);
      assert (filter.get_option_names ().length == 4);
      assert (filter.get_option_ids ()[1] == "pop");
      assert (filter.get_option_ids () [3] == "electro");
      assert (filter.get_option_names () [1] == "Pop");
      assert (filter.get_option_names () [3] == "Electro");

      filter = filters[1];
      assert (filter.id == "decade");
      assert (filter.name == "Decade");
      assert (filter.filter_type == "multi-range");
      assert (filter.get_option_ids ().length == 3);
      assert (filter.get_option_names ().length == 3);
    }
  }
}
