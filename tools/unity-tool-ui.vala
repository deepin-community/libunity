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
 * Authored by Pawel Stolowski <pawel.stolowski@canonical.com>
 *
 */
using Gtk;

namespace Unity.Tester {

public class UnityToolUi: GLib.Object
{
    public UnityToolUi()
    {
    }

    public bool init_gui()
    {
        var builder = new Builder ();

        try {
            builder.add_from_resource("/com/canonical/Unity/unity-tool/unity-tool.ui");
            builder.connect_signals(this);

            spinner = builder.get_object ("spinner") as Spinner;

            var window = builder.get_object ("window") as Window;
            window.destroy.connect(Gtk.main_quit);
            window.show_all();

            uimodel = builder.get_object("results_model") as Gtk.ListStore;
            ui_filter_model = builder.get_object("filters_model") as Gtk.ListStore;
            ui_cat_model = builder.get_object("categories_model") as Gtk.ListStore;

            notebook = builder.get_object("notebook") as Notebook;
            search_entry = builder.get_object("search_entry") as Entry;
            search_type_global_rbutton = builder.get_object("search_type_global") as RadioButton;
            search_button = builder.get_object("search_button") as Button;
            results_button = builder.get_object("results_button") as Button;
            prev_preview_button = builder.get_object("prev_preview_btn") as Button;
            next_preview_button = builder.get_object("next_preview_btn") as Button;
            statusbar = builder.get_object("statusbar") as Statusbar;
            log_buffer = builder.get_object("log_buffer") as TextBuffer;
            preview_raw_data = builder.get_object("preview_raw_data") as TextBuffer;
            preview_buttons_container = builder.get_object("preview_buttons_container") as Alignment;
            preview_extra_buttons_container = builder.get_object("preview_extra_buttons_container") as Alignment;
            preview_viewport = builder.get_object("preview_viewport") as Viewport;
            assert(preview_viewport != null);

            results_view = builder.get_object("results_view") as TreeView;
            results_view_selection = builder.get_object("results_view_selection") as TreeSelection;
            results_popup_menu = builder.get_object("results_popup_menu") as Gtk.Menu;

            statusbar_info_ctx = statusbar.get_context_id("Info");
            statusbar_error_ctx = statusbar.get_context_id("Error");

            show_no_preview();
            show_connect_dialog();
        }
        catch (GLib.Error e) {
            ui_load_error(e.message);
            return false;
        }
        return true;
    }

    private void ui_load_error(string message)
    {
        Gtk.Dialog dlg = new Gtk.MessageDialog(null,
                    Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                    "Error loading UI file:\n%s".printf(message));
        dlg.title = "Error creating UI";
        dlg.run();
        dlg.destroy();
    }

    private void discover_scope()
    {
        scope_discovery_spinner.start();

        TreeIter iter;
        scope_list_model.append(out iter);
        scope_list_model.set(iter, 0,"", 1, "", -1); //add empty combobox entry

        DBusLensUtil c = new DBusLensUtil();
        c.findLenses.begin((obj, res) => {
                try {
                    unowned List<DBusLensUtil.DBusObjectAddress?> results = c.findLenses.end(res);
                    foreach (DBusLensUtil.DBusObjectAddress addr in results) {
                        scope_list_model.append(out iter);
                        scope_list_model.set(iter, 0, addr.dbus_name, 1, addr.dbus_path, -1);
                    }
                    scope_discovery_spinner.stop();
                }
                catch (Error e) {
                    stderr.printf("DBus Lens auto-discovery failed %s\n", e.message);
                    scope_discovery_spinner.stop();
                }
            });
    }

    [CCode (instance_pos = -1)]
    public void on_scope_combobox_clicked(Gtk.MenuItem item)
    {
        TreeIter iter;
        if (scope_list_combobox.get_active() > 0) { // ignore first empty item
            if (scope_list_combobox.get_active_iter(out iter)) {
                Value val;
                scope_list_model.get_value(iter, 0, out val);
                dbus_name_entry.text = val.get_string();
                scope_list_model.get_value(iter, 1, out val);
                dbus_path_entry.text = val.get_string();
            }
        }
    }

    //
    // Handler for File > New menu item.
    [CCode (instance_pos = -1)]
    public void on_connect_clicked(Gtk.MenuItem item)
    {
        show_connect_dialog();
    }

