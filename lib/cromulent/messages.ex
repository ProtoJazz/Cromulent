defmodule Cromulent.Messages do
  alias Cromulent.Accounts.User

  @homer %User{id: 55, email: "homer@springfield.com"}
  @marge %User{id: 56, email: "marge@springfield.com"}
  @bart %User{id: 57, email: "bart@springfield.com"}
  @lisa %User{id: 58, email: "lisa@springfield.com"}
  @burns %User{id: 59, email: "burns@springfield.com"}
  @moe %User{id: 60, email: "moe@springfield.com"}

  @messages %{
    "general" => [
      %{id: 1, user: @homer, body: "D'oh! Wrong channel again.", inserted_at: ~U[2026-02-16 14:00:00Z]},
      %{id: 2, user: @marge, body: "Homer, this IS the general channel.", inserted_at: ~U[2026-02-16 14:01:00Z]},
      %{id: 3, user: @bart, body: "Eat my shorts!", inserted_at: ~U[2026-02-16 14:02:30Z]},
      %{id: 4, user: @lisa, body: "Can we please keep this channel on topic?", inserted_at: ~U[2026-02-16 14:03:00Z]},
      %{id: 5, user: @homer, body: "Mmm... donuts.", inserted_at: ~U[2026-02-16 14:05:00Z]},
      %{id: 6, user: @burns, body: "Excellent.", inserted_at: ~U[2026-02-16 14:06:00Z]},
      %{id: 7, user: @marge, body: "Has anyone seen the cat?", inserted_at: ~U[2026-02-16 14:10:00Z]},
      %{id: 8, user: @bart, body: "Ay caramba!", inserted_at: ~U[2026-02-16 14:11:00Z]},
      %{id: 9, user: @homer, body: "Marge, can you bring me a beer?", inserted_at: ~U[2026-02-16 14:15:00Z]},
      %{id: 10, user: @marge, body: "Get it yourself, Homer.", inserted_at: ~U[2026-02-16 14:15:30Z]},
      %{id: 11, user: @lisa, body: "Did everyone do the assigned reading for today?", inserted_at: ~U[2026-02-16 14:18:00Z]},
      %{id: 12, user: @bart, body: "There was assigned reading?", inserted_at: ~U[2026-02-16 14:18:30Z]},
      %{id: 13, user: @burns, body: "Smithers, who are all these people?", inserted_at: ~U[2026-02-16 14:20:00Z]},
      %{id: 14, user: @moe, body: "Hey Homer, you still owe me for last Tuesday.", inserted_at: ~U[2026-02-16 14:22:00Z]},
      %{id: 15, user: @homer, body: "Put it on my tab.", inserted_at: ~U[2026-02-16 14:22:30Z]},
      %{id: 16, user: @moe, body: "Your tab is longer than my arm, Homer.", inserted_at: ~U[2026-02-16 14:23:00Z]},
      %{id: 17, user: @lisa, body: "I just finished my college application essay. Want to proofread it?", inserted_at: ~U[2026-02-16 14:25:00Z]},
      %{id: 18, user: @bart, body: "Hard pass.", inserted_at: ~U[2026-02-16 14:25:15Z]},
      %{id: 19, user: @marge, body: "I'd love to read it, sweetie!", inserted_at: ~U[2026-02-16 14:25:45Z]},
      %{id: 20, user: @homer, body: "College? Pfft. I didn't go to college and look how I turned out.", inserted_at: ~U[2026-02-16 14:26:00Z]},
      %{id: 21, user: @burns, body: "I went to Yale. Twice, actually. Once as a student, once to buy it.", inserted_at: ~U[2026-02-16 14:28:00Z]},
      %{id: 22, user: @bart, body: "Who wants to go to the Kwik-E-Mart?", inserted_at: ~U[2026-02-16 14:30:00Z]},
      %{id: 23, user: @homer, body: "Ooh! Get me a Squishee!", inserted_at: ~U[2026-02-16 14:30:15Z]},
      %{id: 24, user: @marge, body: "Nobody is going anywhere until homework is done.", inserted_at: ~U[2026-02-16 14:31:00Z]},
      %{id: 25, user: @bart, body: "I don't believe in homework. It's against my religion.", inserted_at: ~U[2026-02-16 14:31:30Z]},
      %{id: 26, user: @lisa, body: "Since when?", inserted_at: ~U[2026-02-16 14:31:45Z]},
      %{id: 27, user: @homer, body: "The boy makes a good point, Marge.", inserted_at: ~U[2026-02-16 14:32:00Z]},
      %{id: 28, user: @marge, body: "Hmmmm.", inserted_at: ~U[2026-02-16 14:32:30Z]},
      %{id: 29, user: @moe, body: "Anybody seen Barney? He left his tab open.", inserted_at: ~U[2026-02-16 14:35:00Z]},
      %{id: 30, user: @burns, body: "I must say, this digital communication contraption is rather amusing.", inserted_at: ~U[2026-02-16 14:38:00Z]}
    ],
    "random" => [
      %{id: 31, user: @moe, body: "Is there a Hugh Jass here?", inserted_at: ~U[2026-02-16 13:00:00Z]},
      %{id: 32, user: @homer, body: "I am so smart! S-M-R-T!", inserted_at: ~U[2026-02-16 13:05:00Z]},
      %{id: 33, user: @lisa, body: "If anyone wants to practice saxophone, I'm in.", inserted_at: ~U[2026-02-16 13:10:00Z]},
      %{id: 34, user: @burns, body: "Release the hounds.", inserted_at: ~U[2026-02-16 13:15:00Z]},
      %{id: 35, user: @bart, body: "Nobody better lay a finger on my Butterfinger.", inserted_at: ~U[2026-02-16 13:20:00Z]},
      %{id: 36, user: @moe, body: "I'm gonna have to ask you to leave.", inserted_at: ~U[2026-02-16 13:25:00Z]},
      %{id: 37, user: @homer, body: "To alcohol! The cause of, and solution to, all of life's problems.", inserted_at: ~U[2026-02-16 13:30:00Z]},
      %{id: 38, user: @bart, body: "I didn't do it. Nobody saw me do it. You can't prove anything.", inserted_at: ~U[2026-02-16 13:35:00Z]},
      %{id: 39, user: @lisa, body: "The whole reason we have elected officials is so we don't have to think all the time.", inserted_at: ~U[2026-02-16 13:40:00Z]},
      %{id: 40, user: @marge, body: "Homer, you have the emotional maturity of a teenager.", inserted_at: ~U[2026-02-16 13:45:00Z]},
      %{id: 41, user: @homer, body: "Thanks, Marge!", inserted_at: ~U[2026-02-16 13:45:30Z]},
      %{id: 42, user: @burns, body: "I could crush him like an ant. But it would be too easy.", inserted_at: ~U[2026-02-16 13:50:00Z]},
      %{id: 43, user: @moe, body: "Amanda Hugginkiss? Hey, I'm looking for Amanda Hugginkiss!", inserted_at: ~U[2026-02-16 13:55:00Z]},
      %{id: 44, user: @bart, body: "Cowabunga, dude!", inserted_at: ~U[2026-02-16 14:00:00Z]},
      %{id: 45, user: @homer, body: "Facts are meaningless. You could use facts to prove anything that's even remotely true.", inserted_at: ~U[2026-02-16 14:05:00Z]},
      %{id: 46, user: @lisa, body: "That doesn't even make sense, Dad.", inserted_at: ~U[2026-02-16 14:05:30Z]},
      %{id: 47, user: @marge, body: "Kids, stop fighting. Eat your French fries.", inserted_at: ~U[2026-02-16 14:10:00Z]},
      %{id: 48, user: @burns, body: "What good is money if it can't inspire terror in your fellow man?", inserted_at: ~U[2026-02-16 14:15:00Z]},
      %{id: 49, user: @moe, body: "I've been called ugly, pug-ugly, fugly, pug-fugly, but never ugly-ugly.", inserted_at: ~U[2026-02-16 14:20:00Z]},
      %{id: 50, user: @homer, body: "Operator! Give me the number for 911!", inserted_at: ~U[2026-02-16 14:25:00Z]}
    ]
  }

  @user_messages [
    "Hey everyone, just got here!",
    "lol",
    "That's hilarious",
    "Can someone explain what's going on?",
    "brb"
  ]

  def list_messages(channel_id, current_user) do
    messages = Map.get(@messages, channel_id, [])
    inject_user_messages(messages, current_user)
  end

  defp inject_user_messages(messages, current_user) do
    # Sprinkle in a few messages from the current user at fixed positions
    positions = [4, 12, 20]

    positions
    |> Enum.with_index()
    |> Enum.reduce(messages, fn {pos, idx}, acc ->
      if pos < length(acc) and idx < length(@user_messages) do
        msg = %{
          id: 1000 + idx,
          user: current_user,
          body: Enum.at(@user_messages, idx),
          inserted_at: Enum.at(acc, pos).inserted_at
        }

        List.insert_at(acc, pos, msg)
      else
        acc
      end
    end)
  end
end
