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

using GLib;
using Dee;

namespace Unity.Protocol {

/* The raw type that get's passed over DBus to Unity */
private struct PreviewRaw
{
  // make sure this matches the real signature
  internal const string SIGNATURE = "(ssssssa(sssua{sv})a(sssv)a{sv})";

  public string renderer_name;

  public string title;
  public string subtitle;
  public string description;
  public string image_source_uri;
  public string image_hint;

  public PreviewActionRaw[] actions;
  public InfoHintRaw[] info_hints;

  public HashTable<string, Variant> hints;

  public PreviewRaw ()
  {
    hints = new HashTable<string, Variant> (str_hash, str_equal);
  }

  public static PreviewRaw? from_variant (Variant v)
  {
    return (PreviewRaw) v;
  }

  public Variant to_variant ()
  {
    return this;
  }
}

public enum LayoutHint
{
  NONE,
  LEFT,
  RIGHT,
  TOP,
  BOTTOM
}

public struct InfoHintRaw
{
  public string id;
  public string display_name;
  public string icon_hint;
  public Variant value;
}

public struct PreviewActionRaw
{
  public string id;
  public string display_name;
  public string icon_hint;
  public uint layout_hint;
  public HashTable<string, Variant> hints;

  public PreviewActionRaw ()
  {
    hints = new HashTable<string, Variant> (str_hash, str_equal);
  }
  
  public static PreviewActionRaw? from_variant (Variant v)
  {
    return (PreviewActionRaw) v;
  }

  public Variant to_variant ()
  {
    return this;
  }
}

public abstract class Preview : Object, Dee.Serializable
{
  public string title { get; set; }
  public string subtitle { get; set; }
  public string description { get; set; }
  public string image_source_uri { get; set; }
  public Icon? image { get; set; }

  private PreviewRaw _raw = PreviewRaw ();
  private PreviewActionRaw[] _actions_raw = null;
  private InfoHintRaw[] _info_hints = null;
  private HashTable<string, Variant>? _updates = null;
  private bool _no_details = false;

  public virtual void begin_updates()
  {
    if (_updates != null)
    {
      warning ("Called begin_updates without end_updates");
    }
    else
    {
      _updates = new HashTable<string, Variant> (str_hash, str_equal);
    }
  }

  public virtual HashTable<string, Variant>? end_updates_as_hashtable ()
  {
    if (_updates == null)
    {
      warning ("Called end_updates without begin_updates");
    }
    
    var result = _updates;
    _updates = null;
    return result;
  }

  public virtual Variant? end_updates ()
  {
    HashTable<string, Variant> result = end_updates_as_hashtable ();
    return result;
  }
  
  public void add_action (string id, string display_name,
                          Icon? icon, uint layout_hint)
  {
    var hints = new HashTable<string, Variant> (null, null);
    add_action_with_hints (id, display_name, icon, layout_hint, (owned) hints);
  }

  public void add_action_with_hints (string id, string display_name,
                                     Icon? icon, uint layout_hint,
                                     owned HashTable<string, Variant> hints)
  {
    PreviewActionRaw? action_raw = PreviewActionRaw ();
    action_raw.id = id;
    action_raw.display_name = display_name;
    action_raw.icon_hint = icon != null ? icon.to_string () : "";
    action_raw.layout_hint = layout_hint;
    action_raw.hints = (owned) hints;

    _actions_raw += (owned) action_raw;
  }

  public unowned PreviewActionRaw[] get_actions ()
  {
    return _actions_raw;
  }

  public void add_info_hint (string id,
                             string display_name,
                             Icon? icon_hint,
                             Variant value)
  {
    InfoHintRaw? info = InfoHintRaw ();
    info.id = id;
    info.display_name = display_name;
    info.icon_hint = icon_hint != null ? icon_hint.to_string () : "";
    info.value = value;

    _info_hints += (owned) info;
  }

  public abstract unowned string get_renderer_name ();

  public unowned InfoHintRaw[] get_info_hints ()
  {
    return _info_hints;
  }

  public void set_no_details (bool val)
  {
    _no_details = val;
  }

  public bool get_no_details ()
  {
    return _no_details;
  }

  /**
   * Called by Dash when preview has been closed
   */
  public void preview_closed ()
  {
    add_update ("base-preview-action", "closed");
  }

  public virtual void update_property (HashTable<string, Variant> properties)
  {
  }

  internal virtual void add_properties (HashTable<string, Variant> properties)
  {
    if (_no_details)
      properties["no-details"] = new Variant.boolean (true);
  }

  internal void add_update(string property, Variant value)
  {
    if (_updates != null)
    {
      _updates[property] = value;
    }
  }

  internal HashTable<string, Variant> get_properties ()
  {
    var properties = new HashTable<string, Variant> (str_hash, str_equal);
    add_properties (properties);
    return properties;
  }

