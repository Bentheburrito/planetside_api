defmodule PS2.SocketClient do
	@moduledoc ~S"""
	A module that handles interaction with Daybreak Games' Planetside 2 Event Streaming service.

	## Implementation
	To handle incoming game events, your module should `use PS2.SocketClient` and call `PS2.SocketClient.start_link/2`,
	to start receiving events. You can now define `handle_event/1` functions to pattern match on your desired events.

	Example implementation:
	```elixir
	defmodule MyApp.Client do
		use PS2.SocketClient

		def start_link do
			PS2.SocketClient.start_link(__MODULE__, [events: ["PlayerLogin"], worlds: [1, 10, 13, 17, 19, 40], characters: ["all"]])
		end

		@impl PS2.SocketClient
		def handle_event({"PlayerLogin", payload}) do
			IO.puts "PlayerLogin: #{payload["character_id"]}"
		end

		@impl PS2.SocketClient
		def handle_event({event_name, _payload}) do
			IO.puts "Unhandled event: #{event_name}"
		end
	end
	```

	For more information, see the official documentation: https://census.daybreakgames.com/#websocket-details
	"""

	@callback handle_event(game_event) :: any

	@typedoc """
	A tuple representing an in-game event. The first element is the event name (String), and the second element
	is the event payload (Map).

	Example:
	`{"VehicleDestroy", %{"attacker_character_id" => "5428812948092239617", ... }`

	For a list of example payloads, see Daybreak's documentation: https://census.daybreakgames.com/#websocket-details
	"""
	@type game_event :: {String.t(), map()}

	@type event_subscriptions :: {:events, list(String.t() | integer())}
	@type world_subscriptions :: {:worlds, list(String.t() | integer())}
	@type character_subscriptions :: {:characters, list(String.t() | integer())}
	@type subscription_set :: [event_subscriptions | world_subscriptions | character_subscriptions]

	@doc """
	Connects to the event stream. If the socket has already been opened, `subscriptions` will be aggregated.
	"""
	@spec start_link(atom, subscription_set) :: {:ok, pid}
	def start_link(module, subscriptions) do

		Task.start_link(fn ->
			case Process.whereis(PS2.Socket) do # Doesn't work when 2+ SocketClients are started under a supervisor. Would need to start the socket beforehand and retrieve subscription data via config.exs
				nil -> PS2.Socket.start_link(subscriptions)
				_ -> WebSockex.cast(PS2.Socket, {:subscribe, {self(), subscriptions}})
			end
			event_dispatch_loop(module, subscriptions)
		end)
	end

	defp event_dispatch_loop(module, subscriptions) do
		receive do
			{:GAME_EVENT, event} ->
				IO.puts "#{inspect self()} Got game event"
				Task.start_link(fn -> module.handle_event(event) end)
				event_dispatch_loop(module, subscriptions)
			_ ->
				event_dispatch_loop(module, subscriptions)
		end
	end

	def child_spec(opts) do
		%{
			id: __MODULE__,
			start: {__MODULE__, :start_link, [opts]},
		}
	end

	defmacro __using__(_args) do
		quote location: :keep do
			@behaviour PS2.SocketClient

			def child_spec(opts) do
				id = Keyword.get(opts, :id, __MODULE__)
        %{
          id: id,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

			def handle_event(_event), do: :ok

			defoverridable handle_event: 1, child_spec: 1
		end
	end
end
