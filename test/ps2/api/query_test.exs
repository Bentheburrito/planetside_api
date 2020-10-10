defmodule PS2.API.QueryTest do
  use ExUnit.Case
  doctest PS2.API.Query

  alias PS2.API.Query

  describe "Query" do
    test "new/0 creates a Query struct" do
      q = Query.new()
      assert q == %Query{}
    end

    test "new/1 creates a Query struct with defined collection field" do
      q = Query.new(collection: "some_col")
      assert q == %Query{collection: "some_col"}
    end

    test "is encoded when passed to to_string/1" do
      q = %Query{collection: "collection", params: %{"character_id" => {"", "1231231231231234"}}}
      assert to_string(q) === "collection?character_id=1231231231231234"
    end
  end
end