    /**
     * Handler for Edit > Clear Log menu item.
     */
    [CCode (instance_pos = -1)]
    public void on_clear_log_clicked(Gtk.MenuItem item)
    {
        Gtk.TextIter start;
        Gtk.TextIter end;
        log_buffer.get_start_iter(out start);
        log_buffer.get_end_iter(out end);
        log_buffer.delete(ref start, ref end);
    }

    private void show_connect_dialog()
    {
        var builder = new Builder ();
        try {
            builder.add_from_resource("/com/canonical/Unity/unity-tool/dbus-scope-connect.ui");
            builder.connect_signals(this);
            scope_discovery_spinner = builder.get_object("scope_discovery_spinner") as Spinner;
            scope_list_model = builder.get_object("scope_list_model") as Gtk.ListStore;
            scope_list_combobox = builder.get_object("scope_list_combobox") as ComboBox;
            dbus_name_entry = builder.get_object("dbus_name_entry") as Entry;
            dbus_path_entry = builder.get_object("dbus_path_entry") as Entry;
            scope_connect_dlg = builder.get_object("scope_connect_dialog") as Dialog;

            discover_scope();

            if (Options.scope_dbus_path != null && Options.scope_dbus_path != "" && Options.scope_dbus_name != null && Options.scope_dbus_name != "") {
                dbus_name_entry.text = Options.scope_dbus_name;
                dbus_path_entry.text = Options.scope_dbus_path;
            }
            scope_connect_dlg.show_all();
        }
        catch (GLib.Error e) {
            ui_load_error(e.message);
        }
    }

    private void results_row_added_cb(Dee.Model model, Dee.ModelIter iter)
    {
        var row = model.get_row(iter);
        TreeIter uiiter;
        uimodel.append(out uiiter);

        uimodel.set(uiiter, 0, row[0].get_string(),
                            1, row[1].get_string(),
                            2, row[2].get_uint32(),
                            3, row[3].get_uint32(),
                            4, row[4].get_string(),
                            5, row[5].get_string(),
                            6, row[6].get_string(),
                            7, row[7].get_string(),
                            8, row[8].print (true),
                            -1);
    }

    private void filters_row_added_cb(Dee.Model model, Dee.ModelIter iter)
    {
        var row = model.get_row(iter);
        TreeIter uiiter;
        ui_filter_model.append(out uiiter);

        ui_filter_model.set(uiiter, 0, row[0].get_string (),
                                    1, row[1].get_string (),
                                    2, row[2].get_string (),
                                    3, row[3].get_string (),
                                    4, row[4].print (true),
                                    5, row[5].get_boolean (),
                                    6, row[6].get_boolean (),
                                    7, row[7].get_boolean (), -1);
    }

    private void categories_row_added_cb(Dee.Model model, Dee.ModelIter iter)
    {
        var row = model.get_row(iter);
        TreeIter uiiter;
        ui_cat_model.append(out uiiter);

        ui_cat_model.set(uiiter, 0, row[0].get_string (),
                                 1, row[1].get_string (),
                                 2, row[2].get_string (),
                                 3, row[3].get_string (),
                                 4, row[4].print (true), -1);
    }

    private void update_status()
    {
        statusbar.pop(statusbar_info_ctx);
        statusbar.push(statusbar_info_ctx, "%u records".printf(dee_results_model.get_n_rows()) + ", DBus name: " + Options.scope_dbus_name + " path: " +
                       Options.scope_dbus_path);
    }

    private void model_synchronized_cb()
    {
        spinner.stop();
        update_status();
        append_log_message("Search returned %u records\n".printf(dee_results_model.get_n_rows()));
        dee_results_model = null;
    }

    private void filter_model_synchronized_cb()
    {
        dee_filters_model = null;
    }

    private void categories_model_synchronized_cb()
    {
        dee_categories_model = null;
    }

    private void on_scope_service_vanished(GLib.DBusConnection connection, string name)
    {
        handle_error("Disconnected from %s".printf(name));
        GLib.Bus.unwatch_name(dbus_watcher_id);
        dbus_watcher_id = 0;
        scope_proxy = null;

        clear_data();
        clear_categories_and_filters();
        remove_preview();
        show_no_preview();

        disable_ui_actions_on_error_condition();
    }

