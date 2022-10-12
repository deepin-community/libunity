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
 */

namespace Unity {
  const string MPRIS_INTERFACE_ROOT_PATH = "/org/mpris/MediaPlayer2";
  const string MPRIS_INTERFACE_ROOT      = "org.mpris.MediaPlayer2";
  const string MPRIS_INTERFACE_PREFIX    = "org.mpris.MediaPlayer2.";
  const string MPRIS_INTERFACE_PLAYER    = "org.mpris.MediaPlayer2.Player";
  const string MPRIS_INTERFACE_PLAYLISTS = "org.mpris.MediaPlayer2.Playlists";

  private class MPRISGateway: GLib.Object
  {
    public MusicPlayer consumer{get; construct;}
    private MprisRoot mpris_root_interface;
    private MprisPlayer mpris_player_interface;
    private MprisPlaylists mpris_playlist_interface;
    private PropertyUpdateManager prop_manager;
    private BlacklistManager blacklist_mgr;
    private SpecificItemManager specific_menuitem_mgr;
    private DBusConnection dbus_connection;
    private bool playlist_interface_raised;
    // Not ideal but I couldn't see any other way around the array problem
    // and the missing notify signal.
    public Playlist edited_playlist {get; set;}
    public int playlist_count {get; set;}
    
    private uint bus_name_owner_handle;
    private uint bus_root_iface_handle;
    private uint bus_player_iface_handle;
    
    public MPRISGateway (MusicPlayer client)
    {
      GLib.Object (consumer : client);
    }

    construct
    { 
      blacklist_mgr = new BlacklistManager (consumer);
      specific_menuitem_mgr = new SpecificItemManager (consumer);
      
      playlist_interface_raised = false;
      bus_name_owner_handle = 0;
      bus_root_iface_handle = 0;
      bus_player_iface_handle = 0;
    }
    
    public void export () {
      if (bus_name_owner_handle != 0)
        {
          critical ("Can not export MPRISGateway@%p. It is already exported",
                    this);
          return;
        }

      if (dbus_connection == null){
        try {
          dbus_connection = Bus.get_sync (BusType.SESSION);
        }
        catch(IOError e){
          critical ("unity-sound-menu-mpris-MPRISGateway: Cannot connect to the session bus.");
        }
      }

      if (prop_manager == null)
          prop_manager = new PropertyUpdateManager (dbus_connection);

      if (mpris_root_interface == null)
        mpris_root_interface = new MprisRoot (consumer, prop_manager);

      if (mpris_player_interface == null)
        mpris_player_interface = new MprisPlayer (consumer, prop_manager);

      if (mpris_playlist_interface == null)
        mpris_playlist_interface = new MprisPlaylists (consumer, prop_manager, this);
      
      try {
        bus_root_iface_handle =
                dbus_connection.register_object (MPRIS_INTERFACE_ROOT_PATH,
                                                 mpris_root_interface);
        bus_root_iface_handle =
                dbus_connection.register_object (MPRIS_INTERFACE_ROOT_PATH,
                                                 mpris_player_interface);
      }  catch (IOError e) {
        critical ("Could not register root or player interface for '%s': %s",
                   this.consumer.app_info.get_name(), e.message);
      }
      
      // TODO: I think you will need to ensure the name is only one word and lower case 
      var mpris_extension = consumer.app_info.get_name().down();
      try {
        var whitespace_regex = new Regex("\\s");
        mpris_extension = whitespace_regex.replace_literal(mpris_extension, -1, 0, "_");
      } catch (RegexError e) {
        critical("Whitespace regex failed to replace for %s: %s", mpris_extension, e.message);
      }
      var dbus_name = MPRIS_INTERFACE_PREFIX.concat (mpris_extension);
      bus_name_owner_handle =
            Bus.own_name (BusType.SESSION,
                          dbus_name,
                          BusNameOwnerFlags.NONE,
                          null,
                          () => { Trace.log ("Owning name %s", dbus_name); },
                          on_name_lost);
    }
    
