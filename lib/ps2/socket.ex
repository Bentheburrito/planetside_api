defmodule PS2.Socket do
	use WebSockex

	def start_link(subscriptions) do
		sid = Application.fetch_env!(:planetside_api, :service_id)

		WebSockex.start_link("wss://push.planetside2.com/streaming?environment=ps2&service-id=s:#{sid}", __MODULE__, subscriptions ++ [clients: [self()]], name: __MODULE__)
	end

	def handle_frame({_type, msg}, state) do

		case Jason.decode(msg) do
			{:ok, %{"connected" => "true"}} ->
				IO.puts("Connected to the socket.")
				subscribe(state)

			{:ok, message} ->
				with {:ok, event} <- create_event(message),
				do: send_event({:GAME_EVENT, event}, state)

			{:error, e} -> IO.inspect(e)
		end

    {:ok, state}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts "Sending #{type} frame with payload: #{msg}"
    {:reply, frame, state}
	end

	# def handle_cast({:subscribe, {pid, subscriptions}}, state) do
	# 	new_state = Keyword.update(state, :clients, [], fn clients -> [pid | clients] end)
	# 	|> Keyword.update(:events, ["all"], fn events -> events ++ subscriptions[:events] end)
	# 	|> Keyword.update(:worlds, ["all"], fn worlds -> worlds ++ subscriptions[:worlds] end)
	# 	|> Keyword.update(:characters, ["all"], fn characters -> characters ++ subscriptions[:characters] end)

	# 	subscribe(new_state)
	# 	IO.inspect new_state
	# 	{:ok, new_state}
	# end

	defp subscribe(state) do
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
	end

	defp create_event(message) do
		with payload when not is_nil(payload) <- message["payload"],
		event_name when not is_nil(event_name) <- payload["event_name"],
		do: {:ok, {event_name, Map.delete(payload, "event_name")}}
	end

	defp send_event(event, state) do
		case Keyword.get(state, :clients, nil) do
			nil -> IO.puts "COULD NOT GET CLIENT"
			clients -> Enum.each(clients, fn pid -> send(pid, event) end)
		end
	end
end
