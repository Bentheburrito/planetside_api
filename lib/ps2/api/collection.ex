defmodule PS2.API.Collection do
  @moduledoc false
  # WIP
  defstruct name: nil, fields: [], resolves: []

  def single_character_by_id,
    do: %__MODULE__{
      name: "single_character_by_id",
      fields: [],
      resolves: [
        "online_status",
        "friends",
        "world",
        "outfit",
        "item",
        "profile",
        "faction"
      ]
    }

  defmodule SingleCharacterByID do
  end
end
