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
 */

namespace Unity.Protocol
{

[DBus (name = "com.canonical.Unity.Lens.Music.PreviewPlayer")]
internal interface PreviewPlayerService: GLib.Object
{
  public signal void progress (string uri, uint32 state, double progress);

  public abstract async void play (string uri) throws Error;
  public abstract async void pause () throws Error;
  public abstract async void pause_resume () throws Error;
  public abstract async void resume () throws Error;
  public abstract async void stop () throws Error;
  public abstract async void close () throws Error;
  public abstract async HashTable<string, Variant> video_properties (string uri) throws Error;
}

/**
 * Client class for preview player DBus interface (com.canonical.Unity.Lens.Music.PreviewPlayer).
 */
public class PreviewPlayer: GLib.Object
{
  static const string PREVIEW_PLAYER_DBUS_NAME = "com.canonical.Unity.Lens.Music.PreviewPlayer";
  static const string PREVIEW_PLAYER_DBUS_PATH = "/com/canonical/Unity/Lens/Music/PreviewPlayer";

  /**
   * Reports progress of playback for given track uri.
   */
  public signal void progress (string uri, PlayState state, double progress);

  private async void connect_to () throws Error
  {
    _preview_player_service = yield Bus.get_proxy (BusType.SESSION, PREVIEW_PLAYER_DBUS_NAME, PREVIEW_PLAYER_DBUS_PATH);
    _preview_player_service.progress.connect (on_progress_signal);
  }

  public async void play (string uri) throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    yield _preview_player_service.play (uri);
  }

  public async void pause () throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    yield _preview_player_service.pause ();
  }

  public async void pause_resume () throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    yield _preview_player_service.pause_resume ();
  }

  public async void resume () throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    yield _preview_player_service.resume ();
  }

  public async void stop () throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    yield _preview_player_service.stop ();
  }

  public async void close () throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    yield _preview_player_service.close ();
  }

  public async HashTable<string, Variant> video_properties (string uri) throws Error
  {
    if (_preview_player_service == null)
    {
      yield connect_to ();
    }
    var props = yield _preview_player_service.video_properties (uri);
    return props;
  }

  internal void on_progress_signal (string uri, uint32 state, double progress_value)
  {
    progress (uri, (PlayState) state, progress_value);
  }

  private PreviewPlayerService _preview_player_service;
}
}
