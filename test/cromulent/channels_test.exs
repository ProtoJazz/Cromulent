defmodule Cromulent.ChannelsTest do
  use Cromulent.DataCase

  alias Cromulent.Channels
  import Cromulent.AccountsFixtures

  defp channel_fixture(attrs \\ %{}) do
    {:ok, channel} =
      attrs
      |> Enum.into(%{name: "test-channel-#{System.unique_integer()}", type: :text})
      |> Channels.create_channel()

    channel
  end

  describe "list_joined_channels/2" do
    test "returns all joined channels when voice_enabled is true (default)" do
      user = user_fixture()
      text_ch = channel_fixture(%{name: "text-ch-#{System.unique_integer()}", type: :text})
      voice_ch = channel_fixture(%{name: "voice-ch-#{System.unique_integer()}", type: :voice})

      Channels.join_channel(user, text_ch)
      Channels.join_channel(user, voice_ch)

      channels = Channels.list_joined_channels(user)

      ids = Enum.map(channels, & &1.id)
      assert text_ch.id in ids
      assert voice_ch.id in ids
    end

    test "excludes voice channels when voice_enabled is false" do
      user = user_fixture()
      text_ch = channel_fixture(%{name: "text-ch2-#{System.unique_integer()}", type: :text})
      voice_ch = channel_fixture(%{name: "voice-ch2-#{System.unique_integer()}", type: :voice})

      Channels.join_channel(user, text_ch)
      Channels.join_channel(user, voice_ch)

      channels = Channels.list_joined_channels(user, false)

      ids = Enum.map(channels, & &1.id)
      assert text_ch.id in ids
      refute voice_ch.id in ids
    end

    test "includes voice channels when voice_enabled is explicitly true" do
      user = user_fixture()
      voice_ch = channel_fixture(%{name: "voice-ch3-#{System.unique_integer()}", type: :voice})

      Channels.join_channel(user, voice_ch)

      channels = Channels.list_joined_channels(user, true)
      ids = Enum.map(channels, & &1.id)
      assert voice_ch.id in ids
    end

    test "returns empty list when user has no joined channels" do
      user = user_fixture()
      assert [] == Channels.list_joined_channels(user, false)
      assert [] == Channels.list_joined_channels(user, true)
    end
  end
end
