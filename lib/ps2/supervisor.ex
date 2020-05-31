defmodule PS2.Supervisor do
	use Supervisor

	def start_link(opts) do
		Supervisor.start_link(__MODULE__, :ok, opts)
	end

	@impl true
	def init(:ok) do

		children = if Application.fetch_env(:planetside_api, :event_streaming) != {:ok, false}, do:
		[
			{PS2.Socket, []}
		], else: []

		Supervisor.init(children, strategy: :one_for_one)
	end
end
