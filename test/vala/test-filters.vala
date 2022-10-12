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
 * Authored by Mikkel Kamstrup Erlandsen <mikkel.kamstrup@canonical.com>
 *
 */
using Unity;

namespace Unity.Test
{
  public class FilterSuite
  {
    public FilterSuite ()
    {
      GLib.Test.add_data_func ("/Unit/Filters/OptionsFilter/Empty",
                               FilterSuite.test_options_filter_empty);
      GLib.Test.add_data_func ("/Unit/Filters/OptionsFilter/SortManual",
                               FilterSuite.test_options_filter_sort_manual);
      GLib.Test.add_data_func ("/Unit/Filters/OptionsFilter/SortDisplayName",
                               FilterSuite.test_options_filter_sort_display_name);
      GLib.Test.add_data_func ("/Unit/Filters/OptionsFilter/SortId",
                               FilterSuite.test_options_filter_sort_id);
      GLib.Test.add_data_func ("/Unit/Filters/RadioOptionsFilter",
                               FilterSuite.test_radio_options_filter);
      GLib.Test.add_data_func ("/Unit/Filters/RatingsFilter",
                               FilterSuite.test_ratings_filter);
    }

    internal static void test_options_filter_empty ()
    {
      var filter = new OptionsFilter ();
      assert (filter.options.length () == 0);
    }
    
    private static int find_filter_offset_by_id (OptionsFilter filter, string id)
    {
      int i = 0;
      foreach (var f in filter.options)
      {
        if (f.id == id)
          return i;
        i++;
      }
      return -1;
    }
    
    internal static void test_options_filter_sort_manual ()
    {
      var filter = new OptionsFilter ();
      assert (filter.sort_type == OptionsFilter.SortType.MANUAL);
      
      filter.add_option ("accessories", "Accessories");
      filter.add_option ("bccessories", "Bccessories");
      filter.add_option ("xenomorphs", "Xenomorphic Creatures");
      
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 2);
      
      filter.add_option ("aardvaark", "Weird Animal");
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 2);
      assert (find_filter_offset_by_id (filter, "aardvaark") == 3);
    }
    
    internal static void test_options_filter_sort_display_name ()
    {
      var filter = new OptionsFilter ();
      filter.sort_type = OptionsFilter.SortType.DISPLAY_NAME;
      assert (filter.sort_type == OptionsFilter.SortType.DISPLAY_NAME);
      
      filter.add_option ("accessories", "Accessories");
      filter.add_option ("bccessories", "Bccessories");
      filter.add_option ("xenomorphs", "Xenomorphic Creatures");
      
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 2);

      filter.add_option ("weirdanimal", "Aardvaark");
      assert (find_filter_offset_by_id (filter, "weirdanimal") == 0);
      assert (find_filter_offset_by_id (filter, "accessories") == 1);
      assert (find_filter_offset_by_id (filter, "bccessories") == 2);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 3);
      
      filter.add_option ("zooanimal", "Zebra");
      assert (find_filter_offset_by_id (filter, "weirdanimal") == 0);
      assert (find_filter_offset_by_id (filter, "accessories") == 1);
      assert (find_filter_offset_by_id (filter, "bccessories") == 2);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 3);
      assert (find_filter_offset_by_id (filter, "zooanimal") == 4);
    }
    
    internal static void test_options_filter_sort_id ()
    {
      var filter = new OptionsFilter ();
      filter.sort_type = OptionsFilter.SortType.ID;
      assert (filter.sort_type == OptionsFilter.SortType.ID);
      
      filter.add_option ("accessories", "Accessories");
      filter.add_option ("bccessories", "Bccessories");
      filter.add_option ("xenomorphs", "Xenomorphic Creatures");
      
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 2);

      filter.add_option ("weirdanimal", "Aardvaark");
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "weirdanimal") == 2);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 3);
      
      filter.add_option ("zooanimal", "Zebra");
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "weirdanimal") == 2);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 3);
      assert (find_filter_offset_by_id (filter, "zooanimal") == 4);
    }

    internal static void test_radio_options_filter ()
    {
      var filter = new RadioOptionFilter ("radio1", "Radio 1", null, false);
      filter.sort_type = OptionsFilter.SortType.ID;
      assert (filter.sort_type == OptionsFilter.SortType.ID);
      
      filter.add_option ("accessories", "Accessories");
      filter.add_option ("bccessories", "Bccessories");
      filter.add_option ("xenomorphs", "Xenomorphic Creatures");
      
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 2);

      filter.add_option ("weirdanimal", "Aardvaark");
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "weirdanimal") == 2);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 3);
      
      filter.add_option ("zooanimal", "Zebra");
      assert (find_filter_offset_by_id (filter, "accessories") == 0);
      assert (find_filter_offset_by_id (filter, "bccessories") == 1);
      assert (find_filter_offset_by_id (filter, "weirdanimal") == 2);
      assert (find_filter_offset_by_id (filter, "xenomorphs") == 3);
      assert (find_filter_offset_by_id (filter, "zooanimal") == 4);
    }

    internal static void test_ratings_filter ()
    {
      var filter = new RatingsFilter ("ratings1", "Ratings 1", null, false);

      assert (filter.rating >= 0);
    }
  }
}
