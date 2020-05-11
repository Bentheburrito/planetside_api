defmodule DummySupervisor do
	@moduledoc false
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, :ok, opts)
	end

	@impl true
	def init(:ok) do

		children = [
			{Dummy, [events: ["PlayerLogin", "VehicleDestroy", "GainExperience"], worlds: ["Connery"], characters: ["5428990295196248449"]]},
			{OtherDummy, [events: ["FacilityControl", "MetagameEvent", "ContinentLock"], worlds: ["Connery", "Miller", "Cobalt", "Emerald"], characters: [], id: Dummy2]}
		]

		Supervisor.init(children, strategy: :one_for_one)
	end
end

defmodule Dummy do
	@moduledoc false
	use PS2.SocketClient

	def start_link(subscriptions) do
		PS2.SocketClient.start_link(__MODULE__, subscriptions)
	end

	def handle_event({"PlayerLogin", _payload}), do: IO.puts "#{__MODULE__} PlayerLogin OK"
	def handle_event({"VehicleDestroy", _payload}), do: IO.puts "#{__MODULE__} VehicleDestroy OK"

	@impl PS2.SocketClient
	def handle_event({event, _payload}) do
		IO.puts "#{__MODULE__} #{inspect self()} recieved unhandled event: #{event}"
	end
end

defmodule OtherDummy do
	@moduledoc false
	use PS2.SocketClient

	def start_link(subscriptions) do
		PS2.SocketClient.start_link(__MODULE__, subscriptions)
	end

	def handle_event({"PlayerLogout", payload}), do: IO.puts "#{__MODULE__} PlayerLogout OK worldID: #{payload["world_id"]}"
	def handle_event({"VehicleDestroy", payload}), do: IO.puts "#{__MODULE__} VehicleDestroy OK worldID: #{payload["world_id"]}"
	def handle_event({"FacilityControl", payload}), do: IO.puts "#{__MODULE__} FacilityControl OK worldID: #{payload["world_id"]}"

	@impl PS2.SocketClient
	def handle_event({event, _payload}) do
		IO.puts "#{__MODULE__} #{inspect self()} recieved unhandled event: #{event}"
	end
end
