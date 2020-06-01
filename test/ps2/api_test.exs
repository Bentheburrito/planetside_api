defmodule PS2.APITest do
  use ExUnit.Case, async: true
  doctest PS2.API

  import PS2.API.QueryBuilder
  alias PS2.API.{Query, Join, Tree}

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
              "test_col?c:lang=en&c:limit=12&c:join=test_col_join^hide:some_other_field'another_field^inject_at:name^show:some_field&c:tree=field:some_field^list:1&c:sort=key:1"}

    assert to_string(q) ==
             "test_col?c:lang=en&c:limit=12&c:join=test_col_join^hide:some_other_field'another_field^inject_at:name^show:some_field&c:tree=field:some_field^list:1&c:sort=key:1"
  end

  describe "API" do
    test "can retrieve a character name" do
      q =
        Query.new()
        |> collection("character_name")
        |> term("name.first_lower", "snowful")
        |> show("character_id")

      assert PS2.API.send_query(q) ===
               {:ok,
                %{
                  :returned => 1,
                  :character_name_list => [%{:character_id => "5428713425545165425"}]
                }}
    end

    test "can retrieve collection list" do
      {:ok, res} = PS2.API.get_collections()
      assert res[:returned] === 111
      assert Map.has_key?(res, :datatype_list)
    end

    test "query with bad collection returns a PS2.API.Error with message \"No data found.\"" do
      q = Query.new() |> collection("does_not_exist")
      assert PS2.API.send_query(q) == {:error, %PS2.API.Error{message: "No data found."}}
    end
  end
end
