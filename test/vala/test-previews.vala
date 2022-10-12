/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2012 Canonical Ltd
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
 * Authored by Michal Hruby <michal.hruby@canonical.com>
 *
 */
using Unity;

namespace Unity.Test
{
  public class PreviewSuite
  {
    public PreviewSuite ()
    {
      GLib.Test.add_data_func ("/Unit/Preview/GenericPreview",
                               test_preview_generic);
      GLib.Test.add_data_func ("/Unit/Preview/GenericPreview/WithMetadata",
                               test_preview_generic_with_metadata);
      GLib.Test.add_data_func ("/Unit/Preview/GenericPreview/Action/ExtraText",
                               test_preview_generic_action_extra_text);
      GLib.Test.add_data_func ("/Unit/Preview/GenericPreview/NoDetails",
                               test_preview_generic_no_details);
      GLib.Test.add_data_func ("/Unit/Preview/ApplicationPreview",
                               test_preview_application);
      GLib.Test.add_data_func ("/Unit/Preview/SocialPreview",
                               test_preview_social);
      GLib.Test.add_data_func ("/Unit/Preview/MusicPreview",
                               test_preview_music);
      GLib.Test.add_data_func ("/Unit/Preview/PaymentPreview",
                               test_preview_payment);
      GLib.Test.add_data_func ("/Unit/Preview/MusicPaymentPreview",
                               test_preview_music_payment);
      GLib.Test.add_data_func ("/Unit/Preview/ApplicationPaymentPreview",
                               test_preview_app_payment);
      GLib.Test.add_data_func ("/Unit/Preview/ErrorPaymentPreview",
                               test_preview_error_payment);
      GLib.Test.add_data_func ("/Unit/Preview/MusicPreview/WithTracks",
                               test_preview_music_with_tracks);
      GLib.Test.add_data_func ("/Unit/Preview/MoviePreview",
                               test_preview_movie);

      GLib.Test.add_data_func ("/Unit/AnnotatedIcon/Protocol/Construct",
                               test_proto_annotated_icon_construct);
      GLib.Test.add_data_func ("/Unit/AnnotatedIcon/Protocol/WithMetadata",
                               test_proto_annotated_icon_with_metadata);
      GLib.Test.add_data_func ("/Unit/AnnotatedIcon/WithMetadata",
                               test_annotated_icon_with_metadata);
      GLib.Test.add_data_func ("/Unit/AnnotatedIcon/WithColor",
                               test_annotated_icon_with_color);
    }

    static bool previews_equal (Variant data, Variant data2)
    {
      if (!data.equal (data2))
      {
        warning ("Reconstructed variant doesn't match:\n%s\n\n%s",
                 data.print (true), data2.print (true));
        return false;
      }

      return true;
    }

    static void test_proto_annotated_icon_construct ()
    {
      var icon = new ThemedIcon ("internet");
      var anno_icon = new Protocol.AnnotatedIcon (icon);
      var serialized = anno_icon.to_string ();

      var deserialized = Icon.new_for_string (serialized);
      assert (deserialized.to_string () == serialized);
      assert (deserialized is Protocol.AnnotatedIcon);
      var de_anno = deserialized as Protocol.AnnotatedIcon;
      assert (de_anno.category == Protocol.CategoryType.NONE);
    }

    static void test_proto_annotated_icon_with_metadata ()
    {
      var icon = new ThemedIcon ("internet");
      var anno_icon = new Protocol.AnnotatedIcon (icon);
      anno_icon.ribbon = "You can't buy the internet!";
      anno_icon.category = Protocol.CategoryType.CLOTHES;
      anno_icon.use_small_icon = true;
      var serialized = anno_icon.to_string ();

      var deserialized = Icon.new_for_string (serialized);
      assert (deserialized.to_string () == serialized);

      var de_anno = deserialized as Protocol.AnnotatedIcon;
      assert (de_anno != null);
      assert (de_anno.ribbon == "You can't buy the internet!");
      assert (de_anno.category == Protocol.CategoryType.CLOTHES);
      assert (de_anno.use_small_icon == true);
    }

    static void test_annotated_icon_with_metadata ()
    {
      var icon = new ThemedIcon ("internet");
      icon.append_name ("outernet");
      var anno_icon = new Unity.AnnotatedIcon (icon);
      anno_icon.ribbon = "You can't buy the internet!";
      assert (anno_icon.ribbon == "You can't buy the internet!");
      assert (anno_icon.icon.equal (icon));
      assert (anno_icon.category == CategoryType.NONE);
      anno_icon.category = CategoryType.MOVIE;
      anno_icon.size_hint = Unity.IconSizeHint.SMALL;
      var serialized = anno_icon.to_string ();

      var deserialized = Icon.new_for_string (serialized);
      assert (deserialized.to_string () == serialized);

      var de_anno = deserialized as Protocol.AnnotatedIcon;
      assert (de_anno != null);
      assert (de_anno.ribbon == "You can't buy the internet!");
      assert (de_anno.category == Protocol.CategoryType.MOVIE);
      assert (de_anno.icon.equal (icon));
      assert (de_anno.use_small_icon == true);
    }

