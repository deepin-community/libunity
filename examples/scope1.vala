/* -*- mode: vala; c-basic-offset: 2; indent-tabs-mode: nil -*- */

class Scope1: Unity.AbstractScope
{
  public Scope1 ()
  {
  }

  public override Unity.ScopeSearchBase create_search_for_query (Unity.SearchContext ctx)
  {
    var search = new Scope1Search ();
    search.set_search_context (ctx);
    return search;
  }

  public override Unity.ResultPreviewer create_previewer (Unity.ScopeResult result, Unity.SearchMetadata metadata)
  {
    return null;
  }

  public override Unity.CategorySet get_categories ()
  {
    return new Unity.CategorySet ();
  }

  public override Unity.FilterSet get_filters ()
  {
    return new Unity.FilterSet ();
  }

  public override Unity.Schema get_schema ()
  {
    return new Unity.Schema ();
  }

  public override string get_group_name ()
  {
    return "org.example.Scope.One";
  }

  public override string get_unique_name ()
  {
    return "/org/example/Scope/One";
  }
}

class Scope1Search: Unity.ScopeSearchBase
{
  public Scope1Search ()
  {
  }

  public override void run ()
  {
    var result = Unity.ScopeResult ();
    result.uri = "test:uri";
    result.icon_hint = "";
    result.category = 0;
    result.result_type = Unity.ResultType.DEFAULT;
    result.mimetype = "inode/folder";
    result.title = "Scope 1 result";
    result.comment = "";
    result.dnd_uri = "test::uri";
    result.metadata = new HashTable<string, Variant> (str_hash, str_equal);
    search_context.result_set.add_result (result);
  }
}

public int unity_scope_module_get_version ()
{
  return Unity.SCOPE_API_VERSION;
}

public List<Unity.AbstractScope> unity_scope_module_load_scopes () throws Error
{
  List<Unity.AbstractScope> scopes = null;
  var scope = new Scope1();
  scopes.append(scope);
  return scopes;
}
