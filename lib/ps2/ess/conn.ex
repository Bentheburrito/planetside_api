defmodule PS2.ESS.Conn do
  alias PS2.ESS.Subscription

  require Logger

  defstruct conn: nil, ref: nil, subscription: nil, websocket: nil

  @opaque t() :: %__MODULE__{
            conn: Mint.HTTP.t(),
            ref: reference(),
            subscription: Subscription.t() | nil,
            websocket: Mint.WebSocket.t()
          }

  @type event() :: map()

  @type send_subscription_result() :: {:ok, t()} | {:error, t(), :conn_not_upgraded | Mint.WebSocket.error() | any()}

  @default_mint_opts transport_opts: [versions: [:"tlsv1.2"]]
  def default_mint_opts, do: @default_mint_opts

  @spec new(URI.t(), (-> String.t()), Subscription.t() | nil) ::
          {:ok, t()} | {:error, Mint.Types.error() | Mint.WebSocket.error()}
  def new(%URI{scheme: scheme} = uri, sid_fxn, sub \\ nil, mint_opts \\ @default_mint_opts) when scheme in ~w|ws wss| do
    http_scheme = if scheme == "wss", do: :https, else: :http

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme, uri.host, uri.port, mint_opts),
         {:ok, conn, ref} <- upgrade(conn, uri, sid_fxn) do
      {:ok, %__MODULE__{conn: conn, ref: ref, subscription: sub, websocket: nil}}
    end
  end

  defp upgrade(conn, uri, sid_fxn) do
    scheme = if uri.scheme == "wss", do: :wss, else: :ws

    path =
      uri
      |> URI.append_query("service-id=#{sid_fxn.()}")
      |> to_string()
      |> String.trim_leading("#{scheme}://#{uri.host}")

    with {:error, conn, error} <- Mint.WebSocket.upgrade(scheme, conn, path, []) do
      {:ok, _} = Mint.HTTP.close(conn)
      {:error, error}
    end
  end

  def close(%__MODULE__{} = ess_conn) do
    with {:ok, conn} <- Mint.HTTP.close(ess_conn.conn), do: {:ok, put_in(ess_conn.conn, conn)}
  end

  @doc """
  Resends the subscription message down the websocket, assuming at least one
  subscription was sent previously. Useful in cases where ESS may mysteriously
  stop sending events of a certain kind. Alternatively, consider killing the
  connection altogether for a fresh start.

  Since subscriptions are additive, if more than one subscription message was
  sent earlier, the cumulative set of subscription will be resent.
  """
  @spec send_subscription(t()) :: send_subscription_result() | {:error, t(), :no_subscription_given}
  def send_subscription(%__MODULE__{subscription: nil} = ess_conn), do: {:error, ess_conn, :no_subscription_given}
  def send_subscription(%__MODULE__{} = ess_conn), do: send_subscription(ess_conn, ess_conn.subscription)

  @doc """
  Sends a new subscription message down the socket. Since subscriptions are
  additive, the given `%PS2.ESS.Subscription{}` will add to subscriptions of
  any previous calls to this function. If the given subscription sets
  `clear?: true`, it will remove the specified items from your total
  subscription set.
  """
  @spec send_subscription(t(), Subscription.t()) ::
          {:ok, t()} | {:error, t(), :conn_not_upgraded | Mint.WebSocket.error() | any()}
  def send_subscription(%__MODULE__{websocket: nil} = ess_conn, _sub), do: {:error, ess_conn, :conn_not_upgraded}

  # no subscriptions to clear? noop
  def send_subscription(%__MODULE__{websocket: %Mint.WebSocket{}, subscription: nil} = ess_conn, %Subscription{
        clear?: true
      }),
      do: {:ok, ess_conn}

  def send_subscription(%__MODULE__{websocket: %Mint.WebSocket{}} = ess_conn, %Subscription{} = sub) do
    json_sub = JSON.encode!(sub)

    with {:ok, ess_conn, encoded_sub} <- encode_websocket(ess_conn, json_sub),
         {:ok, ess_conn} <- send_websocket(ess_conn, encoded_sub) do
      subscription = if is_nil(ess_conn.subscription), do: sub, else: Subscription.merge(ess_conn.subscription, sub)
      {:ok, put_in(ess_conn.subscription, subscription)}
    end
  end

  defp encode_websocket(%__MODULE__{} = ess_conn, to_encode) do
    case Mint.WebSocket.encode(ess_conn.websocket, {:text, to_encode}) do
      {:ok, websocket, encoded} -> {:ok, put_in(ess_conn.websocket, websocket), encoded}
      {:error, websocket, error} -> {:error, put_in(ess_conn.websocket, websocket), error}
    end
  end

  defp send_websocket(%__MODULE__{} = ess_conn, encoded) do
    case Mint.WebSocket.stream_request_body(ess_conn.conn, ess_conn.ref, encoded) do
      {:ok, conn} -> {:ok, put_in(ess_conn.conn, conn)}
      {:error, conn, error} -> {:error, put_in(ess_conn.conn, conn), error}
    end
  end

  @doc "Returns the current subscription of the given ESS connection"
  @spec current_subscription(t()) :: Subscription.t() | nil
  def current_subscription(%__MODULE__{subscription: sub}), do: sub

  @doc """
  Handles websocket messages. The process that called `new/1,2` will receive
  messages that should be passed to this function for processing.
  """
  @spec handle_message(t(), message :: term()) ::
          {:connected, t()}
          | {:ok, t(), [event()]}
          | {:error, t(), Mint.WebSocket.error() | :unexpected_upgrade_response}
  def handle_message(%__MODULE__{websocket: nil} = ess_conn, message) do
    with {:ok, ess_conn, responses} <- stream(ess_conn, message),
         {:ok, status, resp_headers} <- verify_upgrade_response(ess_conn, responses) do
      new_websocket(ess_conn, status, resp_headers)
    end
  end

  def handle_message(%__MODULE__{websocket: %Mint.WebSocket{}} = ess_conn, message) do
    with {:ok, ess_conn, responses} <- stream(ess_conn, message),
         {:ok, ess_conn, events} <- decode_responses(ess_conn, responses) do
      {:ok, ess_conn, events}
    end
  end

  defp stream(%__MODULE__{} = ess_conn, message) do
    case Mint.WebSocket.stream(ess_conn.conn, message) do
      {:ok, conn, responses} ->
        {:ok, put_in(ess_conn.conn, conn), responses}

      {:error, conn, error, responses} ->
        Logger.debug("error streaming ESS Websocket data: #{inspect(error)}")
        {:ok, put_in(ess_conn.conn, conn), responses}

      :unknown ->
        Logger.debug("unknown error streaming ESS Websocket data!")
        {:ok, ess_conn, []}
    end
  end

  defp new_websocket(%__MODULE__{} = ess_conn, status, resp_headers) do
    case Mint.WebSocket.new(ess_conn.conn, ess_conn.ref, status, resp_headers) do
      {:ok, conn, websocket} -> {:connected, struct!(ess_conn, conn: conn, websocket: websocket)}
      {:error, conn, error} -> {:error, put_in(ess_conn.conn, conn), error}
    end
  end

  defp verify_upgrade_response(%__MODULE__{ref: ref}, [
         {:status, ref, status},
         {:headers, ref, resp_headers},
         {:done, ref}
       ]),
       do: {:ok, status, resp_headers}

  defp verify_upgrade_response(ess_conn, _unexpected_res), do: {:error, ess_conn, :unexpected_upgrade_response}

  defp decode_responses(%__MODULE__{} = ess_conn, responses) do
    {ess_conn, events} = Enum.reduce(responses, {ess_conn, []}, &decode_events_from_response/2)
    {:ok, ess_conn, Enum.reverse(events)}
  end

  defp decode_events_from_response({:data, ref, data}, {%__MODULE__{ref: ref} = ess_conn, events}) do
    # TODO: error handling
    {:ok, websocket, messages} = Mint.WebSocket.decode(ess_conn.websocket, data)

    events =
      messages
      |> Stream.map(&decode_message/1)
      |> Stream.map(&handle_decoded/1)
      |> Stream.filter(&is_map/1)
      |> Enum.reduce(events, &[&1 | &2])

    {put_in(ess_conn.websocket, websocket), events}
  end

  defp decode_events_from_response(_invalid_message, acc), do: acc

  defp decode_message({:text, message}), do: JSON.decode(message)
  defp decode_message(_), do: {:error, :not_text_data}

  defp handle_decoded({:ok, %{"subscription" => subscriptions}}),
    do: Logger.debug("Received subscription ack: #{inspect(subscriptions)}")

  defp handle_decoded({:ok, %{"detail" => "EventServerEndpoint" <> _rest} = event}),
    do: Logger.debug("Received server info event: #{inspect(event)}")

  defp handle_decoded({:ok, %{"online" => event}}) do
    Logger.debug("Received online message: #{inspect(event)}")
    Map.put(event, "event_name", PS2.server_health_update())
  end

  defp handle_decoded({:ok, %{"connected" => "true"}}), do: Logger.debug("Received connected ack")
  defp handle_decoded({:ok, %{"send this for help" => _}}), do: Logger.debug("help msg received")
  defp handle_decoded({:ok, %{"payload" => event}}), do: event
  defp handle_decoded({:error, decode_error}), do: Logger.debug("Ignoring non-JSON message: #{decode_error}")
end
