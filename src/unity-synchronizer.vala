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

namespace Unity.Internal {

/*
 * Connects to the necessary signals to reflect changes in the providers on the
 * receiver Model
 */
internal class ResultsSynchronizer : GLib.Object, MergeStrategy
{
  private struct SignalHandlers
  {
    bool blocked;
    ulong row_added_id;
    ulong row_removed_id;
    ulong row_changed_id;
  }

  public unowned Dee.Model receiver { get; construct; }
  public string owner_scope_id { get; construct; }
  public MergeStrategy merge_strategy { get; set; }

  private HashTable<Dee.Model, unowned Dee.Model> _providers;
  private HashTable<string, unowned Dee.Model> _provider_ids;
  // need unowned getter, so no Gee
  private HashTable<unowned Dee.Model, SignalHandlers?> _provider_signal_ids;
  private HashTable<unowned Dee.Model, Dee.ModelTag<unowned Dee.ModelIter>> _provider_tags;
  private HashTable<unowned Dee.Model, Dee.ModelTag<uint>> _clear_seqnum_tags;
  private Variant[] row_buf = new Variant[9];
  private Quark scope_id_quark = Quark.from_string ("scope-id");
  private uint _clear_seq_num = 1;

  internal ResultsSynchronizer (Dee.Model receiver, string scope_id)
  {
    Object (receiver:receiver, owner_scope_id: scope_id);
  }

  construct
  {
    _providers = new HashTable<Dee.Model, unowned Dee.Model> (null, null);
    _provider_ids = new HashTable<string, unowned Dee.Model> (str_hash, str_equal);
    _provider_signal_ids = new HashTable<unowned Dee.Model, SignalHandlers?> (null, null);
    _provider_tags = new HashTable<unowned Dee.Model, Dee.ModelTag<unowned Dee.ModelIter>> (null, null);
    _clear_seqnum_tags = new HashTable<unowned Dee.Model, Dee.ModelTag<uint>> (null, null);
    merge_strategy = this;
  }

  public void clear ()
  {
    ++_clear_seq_num;
    receiver.clear ();
  }
 
  public unowned Dee.ModelIter? merge_result (string source_scope_id,
                                              Dee.Model target, Variant[] row)
  {
    return target.append_row (row);
  }

  public void add_provider (Dee.Model provider, string scope_id)
  {
    if (provider in _providers)
    {
      warning ("%s: provider[%p] was already added", Log.METHOD, provider);
      return;
    }

    if (scope_id in _provider_ids)
    {
      debug ("%s: provider for %s already registered", Log.METHOD, scope_id);
      clear_provider_model (scope_id);
      remove_provider (scope_id);
    }

    _providers.add (provider);
    _provider_ids[scope_id] = provider;
    _provider_tags[provider] = new Dee.ModelTag<unowned Dee.ModelIter> (provider);
    _clear_seqnum_tags[provider] = new Dee.ModelTag<uint> (provider);

    var handlers = SignalHandlers ();
    handlers.blocked = false;
    handlers.row_added_id = provider.row_added.connect (on_row_added);
    handlers.row_removed_id = provider.row_removed.connect (on_row_removed);
    handlers.row_changed_id = provider.row_changed.connect (on_row_changed);

    _provider_signal_ids[provider] = handlers;

    var sm = provider as Dee.SharedModel;
    if (sm != null)
    {
      sm.end_transaction.connect (transaction_finished);
    }

    provider.set_qdata<string> (scope_id_quark, scope_id);
  }

  internal void remove_provider (string scope_id)
  {
    Dee.Model provider = _provider_ids[scope_id];
    if (provider != null)
    {
      _provider_tags.remove (provider);
      _clear_seqnum_tags.remove (provider);

      var handlers = _provider_signal_ids[provider];
      SignalHandler.disconnect (provider, handlers.row_added_id);
      SignalHandler.disconnect (provider, handlers.row_removed_id);
      SignalHandler.disconnect (provider, handlers.row_changed_id);

      var sm = provider as Dee.SharedModel;
      if (sm != null)
      {
        sm.end_transaction.disconnect (transaction_finished);
      }
      _provider_signal_ids.remove (provider);
      _provider_ids.remove (scope_id);
      _providers.remove (provider);
    }
  }

  internal void disable_all_providers ()
  {
    _providers.foreach ((provider) =>
    {
      unowned SignalHandlers? handlers = _provider_signal_ids[provider];
      if (handlers.blocked == false)
      {
        handlers.blocked = true;
        SignalHandler.block (provider, handlers.row_added_id);
        SignalHandler.block (provider, handlers.row_removed_id);
        SignalHandler.block (provider, handlers.row_changed_id);
      }
    });
  }

