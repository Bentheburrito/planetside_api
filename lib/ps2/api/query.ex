defmodule PS2.API.Query do
	@moduledoc """
	A module for creating customizable Census API queries.

	## Examples
		iex> import PS2.API.Query
		PS2.API.Query
		iex> q = new(collection: "character")
		...> |> term("character_id", "5428011263335537297")
		...> |> show(["character_id", "name.en", "faction_id"])
		...> |> limit(3)
		...> |> exact_match_first(true)
		%PS2.API.Query{
			collection: "character",
			subqueries: [],
			terms: %{
				"c:exactMatchFirst" => true,
				"c:limit" => 3,
				"c:show" => "character_id,name.en,faction_id",
				"character_id" => "5428011263335537297"
			}
		}
		iex> encode q
		{:ok, "character?c%3AexactMatchFirst=true&c%3Alimit=3&c%3Ashow=character_id%2Cname.en%2Cfaction_id&character_id=5428011263335537297"}
	"""

	alias PS2.API.Query
	defstruct collection: nil, terms: %{}, subqueries: []

	@spec new([]) :: %Query{}
	def new(), do: %Query{}
	def new(collection: col) do
		%Query{collection: col}
	end
	def new(_), do: %Query{}

	@spec collection(%Query{}, String.t()) :: %Query{}
	def collection(%Query{} = q, collection_name), do:
		%Query{q | collection: collection_name}

	@doc """
	Adds a c:show term. Overwrites previous terms of the same name.
	### API Documentation:
	Only include the provided fields from the object within the result.
	"""
	@spec show(%Query{}, String.t() | list(String.t())) :: %Query{}
	def show(%Query{} = q, values) when is_list(values), do: show(q, Enum.join(values, ","))
	def show(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:show", value)}

	@doc """
	Adds a c:hide term. Overwrites previous terms of the same name.
	### API Documentation:
	Include all field except the provided fields from the object within the result.
	"""
	@spec hide(%Query{}, String.t() | list(String.t())) :: %Query{}
	def hide(%Query{} = q, values) when is_list(values), do: hide(q, Enum.join(values, ","))
	def hide(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:hide", value)}

	@doc """
	Adds a c:sort term. Overwrites previous terms of the same name.
	### API Documentation:
	Sort the results by the field(s) provided.
	"""
	@spec sort(%Query{}, map()) :: %Query{}
	def sort(%Query{} = q, %{} = sort_terms), do:
		%Query{q | subqueries: q.subqueries ++ [{:sort, sort_terms}]}

	@doc """
	Adds a c:has term. Overwrites previous terms of the same name.
	### API Documentation:
	Include objects where the specified field exists, regardless
	of the value within that field.
	"""
	@spec has(%Query{}, String.t() | list()) :: %Query{}
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
	@spec resolve(%Query{}, String.t()) :: %Query{}
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
	@spec case_sense(%Query{}, boolean()) :: %Query{}
	def case_sense(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:case", value)}

	@doc """
	Adds a c:limit term. Overwrites previous terms of the same name.
	### API Documentation:
	Limit the results to at most N [`value`] objects.
	"""
	@spec limit(%Query{}, integer()) :: %Query{}
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
	@spec limit_per_db(%Query{}, integer()) :: %Query{}
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
	@spec start(%Query{}, integer()) :: %Query{}
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
	@spec include_null(%Query{}, boolean()) :: %Query{}
	def include_null(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:includeNull", value)}

	@doc """
	Adds a c:lang term. Overwrites previous terms of the same name.
	### API Documentation:
	For internationalized strings, remove all translations except the one specified.
	"""
	@spec lang(%Query{}, String.t()) :: %Query{}
	def lang(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:lang", value)}

	@doc """
	Adds a c:join term
	### API Documentation:
	Meant to replace c:resolve, useful for dynamically joining (resolving)
	multiple data types in one query. See below for details.
	"""
	@spec join(%Query{}, String.t(), map()) :: %Query{}
	def join(%Query{} = q, collection, %{} = join_terms), do:
		%Query{q | subqueries: q.subqueries ++ [{:join, collection, join_terms}]}

	@doc """
	Adds a c:tree term
	### API Documentaion:
	Useful for rearranging lists of data into trees of data. See below for details.
	"""
	@spec tree(%Query{}, map()) :: %Query{}
	def tree(%Query{} = q, %{} = tree_terms), do:
	%Query{q | subqueries: q.subqueries ++ [{:tree, tree_terms}]}

	@doc """
	Adds a c:timing term. Overwrites previous terms of the same name.
	### API Documentation:
	Shows the time taken by the involved server-side queries and resolves.
	"""
	@spec timing(%Query{}, boolean()) :: %Query{}
	def timing(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:timing", value)}

	@doc """
	Adds a c:exactMatchFirst term. Overwrites previous terms of the same name.
	### API Documentation:
	When using a regex search (=^ or =*) c:exactMatchFirst=true will cause
	exact matches of the regex value to appear at the top of the result list
	despite the value of c:sort.
	"""
	@spec exact_match_first(%Query{}, boolean()) :: %Query{}
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
	@spec distinct(%Query{}, boolean()) :: %Query{}
	def distinct(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:distinct", value)}

	@doc """
	Adds a c:retry term. Overwrites previous terms of the same name.
	### API Documentation:
	If `true`, query will be retried one time. Default value is true.
	If you prefer your query to fail quickly pass c:retry=false.
	"""
	@spec retry(%Query{}, boolean()) :: %Query{}
	def retry(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:retry", value)}

	@doc """
	Add a `term`=`value` to filter by on the collection. i.e. /character?character_id=1234123412341234123
	"""
	@spec term(%Query{}, String.t(), String.t()) :: %Query{}
	def term(%Query{collection: col}, term, _value) when term == "type" and col != "world_event", do:
		{:error, "`type` term only available on the `world_event` collection"}
	def term(%Query{} = q, term, value), do:
		%Query{q | terms: Map.put(q.terms, term, value)}

	@doc """
	Encodes a Query struct into an API-ready string
	"""
	@spec encode(%Query{}) :: {:ok, String.t()}
	def encode(%Query{collection: nil} = _q), do: {:error, %PS2.API.Error{message: "Collection field must be specified to be a valid query."}}
	def encode(%Query{} = q) do
		{:ok,
			"#{q.collection}?"
			<> URI.encode_query(q.terms)
			<> Enum.map_join(q.subqueries,
				&(case &1 do
					{:join, collection, terms} -> "&c:join=#{collection}^" <> Enum.map_join(terms, "^", fn {term, val} -> "#{term}:#{encode_term_values(val)}" end)
					{:tree, terms} -> "&c:tree=" <> Enum.map_join(terms, "^", fn {term, val} -> "#{term}:#{encode_term_values(val)}" end)
					{:sort, terms} -> "&c:sort=" <> Enum.map_join(terms, ",", fn {term, val} -> "#{term}:#{encode_term_values(val)}" end)
				end))
		}
	end

	defp encode_term_values(values) when is_list(values), do: Enum.join(values, "'")
	defp encode_term_values(value) when is_bitstring(value), do: value

	defimpl String.Chars, for: PS2.API.Query do
		def to_string(q) do
			{_, q_str} = Query.encode(q)
			q_str
		end
	end
end
