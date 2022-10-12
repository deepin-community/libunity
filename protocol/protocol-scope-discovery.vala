/*
 * Copyright (C) 2012-2013 Canonical, Ltd.
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
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */

namespace Unity.Protocol
{

  private static const string SCOPES_DIR = "unity/scopes";

  errordomain ParseError
  {
    INVALID_METADATA,
    FILE_NOT_FOUND,
    INVALID_PATH,
    UNKNOWN_FILE
  }

  public class MetaDataColumnInfo
  {
    public string name { get; internal set; }
    public string type_id { get; internal set; }

    /**
     * Creates MetaDataColumnInfo from a string in format "name[t]", where 't' is GVariant type.
     */
    public MetaDataColumnInfo (string v) throws Error
    {
      int idx = v.index_of ("[");
      if (idx > 0 && v.index_of ("]") == v.length - 1) //there must be at least 1 character preceding [, thus > 0
      {
        name = v.substring (0, idx);
        type_id = v.slice (idx + 1, v.length - 1);
      }
      else
      {
        throw new ParseError.INVALID_METADATA ("Invalid format of meta data string");
      }
    }

    public virtual bool equals (MetaDataColumnInfo m)
    {
      return name == m.name && type_id == m.type_id;
    }
  }

  public class MetaDataSchemaInfo
  {
    public GLib.GenericArray<MetaDataColumnInfo> columns;

    /**
     * Creates a list of MetaDataColumnInfo objects from a semicolon-separated strings, e.g. "name1[type];name2[type2]...".
     *
     * @param mdinfo_str semicolon-separated name[type] entries
     * @return list of MetaDataColumnInfo objects
     */
    public static MetaDataSchemaInfo from_string (string mdinfo_str) throws Error
    {
      var schema_info = new MetaDataSchemaInfo ();
      schema_info.columns = new GLib.GenericArray<MetaDataColumnInfo> ();

      foreach (var m in mdinfo_str.split (";"))
      {
        if (m.length > 0)
        {
          var info = new MetaDataColumnInfo (m);
          schema_info.columns.add (info);
        }
      }
      return schema_info;
    }

    public HashTable<string, string> as_hash_table ()
    {
      HashTable<string, string> ret = new HashTable<string, string> (str_hash, str_equal);

      for (int i = 0; i < columns.length; i++)
      {
        unowned MetaDataColumnInfo info = columns[i];
        ret[info.name] = info.type_id;
      }

      return ret;
    }

    public bool equals (MetaDataSchemaInfo s)
    {
      if (columns.length != s.columns.length)
        return false;
      for (int i = 0; i < columns.length; i++)
      {
        if (!columns[i].equals (s.columns[i]))
          return false;
      }
      return true;
    }
  }

  public class CategoryDefinition
  {
    public string id { get; private set; }
    public string name { get; private set; }
    public string icon { get; private set; }
    public string? renderer { get; private set; }
    public string? content_type { get; private set; }
    public string? dedup_field { get; private set; }
    public string? sort_field { get; private set; }
    public string? renderer_hint { get; set; }

    internal static CategoryDefinition create (string id, string name,
                                               string icon,
                                               string? renderer = null,
                                               string? content_type = null,
                                               string? dedup_field = null,
                                               string? sort_field = null)
      requires (id[0] != '\0')
    {
      var def = new CategoryDefinition ();
      def.id = id;
      def.name = name;
      def.icon = icon;
      def.renderer = renderer;
      def.content_type = content_type;
      def.dedup_field = dedup_field;
      def.sort_field = sort_field;

      return def;
    }
  }

  public class FilterDefinition
  {
    public string id { get; private set; }
    public string filter_type { get; private set; }
    public string name { get; private set; }
    public string? sort_type { get; private set; }

    private string[] option_ids;
    private string[] option_names;
    
    public unowned string[] get_option_ids ()
    {
      return option_ids;
    }

    public unowned string[] get_option_names ()
    {
      return option_names;
    }

