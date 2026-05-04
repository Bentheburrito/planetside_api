defmodule PS2.ESS.Subscription do
  @enforce_keys ~w|characters events worlds logical_and_characters_with_worlds|a
  defstruct characters: :all,
            clear?: false,
            events: :all,
            worlds: :all,
            logical_and_characters_with_worlds: false

  @opaque t() :: %__MODULE__{
            characters: MapSet.t() | :all,
            clear?: boolean(),
            events: MapSet.t() | :all,
            worlds: MapSet.t() | :all,
            logical_and_characters_with_worlds: boolean()
          }

  @set_keys ~w|characters events worlds|a

  def new(nil), do: nil
  def new(%__MODULE__{} = sub), do: sub
  def new(attrs), do: struct(__MODULE__, map_attrs(attrs))

  defp map_attrs(attrs) do
    Enum.map(attrs, fn
      {k, v} when k in @set_keys and is_list(v) -> {k, MapSet.new(v)}
      {k, v} -> {k, v}
    end)
  end

  def merge(sub, sub), do: sub

  def merge(%__MODULE__{} = sub, sub_or_attrs) when not is_nil(sub_or_attrs) do
    %__MODULE__{} = sub2 = new(sub_or_attrs)
    clear? = sub2.clear?

    merged_set_attrs = Enum.map(@set_keys, &{&1, merge_sub_set(Map.fetch!(sub, &1), Map.fetch!(sub2, &1), clear?)})

    attrs =
      Keyword.merge(merged_set_attrs,
        clear?: false,
        logical_and_characters_with_worlds: sub2.logical_and_characters_with_worlds
      )

    struct!(sub, attrs)
  end

  defp merge_sub_set(maybe_all, maybe_all2, false) when :all in [maybe_all, maybe_all2], do: :all
  # this case is not really doable - just keep it :all
  defp merge_sub_set(:all, %MapSet{}, true), do: :all
  defp merge_sub_set(maybe_all, maybe_all2, true) when :all in [maybe_all, maybe_all2], do: MapSet.new()
  defp merge_sub_set(%MapSet{} = set1, %MapSet{} = set2, false), do: MapSet.union(set1, set2)
  defp merge_sub_set(%MapSet{} = set1, %MapSet{} = set2, true), do: MapSet.difference(set1, set2)

  def summary(nil), do: "no subscriptions"

  def summary(%__MODULE__{} = sub) do
    char_count = set_summary(sub.characters)
    events_count = set_summary(sub.events)
    worlds_count = set_summary(sub.worlds)
    chars_and_worlds_op = if sub.logical_and_characters_with_worlds, do: "AND", else: "OR"

    "#{events_count} events for #{char_count} chars #{chars_and_worlds_op} #{worlds_count} worlds"
  end

  defp set_summary(:all), do: "all"
  defp set_summary(%MapSet{} = set), do: MapSet.size(set)

  defimpl JSON.Encoder do
    def encode(sub, opts) do
      action = if sub.clear?, do: "clearSubscribe", else: "subscribe"

      JSON.Encoder.Map.encode(
        %{
          "service" => "event",
          "action" => action,
          "characters" => encode_set(sub.characters),
          "worlds" => encode_set(sub.worlds),
          "eventNames" => encode_set(sub.events)
        },
        opts
      )
    end

    defp encode_set(:all), do: ["all"]
    defp encode_set(%MapSet{} = set), do: Enum.map(set, &to_string/1)
  end
end
