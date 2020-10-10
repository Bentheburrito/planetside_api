defmodule PS2.API.Query do
  @moduledoc """
  A data structure representing an API query. Create a struct using %PS2.API.Query{} or the new/0 or new/1 functions.
  """

  alias PS2.API.Query

  defstruct collection: nil, params: %{}, joins: [], tree: nil, sort: nil

  @type t() :: %Query{
          collection: String.t() | nil,
          params: map(),
          joins: list(PS2.API.Join.t()),
          tree: PS2.API.Tree.t() | nil,
          sort: sort_terms | nil
        }

  @typedoc """
  The key of a term is the field name, and the value is the sort direction. Set the value to `nil` for the default sort direction.
  """
  @type sort_terms :: map() | Keyword.t()

  @type opts :: [collection: String.t()]

  @spec new() :: t()
  def new, do: %Query{}
  @spec new(opts) :: t()
  def new(collection: col), do: %Query{collection: col}

  defimpl String.Chars, for: PS2.API.Query do
    def to_string(q) do
      {_, q_str} = PS2.API.encode(q)
      q_str
    end
  end
end
