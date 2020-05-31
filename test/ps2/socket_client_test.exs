defmodule PS2.SocketClientTest do
	use ExUnit.Case
	doctest PS2.SocketClient

	describe "SocketClient" do
		test "can start without subscriptions" do
			assert {:ok, _} = PS2.TestClient.start_link([])
		end

		test "can start with a :name option" do
			assert {:ok, _} = PS2.TestClient.start_link([name: PS2.TestClient])
		end

		test "receives messages and invokes callbacks" do

			{:ok, client} = PS2.TestClient.start_link([events: ["FacilityControl", "VehicleDestroy", "GainExperience"], worlds: ["Connery", "Miller", "Cobalt", "Emerald"], characters: ["all"]])
			:erlang.trace(client, true, [:receive])

			send(client, {:GAME_EVENT, {"VehicleDestroy", %{:character_id => "1", "test_pid" => self()}}})
			send(client, {:GAME_EVENT, {"PlayerLogin", %{:character_id => "1", "test_pid" => self()}}})

			assert_receive {:vehicle_destroy, "1"}
			assert_receive {:unhandled_event, "1"}

			assert_receive {:trace, ^client, :receive, {:STATUS_EVENT, {"Subscribed", _payload}}}
			assert_receive {:trace, ^client, :receive, {:GAME_EVENT, {"GainExperience", _payload}}}
		end
	end
end

defmodule PS2.TestClient do
	@moduledoc false
	use PS2.SocketClient

	def start_link(subscriptions) do
		PS2.SocketClient.start_link(__MODULE__, subscriptions)
	end

	@impl PS2.SocketClient
	def handle_event({"VehicleDestroy", payload}), do: if payload[:character_id] === "1", do: send(payload["test_pid"], {:vehicle_destroy, "1"})

	@impl PS2.SocketClient
	def handle_event({_event, payload}), do: if payload[:character_id] === "1", do: send(payload["test_pid"], {:unhandled_event, "1"})
end