    public void unexport () {
      if (bus_name_owner_handle == 0)
        {
          critical ("Can not unexport MPRISGateway@%p. It is not exported",
                    this);
          return;
        }
        
        Bus.unown_name (bus_name_owner_handle);
        bus_name_owner_handle = 0;
        
        dbus_connection.unregister_object (bus_root_iface_handle);
        bus_root_iface_handle = 0;
        
        dbus_connection.unregister_object (bus_player_iface_handle);
        bus_player_iface_handle = 0;
    }
    
    private void on_name_lost (DBusConnection conn, string name) {
      Trace.log_object (this, "Lost name '%s'", name);
    }
    
    public void ensure_playlist_interface_is_raised()
    {
      if (playlist_interface_raised == true)return;
      
      try {
        this.dbus_connection.register_object (MPRIS_INTERFACE_ROOT_PATH,
                                              mpris_playlist_interface);
        playlist_interface_raised = true;
      }
      catch (IOError e) {
        critical ("Could not register playlist interface for %s: %s",
                   this.consumer.app_info.get_name(), e.message);  
      }
    }
  }

  private class SpecificItemManager :Object{
    private Dbusmenu.Server?    _player_item_server;
    internal ObjectPath         _player_specific_object_path;
    private Dbusmenu.Server?    _track_item_server;
    internal ObjectPath         _track_specific_object_path;
    public MusicPlayer          consumer {get; construct;}
    private SoundServiceInterface sound_service_interface;
    
    public SpecificItemManager (MusicPlayer client){
      GLib.Object (consumer : client);
    }
    construct{
      _track_item_server = null;
      _player_item_server = null;
      _track_specific_object_path = new ObjectPath (@"/com/canonical/indicators/sound/track_specific/$(consumer.app_info.get_name().down())");
      _player_specific_object_path = new ObjectPath (@"/com/canonical/indicators/sound/player_specific/$(consumer.app_info.get_name().down())");
      try {
        this.sound_service_interface = Bus.get_proxy_sync (BusType.SESSION,
                                                           "com.canonical.indicators.sound",
                                                           "/com/canonical/indicators/sound/service",
                                                           DBusProxyFlags.DO_NOT_AUTO_START);
      }
      catch(IOError e){
        warning ("mpris-sound-menu-mpris - SpecificItemManager - Unable to connect to indicator-sound's interface");
      }
      this.consumer.notify["track-menu"].connect (on_track_specific_change);
      this.consumer.notify["player-menu"].connect (on_player_specific_change);
    }
    
    private void on_track_specific_change (ParamSpec p)
    {
      if (this.consumer.track_menu != null && _track_item_server == null){
        _track_item_server = new Dbusmenu.Server (_track_specific_object_path);
        this.sound_service_interface.EnableTrackSpecificItems.begin( _track_specific_object_path,
                                                                     this.consumer.desktop_file_name.split(".")[0]);
        _track_item_server.root_node = this.consumer.track_menu;
      }
      else if (this.consumer.track_menu == null){
        _track_item_server = null;
      }
    }
    
    private void on_player_specific_change (ParamSpec p)
    {
      if (this.consumer.player_menu != null && _player_item_server == null){
        _player_item_server = new Dbusmenu.Server (_player_specific_object_path);
        this.sound_service_interface.EnablePlayerSpecificItems.begin( _player_specific_object_path,
                                                                this.consumer.desktop_file_name.split(".")[0]);        
        _player_item_server.root_node = this.consumer.player_menu;
      }
      else if (this.consumer.player_menu == null){
        _player_item_server = null;
      }
    }
  }
  
  /**
  PropertyUpdate Manager
  Handles all property updates for each of the 3 MPRIS interfaces
  **/
  private class PropertyUpdateManager : Object{

