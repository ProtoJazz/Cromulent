defmodule Cromulent.VoiceState do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def join(user_id, channel), do: Agent.update(__MODULE__, &Map.put(&1, user_id, channel))
  def leave(user_id), do: Agent.update(__MODULE__, &Map.delete(&1, user_id))
  def get(user_id), do: Agent.get(__MODULE__, &Map.get(&1, user_id))
end
