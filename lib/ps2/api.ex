defmodule PS2.API do
	@moduledoc """
	Your gateway to the Census API.

	Use `query/1` to get data from the Census.

		iex> q = PS2.API.Query.new(collection: "character_name")
		...> |> PS2.API.QueryBuilder.term("name.first_lower", "snowful")
		%PS2.API.Query{
		  collection: "character_name",
			joins: [],
			params: %{"name.first_lower" => {"", "snowful"}},
		  sort: nil,
		  tree: nil
		}
		iex> PS2.API.query(q)
		{:ok,
		  %PS2.API.QueryResult{
		    data: [
		      %{
		        "character_id" => "5428713425545165425",
		        "name" => %{"first" => "Snowful", "first_lower" => "snowful"}
		      }
		    ],
	      returned: 1
      }
		}
	"""

	alias PS2.API.{Query, Join, Tree, QueryResult}

	@error_keys ["error", "errorMessage", "errorCode"]

	defp get(query, opts \\ []) do
		sid = Application.fetch_env!(:planetside_api, :service_id)
		HTTPoison.get("https://census.daybreakgames.com/s:#{sid}/get/ps2:v2/#{query}", opts)
	end

	@doc """
	Sends `query` to the API and returns a list of results if successful.
	"""
	@spec query(Query.t(), Keyword.t()) :: {:ok, QueryResult.t()} | {:error, HTTPoison.Error.t() | Jason.DecodeError.t() | PS2.API.Error.t()}
	def query(%Query{} = query, httpoison_opts \\ []) do

		with {:ok, encoded} <- encode(query),
			{:ok, res} <- get(encoded, httpoison_opts),
			{:ok, decoded_res} <- Jason.decode(res.body),
			res_key = query.collection <> "_list",
			{error_map, %{^res_key => res_list, "returned" => returned}} when error_map == %{} <- Map.split(decoded_res, @error_keys) do
				{:ok, %QueryResult{data: res_list, returned: returned}}
		else
			{error_map, _} when is_map(error_map) -> {:error, %PS2.API.Error{message: Enum.map_join(error_map, " ", fn {_, val} -> "#{val}" end), query: query}}
			error -> error
		end
	end

	@doc """
	Sends `query` to the API and returns the first result if successful.
	"""
	@spec query_one(Query.t(), Keyword.t()) :: {:ok, QueryResult.t()} | {:error, HTTPoison.Error.t() | Jason.DecodeError.t() | PS2.API.Error.t()}
	def query_one(%Query{} = query, httpoison_opts \\ []) do
		with {:ok, %QueryResult{} = res} <- query(query, httpoison_opts) do
			{:ok, %{res | data: List.first(res.data)}}
		end
	end

	@doc """
	View a list of all the public API collections and their resolves.
	"""
	@spec get_collections() :: {:ok, QueryResult.t()} | {:error, HTTPoison.Error.t() | Jason.DecodeError.t() | PS2.API.Error.t()}
	def get_collections() do
		with {:ok, res} <- get(""),
		{:ok, decoded_res} <- Jason.decode(res.body),
		{error_map, %{"datatype_list" => res_list, "returned" => returned}} when error_map == %{} <- Map.split(decoded_res, @error_keys) do
			{:ok, %QueryResult{data: res_list, returned: returned}}
		else
			{error_map, _} when is_map(error_map) -> {:error, %PS2.API.Error{message: Enum.map_join(error_map, " ", fn {_, val} -> "#{val}" end)}}
			error -> error
		end
	end

	@doc """
	Gets the image link.
	"""
	@spec get_image_url(String.t()) :: String.t()
	def get_image_url(image_path) do
		"https://census.daybreakgames.com#{image_path}"
	end

	@doc """
	Gets the image binary for a .png.
	"""
	@spec get_image(String.t()) :: {:ok, binary()} | {:error, HTTPoison.Error.t()}
	def get_image(image_path) do
		with {:ok, res} <- HTTPoison.get("https://census.daybreakgames.com#{image_path}"), do: {:ok, res.body}
	end

	@doc """
	Encodes a Query struct into an API-ready string.
	"""
	@spec encode(Query.t()) :: {:ok, String.t()} | {:error, Query.Error.t()}
	def encode(%Query{collection: nil} = _q), do: {:error, %Query.Error{message: "Collection field must be specified to be a valid query."}}
	def encode(%Query{} = q) do
		{:ok,
			"#{q.collection}?"
			<> encode_params(q.params)
			<> (length(q.joins) > 0 && ("&c:join=" <> Enum.map_join(q.joins, ",", &encode_join/1)) || "")
			<> (not is_nil(q.tree) && "&c:tree=#{encode_tree(q.tree)}" || "")
			<> (not is_nil(q.sort) && "&c:sort=#{encode_sort(q.sort)}" || "")
			|> URI.encode()
		}
	end

	defp encode_join(%Join{collection: col} = join) when not is_nil(col) do
		"#{col}#{map_size(join.params) > 0 && "^" || ""}"
		<> Enum.map_join(join.params, "^", fn
				{:terms, terms} when map_size(terms) > 0 -> "terms:#{encode_terms(terms)}"
				{key, val} when not is_nil(val) -> "#{key}:#{encode_param_values(val, "'")}"
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

	defp encode_params(values, separator \\ "&") do
		Enum.map_join(values, separator, fn
			{key, {modifier, val_list}} when is_list(val_list) -> Enum.map_join(val_list, "&", &("#{key}=#{modifier}#{&1}"))
			{key, {modifier, val}} when not is_nil(val) -> "#{key}=#{modifier}#{encode_param_values(val)}"
			{key, val} when not is_nil(val) -> "#{key}=#{encode_param_values(val)}"
		end)
	end

	defp encode_terms(terms) when is_map(terms), do:
		Enum.map_join(terms, "'", fn
			{key, {modifier, val_list}} when not is_nil(val_list) and is_list(val_list) -> Enum.map_join(val_list, "'", &("#{key}=#{modifier}#{&1}"))
			{key, {modifier, val}} when not is_nil(val) -> "#{key}=#{modifier}#{val}"
		end)

	defp encode_param_values(values, separator \\ ",")
	defp encode_param_values(values, separator) when is_list(values), do: Enum.join(values, separator)
	defp encode_param_values(value, _separator) when is_bitstring(value) or is_boolean(value) or is_integer(value), do: value
end
