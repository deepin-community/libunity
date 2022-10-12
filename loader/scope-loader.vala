/* -*- mode: vala; c-basic-offset: 2; indent-tabs-mode: nil -*- */

namespace Options
{
  private static string group;
  private static string module;
}

const OptionEntry[] options =
{
  {
    "group", 'g', 0, OptionArg.STRING, out Options.group,
    "Scope group configuration", null
  },
  {
    "module", 'm', 0, OptionArg.STRING, out Options.module,
    "Scope shared library (for testing)", null
  },
  {
    null
  }
};

public int main (string[] args)
{
  Environment.set_prgname ("unity-scope-loader");
  var opt_context = new OptionContext("[scope-ids]");
  opt_context.add_main_entries (options, null);
  if (args.length <= 1)
  {
    print ("%s\n", opt_context.get_help (true, null));
    return 0;
  }

  var loader = new Unity.ScopeLoader ();
  try
  {
    opt_context.parse (ref args);

    if (Options.group != null)
    {
      loader.load_group (Options.group);
    }
    else if (Options.module != null)
    {
      loader.load_module (Options.module, "C");
    }
    else
    {
      for (var i = 1; i < args.length; i++)
      {
        var scope_id = args[i];
        loader.load_scope (scope_id);
      }
    }
  }
  catch (Error err)
  {
    error ("%s", err.message);
  }

  Unity.ScopeDBusConnector.run ();
  return 0;
}
