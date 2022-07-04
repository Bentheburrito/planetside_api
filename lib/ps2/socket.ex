defmodule PS2.Socket do
  @moduledoc """
  A Websockex client that connects to Planetside's Event Streaming Service (ESS).

  After writing a `PS2.SocketClient`, you can start receiving and handling ESS events by spinning up a `PS2.Socket` with
  your desired event subscriptions. You should start this process in your supervision tree. For example:

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
        # you may also add a :name option. The name defaults to `PS2.Socket`, so if you want to run multiple sockets
        # for some reason, you can specify `name: :none` for no name to be registered.
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

  You can also include metadata in the ESS opts to be passed with every event. For example:

  ```elixir
    ess_opts = [
      subscriptions: subscriptions,
      clients: clients,
      service_id: YOUR_SERVICE_ID,
      metadata: [hello: :websocket]
    ]

    # in your SocketClient:
    def handle_event({event_name, _payload}, metadata) do
      IO.inspect("Received \#{event_name} with metadata \#{inspect(metadata)}")
    end
  ```

  Since your service ID should be kept a secret, if you're using version control (e.g. git), you should
  use `Application.get_env(:your_app, :service_id)`, or use environment variables with
  `System.get_env(:your_app, :service_id)`, in place of `YOUR_SERVICE_ID`. You can read more about configuring Elixir
  applications in [Nicd's awesome blog post](https://blog.nytsoi.net/2020/05/05/elixir-time-for-configuration).
  """
  @max_reconnects 3

  use WebSockex

  require Logger

  alias PS2.Socket

  @enforce_keys [:me]
  defstruct subscriptions: [], clients: [], metadata: :none, me: nil

  def start_link(opts) do
    case Keyword.fetch(opts, :service_id) do
      {:ok, sid} ->
        {name, opts} = Keyword.pop(opts, :name, __MODULE__)
        clients = Keyword.get(opts, :clients, [])
        subscriptions = Keyword.get(opts, :subscriptions, [])
        metadata = Keyword.get(opts, :metadata, :none)

        ws_opts =
          [
            async: true,
            handle_initial_conn_failure: true
          ] ++ if name == :none, do: [], else: [name: name]

        ws =
          WebSockex.start_link(
            "wss://push.planetside2.com/streaming?environment=ps2&service-id=s:#{sid}",
            __MODULE__,
            %Socket{subscriptions: subscriptions, clients: clients, metadata: metadata, me: name},
            ws_opts
          )

        case ws do
          {:ok, pid} when name == :none ->
            send(pid, {:update_me, pid})
            {:ok, pid}

          start_result ->
            start_result
        end

      :error ->
        {:stop, no_sid_error_message()}
    end
  end

  @doc """
  Resubscribe to all events
  """
  def resubscribe(name \\ __MODULE__) do
    WebSockex.cast(name, :resubscribe)
  end

  def no_sid_error_message do
    "Please provide a Census service ID under the :service_id option. (See module documentation)"
  end

  ## WebSockex callbacks

  def handle_frame({_type, nil}, state), do: {:ok, state}

  def handle_frame({_type, msg}, state) do
    handle_message(msg, state)
    {:ok, state}
  end

  def handle_cast({:send, frame}, state), do: {:reply, frame, state}

  def handle_cast({:new_client, new_client}, %Socket{clients: clients} = state) do
    {:ok, %Socket{state | clients: [new_client | clients]}}
  end

  def handle_cast(:resubscribe, %Socket{subscriptions: subs, me: me} = state) do
    subscribe(me, subs)
    {:ok, state}
  end

  def handle_connect(_conn, %Socket{subscriptions: subs, me: me} = state) do
    Logger.info("Connected to the Socket.")
    subscribe(me, subs)
    {:ok, state}
  end

  def handle_disconnect(
        %{reason: %WebSockex.RequestError{code: 403 = code, message: message}},
        state
      ) do
    Logger.error(
      "Disconnected from the Socket: \"#{message}\" (error code #{code}). Make sure you have provided a valid service ID!"
    )

    {:ok, state}
  end

  # Handle ESS timing out
  def handle_disconnect(
        %{attempt_number: @max_reconnects},
        state
      ) do
    Logger.warning(
      "ESS disconnected #{@max_reconnects} time(s), will retry initial connection in 30 seconds...",
      inspect(state)
    )

    Process.sleep(30_000)
    {:ok, state}
  end

  def handle_disconnect(%{attempt_number: attempt} = conn, state) do
    Logger.info(
      "Disconnected from the Socket, attempting to reconnect (#{attempt}/#{@max_reconnects}).",
      inspect(state)
    )

    Logger.debug(inspect(conn))

    {:reconnect, state}
  end

  def handle_info({:update_me, pid}, %Socket{} = state) do
    subscribe(pid, state.subscriptions)
    {:ok, %Socket{state | me: pid}}
  end

  def handle_info(unknown, state) do
    Logger.warn("received unknown message: #{inspect(unknown)}")
    {:ok, state}
  end

  ## Data Transformation and Dispatch

  defp handle_message(msg, %Socket{clients: clients, metadata: metadata}) do
    case Jason.decode(msg) do
      {:ok, %{"connected" => "true"}} ->
        Logger.info("Received connected message.")

      {:ok, %{"subscription" => subscriptions}} ->
        Logger.info("""
        Received subscription acknowledgement:
        #{inspect(subscriptions)}
        """)

      {:ok, %{"send this for help" => _}} ->
        nil

      {:ok, message} ->
        with {:ok, event} <- create_event(message) do
          send_event(event, clients, metadata)
        end

      {:error, e} ->
        Logger.error(e)
    end
  end

  defp subscribe(:none, _subs) do
    :no_dest
  end

  defp subscribe(me, subscriptions) do
    payload =
      Jason.encode!(%{
        "service" => "event",
        "action" => "subscribe",
        "characters" => subscriptions[:characters],
        "worlds" => subscriptions[:worlds],
        "eventNames" => subscriptions[:events]
      })

    WebSockex.cast(me, {:send, {:text, payload}})
    :ok
  end

  defp create_event(message) do
    with payload when not is_nil(payload) and is_map(payload) <- message["payload"],
         event_name when not is_nil(event_name) <- payload["event_name"] do
      {:ok, {event_name, Map.delete(payload, "event_name")}}
    else
      _ ->
        Logger.debug("Couldn't create event from message: #{inspect(message)}")
        :error
    end
  end

  defp send_event(event, clients, metadata) do
    args =
      if metadata == :none do
        [event]
      else
        [event, metadata]
      end

    Enum.each(clients, fn client ->
      Task.start(client, :handle_event, args)
    end)
  end
end