    public void add_option (string id, string name)
      requires (id[0] != '\0')
    {
      option_ids += id;
      option_names += name;
    }

    internal static FilterDefinition create (string id, string filter_type,
                                             string name,
                                             string? sort_type = null)
      requires (id[0] != '\0')
    {
      var def = new FilterDefinition ();
      def.id = id;
      def.filter_type = filter_type;
      def.name = name;
      def.sort_type = sort_type;

      return def;
    }
  }

  public class ScopeRegistry
  {
    private static const string SCOPE_GROUP = "Scope";
    private static const string DESKTOP_GROUP = "Desktop Entry";

    private static string[] scope_directories = null;
    private static string[] scope_file_prefixes = null;
    private static bool overrides_scope_dirs = false;

    private static string extract_scope_id (string path)
    {
      string? real_path = null;
      if (!Path.is_absolute (path))
      {
        var f = File.new_for_path (path);
        real_path = f.get_path ();
        path = real_path;
      }

      if (scope_file_prefixes == null) init_scope_file_prefixes ();

      string normalized_path = path.replace ("//", "/");

      foreach (unowned string prefix in scope_file_prefixes)
      {
        if (normalized_path.has_prefix (prefix))
        {
          string without_prefix = normalized_path.substring (prefix.length);

          if (Path.DIR_SEPARATOR_S in without_prefix)
            return without_prefix.replace (Path.DIR_SEPARATOR_S, "-");

          return without_prefix;
        }
      }

      return Path.get_basename (path);
    }

    internal static void init_scope_file_prefixes ()
    {
      if (scope_directories == null) init_scope_directories ();
      scope_file_prefixes = {};
      foreach (unowned string scope_dir in scope_directories)
      {
        var f = File.new_for_path (scope_dir);
        // this will resolve relative paths
        scope_file_prefixes += "%s/".printf (f.get_path ());
      }
    }

    internal static void init_scope_directories ()
    {
      var overriden_dirs = Environment.get_variable ("LIBUNITY_SCOPE_DIRECTORIES");
      overrides_scope_dirs = overriden_dirs != null;
      if (overriden_dirs == null)
      {
        scope_directories = {};
        var data_dirs = Environment.get_system_data_dirs ();
        foreach (unowned string data_dir in data_dirs)
        {
          scope_directories += Path.build_filename (data_dir, SCOPES_DIR);
        }
      }
      else
      {
        scope_directories = overriden_dirs.split (":");
      }
    }


    public class ScopeMetadata
    {
      private static string[] hidden_scope_ids;
      private const string SCOPE_SCHEMA = "com.canonical.Unity.Lenses";
      static construct
      {
        // the hidden scopes are not supposed to be changed, so no need
        // to monitor for dynamic changes
        update_hidden_scope_ids ();
      }

      internal static void update_hidden_scope_ids ()
      {
        var schema_src = SettingsSchemaSource.get_default().lookup (SCOPE_SCHEMA, false);

        if (schema_src != null)
        {
          var settings = new Settings.full (schema_src, null, null);
          hidden_scope_ids = settings.get_strv ("hidden-scopes");
        }
        else
        {
          hidden_scope_ids = {};
        }
      }

      /* careful here, although it's a private lib, keeping it
       * ABI compatible is a good idea (unity-core uses it) */
      public string id;
      public string domain;
      public string full_path;
      public string name;
      public string dbus_path;
      public string dbus_name;
      public string icon;
      public string category_icon;
      public MetaDataSchemaInfo? required_metadata;
      public MetaDataSchemaInfo? optional_metadata;
      public GLib.SList<string> keywords;
      public string type;
      public string description;
      public string search_hint;
      public bool is_master;
      public bool global_searches;
      public bool visible;
      public bool remote_content;
      public string query_binary;
      public string query_pattern;
      public string shortcut;
      public string no_content_hint;
      public bool no_export;
      public string module;
      public string module_type;
      public int timeout;

      private CategoryDefinition[] categories;
      private FilterDefinition[] filters;
      private string[] subscope_ids;
      private bool overrides_subscopes;

