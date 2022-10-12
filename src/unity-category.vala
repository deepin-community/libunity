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

namespace Unity {

public enum CategoryRenderer
{
  DEFAULT = 0,

  GRID = 1,
  CAROUSEL = 2,
  LIST = 3,

  DYNAMIC = 1000,
  SPECIAL = 1001,

  /* deprecated */
  VERTICAL_TILE = 0,
  HORIZONTAL_TILE = 1;

  public static CategoryRenderer from_string (string renderer_name)
  {
    switch (renderer_name)
    {
      case "default":
        return CategoryRenderer.DEFAULT;
      case "grid":
        return CategoryRenderer.GRID;
      case "carousel":
        return CategoryRenderer.CAROUSEL;
      case "list":
        return CategoryRenderer.LIST;
      case "dynamic":
        return CategoryRenderer.DYNAMIC;
      case "special":
        return CategoryRenderer.SPECIAL;
      default:
        warning ("Unknown CategoryRenderer: %s", renderer_name);
        return CategoryRenderer.DEFAULT;
    }
  }

  public static unowned string to_string (CategoryRenderer val)
  {
    switch (val)
    {
      case CategoryRenderer.DEFAULT:
        return "default";
      case CategoryRenderer.GRID:
        return "grid";
      case CategoryRenderer.LIST:
        return "list";
      case CategoryRenderer.CAROUSEL:
        return "carousel";
      case CategoryRenderer.DYNAMIC:
        return "dynamic";
      case CategoryRenderer.SPECIAL:
        return "special";
      default:
        return "default";
    }
  }
}

public enum CategoryContentType
{
  DEFAULT,
  APPLICATIONS,
  MUSIC,
  VIDEO,
  PLACES,
  SOCIAL,
  WEATHER;

  public static CategoryContentType from_string (string content_type)
  {
    switch (content_type)
    {
      case "apps":
        return CategoryContentType.APPLICATIONS;
      case "music":
        return CategoryContentType.MUSIC;
      case "video":
        return CategoryContentType.VIDEO;
      case "places":
        return CategoryContentType.PLACES;
      case "social":
        return CategoryContentType.SOCIAL;
      case "weather":
        return CategoryContentType.WEATHER;
      default:
        return CategoryContentType.DEFAULT;
    }
  }

  public static unowned string to_string (CategoryContentType val)
  {
    switch (val)
    {
      case CategoryContentType.APPLICATIONS:
        return "apps";
      case CategoryContentType.MUSIC:
        return "music";
      case CategoryContentType.VIDEO:
        return "video";
      case CategoryContentType.PLACES:
        return "places";
      case CategoryContentType.SOCIAL:
        return "social";
      case CategoryContentType.WEATHER:
        return "weather";
      default:
        return "default";
    }
  }
}

public abstract class MetadataProvider : GLib.Object
{
  internal abstract void update_hints (HashTable<string, Variant> hints);
}

public class ProgressSourceProvider: MetadataProvider
{
  public string dbus_name { get; construct; }
  public string dbus_path { get; construct; }

  public ProgressSourceProvider (string dbus_name, string dbus_path)
  {
    Object (dbus_name: dbus_name, dbus_path: dbus_path);
  }

  internal override void update_hints (HashTable<string, Variant> hints)
  {
    Variant[] ps = { new Variant.string (dbus_name + ":" + dbus_path) };
    hints["progress-source"] = new Variant.array (null, ps);
  }
}

public class Category : GLib.Object
{
  public string id { get; construct; }
  public string name { get; construct; }
  public Icon? icon_hint { get; construct; }
  public CategoryRenderer default_renderer { get; construct; }
  public CategoryContentType content_type { get; construct set; }
  public string renderer_hint { get; set; }

  public Category (string id,
                   string name,
                   Icon icon_hint,
                   CategoryRenderer renderer=CategoryRenderer.VERTICAL_TILE)
  {
    Object (id: id, name:name, icon_hint:icon_hint, default_renderer:renderer);
  }

  public void add_metadata_provider (MetadataProvider provider)
  {
    if (hints == null)
    {
      hints = new HashTable<string, Variant> (str_hash, str_equal);
    }

    provider.update_hints (hints);
  }

  /*
   * Implementation
   */
  public string renderer {
    get {
      return CategoryRenderer.to_string (default_renderer);
    }
  }

  private HashTable<string, Variant> hints;

  internal unowned HashTable<string, Variant> get_hints ()
  {
    if (hints == null)
    {
      hints = new HashTable<string, Variant> (str_hash, str_equal);
    }

    hints["content-type"] =
      new Variant.string (CategoryContentType.to_string (content_type));

    if (renderer_hint != null)
    {
      hints["renderer-hint"] = new Variant.string (renderer_hint);
    }

    return hints;
  }
}

} /* namespace */
