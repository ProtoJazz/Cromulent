defmodule Cromulent.Groups do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Groups.{Group, GroupMembership}

  # ── Queries ────────────────────────────────────────────────────────────────

  def list_groups do
    Group
    |> order_by([g], g.name)
    |> preload(:memberships)
    |> Repo.all()
  end

  def get_group!(id), do: Repo.get!(Group, id)

  def get_group_by_slug(slug) do
    Repo.get_by(Group, slug: slug)
  end

  # Returns all groups as a map of %{slug => group} for fast mention lookups
  def groups_by_slug do
    list_groups()
    |> Map.new(&{&1.slug, &1})
  end

  # Returns user_ids for all members of a group
  def user_ids_for_group(group_id) do
    from(m in GroupMembership,
      where: m.group_id == ^group_id,
      select: m.user_id
    )
    |> Repo.all()
  end

  # ── Mutations ──────────────────────────────────────────────────────────────

  def create_group(attrs) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  def add_user_to_group(group_id, user_id) do
    %GroupMembership{}
    |> GroupMembership.changeset(%{group_id: group_id, user_id: user_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:group_id, :user_id])
  end

  def remove_user_from_group(group_id, user_id) do
    from(m in GroupMembership,
      where: m.group_id == ^group_id and m.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  def member_of_group?(group_id, user_id) do
    from(m in GroupMembership,
      where: m.group_id == ^group_id and m.user_id == ^user_id
    )
    |> Repo.exists?()
  end
end
