defmodule PS2.SocketClient do
	@moduledoc ~S"""
	A module that handles interaction with Daybreak Games' Planetside 2 Event Streaming service.

	## Implementation
	To handle incoming game events, your module should `use PS2.SocketClient` and call `PS2.SocketClient.start_link/2` passing
	the desired subscription info (Example implementation below). Note that you should have a catch-all `handle_event/1` callback
	in the case of unhandled events.

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
	The second param of `PS2.SocketClient.start_link/2` is the subscription info your client is interested in. See the link below
	to find a list of all event names. You may also specify "all" in any of the subscription fields (Note: if a field is missing,
	"all" will be the default.)
	If you want to receive heartbeat messages (which contain world online-status updates), include "heartbeat" in your event
	subscriptions.

	For more information, see the official documentation: https://census.daybreakgames.com/#websocket-details
	"""

	@callback handle_event(game_event) :: any

	@typedoc """
	A tuple representing an in-game event. The first element is the event name (String), and the second element
	is the event payload (Map).

	Example:
	`{"VehicleDestroy", %{"attacker_character_id" => "5428812948092239617", ... }}`

	For a list of example payloads, see Daybreak's documentation: https://census.daybreakgames.com/#websocket-details
	"""
	@type game_event :: {String.t(), map()}

	@world_map %{
		"Connery" => 1,
    "Miller" => 10,
    "Cobalt" => 13,
    "Emerald" => 17,
    "Jaeger" => 19,
    "Briggs" => 25,
		"Soltech" => 40,
		"all" => "all"
	}

	@type event_subscriptions :: {:events, list(String.t() | integer())}
	@type world_subscriptions :: {:worlds, list(String.t() | integer())}
	@type character_subscriptions :: {:characters, list(String.t() | integer())}
	@type subscriptions :: [event_subscriptions | world_subscriptions | character_subscriptions]

	@enforce_keys :pid
	defstruct [:pid, events: ["all"], worlds: ["all"], characters: ["all"]]

	@doc """
	Starts the client process, subscribing to the event stream and listens for relevant events.
	"""
	@spec start_link(atom, subscriptions) :: {:ok, pid}
	def start_link(module, subscriptions) do
		Task.start_link(fn ->
			WebSockex.cast(PS2.Socket, {:subscribe,
				%PS2.SocketClient{
					pid: self(),
					events: Keyword.get(subscriptions, :events, ["all"]),
					worlds: Keyword.get(subscriptions, :worlds, ["all"]) |> Enum.map(&Map.get(@world_map, &1) |> to_string) |> Enum.filter(& &1 !== ""),
					characters: Keyword.get(subscriptions, :characters, ["all"])
				}
			})
			proc_loop(module, subscriptions)
		end)
	end

	defp proc_loop(module, subscriptions) do
		receive do
			{:GAME_EVENT, event} ->
				Task.start_link(fn -> module.handle_event(event) end)
				proc_loop(module, subscriptions)
			_ ->
				proc_loop(module, subscriptions)
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
