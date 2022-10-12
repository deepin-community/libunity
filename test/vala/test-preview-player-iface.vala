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
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */
using Unity;

namespace Unity.Test
{
  public GLib.MainLoop test_loop;

  internal class PreviewPlayerServiceMock : Extras.PreviewPlayerService, GLib.Object
  {
    public string got_play_uri;
    public string got_video_properties_uri;
    public bool got_close;
    public bool got_stop;
    public bool got_pause;
    public bool got_resume;
    public bool got_pause_resume;

    public PreviewPlayerServiceMock ()
    {
      reset ();
    }

    public void reset ()
    {
      got_play_uri = "";
      got_video_properties_uri = "";
      got_close = false;
      got_stop = false;
      got_pause = false;
      got_pause_resume = false;
      got_resume = false;
    }

    public async void play (string uri) throws Error
    {
      got_play_uri = uri;
      Unity.Test.test_loop.quit ();
    }

    public async void pause () throws Error
    {
      got_pause = true;
      Unity.Test.test_loop.quit ();
    }

    public async void resume () throws Error
    {
      got_resume = true;
      Unity.Test.test_loop.quit ();
    }

    public async void pause_resume () throws Error
    {
      got_pause_resume = true;
      test_loop.quit ();
    }

    public async void stop () throws Error
    {
      got_stop = true;
      test_loop.quit ();
    }

    public async void close () throws Error
    {
      got_close = true;
      Unity.Test.test_loop.quit ();
    }

    public async HashTable<string, Variant> video_properties (string uri) throws Error
    {
      got_video_properties_uri = uri;
      var res = new HashTable<string, Variant> (str_hash, str_equal);
      res.insert ("got_uri", new GLib.Variant.string (uri));
      return res;
    }
  }

  public class PreviewPlayerIfaceTestSuite
  {
    private static Unity.Extras.PreviewPlayer preview_player;
    private static DBusConnection conn;

    public PreviewPlayerIfaceTestSuite ()
    {
      // create fake preview player service that will get all test requests via DBus
      conn = GLib.Bus.get_sync (BusType.SESSION, null);
      GLib.Bus.own_name (BusType.SESSION, "com.canonical.Unity.Lens.Music.PreviewPlayer", 0);

      // create preview player proxy object that interacts with fake player service
      preview_player = new Unity.Extras.PreviewPlayer ();

      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerPlay", PreviewPlayerIfaceTestSuite.test_preview_player_play);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerPause", PreviewPlayerIfaceTestSuite.test_preview_player_pause);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerResume", PreviewPlayerIfaceTestSuite.test_preview_player_resume);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerPauseResume", PreviewPlayerIfaceTestSuite.test_preview_player_pause_resume);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerStop", PreviewPlayerIfaceTestSuite.test_preview_player_stop);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerClose", PreviewPlayerIfaceTestSuite.test_preview_player_close);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerVideoProperties", PreviewPlayerIfaceTestSuite.test_preview_player_video_properties);
      GLib.Test.add_data_func ("/Unit/Utils/PreviewPlayerProgressSignal", PreviewPlayerIfaceTestSuite.test_preview_player_progress_signal);
    }

    internal static PreviewPlayerServiceMock create_service_mock (out uint id)
    {
      PreviewPlayerServiceMock service = new PreviewPlayerServiceMock ();
      id = conn.register_object<Extras.PreviewPlayerService> ("/com/canonical/Unity/Lens/Music/PreviewPlayer", service);
      return service;
    }

    internal static void unregister_service_mock (uint id)
    {
      conn.unregister_object (id);
    }

    internal static void test_preview_player_play ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      preview_player.play ("bar");

      run_with_timeout (test_loop, 5000);

      assert (service.got_play_uri == "bar");
      assert (service.got_pause == false);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_pause ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      preview_player.pause ();

      run_with_timeout (test_loop, 5000);

      assert (service.got_play_uri == "");
      assert (service.got_pause == true);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_resume ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      preview_player.resume ();

      run_with_timeout (test_loop, 5000);

      assert (service.got_play_uri == "");
      assert (service.got_pause == false);
      assert (service.got_resume == true);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_pause_resume ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      preview_player.pause_resume ();

      run_with_timeout (test_loop, 5000);

      assert (service.got_play_uri == "");
      assert (service.got_pause == false);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == true);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_stop ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      preview_player.stop ();

      run_with_timeout (test_loop, 5000);

      assert (service.got_play_uri == "");
      assert (service.got_pause == false);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == true);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_close ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      preview_player.close ();

      run_with_timeout (test_loop, 5000);

      assert (service.got_play_uri == "");
      assert (service.got_pause == false);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == true);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_video_properties ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      HashTable<string, Variant> props = null;

      preview_player.video_properties.begin ("foo", (obj, res) =>
      {
        props = preview_player.video_properties.end (res);
        test_loop.quit ();
      });

      run_with_timeout (test_loop, 5000);

      assert (props != null);
      assert (props["got_uri"].get_string () == "foo");
      assert (service.got_play_uri == "");
      assert (service.got_pause == false);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "foo");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }

    internal static void test_preview_player_progress_signal ()
    {
      uint id;
      var service = create_service_mock (out id);
      test_loop = new MainLoop ();

      string got_progress_uri = "";
      Unity.MusicPreview.TrackState got_progress_state = Unity.MusicPreview.TrackState.STOPPED;
      double got_progress_value = 0.0f;

      preview_player.progress.connect ((uri, state, value) =>
      {
        got_progress_uri = uri;
        got_progress_state = state;
        got_progress_value = value;
        test_loop.quit ();
        });

      service.progress ("foouri", 1, 0.5f);

      run_with_timeout (test_loop, 1000);

      assert (got_progress_uri == "foouri");
      assert (got_progress_state == MusicPreview.TrackState.PLAYING);
      assert (got_progress_value == 0.5f);

      assert (service.got_play_uri == "");
      assert (service.got_pause == false);
      assert (service.got_resume == false);
      assert (service.got_pause_resume == false);
      assert (service.got_stop == false);
      assert (service.got_video_properties_uri == "");
      assert (service.got_close == false);

      unregister_service_mock (id);
    }
  }
}
