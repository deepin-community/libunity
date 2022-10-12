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
  public HashMap<string, PlaylistDetails?> name_changed_playlistdetails{get; construct;}
  public Mpris2Controller(string name)
  {
    GLib.Object (dbus_name : name);
  }
  construct{
    try {
      this.name_changed_playlistdetails = new HashMap<string, PlaylistDetails?>();
      this.mpris2_root = Bus.get_proxy_sync ( BusType.SESSION,
                                              dbus_name,
                                              "/org/mpris/MediaPlayer2" );
      this.player = Bus.get_proxy_sync ( BusType.SESSION,
                                         dbus_name,
                                         "/org/mpris/MediaPlayer2" );      
      this.playlists = Bus.get_proxy_sync ( BusType.SESSION,
                                            dbus_name,
                                            "/org/mpris/MediaPlayer2" );
      this.playlists.PlaylistChanged.connect (on_playlistdetails_changed);
    } 
    catch (IOError e) {
      critical("Can't create our DBus interfaces - %s", e.message);
    }
  }

  private void on_playlistdetails_changed (PlaylistDetails details)
  {
    this.name_changed_playlistdetails.set (details.name, details);
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

    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Root/Identity",
                             root_identity); 
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Root/DesktopEntry",
                             root_desktop_entry); 
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Root/CanRaise",
                             root_can_raise); 
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Player/CurrentTrack",
                             player_current_metadata); 
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Player/PlaybackStatus",
                             player_current_playback_status);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Blacklisting",
                             test_blacklist_check);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Playlist/CurrentPlaylist",
                             playlists_current_playlist);                             
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Playlist/GetPlaylists",
                             playlists_test_get_playlists);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Playlist/PlaylistCount",
                             playlists_test_playlist_count);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Playlist/Orderings",
                             playlists_test_playlist_orderings);
    GLib.Test.add_data_func ("/Integration/SoundMenu/Mpris/Backend/Playlist/ActivatePlaylist",
                             playlists_test_activate_playlist);

    MprisClient client = new MprisClient (mainloop);
    
    /* Make sure we flush and sync all needed state */
    while (mainloop.get_context().pending() == true){
      mainloop.get_context().iteration (true);
    }
    
    mainloop.run();
    return 0;
  }

  public static bool run_tests()
  {
    Test.run ();
    return false;
  }
  
  internal static void root_identity ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    if (controller.mpris2_root.Identity != "Rhythmbox")
      {
        critical ("Expected 'Rhythmbox', but found '%s'",
                  controller.mpris2_root.Identity);
        assert (controller.mpris2_root.Identity == "Rhythmbox");
      }
  }
  
  internal static void root_desktop_entry ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert (controller.mpris2_root.DesktopEntry == "rhythmbox");
  }
  
  internal static void root_can_raise ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert (controller.mpris2_root.CanRaise == true);
  }


  internal static void player_current_metadata ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    Variant? v_artist = controller.player.Metadata.lookup ("xesam:artist");
    Variant? v_album = controller.player.Metadata.lookup ("xesam:album");
    Variant? v_title = controller.player.Metadata.lookup ("xesam:title");
    Variant? v_art = controller.player.Metadata.lookup ("mpris:artUrl");

    assert (v_artist.get_string() == "Autechre");
    assert (v_album.get_string() == "LP5");
    assert (v_title.get_string() == "Rae");
    assert (v_art.get_string() == "file:///home/user/download/ae_lp5.jpg"); 
  }

  internal static void player_current_playback_status ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert (controller.player.PlaybackStatus == "Paused");
    controller.player.PlayPause();
    Timeout.add (2, test_playbackstatus_change);
  }

  internal static bool test_playbackstatus_change ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert (controller.player.PlaybackStatus == "Playing");    
    controller.player.PlayPause();
    Timeout.add (2, test_second_playbackstatus_change);
    return false;
  }

  internal static bool test_second_playbackstatus_change ()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert (controller.player.PlaybackStatus == "Paused");
    return false;
  }
  
  // This test is flaky, I'm unsure why ...
  internal static void test_blacklist_check()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    // TODO - timeout needed ?    
    var settings = new Settings ("com.canonical.indicator.sound");
    var blacklist = settings.get_strv ("blacklisted-media-players");
    bool present = false;
    foreach (var s in blacklist){
      //debug("%s is blacklisted", s);
      if (s == controller.mpris2_root.DesktopEntry){
        present = true;
      }
    }
    assert (present == false);
  }

  internal static void playlists_current_playlist()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert (controller.playlists.ActivePlaylist.valid == true);
    assert (controller.playlists.ActivePlaylist.details.path == "/fake/pl/id");
    assert (controller.playlists.ActivePlaylist.details.name == "yellow swans like");
    assert (controller.playlists.ActivePlaylist.details.icon_name == "audio-volume-high");   
  }

  internal static void playlists_test_playlist_count()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert(controller.playlists.PlaylistCount == 2);
  }

  internal static void playlists_test_playlist_orderings()
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    assert(controller.playlists.Orderings.length == 1);
    assert(controller.playlists.Orderings[0] == "alphabetical");
  }

  internal static void playlists_test_get_playlists()
  {
    MainLoop loop = new MainLoop();
    do_test_async_get_playlists (loop);
    loop.run();
  }

  internal static async void do_test_async_get_playlists (MainLoop loop)
  {
    var controller = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    try{
      PlaylistDetails[] pls = yield controller.playlists.GetPlaylists (0,
                                                                       10,
                                                                       "alphabetical",
                                                                       false);
      assert (pls.length == 2);
      assert((string)pls[0].path == "/fake/pl/id");
      assert((string)pls[1].path == "/fake/pl2/id");
      assert (pls[0].name == "yellow swans like");
      assert (pls[1].name == "another playlist");      
      assert (pls[0].icon_name == "audio-volume-high");            
      assert (pls[1].icon_name == "audio-volume-high");            
    }
    catch (IOError e){
      warning ("do_test_async_get_playlists: Failed to get the playlists asynchronously");
    }
    loop.quit();
  }

  internal static void playlists_test_activate_playlist()
  {
    MainLoop loop = new MainLoop();
    do_test_async_activate_playlist (loop);
    loop.run();
  }

  internal static async void do_test_async_activate_playlist (MainLoop loop)
  {
    var contr = new Mpris2Controller ("org.mpris.MediaPlayer2.rhythmbox");
    try{
      PlaylistDetails[] pls = yield contr.playlists.GetPlaylists (0,
                                                                  10,
                                                                  "alphabetical",
                                                                  false);      
      contr.playlists.ActivatePlaylist.begin(pls[1].path);
      // Give it a sec
      Timeout.add_seconds (2, () => {
        assert (contr.playlists.ActivePlaylist.valid == true);
        assert (contr.playlists.ActivePlaylist.details.path == "/fake/pl2/id");
        assert (contr.playlists.ActivePlaylist.details.name == "another playlist");
        assert (contr.playlists.ActivePlaylist.details.icon_name == "audio-volume-high");                 
        return false;
       });      
    }
    catch (IOError e){
      warning ("do_test_async_activate_playlist: Failed to activate playlist asynchronously");
    }
    loop.quit();  
  }
}
