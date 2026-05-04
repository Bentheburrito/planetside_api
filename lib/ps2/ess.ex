defmodule PS2.ESS do
  @moduledoc ~S"""
  An Event Streaming Service (ESS) client behaviour.

  Below is an example of an ESS client implementation:

  ```elixir
  defmodule MyApp.EventHandler do
    @behaviour PS2.ESS

    @impl PS2.ESS
    def handle_event(%{"event_name" => "PlayerLogin"} = event) do
      IO.puts "PlayerLogin: #{event["character_id"]}"
    end

    # Catch-all callback
    @impl PS2.ESS
    def handle_event(event) do
      IO.puts "Unhandled event: #{event["event_name"]}"
    end
  end
  ```

  You can then add it to your supervision tree:

  ```elixir
  defmodule MyApp.Application do
    use Application

    @impl Application
    def start(_type, _args) do
      subscription = PS2.ESS.Subscription.new(
        events: [PS2.player_login()],
        worlds: [PS2.connery(), PS2.miller(), PS2.soltech()],
        characters: :all
      )

      ess_opts = [
        subscription: subscription,
        callback_mod: MyApp.EventHandler,
        service_id: "YOUR_SERVICE_ID_HERE",
        # optional name to register the client process under
        name: MyApp.EventHandler
      ]

      children = [
        # ...
        {PS2.ESS, ess_opts},
        # ...
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```

  For more information about events and their payloads, see the [Census
  documentation](https://census.daybreakgames.com/#websocket-details)
  """

  use GenServer

  alias PS2.ESS.Conn
  alias PS2.ESS.Subscription

  require Logger

  defstruct callback_mod: nil, conn: nil

  @typedoc """
  A map of fields that make up the ESS event, e.g.
  `%{"event_name" => "Death", "attacker_character_id" => "5428812948092239617", ... }`
  """
  @type event() :: Conn.event()

  @callback handle_event(event()) :: any()

  def start_link(opts) do
    with {:ok, sid} <- fetch_sid(opts) do
      endpoint = Keyword.get(opts, :endpoint, "wss://push.planetside2.com/streaming")
      environment = Keyword.get(opts, :environment, "ps2")

      callback_mod = Keyword.get(opts, :callback_mod, nil)
      subscription = opts |> Keyword.get(:subscription) |> Subscription.new()

      mint_opts = Keyword.get_lazy(opts, :mint_opts, &Conn.default_mint_opts/0)

      uri = URI.new!("#{endpoint}?environment=#{environment}")
      sid_fxn = fn -> "s:#{sid}" end

      GenServer.start_link(
        __MODULE__,
        {uri, sid_fxn, callback_mod, subscription, mint_opts},
        Keyword.take(opts, [:name])
      )
    end
  end

  defp fetch_sid(opts) do
    with :error <- Keyword.fetch(opts, :service_id) do
      {:stop, "Please provide a Census service ID via the :service_id option. (See #{__MODULE__} documentation)"}
    end
  end

  @doc """
  Adds a new subscription, or resubscribes if no subscription is provided.
  Raises a `KeyError` if `subscription` is not formatted correctly.

  `subscription` should be a keyword list similar to the one passed in the
  options to `PS2.Socket`.
  """
  def subscribe(ess_server), do: GenServer.cast(ess_server, :resubscribe)
  def subscribe(ess_server, %Subscription{} = sub), do: GenServer.cast(ess_server, {:subscribe, sub})

  ### IMPL ###

  @impl GenServer
  def init({%{scheme: nil}, _sid_fxn, _callback, _sub, _opts}),
    do: {:stop, "Please provide a scheme (wss:// or ws://) as a part of the given :endpoint"}

  def init({uri, sid_fxn, callback_mod, subscription, mint_opts}) do
    case Conn.new(uri, sid_fxn, subscription, mint_opts) do
      {:ok, conn} -> {:ok, %__MODULE__{callback_mod: callback_mod, conn: conn}}
      {:error, error} -> {:stop, error}
    end
  end

  @impl GenServer
  def terminate(reason, %__MODULE__{} = state) do
    with {:ok, _conn} <- Conn.close(state.conn) do
      Logger.debug("ESS Connection closed (#{inspect(reason)})")
    end
  end

  @impl GenServer
  def handle_cast(:resubscribe, %__MODULE__{} = state) do
    case Conn.send_subscription(state.conn) do
      {:ok, conn} ->
        current_sub = Conn.current_subscription(conn)
        Logger.info("Resubscribed with #{Subscription.summary(current_sub)}")
        {:noreply, put_in(state.conn, conn)}

      {:error, conn, error} ->
        Logger.error("could not resubscribe: #{inspect(error)}")
        {:noreply, put_in(state.conn, conn)}
    end
  end

  @impl GenServer
  def handle_cast({:subscribe, subscription}, %__MODULE__{} = state) do
    case Conn.send_subscription(state.conn, subscription) do
      {:ok, conn} ->
        current_sub = Conn.current_subscription(conn)
        Logger.info("Subscribed with #{Subscription.summary(current_sub)}")
        {:noreply, put_in(state.conn, conn)}

      {:error, conn, error} ->
        Logger.error("could not subscribe: #{inspect(error)}")
        {:noreply, put_in(state.conn, conn)}
    end
  end

  @impl GenServer
  def handle_info(:resubscribe, %__MODULE__{} = state), do: handle_cast(:resubscribe, state)

  @impl GenServer
  def handle_info(message, %__MODULE__{} = state) do
    case Conn.handle_message(state.conn, message) do
      {:connected, conn} ->
        Logger.debug("#{inspect(self())}: Connected to ESS Websocket.")
        Logger.info("Connected to ESS.")

        current_sub = Conn.current_subscription(state.conn)
        if not is_nil(current_sub), do: send(self(), :resubscribe)

        {:noreply, put_in(state.conn, conn)}

      {:ok, conn, events} when not is_nil(state.callback_mod) ->
        for event <- events, do: Task.start_link(state.callback_mod, :handle_event, [event])
        {:noreply, put_in(state.conn, conn)}

      {:ok, conn, _events} ->
        {:noreply, put_in(state.conn, conn)}

      {:error, conn, :unexpected_upgrade_response} ->
        {:noreply, put_in(state.conn, conn)}
    end
  end
end