    private void disable_ui_actions_on_error_condition()
    {
        if (scope_proxy == null || Options.scope_dbus_path == null || Options.scope_dbus_path.length == 0 || Options.scope_dbus_name == null || Options.scope_dbus_name.length == 0) {
            search_entry.sensitive = false;
            results_button.sensitive = false;
            search_button.sensitive = false;
        } else {
            search_entry.sensitive = true;
            results_button.sensitive = true;
            search_button.sensitive = true;
        }
    }

    /**
     * Triggered by clicking 'Ok' in the connection dialog.
     */
    [CCode (instance_pos = -1)]
    public void on_scope_connect(Gtk.Dialog dlg, int response)
    {
        //
        // user clicked 'Ok' in the Lens Connect dialog
        if (response == 1) {
            clear_data();
            clear_categories_and_filters();
            remove_preview();
            show_no_preview();

            Options.scope_dbus_name = dbus_name_entry.text;
            Options.scope_dbus_path = dbus_path_entry.text;

            scope_proxy = null;
            DBusConnection? bus = null;

            try
            {
                bus = Bus.get_sync(BusType.SESSION);
                scope_proxy = bus.get_proxy_sync<Protocol.ScopeService>(Options.scope_dbus_name, Options.scope_dbus_path);

                if (dbus_watcher_id > 0) {
                    GLib.Bus.unwatch_name(dbus_watcher_id);
                }
                dbus_watcher_id = GLib.Bus.watch_name(GLib.BusType.SESSION, Options.scope_dbus_name, GLib.BusNameWatcherFlags.AUTO_START, null, on_scope_service_vanished);

                /* read global models */
                dee_filters_model = Dee.Serializable.parse(scope_proxy.filters, typeof(Dee.SequenceModel)) as Dee.SerializableModel;
                for (var iter = dee_filters_model.get_first_iter();
                     iter != dee_filters_model.get_last_iter();
                     iter = dee_filters_model.next(iter))
                  filters_row_added_cb(dee_filters_model, iter);

                dee_categories_model = Dee.Serializable.parse(scope_proxy.categories, typeof(Dee.SequenceModel)) as Dee.SerializableModel;
                for (var iter = dee_categories_model.get_first_iter();
                     iter != dee_categories_model.get_last_iter();
                     iter = dee_categories_model.next(iter))
                  categories_row_added_cb(dee_categories_model, iter);

                var is_global = search_type_global_rbutton.get_active();
                scope_proxy.open_channel.begin(is_global ? 1 : 0, new HashTable<string, Variant>(null, null), null, null, (obj, res) =>
                {
                  var proxy = obj as Protocol.ScopeService;
                  HashTable<string, Variant> hints;
                  current_channel_id = proxy.open_channel.end(res, out hints);
                  string model_name = hints["model-swarm-name"].get_string();
                  current_swarm_name = model_name;
                });
                append_log_message("Connected to: %s, %s\n".printf(Options.scope_dbus_name, Options.scope_dbus_path));
            }
            catch (GLib.IOError e) {
                handle_error(e.message);
            }
        }
        disable_ui_actions_on_error_condition();
        dlg.destroy();
    }

    /**
     * Triggered by clicking 'From scope file' button in the connection dialog.
     * Opens file browser letting the user pick a .scope file.
     */
    [CCode (instance_pos = -1)]
    public void on_from_scope_clicked(Gtk.Button btn)
    {
        var filter = new FileFilter();
        filter.set_name("Scope files");
        filter.add_pattern("*.scope");

        var file_chooser = new FileChooserDialog("Open Lens file", null, Gtk.FileChooserAction.OPEN, Gtk.Stock.CANCEL, 0, Gtk.Stock.OPEN, 1);
        file_chooser.set_filter(filter);
        if (file_chooser.run() == 1) {
            try {
                get_scope_params_from_file(file_chooser.get_filename());
                dbus_name_entry.text = Options.scope_dbus_name;
                dbus_path_entry.text = Options.scope_dbus_path;
            }
            catch (Error e) {
                Gtk.Dialog dlg = new Gtk.MessageDialog(null,
                                   Gtk.DialogFlags.DESTROY_WITH_PARENT | Gtk.DialogFlags.MODAL,
                                   Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                                   "Error loading scope parameters from file:\n%s".printf(e.message));
                dlg.title = "Error loading scope file";
                dlg.run();
                dlg.destroy();
            }
        }
        file_chooser.destroy();
    }

