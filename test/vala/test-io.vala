/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */
/*
 * Copyright (C) 2010 Canonical Ltd
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
 * Authored by Mikkel Kamstrup Erlandsen <mikkel.kamstrup@canonical.com>
 *
 */
using Unity.Internal;

namespace Unity.Test
{
  public class IOSuite
  {
    /* Copy of the data found in data/test_desktop_file.deskop */
    static string TEST_DATA = """[Desktop Entry]
Name=Test Application
Comment=This is a test application desktop file
Exec=/bin/true
Terminal=false
Type=Application
StartupNotify=false
Icon=test_desktop_icon.png

""";
  
    public IOSuite ()
    {
      GLib.Test.add_data_func ("/Unit/IO/AsyncDesktopFile",
                               IOSuite.test_async_find_and_load);
      GLib.Test.add_data_func ("/Unit/IO/AsyncOpenFromDataDirs",
                               IOSuite.test_async_open_from_data_dirs);
      GLib.Test.add_data_func ("/Unit/Utils/AsyncOnce",
                               IOSuite.test_async_once);
      GLib.Test.add_data_func ("/Unit/Utils/AsyncMutex",
                               IOSuite.test_async_mutex);
    }

    internal static void test_async_find_and_load()
    {
      MainLoop mainloop = new MainLoop ();
      do_test_async_find_and_load.begin ((obj, res) =>
      {
        do_test_async_find_and_load.end (res);
        mainloop.quit ();
      });
      mainloop.run ();
    }
    
    internal static void test_async_open_from_data_dirs()
    {
      MainLoop mainloop = new MainLoop ();
      do_test_async_open_from_data_dirs.begin ((obj, res) =>
      {
        do_test_async_open_from_data_dirs.end (res);
        mainloop.quit ();
      });
      mainloop.run ();
    }
    
    internal static async void do_test_async_find_and_load ()
    {
      string[] dirs = new string[1];
      dirs[0] = Path.build_filename (Config.TESTDIR, "data");
      
      try
        {
          var input = yield IO.open_from_dirs ("test_desktop_file.desktop",
                                               dirs);
          assert (input is FileInputStream);
          
          /* Read in small chunks to test reading across buffer pages */
          uint8[] data;
          size_t data_size;
          yield IO.read_stream_async (input,
                                      Priority.LOW, null,
                                      out data, out data_size);
          
          /* Test file bytes size */
          if (data_size != TEST_DATA.length)
            {
              critical (@"Expected file size $(TEST_DATA.length), but found $data_size");
              assert (data_size == TEST_DATA.length);
            }
          
          /* null terminate the data so we can use it string comparison */
          string sdata = ((string)data);
          assert (sdata == TEST_DATA);
        }
      catch (Error e)
        {
          error ("Failed read test file: %s", e.message);
        }
    }

    internal static async void do_test_async_open_from_data_dirs ()
    {
      var result = yield IO.open_from_data_dirs ("testapp1.desktop");
    }

    private static int init_tester = 0;

    private static async void async_once_test_actual_init ()
    {
      // this method needs to be called exactly once
      assert (init_tester == 0);

      Timeout.add (100, async_once_test_actual_init.callback);
      init_tester++;

      yield;

      assert (init_tester == 1);
      init_tester++;
    }

    private static async void async_once_test_inner (Utils.AsyncOnce<void*> once)
    {
      if (!once.is_initialized ())
      {
        if (yield once.enter ())
        {
          // this is the core method, it needs to be called just once
          yield async_once_test_actual_init ();
          once.leave (null);
        }
      }
    }

    private static async void run_async_once_test (Utils.AsyncOnce once)
    {
      int num_requests = 0;
      bool waiting = false;
      AsyncReadyCallback cb = (obj, res) =>
      {
        async_once_test_inner.end (res);
        if (--num_requests == 0 && waiting) run_async_once_test.callback ();
      };

      for (int i = 0; i < 100; i++)
      {
        if (i % 4 == 0)
        {
          // introduce lots of asynchronicity
          Timeout.add (5, run_async_once_test.callback);
          yield;
        }

        num_requests++;
        async_once_test_inner.begin (once, cb);
      }

      waiting = true;
      yield;

      assert (init_tester == 2);
    }

    private static void test_async_once ()
    {
      var ml = new MainLoop ();
      var once = new Utils.AsyncOnce<void*> ();
      run_async_once_test.begin (once, (obj, res) =>
      {
        ml.quit ();
        run_async_once_test.end (res);
      });
      assert (run_with_timeout (ml));
      assert (init_tester == 2);
    }

    private static bool resource_in_use;
    private static async void async_mutex_test_inner (Utils.AsyncMutex mutex)
    {
      if (!mutex.try_lock ()) yield mutex.lock ();

      assert (!resource_in_use);

      resource_in_use = true;
      Idle.add (async_mutex_test_inner.callback);
      yield;
      resource_in_use = false;

      mutex.unlock ();
    }

    private static async void run_async_mutex_test (Utils.AsyncMutex mutex)
    {
      int num_requests = 0;
      bool waiting = false;
      AsyncReadyCallback cb = (obj, res) =>
      {
        async_mutex_test_inner.end (res);
        if (--num_requests == 0 && waiting) run_async_mutex_test.callback ();
      };

      for (int i = 0; i < 100; i++)
      {
        if (i % 4 == 0)
        {
          // introduce lots of asynchronicity
          Timeout.add (5, run_async_mutex_test.callback);
          yield;
        }

        num_requests++;
        async_mutex_test_inner.begin (mutex, cb);
      }

      waiting = true;
      yield;
    }

    private static void test_async_mutex ()
    {
      var ml = new MainLoop ();
      var once = new Utils.AsyncMutex ();
      run_async_mutex_test.begin (once, (obj, res) =>
      {
        ml.quit ();
        run_async_once_test.end (res);
      });
      assert (run_with_timeout (ml));
    }
  }
}