      public unowned CategoryDefinition[] get_categories ()
      {
        return categories;
      }
      public unowned FilterDefinition[] get_filters ()
      {
        return filters;
      }

      public unowned string[] get_subscope_ids ()
      {
        return subscope_ids;
      }

      internal bool get_overrides_subscopes ()
      {
        return overrides_subscopes;
      }

      public void load_from_key_file (KeyFile file) throws Error
      {
        this.domain = null;

        // Get the Gettext-Domain first, if it exists
        if (file.has_group (DESKTOP_GROUP) && file.has_key (DESKTOP_GROUP, "X-Ubuntu-Gettext-Domain"))
            this.domain = file.get_string (DESKTOP_GROUP, "X-Ubuntu-Gettext-Domain");

        // required fields
        this.name = dgettext(this.domain, file.get_string (SCOPE_GROUP, "Name"));
        // support deprecated DBusName / DBusPath, but require the new
        // GroupName & UniqueName
        if (file.has_key (SCOPE_GROUP, "DBusName"))
        {
          this.dbus_name = file.get_string (SCOPE_GROUP, "DBusName");
        }
        else
        {
          this.dbus_name = file.get_string (SCOPE_GROUP, "GroupName");
        }
        if (file.has_key (SCOPE_GROUP, "DBusPath"))
        {
          this.dbus_path = file.get_string (SCOPE_GROUP, "DBusPath");
        }
        else
        {
          this.dbus_path = file.get_string (SCOPE_GROUP, "UniqueName");
        }
        this.icon = file.get_string (SCOPE_GROUP, "Icon");
        this.type = file.get_string (SCOPE_GROUP, "Type");

        // optional fields
        if (file.has_key (SCOPE_GROUP, "IsMaster"))
          this.is_master = file.get_boolean (SCOPE_GROUP, "IsMaster");
        else
          this.is_master = false;

        if (file.has_key (SCOPE_GROUP, "Module"))
          this.module = file.get_string (SCOPE_GROUP, "Module");
        else
          this.module = null;

        if (file.has_key (SCOPE_GROUP, "ModuleType"))
          this.module_type = file.get_string (SCOPE_GROUP, "ModuleType");
        else
          this.module_type = null;

        if (file.has_key (SCOPE_GROUP, "Visible"))
          this.visible = file.get_boolean (SCOPE_GROUP, "Visible");
        else
          this.visible = true;

        if (file.has_key (SCOPE_GROUP, "GlobalSearches"))
          this.global_searches = file.get_boolean (SCOPE_GROUP, "GlobalSearches");
        else
          this.global_searches = true;

        if (file.has_key (SCOPE_GROUP, "RemoteContent"))
          this.remote_content = file.get_boolean (SCOPE_GROUP, "RemoteContent");
        else
          this.remote_content = false;

        if (file.has_key (SCOPE_GROUP, "QueryBinary"))
          this.query_binary = file.get_string (SCOPE_GROUP, "QueryBinary");

        if (file.has_key (SCOPE_GROUP, "CategoryIcon"))
          this.category_icon = file.get_string (SCOPE_GROUP, "CategoryIcon");

        if (file.has_key (SCOPE_GROUP, "QueryPattern"))
          this.query_pattern = file.get_string (SCOPE_GROUP, "QueryPattern");

        if (file.has_key (SCOPE_GROUP, "Description"))
          this.description = file.get_string (SCOPE_GROUP, "Description");

        if (file.has_key (SCOPE_GROUP, "SearchHint"))
          this.search_hint = dgettext (this.domain, file.get_string (SCOPE_GROUP, "SearchHint"));

        if (file.has_key (SCOPE_GROUP, "RequiredMetadata"))
          this.required_metadata = MetaDataSchemaInfo.from_string (file.get_string (SCOPE_GROUP, "RequiredMetadata"));

        if (file.has_key (SCOPE_GROUP, "OptionalMetadata"))
          this.optional_metadata = MetaDataSchemaInfo.from_string (file.get_string (SCOPE_GROUP, "OptionalMetadata"));

        if (file.has_key (SCOPE_GROUP, "Keywords"))
        {
          // split keywords
          this.keywords = new GLib.SList<string> ();
          foreach (var k in file.get_string (SCOPE_GROUP, "Keywords").split (";"))
          {
            if (k.length > 0)
              this.keywords.append (k);
          }
        }

        if (file.has_key (SCOPE_GROUP, "Shortcut"))
        {
          this.shortcut = file.get_string (SCOPE_GROUP, "Shortcut");
        }

        if (file.has_key (SCOPE_GROUP, "Timeout"))
        {
          this.timeout = file.get_integer (SCOPE_GROUP, "Timeout");
        }

        if (file.has_key (SCOPE_GROUP, "NoExport"))
        {
          this.no_export = file.get_boolean (SCOPE_GROUP, "NoExport");
        }
        else
        {
          this.no_export = false;
        }

        // key to specify subscope ids, so no discovery is needed

        if (file.has_key (SCOPE_GROUP, "NoContentHint"))
        {
          this.no_content_hint = dgettext (this.domain, file.get_string (SCOPE_GROUP, "NoContentHint"));
        }

        if (file.has_key (SCOPE_GROUP, "Subscopes"))
        {
          this.subscope_ids = file.get_string_list (SCOPE_GROUP, "Subscopes");
          this.overrides_subscopes = true;
        }

        const string FILTER_PREFIX = "Filter ";
        const string CATEGORY_PREFIX = "Category ";

        // parse categories and filters
        foreach (unowned string group_name in file.get_groups ())
        {
          var stripped = group_name.strip ();
          if (group_name.has_prefix (CATEGORY_PREFIX)
              && stripped.length >= CATEGORY_PREFIX.length + 1)
          {
            var id = stripped.substring (CATEGORY_PREFIX.length).strip ();
            var name = dgettext (this.domain, file.get_string (group_name, "Name"));
            var icon = file.get_string (group_name, "Icon");
            string? dedup_field = null;
            if (file.has_key (group_name, "DedupField"))
            {
              dedup_field = file.get_string (group_name, "DedupField");
            }

            string? sort_field = null;
            if (file.has_key (group_name, "SortField"))
            {
              sort_field = file.get_string (group_name, "SortField");
            }

            string? renderer = null;
            if (file.has_key (group_name, "Renderer"))
            {
              renderer = file.get_string (group_name, "Renderer");
            }

            string? cat_content_type = null;
            if (file.has_key (group_name, "ContentType"))
            {
              cat_content_type = file.get_string (group_name, "ContentType");
            }

            string? renderer_hint = null;
            if (file.has_key (group_name, "RendererHint"))
            {
              renderer_hint = file.get_string (group_name, "RendererHint");
            }

            var category_definition = CategoryDefinition.create (id, name, icon,
                                                                 renderer,
                                                                 cat_content_type,
                                                                 dedup_field,
                                                                 sort_field);
            if (category_definition != null)
            {
              category_definition.renderer_hint = renderer_hint;
              categories += category_definition;
            }
          }
          else if (group_name.has_prefix (FILTER_PREFIX)
              && stripped.length >= FILTER_PREFIX.length + 1)
          {
            var id = stripped.substring (FILTER_PREFIX.length).strip ();
            var type = file.get_string (group_name, "Type");
            var name = dgettext (this.domain, file.get_string (group_name, "Name"));
            string? sort_type = null;
            if (file.has_key (group_name, "SortType"))
            {
              sort_type = file.get_string (group_name, "SortType");
            }

            var filter_definition = FilterDefinition.create (id, type, name,
                                                             sort_type);
            // parse the options
            var option_ids = file.get_string_list (group_name, "OptionIDs");
            var option_names_str = dgettext (this.domain, file.get_string (group_name, "OptionNames"));
            // trailing ';' will cause extra split argument containing empty string, get rid of that
            if (option_names_str[option_names_str.length-1] == ';')
            {
              option_names_str.data[option_names_str.length-1] = 0;
            }
            var option_names = option_names_str.split (";");
            if (option_ids.length != option_names.length)
            {
              warning ("Number of elements of OptionIDs doesn't match OptionNames (%d vs %d)", option_ids.length, option_names.length);
            }
            for (int i = 0; i < option_ids.length && i < option_names.length; i++)
            {
              filter_definition.add_option (option_ids[i], option_names[i]);
            }

            if (filter_definition != null)
            {
              filters += filter_definition;
            }
          }
        }
      }

