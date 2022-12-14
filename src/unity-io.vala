/*
 * Copyright (C) 2010 Canonical, Ltd.
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
 * Authored by Mikkel Kamstrup Erlandsen <mikkel.kamstrup@canonical.com>
 *
 */

/*
 * IMPLEMENTATION NOTE:
 * We want the generatedd C API to be nice and not too Vala-ish. We must
 * anticipate that place daemons consuming libunity will be written in
 * both Vala and C.
 *
 */

/**
 * A collection of assorted utilities
 */

namespace Unity.Internal.IO {

  /**
   * Asynchronously read a stream into memory. This method will close
   * the input stream when done.
   */
  internal async void read_stream_async (InputStream input,
                                         int io_priority = GLib.Priority.LOW,
                                         GLib.Cancellable? cancellable = null,
                                         out uint8[] data,
                                         out size_t size) throws IOError
  {
    /* Since the free func of the MemoryOutputStream is null, we own the
     * ref to the internal buffer when the stream is finalized */
    var output = new MemoryOutputStream (null, realloc, null);
    yield output.splice_async (input,
                               OutputStreamSpliceFlags.CLOSE_SOURCE,
                               io_priority, cancellable);
    
    /* We can close the mem stream synchronously without risk,
     * and we must close() it before stealing the data */
    output.close (null);
    
    data = output.steal_data();
    size = output.get_data_size ();
    
    /* Start closing the input stream, but don't wait for it to happen */
    input.close_async.begin(Priority.LOW, null);    
  }
  
  /**
   * Asynchronously looks for a file with base name 'filename' in all the
   * directories defined in 'dirs' and returns a file input stream for it.
   *
   * If the file can not be found this method returns null.
   */
  internal async FileInputStream? open_from_dirs (string filename,
                                                  string[] dirs) throws Error
  {
    string path;
    File datafile;
    
    /* Scan the dirs in order */
    foreach (string dir in dirs)
      {
        path = Path.build_filename (dir, filename, null);
        datafile = File.new_for_path (path);
        try
          {
            return yield datafile.read_async (Priority.DEFAULT, null);
          }
        catch (Error ee)
          {
            if(!(ee is IOError.NOT_FOUND))
              throw ee;
          }
      }
    
    /* File not found */
    return null;
  }
  
  /**
   * Like open_from_dirs() but scans first the user data dir and then
   * the system data dirs as defined by the XDG_DATA_DIRS environment variable.
   */
  internal async FileInputStream? open_from_data_dirs (string filename) throws Error
  {
    /* First look in the user data dir */
    string path = Path.build_filename (Environment.get_user_data_dir(),
                                       filename, null);
    File f = File.new_for_path (path);
    try
      {
        return yield f.read_async (Priority.DEFAULT, null);
      }
    catch (Error e)
      {        
        if(!(e is IOError.NOT_FOUND))
          {
          throw e;
          }
      }
    
    /* Now look in the system data dirs */
    string[] dirs = get_system_data_dirs ();
    return yield open_from_dirs (filename, dirs);
  }
  
  /**
   * Use this method instead of Environment.get_system_data_dirs()
   * (aka g_get_system_data_dirs()) because the Vala compiler has some
   * issues with the const-ness of the returned char**.
   * See https://bugzilla.gnome.org/show_bug.cgi?id=622708
   */
  private static string[] system_data_dirs = null;
  internal string[] get_system_data_dirs ()
  {
    if (system_data_dirs == null)
      {
        string? dirs = Environment.get_variable("XDG_DATA_DIRS");
        if (dirs != null)
          {
            system_data_dirs = dirs.split(":");
          }
        else
          {
            system_data_dirs = new string[0];
          }
      }
    
    return system_data_dirs;
  }
                           

} /* namespace */