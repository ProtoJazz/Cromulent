defmodule Cromulent.UUID7 do
  use Ecto.Type

  def type, do: :uuid

  def cast(value), do: Ecto.UUID.cast(value)

  def load(value), do: Ecto.UUID.load(value)

  def dump(value), do: Ecto.UUID.dump(value)

  def autogenerate, do: Uniq.UUID.uuid7()
end
