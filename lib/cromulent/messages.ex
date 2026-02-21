defmodule Cromulent.Messages do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Messages.Message
  alias Cromulent.Channels

  @page_size 50

  def list_messages(channel_id) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], desc: m.id)
    |> limit(@page_size)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()  # back to chronological order
  end

    def list_messages_before(channel_id, before_id) do
    Message
    |> where([m], m.channel_id == ^channel_id and m.id < ^before_id)
    |> order_by([m], desc: m.id)
    |> limit(@page_size)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end


  def create_message(user, channel, attrs) do
    if Channels.can_write?(user, channel) do
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :permission_denied}
    end
  end
end