    private GLib.HashTable<string, GLib.HashTable<string, Variant>> queued_properties;
    private GLib.HashTable<string, uint> source_ids;
    public  DBusConnection connection {get; construct;}

    public PropertyUpdateManager (DBusConnection conn)
    {
      GLib.Object (connection: conn);
    }
    
    construct {
      queued_properties = new HashTable<string, GLib.HashTable<string, Variant>>(str_hash, str_equal);
      queued_properties.insert (MPRIS_INTERFACE_ROOT, new HashTable<string, Variant>(str_hash, str_equal));
      queued_properties.insert (MPRIS_INTERFACE_PLAYER, new HashTable<string, Variant>(str_hash, str_equal));
      queued_properties.insert (MPRIS_INTERFACE_PLAYLISTS, new HashTable<string, Variant>(str_hash, str_equal));

      source_ids = new HashTable<string,uint>(str_hash, str_equal);
      source_ids.insert (MPRIS_INTERFACE_ROOT, (uint)0);
      source_ids.insert (MPRIS_INTERFACE_PLAYER, (uint)0);
      source_ids.insert (MPRIS_INTERFACE_PLAYLISTS, (uint)0);
    }

    public void queue_property_update (string prop_name, Variant update, string interface_name)
    {
      var appropriate_hash = queued_properties.lookup (interface_name);
      appropriate_hash.insert (prop_name, update);
      var appropriate_source_id = source_ids.lookup (interface_name);
      if (appropriate_source_id == 0){   
        appropriate_source_id = Idle.add (() => { return dispatch_property_update (interface_name);});   
        source_ids.insert (interface_name, appropriate_source_id);         
      }
    }
      
    private bool dispatch_property_update (string interface_name) 
    {
      var builder             = new VariantBuilder (new VariantType ("a{sv}"));
      var invalidated_builder = new VariantBuilder (new VariantType ("as"));
      var appropriate_hash    = queued_properties.lookup (interface_name);

      if (appropriate_hash == null){
        warning ("can't find the appropriate hash within queued properties for name %s", interface_name);
        return false;  
      }
      if (appropriate_hash.size() == 0){
        warning ("dispatch called on an empty array !!!");
        source_ids.insert (interface_name, (uint)0);
        return false;
      }
      
      foreach (string name in appropriate_hash.get_keys ()) {
			  Variant variant = appropriate_hash.lookup (name);
			  builder.add ("{sv}", name.dup(), variant);
		  }
      
      this.emit_dbus_signal ("org.freedesktop.DBus.Properties", 
                             "PropertiesChanged", 
                              new Variant ("(sa{sv}as)", 
                                            interface_name, 
                                            builder, 
                                            invalidated_builder));               

      source_ids.insert (interface_name, (uint)0);
      appropriate_hash.remove_all ();
      
      return false;
    } 

    public void emit_dbus_signal (string interface_name,
                                  string signal_name,
                                  Variant payload)
    {
		  try {
			  this.connection.emit_signal (null,
                                     MPRIS_INTERFACE_ROOT_PATH,
			                               interface_name,
			                               signal_name,
                                     payload);
		  }
		  catch(Error e) {
			  warning ("Error emitting DBus signal '%s.%s': %s\n",
			           interface_name, signal_name, e.message);
      }
    }
  }

  /*
   Use the GSettings API directly.
   */
  private class BlacklistManager : GLib.Object
  {
    private Settings settings;
    private MusicPlayer consumer;
    
    public BlacklistManager (MusicPlayer client)
    {
      this.consumer = client;
      this.wire_it_up();
    }
    construct{
    }

    private void wire_it_up()
    {
      this.settings = new Settings ("com.canonical.indicator.sound");
      this.consumer.is_blacklisted = check_presence ();
      this.settings.changed["blacklisted-media-players"].connect (on_blacklist_event);
      this.consumer.notify["is-blacklisted"].connect (consumer_blacklist_change);
    }

