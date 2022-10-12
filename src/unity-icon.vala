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

namespace Unity
{
  /* Keep in sync with Protocol.CategoryType! */
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

  public enum IconSizeHint
  {
    DEFAULT,
    SMALL,
    LARGE
  }

  /*
   * AnnotatedIcon can be used to add various icon and text overlays to an icon.
   * Add desired overlays using properties of this class and use the to_string()
   * method to serialize the icon (for example when appending rows to scope
   * results model).
   *
   * NOTE: We can't make this class implement GIcon, cause GIcon includes
   * the type name in the serialized string, and if that didn't match
   * the type name from protocol library, the library wouldn't be able
   * to deserialize it.
   * This does have also a nice side effect though - being unable to construct
   * an AnnotatedIcon with another AnnotatedIcon as the base_icon.
   */
  public class AnnotatedIcon : Object
  {
    private Protocol.AnnotatedIcon _pai;

    public Icon icon
    {
      get { return _pai.icon; }
      set { _pai.icon = value; }
    }

    public string ribbon
    {
      get { return _pai.ribbon; }
      set { _pai.ribbon = value; }
    }

    public CategoryType category
    {
      get { return (CategoryType) _pai.category; }
      set { _pai.category = (Protocol.CategoryType) value; }
    }

    public IconSizeHint size_hint
    {
      get
      {
        return _pai.use_small_icon ? IconSizeHint.SMALL : IconSizeHint.DEFAULT;
      }
      set { _pai.use_small_icon = value == IconSizeHint.SMALL; }
    }

    public void set_colorize_rgba (double r, double g, double b, double a)
    {
      _pai.set_colorize_rgba (r, g, b, a);
    }

    public AnnotatedIcon (Icon base_icon)
    {
      Object (icon: base_icon);
    }

    construct
    {
      static_assert ((uint) CategoryType.N_CATEGORIES ==
                     (uint) Protocol.CategoryType.N_CATEGORIES);
      _pai = new Protocol.AnnotatedIcon (null);
    }

    /* GIcon-like to string method */
    public string to_string ()
    {
      return _pai.to_string ();
    }
  }
} /* namespace */
