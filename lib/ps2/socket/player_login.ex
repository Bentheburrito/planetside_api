defmodule PS2.Socket.PlayerLogin do
  import PS2

  typedstruct do
    field(:character_id, :integer, enforced?: true)
    field(:timestamp, :integer, enforced?: true)
    field(:world_id, :integer, enforced?: true)
  end

  def parse!(payload) do
    %PS2.Socket.PlayerLogin{
      character_id: String.to_integer(payload["character_id"]),
      timestamp: String.to_integer(payload["timestamp"]),
      world_id: String.to_integer(payload["world_id"])
    }
  end
end
