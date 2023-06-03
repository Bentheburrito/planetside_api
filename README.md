# Planetside 2 API Wrapper

A library that provides clean PS2 Census query creation
and Event Stream management for Elixir developers.

View the full documentation [on hexdocs.pm](https://hexdocs.pm/planetside_api/PS2.API.html#content)

## Installation

Add `planetside_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:planetside_api, "~> 0.3.4"}
  ]
end
```

## Census API Queries

This wrapper provides several data structures and functions
that make creating readable Census API queries easy. The
structs, `PS2.API.{Query, Join, Tree}`, can be manipulated
and added to via the functions from `PS2.API.QueryBuilder`.

`Query` is a struct representation of a Census query that is
encoded into its url form when passed to `PS2.API.query/1`
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

Queries are sent to the API with `PS2.API.query/1`,
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

Daybreak offers their [Event Streaming](https://census.daybreakgames.com/#what-is-websocket)
service through websockets to provide developers with live in-game
events as they occur. This wrapper handles the websocket connection
and distributes parsed payloads through `PS2.SocketClient`s.

### Example SocketClient Implementation

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

After creating a client module like the above, you can start `PS2.Socket`
and pass the client in your supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    subscriptions = [
      events: [PS2.player_login],
      worlds: [PS2.connery, PS2.miller, PS2.soltech],
      characters: ["all"]
    ]

    clients = [MyApp.EventHandler]

    ess_opts = [
      subscriptions: subscriptions,
      clients: clients,
      service_id: YOUR_SERVICE_ID,
      # you may also add a :name option.
    ]

    children = [
      # ...
      {PS2.Socket, ess_opts},
      # ...
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

The subscription keys are:

- `:events` is a list of event names
- `:worlds` is a list of world/server IDs
- `:characters` is a list of character IDs.

The `PS2` module provides some convenience methods for both
event names and world IDs. If you want to receive all events
for any of these keys, you can use `["all"]` instead of a
list of specific values.

See the official [Event Streaming docs](https://census.daybreakgames.com/#what-is-websocket)
for more information.
