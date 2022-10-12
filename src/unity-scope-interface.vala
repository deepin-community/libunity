/*
 * Copyright (C) 2013 Canonical, Ltd.
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
 * Authored by Michal Hruby <michal.hruby@canonical.com>
 *
 */

namespace Unity
{

public const int SCOPE_API_VERSION = 7;

public extern int scope_module_get_version ();
public extern List<AbstractScope> scope_module_load_scopes () throws Error;

public enum SearchType
{
  DEFAULT,
  GLOBAL,

  N_TYPES
}

public enum ResultType
{
  DEFAULT,
  PERSONAL,
  SEMI_PERSONAL
}

public class FilterSet: Object
{
  private List<Filter> filters;
  public virtual void add (Filter filter) { filters.append (filter); }
  public virtual unowned Filter? get_filter_by_id (string filter_id)
  {
    foreach (unowned Filter filter in filters)
    {
      if (filter.id == filter_id) return filter;
    }

    return null;
  }

  public virtual List<unowned Filter> get_filters ()
  {
    return filters.copy ();
  }

  construct
  {
    filters = new List<Filter> ();
  }
}

public class CategorySet: Object
{
  private List<Category> categories;
  public virtual void add (Category category) { categories.append (category); }
  public virtual List<unowned Category> get_categories ()
  {
    return categories.copy ();
  }

  construct
  {
    categories = new List<Category> ();
  }
}

public class Schema: Object
{
  private List<FieldInfo?> fields;

  public enum FieldType
  {
    OPTIONAL,
    REQUIRED
  }

  public struct FieldInfo
  {
    string name;
    string schema;
    FieldType type;
    FieldInfo (string field_name, string field_schema, FieldType field_type)
    {
      this.name = field_name;
      this.schema = field_schema;
      this.type = field_type;
    }
  }

  public virtual void add_field (string name, string schema, FieldType type)
  {
    if (fields == null) fields = new List<FieldInfo?> ();
    fields.append (FieldInfo (name, schema, type));
  }

  public virtual List<unowned FieldInfo?> get_fields ()
  {
    return fields.copy ();
  }
}

public struct ScopeResult
{
  public string uri;
  public string icon_hint;
  public uint category;
  public ResultType result_type;
  public string mimetype;
  public string title;
  public string comment;
  public string dnd_uri;
  public HashTable<string, Variant>? metadata;

  /**
   * Create a new ScopeResult
   *
   * This method will create a new heap-allocated ScopeResult.
   * It is primarily meant for low-level language bindings, to ensure correct
   * memory management of the individual fields in the struct.
   */
  public static ScopeResult? create (string uri, string? icon_hint,
                                     uint category, ResultType result_type,
                                     string mimetype, string title,
                                     string comment, string dnd_uri,
                                     HashTable<string, Variant> metadata)
  {
    ScopeResult? result = ScopeResult ();
    result.uri = uri;
    result.icon_hint = icon_hint;
    result.category = category;
    result.result_type = result_type;
    result.mimetype = mimetype;
    result.title = title;
    result.comment = comment;
    result.dnd_uri = dnd_uri;
    result.metadata = metadata;

    return result;
  }

  /**
   * Create a new ScopeResult from a tuple variant
   *
   * This method will create a new heap-allocated ScopeResult.
   * It is primarily meant for low-level language bindings.
   */
  public static ScopeResult? create_from_variant (Variant variant)
  {
    const string EXPECTED_SIG = "(ssuussssa{sv})";
    if (variant.get_type_string () != EXPECTED_SIG)
    {
      warning ("Incorrect variant signature, expected \"%s\", got \"%s\"",
               EXPECTED_SIG, variant.get_type_string ());
      return null;
    }
    Variant dict;
    // careful here, using dark corners of vala compiler to not copy everything
    ScopeResult real_result = ScopeResult ();
    unowned ScopeResult result = real_result;

    variant.get ("(&s&suu&s&s&s&s@a{sv})",
                 out result.uri, out result.icon_hint, out result.category,
                 out result.result_type, out result.mimetype, out result.title,
                 out result.comment, out result.dnd_uri, out dict);

    HashTable<string, Variant> metadata = (HashTable<string, Variant>) dict;
    result.metadata = metadata;

    return result;
  }
}

public abstract class Cancellable: Object
{
  public abstract void cancel ();
  public abstract bool is_cancelled ();

  /**
   * Instantiate a default implementation of the Cancellable
   *
   * Create a new instance of Cancellable.
   */
  public static Cancellable create ()
  {
    return new Internal.GLibCancellable ();
  }

  /**
   * Return a GCancellable that can be used to monitor this cancellable.
   */
  public virtual GLib.Cancellable? get_gcancellable ()
  {
      return null;
  }
}

public delegate void ScopeSearchBaseCallback (ScopeSearchBase instance);

public abstract class ScopeSearchBase : Object
{
  public SearchContext? search_context;

