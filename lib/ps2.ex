defmodule PS2 do
  @moduledoc """
  Base module for :planetside_api. Provides convenience functions for world/server IDs and event names.
  """

  def connery, do: 1
  def miller, do: 10
  def cobalt, do: 13
  def emerald, do: 17
  def jaeger, do: 19
  def briggs, do: 25
  def soltech, do: 40

  def achievement_earned, do: "AchievementEarned"
  def battle_rank_up, do: "BattleRankUp"
  def death, do: "Death"
  def facility_control, do: "FacilityControl"
  def gain_experience, do: "GainExperience"
  def gain_experience(id), do: "GainExperience_experience_id_#{id}"
  def item_added, do: "ItemAdded"
  def metagame_event, do: "MetagameEvent"
  def player_facility_capture, do: "PlayerFacilityCapture"
  def player_facility_defend, do: "PlayerFacilityDefend"
  def player_login, do: "PlayerLogin"
  def player_logout, do: "PlayerLogout"
  def skill_added, do: "SkillAdded"
  def vehicle_destroy, do: "VehicleDestroy"
  def continent_lock, do: "ContinentLock"
  def continent_unlock, do: "ContinentUnlock"

  # via https://dorgan.netlify.app/posts/2021/04/the_elixir_ast_typedstruct/
  defmacro typedstruct(do: ast) do
    fields_ast =
      case ast do
        {:__block__, [], fields} -> fields
        field -> [field]
      end

    fields_data = Enum.map(fields_ast, &get_field_data/1)

    enforced_fields =
      for field <- fields_data, field.enforced? do
        field.name
      end

    typespecs =
      Enum.map(fields_data, fn
        %{name: name, typespec: typespec, enforced?: true} ->
          {name, typespec}

        %{name: name, typespec: typespec} ->
          {
            name,
            {:|, [], [typespec, nil]}
          }
      end)

    fields =
      for %{name: name, default: default} <- fields_data do
        {name, default}
      end

    quote location: :keep do
      @type t :: %__MODULE__{unquote_splicing(typespecs)}
      @enforce_keys unquote(enforced_fields)
      defstruct unquote(fields)
    end
  end

  defp get_field_data({:field, _meta, [name, typespec]}) do
    get_field_data({:field, [], [name, typespec, []]})
  end

  defp get_field_data({:field, _meta, [name, typespec, opts]}) do
    default = Keyword.get(opts, :default)
    enforced? = Keyword.get(opts, :enforced?, false)

    %{
      name: name,
      typespec: typespec,
      default: default,
      enforced?: enforced?
    }
  end
end
