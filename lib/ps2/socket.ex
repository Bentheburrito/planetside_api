defmodule PS2.Socket do
  @moduledoc """
  A Websockex client that connects to Planetside's Event Streaming Service (ESS).

  After writing a `PS2.SocketClient`, you can start receiving and handling ESS events by spinning up a `PS2.Socket` with
  your desired event subscriptions. You should start this process in your supervision tree. For example:
  ```elixir
  defmodule MyApp.Application do
    use Application

    @impl true
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
  Since your service ID should be kept a secret, if you're using version control (e.g. git), you should
  use `Application.get_env(:your_app, :service_id)`, or use environment variables with
  `System.get_env(:your_app, :service_id)`, in place of `YOUR_SERVICE_ID`. You can read more about configuring Elixir
  applications in [Nicd's awesome blog post](https://blog.nytsoi.net/2020/05/05/elixir-time-for-configuration).
  """
  @max_reconnects 3

  use WebSockex

  require Logger

  def start_link(opts) do
    case Keyword.fetch(opts, :service_id) do
      {:ok, sid} ->
        {name, opts} = Keyword.pop(opts, :name, __MODULE__)
        clients = Keyword.get(opts, :clients, [])
        subscriptions = Keyword.get(opts, :subscriptions, [])

        ws_opts = [
          name: name,
          async: true,
          handle_initial_conn_failure: true
        ]

        WebSockex.start_link(
          "wss://push.planetside2.com/streaming?environment=ps2&service-id=s:#{sid}",
          __MODULE__,
          {subscriptions, clients},
          ws_opts
        )

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

  def handle_cast({:new_client, new_client}, {subscriptions, clients}) do
    {:ok, {subscriptions, [new_client | clients]}}
  end

  def handle_cast(:resubscribe, {subs, _clients} = state) do
    subscribe(subs)
    {:ok, state}
  end

  def handle_connect(_conn, {subs, _clients} = state) do
    Logger.info("Connected to the Socket.")
    subscribe(subs)
    {:ok, state}
  end

  def handle_disconnect(%{reason: %WebSockex.RequestError{code: 403 = code, message: message}}, state) do
    Logger.error("Disconnected from the Socket: \"#{message}\" (error code #{code}). Make sure you have provided a valid service ID!")
    {:ok, state}
  end

  # Handle ESS timing out
  def handle_disconnect(
        %{attempt_number: @max_reconnects},
        state
      ) do
    Logger.warn(
      "ESS disconnected #{@max_reconnects} time(s), will retry initial connection in 30 seconds..."
    )

    Process.sleep(30_000)
    {:ok, state}
  end

  def handle_disconnect(%{attempt_number: attempt} = conn, state) do
    Logger.info(
      "Disconnected from the Socket, attempting to reconnect (#{attempt}/#{@max_reconnects})."
    )
    Logger.debug(inspect(conn))

    {:reconnect, state}
  end

  def handle_info(unknown, state) do
    Logger.warn("received unknown message: #{inspect(unknown)}")
    {:ok, state}
  end

  ## Data Transformation and Dispatch

  defp handle_message(msg, {_subs, clients}) do
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
          send_event(event, clients)
        end

      {:error, e} ->
        Logger.error(e)
    end
  end

  defp subscribe(subscriptions) do
    payload =
      Jason.encode!(%{
        "service" => "event",
        "action" => "subscribe",
        "characters" => subscriptions[:characters],
        "worlds" => subscriptions[:worlds],
        "eventNames" => subscriptions[:events]
      })

    WebSockex.cast(__MODULE__, {:send, {:text, payload}})
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

  defp send_event(event, clients) do
    Enum.each(clients, fn client ->
      Task.start(client, :handle_event, [event])
    end)
  end
end
