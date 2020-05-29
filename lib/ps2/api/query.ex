defmodule PS2.API.Query do
	@moduledoc """
	A data structure representing an API query. Create a struct using %PS2.API.Query{} or the new/0 or new/1 functions.
	"""

	alias PS2.API.Query

	defstruct collection: nil, terms: %{}, joins: [], tree: nil, sort: nil
	@type t() :: %Query{collection: String.t(), terms: map(), joins: list(Join.t()), tree: Tree.t(), sort: sort_terms}

	@typedoc """
	The key of a term is the field name, and the value is the sort direction. Set the value to `nil` for the default sort direction.
	"""
	@type sort_terms :: map() | Keyword.t()

	@type opts :: [collection: String.t()]

	@spec new(opts) :: %Query{}
	def new, do: %Query{}
	def new(collection: col), do:
		%Query{collection: col}

	defimpl String.Chars, for: PS2.API.Query do
		def to_string(q) do
			{_, q_str} = PS2.API.encode(q)
			q_str
		end
	end
end
