defmodule PS2.SocketClient do

	def start_link(subscriptions) do

		Task.start_link(fn ->
			PS2.Socket.start_link(subscriptions)
			handle_event_loop(subscriptions)
		end)
	end

	defp handle_event_loop(subscriptions) do
		receive do
			{:GAME_EVENT, event} ->
				IO.puts "Event arrived"
				IO.inspect event
				handle_event_loop(subscriptions)
			_ -> handle_event_loop(subscriptions)
		end
	end

	def child_spec(opts) do
		%{
			id: __MODULE__,
			start: {__MODULE__, :start_link, [opts]},
		}
	end

	# @callback handle_event(any) :: any()

	# defmacro __using__(args) do
	# 	quote location: :keep do
	# 		@behaviour PS2.SocketClient

	# 		def start_link(subscriptions) do
	# 			PS2.SocketClient.start_link(subscriptions)
	# 		end

	# 		def child_spec(_args) do
  #       spec = %{
  #         id: __MODULE__,
  #         start: {__MODULE__, :start_link, []}
  #       }
  #       Supervisor.child_spec(spec, unquote(Macro.escape(args)))
  #     end

	# 		def handle_event(_event), do: :ok

	# 		defoverridable handle_event: 1, child_spec: 1
	# 	end
	# end


	# use GenServer

	# def start_link(options) do
	# 	GenServer.start_link(__MODULE__, options)
	# end

	# def send_event(pid, event) do
	# 	GenServer.cast(pid, event)
	# end


	# def init(subscriptions) do
	# 	PS2.Socket.start_link(subscriptions)
	# 	{:ok, subscriptions}
	# end

	# def handle_cast({:GAME_EVENT, event}, state) do
	# 	IO.puts "Event arrived."
	# 	IO.inspect event
	# 	{:noreply, state}
	# end

end