    /**
     * Appends log message to 'Log' tab.
     */
    private void append_log_message(string message)
    {
        TextIter iter;
        log_buffer.get_end_iter(out iter);
        log_buffer.insert(ref iter, message, -1);
    }

    /**
     * Clears all models, removing all search results.
     */
    private void clear_data()
    {
        if (dee_results_model != null) {
            dee_results_model = null;
        }
        uimodel.clear();
    }

    private void clear_categories_and_filters()
    {
        if (dee_filters_model != null) {
            dee_filters_model = null;
        }
        if (dee_categories_model != null) {
            dee_categories_model = null;
        }
        ui_filter_model.clear();
        ui_cat_model.clear();
    }

    [CCode (instance_pos = -1)]
    public void on_results_button_clicked(Gtk.Button btn)
    {
        clear_data();
        remove_preview();
    }

    /**
     * Triggered by clicking 'Search' button. Starts scope search over dbus.
     */
    [CCode (instance_pos = -1)]
    public void on_search_button_clicked(Gtk.Button btn)
    {
        string text = search_entry.text;
        spinner.start();

        if (DBus.is_name(Options.scope_dbus_name) && GLib.Variant.is_object_path(Options.scope_dbus_path)) {
            append_log_message("Query: '%s' (%s), DBus name: %s, DBus path: %s\n".printf(
                                   text,
                                   search_type_global_rbutton.get_active() ? "global" : "local",
                                   Options.scope_dbus_name,
                                   Options.scope_dbus_path));

            remove_preview();
            show_no_preview();
            clear_data();

            var is_global_search = search_type_global_rbutton.get_active();
            scope_proxy.search.begin(current_channel_id, text,
                                     new HashTable<string, Variant>(null, null),
                                     null, (obj, res) =>
            {
              try {
                var proxy = obj as Protocol.ScopeService;
                var result = proxy.search.end(res);
                dee_results_model = new Dee.SharedModel(current_swarm_name);
                model_sync_sig_id = dee_results_model.notify["synchronized"].connect(model_synchronized_cb);
                dee_results_model.row_added.connect(results_row_added_cb);
                var msg = "Search reply: %s\n".printf (dump_ht_reply(result));
                append_log_message(msg);
              }
              catch (Error e) {
                handle_error(e.message);
              }
            });
        } else {
            handle_error("Invalid DBus name/path");
        }
    }

    private static string dump_ht_reply(HashTable<string, Variant> reply)
    {
        var bld = new StringBuilder("{\n");
        reply.foreach((k, v) => {
                bld.append_printf("\t%s = %s", k, v.print(true));
            });
        bld.append("\n}");
        return bld.str;
    }

    private static string dump_activation_reply(Unity.Protocol.ActivationReplyRaw reply)
    {
        var bld = new StringBuilder();
        string handled_str = ((EnumClass) typeof (Unity.HandledType).class_ref()).get_value((int)reply.handled).value_name;
        bld.append_printf("ActivationReplyRaw: {\n\turi=%s,\n\thandled=%s,\n\thints={\n\t", reply.uri, handled_str);
        reply.hints.foreach((k, v) => {
                bld.append_printf("\t\t%s = %s", k, v.print(true));
            });
        bld.append("\n\t}\n}");
        return bld.str;
    }

    /**
     * Helper method that stops spinner and puts error message on statusbar.
     */
    private void handle_error(string message)
    {
        spinner.stop();
        statusbar.pop(statusbar_error_ctx);
        statusbar.push(statusbar_error_ctx, message);
        append_log_message(message + "\n");
    }

    /**
     * Helper method to workaround vala-0.16 & vala-0.17 bug -
     * fix is coming to vala - see http://git.gnome.org/browse/vala/commit/?id=79925e1174d62d740ca8f360f489dd1660ea5881
     */
    private async void send_activate (string channel_id, Variant[] result_arr, uint action_type, HashTable<string,Variant>? hints_, out Unity.Protocol.ActivationReplyRaw reply) throws GLib.IOError
    {
        var hints = hints_;
        if (hints == null) {
            hints = new HashTable<string, Variant> (null, null);
        }
        reply = yield scope_proxy.activate (channel_id, result_arr,
                                            action_type, hints);
    }

