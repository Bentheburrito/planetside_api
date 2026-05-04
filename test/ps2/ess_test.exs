defmodule PS2.ESSTest do
  alias PS2.ESS.Subscription
  use ExUnit.Case
  doctest PS2.ESS

  @default_sub Subscription.new(events: [PS2.gain_experience()], worlds: :all, characters: :all)
  @test_opts [service_id: System.fetch_env!("SERVICE_ID"), subscription: @default_sub, callback_mod: TestCallback]

  test "calls `callback_mod.handle_event/1` for each event" do
    start_supervised!({Registry, keys: :duplicate, name: TestPIDs})
    Registry.register(TestPIDs, "GainExperience", nil)
    Registry.register(TestPIDs, "Death", nil)

    {:ok, pid} = PS2.ESS.start_link(@test_opts)

    assert_receive "GainExperience", 1000
    refute_received "Death"

    PS2.ESS.subscribe(pid, Subscription.new(events: [PS2.death()]))

    assert_receive "Death", 1000
  end
end

defmodule TestCallback do
  @behaviour PS2.ESS

  @impl PS2.ESS
  def handle_event(%{"event_name" => event_name}) do
    for {pid, _} <- Registry.lookup(TestPIDs, event_name), do: send(pid, event_name)
  end
end
