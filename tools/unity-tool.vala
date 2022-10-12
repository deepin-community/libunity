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
 * Authored by Michal Hruby <michal.hruby@canonical.com>
 *
 */
using Gtk;
using Unity.Protocol;

namespace Unity.Tester
{
  namespace Options
  {
    public static bool gui;
    public static bool benchmark;
    public static string scope_dbus_name;
    public static string scope_dbus_path;
    public static string scope_file;
    public static string search_string;
    public static int search_type;
    public static bool private_channel;
    public static bool common_tests;
    public static bool print_search_reply;
    public static bool dump_results;
    public static bool dump_filters;
    public static bool diff_changes;

    public static bool test_server_mode;
    public static string[] test_cases;
  }

  namespace TestRunner
  {
    public static string[] test_cases;
    public static int test_index;
  }

  public errordomain TesterError
  {
    INVALID_ARGS
  }

  private UnityToolUi ui;

  const OptionEntry[] options =
  {
    {
      "gui", 'g', 0, OptionArg.NONE, out Options.gui,
      "Run GUI", null
    },
    {
      "benchmark", 'b', 0, OptionArg.NONE, out Options.benchmark,
      "Benchmark searches", null
    },
    {
      "dbus-name", 'n', 0, OptionArg.STRING, out Options.scope_dbus_name,
      "Unique dbus name of the tested scope", null
    },
    {
      "dbus-path", 'p', 0, OptionArg.STRING, out Options.scope_dbus_path,
      "Object path of the scope", null
    },
    {
      "scope-file", 's', 0, OptionArg.STRING, out Options.scope_file,
      "Path to the scope file (to read out dbus name and path)", null
    },
    {
      "common-tests", 'c', 0, OptionArg.NONE, out Options.common_tests,
      "Perform common tests each scope should conform to", null
    },
    {
      "search", 'q', 0, OptionArg.STRING, out Options.search_string,
      "Search string to send to the scope", null
    },
    {
      "search-type", 't', 0, OptionArg.INT, out Options.search_type,
      "Type of the search (value from Unity.SearchType enum)", null
    },
    {
      "dump-results", 'r', 0, OptionArg.NONE, out Options.dump_results,
      "Output the results model on stdout", null
    },
    {
      "dump-filters", 'f', 0, OptionArg.NONE, out Options.dump_filters,
      "Output the filter model on stdout", null
    },
    {
      "print-search-reply", 0, 0, OptionArg.NONE, out Options.print_search_reply,
      "Output reply of the search call in its raw form", null
    },
    {
      "private-channel", 0, 0, OptionArg.NONE, out Options.private_channel,
      "Use private channel for results transfer", null
    },
    {
      "diff-changes", 'd', 0, OptionArg.NONE, out Options.diff_changes,
      "Use diff channel", null
    },
    {
      "test-server-mode", 0, 0, OptionArg.NONE, out Options.test_server_mode,
      "Run a collection of test scripts", null
    },
    {
      "", 0, 0, OptionArg.FILENAME_ARRAY, out Options.test_cases,
      "Invididual test cases", "<test-scripts>"
    },
    {
      null
    }
  };

  public static void get_scope_params_from_file(string filename) throws Error
  {
    Unity.Protocol.ScopeRegistry.ScopeMetadata metadata;
    if (Path.is_absolute (filename))
    {
      metadata = Unity.Protocol.ScopeRegistry.ScopeMetadata.for_path (filename);
    }
    else
    {
      metadata = Unity.Protocol.ScopeRegistry.ScopeMetadata.for_id (filename);
    }

    Options.scope_dbus_name = metadata.dbus_name;
    Options.scope_dbus_path = metadata.dbus_path;
  }

  public static void warn (string format, ...)
  {
    var args = va_list ();
    logv ("libunity-tool", LogLevelFlags.LEVEL_WARNING, format, args);
  }