    private async void send_update (string channel_id, string uri, HashTable<string, Variant> props, out HashTable<string, Variant> reply) throws GLib.IOError
    {
        // TODO: handle locally, same way the dash does
        warning ("Unimplemented preview update for %s", uri);
    }

    private void activate_preview(string channel_id, Variant[] result_arr)
    {
        // call scope activate over dbus
        Unity.Protocol.ActivationReplyRaw? reply_struct = null;
        send_activate.begin(channel_id, result_arr,
                            Unity.Protocol.ActionType.PREVIEW_RESULT, null,
                            (obj, res) => {
                try {
                    send_activate.end(res, out reply_struct);
                    preview_scope_uri = reply_struct.uri;
                    handle_activation_reply(reply_struct);
                    notebook.set_current_page(3); //activate 'Preview' tab
                }
                catch (GLib.IOError e) {
                    handle_error(e.message);
                }
            });
    }

    private void update_next_prev_buttons(TreeModel model, TreeIter cur_iter)
    {
        TreeIter iter;

        iter = cur_iter;
        prev_preview_button.sensitive = model.iter_previous(ref iter);
        iter = cur_iter;
        next_preview_button.sensitive = model.iter_next(ref iter);
    }

    /**
     * Handler for 'Request preview' context menu item.
     */
    [CCode (instance_pos = -1)]
    public void on_request_preview(Gtk.MenuItem item)
    {
        TreeModel model;
        TreeIter iter;
        if (results_view_selection.get_selected(out model, out iter)) {
            last_active_model = model;
            last_active_iter = iter;
            activate_preview(current_channel_id,
                             get_selected_result_variant (results_view_selection));
            update_next_prev_buttons(model, iter);
        }
    }

    /**
     * Handler for 'Request preview' context menu item.
     */
    [CCode (instance_pos = -1)]
    public void on_prev_preview_clicked(Gtk.Button button)
        requires (last_active_model != null)
    {
        TreeModel model = last_active_model;
        TreeIter iter = last_active_iter;
        if (last_active_model.iter_previous (ref iter)) {
            last_active_iter = iter;
            results_view_selection.select_iter (iter);
            var result_arr = get_selected_result_variant (results_view_selection);
            activate_preview(current_channel_id, result_arr);
            update_next_prev_buttons(model, iter);
        }
    }
    /**
     * Handler for 'Request preview' context menu item.
     */
    [CCode (instance_pos = -1)]
    public void on_next_preview_clicked(Gtk.MenuItem item)
        requires (last_active_model != null)
    {
        TreeModel model = last_active_model;
        TreeIter iter = last_active_iter;
        if (last_active_model.iter_next (ref iter)) {
            last_active_iter = iter;
            results_view_selection.select_iter (iter);
            var result_arr = get_selected_result_variant (results_view_selection);
            activate_preview(current_channel_id, result_arr);
            update_next_prev_buttons(model, iter);
        }
    }
    /**
     * Handler for 'Activate result' context menu item.
     */
    [CCode (instance_pos = -1)]
    public void on_activate_result(Gtk.MenuItem item)
    {
        var result_arr = get_selected_result_variant (results_view_selection);
        //
        // call scope activate over dbus
        //
        Unity.Protocol.ActivationReplyRaw? reply_struct = null;
        send_activate.begin(current_channel_id, result_arr, Unity.Protocol.ActionType.ACTIVATE_RESULT, null, (obj, res) => {
                try {
                    send_activate.end(res, out reply_struct);
                    handle_activation_reply(reply_struct);
                }
                catch (GLib.IOError e) {
                    handle_error(e.message);
                }
        });
    }

    private Variant[] get_selected_result_variant (Gtk.TreeSelection selection)
    {
        Variant[] result_props = new Variant[9];
        TreeModel model;
        TreeIter iter;
        if (selection.get_selected(out model, out iter)) {
            Value value;
            // Convert model row to variant array
            model.get_value(iter, 0, out value);
            result_props[0] = value.get_string ();
            model.get_value(iter, 1, out value);
            result_props[1] = value.get_string ();
            model.get_value(iter, 2, out value);
            result_props[2] = value.get_uint ();
            model.get_value(iter, 3, out value);
            result_props[3] = value.get_uint ();
            model.get_value(iter, 4, out value);
            result_props[4] = value.get_string ();
            model.get_value(iter, 5, out value);
            result_props[5] = value.get_string ();
            model.get_value(iter, 6, out value);
            result_props[6] = value.get_string ();
            model.get_value(iter, 7, out value);
            result_props[7] = value.get_string ();
            model.get_value(iter, 8, out value);
            result_props[8] = Variant.parse (null, value.get_string ());
        }

        return result_props;
    }

