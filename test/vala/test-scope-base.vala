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
using Unity;
using Unity.Protocol;

namespace Unity.Test
{
  public class ScopeSuite
  {
    public ScopeSuite ()
    {
      GLib.Test.add_data_func ("/Unit/SearchContext/Create",
        Fixture.create<SearchContextTester> (SearchContextTester.test_create));
      GLib.Test.add_data_func ("/Unit/SearchContext/SetMetadata",
        Fixture.create<SearchContextTester> (SearchContextTester.test_metadata));
      GLib.Test.add_data_func ("/Unit/ScopeResult/CreateFromVariant",
        Fixture.create<ScopeResultTester> (ScopeResultTester.test_create_from_variant));
      GLib.Test.add_data_func ("/Unit/AbstractScope/AddResult",
        Fixture.create<AbstractScopeTester> (AbstractScopeTester.test_add_result));
      GLib.Test.add_data_func ("/Unit/AbstractScope/AddResultFromVariant",
        Fixture.create<AbstractScopeTester> (AbstractScopeTester.test_add_variant_result));
      GLib.Test.add_data_func ("/Unit/AbstractScope/MetadataWithLocation",
        Fixture.create<AbstractScopeTester> (AbstractScopeTester.test_metadata_with_location));
      GLib.Test.add_data_func ("/Unit/Cancellable/GetGCancellable",
        Fixture.create<CancellableTester> (CancellableTester.test_get_gcancellable));
    }

    class ResultSetTestImpl: ResultSet
    {
      public GenericArray<ScopeResult?> results;

      construct
      {
        results = new GenericArray<ScopeResult?> ();
      }
      protected override void add_result (ScopeResult result)
      {
        results.add (result);
      }
    }

    class SearchContextTester: Object, Fixture
    {
      public void test_create ()
      {
        var metadata_ht = new HashTable<string, Variant> (str_hash, str_equal);
        metadata_ht["locale"] = new Variant.string ("en_GB");
        var result_set =  new ResultSetTestImpl ();
        var context = Unity.SearchContext.create ("query",
                                                  Unity.SearchType.GLOBAL,
                                                  null,
                                                  metadata_ht,
                                                  result_set,
                                                  null);

        assert (context.search_query == "query");
        assert (context.search_type == Unity.SearchType.GLOBAL);
        assert (context.filter_state == null);
        assert (context.result_set == result_set);
        assert (context.cancellable == null);
        assert (context.search_metadata.locale == "en_GB");
      }

      public void test_metadata ()
      {
        var result_set =  new ResultSetTestImpl ();
        var context = Unity.SearchContext.create ("query",
                                                  Unity.SearchType.GLOBAL,
                                                  null,
                                                  null,
                                                  result_set,
                                                  null);
        assert (context.search_metadata.locale == null);

        // set metadata after creation
        var metadata_ht = new HashTable<string, Variant> (str_hash, str_equal);
        metadata_ht["locale"] = new Variant.string ("en_AU");
        context.set_search_metadata (SearchMetadata.create (metadata_ht));
        assert (context.search_metadata.locale == "en_AU");

        // set metadata from variant
        var locale_v = new Variant.dict_entry ("locale", new Variant.variant ("en_NZ"));
        var metadata_v = new Variant.array (VariantType.VARDICT.element (),
                                            {locale_v});
        var metadata = Unity.SearchMetadata.create_from_variant (metadata_v);
        context.set_search_metadata (metadata);
        assert (context.search_metadata.locale == "en_NZ");
      }
    }

    class AbstractScopeTester: Object, Fixture
    {
      delegate void RunFunc (SearchContext search);

      private AbstractScopeTestImpl scope;

      class ScopeSearchTestImpl: ScopeSearchBase
      {
        private unowned RunFunc runner;
        public ScopeSearchTestImpl (RunFunc run_func)
        {
          runner = run_func;
        }
        protected override void run ()
        {
          runner (search_context);
        }
      }

      class AbstractScopeTestImpl : AbstractScope
      {
        public RunFunc run_func;

        public AbstractScopeTestImpl ()
        {
        }

        protected override ScopeSearchBase create_search_for_query (SearchContext search_context)
        {
          var search_runner = new ScopeSearchTestImpl (run_func);
          search_runner.set_search_context (search_context);
          return search_runner;
        }

        protected override ResultPreviewer create_previewer (ScopeResult result, SearchMetadata metadata)
        {
          return null;
        }

        protected override CategorySet get_categories ()
        {
          return new CategorySet ();
        }

        protected override FilterSet get_filters ()
        {
          return new FilterSet ();
        }

        protected override Schema get_schema ()
        {
          return new Schema ();
        }

