namespace Unity {

/**
 * A small AbstractScope wrapper which is easy to use in C.
 *
 * All you need to do when using this class is instantiate it using
 * unity_simple_scope_new(), set a few properties (filters, categories,
 * group and unique name) and most importantly set the pointer to the search,
 * preview and (optionally) activation functions.
 */
public class SimpleScope: Unity.AbstractScope
{
  public delegate void SearchRunFunc (ScopeSearchBase search);
  public delegate void SearchRunAsyncFunc (ScopeSearchBase search,
                                           ScopeSearchBaseCallback cb);
  public delegate AbstractPreview? PreviewRunFunc (ResultPreviewer previewer);
  public delegate void PreviewRunAsyncFunc (ResultPreviewer previewer,
                                            AbstractPreviewCallback cb);
  public delegate ActivationResponse? ActivateFunc (ScopeResult result,
                                                    SearchMetadata metadata,
                                                    string? action_id);

  private class SimpleScopeSearch: ScopeSearchBase
  {
    private unowned SearchRunFunc run_func;
    private unowned SearchRunAsyncFunc run_async_func;

    public SimpleScopeSearch (SearchRunFunc run_f, SearchRunAsyncFunc run_af)
    {
      Object ();
      run_func = run_f;
      run_async_func = run_af;
    }

    protected override void run ()
    {
      if (run_func == null)
      {
        critical ("Unable to handle search request, search_func was not set");
        return;
      }
      run_func (this);
    }

    protected override void run_async (ScopeSearchBaseCallback cb)
    {
      if (run_async_func != null)
      {
        // FIXME: unowned delegate, will the ref-counting work fine here?
        run_async_func (this, cb);
      }
      else
      {
        base.run_async (cb);
      }
    }
  }

  private class SimpleResultPreviewer: ResultPreviewer
  {
    private unowned PreviewRunFunc run_func;
    private unowned PreviewRunAsyncFunc run_async_func;

    public SimpleResultPreviewer (PreviewRunFunc run_f,
                                  PreviewRunAsyncFunc run_af)
    {
      Object ();
      run_func = run_f;
      run_async_func = run_af;
    }
    
    protected override AbstractPreview? run ()
    {
      if (run_func == null)
      {
        critical ("Unable to handle preview request, preview_func was not set");
        return null;
      }
      return run_func (this);
    }

    protected override void run_async (AbstractPreviewCallback cb)
    {
      if (run_async_func != null)
      {
        run_async_func (this, cb);
      }
      else
      {
        base.run_async (cb);
      }
    }
  }

  public FilterSet filter_set { get; set; default = new FilterSet (); }
  public CategorySet category_set { get; set; default = new CategorySet (); }
  public Schema schema { get; set; default = new Schema (); }
  public string search_hint { get; set; default = ""; }
  // hopefully these props will disappear
  public string group_name { get; set; }
  public string unique_name { get; set; }

  private SearchRunFunc search_run_func;
  private SearchRunAsyncFunc search_run_async_func;
  private PreviewRunFunc preview_run_func;
  private PreviewRunAsyncFunc preview_run_async_func;
  private ActivateFunc activate_func;

  /**
   * Set search function.
   *
   * Use this call to set the search function. The search function should be 
   * set right after the call to unity_simple_scope_new().
   * Note that by default the search function will be invoked in a separate 
   * thread, if you want to change that behavior use the set_search_async_func()
   * method instead.
   * You must call either this method or the async variant
   * set_search_async_func() to make this instance fully usable.
   */
  public void set_search_func (owned SearchRunFunc func)
  {
    search_run_func = (owned) func;
  }

  /**
   * Set search function (async variant).
   *
   * Use this call to set the search function. By default a new thread will be
   * spawned and the search_func will be invoked there.
   * You must call either this method or the sync variant
   * set_search_func() to make this instance fully usable.
   * See set_search_func() for more details.
   */
  public void set_search_async_func (owned SearchRunAsyncFunc? func)
  {
    search_run_async_func = (owned) func;
  }

  /**
   * Set activation function.
   *
   * Use this call to set the activation function. The activation function
   * is not required if the scope results are using standard URI schemas.
   */
  public void set_activate_func (owned ActivateFunc? func)
  {
    activate_func = (owned) func;
  }

  /**
   * Set preview function.
   *
   * Use this call to set the preview function. The preview function should be
   * set right after the call to unity_simple_scope_new().
   * Note that by default the preview function will be invoked in a separate
   * thread, if you want to change that behavior use the
   * set_preview_async_func() method instead.
   * You must call either this method or the async variant
   * set_preview_async_func() to make this instance fully usable.
   */
  public void set_preview_func (owned PreviewRunFunc func)
  {
    preview_run_func = (owned) func;
  }

  /**
   * Set preview function (async variant).
   *
   * Use this call to set the preview function. By default a new thread will be
   * spawned and the preview_func will be invoked there.
   * You must call either this method or the sync variant
   * set_preview_func() to make this instance fully usable.
   * See set_preview_func() for more details.
   */
  public void set_preview_async_func (owned PreviewRunAsyncFunc? func)
  {
    preview_run_async_func = (owned) func;
  }

  public SimpleScope ()
  {
  }

  protected override ScopeSearchBase create_search_for_query (SearchContext ctx)
  {
    var search = new SimpleScopeSearch (search_run_func, search_run_async_func);
    search.set_search_context (ctx);
    return search;
  }

  protected override ResultPreviewer create_previewer (ScopeResult result,
                                                       SearchMetadata metadata)
  {
    var previewer = new SimpleResultPreviewer (preview_run_func,
                                               preview_run_async_func);
    previewer.set_scope_result (result);
    previewer.set_search_metadata (metadata);
    return previewer;
  }

  protected override ActivationResponse? activate (ScopeResult result,
                                                   SearchMetadata metadata,
                                                   string? action_id)
  {
    if (activate_func != null)
    {
      return activate_func (result, metadata, action_id);
    }

    return null;
  }

  protected override CategorySet get_categories ()
  {
    return category_set;
  }

  protected override FilterSet get_filters ()
  {
    return filter_set;
  }

  protected override Schema get_schema ()
  {
    return schema;
  }

  protected override string get_search_hint ()
  {
    return search_hint;
  }

  protected override string get_group_name ()
  {
    return group_name;
  }

  protected override string get_unique_name ()
  {
    return unique_name;
  }
}

} // namespace Unity

