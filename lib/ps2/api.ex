defmodule PS2.API do
	@moduledoc """
	Your gateway to the Census API.

	Pass you queries to `send_query/1` and get `{:ok, result}`, where
	`result` is a map.

		iex> q = PS2.API.Query.new(collection: "character_name")
		...> |> PS2.API.QueryBuilder.term("name.first_lower", "snowful")
		%PS2.API.Query{
		  collection: "character_name",
			joins: [],
			params: %{"name.first_lower" => {"", "snowful"}},
		  sort: nil,
		  tree: nil
		}
		iex> PS2.API.send_query(q)
		{:ok,
		  %{
		    "character_name_list" => [
		      %{
		        "character_id" => "5428713425545165425",
		        "name" => %{"first" => "Snowful", "first_lower" => "snowful"}
		      }
		    ],
	      "returned" => 1
      }}
	"""

	alias PS2.API.{Query, Join, Tree}

	@type result :: map()

	@error_keys ["error", "errorMessage", "errorCode"]

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
		{:ok, decoded_res} <- Jason.decode(res.body),
		{error_map, valid_res} when error_map == %{} <- Map.split(decoded_res, @error_keys) do
			{:ok, valid_res}
		else
			{error_map, _} when is_map(error_map) -> {:error, %PS2.API.Error{message: Enum.map_join(error_map, " ", fn {_, val} -> "#{val}" end)}}
			error -> error
		end
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
		{:ok, decoded_res} <- Jason.decode(res.body),
		{error_map, valid_res} when error_map == %{} <- Map.split(decoded_res, @error_keys) do
			{:ok, valid_res}
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
