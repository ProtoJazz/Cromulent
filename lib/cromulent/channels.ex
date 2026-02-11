defmodule Cromulent.Channels do
  def list_channels do
    Application.get_env(:cromulent, :channels, [])
  end

  def get_channel(id) do
    list_channels() |> Enum.find(&(&1.id == id))
  end
end