  private Variant serialize ()
  {
    _raw.renderer_name = get_renderer_name ();
    _raw.title = title != null ? title : "";
    _raw.subtitle = subtitle != null ? subtitle : "";
    _raw.description = description != null ? description : "";
    _raw.image_source_uri = image_source_uri != null ? image_source_uri : "";
    _raw.image_hint = image != null ? image.to_string () : "";

    _raw.actions = _actions_raw;
    _raw.info_hints = _info_hints;

    _raw.hints = get_properties ();

    return _raw.to_variant ();
  }

  internal static Icon? string_to_icon (string s)
  {
    if (s[0] != '\0')
    {
      try
      {
        return Icon.new_for_string (s);
      }
      catch (Error err)
      {
        warning ("Failed to deserialize GIcon: %s", err.message);
        return null;
      }
    }
    return null;
  }

  internal static Icon? variant_to_icon (Variant? v)
  {
    return v != null ? string_to_icon (v.get_string ()) : null;
  }

  private static bool parsers_registered = false;
  private static void register_parsers ()
  {
    typeof (GenericPreview).class_ref ();
    typeof (ApplicationPreview).class_ref ();
    typeof (MusicPreview).class_ref ();
    typeof (PaymentPreview).class_ref ();
    typeof (MoviePreview).class_ref ();
    typeof (SocialPreview).class_ref ();
    typeof (SeriesPreview).class_ref ();
  }

  public static Preview? parse (Variant data)
  {
    if (!parsers_registered)
    {
      register_parsers ();
      parsers_registered = true;
    }

    Object? result_obj = null;
    unowned string renderer = data.get_child_value (0).get_string ();
    switch (renderer)
    {
      case GenericPreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (GenericPreview));
        break;
      case ApplicationPreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (ApplicationPreview));
        break;
      case MusicPreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (MusicPreview));
        break;
      case PaymentPreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (PaymentPreview));
        break;
      case MoviePreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (MoviePreview));
        break;
      case SocialPreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (SocialPreview));
        break;
      case SeriesPreview.RENDERER_NAME:
        result_obj = Dee.Serializable.parse (data, typeof (SeriesPreview));
        break;
      default:
        warning ("Unknown preview renderer: %s", renderer);
        break;
    }

    return result_obj as Preview;
  }

  internal static T deserialize<T> (
    Variant data, out HashTable<string, Variant> out_properties = null)
    requires (typeof (T).is_a (typeof (Preview)))
  {
    Preview result = Object.new (typeof (T)) as Preview;

    var raw = PreviewRaw.from_variant (data);
    out_properties = raw.hints;

    // set base properties
    result.title = raw.title;
    result.subtitle = raw.subtitle;
    result.description = raw.description;
    result.image_source_uri = raw.image_source_uri;
    result.image = Preview.string_to_icon (raw.image_hint);

    result._actions_raw = (owned) raw.actions;
    result._info_hints = (owned) raw.info_hints;

    unowned Variant no_det_var = raw.hints.lookup ("no-details");
    if (no_det_var != null)
      result._no_details = no_det_var.get_boolean ();

    return (T) result;
  }

  internal static void checked_set (Variant? v, Func<Variant> f)
  {
    if (v != null) f (v);
  }
}

public class GenericPreview : Preview
{
  internal const string RENDERER_NAME = "preview-generic";

  public GenericPreview ()
  {
    Object ();
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (GenericPreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      GenericPreview result;
      result = Preview.deserialize<GenericPreview> (data);

      return result;
    });
  }
}


public class ApplicationPreview : Preview
{
  internal const string RENDERER_NAME = "preview-application";

  public Icon app_icon { get; set; }
  public string license { get; set; }
  public string copyright { get; set; }
  public string last_update { get; set; }
  public float rating { get; set; }
  public uint num_ratings { get; set; }

  public ApplicationPreview ()
  {
    Object ();
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  internal override void add_properties (HashTable<string, Variant> properties)
  {
    base.add_properties (properties);

    if (app_icon != null)
      properties["application-icon"] = app_icon.to_string ();

    if (license != null)
      properties["license"] = license;
    if (copyright != null)
      properties["copyright"] = copyright;
    if (last_update != null)
      properties["last-update"] = last_update;

    if (rating >= -1.0f)
      properties["rating"] = (double) rating;
    if (num_ratings > 0)
      properties["num-ratings"] = num_ratings;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (ApplicationPreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      HashTable<string, Variant> properties;
      ApplicationPreview result = Preview.deserialize<ApplicationPreview> (
        data, out properties);

      Preview.checked_set (properties["application-icon"],
        (v) => { result.app_icon = Preview.variant_to_icon (v); });
      Preview.checked_set (properties["license"],
        (v) => { result.license = v.get_string (); });
      Preview.checked_set (properties["copyright"],
        (v) => { result.copyright = v.get_string (); });
      Preview.checked_set (properties["last-update"],
        (v) => { result.last_update = v.get_string (); });
      Preview.checked_set (properties["rating"],
        (v) => { result.rating = (float) v.get_double (); });
      Preview.checked_set (properties["num-ratings"],
        (v) => { result.num_ratings = v.get_uint32 (); });

      return result;
    });
  }
}