      /* Private method cause ScopeMetadata.full_path and .id are null */
      private static ScopeMetadata for_keyfile (KeyFile file) throws Error
      {
        ScopeMetadata data = new ScopeMetadata ();
        data.load_from_key_file (file);

        return data;
      }

      public static ScopeMetadata for_id (string scope_id) throws Error
      {
        debug ("for_id: %s", scope_id);

        if (scope_id in hidden_scope_ids)
          throw new ParseError.FILE_NOT_FOUND ("Scope is disabled: %s", scope_id);

        string full_path;
        var file = new KeyFile ();
        bool loaded;
        if (overrides_scope_dirs)
        {
          loaded = file.load_from_dirs (scope_id, scope_directories,
                                        out full_path, KeyFileFlags.NONE);
        }
        else
        {
          var path = "%s/%s".printf (SCOPES_DIR, scope_id);
          loaded = file.load_from_data_dirs (path, out full_path,
                                             KeyFileFlags.NONE);
        }

        if (!loaded)
          throw new ParseError.FILE_NOT_FOUND ("Scope not found: %s", scope_id);

        var data = ScopeMetadata.for_keyfile (file);
        data.id = scope_id;
        data.full_path = full_path;

        return data;
      }

      public static ScopeMetadata for_path (string path) throws Error
      {
        debug ("for_path: %s", path);

        bool loaded = true;
        string full_path;

        var keyfile = new KeyFile ();
        if (GLib.Path.is_absolute (path))
        {
          loaded = keyfile.load_from_file (path, KeyFileFlags.NONE);
          full_path = path;
        }
        else
        {
          loaded = keyfile.load_from_data_dirs (path, out full_path, KeyFileFlags.NONE);
        }

        if (!loaded)
          throw new ParseError.FILE_NOT_FOUND ("File not found: %s", path);

        ScopeMetadata data = ScopeMetadata.for_keyfile (keyfile);
        data.full_path = full_path;
        data.id = extract_scope_id (full_path);

        if (data.id in hidden_scope_ids)
          throw new ParseError.FILE_NOT_FOUND ("Scope is disabled: %s", data.id);

        return data;
      }
    }

