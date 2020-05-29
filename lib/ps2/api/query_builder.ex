defmodule PS2.API.QueryBuilder do
	@moduledoc """
	A module for creating Census API queries in a clean manner via pipelines.

	## Example
		iex> import PS2.API.QueryBuilder
		PS2.API.QueryBuilder
		iex> alias PS2.API.Query
		PS2.API.Query
		iex> q = Query.new(collection: "character")
		...> |> term("character_id", "5428011263335537297")
		...> |> show(["character_id", "name.en", "faction_id"])
		...> |> limit(3)
		...> |> exact_match_first(true)
		%PS2.API.Query{
			collection: "character",
			joins: [],
			sort: nil,
			terms: %{
				"c:exactMatchFirst" => true,
				"c:limit" => 3,
				"c:show" => "character_id,name.en,faction_id",
				"character_id" => {"", "5428011263335537297"}
			},
			tree: nil
		}
		iex> PS2.API.encode q
		{:ok, "character?c:exactMatchFirst=true&c:limit=3&c:show=character_id,name.en,faction_id&character_id=5428011263335537297"}

	You can then send the query to the api using `PS2.API.send_query/1`.

	## Joining Queries

	You can use `Join`s to gather data from multiple collections within one query,
	like so:

	```elixir
	import PS2.API.QueryBuilder
	alias PS2.API.{Query, Join}

	online_status_join =
		%Join{} # Note you could also Join.new(collection: "characters_online_status", show: "online_status" ...)
		|> collection("characters_online_status")
		|> show("online_status")
		|> inject_at("online_status")
		|> list(true)
	q =
		%Query{}
		|> collection("character")
		|> join(online_status_join)
	```
	When the query `q` is sent to the API, the result with have an extra field,
	"online_status", which contains the result of the `Join` (in this case, the
	player's online	status.)

	You can create as many `Join`s as you like with `QueryBuilder.join/2`. However,
	you can also nest `Join`s

	```elixir
	import PS2.API.QueryBuilder
	alias PS2.API.{Query, Join}

	char_achieve_join =
		Join.new(collection: "characters_achievement", on: "character_id")

	char_name_join =
		Join.new(collection: "character_name", on: "character_id", inject_at: "c_name")
		|> join_adjacent(char_achieve_join)

	online_status_join =
		Join.new(collection: "characters_online_status")
		|> join_nested(char_name_join)

	q =
		%Query{}
		|> collection("character")
		|> term("name.first", "Snowful")
		|> show(["character_id", "faction_id"])
		|> join(online_status_join)
	```
	Using `join_adjacent/2` and `join_nested/2`, we can join any collection with common
	fields
	"""

	@modifier_map %{
		greater_than: ">",
		greater_than_or_equal: "]",
		less_than: "<",
		less_than_or_equal: "[",
		starts_with: "^",
		contains: "*",
		not: "!"
	}

	@type modifer ::
		:greater_than
		| :greater_than_or_equal
		| :less_than
		| :less_than_or_equal
		| :starts_with
		| :contains
		| :not
		| nil

	@type collection_name :: String.t()
	@type field_name :: String.t()

	alias PS2.API.{Query, Join, Tree}

	@spec collection(Query.t(), collection_name) :: %Query{}
	def collection(%Query{} = q, collection_name), do:
		%Query{q | collection: collection_name}

	@spec collection(Join.t(), collection_name) :: %Join{}
	def collection(%Join{} = join, collection), do:
		%Join{join | collection: collection}

	@doc """
	Adds a c:show term. Overwrites previous terms of the same name.
	### API Documentation:
	Only include the provided fields from the object within the result.
	"""
	@spec show(Query.t(), String.t() | list(String.t())) :: Query.t()
	@spec show(Join.t(), String.t() | list(String.t())) :: Join.t()
	def show(t, value)

	def show(%Query{} = q, values) when is_list(values), do: show(q, Enum.join(values, ","))
	def show(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:show", value)}

	def show(%Join{} = join, values) when is_list(values), do: show(join, Enum.join(values, "'"))
	def show(%Join{} = join, value), do:
		%Join{join | terms: Map.put(join.terms, :show, value)}

	@doc """
	Adds a c:hide term. Overwrites previous terms of the same name.
	### API Documentation:
	Include all field except the provided fields from the object within the result.
	"""
	@spec hide(Query.t(), String.t() | list(String.t())) :: %Query{}
	def hide(%Query{} = q, values) when is_list(values), do: hide(q, Enum.join(values, ","))
	def hide(%Query{} = q, value), do: %Query{q | terms: Map.put(q.terms, "c:hide", value)}

	@spec hide(Join.t(), String.t() | list(String.t())) :: %Join{}
	def hide(%Join{} = join, values) when is_list(values), do: hide(join, Enum.join(values, "'"))
	def hide(%Join{} = join, field), do: %Join{join | terms: Map.put(join.terms, :hide, field)}

	@doc """
	Add a term to filter query results. i.e. filter a query by character ID:  `.../character?character_id=1234123412341234123`
	"""
	def term(t, field, value, modifier \\ nil)
	@spec term(Query.t(), String.t() | atom, any, modifer) :: Query.t()
	@spec term(Join.t(), String.t() | atom, any, modifer) :: Join.t()

	def term(%Query{} = q, field, value, modifier), do:
		%Query{q | terms: Map.put(q.terms, field, {Map.get(@modifier_map, modifier, ""), value})}

	def term(%Join{} = join, field, value, modifier), do:
		%Join{join | terms: Map.put(join.terms, field, {Map.get(@modifier_map, modifier, ""), value})}

	@doc """
	Adds a sort term (to a Join or Tree).
	Specifies whether the result should be a list (true) or a single record (false). Defaults to false.
	"""
	@spec list(Join.t(), boolean()) :: %Join{}
	def list(%Join{} = join, val), do: %Join{join | terms: Map.put(join.terms, :list, PS2.Utils.boolean_to_integer(val))}

	@spec list(Tree.t(), boolean()) :: %Tree{}
	def list(%Tree{} = tree, val), do: %Tree{tree | terms: Map.put(tree.terms, :list, PS2.Utils.boolean_to_integer(val))}

	### Query specific functions

	@doc """
	Adds a c:sort term. Overwrites previous terms of the same name.
	### API Documentation:
	Sort the results by the field(s) provided.
	"""
	@spec sort(Query.t(), Query.sort_terms()) :: %Query{}
	def sort(%Query{} = q, %{} = sort_terms), do:
		%Query{q | sort: sort_terms}

	@doc """
	Adds a c:has term. Overwrites previous terms of the same name.
	### API Documentation:
	Include objects where the specified field exists, regardless
	of the value within that field.
	"""
	@spec has(Query.t(), String.t() | list()) :: %Query{}
	def has(%Query{} = q, values) when is_list(values), do: has(q, Enum.join(values, ","))
	def has(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:has", value)}

	@doc """
	Adds a c:resolve term. Overwrites previous terms of the same name.
	**Note** that `join/3` is recommended over `resolve/2`, as resolve relies
	on supported collections to work.

	### API Documentation:
	"Resolve" information by merging data from another collection and include
	the detailed object information for the provided fields from the object
	within the result (multiple field names separated by a comma).\n
	*Please note that the resolve will only function if the initial query contains
	the field to be resolved on. For instance, resolving leader on outfit requires
	that leader_character_id be in the initial query.
	"""
	@spec resolve(Query.t(), String.t()) :: %Query{}
	def resolve(%Query{} = q, collection), do:
		%Query{q | terms: Map.put(q.terms, "c:resolve", collection)}

	@doc """
	Adds a c:case (sensitivity) term. Overwrites previous terms of the same name.
	### API Documentation:
	Set whether a search should be case-sensitive, `true` means
	case-sensitive. true is the default. Note that using this command may slow
	down your queries. If a lower case version of a field is available use that
	instead for faster performance.
	"""
	@spec case_sensitive(Query.t(), boolean()) :: %Query{}
	def case_sensitive(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:case", value)}

	@doc """
	Adds a c:limit term. Overwrites previous terms of the same name.
	### API Documentation:
	Limit the results to at most N [`value`] objects.
	"""
	@spec limit(Query.t(), integer()) :: %Query{}
	def limit(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:limit", value)}

	@doc """
	Adds a c:limitPerDB term. Overwrites previous terms of the same name.
	### API Documentation:
	Limit the results to at most (N * number of databases) objects.\n
	*The data type ps2/character is distributed randomly across 20
	databases. Using c:limitPerDb will have more predictable results on
	ps2/character than c:limit will.
	"""
	@spec limit_per_db(Query.t(), integer()) :: %Query{}
	def limit_per_db(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:limitPerDB", value)}

	@doc """
	Adds a c:start term. Overwrites previous terms of the same name.
	### API Documentation:
	Start with the Nth object within the results of the query.\n
	*Please note that c:start will have unusual behavior when
	querying ps2/character which is distributed randomly across
	20 databases.
	"""
	@spec start(Query.t(), integer()) :: %Query{}
	def start(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:start", value)}

	@doc """
	Adds a c:includeNull term. Overwrites previous terms of the same name.
	### API Documentation:
	Include `NULL` values in the result. By default this is false. For
	example, if the `name.fr` field of a vehicle is `NULL` the field `name.fr`
	will not be included in the response by default. Add the
	c:includeNull=true command if you want the value name.fr : `NULL` to be
	returned in the result.
	"""
	@spec include_null(Query.t(), boolean()) :: %Query{}
	def include_null(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:includeNull", value)}

	@doc """
	Adds a c:lang term. Overwrites previous terms of the same name.
	### API Documentation:
	For internationalized strings, remove all translations except the one specified.
	"""
	@spec lang(Query.t(), String.t()) :: %Query{}
	def lang(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:lang", value)}

	@doc """
	Adds an adjacent join to a query. See the "Using c:join to join collections dynamically"
	section at https://census.daybreakgames.com/#query-commands to learn more about the APIs
	c:join parameter.
	### c:join API Documentation:
	Meant to replace c:resolve, useful for dynamically joining (resolving)
	multiple data types in one query.
	"""
	@spec join(Query.t(), %Join{}) :: %Query{}
	def join(%Query{} = q, %Join{} = join), do:
		%Query{q | joins: [join | q.joins]}

	@doc """
	Adds a c:tree term
	### API Documentaion:
	Useful for rearranging lists of data into trees of data. See below for details.
	"""
	@spec tree(Query.t(), %Tree{}) :: %Query{}
	def tree(%Query{} = q, %Tree{} = tree), do:
	%Query{q | tree: tree}

	@doc """
	Adds a c:timing term. Overwrites previous terms of the same name.
	### API Documentation:
	Shows the time taken by the involved server-side queries and resolves.
	"""
	@spec timing(Query.t(), boolean()) :: %Query{}
	def timing(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:timing", value)}

	@doc """
	Adds a c:exactMatchFirst term. Overwrites previous terms of the same name.
	### API Documentation:
	When using a regex search (=^ or =*) c:exactMatchFirst=true will cause
	exact matches of the regex value to appear at the top of the result list
	despite the value of c:sort.
	"""
	@spec exact_match_first(Query.t(), boolean()) :: %Query{}
	def exact_match_first(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:exactMatchFirst", value)}

	@doc """
	Adds a c:distinct term. Overwrites previous terms of the same name.
	### API Documentation:
	Get the distinct values of the given field. For example to get the
	distinct values of ps2.item.max_stack_size use
	`http://census.daybreakgames.com/get/ps2/item?c:distinct=max_stack_size`.
	Results are capped at 20,000 values.
	"""
	@spec distinct(Query.t(), boolean()) :: %Query{}
	def distinct(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:distinct", value)}

	@doc """
	Adds a c:retry term. Overwrites previous terms of the same name.
	### API Documentation:
	If `true`, query will be retried one time. Default value is true.
	If you prefer your query to fail quickly pass c:retry=false.
	"""
	@spec retry(Query.t(), boolean()) :: %Query{}
	def retry(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:retry", value)}

	### Join specific functions

	@doc """
	Adds an `on:` term. `field` is the field on the parent/leading collection to compare with the join's field
	(optionally	specified with the `to/2` function).
	### API Documentation:
	The field on this type to join on, i.e. item_id. Will default to {this_type}_id or {other_type}_id if not provided.
	"""
	@spec on(Join.t(), field_name) :: %Join{}
	def on(%Join{} = join, field), do:
		%Join{join | terms: Map.put(join.terms, :on, field)}

	@doc """
	Adds a `to:` term. `field` is the field on the joined collection to compare with the parent/leading field
	(optionally	specified with the `on/2` function).
	### API Documentation:
	The field on the joined type to join to, i.e. attachment_item_id. Will default to on if on is provide, otherwise
	will default to {this_type}_id or {other_type}_id if not provided.
	"""
	@spec to(Join.t(), field_name) :: %Join{}
	def to(%Join{} = join, field), do:
		%Join{join | terms: Map.put(join.terms, :to, field)}

	@doc """
	Adds an `injected_at:` term. `field` is the name of the new field where the result of the join is inserted.
	### API Documentation:
	The field name where the joined data should be injected into the returned document.
	"""
	@spec inject_at(Join.t(), field_name) :: %Join{}
	def inject_at(%Join{} = join, field), do:
		%Join{join | terms: Map.put(join.terms, :inject_at, field)}

	@doc """
	Adds an `outer:` term. Note: where the API docs specify `1`, `true` should be passed, and `false` in place of `0`.
	### API Documentation:
	1 if you wish to do an outer join (include non-matches), 0 if you wish to do an inner join (exclude non-matches).
	Defaults to 1- do an outer join, include non-matches.
	"""
	@spec outer(Join.t(), boolean()) :: %Join{}
	def outer(%Join{} = join, val), do:
		%Join{join | terms: Map.put(join.terms, :outer, val)}

	@doc """
	Add an adjacent join.
	"""
	@spec join_adjacent(Join.t(), Join.t()) :: %Join{}
	def join_adjacent(%Join{} = join, %Join{} = new_join), do:
		%Join{join | adjacent_joins: [new_join | join.adjacent_joins]}

	@doc """
	Add a nested join.
	"""
	@spec join_nested(Join.t(), Join.t()) :: %Join{}
	def join_nested(%Join{} = join, %Join{} = new_join), do:
		%Join{join | nested_joins: [new_join | join.nested_joins]}

	### Tree specific functions

	@doc """
	Adds a `start:` term.
	### API Documentaion:
	Used to tell the tree where to start. By default, the list of objects at the root will be formatted as a tree.
	"""
	@spec start_field(Tree.t(), field_name()) :: %Tree{}
	def start_field(%Tree{} = tree, field), do: %Tree{tree | terms: Map.put(tree.terms, :start, field)}

	@doc """
	Add a `field:` term.
	### API Documentation:
	The field to remove and use as in the data structure, or tree.
	"""
	@spec field(Tree.t(), field_name()) :: %Tree{}
	def field(%Tree{} = tree, field), do: %Tree{tree | terms: Map.put(tree.terms, :field, field)}

	@doc """
	Add a `prefix:` term.
	### API Documentation:
	A prefix to add to the field value to make it more readable. For example, if the field is "faction_id" and prefix
	is "f_", path will be f_1, f_2, f_3 etc.
	"""
	@spec prefix(Tree.t(), String.t()) :: %Tree{}
	def prefix(%Tree{} = tree, prefix), do: %Tree{tree | terms: Map.put(tree.terms, :prefix, prefix)}
end
