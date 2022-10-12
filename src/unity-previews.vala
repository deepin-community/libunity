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

/*
 * Previews
 */

public abstract class Preview : AbstractPreview, Dee.Serializable
{
  public string title
  {
    get { return _raw.title; }
    set { _raw.title = value; }
  }
  public string subtitle
  {
    get { return _raw.subtitle; }
    set { _raw.subtitle = value; }
  }
  public string description_markup
  {
    get { return _raw.description; }
    set { _raw.description = value; }
  }
  /**
   * Source for the image.
   *
   * URI to the source which can be used to generate a thumbnail. (for example
   * a .pdf file, .webm etc). If a thumbnail in appropriate resolution
   * is already available use the "image" property instead.
   */
  public string image_source_uri
  {
    get { return _raw.image_source_uri; }
    set { _raw.image_source_uri = value; }
  }
  public Icon? image
  {
    get { return _raw.image; }
    set { _raw.image = value; }
  }

  private Protocol.Preview? _raw;
  internal unowned Protocol.Preview? get_raw ()
  {
    return _raw;
  }

  construct
  {
    _raw = create_raw () as Protocol.Preview;
    warn_if_fail (_raw != null);
  }

  // as a virtual method this will get into our main .h file and we don't want
  // to add dep on the unity-protocol library, therefore it returns Object
  // instead of Protocol.Preview
  internal abstract Object create_raw ();

  private GenericArray<PreviewAction> _actions =
    new GenericArray<PreviewAction> ();

  public void add_action (PreviewAction action)
  {
    _actions.add (action);

    _raw.add_action_with_hints (action.id, action.display_name,
                                action.icon_hint, action.layout_hint,
                                action.get_hints_internal ());
  }

  public void add_info (InfoHint info_hint)
  {
    // unlike Vala, C will likely pass floating ref
    var sunk = info_hint.ref_sink () as InfoHint;
    _raw.add_info_hint (sunk.id, sunk.display_name,
                        sunk.icon_hint, sunk.data);
  }

  internal unowned GenericArray<PreviewAction> get_actions ()
  {
    return _actions;
  }

  private Variant serialize ()
  {
    return _raw.serialize ();
  }

  protected override uint8[] serialize_as (Unity.SerializationType serialize_type)
  {
    switch (serialize_type)
    {
      case SerializationType.BINARY:
        Variant serialized = this.serialize ();
        var result = new uint8[serialized.get_size ()];
        serialized.store (result);
        return result;
      case SerializationType.JSON:
        return """{"error": "JSON serialization not supported"}""".data;
    }

    return {};
  }
}

/* This is 1:1 copy of Protocol.LayoutHint, but we need to expose this
 * to our gir, we don't want to depend on UnityProtocol's gir */
public enum LayoutHint
{
  NONE,
  LEFT,
  RIGHT,
  TOP,
  BOTTOM
}

public class PreviewAction : Object, Dee.Serializable // TODO: Implement GLib.Action
{
  public string id { get; construct; }
  public string display_name { get; construct; }
  public string extra_text { get; set; }
  public Icon? icon_hint { get; construct; }
  public LayoutHint layout_hint { get; construct; }
  public HashTable<string, Variant>? hints { get { return hints_; } }

  private HashTable<string, Variant> hints_ =
    new HashTable<string, Variant> (str_hash, str_equal);

  public PreviewAction (string id, string display_name, Icon? icon_hint)
  {
    Object (id: id, display_name: display_name, icon_hint: icon_hint);
  }

  public PreviewAction.with_layout_hint (string id, string display_name,
                                         Icon? icon_hint, LayoutHint layout)
  {
    Object (id: id, display_name: display_name, icon_hint: icon_hint,
            layout_hint: layout);
  }

  public PreviewAction.with_uri (string uri, string display_name,
                                 Icon? icon_hint)
  {
    Object (id: uri, display_name: display_name, icon_hint: icon_hint);

    hints["activation-uri"] = uri;
  }

  public signal ActivationResponse activated (string uri);

  private Variant serialize ()
  {
    // FIXME: we should use PreviewActionRaw, but this is faster
    Variant tuple[5];

    tuple[0] = id;
    tuple[1] = display_name;
    tuple[2] = new Variant.string (icon_hint != null ? icon_hint.to_string () : "");
    tuple[3] = (uint) layout_hint;
    tuple[4] = get_hints_internal ();

    return new Variant.tuple (tuple);
  }

