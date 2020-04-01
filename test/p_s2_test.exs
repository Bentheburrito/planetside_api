defmodule PS2Test do
  use ExUnit.Case
  doctest PS2

  test "greets the world" do
    assert PS2.hello() == :world
  end
end
