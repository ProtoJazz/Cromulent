defmodule Cromulent.Channels do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Channels.Channel

  def list_channels do
    Repo.all(from c in Channel, order_by: [asc: c.inserted_at])
  end

  def get_channel(id) do
    Repo.get(Channel, id)
  end

  def get_channel_by_name(name) do
    Repo.get_by(Channel, name: name)
  end

  def get_channel_by_slug(slug) do
    Repo.get_by(Channel, slug: slug)
  end

  def create_channel(attrs) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end
end