public enum PlayState
{
  STOPPED,
  PLAYING,
  PAUSED
}


public class MusicPreview : Preview
{
  internal const string RENDERER_NAME = "preview-music";

  public string track_data_swarm_name { get; set; }
  public string track_data_address { get; set; }
  public Dee.SerializableModel track_model { get; set; }

  public MusicPreview ()
  {
    Object ();
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  internal override void add_properties (HashTable<string, Variant> properties)
  {
    base.add_properties (properties);

    if (track_data_swarm_name != null)
      properties["track-data-swarm-name"] = track_data_swarm_name;

    if (track_data_address != null)
      properties["track-data-address"] = track_data_address;

    if (track_model != null)
      properties["track-model"] = track_model.serialize ();
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (MusicPreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      HashTable<string, Variant> properties;
      MusicPreview result = Preview.deserialize<MusicPreview> (
        data, out properties);

      Preview.checked_set (properties["track-data-swarm-name"],
        (v) => { result.track_data_swarm_name = v.get_string (); });
      Preview.checked_set (properties["track-data-address"],
        (v) => { result.track_data_address= v.get_string (); });
      Preview.checked_set (properties["track-model"], (v) =>
      {
        var model = Dee.Serializable.parse (v, typeof (Dee.SequenceModel));
        result.track_model = model as Dee.SerializableModel;
      });

      return result;
    });
  }
}

public enum PreviewPaymentType {
  APPLICATION,
  MUSIC,
  ERROR,
}

public class PaymentPreview : Preview
{
  internal const string RENDERER_NAME = "preview-payment";

  public string header { get; set; }
  public string email { get; set; }
  public string payment_method { get; set; }
  public string purchase_prize { get; set; }
  public string purchase_type { get; set; }
  public PreviewPaymentType preview_type { get; set; default = PreviewPaymentType.MUSIC; }

  public PaymentPreview ()
  {
    Object ();
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  internal override void add_properties (HashTable<string, Variant> properties)
  {
    base.add_properties (properties);

    if (header != null)
      properties["header"] = header;

    if (email != null)
      properties["email"] = email;

    if (payment_method != null)
      properties["payment-method"] = payment_method;

    if (purchase_prize != null)
      properties["purchase-prize"] = purchase_prize;

    if (purchase_type != null)
      properties["purchase-type"] = purchase_type;

    properties["preview-type"] = preview_type;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (PaymentPreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      HashTable<string, Variant> properties;
      PaymentPreview result = Preview.deserialize<PaymentPreview> (
        data, out properties);

      Preview.checked_set (properties["title"],
        (v) => { result.title = v.get_string (); });
      Preview.checked_set (properties["subtitle"],
        (v) => { result.subtitle = v.get_string (); });
      Preview.checked_set (properties["header"],
        (v) => { result.header = v.get_string (); });
      Preview.checked_set (properties["email"],
        (v) => { result.email = v.get_string (); });
      Preview.checked_set (properties["payment-method"],
        (v) => { result.payment_method = v.get_string (); });
      Preview.checked_set (properties["purchase-prize"],
        (v) => { result.purchase_prize = v.get_string (); });
      Preview.checked_set (properties["purchase-type"],
        (v) => { result.purchase_type = v.get_string (); });
      Preview.checked_set (properties["preview-type"],
        (v) => { result.preview_type = (PreviewPaymentType) v.get_int32 (); });

      return result;
    });
  }
}

public class MoviePreview : Preview
{
  internal const string RENDERER_NAME = "preview-movie";

  public string year { get; set; }
  public float rating { get; set; }
  public uint num_ratings { get; set; }

  public MoviePreview ()
  {
    Object ();
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  internal override void add_properties (HashTable<string, Variant> properties)
  {
    base.add_properties (properties);

    if (rating >= -1.0f)
      properties["rating"] = (double) rating;
    if (num_ratings > 0)
      properties["num-ratings"] = num_ratings;
    if (year != null)
      properties["year"] = year;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (MoviePreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      HashTable<string, Variant> properties;
      MoviePreview result = Preview.deserialize<MoviePreview> (
        data, out properties);

      Preview.checked_set (properties["rating"],
        (v) => { result.rating = (float) v.get_double (); });
      Preview.checked_set (properties["num-ratings"],
        (v) => { result.num_ratings = v.get_uint32 (); });
      Preview.checked_set (properties["year"],
        (v) => { result.year = v.get_string (); });

      return result;
    });
  }
}

