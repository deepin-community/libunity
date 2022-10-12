/*
 * Copyright (C) 2012 Canonical, Ltd.
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

namespace Unity.Protocol {

public enum CategoryType
{
  NONE,
  APPLICATION,
  BOOK,
  MUSIC,
  MOVIE,
  GAMES,
  ELECTRONICS,
  COMPUTERS,
  OFFICE,
  HOME,
  GARDEN,
  PETS,
  TOYS,
  CHILDREN,
  BABY,
  CLOTHES,
  SHOES,
  WATCHES,
  SPORTS,
  OUTDOORS,
  GROCERY,
  HEALTH,
  BEAUTY,
  DIY,
  TOOLS,
  CAR,

  N_CATEGORIES
}

public class AnnotatedIcon : Object, GLib.Icon
{
  public Icon icon { get; set; }
  public string ribbon { get; set; }
  public CategoryType category { get; set; default = CategoryType.NONE; }
  public bool use_small_icon { get; set; }
  public uint32 colorize_value { get; set; }

  public AnnotatedIcon (Icon? base_icon)
  {
    Object (icon: base_icon);
  }

  construct
  {
    _hints = new HashTable<string, Variant> (str_hash, str_equal);
  }

  private HashTable<string, Variant> _hints;

  public void add_hint (string name, Variant value)
  {
    _hints[name] = value;
  }

  public unowned Variant? get_hint (string name)
  {
    return _hints[name];
  }

  public void set_colorize_rgba (double r, double g, double b, double a)
  {
    const uint MAX_VAL = 255;
    const double MAX_VAL_DBL = 255.0;
    uint32 color = 0;
    color += uint.min (MAX_VAL, (uint) Math.round (r * MAX_VAL_DBL));
    color <<= 8;
    color += uint.min (MAX_VAL, (uint) Math.round (g * MAX_VAL_DBL));
    color <<= 8;
    color += uint.min (MAX_VAL, (uint) Math.round (b * MAX_VAL_DBL));
    color <<= 8;
    color += uint.min (MAX_VAL, (uint) Math.round (a * MAX_VAL_DBL));

    colorize_value = color;
  }

  private bool equal (Icon? icon2)
  {
    return (this.to_string () == icon2.to_string ());
  }

  private uint hash ()
  {
    return str_hash (to_string ());
  }

  /* FIXME: hack, vala thinks this is instance method, while it actually
   *   is not one - it's suppossed to create a new instance, kind of
   *   `static virtual` (access "this" and the process will die a swift,
   *   yet painful death with the famous last words of SIGSEGV) */
  [CCode (instance_pos = -0.9)]
  private Icon? from_tokens (string[] tokens, int version) throws Error
  {
    if (tokens.length != 1)
    {
      throw new IOError.INVALID_ARGUMENT (
        "Unable to construct AnnotatedIcon: wrong number of tokens");
    }

    var dict = Variant.parse (null, tokens[0]);
    var icon = Object.new (typeof (AnnotatedIcon)) as AnnotatedIcon;
    icon._hints = (HashTable<string, Variant>) dict;

    unowned Variant icon_variant = icon.get_hint ("base-icon");
    if (icon_variant != null && icon_variant.get_string () != null)
    {
      icon.icon = Icon.new_for_string (icon_variant.get_string ());
      icon._hints.remove ("base-icon");
    }

    unowned Variant category_variant = icon.get_hint ("category");
    if (category_variant != null)
    {
      icon.category = (CategoryType) category_variant.get_uint32 ();
      icon._hints.remove ("category");
    }

    unowned Variant ribbon_variant = icon.get_hint ("ribbon");
    if (ribbon_variant != null && ribbon_variant.get_string () != null)
    {
      icon.ribbon = ribbon_variant.get_string ();
      icon._hints.remove ("ribbon");
    }

    unowned Variant small_icon_variant = icon.get_hint ("use-small-icon");
    if (small_icon_variant != null)
    {
      icon.use_small_icon = small_icon_variant.get_boolean ();
      icon._hints.remove ("use-small-icon");
    }

    unowned Variant colorize_variant = icon.get_hint ("colorize-value");
    if (colorize_variant != null)
    {
      icon.colorize_value = colorize_variant.get_uint32 ();
      icon._hints.remove ("colorize-value");
    }

    return icon;
  }

  private bool to_tokens (GenericArray<string> tokens, out int version)
    requires (icon != null)
  {
    version = 0;

    var base_icon_string = icon.to_string ();
    add_hint ("base-icon", base_icon_string);
    if (category != CategoryType.NONE && category < CategoryType.N_CATEGORIES)
      add_hint ("category", new Variant.uint32 (category));
    if (ribbon != null && ribbon[0] != '\0')
      add_hint ("ribbon", ribbon);
    if (use_small_icon)
      add_hint ("use-small-icon", new Variant.boolean (true));
    if (colorize_value > 0)
      add_hint ("colorize-value", new Variant.uint32 (colorize_value));

    Variant dict = _hints;
    tokens.add (dict.print (true));
    return true;
  }

  /* Added to GIcon interface in 2.37 */
  private Variant? serialize ()
  {
    Variant? ret = null;
    return ret;
  }
}


} /* namespace unity */
