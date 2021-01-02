defmodule PS2.SocketClient do
  @moduledoc ~S"""
  A module that handles all interaction with Daybreak Games' Planetside 2 Event Streaming service.

  ## Implementation
  To handle incoming game events, your module should `use PS2.SocketClient` and call `PS2.SocketClient.start_link/2`, passing
  the desired subscription info (Example implementation below). Events will now be sent to your SocketClient, which you handle
  though `handle_event/1`. Note that you should have a catch-all `handle_event/1` callback in the case of unhandled events
  (see example), otherwise the client will crash whenever it receives an unhandled event.

  Example implementation:
  ```elixir
  defmodule MyApp.EventStream do
    use PS2.SocketClient

  	def start_link do
  		subscriptions = [
  			events: ["PlayerLogin"],
  			worlds: ["Connery", "Miller", "Soltech"],
  			characters: ["all"]
  		]
      PS2.SocketClient.start_link(__MODULE__, subscriptions)
    end

    @impl PS2.SocketClient
    def handle_event({"PlayerLogin", payload}) do
      IO.puts "PlayerLogin: #{payload["character_id"]}"
    end

    # Catch-all callback.
    @impl PS2.SocketClient
    def handle_event({event_name, _payload}) do
      IO.puts "Unhandled event: #{event_name}"
    end
  end
  ```
  The second param of `PS2.SocketClient.start_link/2` is the subscription info your client is interested in. See the link below
  to find a list of all event names. You may also specify "all" in any of the subscription fields (Note: if a field is missing,
  "all" will be the default.) If you want to receive heartbeat messages (which contain world status updates), include "heartbeat"
  in your event subscriptions.

  For more information, see the official documentation: https://census.daybreakgames.com/#websocket-details
  """

  @callback handle_event(event) :: any

  @typedoc """
  A two-element tuple representing an in-game event.

  The first element is the event name (String), and the second element
  is the event payload (Map).
  Example:
  `{"VehicleDestroy", %{attacker_character_id: "5428812948092239617", ... }}`

  For a list of example payloads, see Daybreak's documentation: https://census.daybreakgames.com/#websocket-details
  """
  @type event :: {String.t(), map()}

	@typedoc """
	An element in a keyword list where the key is either `:events`,
	`:worlds`, or `:characters`, and the value is a list of event
	names, world names, or character IDs with respect to the key.
	"""
  @type subscription ::
		{:events, [String.t()]}
		| {:worlds, [String.t()]}
		| {:characters, [integer() | String.t()]}

	@typedoc """
	A list of `subscription`s.
	"""
  @type subscription_list :: [subscription] | []

  @world_map %{
    "Connery" => "1",
    "Miller" => "10",
    "Cobalt" => "13",
    "Emerald" => "17",
    "Jaeger" => "19",
    "Briggs" => "25",
    "Soltech" => "40",
    "all" => "all"
  }

  @enforce_keys :pid
  defstruct [:pid, events: ["all"], worlds: ["all"], characters: ["all"]]

  @doc """
  Starts the client process, subscribing to the event stream and listens for relevant events.
  """
  @spec start_link(atom, subscription_list) :: {:ok, pid}
  def start_link(module, subscriptions) when not is_nil(subscriptions) do
    pid =
      spawn(fn ->
        struct_opts =
          Keyword.put(subscriptions, :pid, self())
          |> Keyword.update(:worlds, ["all"], &world_ids_from_name/1)

        if not is_nil(name = Keyword.get(subscriptions, :name)),
          do: Process.register(self(), name)

        WebSockex.cast(PS2.Socket, {:subscribe, struct(PS2.SocketClient, struct_opts)})
        proc_loop(module, subscriptions)
      end)

    {:ok, pid}
  end

  @doc false
  defp proc_loop(module, subscriptions) do
    receive do
      {:GAME_EVENT, event} ->
        Task.start(fn -> module.handle_event(event) end)
        proc_loop(module, subscriptions)

      _ ->
        proc_loop(module, subscriptions)
    end
  end

  defp world_ids_from_name(worlds) do
    Enum.map(worlds, &Map.get(@world_map, &1)) |> Enum.filter(&(&1 !== nil))
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  defmacro __using__(_args) do
    quote location: :keep do
      @behaviour PS2.SocketClient

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      def handle_event(_event), do: :ok

      defoverridable handle_event: 1, child_spec: 1
    end
  end
end
