using Unity;
using Gee;

public class MprisServer : GLib.Object
{
  public MainLoop mainloop {get; construct;}
  public TypicalPlayer player {get; construct;}
  
  public MprisServer(MainLoop loop, TypicalPlayer p)
  {
    Object (mainloop : loop, player : p);
  }
  construct{
    Timeout.add_seconds(2, set_up_typical_consumer);
  }

  public bool escape ()
  {
    this.mainloop.quit ();
    return false;
  }

  public bool set_up_typical_consumer()
  {
    TrackMetadata metadata = new TrackMetadata();
    metadata.artist = "Autechre";
    metadata.album = "LP5";
    metadata.title = "Rae";
    metadata.art_location = File.new_for_uri ("file:///home/user/download/ae_lp5.jpg");
    this.player.menu_player.current_track = metadata;
    this.player.menu_player.is_blacklisted = false;

    Playlist pl = new Playlist ("/fake/pl/id");
    pl.name = "yellow swans like";
    try{
      pl.icon = Icon. new_for_string("audio-volume-high");
    }
    catch (GLib.Error e){
      warning ("Unable to load Icon from name provided - unable to complete test");
      return false;
    }

    player.menu_player.current_playlist = pl;
    player.menu_player.add_playlist (pl);

    Playlist pl2 = new Playlist ("/fake/pl2/id");
    pl2.name = "another playlist";
    try{
      pl2.icon = Icon.new_for_string("audio-volume-high");
    }
    catch (GLib.Error e){
      warning ("Unable to load Icon from name provided - unable to complete test");
      return false;
    }
    player.menu_player.add_playlist (pl2);                                             
    Timeout.add_seconds (10, escape);
                                              
    return false;
  }

  public bool change_playlist_names()
  {
    int i = 0;

    foreach (Playlist pl in this.player.menu_player.get_playlists()){
      debug ("old playlist name = %s", pl.name);
      pl.name = "name-changed-" + i.to_string();
      i++;
    }
    
    return false;
  }
  
  public static int main (string[] args)  
  {
    Environment.set_variable ("XDG_DATA_HOME", Config.TESTDIR+"/data", true);
    MainLoop mainloop = new MainLoop (MainContext.default(), false);

    TypicalPlayer player;
    player = new TypicalPlayer ();

    MprisServer server = new MprisServer (mainloop, player);
    
    /* Make sure we flush and sync all needed state */
    while (mainloop.get_context().pending() == true){
      mainloop.get_context().iteration (true);
    }
    
    mainloop.run();

    return 0;
  }
}

public class TypicalPlayer : GLib.Object
{
  public MusicPlayer menu_player{get; construct;}

  public TypicalPlayer (){}
  construct{
    this.menu_player = new MusicPlayer ("rhythmbox.desktop");
    this.menu_player.raise.connect(on_raise);
    this.menu_player.play_pause.connect (on_play_pause);
    this.menu_player.previous.connect (on_previous);
    this.menu_player.next.connect (on_next);
    this.menu_player.activate_playlist.connect (on_activate_playlist);
    
  }

  private void on_raise(){}

  private void on_play_pause()
  {
    this.menu_player.playback_state = this.menu_player.playback_state == PlaybackState.PLAYING ? PlaybackState.PAUSED : PlaybackState.PLAYING; 
  }
  
  private void on_previous(){}
  private void on_next()
  {
    TrackMetadata metadata = new TrackMetadata();
    metadata.artist = "Sonnamble";
    metadata.album = "Seven months in E minor";
    metadata.title = "Sehnsucht";
    metadata.art_location = File.new_for_uri ("file:///home/user/download/sonnamble.jpg");
    this.menu_player.current_track = metadata;    
  }
  
  private void on_activate_playlist (ObjectPath playlist_id)
  {
    foreach (Playlist pl in this.menu_player.get_playlists()){
      if (pl.id == (string)playlist_id){
        this.menu_player.current_playlist = pl;
        return;  
      }
    }
  }
}


