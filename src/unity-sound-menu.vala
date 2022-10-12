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
 * Note: We aim to not wrap a typical MPRIS server but just expose to the consumer
 * the elements we need for it to populate. So that means things like Supported
 * Mime Types which are part of MPRIS but are not relevant to the consumer should 
 * remain hidden and as a result not used.
 *
 * Reasons why a client may not be able to 'embed' itself.
 *   1. Cannot find the desktop file from the name provided
 *   2. Name already taken on the bus, in the current implementation does it hang
 *      around waiting for the name to come available
 */

namespace Unity {

  public class TrackMetadata : GLib.Object
  {
    public string uri { get; set; }
    public int track_no { get; set; }
    public string artist { get; set; }
    public string title { get; set; }
    public string album { get; set; }
    public uint length { get; set; }
    public File art_location
    {
      get { return _art_file; }
      set
      {
        _art_file = value;
        _art_icon = new FileIcon (_art_file);
        notify_property ("art-icon");
      }
    }
    public Icon art_icon
    {
      get { return _art_icon; }
      set
      {
        _art_icon = value;
        if (_art_icon is FileIcon)
        {
          var file_icon = _art_icon as FileIcon;
          _art_file = file_icon.get_file ();
        }
        else _art_file = null;
        notify_property ("art-location");
      }
    }

    private Icon _art_icon;
    private File _art_file;

    public TrackMetadata ()
    {
      Object ();
    }

    public TrackMetadata.full (string uri, int track_no, string title,
                               string artist, string album, uint length)
    {
      Object (uri: uri, track_no: track_no, title: title,
              artist: artist, album: album, length: length);
    }
  }

  public class Playlist : GLib.Object
  {
    public Playlist (string id)
    {
      GLib.Object (id: id);
    }
    public string id {get; construct;}
    public string name {get; set;}
    public Icon icon {get; set;}
    public DateTime creation_date { get; set; }
    public DateTime modification_date { get; set; }
    public DateTime last_play_date { get; set; }
  }

  public enum PlaybackState{
    PLAYING,
    PAUSED
  }

  public class MusicPlayer : GLib.Object
  {
    private MPRISGateway mpris_gateway;
    private GenericArray<Playlist> internal_playlists;

    public GLib.AppInfo app_info {get; construct;}
    public string desktop_file_name {get; construct;}

    public MusicPlayer (string desktop)
    {
      GLib.Object (desktop_file_name : desktop);
      this.internal_playlists = new GenericArray<Playlist>();
    }
    
    construct{
      GLib.AppInfo? a_info = create_app_info (desktop_file_name);
      if (a_info == null){
        critical ("Cannot locate the Desktop file ");  
        return;
      }
      this.app_info = a_info;
      this.title = this.app_info.get_name();

      try {
        this.mpris_gateway = new MPRISGateway (this);
      } catch (IOError e){
        critical ("Could not create the MPRISGateway for '%s': %s",
                   this.app_info.get_name(), e.message);
        return;
      }
      this.title = this.app_info.get_name();
      this.playback_state = PlaybackState.PAUSED;
    }
    
    public void export () {
      mpris_gateway.export ();
    }
    
    public void unexport () {
      mpris_gateway.unexport ();
    }
    
    private static AppInfo? create_app_info ( string desktop )
    {
      DesktopAppInfo info = new DesktopAppInfo ( desktop );
      if ( desktop == null || info == null ){
        warning ("Could not create a desktopappinfo instance from app: %s",
                  desktop);
        return null;
      }
      GLib.AppInfo app_info = info as GLib.AppInfo;
      return app_info;
    }
    
    /* Playlist related public methods - pity Vala doesn't properly support Arrays */
    public bool add_playlist (Playlist p)
    {
      this.mpris_gateway.ensure_playlist_interface_is_raised();
      this.internal_playlists.add(p); 
      // send the signal last...
      this.mpris_gateway.playlist_count = this.internal_playlists.length;
      return true;
    }
    
    public bool remove_playlist (Playlist p)
    {
      bool result = this.internal_playlists.remove(p); 
      // send the signal last...
      this.mpris_gateway.playlist_count = this.internal_playlists.length;
      return result;      
    }

    public Playlist[] get_playlists()
    {
      return internal_playlists.data;
    }

    public void edit_playlist_name (string id, string name)
    {
      internal_playlists.foreach ((pl) =>
      {
        if (pl.id == id)
        {
          pl.name = name;
          this.mpris_gateway.edited_playlist = pl;
          return;
        }
      });
    }
        
    /*
     * Public API
     * Properties
     */
    public bool is_blacklisted {get; set;}
    public string title {get; set;}
    public bool can_go_next {get; set;}
    public bool can_go_previous {get; set;}
    public bool can_play {get; set;}
    public bool can_pause {get; set;}     
    public TrackMetadata current_track {get; set;}
    public PlaybackState playback_state {set; get;}
    public Playlist current_playlist {get; set;}
    public Dbusmenu.Menuitem? track_menu { get; set; }
    public Dbusmenu.Menuitem? player_menu { get; set; }

    /*
     * Public API
     * Signals
     */
    public signal void raise ();
    public signal void play_pause ();
    public signal void previous ();
    public signal void next ();
    public signal void activate_playlist (ObjectPath playlist_id);
  }
}