    static void test_annotated_icon_with_color ()
    {
      var icon = new ThemedIcon ("internet");
      var anno_icon = new Unity.AnnotatedIcon (icon);
      anno_icon.set_colorize_rgba (0.5, 0.0, 1.0, 1.0);
      assert (anno_icon.icon.equal (icon));
      var serialized = anno_icon.to_string ();

      var deserialized = Icon.new_for_string (serialized);
      assert (deserialized.to_string () == serialized);

      var de_anno = deserialized as Protocol.AnnotatedIcon;
      assert (de_anno != null);
      assert (de_anno.icon.equal (icon));
      assert (de_anno.colorize_value == 0x8000ffff);
    }

    static void test_preview_generic ()
    {
      var thumbnail = new ThemedIcon ("internet");
      var preview = new GenericPreview ("A title", "Description", thumbnail);
      preview.image_source_uri = "an uri";

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.GenericPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.description_markup == reconstructed.description);
      assert (preview.image.equal (reconstructed.image));
      assert (preview.image_source_uri == reconstructed.image_source_uri);

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_generic_with_metadata ()
    {
      var thumbnail = new ThemedIcon ("internet");
      var preview = new GenericPreview ("A title", "Description", thumbnail);
      preview.subtitle = "subtitle";
      preview.add_action (new PreviewAction ("action1", "Do stuff!", null));
      preview.add_action (new PreviewAction.with_layout_hint ("action2", "Do other stuff!", null, LayoutHint.LEFT));
      preview.add_action (new PreviewAction.with_uri ("x-unity-preview:file%3A%2F%2F%2Ffoo", "Uri action", null));
      preview.add_info (new InfoHint ("hint1", "Hint", null, "Hint value"));

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.GenericPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.subtitle == reconstructed.subtitle);
      assert (preview.description_markup == reconstructed.description);
      assert (preview.image.equal (reconstructed.image));
      assert (reconstructed.get_actions().length == 3);
      var action = reconstructed.get_actions()[0];
      assert (action.id == "action1");
      action = reconstructed.get_actions()[1];
      assert (action.id == "action2");
      action = reconstructed.get_actions()[2];
      assert (action.hints.contains ("activation-uri"));
      assert (reconstructed.get_info_hints().length == 1);
      var hint = reconstructed.get_info_hints()[0];
      assert (hint.id == "hint1");

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_generic_action_extra_text ()
    {
      var thumbnail = new ThemedIcon ("internet");
      var preview = new GenericPreview ("A title", "Description", thumbnail);
      preview.subtitle = "subtitle";
      var action = new PreviewAction ("action1", "Do stuff!", null);
      action.extra_text = "Foo";
      preview.add_action (action);

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.GenericPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.subtitle == reconstructed.subtitle);
      assert (preview.description_markup == reconstructed.description);
      assert (preview.image.equal (reconstructed.image));
      assert (reconstructed.get_actions().length == 1);
      var rec_action = reconstructed.get_actions()[0];
      assert (rec_action.id == "action1");
      assert (rec_action.hints["extra-text"].get_string () == "Foo");

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_generic_no_details ()
    {
      var preview = GenericPreview.empty ();

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.GenericPreview;

      assert (reconstructed.title == "");
      assert (reconstructed.subtitle =="");
      assert (reconstructed.description == "");
      assert (reconstructed.get_no_details () == true);

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_application ()
    {
      var app_icon = new ThemedIcon ("gedit");
      var preview = new ApplicationPreview ("A title", "subtitle",
                                            "Description", app_icon, null);

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.ApplicationPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.description_markup == reconstructed.description);
      assert (preview.image.equal (reconstructed.image));
      assert (app_icon.equal (reconstructed.app_icon));
      assert (preview.last_update == reconstructed.last_update);
      assert (preview.copyright == reconstructed.copyright);
      assert (preview.license == reconstructed.license);

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_social ()
    {
      var avatar = new ThemedIcon ("gwibber");
      var preview = new SocialPreview ("sender", "title",
                                       "content", avatar);
      preview.add_comment (new SocialPreview.Comment ("comment1", "Comment #1",
                                                      "Text #1", "Monday"));

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.SocialPreview;

      assert (preview.sender == reconstructed.sender);
      assert (preview.title == reconstructed.title);
      assert (preview.content == reconstructed.description);
      assert (avatar.equal (reconstructed.avatar));

      assert (previews_equal (data, reconstructed.serialize ()));
    }


    static void test_preview_music ()
    {
      var artwork = new FileIcon (File.new_for_path ("/usr/share/icons/beatles.jpg"));
      var preview = new MusicPreview ("Beatles", "Help", artwork);

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.MusicPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.subtitle == reconstructed.subtitle);
      assert (preview.image.equal (reconstructed.image));
      assert (artwork.equal (reconstructed.image));

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_music_with_tracks ()
    {
      var artwork = new FileIcon (File.new_for_path ("/usr/share/icons/beatles.jpg"));
      var preview = new MusicPreview ("Beatles", "Help", artwork);
      var track_uri = "file:///media/music/beatles/help/1.mp3";
      var track = new TrackMetadata.full (
          track_uri,
          1,
          "Help",
          "Beatles",
          "Help!",
          123);
      preview.add_track (track);

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.MusicPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.subtitle == reconstructed.subtitle);
      assert (preview.image.equal (reconstructed.image));
      assert (artwork.equal (reconstructed.image));
      assert (reconstructed.track_model.get_n_rows () == 1);

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    delegate PaymentPreview PreviewConstructor (string title, string subtitle,
      FileIcon icon);

    static void assert_payment_deserialization(PreviewConstructor constructor,
      string artwork_path)
    {
      var artwork = new FileIcon (File.new_for_path (artwork_path));
      var preview = constructor ("Beatles", "Help", artwork);

      // set the diff data for the preview
      preview.header = "Hi %s, you purchased in the past from Ubuntu One,"
      + " would you like to use the same payment details?"
      + " Please review your order.";
      preview.email = "test@canonical.com";
      preview.payment_method = "****** ** *** ***34";
      preview.purchase_prize = "2 eur";
      preview.purchase_type = "Digital CD";

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed =
        Protocol.Preview.parse (data) as Protocol.PaymentPreview;

      assert (preview.title == reconstructed.title);
      assert (preview.subtitle == reconstructed.subtitle);
      assert (preview.header == reconstructed.header);
      assert (preview.email == reconstructed.email);
      assert (preview.payment_method == reconstructed.payment_method);
      assert (preview.purchase_prize == reconstructed.purchase_prize);
      assert (preview.purchase_type == reconstructed.purchase_type);
      assert ((int) preview.preview_type == (int) reconstructed.preview_type);
      assert (preview.image.equal (reconstructed.image));
      assert (artwork.equal (reconstructed.image));

      assert (previews_equal (data, reconstructed.serialize ()));
    }

    static void test_preview_payment ()
    {
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview (title, subtitle, artwork);
          assert (preview.preview_type == PaymentPreview.Type.MUSIC);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");
    }

    static void test_preview_music_payment ()
    {
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview.for_music (title, subtitle, artwork);
          assert (preview.preview_type == PaymentPreview.Type.MUSIC);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");

      // same assert but using the property
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview (title, subtitle, artwork);
          preview.preview_type = PaymentPreview.Type.MUSIC;
          assert (preview.preview_type == PaymentPreview.Type.MUSIC);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");
    }

    static void test_preview_app_payment ()
    {
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview.for_application (title, subtitle,
                          artwork);
          assert (preview.preview_type == PaymentPreview.Type.APPLICATION);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");

      // same assert but using the property
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview (title, subtitle, artwork);
          preview.preview_type = PaymentPreview.Type.APPLICATION;
          assert (preview.preview_type == PaymentPreview.Type.APPLICATION);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");
    }

    static void test_preview_error_payment ()
    {
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview.for_error (title, subtitle, artwork);
          assert (preview.preview_type == PaymentPreview.Type.ERROR);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");

      // same assert but using the property
      assert_payment_deserialization (
        (title, subtitle, artwork) => {
          var preview = new PaymentPreview (title, subtitle, artwork);
          preview.preview_type = PaymentPreview.Type.ERROR;
          assert (preview.preview_type == PaymentPreview.Type.ERROR);
          return preview;
        },
        "/usr/share/icons/beatles.jpg");
    }

    static void test_preview_movie ()
    {
      var artwork = new FileIcon (File.new_for_path ("/usr/share/icons/my_favourite_movie.png"));
      var preview = new MoviePreview ("Movie!", "The favourite", "It really is", artwork);
      preview.year = "2012";
      preview.set_rating (4.3f, 12);

      // check if serialization works properly
      var data = preview.serialize ();
      var reconstructed = Protocol.Preview.parse (data) as Protocol.MoviePreview;

      assert (preview.title == reconstructed.title);
      assert (preview.subtitle == reconstructed.subtitle);
      assert (preview.description_markup == reconstructed.description);
      assert (preview.image.equal (reconstructed.image));
      assert (artwork.equal (reconstructed.image));
      assert (reconstructed.num_ratings == 12);
      assert (reconstructed.year == "2012");

      assert (previews_equal (data, reconstructed.serialize ()));
    }
  }
}
