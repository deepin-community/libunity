using Unity;
using Gee;

const string MPRIS_PREFIX = "org.mpris.MediaPlayer2.";
const string MPRIS_MEDIA_PLAYER_PATH = "/org/mpris/MediaPlayer2";
const string FREEDESKTOP_SERVICE = "org.freedesktop.DBus";
const string FREEDESKTOP_OBJECT = "/org/freedesktop/DBus";

[DBus (name = "org.freedesktop.DBus")]
public interface FreeDesktopObject: Object {
  public abstract async string[] list_names() throws IOError;
  public abstract signal void name_owner_changed ( string name,
                                                   string old_owner,
                                                   string new_owner );
}


[DBus (name = "org.mpris.MediaPlayer2")]
public interface MprisRoot : Object {
  // properties
  public abstract bool HasTracklist{owned get; set;}
  public abstract bool CanQuit{owned get; set;}
  public abstract bool CanRaise{owned get; set;}
  public abstract string Identity{owned get; set;}
  public abstract string DesktopEntry{owned get; set;}
  // methods
  public abstract async void Quit() throws IOError;
  public abstract async void Raise() throws IOError;
}

[DBus (name = "org.mpris.MediaPlayer2.Player")]
public interface MprisPlayer : Object {
  // properties
  public abstract HashTable<string, Variant?> Metadata{owned get; set;}
  public abstract int32 Position{owned get; set;}
  public abstract string PlaybackStatus{owned get; set;}  
  // methods
  public abstract async void PlayPause() throws IOError;
  public abstract async void Next() throws IOError;
  public abstract async void Previous() throws IOError;
  public abstract async void Seek(int64 offset) throws IOError;
  // signals
  public signal void Seeked(int64 new_position);
}

// Playlist container
public struct PlaylistDetails{
  public ObjectPath path;
  public string name;
  public string icon_name;
}

// Active playlist property container
public struct ActivePlaylistContainer{
  public bool valid;
  public PlaylistDetails details;
}

[DBus (name = "org.mpris.MediaPlayer2.Playlists")]
public interface MprisPlaylists : Object {
  //properties
  public abstract string[] Orderings{owned get; set;}
  public abstract uint32 PlaylistCount{owned get; set;}
  public abstract ActivePlaylistContainer ActivePlaylist {owned get; set;}
  
  //methods
  public abstract async void ActivatePlaylist(ObjectPath playlist_id) throws IOError;
  public abstract async PlaylistDetails[] GetPlaylists (  uint32 index,
                                                          uint32 max_count,
                                                          string order,
                                                          bool reverse_order ) throws IOError;
  //signals
  public signal void PlaylistChanged (PlaylistDetails details);
  
}

[DBus (name = "org.freedesktop.DBus.Properties")]
public interface FreeDesktopProperties : Object{
  public signal void PropertiesChanged (string source, HashTable<string, Variant?> changed_properties,
                                        string[] invalid );
}

public errordomain XmlError {
  FILE_NOT_FOUND,
  XML_DOCUMENT_EMPTY
}

public class Mpris2Watcher : GLib.Object
{
  FreeDesktopObject fdesktop_obj;
  
  public signal void client_appeared ();
  public signal void client_disappeared ();

  public Mpris2Watcher ()
  {
  }

  construct
  {  
    try {
      this.fdesktop_obj = Bus.get_proxy_sync ( BusType.SESSION,
                                               FREEDESKTOP_SERVICE,
                                               FREEDESKTOP_OBJECT,
                                               DBusProxyFlags.DO_NOT_LOAD_PROPERTIES );      
      this.fdesktop_obj.name_owner_changed.connect (this.name_changes_detected);      
    }
    catch ( IOError e ){
      warning( "Mpris2watcher could not set up a watch for mpris clients appearing on the bus: %s",
                e.message );
    }
  }

  // At startup check to see if there are clients up that we are interested in
  public async void check_for_active_clients()
  {
    string[] interfaces;
    try{
      interfaces = yield this.fdesktop_obj.list_names();
    }
    catch ( IOError e) {
      warning( "Mpris2watcher could fetch active interfaces at startup: %s",
                e.message );
      return;
    }
    foreach (var address in interfaces) {
      if (address.has_prefix (MPRIS_PREFIX)){
        MprisRoot? mpris2_root = this.create_mpris_root(address);
        if (mpris2_root == null) return;
        client_appeared ();
      }
    }
  }

