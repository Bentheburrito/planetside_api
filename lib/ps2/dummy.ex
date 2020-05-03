defmodule DummySupervisor do
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, :ok, opts)
	end

	@impl true
	def init(:ok) do

		children = [
			{PS2.SocketClient, [events: ["PlayerLogin"], worlds: [1, 10, 13, 17, 19, 40], characters: ["all"]]}
		]

		Supervisor.init(children, strategy: :one_for_one)
	end
end

# defmodule Dummy do
# 	use PS2.SocketClient

# 	def start_link do
# 		PS2.SocketClient.start_link(__MODULE__)
# 	end

# 	def init(init_arg) do
# 		{:ok, init_arg}
# 	end

# 	@impl PS2.SocketClient
# 	def handle_event({event_name, _payload}) do

# 		IO.inspect "Wow, look at that"
# 	end
# end
