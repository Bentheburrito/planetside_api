defmodule PS2.APITest do
  use ExUnit.Case, async: true
	doctest PS2.API
	alias PS2.API.Query

	test "Retrieve a character name" do
		q = Query.new |> Query.collection("character_name") |> Query.term("name.first_lower", "snowful") |> Query.show("character_id")
		assert PS2.API.query(q) == {:ok, %{"returned" => 1, "character_name_list" => [%{"character_id" => "5428713425545165425"}]}}
	end

	test "PS2.API.Error returned from bad collection with \"No data found.\" error message" do
		q = Query.new |> Query.collection("does_not_exist")
		assert PS2.API.query(q) == {:error, %PS2.API.Error{message: "No data found."}}
	end
end
