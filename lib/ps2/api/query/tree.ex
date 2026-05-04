defmodule PS2.API.Query.Tree do
  @moduledoc """
  A data structure representing a tree on an API query. Create a tree using
  PS2.API.Query.Tree.new/1 functions.
  """

  alias PS2.API.Query.Tree

  @enforce_keys [:field]
  defstruct field: nil, list: false, prefix: nil, start: nil

  @type t() :: %Tree{
          field: String.t(),
          list: 0 | 1,
          prefix: String.t() | nil,
          start: String.t() | nil
        }

  @type opts :: [
          field: String.t(),
          list: 0 | 1,
          prefix: String.t() | nil,
          start: String.t() | nil
        ]

  @spec new(opts) :: t()
  def new(opts \\ []), do: struct!(Tree, opts)
end