  /**
   * Abstract method where the search is performed
   *
   * Scopes need to implement this method and add results to the ResultSet
   * which was passed to the {@link Unity.AbstractScope.create_search_for_query}.
   * By the time this method returns, the ResultSet is considered complete.
   */
  public abstract void run ();
  /**
   * Virtual method to perform the search asynchronously
   *
   * The default implementation of this method will spawn a new thread,
   * call the run() method (which is synchronous) inside the thread, and
   * invoke the callback when run() returns.
   * Implementations that perform searches asynchronously should override
   * this method as well as run() method.
   *
   * @param async_callback Callback to invoke when the search finishes
   */
  public virtual void run_async (ScopeSearchBaseCallback async_callback)
  {
    new Thread<void*> ("search-thread", () =>
    {
      run ();
      async_callback (this);
      return null;
    });
  }

  /**
   * Set associated SearchContext
   *
   * This method should be called inside 
   * Unity.AbstractScope.create_search_for_query() after instantiating your
   * ScopeSearchBase subclass. It will ensure that all search_context fields
   * are properly initialized.
   */
  public virtual void set_search_context (SearchContext ctx)
  {
    search_context = ctx;
  }
}

public enum SerializationType
{
  BINARY,
  JSON
}

public abstract class ResultSet: Object
{
  public int ttl;
  public abstract void add_result (ScopeResult result);

  /**
   * Add a result from a tuple variant
   *
   * This method will add a new result to the result set from a variant.
   * The default implementation will transform the variant into a ScopeResult
   * and invoke the add_result() method.
   * The expected type of the variant is '(ssuussssa{sv})'.
   * It is primarily meant for low-level language bindings.
   */
  public virtual void add_result_from_variant (Variant variant)
  {
    const string EXPECTED_SIG = "(ssuussssa{sv})";
    if (variant.get_type_string () != EXPECTED_SIG)
    {
      warning ("Incorrect variant signature, expected \"%s\", got \"%s\"",
               EXPECTED_SIG, variant.get_type_string ());
      return;
    }
    Variant dict;
    // careful here, using dark corners of vala compiler to not copy everything
    ScopeResult real_result = ScopeResult ();
    unowned ScopeResult result = real_result;
    variant.get ("(&s&suu&s&s&s&s@a{sv})",
                 out result.uri, out result.icon_hint, out result.category,
                 out result.result_type, out result.mimetype, out result.title,
                 out result.comment, out result.dnd_uri, out dict);

    HashTable<string, Variant> metadata = (HashTable<string, Variant>) dict;
    result.metadata = metadata;

    add_result (result);
  }

  /**
   * Flush recently added results before continuing.
   *
   * Hint the transport to flush the ResultSet backend to ensure that results
   * are sent to the origin of the search. Note that this is just a hint
   * and it might be a noop or the request can be ignored
   * because of rate-limiting.
   */
  public virtual void flush ()
  {
  }
}

public abstract class AbstractPreview: Object
{
  public abstract uint8[] serialize_as (SerializationType serialization_type);
}

public delegate void AbstractPreviewCallback (ResultPreviewer previewer,
                                              AbstractPreview? preview);

public abstract class ResultPreviewer: Object
{
  public ScopeResult result;
  public SearchMetadata metadata;
  public Cancellable cancellable;

  public abstract AbstractPreview? run ();
  public virtual void run_async (AbstractPreviewCallback async_callback)
  {
    new Thread<void*> ("preview-thread", () =>
    {
      var preview = run ();
      async_callback (this, preview);
      return null;
    });
  }

  public void set_scope_result (ScopeResult scope_result)
  {
    this.result = scope_result;
  }

  public void set_search_metadata (SearchMetadata search_metadata)
  {
    this.metadata = search_metadata;
  }
}

public class SearchMetadata : Object
{
  private HashTable<string, Variant>? all_metadata;
  private GeoCoordinate? geo_coordinate;

  public string? locale
  {
    get
    {
      if (all_metadata == null) return null;
      Variant locale_v = all_metadata["locale"];
      if (locale_v == null) return null;
      return locale_v.get_string ();
    }
  }

  public string? form_factor
  {
    get
    {
      if (all_metadata == null) return null;
      Variant form_factor_v = all_metadata["form-factor"];
      if (form_factor_v == null) return null;
      return form_factor_v.get_string ();
    }
  }

  public GeoCoordinate? location
  {
    get
    {
      if (geo_coordinate != null) return geo_coordinate;
      const string EXPECTED_TYPE = "(iddd)";
      if (all_metadata == null) return null;
      Variant location_v = all_metadata["location"];
      if (location_v == null || location_v.get_type_string () != EXPECTED_TYPE)
        return null;

      double lat;
      double lon;
      double alt;
      int loc_type;
      location_v.get (EXPECTED_TYPE, out loc_type, out lat, out lon, out alt);
      if (loc_type == GeoCoordinate.CoordinateType.COORDINATE_3D)
        geo_coordinate = new GeoCoordinate.with_altitude (lat, lon, alt);
      else
        geo_coordinate = new GeoCoordinate (lat, lon);

      return geo_coordinate;
    }
  }

