defmodule PS2.API.Query do
	alias PS2.API.Query

	defstruct collection: nil, terms: %{}, joins: %{}

	@spec new() :: %Query{}
	def new(), do: %Query{}

	@spec collection(%Query{}, String.t()) :: %Query{}
	def collection(%Query{} = q, collection_name) do
		%Query{q | collection: collection_name}
	end

	@doc """
	Adds a c:show term. Overwrites previous terms of the same name.
	### API Documentation:
	Only include the provided fields from the object within the result.
	"""
	@spec show(%Query{}, integer()) :: %Query{}
	def show(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:show", value)}

	@doc """
	Adds a c:hide term. Overwrites previous terms of the same name.
	### API Documentation:
	Include all field except the provided fields from the object within the result.
	"""
	@spec hide(%Query{}, integer()) :: %Query{}
	def hide(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:hide", value)}

	@doc """
	Adds a c:sort term. Overwrites previous terms of the same name.
	### API Documentation:
	Sort the results by the field(s) provided.
	"""
	@spec sort(%Query{}, integer()) :: %Query{}
	def sort(%Query{} = q, _value), do:
		q

	@doc """
	Adds a c:has term. Overwrites previous terms of the same name.
	### API Documentation:
	Include objects where the specified field exists, regardless
	of the value within that field.
	"""
	@spec has(%Query{}, integer()) :: %Query{}
	def has(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:has", value)}

	@doc """
	Adds a c:resolve term. Overwrites previous terms of the same name.
	**Note** that `join/3` is recommended over resolve, as resolve relies
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
	def resolve(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:resolve", value)}

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
		%Query{q | joins: Map.put(q.joins, collection, join_terms)}

	@doc """
	Adds a c:tree term
	### API Documentaion:
	Useful for rearranging lists of data into trees of data. See below for details.
	"""
	@spec tree(%Query{}, String.t(), map()) :: %Query{}
	def tree(%Query{} = q, _collection, %{} = _tree_terms), do:
		q

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

	"""
	@spec distinct(%Query{}, boolean()) :: %Query{}
	def distinct(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:distinct", value)}

	@doc """
	Adds a c:retry term. Overwrites previous terms of the same name.
	### API Documentation:

	"""
	@spec retry(%Query{}, boolean()) :: %Query{}
	def retry(%Query{} = q, value), do:
		%Query{q | terms: Map.put(q.terms, "c:retry", value)}

	@doc """
	Explicitly specify your `term` with this function.
	"""
	@spec add_raw_term(%Query{}, String.t(), String.t()) :: %Query{}
	def add_raw_term(%Query{} = q, term, value) do
		%Query{q | terms: Map.put(q.terms, term, value)}
	end

	@doc """
	Encodes a Query struct into an API-ready string
	"""
	@spec encode(%Query{}) :: String.t()
	def encode(%Query{} = q) do
		"#{q.collection}?" <> URI.encode_query(q.terms) <> Enum.map_join(q.joins, fn {collection, terms} -> "&c:join=#{collection}^" <> Enum.map_join(terms, "^", fn {term, val} -> "#{term}:#{val}" end) end)
	end

	defimpl String.Chars, for: PS2.API.Query do
		def to_string(q), do: Query.encode(q)
	end
end
