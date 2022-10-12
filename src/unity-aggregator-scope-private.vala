/*
 * Copyright (C) 2011-2012 Canonical, Ltd.
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
 *             Michal Hruby <michal.hruby@canonical.com>
 *
 */

using GLib;
using Dee;
using Unity;
using Unity.Protocol;

namespace Unity.Internal {

private class AggregatorScopeImpl : GLib.Object, ScopeService, ScopeDBusImpl,
                                    DeprecatedScopeDBusImpl, MergeStrategy
{
  const int DEFAULT_TIMEOUT_INTERVAL_MS = 16;

  private abstract class CategoryMerger : Object
  {
    protected HashTable<string, int> category_map = new HashTable<string, int> (str_hash, str_equal);
    public abstract int remap (string scope_id, uint32 category_index);
    public abstract bool merge_metadata (string scope_id, Dee.Model categories, Dee.Model master_categories);
    
    /*
      Check if values array contains given progress-source string.
      Note that this is not efficient for many progress source values, but in reality
      we will be dealing with a single source at a time.
     */
    internal static bool contains_progress_source (Variant[] values, Variant psvar)
    {
      unowned string ps = psvar.get_string ();
      foreach (var v in values)
      {
        if (v.get_string () == ps)
          return true;
      }
      return false;
    }

    internal static bool merge_progress_source (Variant[] values, HashTable<string, Variant> hints)
    {
      if (values.length == 0)
        return false;

      Variant[] master_ps = new Variant [0];
      var val = hints.lookup ("progress-source");
      if (val != null)
      {
        for (int i=0; i<val.n_children(); i++)
        {
          var ps = val.get_child_value (i);
          if (!contains_progress_source (master_ps, ps))
            master_ps += ps;
        }
      }
      foreach (var ps in values)
      {
        if (!contains_progress_source (master_ps, ps))
          master_ps += ps;
      }

      hints["progress-source"] = new Variant.array (null, master_ps);

      return true;
    }
  }

  private class CategoryMergerByScope : CategoryMerger
  {
    public void add_scope_mapping (Unity.AggregatorScope scope, string scope_id)
    {
      var idx = scope.category_index_for_scope_id (scope_id);
      if (idx >= 0)
        category_map[scope_id] = idx;
    }

    public override int remap (string scope_id, uint32 category_index)
    {
      if (category_map.contains (scope_id))
        return category_map[scope_id];
      warning ("No category mapping for %s", scope_id);
      return -1;
    }

    public override bool merge_metadata (string scope_id, Dee.Model categories_model, Dee.Model master_categories)
    {
      bool changed = false;
      int cat_index = remap (scope_id, 0);

      if (cat_index >= 0)
      {
        var miter = master_categories.get_iter_at_row (cat_index);
        if (miter != master_categories.get_last_iter ())
        {
          Variant[] master_ps = new Variant [0];

          var iter = categories_model.get_first_iter ();
          var end_iter = categories_model.get_last_iter ();
          while (iter != end_iter)
          {
            var hints = categories_model.get_value (iter, CategoryColumn.HINTS);
            var val = hints.lookup_value ("progress-source", null);
            if (val != null)
            {
              for (int i=0; i<val.n_children(); i++)
                master_ps += val.get_child_value (i);
            }
            iter = categories_model.next (iter);
          }

          HashTable<string, Variant> master_hints = (HashTable<string, Variant>)master_categories.get_value (miter, CategoryColumn.HINTS);
          changed = merge_progress_source (master_ps, master_hints);
          master_categories.set_value (miter, CategoryColumn.HINTS, Utils.hash_table_to_asv (master_hints));
        }
      }
      return changed;
    }
  }

  private class CategoryMergerByField : CategoryMerger
  {
    private HashTable<string, HashTable<int, int>?> subscopes = new HashTable<string, HashTable<int, int>?> (str_hash, str_equal);
    private uint column_index;

    public CategoryMergerByField (Dee.SerializableModel master_categories_model,
                                  uint column_index)
    {
      this.column_index = column_index;
      // iterate over aggregator scope categories and create name -> index mapping
      int count = 0;
      var iter = master_categories_model.get_first_iter ();
      var end_iter = master_categories_model.get_last_iter ();
      while (iter != end_iter)
      {
        var name = master_categories_model.get_string (iter, column_index);
        if (category_map.contains (name))
          warning ("Duplicated category name: %s", name);
        else
          category_map[name] = count++;
        iter = master_categories_model.next (iter);
      }
    }

    /**
     * Creates mapping for given subscope and its categories to aggregator scope category indexes
     */
    public void map_subscope_categories (string scope_id, Dee.SerializableModel categories_model)
    {
      string[] categories = new string [0];

      var iter = categories_model.get_first_iter ();
      var end_iter = categories_model.get_last_iter ();
      while (iter != end_iter)
      {
        string cat_id = categories_model.get_string (iter, column_index);
        categories += cat_id;
        iter = categories_model.next (iter);
      }
      map_subscope_categories_from_list (scope_id, categories);
    }

    public void map_subscope_categories_from_list (string scope_id, string[] categories)
    {
      int count = 0;

      HashTable<int, int> subscope_category_map = subscopes.lookup (scope_id);
      if (subscope_category_map == null)
      {
        subscope_category_map = new HashTable<int, int> (direct_hash, direct_equal);
        subscopes[scope_id] = subscope_category_map;
      }

      foreach (var cat_id in categories)
      {
        if (category_map.contains (cat_id)) //does master have this category?
        {
          var cat_idx = category_map[cat_id];
          subscope_category_map[count++] = cat_idx;
        }
        else
        {
          warning ("Subscope '%s' category '%s' not present in aggregator scope model", scope_id, cat_id);
        }
      }
    }

    public override int remap (string scope_id, uint32 category_index)
    {
      var subscope_category_map = subscopes.lookup (scope_id);
      if (subscope_category_map != null)
      {
        if (subscope_category_map.contains ((int)category_index))
        {
          var idx = subscope_category_map[(int)category_index];
          return (int)idx;
        }
        warning ("No category mapping for %s, category %u", scope_id, category_index);
      }
      warning ("No category mapping for %s", scope_id);
      return -1;
    }

    public override bool merge_metadata (string scope_id, Dee.Model categories_model, Dee.Model master_categories)
    {
      bool changed = false;

      // create temporary cat_id -> hints lookup from categories_model
      var meta = new HashTable<string, Variant> (str_hash, str_equal);
      var iter = categories_model.get_first_iter ();
      var end_iter = categories_model.get_last_iter ();
      while (iter != end_iter)
      {
        unowned string cat_id = categories_model.get_string (iter, CategoryColumn.ID);
        var hints = categories_model.get_value (iter, CategoryColumn.HINTS);

        // optimization - only store hints if they contain values that need to be merged with master
        if (hints.lookup_value ("progress-source", null) != null)
          meta[cat_id] = hints;
        iter = categories_model.next (iter);
      }

      // merge select hints of master_categories model with hints collected in meta
      iter = master_categories.get_first_iter ();
      end_iter = master_categories.get_last_iter ();
      while (iter != end_iter)
      {
        unowned string cat_id = master_categories.get_string (iter, CategoryColumn.ID);
        var hints = meta.lookup (cat_id);

        if (hints != null)
        {
          Variant? val = hints.lookup_value ("progress-source", null);
          if (val != null)
          {
            Variant[] master_ps = new Variant [0];
            for (int i=0; i<val.n_children(); i++)
              master_ps += val.get_child_value (i);

            HashTable<string, Variant> master_hints = (HashTable<string, Variant>)master_categories.get_value (iter, CategoryColumn.HINTS);
            changed = merge_progress_source (master_ps, master_hints);
            master_categories.set_value (iter, CategoryColumn.HINTS, Utils.hash_table_to_asv (master_hints));
          }
        }
        iter = master_categories.next (iter);
      }
      return changed;
    }
  }

  private struct Sorter
  {
    int category;
    int column_index;
    string? field_name;
    char schema;
    int multiplier; // +1 / -1 to implement ASCENDING / DESCENDING sort

    public int apply (Variant[] row1, Variant[] row2)
    {
      Variant dummy1;
      Variant dummy2;
      unowned Variant var1 = row1[column_index];
      unowned Variant var2 = row2[column_index];
      if (field_name != null)
      {
        dummy1 = var1.lookup_value ("content", VariantType.VARDICT).lookup_value (field_name, null);
        dummy2 = var2.lookup_value ("content", VariantType.VARDICT).lookup_value (field_name, null);
        // handle non-presence of optional fields
        if (dummy1 == null && dummy2 == null) return 0;
        var1 = dummy1;
        var2 = dummy2;
      }
      int result;
      switch (schema)
      {
        case 's':
          // strings are special, if optional field is not present,
          // bury the result; numeric types behave as if 0 was set
          if (var1 == null) result = 1 * multiplier;
          else if (var2 == null) result = -1 * multiplier;
          else
          {
            // FIXME: implement a way to use simple ascii sort
            result = var1.get_string ().collate (var2.get_string ());
          }
          break;
        case 'i':
          int i1 = var1 != null ? var1.get_int32 () : 0;
          int i2 = var2 != null ? var2.get_int32 () : 0;
          result = compare_int (i1, i2);
          break;
        case 'u':
          uint u1 = var1 != null ? var1.get_uint32 () : 0;
          uint u2 = var2 != null ? var2.get_uint32 () : 0;
          result = compare_uint (u1, u2);
          break;
        case 'x':
          int64 x1 = var1 != null ? var1.get_int64 () : 0;
          int64 x2 = var2 != null ? var2.get_int64 () : 0;
          result = compare_int64 (x1, x2);
          break;
        case 't':
          uint64 t1 = var1 != null ? var1.get_uint64 () : 0;
          uint64 t2 = var2 != null ? var2.get_uint64 () : 0;
          result = compare_uint64 (t1, t2);
          break;
        case 'd':
          double d1 = var1 != null ? var1.get_double () : 0.0;
          double d2 = var2 != null ? var2.get_double () : 0.0;
          result = compare_double (d1, d2);
          break;
        default:
          return 0;
      }

      return result * multiplier;
    }

    private static int compare_int (int a, int b)
    {
      return a > b ? 1 : a == b ? 0 : -1;
    }

    private static int compare_uint (uint a, uint b)
    {
      return a > b ? 1 : a == b ? 0 : -1;
    }

    private static int compare_int64 (int64 a, int64 b)
    {
      return a > b ? 1 : a == b ? 0 : -1;
    }

    private static int compare_uint64 (uint64 a, uint64 b)
    {
      return a > b ? 1 : a == b ? 0 : -1;
    }

    private static int compare_double (double a, double b)
    {
      return a > b ? 1 : a == b ? 0 : -1;
    }
  }

  private const string SOURCES_FILTER_ID = "unity-sources";

  public unowned AggregatorScope owner { private get; construct; }
  private HashTable<string, ScopeChannel> _channels;
  private uint _dbus_id;
  private DBusConnection? _dbus_connection;
  private ScopeTracker _scopes;
  private Sorter[] _sorters;
  private Sorter[] _constraints;
  private CategoryMerger category_merger;
  private Rand _rand;

  public Dee.SerializableModel categories_model { get; set; }
  public Dee.SerializableModel filters_model { get; set; }

  /* Make sure the object doesn't reference itself, we do want it to be
   * properly destroyed */
  private MergeStrategy? _merge_strategy = null;
  public MergeStrategy? merge_strategy
  {
    internal get { return _merge_strategy != null ? _merge_strategy : this; }
    set { _merge_strategy = value != this ? value : null; }
  }

  /* we need notifications on this property */
  public ViewType view_type { get; set; }

  public AggregatorScopeImpl (AggregatorScope owner)
  {
    Object (owner: owner);
  }

  static bool measure_requests;

  static construct
  {
    measure_requests =
      Environment.get_variable (VAR_MEASURED_SEARCHES) != null;
  }

  construct
  {
    _rand = new Rand ();
    _channels = new HashTable<string, ScopeChannel> (str_hash, str_equal);
    _scopes = new ScopeTracker ();
    _scopes.results_invalidated.connect (on_results_invalidated);
    _scopes.proxy_category_model_changed.connect (on_proxy_categories_changed);
    merge_strategy = this;
    create_models ();
  }

  // keep the scope list in a set for fast lookup
  private static HashTable<string, unowned string> disabled_scope_ids;

  private static bool is_scope_disabled (string scope_id)
  {
    if (disabled_scope_ids == null)
    {
      disabled_scope_ids = new HashTable<string, unowned string> (str_hash, str_equal);
      var pref_man = PreferencesManager.get_default ();
      pref_man.notify["disabled-scopes"].connect (update_disabled_scopes);
      update_disabled_scopes ();
    }

    return scope_id in disabled_scope_ids;
  }

  private static void update_disabled_scopes ()
  {
    var pref_man = PreferencesManager.get_default ();
    disabled_scope_ids.remove_all ();
    foreach (unowned string scope_id in pref_man.disabled_scopes)
    {
      disabled_scope_ids.add (scope_id);
    }
  }

  public GLib.List<weak string> subscope_ids ()
  {
    return _scopes.scope_ids_for_proxies ();
  }

  /* Create usable name prefix for the models */
  private string create_dbus_name ()
  {
    /* We randomize the names to avoid conflicts to ensure that we always
     * have a clean start (no processes hanging around that would cause
     * our models to not be the leaders)
     */
    var t = get_monotonic_time ();
    const string format_string = "com.canonical.Unity.Master.Scope.%s.T%" + int64.FORMAT + "%d";
    var dbus_name = format_string.printf (Path.get_basename (owner.dbus_path),
                                          t, _rand.int_range (0, 10000));
    return dbus_name;
  }

  private void create_models ()
  {
    /* Schema definitions come from the Lens specification */
    categories_model = new Dee.SequenceModel ();
    categories_model.set_schema_full (CATEGORIES_SCHEMA);

    filters_model = new Dee.SequenceModel ();
    filters_model.set_schema_full (FILTERS_SCHEMA);
  }

  public void export () throws IOError
  {
    _dbus_connection = Bus.get_sync (BusType.SESSION);
    _dbus_id = _dbus_connection.register_object (owner.dbus_path,
                                                 this as ScopeService);
  }

  public void unexport ()
  {
    if (_dbus_id != 0)
    {
      _dbus_connection.unregister_object (_dbus_id);
      _dbus_id = 0;
      _dbus_connection = null;
    }

    // get rid of open channels
    string[] channel_ids = {};
    foreach (unowned string channel_id in _channels.get_keys ())
    {
      channel_ids += channel_id;
    }
    foreach (unowned string channel_id in channel_ids)
    {
      _scopes.unregister_channel (channel_id);
      _channels.remove (channel_id);
    }
  }

  public void set_categories (List<unowned Category> categories)
  {
    bool categories_model_empty = categories_model.get_n_rows () == 0;
    if (!categories_model_empty)
    {
      // we support only appending new categories, no changes/deletes
      unowned List<unowned Category> cats = categories;
      uint cats_length = categories.length ();
      bool data_matches = cats_length >= categories_model.get_n_rows ();

      var iter = categories_model.get_first_iter ();
      var end_iter = categories_model.get_last_iter ();
      while (data_matches && iter != end_iter)
      {
        data_matches &= cats.data.id == categories_model.get_string (iter, 0);
        // FIXME: emit row-changed if other props changed
        iter = categories_model.next (iter);
        cats = cats.next;
      }

      if (!data_matches)
      {
        warning ("Categories can only be added, ignoring request");
        return;
      }
      else
      {
        categories = cats;
      }
    }

    foreach (unowned Category category in categories)
    {
      string icon_hint = Utils.icon_to_string (category.icon_hint);
      categories_model.append (category.id,
                               category.name,
                               icon_hint,
                               category.renderer,
                               Utils.hash_table_to_asv (category.get_hints ()));
    }

    if (_dbus_id != 0)
    {
      queue_property_notification ("Categories",
                                   new Variant.variant (this.categories));
    }
  }

  public void set_filters (List<unowned Filter> filters)
  {
    filters_model.clear ();

    foreach (unowned Filter filter in filters)
    {
      //filter.changed.connect (on_filter_option_changed);
    }

    List<unowned Filter> filters_and_sources = filters.copy ();
    if (owner.sources.options.length () > 0)
      filters_and_sources.append (owner.sources);

    Variant data[8];
    foreach (unowned Filter filter in filters_and_sources)
    {
      var serialized_filter = filter.serialize ();
      for (size_t i = 0; i < serialized_filter.n_children (); i++)
        data[i] = serialized_filter.get_child_value (i);

      filters_model.append_row (data);
    }

    if (_dbus_id != 0)
    {
      queue_property_notification ("Filters",
                                   new Variant.variant (this.filters));
    }

    foreach (var channel in _channels.get_values ())
    {
      channel.set_filter_base (filters_model);
    }
  }

  private void on_results_invalidated (ChannelUpdateFlags flags)
  {
    // results of a subscope got invalidated, propagate the change if necesary
    if (ChannelUpdateFlags.DEFAULT in flags)
    {
      var channel_type = ChannelType.DEFAULT;
      if (invalidate_last_search_for_channel (channel_type))
        this.results_invalidated (channel_type);
    }
    if (ChannelUpdateFlags.GLOBAL in flags)
    {
      var channel_type = ChannelType.GLOBAL;
      if (invalidate_last_search_for_channel (channel_type))
        this.results_invalidated (channel_type);
    }
  }

  private void channel_owner_lost (ScopeChannel channel)
  {
    var empty = new HashTable<string, Variant> (str_hash, str_equal);
    close_channel.begin (channel.id, empty, null);
  }

  private void on_proxy_categories_changed (string scope_id, ScopeProxy proxy)
  {
    if (category_merger is CategoryMergerByField)
    {
      (category_merger as CategoryMergerByField).map_subscope_categories (scope_id, proxy.categories_model);
    }

    var categories_updated = category_merger.merge_metadata (scope_id, proxy.categories_model, categories_model);
    if (categories_updated && _dbus_id != 0)
    {
      queue_property_notification ("Categories", new Variant.variant (this.categories));
    }
  }

  private bool invalidate_last_search_for_channel (ChannelType channel_type)
  {
    bool any_invalidated = false;
    foreach (var channel in _channels.get_values ())
    {
      if (channel.channel_type == channel_type)
      {
        channel.last_search = null;
        any_invalidated = true;
      }
    }
    return any_invalidated;
  }

  public void queue_search_for_type (SearchType search_type)
  {
    var flags = search_type == SearchType.GLOBAL ?
      ChannelUpdateFlags.GLOBAL : ChannelUpdateFlags.DEFAULT;
    on_results_invalidated (flags);
  }

  public void invalidate_search (SearchType search_type)
  {
    // not really relevant for master scopes
  }

  private VariantBuilder? changed_props;

  public void queue_property_notification (string prop_name, Variant prop_value)
  {
    if (_dbus_id == 0) return;

    bool schedule_emit = changed_props == null;
    if (changed_props == null)
      changed_props = new VariantBuilder (new VariantType ("a{sv}"));

    changed_props.add ("{sv}", prop_name, prop_value);

    if (schedule_emit)
    {
      Idle.add (() =>
      {
        var invalidated = new Variant.array (new VariantType ("s"), {});
        try
        {
          _dbus_connection.emit_signal (null, owner.dbus_path,
                                        "org.freedesktop.DBus.Properties",
                                        "PropertiesChanged",
                                        new Variant ("(sa{sv}@as)",
                                                     ScopeService.INTERFACE_NAME,
                                                     changed_props,
                                                     invalidated));
        }
        catch (Error err)
        {
          warning ("%s", err.message);
        }
        changed_props = null;
        return false;
      });
    }
  }



  public void add_sorter (uint category_index, string field,
                          AggregatorScope.SortFlags flags)
  {
    string? schema = null;
    bool is_base_column = field in RESULTS_COLUMN_NAMES;
    bool field_found = false;

    foreach (unowned Schema.FieldInfo? info in owner.schema.get_fields ())
    {
      if (info.name == field)
      {
        schema = info.schema;
        field_found = true;
        break;
      }
    }
    // ensure the field name is valid
    if (!is_base_column && !field_found)
    {
      critical ("Field name '%s' is not valid for this scope", field);
      return;
    }

    // get column index
    int col_index = -1;
    for (int i = 0; i < RESULTS_COLUMN_NAMES.length; i++)
    {
      if (field == RESULTS_COLUMN_NAMES[i])
      {
        col_index = i;
        break;
      }
    }

    if (col_index >= 0)
      schema = RESULTS_SCHEMA[col_index];

    if (new VariantType (schema).is_basic () == false)
    {
      critical ("Only basic types can be sorted, '%s' is not supported",
                schema);
      return;
    }

    var sorter = Sorter ();
    sorter.category = (int) category_index;
    sorter.column_index = col_index < 0 ? RESULTS_COLUMN_NAMES.length - 1 : col_index;
    sorter.field_name = col_index < 0 ? field : null;
    sorter.schema = schema[0];
    sorter.multiplier = AggregatorScope.SortFlags.DESCENDING in flags ? -1 : 1;

    _sorters += (owned) sorter;
  }

  public void add_constraint (int category_index, string field)
  {
    string? schema = null;
    bool is_base_column = field in RESULTS_COLUMN_NAMES;
    bool field_found = false;

    foreach (unowned Schema.FieldInfo? info in owner.schema.get_fields ())
    {
      if (info.name == field)
      {
        schema = info.schema;
        field_found = true;
        break;
      }
    }
    // ensure the field name is valid
    if (!is_base_column && !field_found)
    {
      critical ("Field name '%s' is not valid for this scope", field);
      return;
    }

    // get column index
    int col_index = -1;
    for (int i = 0; i < RESULTS_COLUMN_NAMES.length; i++)
    {
      if (field == RESULTS_COLUMN_NAMES[i])
      {
        col_index = i;
        break;
      }
    }

    if (col_index >= 0)
      schema = RESULTS_SCHEMA[col_index];

    if (new VariantType (schema).is_basic () == false)
    {
      critical ("Only basic types can be sorted, '%s' is not supported",
                schema);
      return;
    }

    if (category_index >= 0)
    {
      // we need a category sorter
      bool category_sorter_present = false;
      int category_col_index = -1;
      for (int i = 0; i < RESULTS_COLUMN_NAMES.length; i++)
      {
        if (RESULTS_COLUMN_NAMES[i] == "category")
        {
          category_col_index = i;
          break;
        }
      }
      warn_if_fail (category_col_index >= 0);
      foreach (unowned Sorter it_sorter in _constraints)
      {
        if (it_sorter.column_index == category_col_index)
        {
          category_sorter_present = true;
          break;
        }
      }
      if (!category_sorter_present) add_constraint (-1, "category");
    }

    var sorter = Sorter ();
    sorter.category = category_index;
    sorter.column_index = col_index < 0 ? RESULTS_COLUMN_NAMES.length - 1 : col_index;
    sorter.field_name = col_index < 0 ? field : null;
    sorter.schema = schema[0];
    sorter.multiplier = 1;

    foreach (unowned Sorter it_sorter in _constraints)
    {
      // check for duplicate constraints
      if (it_sorter.category == sorter.category && 
          it_sorter.column_index == sorter.column_index &&
          it_sorter.field_name == sorter.field_name &&
          it_sorter.schema == sorter.schema)
      {
        warning ("Trying to add duplicate constraint, ignoring");
        return;
      }
    }

    _constraints += (owned) sorter;
  }

  private static int apply_sorters (Variant[] row1, Variant[] row2,
                                    uint category, Sorter[] sorters)
  {
    foreach (unowned Sorter sorter in sorters)
    {
      if (sorter.category >= 0 && sorter.category != category) continue;
      int sorter_result = sorter.apply (row1, row2);
      if (sorter_result != 0) return sorter_result;
    }
    return 0;
  }

  /* MergeStrategy implementation */
  private unowned Dee.ModelIter? merge_result (string scope_id,
                                               Dee.Model target, Variant[] row)
  {
    // remap category index in the result
    uint row_category = row[ResultColumn.CATEGORY].get_uint32 ();
    int cat_idx = category_merger.remap (scope_id, row_category);
    if (cat_idx >= 0)
    {
      row[ResultColumn.CATEGORY] = new GLib.Variant.uint32 (cat_idx);
    }
    else
    {
      warning ("Unable to remap category %u for %s", row_category, scope_id);
      return null;
    }

    // check for duplicates
    if (_constraints.length > 0)
    {
      /* the lookups need to be fast, so keeping a FilterModel on top
       * of the real model that's sorted according to the de-dup fields */
      var dedup_model = target.get_qdata<Dee.Model> (ScopeTracker.DEDUP_MODEL_QUARK);
      if (dedup_model == null)
      {
        warn_if_fail (target.get_n_rows () == 0);
        var filter = Dee.Filter.new (() => {}, // no MapFunc
                                     (orig_model, orig_iter, m) =>
        {
          Variant row_data[9];
          orig_model.get_row_static (orig_iter, row_data);
          var iter = m.find_row_sorted (row_data, (row1, row2) =>
          {
            uint category = row1[ResultColumn.CATEGORY].get_uint32 ();
            return apply_sorters (row1, row2, category, _constraints);
          }, null);
          m.insert_iter_before (orig_iter, iter);
          return true;
        });
        dedup_model = new Dee.FilterModel (target, filter);
        // eek, circular reference
        target.set_qdata (ScopeTracker.DEDUP_MODEL_QUARK, dedup_model);
      }
      bool found;
      bool fell_through = false;
      dedup_model.find_row_sorted (row, (row1, row2) =>
      {
        uint category = row1[ResultColumn.CATEGORY].get_uint32 ();
        // customized version of apply_sorters that's suitable for dedup
        for (int i = 0; i < _constraints.length; i++)
        {
          unowned Sorter sorter = _constraints[i];
          if (sorter.category >= 0 && sorter.category != category) continue;
          int sorter_result = sorter.apply (row1, row2);
          if (sorter_result != 0 || i == _constraints.length - 1)
            return sorter_result;
        }
        fell_through = true;
        return 0;
      }, out found);
      if (found && !fell_through) return null;
    }

    return target.insert_row_sorted (row, (row1, row2) =>
    {
      // first of all sort by categories
      uint category = row1[ResultColumn.CATEGORY].get_uint32 ();
      int cat_delta = (int) category -
                      (int) row2[ResultColumn.CATEGORY].get_uint32 ();
      if (cat_delta != 0) return cat_delta > 0 ? 1 : -1;

      return apply_sorters (row1, row2, category, _sorters);
    });
  }

  private unowned ScopeProxy? get_proxy_for_result (Variant? result_metadata,
                                                    out string? scope_id)
    throws ScopeError
  {
    if (result_metadata == null)
      throw new ScopeError.REQUEST_FAILED ("Unable to find scope proxy");

    if (!result_metadata.lookup ("scope-id", "s", out scope_id))
      throw new ScopeError.REQUEST_FAILED ("Unable to find scope proxy");

    return _scopes.get_proxy_for_scope_id (scope_id);
  }

  /*
   * DBus Interface Implementation
   */
  public async ActivationReplyRaw activate (
      string channel_id,
      Variant[] result_arr,
      uint action_type,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws IOError, ScopeError
  {
    var channel = get_channel_by_id (channel_id); // ensure the channel is valid

    string? scope_id;
    unowned ScopeProxy proxy;
    Variant metadata = result_arr[ResultColumn.METADATA];
    proxy = get_proxy_for_result (metadata, out scope_id);
    result_arr[ResultColumn.METADATA] = metadata.lookup_value ("content", null);

    var scope_result = ScopeResult ();
    scope_result.uri = result_arr[ResultColumn.URI].get_string ();
    scope_result.icon_hint = result_arr[ResultColumn.ICON_HINT].get_string ();
    scope_result.category = result_arr[ResultColumn.CATEGORY].get_uint32 ();
    scope_result.result_type = (ResultType) result_arr[ResultColumn.RESULT_TYPE].get_uint32 ();
    scope_result.mimetype = result_arr[ResultColumn.MIMETYPE].get_string ();
    scope_result.title = result_arr[ResultColumn.TITLE].get_string ();
    scope_result.comment = result_arr[ResultColumn.COMMENT].get_string ();
    scope_result.dnd_uri = result_arr[ResultColumn.DND_URI].get_string ();
    if (result_arr[ResultColumn.METADATA].get_type ().equal (VariantType.VARDICT))
    {
      scope_result.metadata = (HashTable<string, Variant>) result_arr[ResultColumn.METADATA];
    }

    if (scope_id == null)
    {
      throw new ScopeError.REQUEST_FAILED ("Unable to determine scope id!");
    }

    // arrays in async methods are not copied by default, force the copy
    var result_arr_cpy = result_arr;
    var activation_obj = new AggregatorActivation (channel_id, scope_id,
                                                   action_type, scope_result);
    activation_obj.hints = hints;

    var response = yield owner.activate (activation_obj);
    if (response != null)
    {
      var raw = ActivationReplyRaw ();
      raw.uri = scope_result.uri;
      if (response.goto_uri != null)
      {
          var stripped = response.goto_uri.strip ();
          if (stripped != "") raw.uri = stripped;
      }
      raw.handled = response.handled;
      raw.hints = response.get_hints ();

      return raw;
    }

    if (proxy == null)
    {
      if (action_type != Protocol.ActionType.PREVIEW_RESULT)
      {
        response = new ActivationResponse (HandledType.NOT_HANDLED);
      }
      else
      {
        response = new ActivationResponse.with_preview (GenericPreview.empty ());
      }
      var raw = ActivationReplyRaw ();
      raw.uri = scope_result.uri;
      raw.handled = response.handled;
      raw.hints = response.get_hints ();

      return raw;
    }

    /* proxy the request by default */
    try
    {
      return yield _scopes.activate_wrapper (channel, scope_id,
                                             (owned) result_arr_cpy,
                                             action_type, hints, cancellable);
    }
    catch (ScopeError scope_error)
    {
      throw scope_error;
    }
    catch (Error err)
    {
      throw new ScopeError.REQUEST_FAILED ("Unhandled error: %s".printf (err.message));
    }
  }

  public async HashTable<string, Variant> search (
      string channel_id,
      string search_string,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws IOError, ScopeError
  {
    var channel = get_channel_by_id (channel_id);
    var response = new HashTable<string, Variant> (str_hash, str_equal);

    var synchronizer = _scopes.get_synchronizer (channel_id);
    if (synchronizer == null)
    {
      var msg = "No synchronizer registered for channel %s".printf (channel_id);
      warning ("%s", msg);
      throw new ScopeError.REQUEST_FAILED (msg);
    }

    // if filters changed, invalidate last search
    unowned Variant filter_row_variant = hints[SEARCH_FILTER_ROW_HINT];
    if (filter_row_variant != null)
    {
      update_filter_state (channel, filter_row_variant);
    }

    unowned Variant subscopes_filter_variant = hints[SEARCH_SUBSCOPES_HINT];
    uint subscope_filter_tag = 0;
    string[] enabled_subscopes = {};
    if (subscopes_filter_variant != null && subscopes_filter_variant.get_type_string () == "as")
    {
      enabled_subscopes = (string[]) subscopes_filter_variant;
      subscope_filter_tag = string.joinv (";", enabled_subscopes).hash ();
    }

    bool invalidate_last_search = filter_row_variant != null;

    if (invalidate_last_search && channel.last_search != null)
    {
      channel.last_search.search_context.cancellable.cancel ();
      channel.last_search = null;
    }

    // did the search change?
    ScopeSearchBase? last_search = channel.last_search;
    if (last_search != null)
    {
      // FIXME: take result set's TTL into consideration when scopes
      //  properly set it
      if (last_search.search_context.search_query == search_string
          && channel.last_search_tag == subscope_filter_tag)
      {
        if (channel.is_search_running ())
        {
          yield channel.wait_for_search ();
        }
        if (last_search.search_context.cancellable.is_cancelled ())
        {
          throw new ScopeError.SEARCH_CANCELLED ("Search '%s' was cancelled", search_string);
        }
        var last_agg_search = last_search as AggregatedScopeSearch;
        // copy hints from last search (no-results message etc)
        HashTable<string, Variant>? last_hints = last_agg_search.get_reply_hints ();
        if (last_hints != null)
        {
          var hints_iter = HashTableIter<string, Variant> (last_hints);
          unowned string key;
          unowned Variant variant;
          while (hints_iter.next (out key, out variant))
            response.insert (key, variant);
        }

        response[SEARCH_SEQNUM_HINT] = new Variant.uint64 (channel.get_last_seqnum ());
        return response;
      }
      else
      {
        last_search.search_context.cancellable.cancel ();
      }
    }

    // clear the master/aggregated model so that results from scopes
    // that are not searched this time disappear
    synchronizer.clear ();

    // if this search will query fewer sources than the last one, there could
    // be a race where results from the last query start appearing for this
    // one (cause the sources took a while to complete the search)
    synchronizer.disable_all_providers ();

    var search_cancellable = Unity.Cancellable.create ();

    var result_set = new DeeResultSet.with_model (channel.backend_model);
    result_set.ttl = -1;
    result_set.flush_model = channel.transfer_model;
    AggregatedScopeSearch? aggsearch = null;

    uint timer_src_id = 0;
    var txn_sig_id = synchronizer.transaction_complete.connect ((src_model, scope_id) =>
    {
      if (search_cancellable.is_cancelled ()) return;
      // if we search for "f", "fi", "fir", "fire", we could get transaction
      // complete signal for the "f" search although we're waiting for "fire"
      // already, FIXME? but how? (tag results with "search_id"?)
      if (owner.automatic_flushing && timer_src_id == 0)
      {
        timer_src_id = Timeout.add_full (Priority.DEFAULT_IDLE,
                                         DEFAULT_TIMEOUT_INTERVAL_MS,
                                         () =>
        {
          if (!search_cancellable.is_cancelled ()) result_set.flush ();
          timer_src_id = 0;
          return false;
        });
      }
      if (scope_id == null)
      {
        warning ("Unknown origin scope id for model [%p]", src_model);
      }
      else
      {
        aggsearch.transaction_complete (scope_id);
      }
    });

    SearchContext search_context = SearchContext ();
    search_context.search_query = search_string;
    search_context.search_type = channel.get_search_type ();
    search_context.filter_state = channel.filters;
    search_context.search_metadata = SearchMetadata.create (hints);
    search_context.result_set = result_set;
    search_context.cancellable = search_cancellable;

    aggsearch = new AggregatedScopeSearch (owner, channel.id,
                                           hints, channel.backend_model);
    aggsearch.set_search_context (search_context);

    ulong sig_id = aggsearch.category_order_changed.connect ((indices) =>
    {
      if (indices.length != categories_model.get_n_rows ())
        warning ("Invalid number of category indices, expected %u, got %u", categories_model.get_n_rows (), indices.length);
      else
        category_order_changed (channel_id, indices);
    });

    channel.last_search = aggsearch;
    channel.last_search_tag = subscope_filter_tag;
    // we need to wait for the cancelled search to clean up the channel state
    if (channel.is_search_running ())
    {
      yield channel.wait_for_search ();
    }
    // don't even run the search if this search got cancelled meanwhile
    if (search_cancellable.is_cancelled ())
    {
      // FIXME: would be nice to have auto-disconnecting wrapper
      SignalHandler.disconnect (aggsearch, sig_id);
      SignalHandler.disconnect (synchronizer, txn_sig_id);
      if (timer_src_id != 0) Source.remove (timer_src_id);
      throw new ScopeError.SEARCH_CANCELLED ("Search '%s' was cancelled", search_string);
    }
    // "lock" the channel
    channel.set_state (ChannelState.SEARCH_ACTIVE);

    foreach (var provider in channel.get_pushed_models (search_string))
    {
      // ResultsSynchronizer.add_provider () will set this data
      unowned string provider_scope_id = provider.get_data<string> ("scope-id");
      if (subscope_filter_tag == 0 ||
        (subscope_filter_tag != 0 && provider_scope_id in enabled_subscopes))
      {
        synchronizer.copy_model (provider);
      }
    }

    int64 search_start_time = 0;
    if (measure_requests) search_start_time = get_monotonic_time ();
    int64 search_end_time = search_start_time;

    var glib_cancellable = search_cancellable.get_gcancellable ();
    ulong canc_sig_id = 0;
    uint canc_src_id = 0;
    bool was_cancelled = false;

    Unity.Trace.tracepoint ("search:start::scope=%s;query=%s", owner.id, search_string);

    // danger ahead, we're running the search in (possibly) different thread
    // and at the same time waiting for the cancellable while holding
    // channel lock (ChannelState set to SEARCH_ACTIVE), other searches won't
    // start until the state is set back to IDLE
    aggsearch.run_async (() =>
    {
      // careful, this callback can be running in a different thread
      if (measure_requests) search_end_time = get_monotonic_time ();
      Idle.add_full (Priority.DEFAULT, search.callback);
    });

    if (glib_cancellable != null)
    {
      canc_sig_id = glib_cancellable.connect (() =>
      {
        canc_src_id = Idle.add_full (Priority.DEFAULT, () =>
        {
          canc_src_id = 0;
          was_cancelled = true;
          search.callback ();
          return false;
        });
      });
    }

    yield; // call virtual search method of the public API

    if (canc_sig_id != 0) glib_cancellable.disconnect (canc_sig_id);
    SignalHandler.disconnect (aggsearch, sig_id);
    SignalHandler.disconnect (synchronizer, txn_sig_id);
    if (timer_src_id != 0) Source.remove (timer_src_id);
    if (canc_src_id != 0) Source.remove (canc_src_id);

    // unlock the channel
    channel.set_state (ChannelState.IDLE);

    if (was_cancelled)
    {
      // this means the run_async is still in progress, and we have to wait for
      // it cause it's not marked as owned, nor having scope="async",
      // therefore the data associated with this search invocation has to
      // be valid when the callback is invoked
      yield;
    }

    Unity.Trace.tracepoint ("search:end::scope=%s;query=%s", owner.id, search_string);

    if (search_cancellable.is_cancelled ())
    {
      throw new ScopeError.SEARCH_CANCELLED ("Search '%s' was cancelled", search_string);
    }

    // copy reply hints into response hash
    HashTable<string, Variant>? reply_hints = aggsearch.get_reply_hints ();
    if (reply_hints != null)
    {
      HashTableIter<string, Variant> iter = HashTableIter<string, Variant> (reply_hints);
      unowned string key;
      unowned Variant variant;
      while (iter.next (out key, out variant))
        response.insert (key, variant);
    }

    result_set.flush ();
    response[SEARCH_SEQNUM_HINT] = new Variant.uint64 (channel.get_last_seqnum ());
    if (measure_requests)
    {
      int64 delta_us = search_end_time - search_start_time;
      double delta = delta_us / 1000000.0;
      response[SEARCH_TIME_HINT] = new Variant.double (delta);
    }

    if (cancellable != null) cancellable.set_error_if_cancelled ();
    return response;
  }

  public async HashTable<string, Variant> search_scope (
      Unity.AggregatedScopeSearch search, string scope_id,
      string search_string, SearchType search_type,
      HashTable<string, Variant>? hints,
      GLib.Cancellable? cancellable) throws Error
  {
    if (is_scope_disabled (scope_id))
    {
      return new HashTable<string, Variant> (null, null);
    }

    // remove the filter hints
    if (!owner.proxy_filter_hints)
      search.hints.remove (SEARCH_FILTER_ROW_HINT);

    HashTable<string, Variant>? combined_hints = null;
    if (hints != null)
    {
      combined_hints = new HashTable<string, Variant> (str_hash, str_equal);
      HFunc<string, Variant> combiner = (k, v) =>
      {
        combined_hints.insert (k, v);
      };
      hints.foreach (combiner);
      search.hints.foreach (combiner);
    }

    if (category_merger is CategoryMergerByScope)
      (category_merger as CategoryMergerByScope).add_scope_mapping (owner, scope_id);

    var channel_type = search_type == SearchType.DEFAULT ?
      ChannelType.DEFAULT : ChannelType.GLOBAL;
    var channel = get_channel_by_id (search.channel_id);
    var res = yield _scopes.search_wrapper (channel,
                                            channel_type,
                                            search_string,
                                            combined_hints != null ? combined_hints : search.hints,
                                            scope_id,
                                            cancellable);
    res.foreach ((key, variant) =>
    {
      if (key != SEARCH_SEQNUM_HINT)
      {
        search.set_reply_hint (key, variant);
      }
    });
    return res;
  }

  public async void push_results_to_scope (
      string channel_id,
      string search_string,
      string scope_id,
      Dee.SerializableModel results_model,
      string[] category_ids,
      GLib.Cancellable? cancellable) throws Error
  {
    if (!("-" in scope_id))
    {
      throw new ScopeError.REQUEST_FAILED ("Incorrect scope_id \"%s\"". printf (scope_id));
    }

    if (is_scope_disabled (scope_id))
    {
      throw new ScopeError.REQUEST_FAILED ("Scope is disabled");
    }

    // get the master scope id
    var parts = scope_id.split ("-", 2);
    var master_scope_id = "%s.scope".printf (parts[0]);
    
    if (category_merger is CategoryMergerByScope)
      (category_merger as CategoryMergerByScope).add_scope_mapping (owner, master_scope_id);

    Unity.Trace.tracepoint ("push:start::scope=%s;target=%s;query=%s",
                            master_scope_id, scope_id, search_string);

    try
    {
      var channel = get_channel_by_id (channel_id);
      yield _scopes.push_wrapper (channel, search_string, ChannelType.GLOBAL,
                                  master_scope_id, scope_id,
                                  results_model, category_ids, cancellable);
    }
    finally
    {
      Unity.Trace.tracepoint ("push:end::scope=%s;target=%s;query=%s",
                              master_scope_id, scope_id, search_string);
    }
  }

  public void push_filter_settings (string channel_id, FilterSet filters)
  {
    try
    {
      get_channel_by_id (channel_id);
    }
    catch (Error err)
    {
      warning ("Unexpected error: %s", err.message);
    }

    var filter_rows = new VariantBuilder (new VariantType ("a(ssssa{sv}bbb)"));
    foreach (unowned Filter f in filters.get_filters ())
    {
      filter_rows.add_value (f.serialize ());
    }

    filter_settings_changed (channel_id, filter_rows.end ());
  }

  private void update_filter_state (ScopeChannel channel,
                                    Variant changed_row) throws ScopeError
  {
    if (changed_row.get_type_string () != "(ssssa{sv}bbb)")
    {
      throw new ScopeError.REQUEST_FAILED ("Incorrect signature of filter-state (got '%s')".printf (changed_row.get_type_string ()));
    }

    string filter_id;
    changed_row.get_child (FilterColumn.ID, "s", out filter_id);
    var filter = channel.get_filter_by_id (filter_id);

    if (filter == null)
    {
      throw new ScopeError.REQUEST_FAILED ("Unable to find filter with id '%s'".printf (filter_id));
    }
    // update() will just update the hints, need to handle base props

    bool state;
    changed_row.get_child (FilterColumn.FILTERING, "b", out state);
    filter.filtering = state;
    changed_row.get_child (FilterColumn.COLLAPSED, "b", out state);
    filter.collapsed = state;
    filter.update (changed_row.get_child_value (FilterColumn.RENDERER_STATE));
  }

  public async string open_channel (
      uint channel_type,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable,
      BusName? sender = null,
      out HashTable<string, Variant> out_hints) throws IOError
  {
    Unity.AggregatorScope aggscope = owner as Unity.AggregatorScope;

    /* Create category merger on first channel request */
    if (category_merger == null)
    {
      if (aggscope.merge_mode == AggregatorScope.MergeMode.OWNER_SCOPE)
      {
        category_merger = new CategoryMergerByScope ();
      }
      else
      {
        category_merger = new CategoryMergerByField (categories_model, CategoryColumn.ID);
      }
    }

    ChannelFlags flags = ChannelFlags.from_hints (hints);
    var channel = new ScopeChannel ((ChannelType) channel_type);

    var schema = owner.schema;
    var required_schema = new HashTable<string, string> (str_hash, str_equal);
    var optional_schema = new HashTable<string, string> (str_hash, str_equal);
    foreach (unowned Unity.Schema.FieldInfo? field in schema.get_fields ())
    {
      if (field.type == Schema.FieldType.REQUIRED)
        required_schema[field.name] = field.schema;
      else
        optional_schema[field.name] = field.schema;
    }

    var model_name = channel.create_channel (create_dbus_name (),
                                             required_schema,
                                             optional_schema,
                                             filters_model,
                                             flags | ChannelFlags.NO_FILTERING);

    if (channel.transfer_model != null)
    {
      yield Internal.Utils.wait_for_model_synchronization (channel.transfer_model);
      if (sender != null)
      {
        channel.watch_owner (_dbus_connection, sender);
        channel.owner_lost.connect (this.channel_owner_lost);
      }
    }

    _channels[channel.id] = channel;
    _scopes.register_channel (owner.id, channel.id, channel.backend_model, merge_strategy);

    out_hints = new HashTable<string, Variant> (str_hash, str_equal);
    out_hints[CHANNEL_SWARM_NAME_HINT] = new Variant.string (model_name);

    return channel.id;
  }

  private ScopeChannel get_channel_by_id (string channel_id)
    throws ScopeError
  {
    unowned ScopeChannel channel = _channels[channel_id];
    if (channel == null)
      throw new ScopeError.INVALID_CHANNEL ("Invalid channel ID!");

    return channel;
  }

  public async void close_channel (
      string channel_id,
      HashTable<string, Variant> hints,
      GLib.Cancellable? cancellable) throws IOError, ScopeError
  {
    unowned ScopeChannel channel = _channels[channel_id];
    if (channel == null)
      throw new ScopeError.INVALID_CHANNEL ("Invalid channel ID!");

    _scopes.unregister_channel (channel_id);
    _channels.remove (channel_id);
  }

  public async void set_view_type (uint view_type_id) throws IOError
  {
    ViewType view_type = (ViewType) view_type_id;
    this.view_type = view_type;
  }

  public async void set_active_sources (
      string channel_id, string[] sources,
      GLib.Cancellable? cancellable) throws IOError
  {
    owner.set_active_sources_internal (sources);
  }

  public async HashTable<string, Variant> push_results (
      string channel_id,
      string search_string,
      string source_scope_id,
      Variant model_v,
      string[] categories,
      GLib.Cancellable? cancellable = null) throws IOError, ScopeError
  {
    var channel = get_channel_by_id (channel_id);

    var model_obj = Dee.Serializable.parse (model_v, typeof (Dee.SequenceModel));
    if (model_obj == null)
      throw new ScopeError.REQUEST_FAILED ("Can't deserialize model");

    var sync = _scopes.get_synchronizer (channel_id);
    if (sync == null)
      throw new ScopeError.REQUEST_FAILED ("No synchronizer for channel %s", channel_id);

    var merger = category_merger as CategoryMergerByField;
    if (merger != null)
    {
      merger.map_subscope_categories_from_list (source_scope_id, categories);
    }
    else
    {
      throw new ScopeError.REQUEST_FAILED ("Merging not implemented");
    }

    var provider = model_obj as Dee.SerializableModel;
    channel.register_pushed_model (search_string, provider);

    sync.add_provider (provider, source_scope_id);
    sync.copy_model (provider);

    var result = new HashTable<string, Variant> (str_hash, str_equal);
    result[SEARCH_SEQNUM_HINT] = new Variant.uint64 (channel.get_last_seqnum ());
    if (channel.transfer_model != null)
    {
      channel.transfer_model.flush_revision_queue ();
    }

    return result;
  }

  /* DBus properties */
  public int protocol_version { get { return 1; } }
  public bool visible { owned get { return owner.visible; } }
  public bool is_master { owned get { return owner.is_master; } }
  public string search_hint { owned get { return owner.search_hint ?? ""; } }
  public HashTable<string, string> metadata
  {
    owned get
    {
      var schema = owner.schema;
      var required_schema = new HashTable<string, string> (str_hash, str_equal);
      foreach (unowned Unity.Schema.FieldInfo? field in schema.get_fields ())
      {
        if (field.type == Schema.FieldType.REQUIRED)
          required_schema[field.name] = field.schema;
      }
      return required_schema;
    }
  }
  public HashTable<string, string> optional_metadata
  {
    owned get
    {
      var schema = owner.schema;
      var optional_schema = new HashTable<string, string> (str_hash, str_equal);
      foreach (unowned Unity.Schema.FieldInfo? field in schema.get_fields ())
      {
        if (field.type == Schema.FieldType.OPTIONAL)
          optional_schema[field.name] = field.schema;
      }
      return optional_schema;
    }
  }
  public Variant categories
  {
    owned get { return categories_model.serialize (); }
  }
  public Variant filters
  {
    owned get { return filters_model.serialize (); }
  }
  public HashTable<string, Variant> hints
  {
    owned get { return new HashTable<string, Variant> (null, null); }
  }
}

} /* namespace Unity.Internal */
