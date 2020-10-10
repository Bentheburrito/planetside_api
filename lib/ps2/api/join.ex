defmodule PS2.API.Join do
  @moduledoc """
  A data structure representing a join on an API query. Create a join using %PS2.API.Join{} or the new/0 or new/1 functions.
  """

  alias PS2.API.Join

  defstruct [:collection, params: %{}, joins: []]

  @type t() :: %Join{
		collection: String.t() | nil,
		params: map(),
		joins: [t()]
	}

  @type opts :: [
		collection: String.t(),
		on: String.t(),
		to: String.t(),
		list: boolean(),
		show: list(term()),
		hide: list(term()),
		inject_at: String.t(),
		outer: boolean()
	]

  @spec new() :: t()
  def new, do: %Join{}
  @spec new(opts) :: t()
  def new(opts),
    do: %Join{
      collection: Keyword.get(opts, :collection),
      params: (for {key, val} <- Keyword.delete(opts, :collection), into: %{}, do: {Atom.to_string(key), val})
    }
end
