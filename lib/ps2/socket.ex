defmodule PS2.Socket do
	use WebSockex

	def start_link(subscriptions) do
		sid = Application.fetch_env!(:planetside_api, :service_id)

		WebSockex.start_link("wss://push.planetside2.com/streaming?environment=ps2&service-id=s:#{sid}", __MODULE__, subscriptions ++ [client: self()], name: __MODULE__)
	end

	def handle_frame({_type, msg}, state) do

		parse(msg, state)

    {:ok, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts "Sending #{type} frame with payload: #{msg}"
    {:reply, frame, state}
	end

	defp parse(msg, state) do
		case Jason.decode(msg) do
			{:ok, %{"connected" => "true"}} ->
				IO.puts("Connected to the socket.")

				characters = Keyword.get(state, :characters, ["all"])
				worlds = Keyword.get(state, :worlds, ["all"])
				events = Keyword.get(state, :events, ["all"])

				payload = Jason.encode!(%{
					service: "event",
					action: "subscribe",
					characters: characters,
					worlds: worlds,
					eventNames: events
				})
				WebSockex.cast(__MODULE__, {:send, {:text, payload}})

			{:ok, message} -> send_event({:GAME_EVENT, message}, state)
			{:error, e} -> IO.inspect(e)
		end
	end

	defp send_event(event, state) do
		case Keyword.get(state, :client, nil) do
			nil -> IO.puts "COULD NOT GET CLIENT"
			pid ->
				# PS2.SocketClient.send_event(pid, event)
				send(pid, event)
		end
	end
end