    /**
     * Render preview and action buttons depending on preview type (if applicable); log reply.
     */
    private void handle_activation_reply(Unity.Protocol.ActivationReplyRaw reply_struct)
    {
        append_log_message("Activate reply: " + dump_activation_reply(reply_struct) + "\n");

        if (reply_struct.handled == Unity.HandledType.SHOW_PREVIEW) {
            if (reply_struct.hints.contains("preview")) {
                handle_preview(reply_struct.hints["preview"]);
            } else {
                handle_error("Reply hints don't contain preview element");
            }
        } else {
            remove_preview();
            show_no_preview();
        }
    }

    private void handle_preview(Variant preview_var)
    {
        Unity.Protocol.Preview? reconstructed = Unity.Protocol.Preview.parse(preview_var);
        preview_raw_data.set_text(preview_var.print(true));
        preview_renderer = PreviewRenderer.create(reconstructed, preview_scope_uri);
        update_preview();
    }

    private void update_preview()
    {
        remove_preview();

        if (preview_renderer != null) {
            preview_renderer.preview_action_clicked.connect(on_preview_action_clicked);
            preview_renderer.preview_closed_clicked.connect(on_preview_closed_clicked);
            if (preview_renderer is SeriesPreviewRenderer) {
                ((SeriesPreviewRenderer)preview_renderer).change_selected_series_item_clicked.connect(on_change_selected_series_item_clicked);
            }
            else if (preview_renderer is MusicPreviewRenderer) {
                var renderer = preview_renderer as MusicPreviewRenderer;
                renderer.play_music_track_clicked.connect(on_play_music_track_clicked);
                renderer.pause_music_track_clicked.connect(on_pause_music_track_clicked);
            }
            preview_viewport.add_with_properties(preview_renderer.get_widget());
            preview_viewport.show_all();

            preview_buttons_container.add_with_properties(preview_renderer.get_buttons());
            preview_buttons_container.show_all();

            preview_extra_buttons_container.add_with_properties(preview_renderer.get_extra_buttons());
            preview_extra_buttons_container.show_all();
        } else {
            handle_error("Unknown preview type");
            show_no_preview();
        }
    }

    private void show_no_preview()
    {
        preview_renderer = null;

        preview_raw_data.set_text("");
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        var label = new Gtk.Label("No preview");
        box.pack_start(label);
        preview_viewport.add_with_properties(box);
        box.show_all();
    }

    /**
     * Destroys all preview objects in the 'Render' tab.
     */
    private void remove_preview()
    {
        preview_viewport.foreach((obj) => { obj.destroy(); });

        // remove preview buttons
        preview_buttons_container.foreach((btn) => { btn.destroy(); });
        preview_extra_buttons_container.foreach((btn) => { btn.destroy(); });
    }

    private void on_preview_closed_clicked(PreviewRenderer renderer)
    {
        renderer.preview.begin_updates();
        renderer.preview.preview_closed();
        handle_preview_signals(renderer.preview.end_updates_as_hashtable());

        remove_preview();
    }

    private void on_preview_action_clicked(PreviewRenderer renderer, string action_id)
    {
        Unity.Protocol.ActivationReplyRaw? reply_struct = null;
        var hints = new HashTable<string,Variant>(null, null);
        hints.insert("preview-action-id", action_id);
        send_activate.begin(current_channel_id, get_selected_result_variant (results_view_selection), Unity.Protocol.ActionType.PREVIEW_ACTION, hints, (obj, res) => {
                try {
                    send_activate.end(res, out reply_struct);
                    handle_activation_reply(reply_struct);
                }
                catch (GLib.IOError e) {
                    handle_error(e.message);
                }
            });
    }

    private void on_play_music_track_clicked(MusicPreviewRenderer renderer, string uri)
    {
        var player = new Protocol.PreviewPlayer ();
        player.play.begin (uri);
    }