  public static SearchMetadata create (HashTable<string, Variant>? metadata)
  {
    var m = new SearchMetadata ();
    m.all_metadata = metadata;

    return m;
  }

  /**
   * Create a new SearchMetadata from a variant
   *
   * This method will create a new heap-allocated SearchMetadata.
   * The expected type for the variant is 'a{sv}'.
   * It is primarily meant for low-level language bindings.
   */
  public static SearchMetadata create_from_variant (Variant metadata)
  {
    var m = new SearchMetadata ();
    if (!metadata.is_of_type (VariantType.VARDICT))
    {
      warning ("Incorrect variant type for SearchMetadata.create_from_variant. "
               + "Expected %s, but got %s", VariantType.VARDICT.dup_string (),
               metadata.get_type_string ());
      return m;
    }
    m.all_metadata = (HashTable<string, Variant>) metadata;

    return m;
  }
}

public class GeoCoordinate: Object
{
  public double latitude;
  public double longitude;
  public double altitude;

  private enum CoordinateType
  {
    COORDINATE_2D,
    COORDINATE_3D
  }
  private CoordinateType coord_type;

  public GeoCoordinate (double latitude_, double longitude_)
  {
    latitude = latitude_;
    longitude = longitude_;
    coord_type = CoordinateType.COORDINATE_2D;
  }

  public GeoCoordinate.with_altitude (double latitude_, double longitude_,
                                      double altitude_)
  {
    latitude = latitude_;
    longitude = longitude_;
    altitude = altitude_;
    coord_type = CoordinateType.COORDINATE_3D;
  }

  public bool has_valid_altitude ()
  {
    return coord_type == CoordinateType.COORDINATE_3D;
  }
}

public struct SearchContext
{
  public string search_query;
  public SearchType search_type;
  public FilterSet filter_state;
  public SearchMetadata search_metadata;
  public ResultSet result_set;
  public Cancellable cancellable;

  /**
   * Create a new SearchContext
   *
   * This method will create a new heap-allocated SearchContext.
   * It is primarily meant for low-level language bindings, to ensure correct
   * memory management of the individual fields in the struct.
   */
  public static SearchContext? create (string search_query,
                                       SearchType search_type,
                                       FilterSet? filter_state,
                                       HashTable<string, Variant>? metadata,
                                       ResultSet result_set,
                                       Cancellable? cancellable)
  {
    SearchContext? ctx = SearchContext ();
    ctx.search_query = search_query;
    ctx.search_type = search_type;
    ctx.filter_state = filter_state;
    ctx.search_metadata = SearchMetadata.create (metadata);
    ctx.result_set = result_set;
    ctx.cancellable = cancellable;

    return ctx;
  }

  /**
   * Set search_metadata
   *
   * This method will create a new heap-allocated SearchContext.
   * It is primarily meant for low-level language bindings, to ensure correct
   * memory management of the individual fields in the struct.
   */
  public void set_search_metadata (SearchMetadata metadata)
  {
    this.search_metadata = metadata;
  }
}

public abstract class AbstractScope : GLib.Object
{
  public abstract ScopeSearchBase create_search_for_query (
      SearchContext search_context);
  public abstract ResultPreviewer create_previewer (ScopeResult result, SearchMetadata metadata);

  public abstract CategorySet get_categories ();
  public abstract FilterSet get_filters ();
  public abstract Schema get_schema ();
  /**
   * Getter for the search hint
   *
   * Search hint is usually displayed in a text entry widget when the search
   * string is empty.
   */
  public virtual string get_search_hint () { return ""; }

  /**
   * Get scope group name
   *
   * Each scope should provide a group name that's specific to the scope.
   * The name should be in the format similar to "com.example.Scope.ScopeName".
   */
  public abstract string get_group_name ();
  /**
   * Get the unique name of the scope
   *
   * Each scope needs to provide a unique name that identifies the scope.
   * The name should be in the format of "/com/example/Scope/ScopeName".
   * Note that the combination of scope group name and unique name needs to
   * be globally unique for each scope.
   */
  public abstract string get_unique_name ();

  public virtual ActivationResponse? activate (ScopeResult result, SearchMetadata metadata, string? action_id)
  {
    return null;
  }
  /**
   * Virtual method to normalize the search string
   *
   * Scope can override this method to specify custom normalization
   * of the search query. Normalized search query is usually stripped
   * of whitespace and lowercased.
   * The default implementation doesn't modify the search string in any way.
   */
  public virtual string normalize_search_query (string search_query)
  {
    return search_query;
  }

  /**
   * Invalidate previously sent results.
   *
   * If a scope knows that results it has sent out previously are no
   * longer valid, it can call this function to notify any interested
   * parties that they may want to perform a new search.
   */
  public void results_invalidated (SearchType search_type)
    requires (search_type < SearchType.N_TYPES)
  {
    this.results_invalidated_internal (search_type);
  }

  public signal void results_invalidated_internal (SearchType search_type);
}

} /* namespace Unity */
