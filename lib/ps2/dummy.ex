defmodule DummySupervisor do
	@moduledoc """
	Used for testing.
	"""
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, :ok, opts)
	end

	@impl true
	def init(:ok) do

		children = [
			{Dummy, [events: ["PlayerLogin", "VehicleDestroy"], worlds: [1, 10, 13, 17, 19, 40], characters: ["all"]]},
			# {Dummy, [events: ["PlayerLogout"], worlds: [1, 10, 13, 17, 19, 40], characters: ["all"], id: Dummy2]}
		]

		Supervisor.init(children, strategy: :one_for_one)
	end
end

defmodule Dummy do
	use PS2.SocketClient

	def start_link(subscriptions) do
		PS2.SocketClient.start_link(__MODULE__, subscriptions)
	end

	def handle_event({"VehicleDestroy", payload}), do: IO.inspect payload

	@impl PS2.SocketClient
	def handle_event({event, _payload}) do
		IO.puts "#{inspect self()} recieved unhandled event: #{event}"
	end
end
