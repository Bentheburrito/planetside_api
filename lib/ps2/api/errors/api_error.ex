defmodule PS2.API.Error do
  @moduledoc false
  defexception message: "The API returned an error.", query: nil

  @type t() :: %__MODULE__{message: String.t(), query: PS2.API.Query.t()}
end
