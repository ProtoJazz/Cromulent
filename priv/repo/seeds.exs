# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Cromulent.Repo.insert!(%Cromulent.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
# priv/repo/seeds.exs
#
# Run with: mix run priv/repo/seeds.exs
# Or as part of: mix ecto.reset

alias Cromulent.Repo
alias Cromulent.Accounts
alias Cromulent.Accounts.User
alias Cromulent.Channels
alias Cromulent.Channels.Channel
alias Cromulent.Messages
alias Cromulent.Messages.Message

import Ecto.Query

# ─── Helpers ──────────────────────────────────────────────────────────────────
IO.puts("Seeds starting...")
defmodule Seeds.Helpers do
  IO.puts("Seeds starting...")
  def find_or_create_user(attrs) do
    case Repo.get_by(User, email: attrs.email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{
          email: attrs.email,
          password: attrs.password,
          username: attrs.username
        })
        user

      user ->
        user
    end
  end

  def find_channel_by_name(name) do
    Repo.get_by(Channel, name: name)
  end

  def insert_message(channel, user, body, inserted_at) do
    %Message{}
    |> Message.changeset(%{
      channel_id: channel.id,
      user_id: user.id,
      body: body
    })
    |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
    |> Repo.insert!(on_conflict: :nothing)
  end

  # Space messages out starting from a base time, with small random-ish offsets
  def timestamps(base_datetime, count, spacing_seconds \\ 90) do
    for i <- 0..(count - 1) do
      jitter = rem(i * 37 + i * i, 45)
      DateTime.add(base_datetime, i * spacing_seconds + jitter, :second)
    end
  end
end

IO.puts("Creating channels...")

general_channel =
  case Cromulent.Channels.get_channel_by_name("general") do
    nil ->
      {:ok, ch} = Cromulent.Channels.create_channel(%{name: "general", type: :text})
      ch
    ch -> ch
  end

random_channel =
  case Cromulent.Channels.get_channel_by_name("random") do
    nil ->
      {:ok, ch} = Cromulent.Channels.create_channel(%{name: "random", type: :text})
      ch
    ch -> ch
  end

_voice_channel =
  case Cromulent.Channels.get_channel_by_name("voice-main") do
    nil ->
      {:ok, ch} = Cromulent.Channels.create_channel(%{name: "voice-main", type: :voice})
      ch
    ch -> ch
  end

IO.puts("Channels ready.")

# ─── Users ────────────────────────────────────────────────────────────────────

IO.puts("Creating users...")

# Simpsons crew (for #random)
homer   = Seeds.Helpers.find_or_create_user(%{email: "homer@springfield.gov",   username: "homer_s",    password: "donutsdonuts123"})
marge   = Seeds.Helpers.find_or_create_user(%{email: "marge@springfield.gov",   username: "marge_s",    password: "donutsdonuts123"})
bart    = Seeds.Helpers.find_or_create_user(%{email: "bart@springfield.gov",     username: "el_barto",   password: "donutsdonuts123"})
lisa    = Seeds.Helpers.find_or_create_user(%{email: "lisa@springfield.gov",     username: "lisa_s",     password: "donutsdonuts123"})
burns   = Seeds.Helpers.find_or_create_user(%{email: "burns@montsimco.com",      username: "mrburns",    password: "donutsdonuts123"})
moe     = Seeds.Helpers.find_or_create_user(%{email: "moe@moestav.com",          username: "moe_szys",   password: "donutsdonuts123"})

# Stormlight crew (for #general)
kaladin = Seeds.Helpers.find_or_create_user(%{email: "kaladin@windrunners.org",  username: "kaladin",    password: "goblessedbythestorms1"})
shallan = Seeds.Helpers.find_or_create_user(%{email: "shallan@house-davar.com",  username: "shallan_d",  password: "goblessedbythestorms1"})
dalinar = Seeds.Helpers.find_or_create_user(%{email: "dalinar@kholin.com",       username: "the_blackthorn", password: "goblessedbythestorms1"})
adolin  = Seeds.Helpers.find_or_create_user(%{email: "adolin@kholin.com",        username: "adolin_k",   password: "goblessedbythestorms1"})
szeth   = Seeds.Helpers.find_or_create_user(%{email: "szeth@truthless.net",      username: "szeth",      password: "goblessedbythestorms1"})
navani  = Seeds.Helpers.find_or_create_user(%{email: "navani@kholin.com",        username: "navani_k",   password: "goblessedbythestorms1"})

IO.puts("Users created.")

# ─── Channels ─────────────────────────────────────────────────────────────────
# NOTE: Cromulent currently hardcodes channels in config. These seeds assume
# "general" and "random" text channels already exist in the DB. If your
# migration creates them automatically, those rows will be found here.
# If not, create them:

general_channel = case Seeds.Helpers.find_channel_by_name("general") do
  nil ->
    Repo.insert!(%Channel{name: "general", type: :text})
  ch -> ch
end

random_channel = case Seeds.Helpers.find_channel_by_name("random") do
  nil ->
    Repo.insert!(%Channel{name: "random", type: :text})
  ch -> ch
end

IO.puts("Channels ready.")

# ─── #general — Stormlight Archive themed ─────────────────────────────────────
IO.puts("Seeding #general (Stormlight Archive)...")

base = ~U[2026-02-16 10:00:00Z]
times = Seeds.Helpers.timestamps(base, 40)

general_messages = [
  {kaladin, "Another highstorm last night. Lost two practice dummies off the plateau. Bridge Four is fine though."},
  {shallan,  "I sketched the storm from the window. The lightning patterns were actually beautiful if you ignored the screaming wind."},
  {dalinar,  "The Codes require we remain prepared regardless of weather. A soldier who blames the storm is blaming the wrong enemy."},
  {adolin,   "Father, with respect, the Codes don't say anything about getting sleep. Some of us dueled three times yesterday."},
  {navani,   "I've been working on a new fabrials design to measure highstorm pressure at altitude. The data could help predict arrival windows."},
  {kaladin,  "That would actually be useful. We lost a scouting patrol last month because the warning came too late."},
  {shallan,  "Navani, could I sit in on your fabrial work sometime? The intersection of art and engineering is fascinating to me."},
  {navani,   "Of course. Bring your sketchbook — I find visual records of the process invaluable."},
  {szeth,    "I will be present at the appointed location. That is all."},
  {adolin,   "Szeth, do you want anything from the market? We're making a run before the afternoon drills."},
  {szeth,    "I require nothing."},
  {kaladin,  "He literally never wants anything. It's unsettling."},
  {shallan,  "I find it kind of admirable? No, actually I find it deeply concerning. Never mind."},
  {dalinar,  "Focus. The Parshendi movements on the eastern plateaus suggest they are consolidating rather than raiding. I want analysis from everyone."},
  {adolin,   "Their formation discipline has gotten sharper. They weren't fighting like this a year ago."},
  {kaladin,  "Bridge Four noticed the same thing. They're coordinating across plateau groups now, not just within them."},
  {navani,   "The gemstone records from three years ago don't match current behavior at all. Something changed. Or someone changed it for them."},
  {shallan,  "I've been comparing the historical sketches. Their carapace arrangements are different too — more structured."},
  {dalinar,  "Good observations. Keep them coming. This matters."},
  {kaladin,  "One other thing — the bridgemen have been asking about the Radiants again. Specifically whether the old orders are actually gone."},
  {adolin,   "People ask that every time something weird happens. It's basically Alethi small talk at this point."},
  {szeth,    "The Radiants are not gone."},
  {shallan,  "...Do you want to expand on that, Szeth?"},
  {szeth,    "No."},
  {kaladin,  "Great. Very helpful. Thanks."},
  {navani,   "I'll note that the historical accounts of Radiants are remarkably consistent across disparate cultures, which suggests a real shared referent rather than mythologizing."},
  {dalinar,  "My dreams have shown me things I cannot explain through natural means. I don't say this lightly."},
  {adolin,   "Father... are you sure you want to put that in writing?"},
  {dalinar,  "I am sure of nothing. That is why I'm documenting it."},
  {shallan,  "For what it's worth, I've seen things I also can't explain. The world may be stranger than the Vorin church would prefer."},
  {kaladin,  "Bridge Four's official position: we fight, we protect, we ask questions later."},
  {navani,   "A practical philosophy. I'll take rigorous documentation over battle cries any day, but each to their own."},
  {adolin,   "Speaking of documentation — anyone want to witness my duel against Brightlord Reshphin tomorrow? Noon at the arena."},
  {shallan,  "I'll be there. I want sketches of his face when he realizes what he's walked into."},
  {kaladin,  "I'll post a few of my men at the entrance. Just in case."},
  {dalinar,  "I'll attend. Win decisively, Adolin. No unnecessary cruelty, but leave no doubt."},
  {adolin,   "When do I ever leave doubt?"},
  {szeth,    "I will observe from a position of concealment."},
  {adolin,   "...you know there are seats, right?"},
  {szeth,    "Yes."},
  {navani,   "On that note, I've put together some notes on Shardplate maintenance that I'd like everyone to review when they have time. It matters more than people realize."},
]

general_messages
|> Enum.zip(times)
|> Enum.each(fn {{user, body}, ts} ->
  Seeds.Helpers.insert_message(general_channel, user, body, ts)
end)

# ─── #random — Simpsons themed ────────────────────────────────────────────────

IO.puts("Seeding #random (Simpsons)...")

