defmodule Cromulent.FeatureFlags do
  @moduledoc """
  Context for operator-controlled feature flags stored in the database.
  All flags default to safe values when no DB row exists (no crash on fresh install).
  """
  alias Cromulent.Repo
  alias Cromulent.FeatureFlags.Flags

  @doc "Returns current feature flags, or struct defaults if no row exists."
  def get_flags do
    Repo.one(Flags) || %Flags{}
  end

  @doc "Upserts the feature flags row. Returns {:ok, flags} or {:error, changeset}."
  def upsert_flags(attrs) do
    case get_flags() do
      %Flags{id: nil} = defaults ->
        defaults
        |> Flags.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> Flags.changeset(attrs)
        |> Repo.update()
    end
  end
end
