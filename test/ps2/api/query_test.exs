defmodule PS2.API.QueryTest do
  use ExUnit.Case
  doctest PS2.API.Query

  import PS2.API.QueryBuilder

  alias PS2.API.Query
  alias PS2.API.Query.Join
  alias PS2.API.Query.Tree

  describe "new/1" do
    test "creates a Query struct" do
      q = Query.new(collection: "character")
      assert q == %Query{collection: "character"}
    end
  end

  test "to_string/1 encodes a Query as expected" do
    q = %Query{collection: "collection", params: %{"character_id" => {"", "1231231231231234"}}}
    assert to_string(q) === "/collection?character_id=1231231231231234&"
  end

  describe "encode/1" do
    test "" do
      query_uri =
        Query.new(collection: "test_col")
        |> limit(12)
        |> lang("en")
        |> join(
          %Join{}
          |> collection("test_col_join")
          |> show("some_field")
          |> hide(["some_other_field", "another_field"])
          |> inject_at("name")
        )
        |> tree(
          %Tree{field: "some_field"}
          |> list(true)
        )
        |> sort(%{"key" => "1"})
        |> Query.encode()

      assert %{
               path: "/test_col",
               query:
                 "c:lang=en&c:limit=12&c:join=test_col_join^hide:some_other_field'another_field^inject_at:name^show:some_field&c:tree=list:1^field:some_field&c:sort=key:1"
             } = query_uri
    end
  end
end
