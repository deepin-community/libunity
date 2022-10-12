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

    public abstract class PreviewRenderer: Object
    {
        public signal void preview_action_clicked(string action_id);
        public signal void preview_closed_clicked();

        public abstract Gtk.Widget get_widget();
        public abstract Gtk.Widget get_buttons();
        public abstract Gtk.Widget get_extra_buttons();

        internal abstract void render_buttons();
        internal abstract void render_extra_buttons();
        internal abstract void render();

        public static PreviewRenderer? create(Unity.Protocol.Preview preview, string scope_uri)
        {
            if (preview is Unity.Protocol.GenericPreview) {
                return new GenericPreviewRenderer(preview as Unity.Protocol.GenericPreview, scope_uri);
            }
            if (preview is Unity.Protocol.ApplicationPreview) {
                return new ApplicationPreviewRenderer(preview as Unity.Protocol.ApplicationPreview, scope_uri);
            }
            if (preview is Unity.Protocol.MusicPreview) {
                return new MusicPreviewRenderer(preview as Unity.Protocol.MusicPreview, scope_uri);
            }
            if (preview is Unity.Protocol.MoviePreview) {
                return new MoviePreviewRenderer(preview as Unity.Protocol.MoviePreview, scope_uri);
            }
            if (preview is Unity.Protocol.SeriesPreview) {
                return new SeriesPreviewRenderer(preview as Unity.Protocol.SeriesPreview, scope_uri);
            }
            /* fallback - a generic preview renderer */
            return new GenericPreviewRenderer(preview, scope_uri);
        }

        public Unity.Protocol.Preview preview { get; construct; }
        public string scope_uri { get; construct; }
    }

    /**
     * Render preview in Gtk.Grid with 2 columns (name and value).
     */
    public abstract class GridRenderer: PreviewRenderer
    {
        protected GridRenderer()
        {
            Object();
        }

        internal void add_standard_attributes(Unity.Protocol.Preview preview)
        {
            add_text_row("<b>Title</b>", preview.title);
            add_text_row("<b>Subtitle</b>", preview.subtitle);
            add_text_row("<b>Description</b>", preview.description);
            add_text_row("<b>Image source</b>", preview.image_source_uri);
            add_text_icon_row("<b>Image</b>", preview.image, preview.image.to_string(), 512);
        }

        internal void add_info_hints(Unity.Protocol.Preview preview)
        {
            Unity.Protocol.InfoHintRaw[] hints = preview.get_info_hints();
            add_headline("<b><u>Info Hint</u></b>");
            foreach (Unity.Protocol.InfoHintRaw hint in hints) {
                add_text_row("<b>Id</b>", hint.id);
                add_text_row("<b>Display Name</b>", hint.display_name);
                add_text_row("<b>Icon hint</b>", hint.icon_hint);
                add_text_row("<b>Value</b>", hint.value.print(true));
            }
        }

        /**
         * Renders name and value in two adjacent cells of grid row
         */
        public void add_text_row(string name, string? value)
        {
            var name_label = new Gtk.Label(null);
            name_label.set_markup(name);
            grid.attach(name_label, 0, row, 1, 1);
            var value_label = new Gtk.Label(value);
            value_label.selectable = true;
            grid.attach(value_label, 1, row, 1, 1);

            ++row;
        }

        /**
         * Renders text in two joined cells of grid row
         */
        public void add_headline(string text)
        {
            var label = new Gtk.Label(null);
            label.set_markup(text);
            grid.attach(label, 0, row, 2, 1);

            ++row;
        }

        /**
         * Renders name and arbitrary widget in two adjacent cells of grid row
         */
        public void add_widget(string name, Gtk.Widget widget)
        {
            var name_label = new Gtk.Label(null);
            name_label.set_markup(name);
            grid.attach(name_label, 0, row, 1, 1);
            grid.attach(widget, 1, row, 1, 1);
            ++row;
        }
        
        public void on_preview_action_clicked(Gtk.Button button)
        {
            string id = preview_actions.get(button);
            preview_action_clicked(id);
        }

        public void on_preview_closed_clicked(Gtk.Button button)
        {
            preview_closed_clicked();
        }

        /**
         * Renders name and icon in two adjacent cells of grid row
         */
        public void add_text_icon_row(string name, GLib.Icon? icon, string? tooltip, int size=32)
        {
            var icon_label = new Gtk.Label(null);
            icon_label.set_markup(name);
            grid.attach(icon_label, 0, row, 1, 1);
            var themed_icon = Gtk.IconTheme.get_default().lookup_by_gicon(icon, size, 0);
            try {
                var pixbuf = themed_icon.load_icon();
                Gtk.Image image = new Gtk.Image.from_pixbuf(pixbuf);
                if (tooltip != null) {
                    image.set_tooltip_text(tooltip);
                }
                grid.attach(image, 1, row, 1, 1);
            }
            catch (GLib.Error e) {
                warning(@"Got error while loading pixmap: $(e.message)");
            }

            ++row;
        }

        public override Gtk.Widget get_widget()
        {
            render();
            grid.foreach((obj) => { obj.set_halign(Gtk.Align.START); });
            return grid;
        }

        public override Gtk.Widget get_buttons()
        {
            render_buttons();
            return preview_actions_box;
        }

        public override Gtk.Widget get_extra_buttons()
        {
            render_extra_buttons();
            return preview_extra_buttons_box;
        }

        public override void render_buttons()
        {
            preview_actions = new GLib.HashTable<Gtk.Button, string>(null, null);
            Unity.Protocol.PreviewActionRaw[] actions = preview.get_actions();
            for (int i=0; i<actions.length; i++) {
                unowned Unity.Protocol.PreviewActionRaw action = actions[i];
                Gtk.Button btn = new Gtk.Button.with_label(action.display_name);
                btn.clicked.connect(on_preview_action_clicked);
                preview_actions_box.pack_start(btn, false, false);
                btn.set_tooltip_text(action.id);
                preview_actions.insert(btn, action.id);
                btn.show_all();
            }
        }

        internal override void render_extra_buttons()
        {
            Gtk.Button btn = new Gtk.Button.with_label("Close");
            btn.clicked.connect(on_preview_closed_clicked);
            preview_extra_buttons_box.pack_start(btn, false, false);
            btn.show_all();
        }

        construct {
            grid = new Gtk.Grid();
            grid.set_column_spacing(5);
            grid.set_row_spacing(5);
            grid.border_width = 5;
            grid.set_halign(Gtk.Align.FILL);
            grid.set_valign(Gtk.Align.FILL);
            grid.hexpand = true;
            grid.vexpand = true;

            preview_actions_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            preview_actions_box.set_halign(Gtk.Align.FILL);
            preview_actions_box.set_valign(Gtk.Align.FILL);
            preview_actions_box.hexpand = false;
            preview_actions_box.vexpand = false;

            preview_extra_buttons_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
            preview_extra_buttons_box.set_halign(Gtk.Align.FILL);
            preview_extra_buttons_box.set_valign(Gtk.Align.FILL);
            preview_extra_buttons_box.hexpand = false;
            preview_extra_buttons_box.vexpand = false;
        }

        private int row = 0;
        public Gtk.Grid grid { get; construct; }
        public Gtk.Box preview_actions_box { get; construct; }
        public Gtk.Box preview_extra_buttons_box { get; construct; }
        private GLib.HashTable<Gtk.Button, string> preview_actions = null;
    }

    public class GenericPreviewRenderer: GridRenderer
    {
        public GenericPreviewRenderer(Unity.Protocol.Preview preview, string scope_uri)
        {
            Object(preview: preview, scope_uri: scope_uri);
        }

        internal override void render()
        {
            assert(preview != null);

            base.add_standard_attributes(preview as Unity.Protocol.Preview);
            base.add_info_hints(preview as Unity.Protocol.Preview);
        }
    }

    public class ApplicationPreviewRenderer: GridRenderer
    {
        public ApplicationPreviewRenderer(Unity.Protocol.ApplicationPreview preview, string scope_uri)
        {
            Object(preview: preview, scope_uri: scope_uri);
        }

        internal override void render()
        {
            assert(preview != null);

            var app_preview = preview as Unity.Protocol.ApplicationPreview;

            base.add_standard_attributes(preview);
            base.add_text_row("<b>License</b>", app_preview.license);
            base.add_text_row("<b>Copyright</b>", app_preview.copyright);
            base.add_text_row("<b>Last update</b>", app_preview.last_update);
            base.add_text_row("<b>Rating</b>", "%.2f".printf(app_preview.rating));
            base.add_text_row("<b>Number of ratings</b>", "%u".printf(app_preview.num_ratings));
            base.add_text_icon_row("<b>Application icon</b>", app_preview.app_icon, app_preview.app_icon.to_string());
            base.add_info_hints(app_preview);
        }
    }

    public class MusicPreviewRenderer: GridRenderer
    {
        private MusicTrackModelRenderer track_model_renderer;
        private Gtk.TreeView track_view;
        private Gtk.Menu track_view_popup_menu;

        public signal void play_music_track_clicked(string uri);
        public signal void pause_music_track_clicked(string uri);

        public MusicPreviewRenderer(Unity.Protocol.MusicPreview preview, string scope_uri)
        {
            Object(preview: preview, scope_uri: scope_uri);
        }

        internal override void render()
        {
            assert(preview != null);
            var music_preview = preview as Unity.Protocol.MusicPreview;

            base.add_standard_attributes(preview);
            base.add_text_row("<b>Track data swarm name</b>", music_preview.track_model != null ? "<<serialized model present>>" : music_preview.track_data_swarm_name);
            base.add_text_row("<b>Track data address</b>", music_preview.track_data_address);
            base.add_info_hints(music_preview);

            if (music_preview.track_model != null)
            {
                track_model_renderer = new MusicTrackModelRenderer(music_preview.track_model);
                track_view = new TreeView();
                var track_view_viewport = new Viewport(null, null);
            
                track_view.set_model(track_model_renderer.track_view_model);

                track_view.insert_column_with_attributes(-1, "uri", new CellRendererText (), "text", 0);
                track_view.insert_column_with_attributes(-1, "track no", new CellRendererText (), "text", 1);
                track_view.insert_column_with_attributes(-1, "title", new CellRendererText (), "text", 2);
                track_view.insert_column_with_attributes(-1, "length", new CellRendererText (), "text", 3);
                track_view.insert_column_with_attributes(-1, "playing", new CellRendererText (), "text", 4);
                track_view.insert_column_with_attributes(-1, "progress", new CellRendererText (), "text", 5);
            
                track_view_viewport.add_with_properties(track_view);
                add_widget("Track model", track_view_viewport);
                
                track_view_popup_menu = new Gtk.Menu();
                var play_item = new Gtk.MenuItem.with_label("Play");
                play_item.activate.connect(on_play_item_clicked);
                track_view_popup_menu.append(play_item);
                play_item.show();
                var pause_item = new Gtk.MenuItem.with_label("Pause");
                pause_item.activate.connect(on_pause_item_clicked);
                track_view_popup_menu.append(pause_item);
                pause_item.show();

                track_view.button_press_event.connect(on_track_view_right_click);
                track_model_renderer.sync();
            }
        }

        public bool on_track_view_right_click(Gtk.Widget widget, Gdk.EventButton event)
        {
            if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 3 /* right mouse button */) {
                track_view_popup_menu.popup(null, null, null, event.button, event.time);
            }
            return false;
        }
       
        internal string get_selected_track_uri()
        {
            TreeModel model;
            TreeIter iter;
            var selection = track_view.get_selection();
            if (selection.get_selected(out model, out iter)) {
                Value val;
                // get uri column
                model.get_value(iter, 0, out val);
                return val.get_string();
            }
            return "";
        }

        internal void on_play_item_clicked(Gtk.MenuItem item)
        {
            string uri = get_selected_track_uri();
            if (uri != "")
            {
                play_music_track_clicked(uri);
            }
        }

        internal void on_pause_item_clicked(Gtk.MenuItem item)
        {
            string uri = get_selected_track_uri();
            if (uri != "")
            {
                pause_music_track_clicked(uri);
            }
        }
    }

    public class MoviePreviewRenderer: GridRenderer
    {
        public MoviePreviewRenderer(Unity.Protocol.MoviePreview preview, string scope_uri)
        {
            Object(preview: preview, scope_uri: scope_uri);
        }

        internal override void render()
        {
            assert(preview != null);
            var movie_preview= preview as Unity.Protocol.MoviePreview;

            base.add_standard_attributes(preview);
            base.add_text_row("<b>Rating</b>", "%.2f".printf(movie_preview.rating));
            base.add_text_row("<b>Number of ratings</b>", "%u".printf(movie_preview.num_ratings));
            base.add_info_hints(movie_preview);
        }
    }

    public class SeriesPreviewRenderer: GridRenderer
    {
        public signal void change_selected_series_item_clicked(string uri, int index);

        public SeriesPreviewRenderer(Unity.Protocol.SeriesPreview preview, string scope_uri)
        {
            Object(preview: preview, scope_uri: scope_uri);
        }

        public void update_child_preview(Unity.Protocol.Preview child_preview)
        {
            (preview as Unity.Protocol.SeriesPreview).child_preview = child_preview;
        }

        private void on_change_selected_item_clicked(Gtk.ComboBox combo)
        {
            int index = int.parse(combo.active_id);
            var series_preview = preview as Unity.Protocol.SeriesPreview;
            if (index != series_preview.selected_item) {
                change_selected_series_item_clicked(scope_uri, index);
            }
        }

        internal override void render_extra_buttons()
        {
            var series_preview = preview as Unity.Protocol.SeriesPreview;

            Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 5);

            Gtk.ComboBoxText items_combo = new Gtk.ComboBoxText();
            items_combo.changed.connect(on_change_selected_item_clicked);
            Protocol.SeriesItemRaw[] items = series_preview.get_items();
            for (int i=0; i<items.length; i++) {
                items_combo.append("%u".printf(i), "Series item #%u".printf(i));
            }
            items_combo.set_active_id("%u".printf(series_preview.selected_item));

            var label = new Gtk.Label("Set active:");
            box.pack_start(label);
            box.pack_start(items_combo, false, false);
            box.show_all();

            preview_extra_buttons_box.pack_start(box, false, false);
        }

        internal override void render()
        {
            assert(preview != null);
            var series_preview = preview as Unity.Protocol.SeriesPreview;

            base.add_standard_attributes(preview);
            base.add_text_row("<b>Selected item</b>", "%d".printf(series_preview.selected_item));
            Protocol.SeriesItemRaw[] items = series_preview.get_items();

            PreviewRenderer? child_preview = PreviewRenderer.create(series_preview.child_preview, scope_uri);
            if (child_preview != null) {
                base.add_widget("<b>Child preview</b>", child_preview.get_widget());
            }

            for (int i=0; i<items.length; i++) {
                base.add_headline("<u><b>Series item #%u</b></u>".printf(i));
                base.add_text_row("<b>Title</b>", items[i].title);
                base.add_text_row("<b>Uri</b>", items[i].uri);

                if (items[i].icon_hint != null) {
                    try {
                        var icon = GLib.Icon.new_for_string(items[i].icon_hint);
                        base.add_text_icon_row("<b>Icon</b>", icon, items[i].icon_hint.to_string());
                    }
                    catch (GLib.Error e) {
                        stderr.printf("Series Item icon couldn't be loaded: %s\n", e.message);
                    }
                }
            }
            base.add_info_hints(series_preview);
        }
    }
}
