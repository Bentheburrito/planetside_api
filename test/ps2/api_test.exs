defmodule PS2.APITest do
  use ExUnit.Case, async: true
  doctest PS2.API

  import PS2.API.QueryBuilder
  alias PS2.API.{Query, Join, Tree, QueryResult}

  @invalid_search_term_message "SERVER_ERROR INVALID_SEARCH_TERM: Invalid search term: c:exactMatchFirst. Value must be a boolean: 0, false, f, 1, true or t."

  test "Ensure proper query encoding" do
    q =
      %Query{}
      |> collection("test_col")
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
        %Tree{}
        |> field("some_field")
        |> list(true)
      )
      |> sort(%{"key" => "1"})

    assert PS2.API.encode(q) ==
             {:ok,
              "test_col?c:lang=en&c:limit=12&c:join=test_col_join%5Ehide:some_other_field'another_field%5Einject_at:name%5Eshow:some_field&c:tree=field:some_field%5Elist:1&c:sort=key:1"}

    assert to_string(q) ==
             "test_col?c:lang=en&c:limit=12&c:join=test_col_join%5Ehide:some_other_field'another_field%5Einject_at:name%5Eshow:some_field&c:tree=field:some_field%5Elist:1&c:sort=key:1"
  end

  describe "API" do
    test "can retrieve a character list from a name" do
      q =
        Query.new()
        |> collection("character_name")
        |> term("name.first_lower", "snowful")
        |> show("character_id")

      assert PS2.API.query(q) ===
               {:ok,
                %QueryResult{
                  data: [%{"character_id" => "5428713425545165425"}],
                  returned: 1
                }}
    end

    test "can retrieve one character from a name" do
      q =
        Query.new()
        |> collection("character_name")
        |> term("name.first_lower", "snowful")
        |> show("character_id")

      assert PS2.API.query_one(q) ===
               {:ok,
                %QueryResult{
                  data: %{"character_id" => "5428713425545165425"},
                  returned: 1
                }}
    end

    test "can retrieve collection list" do
      {:ok, res} = PS2.API.get_collections()
      assert res.returned === 111
      assert length(res.data) === 111
    end

    test "query with bad collection returns a PS2.API.Error with message \"No data found.\"" do
      q = Query.new() |> collection("does_not_exist")

      assert PS2.API.query(q) ==
               {:error,
                %PS2.API.Error{
                  message: "No data found.",
                  query: %PS2.API.Query{
                    collection: "does_not_exist",
                    joins: [],
                    params: %{},
                    sort: nil,
                    tree: nil
                  }
                }}
    end

    test "query with bad param value returns a PS2.API.Error with message an INVALID_SEARCH_TERM message." do
      q =
        Query.new()
        |> collection("character_name")
        |> term("name.first_lower", "snowful")
        |> exact_match_first("invalid_value")

      assert PS2.API.query(q) ==
               {:error,
                %PS2.API.Error{
                  message: @invalid_search_term_message,
                  query: %PS2.API.Query{
                    collection: "character_name",
                    joins: [],
                    params: %{
                      "c:exactMatchFirst" => "invalid_value",
                      "name.first_lower" => {"", "snowful"}
                    },
                    sort: nil,
                    tree: nil
                  }
                }}
    end
  end
end