  internal unowned HashTable<string, Variant> get_hints_internal ()
  {
    if (extra_text != null && extra_text[0] != '\0')
      hints["extra-text"] = extra_text;

    return hints;
  }

  static construct
  {
    Dee.Serializable.register_parser (typeof (PreviewAction),
                                      new VariantType ("(sssua{sv})"),
                                      (data) =>
    {
      unowned string icon_hint = data.get_child_value (2).get_string ();
      Icon? icon = null;
      if (icon_hint != null && icon_hint != "")
      {
        try
        {
          icon = Icon.new_for_string (icon_hint);
        }
        catch (Error err)
        {
          warning ("Failed to deserialize GIcon: %s", err.message);
        }
      }

      var result = new PreviewAction.with_layout_hint (
        data.get_child_value (0).get_string (),
        data.get_child_value (1).get_string (),
        icon,
        (LayoutHint) data.get_child_value (3).get_uint32 ());
      result.hints_ = (HashTable<string, Variant>) data.get_child_value (4);
      return result;
    });
  }
}


public class InfoHint : InitiallyUnowned
{
  public string id { get; construct; }
  public string display_name { get; construct; }
  public Icon? icon_hint { get; construct; }
  public Variant data { get; construct; }

  public InfoHint (string id, string display_name, Icon? icon_hint,
                   string data)
  {
    Object (id: id, display_name: display_name, icon_hint: icon_hint,
            data: new Variant.string (data));
  }

  public InfoHint.with_variant (string id, string display_name,
                                Icon? icon_hint, Variant data)
  {
    Object (id: id, display_name: display_name, icon_hint: icon_hint,
            data: data);
  }
}


public class GenericPreview : Preview
{
  public GenericPreview (string title,
                         string description,
                         Icon? image)
  {
    Object (title: title, image: image,
            description_markup: description);
  }

  internal static GenericPreview empty ()
  {
    var preview = new GenericPreview ("", "", null);
    preview.get_raw ().set_no_details (true);

    return preview;
  }

  internal override Object create_raw ()
  {
    return new Protocol.GenericPreview ();
  }
}


public class ApplicationPreview : Preview
{
  public Icon app_icon
  {
    get { return _raw.app_icon; }
    set { _raw.app_icon = value; }
  }
  public string license
  {
    get { return _raw.license; }
    set { _raw.license = value; }
  }
  public string copyright
  {
    get { return _raw.copyright; }
    set { _raw.copyright = value; }
  }
  public string last_update
  {
    get { return _raw.last_update; }
    set { _raw.last_update = value; }
  }

  public ApplicationPreview (string title,
                             string subtitle,
                             string description,
                             Icon? icon,
                             Icon? screenshot)
  {
    Object (title: title, subtitle: subtitle, image: screenshot,
            description_markup: description, app_icon: icon);
  }

  public void set_rating (float rating, uint num_ratings)
  {
    _raw.rating = rating;
    _raw.num_ratings = num_ratings;
  }

  private unowned Protocol.ApplicationPreview _raw;
  internal override Object create_raw ()
  {
    var raw = new Protocol.ApplicationPreview ();
    _raw = raw;
    return _raw;
  }
}


public class MusicPreview : Preview
{
  /* Keep in sync with Protocol.PlayState! */
  public enum TrackState
  {
    STOPPED,
    PLAYING,
    PAUSED
  }

  private Dee.SerializableModel _track_data;

  public MusicPreview (string title,
                       string subtitle,
                       Icon? image)
  {
    Object (title: title, subtitle: subtitle, image: image);
  }

  private unowned Protocol.MusicPreview _raw;
  internal override Object create_raw ()
  {
    var raw = new Protocol.MusicPreview ();
    _raw = raw;
    return _raw;
  }

  public void add_track (TrackMetadata track)
  {
    init_model ();

    _track_data.append (track.uri, track.track_no, track.title,
                        track.length, TrackState.STOPPED, 0.0);
  }

  // use add_info to add total number of tracks and "tags"

  private enum TrackDataColumns
  {
    URI,
    TRACK_NO,
    TITLE,
    LENGTH,
    PLAY_STATE,
    PROGRESS
  }

  private void init_model ()
  {
    if (_track_data == null)
    {
      _track_data = new Dee.SequenceModel ();
      _track_data.set_schema ("s", "i", "s", "u", "u", "d");
      _track_data.set_column_names ("uri", "track-number", "title", "length",
                                    "play-state", "progress");

      _raw.track_model = _track_data;
    }
  }
}


