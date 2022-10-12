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
 * Authored by Didier Roche <didrocks@ubuntu.com>
 *
 */

namespace Unity {

  /**
   * A singleton class that caches different gsettings settings.
   *
   */
  public class PreferencesManager : GLib.Object
  {
    private static PreferencesManager singleton = null;

    private Settings gp_settings;
    private const string REMOTE_CONTENT_KEY = "remote-content-search";
    private const string ALWAYS_SEARCH_KEY = "always-search";
    private const string HOMELENS_PRIORITY = "home-lens-priority";
    private const string HOMELENS_DEFAULT_VIEW = "home-lens-default-view";
    private const string DISABLED_SCOPES_KEY = "disabled-scopes";

    public enum RemoteContent
    {
      ALL,
      NONE,
    }

    private PreferencesManager ()
    {
      Object ();
    }

    construct
    {
      var flags = SettingsBindFlags.GET;
      gp_settings = new Settings ("com.canonical.Unity.Lenses");
      gp_settings.bind (REMOTE_CONTENT_KEY, this, "remote_content_search", flags);
      gp_settings.bind (ALWAYS_SEARCH_KEY, this, "always_search", flags);
      gp_settings.bind (HOMELENS_PRIORITY, this, "home_lens_priority", flags);
      gp_settings.bind (HOMELENS_DEFAULT_VIEW, this, "home_lens_default_view", flags);
      gp_settings.bind (DISABLED_SCOPES_KEY, this, "disabled_scopes", flags);
    }

    public RemoteContent remote_content_search { get; set; default = RemoteContent.ALL; }
    public string[] always_search { get; set; default = new string[0]; }
    public string[] home_lens_priority { get; set; default = new string[0]; }
    public string[] home_lens_default_view { get; set; default = new string[0]; }
    public string[] disabled_scopes { get; set; default = new string[0]; }

    /**
     * Get a ref to the singleton PreferencesManager
     */
    public static PreferencesManager get_default ()
    {
      if (PreferencesManager.singleton == null)
        PreferencesManager.singleton = new PreferencesManager ();

      return PreferencesManager.singleton;
    }

  } /* class PreferencesManager */

} /* namespace */