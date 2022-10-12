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

using GLib;
using Unity.Internal;

namespace Unity {

public enum FilterRenderer
{
  CHECK_OPTIONS,
  RADIO_OPTIONS,
  MULTIRANGE,
  RATINGS,
  CHECK_OPTIONS_COMPACT;

  public static unowned string to_string (FilterRenderer renderer)
  {
    switch (renderer)
    {
      case FilterRenderer.CHECK_OPTIONS: return "filter-checkoption";
      case FilterRenderer.CHECK_OPTIONS_COMPACT: return "filter-checkoption-compact";
      case FilterRenderer.RADIO_OPTIONS: return "filter-radiooption";
      case FilterRenderer.RATINGS: return "filter-ratings";
      case FilterRenderer.MULTIRANGE: return "filter-multirange";
      default: return "invalid-renderer";
    }
  }

  public static FilterRenderer from_string (string renderer_name)
  {
    switch (renderer_name)
    {
      case "filter-checkoption": return FilterRenderer.CHECK_OPTIONS;
      case "filter-checkoption-compact": return FilterRenderer.CHECK_OPTIONS_COMPACT;
      case "filter-radiooption": return FilterRenderer.RADIO_OPTIONS;
      case "filter-ratings": return FilterRenderer.RATINGS;
      case "filter-multirange": return FilterRenderer.MULTIRANGE;
      default:
        warning ("Unknown filter renderer: %s", renderer_name);
        return FilterRenderer.RADIO_OPTIONS;
    }
  }
}

/*
 * Base class for filters. If you are implmenting a scope, checking first that
 * a filter is "filtering" is a good way to avoid unnecessary extra logic in
 * your search. I.e. if a ratings filter was filtering, then it would mean that
 * the user has chosen a minimum rating. However, if the filtering property was
 * equal to false, that would indicate that the user has not chosen anything
 * and therefore the search can accept any rating.
 */
public abstract class Filter : Object, Dee.Serializable
{
  public string id { get; construct; }
  public string display_name { get; internal construct set; }
  public Icon? icon_hint { get; construct; }
  public FilterRenderer renderer { get; construct; }
  public bool visible { get; construct set; }
  public bool collapsed { get; internal construct set; }
  public bool filtering { get; internal construct set; }

  public signal void changed ();
  
  private Dee.Model _model;
  private unowned Dee.ModelIter _iter;

  internal void set_model_and_iter (Dee.Model model, Dee.ModelIter iter)
  {
    _model = model;
    _iter = iter;

    _model.row_changed.connect (on_row_changed);

    on_row_changed (model, iter);
  }

  private void on_row_changed (Dee.Model model, Dee.ModelIter iter)
  {
    if (iter != _iter)
      return;

    filtering = model.get_bool (iter, FilterColumn.FILTERING);

    var properties = model.get_value (iter, FilterColumn.RENDERER_STATE);
    update (properties);
  }

  private Variant serialize ()
  {
    var vb = new VariantBuilder (new VariantType ("(ssssa{sv}bbb)"));
    vb.add ("s", id);
    vb.add ("s", display_name);
    vb.add ("s", Utils.icon_to_string (icon_hint));
    vb.add ("s", FilterRenderer.to_string (renderer));
    vb.add ("@a{sv}", Utils.hash_table_to_asv (get_hints ()));
    vb.add ("b", visible);
    vb.add ("b", collapsed);
    vb.add ("b", filtering);

    return vb.end ();
  }

  internal abstract HashTable<string, Variant> get_hints ();
  internal abstract void update (Variant properties);

  internal static Filter? for_filter_model_row (Dee.Model model,
                                                Dee.ModelIter iter)
  {
    string icon_hint = model.get_string (iter, FilterColumn.ICON_HINT);
    Icon? icon = null;
    try
    {
      if (icon_hint != "")
        icon = Icon.new_for_string (icon_hint);
    }
    catch (Error e)
    {
      warning ("Error parsing GIcon data '%s': %s", icon_hint, e.message);
    }

    Filter? filter = null;
    FilterRenderer renderer = FilterRenderer.from_string (
        model.get_string (iter, FilterColumn.RENDERER_NAME));

    switch (renderer)
    {
      case FilterRenderer.RATINGS:
        filter = new RatingsFilter (model.get_string (iter, FilterColumn.ID),
                                    model.get_string (iter, FilterColumn.DISPLAY_NAME),
                                    icon);
        break;
      case FilterRenderer.RADIO_OPTIONS:
        filter = new RadioOptionFilter (model.get_string (iter, FilterColumn.ID),
                                        model.get_string (iter, FilterColumn.DISPLAY_NAME),
                                        icon);
        break;
      case FilterRenderer.CHECK_OPTIONS:
        filter = new CheckOptionFilter (model.get_string (iter, FilterColumn.ID),
                                        model.get_string (iter, FilterColumn.DISPLAY_NAME),
                                        icon);
        break;
      case FilterRenderer.CHECK_OPTIONS_COMPACT:
        filter = new CheckOptionFilterCompact (model.get_string (iter, FilterColumn.ID),
                                               model.get_string (iter, FilterColumn.DISPLAY_NAME),
                                               icon);
        break;
      case FilterRenderer.MULTIRANGE:
        filter = new MultiRangeFilter (model.get_string (iter, FilterColumn.ID),
                                       model.get_string (iter, FilterColumn.DISPLAY_NAME),
                                       icon);
        break;
    }

    filter.filtering = model.get_bool (iter, FilterColumn.FILTERING);
    var properties = model.get_value (iter, FilterColumn.RENDERER_STATE);
    filter.update (properties);

    return filter;
  }
}

/*
 * Reused in any filter that requires one or more options
 */
public class FilterOption : Object
{
  public string id { get; construct; }
  public string display_name { get; construct; }
  public Icon icon_hint { get; construct; }
  public bool active { get; construct set; }

