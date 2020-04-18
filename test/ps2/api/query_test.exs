defmodule PS2.API.QueryTest do
  use ExUnit.Case
	doctest PS2.API.Query
	alias PS2.API.Query

	setup do
		q = Query.new()
			|> Query.collection("test_col")
			|> Query.limit(12)
			|> Query.lang("en")
			|> Query.join("test_col_joinable", %{"Key" => "Value"})
			|> Query.sort(%{"Key" => "Value1'Value2"})
			|> Query.tree(%{"Key" => ["Value1", "Value2"]})
		%{test_q: q}
	end

	test "Ensure proper query construction", %{test_q: test_q} do
		q = Query.new()
		assert q == %Query{}

		assert test_q == %Query{
			collection: "test_col",
			terms: %{"c:limit" => 12, "c:lang" => "en"},
			subqueries: [{:join, "test_col_joinable", %{"Key" => "Value"}}, {:sort, %{"Key" => "Value1'Value2"}}, {:tree, %{"Key" => ["Value1", "Value2"]}}]
		}
	end

	test "Ensure proper query encoding", %{test_q: test_q} do
		assert Query.encode(test_q) == {:ok, "test_col?c%3Alang=en&c%3Alimit=12&c:join=test_col_joinable^Key:Value&c:sort=Key:Value1'Value2&c:tree=Key:Value1'Value2"}
		assert to_string(test_q) == "test_col?c%3Alang=en&c%3Alimit=12&c:join=test_col_joinable^Key:Value&c:sort=Key:Value1'Value2&c:tree=Key:Value1'Value2"
	end
end