  public static int main (string[] args)
  {
    Environment.set_prgname ("libunity-tool");
    var opt_context = new OptionContext (" - libunity tool");
    opt_context.add_main_entries (options, null);

    try
    {
      if (args.length <= 1)
      {
        print ("%s\n", opt_context.get_help (true, null));
        return 0;
      }

      opt_context.parse (ref args);
      if (Options.test_server_mode)
      {
        if (Options.test_cases == null ||
          (Options.test_cases.length=(int)strv_length(Options.test_cases)) == 0)
        {
          throw new TesterError.INVALID_ARGS ("No test cases specified");
        }

        // special mode where we just run test scripts inside a directory
        string[] test_scripts = get_test_cases ();
        TestRunner.test_cases = test_scripts;

        Test.init (ref args);
        foreach (unowned string test_case in test_scripts)
        {
          Test.add_data_func ("/Integration/ScopeTest/" + 
                              Path.get_basename (test_case),
                              () =>
                              {
                                string test = TestRunner.test_cases[TestRunner.test_index++];
                                int status;
                                try
                                {
                                  Process.spawn_command_line_sync (test,
                                                                   null,
                                                                   null,
                                                                   out status);
                                }
                                catch (Error e)
                                {
                                  warn ("%s", e.message);
                                  status = -1;
                                }
                                assert (status == 0);
                              });
        }
        return Test.run ();
      }
      else
      {
        // read dbus name and path from the scope file
        if (Options.scope_file != null)
        {
          get_scope_params_from_file(Options.scope_file);
        }

        if (Options.gui)
        {
            Gtk.init(ref args);
            ui = new UnityToolUi();
            if (ui.init_gui()) {
                Gtk.main();
            }
            return 0;
        }

        // check that we have dbus names
        if (Options.scope_dbus_name == null || Options.scope_dbus_path == null)
        {
          throw new TesterError.INVALID_ARGS ("Scope DBus name and path not specified!");
        }
        if (Options.common_tests)
        {
          int status = run_common_tests ();
          assert (status == 0);
        }

        if (Options.benchmark)
        {
          // libunity uses an envvar to add time information, tell dbus
          // to use that envvar for newly spawned services
          var conn = Bus.get_sync (BusType.SESSION, null);
          var env = new HashTable<string, string> (str_hash, str_equal);
          env["LIBUNITY_TIME_SEARCHES"] = "1";
          conn.call_sync ("org.freedesktop.DBus",
                          "/org/freedesktop/DBus",
                          "org.freedesktop.DBus",
                          "UpdateActivationEnvironment",
                          new Variant.tuple ({env}),
                          null, 0, -1, null);
        }

        // Get proxy
        string channel_id;
        Dee.SerializableModel results_model;
        var proxy = get_scope_proxy (Options.scope_dbus_name,
                                     Options.scope_dbus_path,
                                     (ChannelType) Options.search_type,
                                     get_global_channel_flags (),
                                     out channel_id, out results_model);

        // Performing search
        if (Options.search_string != null)
        {
          var ml = new MainLoop ();
          int64 start_time = get_monotonic_time ();
          int64 first_result = 0;
          uint64 model_seqnum = 0;
          results_model.row_added.connect (() =>
          {
            if (first_result == 0) first_result = get_monotonic_time ();
          });
          proxy.search.begin (channel_id, Options.search_string,
                              new HashTable<string, Variant> (null, null),
                              null,
                              (obj, res) =>
          {
            try
            {
              var reply_dict = proxy.search.end (res);
              if ("model-seqnum" in reply_dict)
                model_seqnum = reply_dict["model-seqnum"].get_uint64 ();
              if (Options.print_search_reply)
              {
                Variant v = reply_dict;
                print ("%s\n", v.print (true)); // so much easier
              }
            }
            catch (Error err)
            {
              warning ("%s", err.message);
            }
            ml.quit ();
          });

          assert (run_with_timeout (ml, 15000));
          wait_for_seqnum (results_model as Dee.SharedModel, model_seqnum);

          if (Options.benchmark)
          {
            int64 end_time = get_monotonic_time ();
            int64 delta = end_time - start_time;
            double elapsed = delta;
            print ("Search took: %g seconds\n", elapsed / 1000000.0);
            if (first_result > 0)
            {
              delta = first_result - start_time;
              elapsed = delta;
              print ("First result after: %g seconds\n", elapsed / 1000000.0);
            }
          }
        }

        // Dumping models
        if (Options.dump_results || Options.dump_filters)
        {
          if (Options.dump_results)
          {
            dump_results_model (results_model);
          }

          if (Options.dump_filters)
          {
            dump_filters_model (proxy.filters_model);
          }
        }

        close_channel (proxy, channel_id);
      }
    }
    catch (Error err)
    {
      warn ("%s", err.message);
      return 1;
    }


    return 0;
  }

