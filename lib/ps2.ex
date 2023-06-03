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

  @doc """
  A custom heartbeat event that clients can consume. Emitted whenever the ESS sends a `%{"online" => %{...}}` message
  to the Socket (approximately every 30 seconds).
  """
  def server_health_update, do: "ServerHealthUpdate"
end
