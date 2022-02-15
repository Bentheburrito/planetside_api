defmodule PS2.SocketClient do
  @moduledoc ~S"""
  A behaviour for handling events from a `PS2.Socket`.

  ## Implementation
  To handle incoming game events, you need to pass a module with a `handle_event/1` callback to `PS2.Socket` when you
  start it. This behaviour provides an outline for developing such a module (Example implementation below). Events will
  be passed to your client module via the `handle_event/1` in a tuple with the form of `{event_name, payload}`. Note
  that you should have a catch-all `handle_event/1` callback in the case of unhandled events (see example), otherwise
  the client will crash whenever it receives an unknown event.

  Once you have a module like the one below, pass it under the `:clients` option to your `PS2.Socket` (see that module's
  documentation for details).

  Example implementation:
  ```elixir
  defmodule MyApp.EventHandler do
    @behaviour PS2.SocketClient

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
  For more information about events and their payloads, see the official documentation:
  https://census.daybreakgames.com/#websocket-details
  """

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

  @callback handle_event(event) :: any
end
