defmodule PS2.SocketTest do
  use ExUnit.Case

  doctest PS2.Socket
  doctest PS2.SocketClient

  @default_subs [
    events: [PS2.gain_experience()],
    worlds: ["all"],
    characters: ["all"]
  ]

  setup_all do
    %{service_id: System.get_env("SERVICE_ID")}
  end

  describe "PS2.Socket" do
    test "can start up with a service ID", %{service_id: sid} do
      assert {:ok, _pid} = PS2.Socket.start_link(service_id: sid)
    end

    test "will not start without a service ID" do
      message = PS2.Socket.no_sid_error_message()
      assert {:stop, ^message} = PS2.Socket.start_link(subscriptions: @default_subs, clients: [])
    end

    test "can distribute GainExperience events to a SocketClient", %{service_id: sid} do
      assert true = Process.register(self(), :test_one_client)

      {:ok, _pid} =
        PS2.Socket.start_link(
          subscriptions: @default_subs,
          clients: [TestClient],
          service_id: sid
        )

      assert_receive {TestClient, "GainExperience"}, 5000
    end

    test "can distribute GainExperience events to many SocketClients", %{service_id: sid} do
      assert true = Process.register(self(), :test_two_clients)

      {:ok, _pid} =
        PS2.Socket.start_link(
          subscriptions: @default_subs,
          clients: [OtherTestClient, AnotherTestClient],
          service_id: sid
        )

      assert_receive {OtherTestClient, "GainExperience"}, 5000
      assert_receive {AnotherTestClient, "GainExperience"}, 5000
    end
  end
end

defmodule TestClient do
  @moduledoc false
  @behaviour PS2.SocketClient

  @impl PS2.SocketClient
  def handle_event({"GainExperience", _payload}),
    do: send(:test_one_client, {TestClient, "GainExperience"})

  @impl PS2.SocketClient
  def handle_event({_event, _payload}), do: nil
end

defmodule OtherTestClient do
  @moduledoc false
  @behaviour PS2.SocketClient

  @impl PS2.SocketClient
  def handle_event({"GainExperience", _payload}),
    do: send(:test_two_clients, {OtherTestClient, "GainExperience"})

  @impl PS2.SocketClient
  def handle_event({_event, _payload}), do: nil
end

defmodule AnotherTestClient do
  @moduledoc false
  @behaviour PS2.SocketClient

  @impl PS2.SocketClient
  def handle_event({"GainExperience", _payload}),
    do: send(:test_two_clients, {AnotherTestClient, "GainExperience"})

  @impl PS2.SocketClient
  def handle_event({_event, _payload}), do: nil
end