        protected override string get_group_name ()
        {
          return "com.canonical.example.Scope.Test";
        }

        protected override string get_unique_name ()
        {
          return "/com/canonical/example/Scope/Test";
        }
      }

      private void setup ()
      {
        scope = new AbstractScopeTestImpl ();
      }

      private void teardown ()
      {
      }

      public void test_add_result ()
      {
        bool runner_invoked = false;
        scope.run_func = (context) =>
        {
          runner_invoked = true;
          var result = ScopeResult ();
          result.uri = "test://";
          result.icon_hint = "unknown";
          result.category = 0;
          result.mimetype = "text/html";
          result.title = "Test";
          result.comment = "comment";
          result.dnd_uri = result.uri;

          context.result_set.add_result (result);
        };

        var result_set = new ResultSetTestImpl ();
        var search = scope.create_search_for_query (
          SearchContext.create ("foo", SearchType.DEFAULT,
                                new FilterSet (), null,
                                result_set, null));
        search.run ();

        assert (runner_invoked);
        assert (result_set.results.length == 1);

        var test_result = result_set.results[0];
        assert (test_result.uri == "test://");
        assert (test_result.title == "Test");
      }
      
      public void test_add_variant_result ()
      {
        bool runner_invoked = false;
        scope.run_func = (context) =>
        {
          runner_invoked = true;
          var result = ScopeResult ();
          result.uri = "test://";
          result.icon_hint = "unknown";
          result.category = 0;
          result.mimetype = "text/html";
          result.title = "Test";
          result.comment = "comment";
          result.dnd_uri = result.uri;

          var metadata = new Variant.array (VariantType.VARDICT.element (), {});
          var variant = new Variant ("(ssuussss@a{sv})",
                                     result.uri, result.icon_hint,
                                     result.category, result.result_type,
                                     result.mimetype, result.title,
                                     result.comment, result.dnd_uri,
                                     metadata);

          context.result_set.add_result_from_variant (variant);
        };

        var result_set = new ResultSetTestImpl ();
        var search = scope.create_search_for_query (
          SearchContext.create ("foo", SearchType.DEFAULT,
                                new FilterSet (), null,
                                result_set, null));
        search.run ();

        assert (runner_invoked);
        assert (result_set.results.length == 1);

        var test_result = result_set.results[0];
        assert (test_result.uri == "test://");
        assert (test_result.title == "Test");
      }

      public void test_metadata_with_location ()
      {
        double LAT = 54.151804;
        double LON = -4.483109;

        bool runner_invoked = false;
        scope.run_func = (context) =>
        {
          runner_invoked = true;
          var location = context.search_metadata.location;
          assert (location != null);
          assert (location.has_valid_altitude () == false);
          assert (Math.fabs (location.latitude - LAT) < 0.01);
          assert (Math.fabs (location.longitude - LON) < 0.01);
        };

        var result_set = new ResultSetTestImpl ();
        var meta_dict = new HashTable<string, Variant> (str_hash, str_equal);
        meta_dict["location"] = new Variant ("(iddd)", 0, LAT, LON, 0.0);
        var search = scope.create_search_for_query (
          SearchContext.create ("foo", SearchType.DEFAULT,
                                new FilterSet (), meta_dict,
                                result_set, null));
        search.run ();

        assert (runner_invoked);
      }
    }

    class CancellableTester: Object, Fixture
    {
      public void test_get_gcancellable ()
      {
        var cancellable = Unity.Cancellable.create ();
        assert (cancellable.get_gcancellable () is GLib.Cancellable);
      }
    }
    
    class ScopeResultTester: Object, Fixture
    {
      public void test_create_from_variant ()
      {
        var metadata_ht = new HashTable<string, Variant> (str_hash, str_equal);
        metadata_ht["foo"] = new Variant.int32 (32);
        metadata_ht["bar"] = new Variant.string ("qoo");
        Variant metadata = metadata_ht;
        var variant = new Variant ("(ssuussss@a{sv})",
                                   "test://", "unknown",
                                   0, Unity.ResultType.PERSONAL,
                                   "text/html", "Test", "comment",
                                   "test://", metadata);

        var scope_result = Unity.ScopeResult.create_from_variant (variant);
        assert (scope_result.uri == "test://");
        assert (scope_result.icon_hint == "unknown");
        assert (scope_result.category == 0);
        assert (scope_result.result_type == Unity.ResultType.PERSONAL);
        assert (scope_result.mimetype == "text/html");
        assert (scope_result.title == "Test");
        assert (scope_result.comment == "comment");
        assert (scope_result.dnd_uri == scope_result.uri);
        assert (scope_result.metadata.size () == 2);
        assert (scope_result.metadata["bar"].get_string () == "qoo");
      }
    }
  }
}
