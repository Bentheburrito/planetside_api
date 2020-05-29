defmodule PS2.API.QueryBuilderTest do
  use ExUnit.Case, async: true
	doctest PS2.API.QueryBuilder

	import PS2.API.QueryBuilder
	alias PS2.API.{Query, Join, Tree}

	describe "QueryBuilder" do
		test "can create a query struct with terms" do
			q =
				Query.new(collection: "character")
				|> show(["character_id", "name"])
				|> term("character_id", "5428713425545165425")
			assert q ===
				%PS2.API.Query{
					collection: "character",
					joins: [],
					sort: nil,
					terms: %{
						"c:show" => "character_id,name",
						"character_id" => {"", "5428713425545165425"}
					},
					tree: nil
				}
		end

		test "functions can overwrite terms" do
			q = Query.new(collection: "col_1") |> collection("col_2")
			assert q.collection === "col_2"

			q = q
				|> term("field_1", "val", :greater_than)
				|> collection("col_3")
				|> term("field_1", "val2", :less_than)
			assert q.collection === "col_3"
			assert Map.get(q.terms, "field_1") === {"<", "val2"}
		end

		test "can create a join struct with terms" do
			join =
				Join.new(collection: "characters_online_status", on: "character_id")
				|> show(["character_id", "name"])
				|> term("character_id", "5428713425545165425")
			assert join ===
				%PS2.API.Join{
					adjacent_joins: [],
					collection: "characters_online_status",
					nested_joins: [],
					terms: %{
						:on => "character_id",
						:show => "character_id'name",
						"character_id" => {"", "5428713425545165425"}
					}
				}
		end

		test "can create a tree struct with terms" do
			tree =
				Tree.new(start: "character_list")
				|> list(true)
				|> field("faction_id")
			assert tree ===
				%PS2.API.Tree{terms: %{field: "faction_id", list: 1, start: "character_list"}}
		end

		test "can create queries with joins, trees, and sorts" do
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
					|> list(true))
					|> sort(%{"key" => "1"}
				)
			assert q ===
				%PS2.API.Query{
					collection: "test_col",
					joins: [
						%PS2.API.Join{
							adjacent_joins: [],
							collection: "test_col_join",
							nested_joins: [],
							terms: %{
								hide: "some_other_field'another_field",
								inject_at: "name",
								show: "some_field"
							}
						}
					],
					sort: %{"key" => "1"},
					terms: %{"c:lang" => "en", "c:limit" => 12},
					tree: %PS2.API.Tree{terms: %{field: "some_field", list: 1}}
				}
		end
		#https://census.daybreakgames.com/s:ps2statusbot/get/ps2:v2/
		#character?name.first=Snowful&c:show=character_id,faction_id
		#&c:join=characters_online_status(character_name^on:character_id^to:character_id,characters_achievement^on:character_id^to:character_id),characters_stat_by_faction
		test "can create adjacent and nested joins" do
			q =
				%Query{}
				|> collection("character")
				|> term("name.first", "Snowful")
				|> show(["character_id", "faction_id"])
				|> join(
					Join.new(collection: "characters_online_status")
					|> join_nested(
						Join.new(collection: "character_name", on: "character_id", to: "character_id")
						|> inject_at("c_name")
						|> join_adjacent(
							Join.new(collection: "characters_achievement", on: "character_id", to: "character_id")
						)
					)
				)
				|> join(
					Join.new(collection: "characters_stat_by_faction")
				)
			assert q === %PS2.API.Query{
				collection: "character",
				joins: [
					%PS2.API.Join{
						adjacent_joins: [],
						collection: "characters_stat_by_faction",
						nested_joins: [],
						terms: %{}
					},
					%PS2.API.Join{
						adjacent_joins: [],
						collection: "characters_online_status",
						nested_joins: [
							%PS2.API.Join{
								adjacent_joins: [
									%PS2.API.Join{
										adjacent_joins: [],
										collection: "characters_achievement",
										nested_joins: [],
										terms: %{on: "character_id", to: "character_id"}
									}
								],
								collection: "character_name",
								nested_joins: [],
								terms: %{on: "character_id", to: "character_id", inject_at: "c_name"}
							}
						],
						terms: %{}
					}
				],
				sort: nil,
				terms: %{
					"c:show" => "character_id,faction_id",
					"name.first" => {"", "Snowful"}
				},
				tree: nil
			}

			q2 =
				Query.new(collection: "character_name")
				|> join(
					Join.new(collection: "character")
					|> join_nested(
						Join.new(collection: "faction")
					)
					|> join_adjacent(
						Join.new(collection: "characters_online_status", on: "character_id") |> list(true)
					)
				)
			assert q2 === %PS2.API.Query{
				collection: "character_name",
				joins: [
					%PS2.API.Join{
						adjacent_joins: [
							%PS2.API.Join{
								adjacent_joins: [],
								collection: "characters_online_status",
								nested_joins: [],
								terms: %{list: 1, on: "character_id"}
							}
						],
						collection: "character",
						nested_joins: [
							%PS2.API.Join{
								adjacent_joins: [],
								collection: "faction",
								nested_joins: [],
								terms: %{}
							}
						],
						terms: %{}
					}
				],
				sort: nil,
				terms: %{},
				tree: nil
			}
		end
	end
end