    // node representing single scope, with optional sub-scopes (if master scope)
    public class ScopeRegistryNode
    {
      public ScopeMetadata scope_info;
      public GLib.SList<ScopeMetadata?>? sub_scopes;
    }

    // list of top-level scopes
    private SList<ScopeRegistryNode> scopes_ = new SList<ScopeRegistryNode> ();
    public GLib.SList<ScopeRegistryNode>? scopes
    {
      get { return scopes_; }
    }

    private ScopeRegistry ()
    {
    }

    static construct
    {
      init_scope_directories ();
    }

    /**
     * Build registry of all scopes in start_path.
     * start_path can be a directory, a .scope file path or just scope id (.scope file name, including extenstion).
     *
     * @param start_path starting directory or specific .scope file
     * @return registry of all scopes (if start_path is a dir) or just one scope and its subscopes.
     */
    public static async ScopeRegistry find_scopes (string? start_path) throws Error
    {
      var registry = new ScopeRegistry ();
      Node<ScopeMetadata?> root_node = new Node<ScopeMetadata?> (null);
      if (start_path == null)
      {
        foreach (unowned string scope_dir in scope_directories)
        {
          if (!FileUtils.test (scope_dir, FileTest.IS_DIR)) continue;
          try
          {
            yield build_scope_node_tree (root_node, scope_dir);
          }
          catch (Error e)
          {
            // we'll ignore errors from here
            warning ("Unable to process scope directory %s: %s",
                     scope_dir, e.message);
          }
        }
      }
      else
      {
        yield build_scope_node_tree (root_node, start_path);
      }

      registry.from_tree (root_node);
      return registry;
    }

