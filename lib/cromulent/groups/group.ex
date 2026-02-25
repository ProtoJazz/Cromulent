defmodule Cromulent.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Cromulent.UUID7, autogenerate: true}
  @foreign_key_type :binary_id

  schema "groups" do
    field :name, :string
    field :slug, :string
    field :color, :string

    has_many :memberships, Cromulent.Groups.GroupMembership
    has_many :users, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :color])
    |> validate_required([:name])
    |> then(fn cs ->
      put_change(cs, :slug, slugify(get_field(cs, :name) || ""))
    end)
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
