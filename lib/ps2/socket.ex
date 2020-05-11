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
		Task.start_link(fn -> handle_message(msg, state) end)
    {:ok, state}
  end

  def handle_cast({:send, frame}, state), do: {:reply, frame, state}

	def handle_cast({:subscribe, %SocketClient{} = new_client}, state) do
		new_state = Keyword.update(state, :clients, [new_client], &([new_client | &1]))
		subscribe(new_state)
		{:ok, new_state}
	end

	def handle_disconnect(_status_map, state) do
		IO.puts ("Disconnected from socket, attempting to reconnect.")
		{:reconnect, state}
	end

	# Data Transformation + Dispatch

	defp handle_message(msg, state) do
		case Jason.decode(msg) do
			{:ok, %{"connected" => "true"}} ->
				IO.puts("Connected to the socket.")
				# if length(state[:clients]) > 0, do: subscribe(state)

			{:ok, %{"subscription" => subscriptions}} ->
				IO.puts "Subscribed to events #{subscriptions["eventNames"] |> Enum.join(", ")}, worlds: #{subscriptions["worlds"] |> Enum.join(", ")}, character count: #{subscriptions["characterCount"]}."

			{:ok, message} ->
				with {:ok, event} <- create_event(message),
				do: send_event({:GAME_EVENT, event}, state)

			{:error, e} -> IO.inspect(e)
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
		with payload when not is_nil(payload) <- message["payload"],
			event_name when not is_nil(event_name) <- payload["event_name"] do
				{:ok, {event_name, Map.delete(payload, "event_name")}}
		# else with
		end
	end

	defp send_event({_event_type, {event_name, payload}} = event, state) do
		with clients <- Keyword.get(state, :clients, nil), do:
			Enum.each(clients, fn client ->
				if ( # If the client's subscriptions match the payload params, send the event.
					Enum.member?(client.events, event_name) and
					(not Map.has_key?(payload, "world_id") or Enum.member?(client.worlds, "all") or Map.get(payload, "world_id") in client.worlds) and
					(not Map.has_key?(payload, "character_id") or Enum.member?(client.characters, "all") or Map.get(payload, "character_id") in client.characters)
				 ), do:
						send(client.pid, event)
			end)
	end
end