    private static bool node_has_child_with_id (Node<ScopeMetadata> node,
                                                string scope_id,
                                                out unowned Node<ScopeMetadata> child)
    {
      bool scope_id_present = false;
      unowned Node<ScopeMetadata> found_child = null;
      node.children_foreach (TraverseFlags.ALL, (child_) =>
      {
        unowned Node<ScopeMetadata> child_node = child_;
        if (child_node.data.id == scope_id)
        {
          scope_id_present = true;
          found_child = child_node;
        }
      });

      child = found_child;

      return scope_id_present;
    }

    private static async void build_scope_node_tree (Node<ScopeMetadata> root_node,
                                                     string start_path)
      throws Error
    {
      debug ("build_scope_node_tree [level: %u]: %s", root_node.depth (), start_path);
      if (FileUtils.test (start_path, FileTest.IS_DIR))
      {
        var dir = GLib.Dir.open (start_path);
        string name;

        while ((name = dir.read_name ()) != null)
        {
          string filename = Path.build_filename (start_path, name);
          if (!filename.has_suffix (".scope")) continue;
          // failure of single scope shouldn't break processing of others scopes
          try
          {
            yield build_scope_node_tree (root_node, filename);
          }
          catch (Error e)
          {
            warning ("Failed to process '%s': %s", filename, e.message);
          }
        }
      }
      else
      {
        if (!start_path.has_suffix (".scope"))
        {
          throw new ParseError.UNKNOWN_FILE ("Unknown file type: \"%s\"", start_path);
        }
        debug ("Found scope file: %s", start_path);
        // this may throw, in such case don't process this scope
        // (and possibly its subscopes if it was master scope)
        ScopeMetadata? scope_data = ScopeMetadata.for_path (start_path);
        if (scope_data == null) return;

        // do we already have this scope in the tree?
        unowned Node<ScopeMetadata> child_node = null;
        bool scope_id_present = node_has_child_with_id (root_node,
                                                        scope_data.id,
                                                        out child_node);

        if (!scope_id_present)
        {
          // save the node in the tree
          child_node = root_node.append_data (scope_data);
        }

        assert (child_node != null);

        if (child_node.data.is_master)
        {
          // if master scope specifies its subscopes, don't try to merge
          // the children from multiple locations
          if (child_node.data.get_overrides_subscopes () &&
              child_node.n_children () == 0)
          {
            debug ("Scope %s overrides its children", child_node.data.id);
            unowned string[] subscopes = child_node.data.get_subscope_ids ();
            foreach (unowned string subscope_id in subscopes)
            {
              try
              {
                ScopeMetadata subscope_data = ScopeMetadata.for_id (subscope_id);
                if (subscope_data != null &&
                    !node_has_child_with_id (child_node, subscope_data.id, null))
                {
                  // FIXME: we're not building the complete tree here,
                  // but right now it's not needed
                  child_node.append_data (subscope_data);
                }
              }
              catch (Error e)
              {
                warning ("Failed to process '%s': %s", subscope_id, e.message);
              }
            }
          }
          else
          {
            /* This is a master scope, find its children in subdirectory */
            var scopefile = GLib.File.new_for_path (scope_data.full_path);
            var parent = scopefile.get_parent ();
            if (parent == null) return;
            string scope_name = remove_scope_extension (scope_data.id);

            string check_path = Path.build_filename (parent.get_path (), scope_name);
            if (!FileUtils.test (check_path, FileTest.IS_DIR)) return;
            yield build_scope_node_tree (child_node, check_path);
          }
        }
      }
    }