    private void consumer_blacklist_change ()
    {
      if (this.consumer.is_blacklisted == true){
        add_to_blacklist();
      }
      else{
        remove_from_blacklist();
      }
    }
    
    private void on_blacklist_event()
    {
      bool is_present = check_presence ();
      if (this.consumer.is_blacklisted != is_present) {
        Trace.log_object (this, "Blacklist Event - consumer blacklist is not the same as the situation");
        this.consumer.is_blacklisted = is_present;
      }
    }
    
    private string? get_blacklist_name()
    {
      var app_id = this.consumer.app_info.get_id ();

      if (app_id == null) {
        return null;
      }

      var components = app_id.split(".");
      
      return components[0];
    }
     
    public bool check_presence()
    {
      var blacklist = this.settings.get_strv ("blacklisted-media-players");
      foreach (var s in blacklist){
        if (s == get_blacklist_name()) return true;
      }
      return false;
    }
    
    private void add_to_blacklist ()
    {
      var blacklist = new GLib.VariantBuilder (new VariantType("as"));
      foreach (var already_blacklisted in this.settings.get_strv("blacklisted-media-players"))
      {
        if (already_blacklisted == get_blacklist_name ())
          return;
        blacklist.add("s", already_blacklisted);
      }
      blacklist.add("s", get_blacklist_name());
      
      this.settings.set_value("blacklisted-media-players", blacklist.end());
    }

    private void remove_from_blacklist()
    {
      var blacklist = new GLib.VariantBuilder(new VariantType("as"));
      foreach (var already_blacklisted in this.settings.get_strv("blacklisted-media-players"))
      {
        if (already_blacklisted == get_blacklist_name())
          continue;
        blacklist.add(already_blacklisted);
      }
      this.settings.set_value("blacklisted-media-players", blacklist.end());
    }
  }
  /****************************************************************************************/
  // Indicator sound DBus interface implementations
  /***************************************************************************************/
  [DBus (name = "com.canonical.indicators.sound")]
  private interface SoundServiceInterface : Object {
    public abstract async void EnableTrackSpecificItems (ObjectPath object_path, string desktop_id) throws IOError;
    public abstract async void EnablePlayerSpecificItems (ObjectPath object_path, string desktop_id) throws IOError;
  }

  /****************************************************************************************/
  // MPRIS DBus interface implementations
  /***************************************************************************************/
  
  /**
  MPRIS Root 
  **/
  [DBus (name = "org.mpris.MediaPlayer2")]
  private class MprisRoot : GLib.Object {

    private MusicPlayer consumer;
    private PropertyUpdateManager prop_mgr;
    private string mpris_desktop_entry;
    
    public MprisRoot (MusicPlayer client, PropertyUpdateManager prop_mgr)
    {
      this.consumer = client;
      this.prop_mgr = prop_mgr;
      this.wire_up();
    }
    construct{
    }
    
    private void wire_up()
    {
      this.consumer.notify["title"].connect ((obj, pspec) => {
        prop_mgr.queue_property_update ("Identity", this.consumer.title, MPRIS_INTERFACE_ROOT); 
      });
      mpris_desktop_entry = this.consumer.desktop_file_name.split(".")[0];
    }
    
    
    // properties
    public bool has_tracklist{
      get{
        return false;
      }
    }
    
    public bool can_quit{
      get{
        return false;
      }
    }

    public bool can_raise{
      get{
        return true;
      }
    }

    public string identity{
      get{
        return this.consumer.title;
      }
    }
      
    public string desktop_entry{
      get{
        return this.mpris_desktop_entry;
      }
    }
      
    // methods
    public async void raise() throws IOError{
      this.consumer.raise ();
    }
  }

  /**
  MPRIS Player
  **/
  [DBus (name = "org.mpris.MediaPlayer2.Player")]
  private class MprisPlayer : Object {
    