  internal void disable_provider (string scope_id)
  {
    var provider = _provider_ids[scope_id];
    if (provider != null)
    {
      unowned SignalHandlers? handlers = _provider_signal_ids[provider];
      if (handlers.blocked) return;
      handlers.blocked = true;
      SignalHandler.block (provider, handlers.row_added_id);
      SignalHandler.block (provider, handlers.row_removed_id);
      SignalHandler.block (provider, handlers.row_changed_id);
    }
  }

  internal void enable_provider (string scope_id)
  {
    var provider = _provider_ids[scope_id];
    if (provider != null)
    {
      unowned SignalHandlers? handlers = _provider_signal_ids[provider];
      if (!handlers.blocked) return;
      handlers.blocked = false;
      SignalHandler.unblock (provider, handlers.row_added_id);
      SignalHandler.unblock (provider, handlers.row_removed_id);
      SignalHandler.unblock (provider, handlers.row_changed_id);
    }
  }

  public signal void transaction_complete (Dee.Model model, string? scope_id);

  private void transaction_finished (Dee.SharedModel model,
                                     uint64 begin_sn, uint64 end_sn)
  {
    unowned string scope_id = model.get_qdata<string> (scope_id_quark);
    Unity.Trace.tracepoint ("changeset::scope=%s;target=%s", owner_scope_id, scope_id);
    if (model in _providers)
    {
      transaction_complete (model, scope_id);
    }
  }

  private void clear_provider_model (string scope_id)
  {
    var provider = _provider_ids[scope_id];
    if (provider != null)
    {
      unowned SignalHandlers? handlers = _provider_signal_ids[provider];
      bool was_blocked = handlers.blocked;
      // enable the provider
      enable_provider (scope_id);
      provider.clear ();
      if (was_blocked) disable_provider (scope_id);
    }
  }

  internal unowned Variant[] prepare_row_buf (Dee.Model provider,
                                              Dee.ModelIter iter)
  {
    // vala doesn't know that the get_row_static method will write into
    // the array, so we need to unref the variants inside ourselves
    for (int i = 0; i < row_buf.length; i++)
    {
      row_buf[i] = null;
    }

    provider.get_row_static (iter, row_buf);

    var scope_id_entry = new Variant.dict_entry ("scope-id",
                                                 new Variant.variant (provider.get_qdata<string> (scope_id_quark)));
    var content_entry = new Variant.dict_entry ("content",
                                                new Variant.variant (row_buf[8]));

    row_buf[8] = new Variant.array (VariantType.VARDICT.element (),
                                    {scope_id_entry, content_entry});

    return row_buf;
  }

  private void on_row_added (Dee.Model provider, Dee.ModelIter iter)
  {
    unowned Dee.ModelIter? i;

    prepare_row_buf (provider, iter);
    i = merge_strategy.merge_result (provider.get_qdata<string>(scope_id_quark),
                                     receiver, row_buf);

    if (i != null)
    {
      var tag = _provider_tags[provider];
      tag [provider, iter] = i;

      var rem_tag = _clear_seqnum_tags[provider];
      rem_tag [provider, iter] = _clear_seq_num;
    }
  }

  private void on_row_removed (Dee.Model provider, Dee.ModelIter iter)
  {
    var rem_tag = _clear_seqnum_tags[provider];
    var tag = _provider_tags[provider];
    uint seq_num = rem_tag[provider, iter];
    if (seq_num == _clear_seq_num)
    {
      rem_tag [provider, iter] = 0;
      var riter = tag[provider, iter];

      if (riter != null)
        receiver.remove (riter);
    }
  }

  private void on_row_changed (Dee.Model provider, Dee.ModelIter iter)
  {
    var tag = _provider_tags[provider];
    var riter = tag[provider, iter];

    if (riter != null)
    {
      prepare_row_buf (provider, iter);
      receiver.set_row (riter, row_buf);
    }
    else
    {
      warning (@"Could not find row to change: $(provider.get_string (iter, 0))");
    }
  }

  internal void copy_model (Dee.Model provider)
  {
    if (!(provider in _providers))
    {
      unowned string scope_id = provider.get_qdata<string> (scope_id_quark);
      critical ("Requested unknown provider model [scope-id: %s]", scope_id);
    }
    else
    {
      var end = provider.get_last_iter ();
      var iter = provider.get_first_iter ();
      while (iter != end)
      {
        on_row_added (provider, iter);
        iter = provider.next (iter);
      }

      transaction_complete (provider, provider.get_qdata<string> (scope_id_quark));
    }
  }
}


} /* namespace Unity */
