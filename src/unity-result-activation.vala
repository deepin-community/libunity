/*
 * Copyright (C) 2011 Canonical, Ltd.
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
 * Authored by Neil Jagdish Patel <neil.patel@canonical.com>
 *
 */

using GLib;
using Dee;

namespace Unity {

/*
 * Forms a response to an activation requesit
 */

/*
 * Keep in sync with proto lib (we want to expose this enum to lenses,
 * so it is re-defined here
 */
public enum HandledType
{
  NOT_HANDLED,
  SHOW_DASH,
  HIDE_DASH,
  GOTO_DASH_URI,
  SHOW_PREVIEW,
  PERFORM_SEARCH
}

public class ActivationResponse : Object
{
  public HandledType handled { get; construct; }
  public string goto_uri { get; construct set; }

  public ActivationResponse (HandledType handled, string goto_uri="")
  {
    Object (handled:handled, goto_uri:goto_uri);
  }

  public ActivationResponse.with_search (string search_string, FilterSet? filter_set, SearchMetadata? search_metadata)
  {
    // filter_set and search_metadata are not currently handled
    Object (handled:HandledType.PERFORM_SEARCH);
    _new_query = search_string;
  }

  public ActivationResponse.with_preview (Preview preview)
  {
    Object (handled:HandledType.SHOW_PREVIEW);
    set_preview (preview);
  }

  private Preview _preview;
  private string? _new_query;

  internal HashTable<string, Variant> get_hints ()
  {
    var hash = new HashTable<string, Variant> (null, null);

    if (goto_uri != null && goto_uri != "")
      hash["goto-uri"] = goto_uri;
    if (_preview != null)
      hash["preview"] = _preview.serialize ();
    if (_new_query != null)
      hash["query"] = _new_query;

    return hash;
  }

  internal void set_preview (Preview preview)
  {
    _preview = preview;
  }

  internal unowned Preview get_preview ()
  {
    return _preview;
  }
}

public class AggregatorActivation : Object
{
  public string channel_id { get; set; }
  public string scope_id { get; set; }
  public uint action_type { get; set; }
  public ScopeResult? scope_result { get; set; }
  public HashTable<string, Variant> hints { get; internal set; }

  public AggregatorActivation (string channel_id, string scope_id,
                               uint action_type, ScopeResult? result)
  {
    Object (channel_id: channel_id, scope_id: scope_id,
            action_type: action_type);
    scope_result = result;
  }
}

} /* namespace */
