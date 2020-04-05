defmodule PS2.Socket do
	use GenServer

	def start_link(opts) do

		server = Keyword.fetch!(opts, :name)
		GenServer.start_link(__MODULE__, server, opts)
	end

	def init(init_arg) do
		{:ok, init_arg}
	end
end
