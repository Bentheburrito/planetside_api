defmodule PS2.API.Join do
	@moduledoc """
	A data structure representing a join on an API query. Create a join using %PS2.API.Join{} or the new/0 or new/1 functions.
	"""

	alias PS2.API.Join

	defstruct [:collection, terms: %{}, adjacent_joins: [], nested_joins: []]
	@type t() :: %Join{
		collection: String.t(),
		terms: map(),
		adjacent_joins: t(),
		nested_joins: t()
	}

	@type opts :: [
		collection: String.t(),
		on: String.t(),
		to: String.t(),
		list: boolean(),
		show: list(term()),
		hide: list(term()),
		inject_at: String.t(),
		outer: boolean(),
	]

	@spec new(opts) :: t()
	def new, do: %Join{}
	def new(opts), do:
		%Join{collection: Keyword.get(opts, :collection), terms: Keyword.delete(opts, :collection) |> Enum.into(%{})}
end
