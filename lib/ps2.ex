defmodule PS2 do
  @moduledoc false
  use Application

  # Application Entry Point
  @impl true
  def start(_type, _args) do
    PS2.Supervisor.start_link(name: PS2.Supervisor)
  end
end
