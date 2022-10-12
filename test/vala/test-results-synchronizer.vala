/*
 * Copyright (C) 2013 Canonical Ltd
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

namespace Unity.Test
{
  public class ResultsSynchronizerTestSuite
  {
    public static string[] RESULTS_SCHEMA = {"s", "s", "u", "u", "s", "s", "s", "s", "a{sv}"};

    public ResultsSynchronizerTestSuite ()
    {
      GLib.Test.add_data_func ("/Unit/ResultsSynchronizer", ResultsSynchronizerTestSuite.test_synchronization);
    }

    internal static void test_synchronization ()
    {
      var receiver = new Dee.SequenceModel ();
      receiver.set_schema_full (RESULTS_SCHEMA);
      var provider1 = new Dee.SequenceModel ();
      provider1.set_schema_full (RESULTS_SCHEMA);
      provider1.set_data<string> ("scope-id", "scope1");

      var provider2 = new Dee.SequenceModel ();
      provider2.set_schema_full (RESULTS_SCHEMA);
      provider2.set_data<string> ("scope-id", "scope2");
      var res_sync = new Internal.ResultsSynchronizer (receiver, "master.scope");
      res_sync.add_provider (provider1, "scope1");
      res_sync.add_provider (provider2, "scope2");

      var empty_asv = new Variant.array (new VariantType ("{sv}"), {});

      assert (receiver.get_n_rows () == 0);

      provider1.append ("uri1", "icon1", 0, 1, "mimetype1", "title1", "comment1", "dnd_uri1", empty_asv);
      provider1.append ("uri2", "icon2", 1, 2, "mimetype2", "title2", "comment2", "dnd_uri2", empty_asv);
      provider2.append ("uri3", "icon3", 2, 3, "mimetype3", "title3", "comment3", "dnd_uri3", empty_asv);

      assert (receiver.get_n_rows () == 3);

      var iter = receiver.get_iter_at_row (0);
      assert (receiver.get_string (iter, 0) == "uri1");
      assert (receiver.get_string (iter, 1) == "icon1");
      assert (receiver.get_uint32 (iter, 2) == 0);
      assert (receiver.get_uint32 (iter, 3) == 1);
      assert (receiver.get_string (iter, 4) == "mimetype1");
      assert (receiver.get_string (iter, 5) == "title1");
      assert (receiver.get_string (iter, 6) == "comment1");
      assert (receiver.get_string (iter, 7) == "dnd_uri1");
      
      iter = receiver.get_iter_at_row (1);
      assert (receiver.get_string (iter, 0) == "uri2");
      assert (receiver.get_string (iter, 1) == "icon2");
      assert (receiver.get_uint32 (iter, 2) == 1);
      assert (receiver.get_uint32 (iter, 3) == 2);
      assert (receiver.get_string (iter, 4) == "mimetype2");
      assert (receiver.get_string (iter, 5) == "title2");
      assert (receiver.get_string (iter, 6) == "comment2");
      assert (receiver.get_string (iter, 7) == "dnd_uri2");

      iter = receiver.get_iter_at_row (2);
      assert (receiver.get_string (iter, 0) == "uri3");
      assert (receiver.get_string (iter, 1) == "icon3");
      assert (receiver.get_uint32 (iter, 2) == 2);
      assert (receiver.get_uint32 (iter, 3) == 3);
      assert (receiver.get_string (iter, 4) == "mimetype3");
      assert (receiver.get_string (iter, 5) == "title3");
      assert (receiver.get_string (iter, 6) == "comment3");
      assert (receiver.get_string (iter, 7) == "dnd_uri3");

      // remove data from master model
      res_sync.clear ();

      assert (receiver.get_n_rows () == 0);
      assert (provider1.get_n_rows () == 2);
      assert (provider2.get_n_rows () == 1);

      // this shouldn't crash synchronizer
      provider1.clear ();
      provider2.clear ();
      
      provider1.append ("uri1", "icon1", 0, 1, "mimetype1", "title1", "comment1", "dnd_uri1", empty_asv);
      assert (receiver.get_n_rows () == 1);
    }
  }
}
