defmodule PS2.API.Tree do
	@moduledoc """
	A data structure representing a tree on an API query. Create a tree using %PS2.API.Tree{} or the new/0 or new/1 functions.
	"""

	alias PS2.API.Tree

	defstruct terms: %{}
	@type t() :: %Tree{
		terms: terms
	}

	@type terms :: %{
		field: String.t(),
		list: boolean(),
		prefix: String.t(),
		start: String.t()
	}

	@type opts :: [
		field: String.t(),
		list: boolean(),
		prefix: String.t(),
		start: String.t()
	]

	@spec new() :: t()
	def new, do: %Tree{}
	@spec new(opts) :: t()
	def new(opts), do: %Tree{terms: Enum.into(opts, %{})}
end