public class PaymentPreview : Preview
{
  public enum Type {
    APPLICATION,
    MUSIC,
    ERROR
  }

  public string header
  {
    get { return _raw.header; }
    set { _raw.header = value;}
  }

  public string email
  {
    get { return _raw.email; }
    set { _raw.email = value; }
  }

  public string payment_method
  {
    get { return _raw.payment_method; }
    set { _raw.payment_method = value; }
  }

  public string purchase_prize
  {
    get { return _raw.purchase_prize; }
    set { _raw.purchase_prize = value; }
  }

  public string purchase_type
  {
    get { return _raw.purchase_type; }
    set { _raw.purchase_type = value; }
  }

  public Type preview_type
  {
    get { return (Type) _raw.preview_type; }
    set { _raw.preview_type = (Unity.Protocol.PreviewPaymentType) value; }
  }

  public PaymentPreview (string title, string subtitle, Icon? image)
  {
    Object (title: title, subtitle: subtitle, image: image);
  }

  public PaymentPreview.for_type (string title, string subtitle, Icon? image,
    Type type)
  {
    this (title, subtitle, image);
    preview_type = type;
  }

  public PaymentPreview.for_application (string title, string subtitle,
    Icon? image)
  {
    this.for_type (title, subtitle, image, Type.APPLICATION);
  }

  public PaymentPreview.for_music (string title, string subtitle, Icon? image)
  {
    this.for_type (title, subtitle, image, Type.MUSIC);
  }

  public PaymentPreview.for_error (string title, string subtitle, Icon? image)
  {
    this.for_type (title, subtitle, image, Type.ERROR);
  }

  static construct
  {
    // perform assertion so that we do not have bad castings if
    // someone forgot to keep the enums synced
    static_assert ((int) Protocol.PreviewPaymentType.APPLICATION ==
                   (int) Type.APPLICATION);
    static_assert ((int) Protocol.PreviewPaymentType.MUSIC ==
                   (int) Type.MUSIC);
    static_assert ((int) Protocol.PreviewPaymentType.ERROR ==
                   (int) Type.ERROR);
  }

  private unowned Protocol.PaymentPreview _raw;
  internal override Object create_raw ()
  {
    var raw = new Protocol.PaymentPreview ();
    _raw = raw;
    return _raw;
  }
}


public class MoviePreview : Preview
{
  public string year
  {
    get { return _raw.year; }
    set { _raw.year = value; }
  }

  public MoviePreview (string title, string subtitle, string description,
                       Icon? image)
  {
    Object (title: title, subtitle: subtitle, description_markup: description,
            image: image);
  }

  public void set_rating (float rating, uint num_ratings)
  {
    _raw.rating = rating;
    _raw.num_ratings = num_ratings;
  }

  private unowned Protocol.MoviePreview _raw;
  internal override Object create_raw ()
  {
    var raw = new Protocol.MoviePreview ();
    _raw = raw;
    return _raw;
  }
}


public class SocialPreview : Preview
{
  public class Comment : InitiallyUnowned
  {
    public string id { get; construct; }
    public string name { get; construct; }
    public string text { get; construct; }
    public string time { get; construct; }

    public Comment (string id, string name, string text, string time)
    {
      Object (id: id, name: name, text: text, time: time);
    }
  }

  public Icon avatar
  {
    get { return _raw.avatar; }
    set { _raw.avatar = value; }
  }
  public string content
  {
    get { return _raw.description; }
    set { _raw.description = value; }
  }
  public string sender
  {
    get { return _raw.sender; }
    set { _raw.sender = value; }
  }

  public SocialPreview (string sender, string subtitle,
                        string content, Icon? avatar)
  {
    Object (title: sender, subtitle: subtitle, content: content,
            avatar: avatar);
  }

  private unowned Protocol.SocialPreview _raw;
  internal override Object create_raw ()
  {
    var raw = new Protocol.SocialPreview ();
    _raw = raw;
    return _raw;
  }

  public void add_comment (Comment comment)
  {
    // unlike Vala, C will likely pass floating ref
    var sunk = comment.ref_sink () as Comment;
    _raw.add_comment (sunk.id, sunk.name, sunk.text, sunk.time);
  }

}


} /* namespace */
