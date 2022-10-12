/*
 * Copyright (C) 2012 Canonical, Ltd.
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

using GLib;

namespace Unity.Internal {

internal interface MergeStrategy : GLib.Object
{
  /**
   * Virtual method to merge row from source model into target model.
   *
   * @param source_scope_id The ID of the source scope
   * @param target The target model to merge a row into
   * @param row An array of variants with the row data for the result
   *
   * @return A model iter pointing to the row in the target model where @row
   *         was added. Or null if the result was discarded
   */
  public abstract unowned Dee.ModelIter? merge_result (string source_scope_id,
                                                       Dee.Model target,
                                                       Variant[] row);
}

} /* namespace */