    private MusicPlayer consumer;
    private PropertyUpdateManager prop_mgr;
    private GLib.HashTable<string, Variant> current_metadata; 

    public MprisPlayer (MusicPlayer client, PropertyUpdateManager prop_mgr)
    {
      this.consumer = client;
      this.prop_mgr = prop_mgr;
      this.wire_it_up ();
    }
    construct{
    }

    private void wire_it_up()
    {
      this.current_metadata = new GLib.HashTable<string, Variant>(str_hash, str_equal);
      this.consumer.notify["current-track"].connect (this.on_metadata_update);
      this.consumer.notify["playback-state"].connect ((obj, pspec) => {
        string update = this.consumer.playback_state == PlaybackState.PAUSED ? "Paused" : "Playing";
        prop_mgr.queue_property_update ("PlaybackStatus", update, MPRIS_INTERFACE_PLAYER); 
      });
      this.consumer.notify["can-go-next"].connect ((obj, pspec) => {
        prop_mgr.queue_property_update ("CanGoNext", this.consumer.can_go_next, MPRIS_INTERFACE_PLAYER);
      });
      this.consumer.notify["can-go-previous"].connect ((obj, pspec) => {
        prop_mgr.queue_property_update ("CanGoPrevious", this.consumer.can_go_previous, MPRIS_INTERFACE_PLAYER);
      });
      this.consumer.notify["can-play"].connect ((obj, pspec) => {
        prop_mgr.queue_property_update ("CanPlay", this.consumer.can_play, MPRIS_INTERFACE_PLAYER);
      });
      this.consumer.notify["can-pause"].connect ((obj, pspec) => {
        prop_mgr.queue_property_update ("CanPause", this.consumer.can_pause, MPRIS_INTERFACE_PLAYER);
      });
      // Send out a playback status message to make sure everything is driven by the consumer
      string update = this.consumer.playback_state == PlaybackState.PAUSED ? "Paused" : "Playing";
      prop_mgr.queue_property_update ("PlaybackStatus", update, MPRIS_INTERFACE_PLAYER);
    }
    
    protected void on_metadata_update (ParamSpec pspec)
    { 
      this.current_metadata.remove_all();
      if (this.consumer.current_track.art_location != null)
        this.current_metadata.insert ("mpris:artUrl", this.consumer.current_track.art_location.get_uri());
      if (this.consumer.current_track.artist != null)
        this.current_metadata.insert ("xesam:artist", this.consumer.current_track.artist);
      if (this.consumer.current_track.album != null)      
        this.current_metadata.insert ("xesam:album", this.consumer.current_track.album);
      if (this.consumer.current_track.title != null)
        this.current_metadata.insert ("xesam:title", this.consumer.current_track.title);
      prop_mgr.queue_property_update ("Metadata", this.current_metadata, MPRIS_INTERFACE_PLAYER);
    }

    // properties
    public HashTable<string, Variant> metadata {
      get{
        return this.current_metadata;  
      }
    }
    public string playback_status {
      get{
        return this.consumer.playback_state == PlaybackState.PAUSED ? "Paused" : "Playing";
      }
    }

    public bool can_control{
      get{
        return true;
      }
    }
    
    public bool can_go_next{
      get{
        return this.consumer.can_go_next;
      }
    }

    public bool can_go_previous{
      get{
        return this.consumer.can_go_previous;
      }
    }

    public bool can_play{
      get{
        return this.consumer.can_play;
      }
    }
    public bool can_pause{
      get{
        return this.consumer.can_pause;
      }
    }
    
    // methods
    public async void play_pause() throws IOError
    {
      this.consumer.play_pause ();
    }
    
    public async void next() throws IOError
    {
      this.consumer.next ();
    }
    
    public async void previous() throws IOError
    {
      this.consumer.previous ();
    }        
  }

