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

namespace Unity.Tester {

public class MusicTrackModelRenderer: Object
{
    public Dee.Model track_model { get; construct; }
    private Dee.ModelTag<int> track_model_tag;
    private int row_counter = 0;
    private ulong model_sync_sig_id = 0;
    public Gtk.ListStore track_view_model { get; construct; }

    public signal void track_list_synchronized();

    construct
    {
        track_view_model = new Gtk.ListStore(6, typeof(string), typeof(int), typeof(string), typeof(uint), typeof(uint), typeof(double));
    }

    public MusicTrackModelRenderer(Dee.Model track_model)
    {
        Object(track_model: track_model);
    }

    public void sync()
    {
        track_model_tag = new Dee.ModelTag<int>(track_model);

        track_model.row_added.connect(track_added_cb);
        track_model.row_changed.connect(track_changed_cb);

        var iter = track_model.get_first_iter ();
        var end_iter = track_model.get_last_iter ();
        while (iter != end_iter)
        {
          track_added_cb (track_model, iter);
          iter = track_model.next (iter);
        }

        if (track_model is Dee.SharedModel)
        {
          model_sync_sig_id = track_model.notify["synchronized"].connect(track_model_synchronized_cb);
        }
    }

    private void track_added_cb(Dee.Model model, Dee.ModelIter iter)
    {
        var row = model.get_row(iter);

        track_model_tag.set(track_model, iter, row_counter++);

        Gtk.TreeIter tm_iter;
        track_view_model.append(out tm_iter);
        track_view_model.set(tm_iter, 0, row[0].get_string(), 1, row[1].get_int32(), 2, row[2].get_string(), 3, row[3].get_uint32(), 4, row[4].get_uint32(), 5, row[5].get_double(), -1);
    }

    private void track_changed_cb(Dee.Model model, Dee.ModelIter iter)
    {
        int index = track_model_tag.get(track_model, iter);
        Gtk.TreeIter tm_iter;
        if (track_view_model.get_iter_first(out tm_iter)) {
            while (index > 0)
            {
                if (!track_view_model.iter_next(ref tm_iter)) {
                    break;
                }
                --index;
            }
            if (index == 0) {
                var row = model.get_row(iter);
                track_view_model.set(tm_iter, 0, row[0].get_string(), 1, row[1].get_int32(), 2, row[2].get_string(), 3, row[3].get_uint32(), 4, row[4].get_uint32(), 5, row[5].get_double(), -1);
            } else {
                stderr.printf("can't update row");
            }
        }
    }

    private void track_model_synchronized_cb()
    {
        SignalHandler.disconnect (track_model, model_sync_sig_id);
        track_list_synchronized();
    }
}

}