  private void name_changes_detected ( FreeDesktopObject dbus_obj,
                                       string     name,
                                       string     previous_owner,
                                       string     current_owner ) 
  {
    MprisRoot? mpris2_root = this.create_mpris_root(name);                                         

    if (mpris2_root == null) return;
    

    if (previous_owner == "" && current_owner != "") {
      debug ("Client '%s' has appeared", name);
      client_appeared ();
    }
  }

  private MprisRoot? create_mpris_root ( string name ){
    MprisRoot mpris2_root = null;
    if ( name.has_prefix (MPRIS_PREFIX) ){
      try {
        mpris2_root = Bus.get_proxy_sync (  BusType.SESSION,
                                            name,
                                            MPRIS_MEDIA_PLAYER_PATH );
      }
      catch (IOError e){
        warning( "Mpris2watcher could not create a root interface: %s",
                  e.message );
      }
    }
    return mpris2_root;
  }
  
}



public class Mpris2Controller : GLib.Object
{
  public string dbus_name {get; construct;}

  public MprisRoot mpris2_root;
  public MprisPlayer player;
  public MprisPlaylists playlists;
  public FreeDesktopProperties properties_interface;
  public ArrayList<string> received_prop_updates_for_playback_status;
  public ArrayList<GLib.HashTable<string, Variant?>> received_prop_updates_for_metadata_change;
  public ArrayList<ActivePlaylistContainer?> received_prop_updates_for_active_playlists;
  
  public Mpris2Controller(string name)
  {
    GLib.Object (dbus_name : name);
  }
  construct{
    try {

      this.received_prop_updates_for_playback_status = new ArrayList<string>();
      this.received_prop_updates_for_metadata_change = new ArrayList<GLib.HashTable<string, Variant?>>();
      this.received_prop_updates_for_active_playlists = new ArrayList<ActivePlaylistContainer?>();

      this.mpris2_root = Bus.get_proxy_sync ( BusType.SESSION,
                                              dbus_name,
                                              "/org/mpris/MediaPlayer2" );
      this.player = Bus.get_proxy_sync ( BusType.SESSION,
                                         dbus_name,
                                         "/org/mpris/MediaPlayer2" );
      this.properties_interface = Bus.get_proxy_sync ( BusType.SESSION,
                                                       "org.freedesktop.Properties.PropertiesChanged",
                                                       "/org/mpris/MediaPlayer2" );
      this.properties_interface.PropertiesChanged.connect ( property_changed_cb );
      
      this.playlists = Bus.get_proxy_sync ( BusType.SESSION,
                                            dbus_name,
                                            "/org/mpris/MediaPlayer2" );
    } 
    catch (IOError e) {
      critical("Can't create our DBus interfaces - %s", e.message);
    }
  }

  public void property_changed_cb ( string interface_source,
                                    HashTable<string, Variant?> changed_properties,
                                    string[] invalid )
  {
    if (changed_properties.lookup ("PlaybackStatus") != null){
      this.received_prop_updates_for_playback_status.add (changed_properties.lookup ("PlaybackStatus").get_string());      
    }
    else if (changed_properties.lookup ("Metadata") != null){
      this.received_prop_updates_for_metadata_change.add ((GLib.HashTable<string, Variant?>)changed_properties.lookup ("Metadata"));    
    }
    else if (changed_properties.lookup ("ActivePlaylist") != null){
      // interesting I can reproduce the race condition which I was seeing with the clients
      Timeout.add (500, update_active_playlist_array);
    }
  }

  private bool update_active_playlist_array()
  {
    this.received_prop_updates_for_active_playlists.add (this.playlists.ActivePlaylist);    
    return false;
  }
}

public class MprisClient : GLib.Object
{
  public MainLoop mainloop {get; construct;}
  public Mpris2Watcher watcher;
  
  public MprisClient (MainLoop loop)
  {
    GLib.Object (mainloop : loop);
  }

  construct{
    this.watcher = new Mpris2Watcher();
    watcher.client_appeared.connect (on_client_appeared);
    watcher.check_for_active_clients();
  }

  public void on_client_appeared ()
  {
    Timeout.add_seconds (5, () =>{
      run_tests();
      return escape();
    });
  }