base2 = ~U[2026-02-16 09:00:00Z]
times2 = Seeds.Helpers.timestamps(base2, 50, 75)

random_messages = [
  {moe,    "Is there a Hugh Jass here? I'm looking for a Hugh Jass."},
  {homer,  "D'oh! I am so smart. S-M-R-T."},
  {bart,   "I didn't do it. Nobody saw me do it. You can't prove anything."},
  {lisa,   "Can everyone please use this channel responsibly? It's called #random, not #chaos."},
  {bart,   "Lisa, chaos IS random."},
  {marge,  "Bart, that is not a philosophy. Homer, put down the donut."},
  {homer,  "But Marge, this donut has BOTH chocolate AND sprinkles. It's like it was made for me specifically."},
  {burns,  "Smithers, who are all these people and why are they on my channel?"},
  {moe,    "Mr. Burns, you don't own this channel."},
  {burns,  "Not yet."},
  {homer,  "To alcohol! The cause of, and solution to, all of life's problems."},
  {marge,  "Homer, it is nine in the morning."},
  {homer,  "Okay, to breakfast alcohol."},
  {bart,   "Cowabunga! Anybody want to come to the skate park? I found a new gap over by the Kwik-E-Mart dumpsters."},
  {lisa,   "Please don't go near the Kwik-E-Mart dumpsters, Bart."},
  {bart,   "Too late. Anyway 8 out of 10, would gap again."},
  {moe,    "I've been called ugly, pug-ugly, fugly, pug-fugly, but never ugly-ugly. There is a difference, people."},
  {homer,  "Moe, you're not ugly. You're... lived-in."},
  {moe,    "Homer that somehow made it worse."},
  {burns,  "What good is money if it can't inspire terror in your fellow man?"},
  {lisa,   "Mr. Burns, that's not a healthy relationship with wealth."},
  {burns,  "Young lady, I have had a healthy relationship with wealth for over 100 years. The wealth is healthy. I am... fine."},
  {bart,   "Ay caramba, did anyone see that thing on TV last night? The one with the thing?"},
  {homer,  "Yes! And then the other thing happened!"},
  {marge,  "I don't think either of you actually watched the same show."},
  {homer,  "Marge, we watched TV together. In the same room. You were there."},
  {marge,  "You both fell asleep at 8pm."},
  {homer,  "In the same room. Counts."},
  {lisa,   "I finished my essay on the socioeconomic impact of the Shelbyville-Springfield rivalry. Does anyone want to proofread it?"},
  {bart,   "Hard pass."},
  {marge,  "I would love to, sweetie!"},
  {homer,  "College? Pfft. I didn't go to college and look how I turned out."},
  {burns,  "I went to Yale. Twice. Once as a student, once to purchase the endowment."},
  {moe,    "Anybody seen Barney? He left his tab open again. Third time this week."},
  {homer,  "Barney's a free spirit, Moe. You gotta respect that."},
  {moe,    "Homer, your tab is literally longer than my arm and I am not a small man."},
  {homer,  "Put it on my tab."},
  {bart,   "Nobody better lay a finger on my Butterfinger."},
  {lisa,   "No one was going to, Bart."},
  {bart,   "Good. Just so we're clear."},
  {burns,  "Release the hounds."},
  {moe,    "Mr. Burns there are no hounds in this chat."},
  {burns,  "Then I shall release a strongly worded message."},
  {homer,  "Facts are meaningless. You could use facts to prove anything that's even remotely true."},
  {lisa,   "Dad, that's... I actually don't know where to begin."},
  {marge,  "Homer, that's not how facts work."},
  {homer,  "Marge, I have used it successfully many times."},
  {bart,   "He's not wrong about the outcomes, to be fair."},
  {lisa,   "Bart, do not encourage him."},
  {moe,    "You know what I always say. \"If you can't beat 'em, arrange to have them beaten.\" Legally. Allegedly."},
]

random_messages
|> Enum.zip(times2)
|> Enum.each(fn {{user, body}, ts} ->
  Seeds.Helpers.insert_message(random_channel, user, body, ts)
end)

IO.puts("""

✅ Seeds complete!

Stormlight users (password: goblessedbythestorms1):
  kaladin@windrunners.org  — kaladin
  shallan@house-davar.com  — shallan_d
  dalinar@kholin.com       — the_blackthorn
  adolin@kholin.com        — adolin_k
  szeth@truthless.net      — szeth
  navani@kholin.com        — navani_k

Simpsons users (password: donutsdonuts123):
  homer@springfield.gov    — homer_s
  marge@springfield.gov    — marge_s
  bart@springfield.gov     — el_barto
  lisa@springfield.gov     — lisa_s
  burns@montsimco.com      — mrburns
  moe@moestav.com          — moe_szys
""")
