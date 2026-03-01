defmodule Cromulent.Channels do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Channels.Channel
  alias Cromulent.Channels.ChannelMembership

  def list_channels do
    Repo.all(from c in Channel, order_by: [asc: c.inserted_at])
  end

  # Channels visible to a given user:
  # - All non-private channels
  # - Private channels they're a member of
  # Admins see everything.
  def list_visible_channels(user) do
    if user.role == :admin do
      list_channels()
    else
      from(c in Channel,
        left_join: m in ChannelMembership,
        on: m.channel_id == c.id and m.user_id == ^user.id,
        where: c.is_private == false or not is_nil(m.user_id),
        order_by: [asc: c.inserted_at]
      )
      |> Repo.all()
    end
  end

  def list_joinable_channels(user, type) do
    from(c in Channel,
      left_join: m in ChannelMembership,
      on: m.channel_id == c.id and m.user_id == ^user.id,
      where: is_nil(m.user_id) and c.is_private == false and c.type == ^type,
      order_by: [asc: c.name]
    )
    |> Repo.all()
  end

  def list_channel_member_ids(channel_id) do
    from(m in ChannelMembership,
      where: m.channel_id == ^channel_id,
      select: m.user_id
    )
    |> Repo.all()
  end

  # Channels a user is a member of (for sidebar)
  def list_joined_channels(user) do
    from(c in Channel,
      join: m in ChannelMembership,
      on: m.channel_id == c.id and m.user_id == ^user.id,
      order_by: [asc: c.inserted_at]
    )
    |> Repo.all()
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
    |> case do
      {:ok, channel} = result ->
        if channel.is_default && !channel.is_private do
          enroll_all_users(channel)
        end

        result

      error ->
        error
    end
  end

  def can_write?(%{role: :admin}, _channel), do: true
  def can_write?(_user, %Channel{write_permission: :everyone}), do: true
  def can_write?(_user, %Channel{write_permission: :admin_only}), do: false

  def delete_channel(%Cromulent.Channels.Channel{} = channel) do
    Cromulent.Repo.delete(channel)
  end

  def get_channel!(id) do
    Cromulent.Repo.get!(Cromulent.Channels.Channel, id)
  end

  def join_channel(_user, %Channel{is_private: true}) do
    #eventually private channel permissions go here
    {:error, :private_channel}
  end

  def join_channel(user, channel) do
    %ChannelMembership{}
    |> ChannelMembership.changeset(%{
      channel_id: channel.id,
      user_id: user.id,
      joined_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def set_default(%Cromulent.Channels.Channel{} = channel, default) do
    channel|>
    Channel.changeset(%{
      is_default: default
    })
    |> Repo.update!
  end

  def leave_channel(user, channel) do
    from(m in ChannelMembership,
      where: m.channel_id == ^channel.id and m.user_id == ^user.id
    )
    |> Repo.delete_all()
  end

  def member?(%{role: :admin}, _channel), do: true

  def member?(user, channel) do
    Repo.exists?(
      from m in ChannelMembership,
        where: m.channel_id == ^channel.id and m.user_id == ^user.id
    )
  end

  def list_members(channel) do
    from(u in Cromulent.Accounts.User,
      join: m in ChannelMembership,
      on: m.user_id == u.id,
      where: m.channel_id == ^channel.id,
      order_by: [asc: u.username]
    )
    |> Repo.all()
  end

  def enroll_in_default_channels(user) do
    default_channels =
      from(c in Channel, where: c.is_default == true and c.is_private == false)
      |> Repo.all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    memberships =
      Enum.map(default_channels, fn channel ->
        %{channel_id: channel.id, user_id: user.id, joined_at: now}
      end)

    Repo.insert_all(ChannelMembership, memberships, on_conflict: :nothing)
  end

  defp enroll_all_users(channel) do
    users = Repo.all(Cromulent.Accounts.User)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    memberships =
      Enum.map(users, fn user ->
        %{channel_id: channel.id, user_id: user.id, joined_at: now}
      end)

    Repo.insert_all(ChannelMembership, memberships, on_conflict: :nothing)
  end

  def add_member(user, channel) do
    %ChannelMembership{}
    |> ChannelMembership.changeset(%{
      channel_id: channel.id,
      user_id: user.id,
      joined_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def remove_member(user, channel) do
    leave_channel(user, channel)
  end
end
