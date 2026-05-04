defmodule PS2.API do
  @moduledoc """
  Functions for querying the Census API.

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
  	iex> PS2.API.query(q, "example")
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

  alias PS2.API.Query
  alias PS2.API.QueryResult

  @error_keys ~w|error errorMessage errorCode|

  def census_endpoint(sid \\ "example"), do: "https://census.daybreakgames.com/s:#{sid}/get/ps2:v2"

  @doc """
  Sends `query` to the Census API, returning {:ok, %QueryResult{}} struct on
  success. `req_opts` is a keyword list of `Req` opts.
  """
  @spec query(Query.t(), String.t(), Keyword.t(), (service_id :: String.t() -> String.t())) ::
          {:ok, QueryResult.t()} | {:error, PS2.API.Error.t() | Exception.t()}
  def query(%Query{} = query, service_id, req_opts \\ [], endpoint_fxn \\ &census_endpoint/1) do
    query_uri = Query.encode(query)

    uri =
      service_id
      |> endpoint_fxn.()
      |> URI.new!()
      # can't use `URI.merge/2`, because it overrides the path of the first
      # with that of the second, instead of appending to it like a sane person
      # would hope.
      |> URI.append_path(URI.encode(query_uri.path))
      |> URI.append_query(URI.encode(query_uri.query))

    with {:ok, %{body: response}} <- Req.get(uri, req_opts) do
      handle_response(query, response)
    end
  end

  defp handle_response(query, response) do
    error_map = Map.take(response, @error_keys)

    if map_size(error_map) > 0 do
      {:error, %PS2.API.Error{query: query, message: Enum.map_join(error_map, " / ", fn {_, val} -> "#{val}" end)}}
    else
      result_key = query.collection <> "_list"
      %{^result_key => res_list, "returned" => returned} = response
      {:ok, %QueryResult{data: res_list, returned: returned}}
    end
  end

  @doc """
  Sends `query` to the API and returns the first result if successful.
  """
  @spec query_one(Query.t(), String.t(), Keyword.t(), (service_id :: String.t() -> String.t())) ::
          {:ok, QueryResult.t()} | {:error, PS2.API.Error.t() | Exception.t()}
  def query_one(%Query{} = query, service_id, req_opts \\ [], endpoint_fxn \\ &census_endpoint/1) do
    with {:ok, %QueryResult{} = res} <- query(query, service_id, req_opts, endpoint_fxn) do
      {:ok, %{res | data: List.first(res.data)}}
    end
  end

  @doc """
  Gets a list of all the public API collections and their resolves.
  """
  @spec get_collections(String.t()) :: {:ok, QueryResult.t()} | {:error, PS2.API.Error.t() | Exception.t()}
  def get_collections(service_id, req_opts \\ [], endpoint_fxn \\ &census_endpoint/1) do
    with {:ok, %{body: response}} <- Req.get(endpoint_fxn.(service_id), req_opts) do
      handle_response(Query.new(collection: "datatype"), response)
    end
  end

  @doc """
  Gets the URL for an image.
  """
  @spec get_image_url(String.t(), String.t()) :: String.t()
  def get_image_url(image_path, endpoint \\ census_endpoint()) do
    endpoint
    |> URI.new!()
    |> Map.put(:path, nil)
    |> URI.append_path(image_path)
    |> URI.to_string()
  end

  @doc """
  Gets the image binary for a .png.
  """
  @spec get_image(String.t(), String.t()) :: {:ok, binary()} | {:error, Exception.t()}
  def get_image(image_path, endpoint \\ census_endpoint()) do
    with {:ok, res} <- image_path |> get_image_url(endpoint) |> Req.get(), do: {:ok, res.body}
  end
end