  public FilterOption (string id, string display_name, Icon? icon_hint=null, bool active=false)
  {
    Object(id:id, display_name:display_name, icon_hint:icon_hint, active:active);
  }
}

/*
 * A base class for filters that require a list of FilterOptions
 */
public class OptionsFilter : Filter
{
  public List<FilterOption> options;
  public SortType sort_type { get; set; default = SortType.MANUAL; }
  public bool show_all_button { get; set; default = true; }
  
  public enum SortType
  {
    MANUAL,
    DISPLAY_NAME,
    ID
  }

  public FilterOption add_option (string id, string display_name, Icon? icon_hint=null)
  {
    var option = new FilterOption(id, display_name, icon_hint);
    
    switch (sort_type)
      {
        case SortType.DISPLAY_NAME:
          options.insert_sorted (option, sort_by_display_name);
          break;
        case SortType.ID:
          options.insert_sorted (option, sort_by_id);
          break;
        case SortType.MANUAL :
        default:
          options.append (option);
          break;
      }

    this.changed ();
    
    return option;
  }
  
  private static int sort_by_display_name (FilterOption f1, FilterOption f2)
  {
    return f1.display_name.collate (f2.display_name);
  }
  
  private static int sort_by_id (FilterOption f1, FilterOption f2)
  {
    return f1.id.collate (f2.id);
  }

  public FilterOption? get_option (string id)
  {
    foreach (FilterOption option in options)
    {
      if (option.id == id)
        return option;
    }
    return null;
  }

  /**
   * Removes a FilterOption from the OptionsFilter.
   *
   * @return true if a FilterOption was removed, false if FilterOption with
   * given id couldn't be found.
   */
  public bool remove_option (string id)
  {
    unowned List<FilterOption> element = null;
    for (unowned List<FilterOption> it = options.first (); it != null; it = it.next)
    {
      if (it.data.id == id)
      {
        element = it;
        break;
      }
    }
    
    if (element != null)
    {
      element.data = null;
      options.delete_link (element);

      this.changed ();
    }
    return element != null;
  }

  internal override void update (Variant properties)
  {
    VariantIter iter;
    properties.get ("a{sv}", out iter);

    for (var i = 0; i < iter.n_children(); i++)
    {
      string key;
      Variant val;

      iter.next("{sv}", out key, out val);

      if (key == "options")
      {
        load_or_update_options (val);
      }
      else if (key == "show-all-button")
      {
        show_all_button = val.get_boolean ();
      }
    }

    this.changed ();
  }

  internal void load_or_update_options (Variant array)
  {
    VariantIter iter;
    array.get("a(sssb)", out iter);

    string[] option_ids = {};

    for (var i = 0; i < iter.n_children(); i++)
    {
      string b_id;
      string b_name;
      string b_icon_hint;
      bool b_active;

      iter.next("(sssb)", out b_id, out b_name, out b_icon_hint, out b_active);

      find_and_update_option(b_id, b_name, b_icon_hint, b_active);
      option_ids += b_id;
    }

    if (options.length () != option_ids.length)
    {
      // something got removed, remove it from the List (and don't use
      // remove_option() cause it emits changed()
      unowned List<FilterOption> l = options;
      while (l != null)
      {
        unowned string id = l.data.id;
        unowned List<FilterOption> to_remove = l;
        l = l.next;
        if (!(id in option_ids))
        {
          to_remove.data = null;
          options.delete_link (to_remove);
        }
      }
    }
  }

  internal void find_and_update_option (string id, string name, string icon_hint_s, bool active)
  {
    foreach (FilterOption option in options)
    {
      if (option.id == id)
      {
        option.active = active;
        return;
      }
    }

    // Create one as we didn't find it
    Icon? icon_hint = null;
    try
      {
        if (icon_hint_s != "")
          icon_hint = Icon.new_for_string (icon_hint_s);
      }
    catch (Error e)
      {
        warning ("Unable to parse GIcon data '%s': %s", icon_hint_s, e.message);
      }
    var option = new FilterOption (id, name, icon_hint, active);
    options.append (option);
  }