  private ScopeProxy get_scope_proxy (string dbus_name, string dbus_path,
                                      ChannelType channel_type,
                                      ChannelFlags channel_flags,
                                      out string channel_id,
                                      out Dee.SerializableModel model)
    throws Error
  {
    ScopeProxy? proxy = null;
    var ml = new MainLoop ();
    ScopeProxy.new_from_dbus.begin (dbus_name, dbus_path, null, (obj, res) =>
    {
      try
      {
        proxy = ScopeProxy.new_from_dbus.end (res);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      ml.quit ();
    });
    run_with_timeout (ml, 15000);
    if (proxy == null)
    {
      throw new IOError.TIMED_OUT ("Timed out waiting for proxy");
    }

    ml = new MainLoop ();
    string? chan_id = null;
    Error? outer_error = null;
    Dee.SerializableModel? results_model = null;
    proxy.open_channel.begin (channel_type, channel_flags, null, (obj, res) =>
    {
      try
      {
        chan_id = proxy.open_channel.end (res, out results_model);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
        outer_error = err;
      }
      ml.quit ();
    });
    run_with_timeout (ml, 15000);
    if (outer_error != null) throw outer_error;

    channel_id = chan_id;
    model = results_model;

    return proxy;
  }

  private void close_channel (ScopeProxy proxy, string channel_id)
  {
    var ml = new MainLoop ();
    proxy.close_channel.begin (channel_id, null, (obj, res) =>
    {
      try
      {
        proxy.close_channel.end (res);
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      ml.quit ();
    });
    run_with_timeout (ml, 15000);
  }

  private static void wait_for_seqnum (Dee.SharedModel model, uint64 seqnum)
  {
    if (model.get_seqnum () >= seqnum) return;

    var ml = new MainLoop ();
    var update_sig_id = model.end_transaction.connect ((m, begin_seqnum, end_seqnum) =>
    {
      if (end_seqnum < seqnum) return;

      /* disconnect from within the signal handler... awesome, right? */
      ml.quit ();
    });
    run_with_timeout (ml, 15000);
    SignalHandler.disconnect (model, update_sig_id);
  }

  public static string[] get_test_cases ()
  {
    string[] results = {};
    foreach (string path in Options.test_cases)
    {
      if (FileUtils.test (path, FileTest.IS_REGULAR) &&
          FileUtils.test (path, FileTest.IS_EXECUTABLE))
      {
        results += path;
      }
      else if (FileUtils.test (path, FileTest.IS_DIR))
      {
        try
        {
          var dir = Dir.open (path);
          unowned string name = dir.read_name ();
          while (name != null)
          {
            var child_path = Path.build_filename (path, name, null);
            if (FileUtils.test (child_path, FileTest.IS_REGULAR) &&
                FileUtils.test (child_path, FileTest.IS_EXECUTABLE))
            {
              results += child_path;
            }

            name = dir.read_name ();
          }
        } catch (Error e) { warn ("%s", e.message); }
      }
    }

    return results;
  }

  public static bool run_with_timeout (MainLoop ml, uint timeout_ms)
  {
    bool timeout_reached = false;
    var t_id = Timeout.add (timeout_ms, () => 
    {
      timeout_reached = true;
      debug ("Timeout reached");
      ml.quit ();
      return false;
    });

    ml.run ();

    if (!timeout_reached) Source.remove (t_id);

    return !timeout_reached;
  }

  private static int run_common_tests ()
  {
    string[] args = { "./libunity-tool" };
    unowned string[] dummy = args;

    Test.init (ref dummy);

    // checks that scope emits finished signal for every search type
    // (and both empty and non-empty searches)
    Test.add_data_func ("/Integration/ScopeTest/DefaultSearch/Empty", () =>
    {
      call_scope_search ("", ChannelType.DEFAULT);
    });

    Test.add_data_func ("/Integration/ScopeTest/DefaultSearch/NonEmpty", () =>
    {
      call_scope_search ("a", ChannelType.DEFAULT);
    });

    // check also non-empty -> empty search
    Test.add_data_func ("/Integration/ScopeTest/DefaultSearch/Empty2", () =>
    {
      call_scope_search ("", ChannelType.DEFAULT);
    });

    Test.add_data_func ("/Integration/ScopeTest/GlobalSearch/Empty", () =>
    {
      call_scope_search ("", ChannelType.GLOBAL);
    });

    Test.add_data_func ("/Integration/ScopeTest/GlobalSearch/NonEmpty", () =>
    {
      call_scope_search ("a", ChannelType.GLOBAL);
    });

    // check also non-empty -> empty search
    Test.add_data_func ("/Integration/ScopeTest/GlobalSearch/Empty2", () =>
    {
      call_scope_search ("", ChannelType.GLOBAL);
    });

    return Test.run ();
  }

  private static ChannelFlags get_global_channel_flags ()
  {
    var flags = ChannelFlags.NONE;
    if (Options.private_channel) flags |= ChannelFlags.PRIVATE;
    if (Options.diff_changes) flags |= ChannelFlags.DIFF_CHANGES;
    return flags;
  }

  private static void call_scope_search (string search_string,
                                         int search_type)
  {
    string channel_id;
    Dee.SerializableModel results_model;

    var proxy = get_scope_proxy (Options.scope_dbus_name,
                                 Options.scope_dbus_path,
                                 (ChannelType) search_type,
                                 get_global_channel_flags (),
                                 out channel_id, out results_model);

    var ml = new MainLoop ();
    uint64 model_seqnum = 0;
    HashTable<string, Variant>? reply_dict = null;
    proxy.search.begin (channel_id, search_string,
                        new HashTable<string, Variant> (null, null),
                        null,
                        (obj, res) =>
    {
      try
      {
        reply_dict = proxy.search.end (res);
        if ("model-seqnum" in reply_dict)
          model_seqnum = reply_dict["model-seqnum"].get_uint64 ();
      }
      catch (Error err)
      {
        warning ("%s", err.message);
      }
      ml.quit ();
    });

    assert (run_with_timeout (ml, 15000));
    wait_for_seqnum (results_model as Dee.SharedModel, model_seqnum);

    close_channel (proxy, channel_id);
  }

  private void dump_results_model (Dee.Model model)
  {
    var iter = model.get_first_iter ();
    var last_iter = model.get_last_iter ();

    while (iter != last_iter)
    {
      var row = model.get_row (iter);
      print ("%s\t%s\t%u\t%u\t%s\t%s\t%s\t%s\t%s\n",
             row[0].get_string (),
             row[1].get_string (),
             row[2].get_uint32 (),
             row[3].get_uint32 (),
             row[4].get_string (),
             row[5].get_string (),
             row[6].get_string (),
             row[7].get_string (),
             row[8].print (true)
             );

      iter = model.next (iter);
    }
  }

  private void dump_filters_model (Dee.Model model)
  {
    var iter = model.get_first_iter ();
    var last_iter = model.get_last_iter ();

    while (iter != last_iter)
    {
      var row = model.get_row (iter);
      print ("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
             row[0].get_string (),
             row[1].get_string (),
             row[2].get_string (),
             row[3].get_string (),
             row[4].print (true),
             row[5].get_boolean ().to_string (),
             row[6].get_boolean ().to_string (),
             row[7].get_boolean ().to_string ()
             );

      iter = model.next (iter);
    }
  }
}