    private void on_pause_music_track_clicked(MusicPreviewRenderer renderer, string uri)
    {
        var player = new Protocol.PreviewPlayer ();
        player.pause.begin ();
    }

    private void handle_preview_signals(HashTable<string, Variant> props)
    {
        HashTable<string, Variant>? ht = null;
        send_update.begin(current_channel_id, preview_scope_uri, props, (obj, res) => {
                try {
                    send_update.end(res, out ht);
                    if (ht != null) {
                        append_log_message("UpdatePreviewProperty reply: " + dump_ht_reply(ht) + "\n"); //TODO: do we expect any reply?
                    }
                }
                catch (GLib.IOError e) {
                    handle_error(e.message);
                }
            });
    }

    private void on_change_selected_series_item_clicked(SeriesPreviewRenderer renderer, string uri, int index)
    {
        var props = new HashTable<string, Variant>(str_hash, str_equal);
        props["series-active-index"] = new Variant.int32(index);

        HashTable<string, Variant>? ht = null;
        send_update.begin(current_channel_id, uri, props, (obj, res) => {
                try {
                    send_update.end(res, out ht);
                    if (ht != null) {
                        append_log_message("UpdatePreviewProperty reply: " + dump_ht_reply(ht) + "\n");
                        if (ht.contains("preview")) {
                            if (preview_renderer is SeriesPreviewRenderer) {
                                (preview_renderer as SeriesPreviewRenderer).update_child_preview(Unity.Protocol.Preview.parse(ht["preview"]));
                                update_preview();
                            }
                        }
                    }
                }
                catch (GLib.IOError e) {
                    handle_error(e.message);
                }
            });
    }

    /**
     * Handle 'Request preview' context menu action.
     */
    [CCode (instance_pos = -1)]
    public void on_results_popup_request(Gtk.Widget widget)
    {
    }

    /**
     * Handles right mouse button click event in 'Results' tab.
     */
    [CCode (instance_pos = -1)]
    public bool on_results_right_click(Gtk.Widget widget, Gdk.EventButton event)
    {
        if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 3 /* right mouse button */) {
            results_popup_menu.popup(null, null, null, event.button, event.time);
        }
        return false;
    }

    private PreviewRenderer preview_renderer = null;
    private Protocol.ScopeService scope_proxy = null;
    private uint dbus_watcher_id = 0;
    private string preview_scope_uri;
    private Gtk.Notebook notebook = null;
    private Gtk.Viewport preview_viewport = null;
    private Gtk.TreeSelection results_view_selection = null;
    private Gtk.Alignment preview_buttons_container = null;
    private Gtk.Alignment preview_extra_buttons_container = null;
    private Gtk.TextBuffer preview_raw_data = null;
    private Gtk.Menu results_popup_menu = null;
    private Gtk.TreeView results_view = null;
    private Gtk.RadioButton search_type_global_rbutton = null;
    private Gtk.Dialog scope_connect_dlg = null;
    private Gtk.Spinner spinner = null;
    private Gtk.Spinner scope_discovery_spinner = null;
    private Gtk.Button search_button = null;
    private Gtk.Button results_button = null;
    private Gtk.Button prev_preview_button = null;
    private Gtk.Button next_preview_button = null;
    private Gtk.Statusbar statusbar = null;
    private Gtk.TextBuffer log_buffer = null;
    private uint statusbar_info_ctx;
    private uint statusbar_error_ctx;
    private Gtk.Entry search_entry = null;
    private Gtk.Entry dbus_name_entry = null;
    private Gtk.Entry dbus_path_entry = null;
    private Gtk.ComboBox scope_list_combobox = null;
    private Gtk.ListStore uimodel = null;
    private Gtk.ListStore ui_filter_model = null;
    private Gtk.ListStore scope_list_model = null;
    private Gtk.ListStore ui_cat_model = null;
    private ulong model_sync_sig_id;
    private Dee.SharedModel? dee_results_model = null;
    private string current_channel_id = "";
    private string current_swarm_name = "";
    private Dee.SerializableModel? dee_filters_model = null;
    private Dee.SerializableModel? dee_categories_model = null;
    private TreeModel? last_active_model = null;
    private TreeIter? last_active_iter = null;
}

}
