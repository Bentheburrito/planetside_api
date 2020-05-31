defmodule PS2.Socket do
	use WebSockex

	require Logger
	alias PS2.SocketClient

	def start_link(_opts) do
		sid = Application.fetch_env!(:planetside_api, :service_id)
		WebSockex.start_link("wss://push.planetside2.com/streaming?environment=ps2&service-id=s:#{sid}", __MODULE__, [clients: []], name: __MODULE__, handle_initial_conn_failure: true)
	end

	# WebSockex callbacks

	def handle_frame({_type, nil}, state), do: {:ok, state}
	def handle_frame({_type, msg}, state) do
		handle_message(msg, state)
    {:ok, state}
	end

  def handle_cast({:send, frame}, state), do: {:reply, frame, state}

	def handle_cast({:subscribe, %SocketClient{} = new_client}, state) do
		new_state = Keyword.update(state, :clients, [new_client], &([new_client | &1]))

		subscribe(new_state)
		send(new_client.pid, {:STATUS_EVENT, {"Subscribed", :ok}})
		Process.monitor(new_client.pid)

		{:ok, new_state}
	end

	def handle_connect(_conn, state) do
		Logger.info("Connected to the Socket.")
		if length(state[:clients]) > 0, do: subscribe(state)
		{:ok, state}
	end

	def handle_disconnect(_status_map, state) do
		Logger.info("Disconnected from the Socket, attempting to reconnect.")
		{:reconnect, state}
	end

	def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
		new_state = Keyword.update!(state, :clients, &List.delete(&1, Enum.find(state[:clients], fn client -> client.pid === pid end)))
		{:ok, new_state}
	end

	def handle_info(_, state), do: {:ok, state}

	# Data Transformation + Dispatch

	defp handle_message(msg, state) do
		case Jason.decode(msg, keys: :atoms) do
			{:ok, %{:connected => "true"}} ->
				Logger.info("Received connected message.")
				# if length(state[:clients]) > 0, do: subscribe(state)

			{:ok, %{:subscription => subscriptions}} ->
				Logger.info("Subscribed to events #{subscriptions[:eventNames] |> Enum.join(", ")}, worlds: #{subscriptions[:worlds] |> Enum.join(", ")}, character count: #{subscriptions[:characterCount]}.")

			{:ok, message} ->
				with {:ok, event} <- create_event(message),
				do: send_event({:GAME_EVENT, event}, state)

			{:error, e} -> Logger.error(e)
		end
	end

	defp subscribe(state) do
		subscriptions = Enum.reduce(state[:clients], [events: [], worlds: [], characters: []], fn (%SocketClient{} = client, acc) ->
			[
				events: acc[:events] ++ client.events,
				worlds: acc[:worlds] ++ client.worlds,
				characters: acc[:characters] ++ client.characters
			]
		end)

		payload = Jason.encode!(%{
			service: "event",
			action: "subscribe",
			characters: subscriptions[:characters],
			worlds: subscriptions[:worlds],
			eventNames: subscriptions[:events]
		})
		WebSockex.cast(__MODULE__, {:send, {:text, payload}})
		:ok
	end

	defp create_event(message) do
		with payload when not is_nil(payload) and is_map(payload) <- message[:payload] || message[:online],
			event_name when not is_nil(event_name) <- payload[:event_name] || message[:type], do:
				{:ok, {to_string(event_name), Map.delete(payload, :event_name)}}
	end

	defp send_event({_event_type, event} = game_event, state) do
		with clients <- Keyword.get(state, :clients, nil), do:
			Enum.each(clients, &(if is_subscribed?(&1, event), do: send(&1.pid, game_event)))
		:ok
	end

	defp is_subscribed?(client, {event_name, payload} = _event) do
		(
			# True if the client is subscribed to the event.
			Enum.member?(client.events, event_name) and
			# If the payload doesn't have a "world_id" key, skip the test (true).
			# If the client is subscribed to all worlds, pass the test (true).
			# If the client is subscribed to events from this world, pass the test (true).
			(not Map.has_key?(payload, :world_id) or Enum.member?(client.worlds, "all") or Map.get(payload, :world_id) in client.worlds) and
			# Same as above but with characters.
			(not Map.has_key?(payload, :character_id) or Enum.member?(client.characters, "all") or Map.get(payload, :character_id) in client.characters)
		)
	end
end
