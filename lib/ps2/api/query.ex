defmodule PS2.API.Query do
  @moduledoc """
  A data structure representing an API query. Create a struct using %PS2.API.Query{} or the new/0 or new/1 functions.
  """

  alias PS2.API.Query
  alias PS2.API.Query.Join
  alias PS2.API.Query.Tree

  @enforce_keys [:collection]
  defstruct collection: nil, params: %{}, joins: [], tree: nil, sort: nil

  @type t() :: %Query{
          collection: String.t(),
          params: map(),
          joins: [Join.t()],
          tree: Tree.t() | nil,
          sort: sort_terms() | nil
        }

  @typedoc """
  The key of a term is the field name, and the value is the sort direction. Set the value to `nil` for the default sort direction.
  """
  @type sort_terms() :: map() | Keyword.t()

  @type opts() :: Keyword.t()

  @spec new() :: t()
  @spec new(opts()) :: t()
  def new(opts \\ []), do: struct!(__MODULE__, opts)

  @doc """
  Encodes a Query as a URL, using the given
  """
  @spec encode(__MODULE__.t()) :: URI.t()
  def encode(%__MODULE__{} = query) do
    "/#{query.collection}"
    |> URI.new!()
    |> URI.append_query(encode_params(query.params))
    |> URI.append_query(encode_joins(query.joins))
    |> URI.append_query(encode_tree(query.tree))
    |> URI.append_query(encode_sort(query.sort))
  end

  defp encode_params(values) do
    Enum.map_join(values, "&", fn
      {key, {modifier, val}} when not is_nil(val) ->
        "#{key}=#{modifier}#{encode_param_values(val)}"

      {key, val} when not is_nil(val) ->
        "#{key}=#{encode_param_values(val)}"
    end)
  end

  defp encode_joins([]), do: ""

  defp encode_joins([%Join{} | _] = joins) do
    "c:join=#{Enum.map_join(joins, ",", &encode_join/1)}"
  end

  defp encode_join(%Join{collection: col} = join) when not is_nil(col) do
    "#{col}#{(map_size(join.params) > 0 && "^") || ""}" <>
      Enum.map_join(join.params, "^", fn
        {:terms, terms} when map_size(terms) > 0 -> "terms:#{encode_join_terms(terms)}"
        {key, val} when not is_nil(val) -> "#{key}:#{encode_param_values(val, "'")}"
      end) <>
      ((length(join.joins) > 0 && "(#{Enum.map_join(join.joins, ",", &encode_join/1)})") || "")
  end

  defp encode_tree(nil), do: ""

  defp encode_tree(%Tree{field: field} = tree) when not is_nil(field) do
    terms =
      tree
      |> Map.from_struct()
      |> Stream.reject(fn {_key, val} -> is_nil(val) end)
      |> Enum.map_join("^", fn {key, val} -> "#{key}:#{val}" end)

    "c:tree=#{terms}"
  end

  defp encode_sort(nil), do: ""

  defp encode_sort(terms) when is_list(terms) or is_map(terms) do
    sort_terms =
      if Keyword.keyword?(terms) or is_map(terms) do
        Enum.map_join(terms, ",", fn
          {key, nil} -> "#{key}"
          {key, val} -> "#{key}:#{val}"
        end)
      else
        Enum.join(terms, ",")
      end

    "c:sort=#{sort_terms}"
  end

  defp encode_join_terms(terms) when is_map(terms) do
    Enum.map_join(terms, "'", fn
      {key, {modifier, val_list}} when is_list(val_list) ->
        Enum.map_join(val_list, "'", &"#{key}=#{modifier}#{&1}")

      {key, {modifier, val}} when not is_nil(val) ->
        "#{key}=#{modifier}#{val}"
    end)
  end

  defp encode_param_values(values, separator \\ ",")
  defp encode_param_values(values, separator) when is_list(values), do: Enum.join(values, separator)

  defp encode_param_values(value, _separator)
       when is_bitstring(value) or is_boolean(value) or is_integer(value) or is_atom(value),
       do: value

  defimpl String.Chars do
    def to_string(q), do: q |> PS2.API.Query.encode() |> URI.to_string()
  end
end
