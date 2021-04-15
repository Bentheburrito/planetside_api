defmodule PS2.API.QueryResult do
	defstruct data: [], returned: 0

	@type t() :: %__MODULE__{
		data: list() | map(),
		returned: integer()
	}
end
