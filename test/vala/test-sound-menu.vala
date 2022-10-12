/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2011 Canonical Ltd
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
 * Authored by Conor Curran <conor.curran@canonical.com>
 *
 */

using Unity;


namespace Unity.Test
{


  public class SoundMenuSuite
  {
    public SoundMenuSuite ()
    {
      GLib.Test.add_data_func ("/Unit/SoundMenu/Player/SanityCheck",
                               test_stability);
      GLib.Test.add_data_func ("/Unit/SoundMenu/Player/MetadataUpdates",
                               test_metadata_updates);
      GLib.Test.add_data_func ("/Unit/SoundMenu/Player/PlaybackStatusUpdates",
                               test_playback_status_updates);
      GLib.Test.add_data_func ("/Unit/SoundMenu/Player/CurrentPlaylist",
                               test_current_playlist);
      GLib.Test.add_data_func ("/Unit/SoundMenu/Player/TrackSpecificItems",
                               test_track_specific_items);                         
      GLib.Test.add_data_func ("/Unit/SoundMenu/Player/PlayerSpecificItems",
                               test_player_specific_items);
    }

    internal static void test_stability()
    {
      var player = new MusicPlayer ("rhythmbox.desktop");
      assert (player is MusicPlayer);
    }

    internal static void test_metadata_updates()
    {
      var player = new MusicPlayer ("rhythmbox.desktop");
      TrackMetadata metadata = new TrackMetadata();
      metadata.artist = "Autechre";
      metadata.album = "LP5";
      metadata.title = "Rae";
      player.current_track = metadata;
      assert (player.current_track.artist == metadata.artist);      
      assert (player.current_track.title == metadata.title);      
      assert (player.current_track.album == metadata.album);      
    }

    internal static void test_playback_status_updates()
    {
      var player = new MusicPlayer ("rhythmbox.desktop");
      player.playback_state = PlaybackState.PLAYING;
      assert (player.playback_state == PlaybackState.PLAYING);
    }

    internal static void test_current_playlist()
    {
      var player = new MusicPlayer ("rhythmbox.desktop");
      Playlist pl = new Playlist ("fake-pl-id");
      pl.name = "yellow swans like";
      try{
        pl.icon = Icon. new_for_string("audio-volume-high");
      }
      catch (GLib.Error e){
        warning ("Unable to load Icon from name provided - unable to complete test");
        return;
      }
      player.current_playlist = pl;
      assert (player.current_playlist.name == pl.name);
      assert (player.current_playlist.id == pl.id);
      assert (player.current_playlist.icon.equal (pl.icon));
    }

    internal static void test_track_specific_items()
    {
      var player = new MusicPlayer ("rhythmbox.desktop");
      Dbusmenu.Menuitem menuitem = new Dbusmenu.Menuitem();
      player.track_menu =  menuitem;
      assert (player.track_menu.get_id() ==  menuitem.get_id());
    }

    internal static void test_player_specific_items()
    {
      var player = new MusicPlayer ("rhythmbox.desktop");
      Dbusmenu.Menuitem menuitem = new Dbusmenu.Menuitem();
      player.player_menu = menuitem;
      assert (player.player_menu.get_id() == menuitem.get_id());
    }
  }
  
  public static int main (string[] args)
  {
    SoundMenuSuite sound_menu_test_suite;
    
    Environment.set_variable ("XDG_DATA_HOME", Config.TESTDIR+"/data", true);
    GLib.Test.init (ref args);

    sound_menu_test_suite = new SoundMenuSuite();

    GLib.Test.run ();

    return 0;
  }
}
