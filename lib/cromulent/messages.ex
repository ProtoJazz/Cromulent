defmodule Cromulent.Messages do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Messages.Message

  def list_messages(channel_id) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], asc: m.inserted_at)
    |> limit(50)
    |> preload(:user)
    |> Repo.all()
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end
end
