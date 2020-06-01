defmodule PS2.API.Query.Error do
  @moduledoc false
  defexception message: "A problem occured while constructing the query."

  @type t() :: %__MODULE__{message: String.t()}
end
