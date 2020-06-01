defmodule PS2.API do
	@moduledoc """
	Your gateway to the Census API.

	Pass you queries to `send_query/1` and get `{:ok, result}`, where
	`result` is a map.

		iex> q = PS2.API.Query.new(collection: "character_name")
		%PS2.API.Query{
		  collection: "character_name",
		  joins: [],
		  sort: nil,
		  terms: %{},
		  tree: nil
		}
		iex> PS2.API.send_query(q)
		{:ok,
		  %{
		    character_name_list: [
		      %{
		        character_id: "5428407427900254785",
		        name: %{first: "B3ASTSALVA23", first_lower: "b3astsalva23"}
		      }
		    ],
	      returned: 1
      }}
	"""

	alias PS2.API.{Query, Join, Tree}

	@type result :: %{}

	defp get(query) do
		sid = Application.fetch_env!(:planetside_api, :service_id)
		HTTPoison.get("https://census.daybreakgames.com/s:#{sid}/get/ps2:v2/#{query}")
	end

	@doc """
	Sends `query` to the API, encoding it if necessary. Returns `{:ok, result}` if successful, where `result` is a map.
	"""
	@spec send_query(Query.t() | String.t()) :: {:ok, result} | {:error, HTTPoison.Error.t() | Jason.DecodeError.t() | PS2.API.Error.t()}
	def send_query(query) when is_bitstring(query) do

		with {:ok, res} <- get(query),
		{:ok, %{:error => m}} <- Jason.decode(res.body, keys: :atoms), do:
		{:error, %PS2.API.Error{message: m}}
	end
	def send_query(%Query{} = q) do
		with {:ok, encoded} <- encode(q),
		do: send_query(encoded)
	end

	@doc """
	View a list of all the public API collections and their resolves.
	"""
	@spec get_collections() :: {:ok, result} | {:error, HTTPoison.Error.t() | Jason.DecodeError.t() | PS2.API.Error.t()}
	def get_collections do
		with {:ok, res} <- get(""),
		{:ok, %{:error => m}} <- Jason.decode(res.body, keys: :atoms), do:
		{:error, %PS2.API.Error{message: m}}
	end

	@doc """
	Encodes a Query struct into an API-ready string.
	"""
	@spec encode(Query.t()) :: {:ok, String.t()} | {:error, Query.Error.t()}
	def encode(%Query{collection: nil} = _q), do: {:error, %Query.Error{message: "Collection field must be specified to be a valid query."}}
	def encode(%Query{} = q) do
		{:ok,
			"#{q.collection}?"
			<> encode_terms(q.terms)
			<> (length(q.joins) > 0 && ("&c:join=" <> Enum.map_join(q.joins, ",", &encode_join/1)) || "")
			<> (not is_nil(q.tree) && "&c:tree=#{encode_tree(q.tree)}" || "")
			<> (not is_nil(q.sort) && "&c:sort=#{encode_sort(q.sort)}" || "")
		}
	end

	defp encode_join(%Join{collection: col} = join) when not is_nil(col) do
		"#{col}#{map_size(join.terms) > 0 && "^" || ""}"
		<> Enum.map_join(join.terms, "^", fn
				{:terms, terms} when map_size(terms) > 0 -> "terms:#{encode_terms(terms, "'")}"
				{key, val} when not is_nil(val) -> "#{key}:#{encode_term_values(val)}"
			end)
		<> (length(join.joins) > 0 && "(#{Enum.map_join(join.joins, ",", &encode_join/1)})" || "")
	end

	defp encode_tree(%Tree{terms: %{field: field}} = tree) when not is_nil(field) do
		Enum.map_join(tree.terms, "^", fn {key, val} when not is_nil(val) -> "#{key}:#{val}" end)
	end

	defp encode_sort(terms) when is_list(terms) or is_map(terms) do
		if Keyword.keyword?(terms) or is_map(terms) do
			Enum.map_join(terms, ",", fn
				{key, nil} -> "#{key}"
				{key, val} -> "#{key}:#{val}"
			end)
		else
			Enum.join(terms, ",")
		end
	end

	defp encode_terms(values, separator \\ "&") do
		Enum.map_join(values, separator, fn
			{key, {modifier, val}} when not is_nil(val) -> "#{key}=#{modifier}#{encode_term_values(val)}"
			{key, val} when not is_nil(val) -> "#{key}=#{encode_term_values(val)}"
		end)
	end

	defp encode_term_values(values) when is_list(values), do: Enum.join(values, "'")
	defp encode_term_values(value) when is_bitstring(value) or is_boolean(value) or is_integer(value), do: value
end
