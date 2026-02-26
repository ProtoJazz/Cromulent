defmodule Cromulent.Groups.GroupMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "group_memberships" do
    belongs_to :group, Cromulent.Groups.Group
    belongs_to :user, Cromulent.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:group_id, :user_id])
    |> validate_required([:group_id, :user_id])
    |> unique_constraint([:group_id, :user_id])
  end
end