  /**
  MPRIS Playlists
  **/  
  public struct PlaylistDetails{
    public GLib.ObjectPath id;
    public string name;
    public string icon_name;
  }

  public struct ActivePlaylistContainer{
    public bool valid;
    public PlaylistDetails details;
  }

  [DBus (name = "org.mpris.MediaPlayer2.Playlists")]
  private class MprisPlaylists : Object {
    private MusicPlayer consumer;
    private PropertyUpdateManager prop_mgr;

    private MPRISGateway gateway;
        
    public MprisPlaylists (MusicPlayer consumer, PropertyUpdateManager prop_mgr, MPRISGateway gw)
    {
      this.gateway = gw;
      this.consumer = consumer;
      this.prop_mgr = prop_mgr;
      this.wire_up();
    }
    construct{
    }
    
    private void wire_up(){
      this.consumer.notify["current-playlist"].connect (on_current_playlist_update);
      // Not pretty but its the only way I can see for us to be notified that one of the 
      // playlists has had a name change.
      this.gateway.notify["edited-playlist"].connect(on_playlist_name_change);
      this.gateway.notify["playlist-count"].connect(on_playlist_count_change);
    }

    private void on_current_playlist_update (ParamSpec p)
    {
      this.prop_mgr.queue_property_update ("ActivePlaylist",
                                           this.active_playlist,
                                           MPRIS_INTERFACE_PLAYLISTS);
    }
    // For the sound menu we are only interested in name changes
    // ID change should mean a complete new playlist and 
    // icon change doesn't effect us now since the icons are not shown on the menu
    private void on_playlist_name_change (ParamSpec p)
    { 
      PlaylistDetails details = PlaylistDetails ();
      prep_playlist (this.gateway.edited_playlist, &details);
      
      var output = new Variant ("(oss)",
                                details.id,
                                details.name,
                                details.icon_name);
      this.prop_mgr.emit_dbus_signal (MPRIS_INTERFACE_PLAYLISTS,
                                      "PlaylistChanged",
                                      output);
    }

    private void on_playlist_count_change (ParamSpec p)
    {
      prop_mgr.queue_property_update ("PlaylistCount",
                                      this.gateway.playlist_count,
                                      MPRIS_INTERFACE_PLAYLISTS);
    }
    
    
    private void prep_playlist (Playlist unity_pl, PlaylistDetails* outward)
    {
      outward->id = new ObjectPath(unity_pl.id);
      outward->name = unity_pl.name;
      outward->icon_name = unity_pl.icon.to_string();
    }

    //properties
    public string[] orderings{
      owned get{
        return {"alphabetical"};
      }
    }
    
    public uint32 playlist_count {
      get{
        return this.consumer.get_playlists().length;
      }
    }
    
    public ActivePlaylistContainer active_playlist {
      owned get{
        
        ActivePlaylistContainer c = ActivePlaylistContainer();
        PlaylistDetails details = PlaylistDetails();
        c.valid = this.consumer.current_playlist != null;

        if (c.valid){
          prep_playlist (this.consumer.current_playlist, &details);
        }
        else{
          // Fill it with a blank struct - the objectpath needs to be populated with something
          // otherwise it will segfault when the current playlist is NULL.
          details.id = new GLib.ObjectPath("/");
          details.name = "";
          details.icon_name = "";
        }
        c.details = details;
        return c;
      }
    }
    
    //methods
    public async void activate_playlist (ObjectPath playlist_id) throws IOError
    {
      this.consumer.activate_playlist (playlist_id);
    }
    
    public async PlaylistDetails[] get_playlists (uint32 index,
                                                 uint32 max_count,
                                                 string order,
                                                 bool reverse_order) throws IOError{
      PlaylistDetails[] result = {};
      foreach (Unity.Playlist up in this.consumer.get_playlists()){
        PlaylistDetails details = PlaylistDetails ();
        prep_playlist (up, &details);
        result += details;
      }
      return result;
    }
  }
}