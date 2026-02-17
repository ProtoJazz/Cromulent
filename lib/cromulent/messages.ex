defmodule Cromulent.Messages do
  alias Cromulent.Accounts.User

  @homer %User{id: 1, email: "homer@springfield.com"}
  @marge %User{id: 2, email: "marge@springfield.com"}
  @bart %User{id: 3, email: "bart@springfield.com"}
  @lisa %User{id: 4, email: "lisa@springfield.com"}
  @burns %User{id: 5, email: "burns@springfield.com"}
  @moe %User{id: 6, email: "moe@springfield.com"}

  @messages %{
    "general" => [
      %{id: 1, user: @homer, body: "D'oh! Wrong channel again.", inserted_at: ~U[2026-02-16 14:00:00Z]},
      %{id: 2, user: @marge, body: "Homer, this IS the general channel.", inserted_at: ~U[2026-02-16 14:01:00Z]},
      %{id: 3, user: @bart, body: "Eat my shorts!", inserted_at: ~U[2026-02-16 14:02:30Z]},
      %{id: 4, user: @lisa, body: "Can we please keep this channel on topic?", inserted_at: ~U[2026-02-16 14:03:00Z]},
      %{id: 5, user: @homer, body: "Mmm... donuts.", inserted_at: ~U[2026-02-16 14:05:00Z]},
      %{id: 6, user: @burns, body: "Excellent.", inserted_at: ~U[2026-02-16 14:06:00Z]},
      %{id: 7, user: @marge, body: "Has anyone seen the cat?", inserted_at: ~U[2026-02-16 14:10:00Z]},
      %{id: 8, user: @bart, body: "Ay caramba!", inserted_at: ~U[2026-02-16 14:11:00Z]}
    ],
    "random" => [
      %{id: 9, user: @moe, body: "Is there a Hugh Jass here?", inserted_at: ~U[2026-02-16 13:00:00Z]},
      %{id: 10, user: @homer, body: "I am so smart! S-M-R-T!", inserted_at: ~U[2026-02-16 13:05:00Z]},
      %{id: 11, user: @lisa, body: "If anyone wants to practice saxophone, I'm in.", inserted_at: ~U[2026-02-16 13:10:00Z]},
      %{id: 12, user: @burns, body: "Release the hounds.", inserted_at: ~U[2026-02-16 13:15:00Z]},
      %{id: 13, user: @bart, body: "Nobody better lay a finger on my Butterfinger.", inserted_at: ~U[2026-02-16 13:20:00Z]},
      %{id: 14, user: @moe, body: "I'm gonna have to ask you to leave.", inserted_at: ~U[2026-02-16 13:25:00Z]}
    ]
  }

  def list_messages(channel_id) do
    Map.get(@messages, channel_id, [])
  end
end