  public bool escape()
  {
    this.mainloop.quit();
    return false;
  }
  
  public static int main (string[] args)  
  {
    Environment.set_variable ("XDG_DATA_HOME", Config.TESTDIR+"/data", true);
    MainLoop mainloop = new MainLoop (MainContext.default(), false);
    
    Test.init (ref args);

    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Player/PlaybackStatusPropertyUpdates",
                             player_property_updates_playback_status);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Player/MetadataPropertyUpdates",
                             player_property_updates_metadata);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Playlists/ActivePlaylistPropertyUpdates",
                             playlists_property_update_test_activate_playlist);

    MprisClient client = new MprisClient (mainloop);
    
    /* Make sure we flush and sync all needed state */
    while (mainloop.get_context().pending() == true){
      mainloop.get_context().iteration (true);
    }
    
    Idle.add (run_tests);
    mainloop.run();
    return 0;                                 
  }

  public static bool run_tests()
  {
    Test.run ();
    return false;
  }


  // No legitimate way of testing, tested manually and it seemed fine
  /*internal static void root_property_updates_identity()
  {    
  }*/

  private const string RB_NAME = "org.mpris.MediaPlayer2.rhythmbox";

  internal static void player_property_updates_playback_status ()
  {
    Mpris2Controller controller = new Mpris2Controller (RB_NAME);
    controller.player.PlayPause();

    Timeout.add_seconds (2, () => {
      //  note the client will miss the initial playbackstatus update hence the first entry is
      // 'playing' from our playpause instruction just above.
      assert (controller.received_prop_updates_for_playback_status[0] == "Playing");
      //debug ("pbs = %s", controller.received_prop_updates_for_playback_status[0]);      
      return false;
    });
  }
  
  internal static void player_property_updates_metadata()
  {
    Mpris2Controller controller = new Mpris2Controller (RB_NAME);
    controller.player.Next();
    Timeout.add_seconds (2, () => {
      assert (controller.received_prop_updates_for_metadata_change.size == 1);
      Variant? artist_v = controller.received_prop_updates_for_metadata_change[0].lookup("xesam:artist");
      assert (artist_v.get_string() == "Sonnamble");
      Variant? album_v = controller.received_prop_updates_for_metadata_change[0].lookup("xesam:album");
      assert (album_v.get_string() == "Seven months in E minor");
      //debug ("album = %s", album_v.get_string());
      Variant? title_v = controller.received_prop_updates_for_metadata_change[0].lookup("xesam:title");
      assert (title_v.get_string() == "Sehnsucht");
      //debug ("title = %s", title_v.get_string());
      Variant? art_v = controller.received_prop_updates_for_metadata_change[0].lookup("mpris:artUrl");
      assert (art_v.get_string() == "file:///home/user/download/sonnamble.jpg");
      //debug ("art = %s", art_v.get_string());
      return false;
    });
  }

  internal static void playlists_property_update_test_activate_playlist()
  {
    MainLoop loop = new MainLoop();
    do_test_async_property_update_activate_playlist (loop);
    loop.run();
  }

  internal static async void do_test_async_property_update_activate_playlist (MainLoop loop)
  {
    Mpris2Controller contr = new Mpris2Controller (RB_NAME);
    try{
      PlaylistDetails[] pls = yield contr.playlists.GetPlaylists (0,
                                                                  10,
                                                                  "alphabetical",
                                                                  false);      
      contr.playlists.ActivatePlaylist.begin(pls[1].path);
      // debug ("new playlist name %s", pls[1].name);
      // Give it a sec
      Timeout.add_seconds (3, () => {
        assert (contr.received_prop_updates_for_active_playlists.size == 1);
        assert (contr.received_prop_updates_for_active_playlists[0].valid == true);
        assert (contr.received_prop_updates_for_active_playlists[0].details.path == "/fake/pl2/id");
        assert (contr.received_prop_updates_for_active_playlists[0].details.name == "another playlist");
        assert (contr.received_prop_updates_for_active_playlists[0].details.icon_name == "audio-volume-high");
        return false;
       });
    }
    catch (IOError e){
      warning ("do_test_async_property_update_activate_playlist: Failed to activate playlist asynchronously");
    }
    loop.quit();
  }
}
