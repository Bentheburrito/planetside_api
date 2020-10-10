# Planetside 2 API Wrapper v0.1.2

A library that provides clean PS2 Census query creation
and Event Stream management for Elixir developers.

View the full documentation [on hexdocs.pm](https://hexdocs.pm/planetside_api/PS2.API.html#content)

## Installation

Add `planetside_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:planetside_api, "~> 0.1.2"}
  ]
end
```

Configure your service ID in `config/config.exs`
```elixir
import Config
config :planetside_api, service_id: "service_id_here"
```
That's it! You can now create/send queries and setup Event
Streaming.

## Census API Queries
This wrapper provides several data structures and functions
that make creating readable Census API queries easy. The
structs, `PS2.API.{Query, Join, Tree}`, can be manipulated
and added to via the functions from `PS2.API.QueryBuilder`.

`Query` is a struct representation of a Census query that is
encoded into its url form when passed to `PS2.API.send_query/1`
or `PS2.API.encode/1`. A `Query` can contain many `Join`s and
a `Tree`.

### Example query with a join and tree
```elixir
# alias struct modules and import QueryBuilder for clean, readable pipelines.
alias PS2.API.{Query, Join, Tree}
import PS2.API.QueryBuilder

q =
  %Query{}
  |> collection("character")
  |> term("name.first_lower", "wrel", :starts_with)
  |> limit(12)
  |> lang("en")
  |> join(
    %Join{}
    |> collection("characters_online_status")
    |> inject_at("online")
  )
  |> tree(
    %Tree{}
    |> field("online.online_status")
    |> list(true)
  )

# For large queries with many joins, you may want to split these further into separate parts:

online_status_join = 
  %Join{}
  |> collection("characters_online_status")
  |> inject_at("online")

online_status_tree =
  %Tree{}
  |> field("online.online_status")
  |> list(true)

q =
  %Query{}
  |> collection("character")
  |> term("name.first_lower", "wrel", :starts_with)
  |> limit(12)
  |> lang("en")
  |> join(online_status_join)
  |> tree(online_status_tree)
```

Queries are sent to the API with `PS2.API.send_query/1`,
returning `{:ok, results}`.

### Nesting `Join`s
`Join`s can be nested within one another using `join/2`. For
example:

```elixir
alias PS2.API.{Query, Join, Tree}
import PS2.API.QueryBuilder

# Note we can pass the collection name (and common fields in Joins) when using a new/1 function.

Query.new(collection: "character")
|> show(["character_id", "faction_id"])
|> lang("en")
|> join(
  Join.new(collection: "characters_online_status", on: "character_id", inject_at: "online")
)
|> join(
  Join.new(collection: "characters_weapon_stat")
  |> join(
    Join.new(collection: "item")
  )
)
```
See the [API docs](https://census.daybreakgames.com/#query-commands)
for more information on joins.

See the PS2.API.QueryBuilder documentation for in-depth explanations and
examples.

## Event Streaming

Daybreak provides their [Event Streaming](https://census.daybreakgames.com/#what-is-websocket)
service through websockets to provide developers with live in-game
events as they occur. This wrapper handles the websocket connection
and distributes parsed payloads through `PS2.SocketClient`s.

### Example SocketClient Implementation
```elixir
defmodule MyApp.EventStream do
  use PS2.SocketClient

  def start_link do
    subscriptions = [
      events: ["MetagameEvent", "VehicleDestroy"], 
      worlds: ["Emerald", "Miller"], 
      characters: ["all"]
    ]
    PS2.SocketClient.start_link(__MODULE__, subscriptions)
  end

  def handle_event({"MetagameEvent", payload}), do: IO.puts "Alert #{payload[:metagame_event_id]}"
  def handle_event({"VehicleDestroy", payload}), do: IO.inspect payload

	# Catch-all callback.
  def handle_event({event, _payload}) do
    IO.puts "Recieved unhandled event: #{event}"
  end
end
```
`PS2.SocketClient.start_link/2` expects a module that implements `PS2.SocketClient`
as the first argument, and a keyword list of subscriptions as the second argument.
`:events` is a list of event names, `:worlds` is a list of world/server names 
(Connery, Miller, Cobalt, Emerald, or Soltech), and `:characters` is a list of
character IDs. See a full list of event names in the
[Event Streaming docs](https://census.daybreakgames.com/#what-is-websocket).

`SocketClient`s also fit well into supervision trees:

```elixir
defmodule MyApp.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {MyApp.EventStream, [events: ["MetagameEvent", "VehicleDestroy"], worlds: ["Emerald", "Miller"], characters: ["all"]]},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule MyApp.EventStream do
  use PS2.SocketClient

  def start_link(subscriptions) do
    PS2.SocketClient.start_link(__MODULE__, subscriptions)
  end

  def handle_event({"MetagameEvent", payload}), do: IO.puts "Alert #{payload[:metagame_event_id]}"
  def handle_event({"VehicleDestroy", payload}), do: IO.inspect payload

  def handle_event({event, _payload}) do
    IO.puts "Recieved unhandled event: #{event}"
  end
end
```

However, if you are not interested in Event Streaming at all, you can set 
`event_streaming: false` in your config file to prevent the socket process
from starting.
```elixir
import Config
config :planetside_api, service_id: "service_id_here", event_streaming: false
```