    private void from_tree (Node<ScopeMetadata> root_node)
    {
      // only 2 level traverse, anything deeper will be discarded
      root_node.children_foreach (TraverseFlags.ALL, (top_child_) =>
      {
        unowned Node<ScopeMetadata> top_child = top_child_;
        var scope_node = new ScopeRegistryNode ()
        {
          scope_info = top_child.data,
          sub_scopes = new GLib.SList<ScopeMetadata?> ()
        };

        top_child.children_foreach (TraverseFlags.ALL, (child_) =>
        {
          unowned Node<ScopeMetadata> child = child_;
          scope_node.sub_scopes.append (child.data);
        });

        this.scopes_.append (scope_node);
      });
    }

    internal static string remove_scope_extension (string scope_id)
    {
      if (scope_id.has_suffix (".scope"))
        return scope_id.substring (0, scope_id.last_index_of ("."));
      return scope_id;
    }

    /**
     * Find sub-scopes for given master scope id in unity/scopes subdirectory
     * of XDG_DATA_DIRS dirs or in root_path.
     * @param scope_id id of a master scope (with .scope suffix)
     * @param root_path base directory of scopes, defaults to XDG_DATA_DIRS paths + "/unity/scopes"
     * @return scope registry with scopes property populated with all sub-scopes of the master scope.
     */
    public static async ScopeRegistry find_scopes_for_id (string scope_id, string? root_path = null) throws Error
    {
      var registry = new ScopeRegistry ();
      debug ("find_scopes_for_id: %s", scope_id);

      var root_node = new Node<ScopeMetadata?> (null);
      // try to find the master scope file
      try
      {
        var scope_metadata = ScopeMetadata.for_id (scope_id);
        yield build_scope_node_tree (root_node, scope_metadata.full_path);
        if (scope_file_prefixes == null) init_scope_file_prefixes ();
      }
      catch (Error err)
      {
        // silently ignore
      }

      /* if the scope was found, we need to check also the other
       * scope_directories, and merge sub-scopes from all of them, if it wasn't
       * this wasn't a valid scope_id, perhaps we can find a dir? */
      string[]? dirs = root_path == null ?
        scope_directories : new string [1] { root_path };

      if (dirs == null || dirs.length == 0)
      {
        throw new ParseError.INVALID_PATH ("Invalid scopes path");
      }

      unowned Node<ScopeMetadata?> node = root_node.n_children () > 0 ?
        root_node.first_child () : root_node;

      var suffix = remove_scope_extension (scope_id);
      foreach (var path in dirs)
      {
        var check_path = Path.build_filename (path, suffix);
        if (!FileUtils.test (check_path, FileTest.IS_DIR)) continue;

        yield build_scope_node_tree (node, check_path);
      }

      // the registry from this method is not expected to contain the scope
      // itself, so don't use the root directly
      registry.from_tree (node);
      return registry;
    }
  }

  public struct ScopeGroupScopeInfo
  {
    public string scope_id;
    public string dbus_name;
    public string dbus_path;
    public string module;
    public string module_type;
  }

  public class ScopeGroupConfig
  {
    private static const string SCOPE_GROUP_GROUP = "Scope Group";

    public List<ScopeGroupScopeInfo?> scopes;
    public int timeout;

    public ScopeGroupConfig (string file_name) throws Error
    {
      var file = new KeyFile ();
      if (!file.load_from_file (file_name, KeyFileFlags.NONE))
      {
        throw new IOError.NOT_FOUND (@"Scope group not found: $file_name");
      }

      if (file.has_key (SCOPE_GROUP_GROUP, "Timeout"))
        this.timeout = file.get_integer (SCOPE_GROUP_GROUP, "Timeout");
      else
        this.timeout = 0;

      this.scopes = null;
      foreach (var scope_id in file.get_string (SCOPE_GROUP_GROUP, "Scopes").split(";"))
      {
        // Read additional metadata from groups named by the scope IDs.
        var metadata = Unity.Protocol.ScopeRegistry.ScopeMetadata.for_id (scope_id);
        this.scopes.append (
          {scope_id,
           metadata.dbus_name, metadata.dbus_path,
           metadata.module, metadata.module_type});
      }
    }
  }

}  /* namespace unity */
