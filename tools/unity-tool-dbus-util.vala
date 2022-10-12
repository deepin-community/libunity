namespace Unity.Tester {

    public class DBusLensUtil
    {
        const MarkupParser parser = {
            start,
            null, /* end */
            null, /* text */
            null, /* comment */
            null  /* error */
        };

        public struct DBusObjectAddress {
            string dbus_name;
            string dbus_path;
        }

        public DBusLensUtil()
        {
            try {
                scope_dbusname_regex = new Regex("^.+[.]Scope[.][a-zA-Z.]+$");
            }
            catch (Error e) {
                stderr.printf("Error parsing scope_dbusname_regex");
            }
        }

        /**
         * Discover available DBus services
         */
        private List<string> getServices() throws GLib.Error
        {
            List<string> services = new List<string>();

            var vt = new VariantType ("(as)");
            var bus = Bus.get_sync (BusType.SESSION);
            Variant v = bus.call_sync("org.freedesktop.DBus",
                                      "/org/freedesktop/DBus",
                                      "org.freedesktop.DBus",
                                      "ListNames",
                                      null,
                                      vt,
                                      0,
                                      -1,
                                      null);

            string *[]names = v.get_child_value(0).get_strv();
            foreach (string *s in names) {
                services.append(s);
            }

            return services;
        }

        private void start(MarkupParseContext context, string name, string[] attr_names, string[] attr_values) throws MarkupError {
            if (name == "node") {
                for (int i=0; i<attr_names.length; i++) {
                    if (attr_names[i] == "name") {
                        string node_path = current_dbus_path.has_suffix("/") ? attr_values[i] : "/" + attr_values[i];
                        DBusObjectAddress obj = DBusObjectAddress() {
                            dbus_name = current_dbus_name,
                            dbus_path = current_dbus_path + node_path
                        };
                        nodes.push_tail(obj);
                    }
                }
            }
            if (name == "interface") {
                for (int i=0; i<attr_names.length; i++) {
                    if (attr_names[i] == "name" && attr_values[i] == "com.canonical.Unity.Scope") {
                        DBusObjectAddress obj = DBusObjectAddress() {
                            dbus_name = current_dbus_name,
                            dbus_path = current_dbus_path
                        };
                        //
                        // ensure there are no duplicates
                        if (lenses.find_custom(obj, (a,b) => {
                                    return a.dbus_name == b.dbus_name  && a.dbus_path == b.dbus_path ? 0 : 1; })
                                .length() == 0) {
                            lenses.append(obj);
                        }
                    }
                }
            }
        }

        /**
         * Find objects implementing com.canonical.Unity.Lens interface
         */
        public async unowned List<DBusObjectAddress?> findLenses() throws GLib.Error
        {
            if (scope_dbusname_regex == null) {
                stderr.printf("Invalid scope_dbusname_regex");
                return lenses;
            }

            var bus = Bus.get_sync (BusType.SESSION);
            var vt = new VariantType ("(s)");

            //
            // Service filtering - potential lenses must match this regexp;
            // e.g. com.canonical.Unity.Lens.applications.T1338793992370.Results
            foreach (string srv in getServices()) {
                if (scope_dbusname_regex.match(srv)) {
                    try {
                        var vb = new VariantBuilder(new VariantType("(s)"));
                        vb.add_value(srv);

                        Variant v = bus.call_sync(
                            "org.freedesktop.DBus",
                            "/",
                            "org.freedesktop.DBus",
                            "GetNameOwner",
                            vb.end(),
                            vt,
                            0,
                            10,
                            null);

                        if (v != null) {
                            string owner = v.get_child_value(0).get_string();
                            if (owner != null) {
                                DBusObjectAddress obj = DBusObjectAddress() {
                                    dbus_name = owner,
                                    dbus_path = "/"
                                };
                                nodes.push_tail(obj);
                            }
                        }
                    }
                    catch (Error e) {
                        // silently ignore
                    }

                }
            }

            //
            // introspect all dbus paths from nodes queue.
            // queue may grow as new paths are discovered.
            while (nodes.length > 0) {
                DBusObjectAddress node = nodes.pop_head();

                current_dbus_name = node.dbus_name;
                current_dbus_path = node.dbus_path;

                try {
                    Variant v = bus.call_sync(current_dbus_name,
                                              current_dbus_path,
                                              "org.freedesktop.DBus.Introspectable",
                                              "Introspect",
                                              null,
                                              vt,
                                              0,
                                              10,
                                              null);

                    if (v != null) {
                        string xmldata = v.get_child_value(0).get_string();
                        var context = new MarkupParseContext (parser, MarkupParseFlags.TREAT_CDATA_AS_TEXT, this, null);
                        context.parse (xmldata, xmldata.length);
                    }
                }
                catch (Error e) {
                    // silently ignore
                }

                Idle.add(findLenses.callback);
                yield;
            }

            return lenses;
        }

        private Regex scope_dbusname_regex;
        private string current_dbus_name;
        private string current_dbus_path;
        private Queue<DBusObjectAddress?> nodes = new Queue<DBusObjectAddress?>();
        private List<DBusObjectAddress?> lenses = new List<DBusObjectAddress?>();
    }
}
