defmodule PS2.Supervisor do
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, :ok, opts)
	end

	@impl true
	def init(:ok) do
		children = [
			{PS2.Socket, name: PS2.Socket}
		]

		Supervisor.init(children, strategy: :one_for_one)
	end
end
