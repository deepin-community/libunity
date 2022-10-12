/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- *//*
 * Copyright (C) 2009,2011 Canonical Ltd
 *
 * This program is free software: you can redistribute it and/or modify
 * idst under the terms of the GNU General Public License version 3 as
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
 * Authored by Neil Jagdish Patel <neil.patel@canonical.com>,
 *             Mikkel Kamstrup Erlandsen <mikkel.kamstrup@canonical.com>
 *
 */

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Config
{
  public const string BUILDDIR;
  public const string TESTVALADIR;
  public const string TESTDIR;
  
  [CCode (cheader_filename = "gio/gsettingsbackend.h", cprefix = "G", lower_case_cprefix = "g_")]
  public static GLib.SettingsBackend keyfile_settings_backend_new (string filename, string root_path, string root_group);
}