public class SocialPreview : Preview
{
  internal const string RENDERER_NAME = "preview-social";

  public Icon avatar { get; set; }
  public string content { get; set; }
  public string sender { get; set; }
  public CommentRaw[] comments;
  private CommentRaw[] _comments = null;

  public struct CommentRaw
  {
    public string id;
    public string display_name;
    public string content;
    public string time;
  }

  public SocialPreview ()
  {
    Object ();
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  internal override void add_properties (HashTable<string, Variant> properties)
  {
    base.add_properties (properties);

    if (_comments.length > 0)
      properties["comments"] = _comments;
    if (avatar != null)
      properties["avatar"] = avatar.to_string ();
    if (content != null)
      properties["content"] = content;
    if (sender != null)
      properties["sender"] = sender;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (SocialPreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      HashTable<string, Variant> properties;
      SocialPreview result = Preview.deserialize<SocialPreview> (
        data, out properties);

      Preview.checked_set (properties["avatar"],
        (v) => { result.avatar = Preview.variant_to_icon (v); });
      Preview.checked_set (properties["content"],
        (v) => { result.content = v.get_string (); });
      Preview.checked_set (properties["sender"],
        (v) => { result.sender = v.get_string (); });

      Preview.checked_set (properties["comments"], (v) =>
      {
        CommentRaw[] comments = (CommentRaw[]) v;
        result._comments = (owned) comments;
      });

      return result;
    });
  }

  public void add_comment (string id,
                             string display_name,
                             string content,
                             string time)
  {
    CommentRaw? comment = CommentRaw ();
    comment.id = id;
    comment.display_name = display_name;
    comment.content = content;
    comment.time = time;

    _comments += (owned) comment;
  }

  public unowned CommentRaw[] get_comments ()
  {
    return _comments;
  }
}

public struct SeriesItemRaw
{
  public string uri;
  public string title;
  public string icon_hint;
}

public class SeriesPreview : Preview
{
  internal const string RENDERER_NAME = "preview-series";

  public int selected_item { get; set; }
  public Preview child_preview { get; set; }

  private SeriesItemRaw[] _items = null;
  private ulong _selected_item_sig_id = 0;

  public SeriesPreview ()
  {
    Object ();
  }

  public override void begin_updates ()
  {
    base.begin_updates();
    if (_selected_item_sig_id == 0)
    {
      _selected_item_sig_id = notify["selected-item"].connect (() =>
      {
        add_update("series-active-index", selected_item);
      });
    }
  }

  public override HashTable<string, Variant>? end_updates_as_hashtable ()
  {
    if (_selected_item_sig_id > 0)
    {
      SignalHandler.disconnect(this, _selected_item_sig_id);
      _selected_item_sig_id = 0;
    }
    return base.end_updates_as_hashtable();
  }

  public void add_series_item (string title, string uri, Icon? icon)
  {
    SeriesItemRaw? item = SeriesItemRaw ();
    item.uri = uri;
    item.title = title;
    item.icon_hint = icon != null ? icon.to_string () : "";

    _items += (owned) item;
  }

  public unowned SeriesItemRaw[] get_items ()
  {
    return _items;
  }

  internal override unowned string get_renderer_name ()
  {
    return RENDERER_NAME;
  }

  public override void update_property (HashTable<string, Variant> properties)
  {
    base.update_property (properties);
    if (properties.contains("series-active-index"))
    {
      selected_item = properties["series-active-index"].get_int32();
    }
  }

  internal override void add_properties (HashTable<string, Variant> properties)
  {
    base.add_properties (properties);

    if (_items.length > 0)
      properties["series-items"] = _items;
    if (child_preview != null)
      properties["current-preview"] = child_preview.serialize ();
    if (selected_item >= 0)
      properties["series-active-index"] = selected_item;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (SeriesPreview),
                                      new VariantType (PreviewRaw.SIGNATURE),
                                      (data) =>
    {
      unowned string renderer = data.get_child_value (0).get_string ();
      warn_if_fail (renderer == RENDERER_NAME);

      HashTable<string, Variant> properties;
      SeriesPreview result = Preview.deserialize<SeriesPreview> (
        data, out properties);

      Preview.checked_set (properties["series-items"], (v) =>
      {
        SeriesItemRaw[] items = (SeriesItemRaw[]) v;
        result._items = (owned) items;
      });
      Preview.checked_set (properties["series-active-index"],
       (v) => { result.selected_item = v.get_int32 (); });
      Preview.checked_set (properties["current-preview"], (v) =>
      {
        result.child_preview = Preview.parse (v);
      });

      return result;
    });
  }
}


} /* namespace unity */