  internal override HashTable<string, Variant> get_hints()
  {
    var b = new VariantBuilder (new VariantType ("a(sssb)"));

    foreach (FilterOption option in options)
    {
      var icon_string = option.icon_hint != null ? option.icon_hint.to_string () : "";
      b.add ("(sssb)", option.id, option.display_name, icon_string, option.active);
    }

    var hash = new HashTable<string, Variant> (str_hash, str_equal);
    hash["options"] = b.end ();
    hash["show-all-button"] = new Variant.boolean (show_all_button);

    return hash;
  }
}


/*
 * Implements radio-option behavior in the filter. Adding options gives users
 * options to choose from, though only one maybe chosen at a time.
 */
public class RadioOptionFilter : OptionsFilter
{
  public RadioOptionFilter (string id,
                            string display_name,
                            Icon? icon_hint=null,
                            bool collapsed=false)
  {
    Object (id:id, display_name:display_name,
            icon_hint:icon_hint, collapsed:collapsed,
            renderer:FilterRenderer.RADIO_OPTIONS, visible:true,
            filtering:false);
  }

  /* Returns the option that the user would like to filter on. If the the
   * filter is not currently filtering, this will return null.
   */
  public FilterOption? get_active_option ()
  {
    foreach (FilterOption option in options)
    {
      if (option.active)
        return option;
    }
    return null;
  }
}

/*
 * Implements check-option behavior in the filter. Adding options gives users
 * options to choose from, and the user may select more than one option at a
 * time. For example, this could be used when you'd like to filter between one
 * or more types of files. Rather than just choosing Images or Music, the user
 * could browse both images and music returned for a search string.
 */
public class CheckOptionFilter : OptionsFilter
{
  public CheckOptionFilter (string id,
                            string display_name,
                            Icon? icon_hint=null,
                            bool collapsed=false)
  {
    Object (id:id, display_name:display_name,
            icon_hint:icon_hint, collapsed:collapsed,
            renderer:FilterRenderer.CHECK_OPTIONS, visible:true,
            filtering:false);
  }
}

public class CheckOptionFilterCompact : OptionsFilter
{
  public CheckOptionFilterCompact (string id,
                                   string display_name,
                                   Icon? icon_hint=null,
                                   bool collapsed=false)
  {
    Object (id:id, display_name:display_name,
            icon_hint:icon_hint, collapsed:collapsed,
            renderer:FilterRenderer.CHECK_OPTIONS_COMPACT, visible:true,
            filtering:false);
  }
}

/* RatingsFilter allows the user to choose a rating between 0.0f and 1.0f in
 * 0.2f blocks (i.e. a rating up to five stars).
 */
public class RatingsFilter : Filter
{
  public float rating { get; internal construct set; }

  public RatingsFilter(string id,
                       string display_name,
                       Icon? icon_hint=null,
                       bool collapsed=false)
  {
    Object (id:id, display_name:display_name,
            icon_hint:icon_hint, collapsed:collapsed,
            renderer:FilterRenderer.RATINGS, rating:0.0f,
            visible:true, filtering:false);
  }

  internal override void update (Variant properties)
  {
    VariantIter iter;
    properties.get ("a{sv}", out iter);

    for (var i = 0; i < iter.n_children(); i++)
    {
      string key;
      Variant val;

      iter.next("{sv}", out key, out val);

      if (key == "rating")
        rating = (float)val.get_double ();
    }

    this.changed ();
  }

  internal override HashTable<string, Variant> get_hints()
  {
    var hash = new HashTable<string, Variant> (null, null);
    hash.insert ("rating", 0.0);
    return hash;
  }
}

/*
 * Implements a range widget that can be adjusted from both sides. This is
 * useful if you want the user to be able to filter a range e.g. decades.
 *
 * Using the decades example, you would add options for every decade you'd
 * like the user to be able to choose from (note: please consider the
 * width of the filter bar in the Dash when choosing names for the options).
 * If you were to add "70s", "80s", "90s", "00s" and "10s", then the user
 * could either choose just one decade, or they could choose a range of
 * decades (say, 80s to 10s).
 *
 * Locally, this is reflected by the "get_first_active" and "get_last_active"
 * methods, allowing you to quickly determine the start and end points of
 * the range (if the filter is currently filtering).
 */
public class MultiRangeFilter : OptionsFilter
{
  public MultiRangeFilter (string id,
                           string display_name,
                           Icon? icon_hint=null,
                           bool collapsed=false)
  {
    Object (id:id, display_name:display_name,
            icon_hint:icon_hint, collapsed:collapsed,
            renderer:FilterRenderer.MULTIRANGE, visible:true,
            filtering:false);
  }

  public FilterOption? get_first_active ()
  {
    foreach (FilterOption option in options)
    {
      if (option.active)
        return option;
    }

    return null;
  }

  public FilterOption? get_last_active ()
  {
    FilterOption? ret = null;

    foreach (FilterOption option in options)
    {
      if (option.active)
        ret = option;
    }

    return ret;
  }
}

} /* namespace */
