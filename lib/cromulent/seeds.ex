defmodule Cromulent.Seeds do
  alias Cromulent.Repo
  alias Cromulent.Accounts
  alias Cromulent.Accounts.User
  alias Cromulent.Channels
  alias Cromulent.Channels.Channel
  alias Cromulent.Messages.Message

  import Ecto.Query

  def run do
    IO.puts("Seeds starting...")
    channels = setup_channels()
    users = setup_users()
    seed_general(channels.general, users)
    seed_random(channels.random, users)
    IO.puts(completion_message())
  end

  # ─── Channels ───────────────────────────────────────────────────────────────

  defp setup_channels do
    IO.puts("Creating channels...")

    general = find_or_create_channel("general", :text)
    random = find_or_create_channel("random", :text)
    _voice = find_or_create_channel("voice-main", :voice)

    IO.puts("Channels ready.")
    %{general: general, random: random}
  end

  defp find_or_create_channel(name, type) do
    case Cromulent.Channels.get_channel_by_name(name) do
      nil ->
        {:ok, ch} = Cromulent.Channels.create_channel(%{name: name, type: type})
        ch
      ch -> ch
    end
  end

  # ─── Users ──────────────────────────────────────────────────────────────────

  defp setup_users do
    IO.puts("Creating users...")

    users = %{
      # Stormlight crew
      kaladin: find_or_create_user("kaladin@windrunners.org", "kaladin",       "goblessedbythestorms1"),
      shallan: find_or_create_user("shallan@house-davar.com", "shallan_d",     "goblessedbythestorms1"),
      dalinar: find_or_create_user("dalinar@kholin.com",      "the_blackthorn","goblessedbythestorms1"),
      adolin:  find_or_create_user("adolin@kholin.com",       "adolin_k",      "goblessedbythestorms1"),
      szeth:   find_or_create_user("szeth@truthless.net",     "szeth",         "goblessedbythestorms1"),
      navani:  find_or_create_user("navani@kholin.com",       "navani_k",      "goblessedbythestorms1"),
      # Simpsons crew
      homer:   find_or_create_user("homer@springfield.gov",   "homer_s",       "donutsdonuts123"),
      marge:   find_or_create_user("marge@springfield.gov",   "marge_s",       "donutsdonuts123"),
      bart:    find_or_create_user("bart@springfield.gov",    "el_barto",      "donutsdonuts123"),
      lisa:    find_or_create_user("lisa@springfield.gov",    "lisa_s",        "donutsdonuts123"),
      burns:   find_or_create_user("burns@montsimco.com",     "mrburns",       "donutsdonuts123"),
      moe:     find_or_create_user("moe@moestav.com",         "moe_szys",      "donutsdonuts123"),
    }

    IO.puts("Users created.")
    users
  end

  defp find_or_create_user(email, username, password) do
    case Repo.get_by(User, email: email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{email: email, password: password, username: username})
        user
      user -> user
    end
  end

  # ─── Messages ───────────────────────────────────────────────────────────────

  defp insert_message(channel, user, body, inserted_at) do
    %Message{}
    |> Message.changeset(%{channel_id: channel.id, user_id: user.id, body: body})
    |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
    |> Repo.insert!(on_conflict: :nothing)
  end

  defp timestamps(base, count, spacing \\ 60) do
    for i <- 0..(count - 1) do
      jitter = rem(i * 37 + i * i, 45)
      DateTime.add(base, i * spacing + jitter, :second)
    end
  end

  # ─── #general ───────────────────────────────────────────────────────────────

  defp seed_general(channel, u) do
    IO.puts("Seeding #general (Stormlight Archive)...")

    messages = [
      {u.kaladin, "Another highstorm last night. Lost two practice dummies off the plateau. Bridge Four is fine though."},
      {u.shallan, "I sketched the storm from the window. There's something beautiful about the destruction if you catch it at the right angle."},
      {u.dalinar, "Beauty in destruction is how wars start, Shallan."},
      {u.navani,  "Dalinar, she's talking about art."},
      {u.dalinar, "I know. I'm talking about the mindset."},
      {u.adolin,  "Good morning everyone. Anyone want to spar? I've been up since the fourth bell."},
      {u.kaladin, "I'll pass. I've had enough of people swinging things at me this week."},
      {u.szeth,   "I will spar."},
      {u.adolin,  "...I'm good actually."},
      {u.shallan, "Smart choice Adolin."},
      {u.kaladin, "Has anyone seen Pattern? He keeps trying to have philosophical debates with the spren in the courtyard."},
      {u.shallan, "He's fine, he's just very interested in lies. He says the Parshmen tell fascinating ones."},
      {u.dalinar, "That's worth documenting. Navani, add it to the research log."},
      {u.navani,  "Already done. I've been watching them for weeks."},
      {u.szeth,   "I have observed that humans lie about small things as frequently as large ones."},
      {u.adolin,  "Szeth, buddy, that's kind of unsettling when you phrase it like that."},
      {u.szeth,   "I am often told this."},
      {u.kaladin, "I grew up in Hearthstone. We lied about harvests and debts. Never about anything that mattered."},
      {u.shallan, "My family lied about everything that mattered. I lied about everything too. Still do sometimes."},
      {u.navani,  "Honesty is a practice. Not a state."},
      {u.dalinar, "The most honest thing I ever did was stop pretending I was a good man and start trying to be one."},
      {u.adolin,  "Father, that was unexpectedly profound."},
      {u.dalinar, "Don't get used to it."},
      {u.kaladin, "We got new recruits this morning. Twelve of them. Most look like they've never held a spear."},
      {u.adolin,  "Give them to Bridge Four. You'll have them ready in a week."},
      {u.kaladin, "Three weeks, realistically. One of them held the spear upside down."},
      {u.shallan, "To be fair, I held a Shardblade the wrong way the first time."},
      {u.adolin,  "You did not."},
      {u.shallan, "I absolutely did. I thought the pointy end went up."},
      {u.navani,  "It does go up when it's sheathed."},
      {u.shallan, "See? Reasonable mistake."},
      {u.szeth,   "I have never made a mistake with a blade."},
      {u.kaladin, "We know, Szeth."},
      {u.szeth,   "I am simply saying."},
      {u.dalinar, "Let's focus. The Parshendi summit is in four days. I need everyone sharp."},
      {u.adolin,  "Sharp like a Shardblade or sharp like a tactician?"},
      {u.dalinar, "Both. Preferably."},
      {u.kaladin, "What's the threat assessment?"},
      {u.navani,  "Unknown. Which is the concerning part."},
      {u.shallan, "I can try to sketch their body language during the meeting. Sometimes the nonverbal tells more."},
      {u.dalinar, "Good idea. Bring Pattern. He can verify if they're being truthful."},
      {u.shallan, "He'll be thrilled. He loves detecting lies."},
      {u.szeth,   "I will stand in the corner and look threatening."},
      {u.adolin,  "That is genuinely your best skill in diplomatic settings."},
      {u.szeth,   "Thank you."},
      {u.adolin,  "It wasn't a compliment."},
      {u.szeth,   "I am aware. I choose to receive it as one."},
      {u.kaladin, "I like that about Szeth, honestly."},
      {u.shallan, "Kaladin, you're going soft."},
      {u.kaladin, "I'm not going soft. I'm just... recalibrating."},
      {u.navani,  "That's what going soft looks like from the outside."},
      {u.dalinar, "Leave Kaladin alone. He's earned some peace."},
      {u.kaladin, "Thank you, Brightlord."},
      {u.dalinar, "Don't thank me. It makes me uncomfortable."},
      {u.adolin,  "Father, you're the one who said—"},
      {u.dalinar, "Next topic."},
      {u.shallan, "I've been working on a new series of sketches. The Unmade. I want to capture what they feel like, not just what they look like."},
      {u.navani,  "That's a fascinating distinction. Do you think they have a feel?"},
      {u.shallan, "Everything has a feel. Even the void."},
      {u.szeth,   "The void feels like nothing. Which is its own kind of feeling."},
      {u.kaladin, "Szeth, are you doing okay?"},
      {u.szeth,   "I am functional."},
      {u.kaladin, "That's not what I asked."},
      {u.szeth,   "...I am managing."},
      {u.adolin,  "That's more honest than most answers I get."},
      {u.navani,  "The fabrials are responding to the new storm patterns. We're getting readings we've never seen before."},
      {u.dalinar, "Favorable?"},
      {u.navani,  "Uncertain. The Everstorm is changing the baseline. We need more data."},
      {u.shallan, "Can I come to the fabrial lab? I want to sketch the readings."},
      {u.navani,  "Of course. Bring Pattern, I want to see if he responds to the output frequencies."},
      {u.shallan, "He's going to be so excited he might vibrate into a wall."},
      {u.kaladin, "Has he done that before?"},
      {u.shallan, "Once. When he found out that fish lie to each other."},
      {u.adolin,  "...Fish lie?"},
      {u.shallan, "Apparently. Something about camouflage being a form of deception."},
      {u.szeth,   "This is philosophically significant."},
      {u.kaladin, "Only to Pattern."},
      {u.szeth,   "And to me."},
      {u.dalinar, "I am now genuinely concerned about this meeting."},
      {u.adolin,  "The summit or the fish?"},
      {u.dalinar, "Both, now."},
      {u.navani,  "I'll add 'piscine deception' to the research log."},
      {u.shallan, "You're my favorite person, Navani."},
      {u.navani,  "I know."},
      {u.kaladin, "Lopen wants to know if he can join the summit delegation."},
      {u.adolin,  "...Why?"},
      {u.kaladin, "He says he has 'diplomatic presence' now that he has two arms."},
      {u.shallan, "I mean, he's not wrong?"},
      {u.dalinar, "Absolutely not."},
      {u.kaladin, "I told him that. He said to tell you he 'understands and respects your position, gancho.'"},
      {u.dalinar, "He called me gancho?"},
      {u.kaladin, "He calls everyone gancho."},
      {u.adolin,  "He called me gancho at my own Shardplate ceremony."},
      {u.szeth,   "He called me gancho when I nearly killed him."},
      {u.shallan, "Lopen is unkillable through sheer force of friendliness."},
      {u.navani,  "Add him to the reserve list. If someone drops out, he's in."},
      {u.kaladin, "He's going to be so happy."},
      {u.dalinar, "He's not going to be happy because he's not going."},
      {u.kaladin, "He's going to be so happy about being on the reserve list."},
      {u.dalinar, "...Fine."},
      {u.adolin,  "Father, Lopen has beaten you twice now."},
      {u.dalinar, "I am aware."},
      {u.shallan, "The highstorm from last week left some incredible deposits on the eastern face. I want to go sketch them."},
      {u.kaladin, "I'll assign a guard detail."},
      {u.shallan, "I don't need a guard detail."},
      {u.kaladin, "You absolutely need a guard detail."},
      {u.shallan, "I have Pattern and a Shardblade."},
      {u.kaladin, "Two guards and Pattern and a Shardblade."},
      {u.shallan, "One guard."},
      {u.kaladin, "Two."},
      {u.adolin,  "I'll go."},
      {u.shallan, "...Okay, Adolin can go."},
      {u.kaladin, "That's not how guard assignments work."},
      {u.adolin,  "I want to see the deposits too."},
      {u.dalinar, "Let them go, Kaladin. Adolin is perfectly capable."},
      {u.szeth,   "I will also attend."},
      {u.adolin,  "Great, it's a field trip."},
      {u.navani,  "Bring one of my resonance meters. I want readings from those deposits."},
      {u.shallan, "This went from 'quick sketch' to 'expedition' very quickly."},
      {u.kaladin, "This is what happens when you announce plans in group chat."},
      {u.dalinar, "Is that what this is? Group chat?"},
      {u.navani,  "Effectively, yes."},
      {u.dalinar, "Hm."},
      {u.adolin,  "Father, are you okay?"},
      {u.dalinar, "I'm fine. I just didn't expect to have something called a 'group chat' at my age."},
      {u.szeth,   "I did not expect to be alive at any age. This is an improvement."},
      {u.kaladin, "Szeth..."},
      {u.szeth,   "That was meant to be optimistic."},
      {u.shallan, "We took it that way."},
      {u.navani,  "Dalinar, stop overthinking and eat something. You skipped breakfast again."},
      {u.dalinar, "I was reviewing the maps."},
      {u.navani,  "Eat and review. You're capable of both."},
      {u.adolin,  "She has a point."},
      {u.dalinar, "I know she has a point. She always has a point."},
      {u.navani,  "That's why you married me."},
      {u.dalinar, "Among other reasons."},
      {u.shallan, "This is actually very sweet."},
      {u.adolin,  "Don't tell them that, they'll get worse."},
      {u.kaladin, "Bridgemen report the new patrols are working. No incidents overnight."},
      {u.dalinar, "Good. Keep the eastern routes doubled until we have better intelligence."},
      {u.kaladin, "Already done."},
      {u.adolin,  "You two are terrifyingly efficient."},
      {u.szeth,   "Efficiency in the field prevents death."},
      {u.kaladin, "What Szeth said."},
      {u.shallan, "Can someone remind me when the summit actually starts? I have conflicting notes."},
      {u.navani,  "Four days. The sixth."},
      {u.shallan, "And the reception dinner?"},
      {u.adolin,  "Fifth. Formal dress."},
      {u.shallan, "I don't own formal dress."},
      {u.adolin,  "We'll get you something."},
      {u.shallan, "Adolin, last time you picked my outfit I looked like a Horneater wedding cake."},
      {u.adolin,  "You looked wonderful."},
      {u.shallan, "I looked like a pastry."},
      {u.dalinar, "The Kholins wear blue. The color is non-negotiable."},
      {u.szeth,   "I do not own blue."},
      {u.dalinar, "We'll find you something."},
      {u.szeth,   "I do not require formal dress."},
      {u.dalinar, "You're standing in a corner at a summit. You require dress."},
      {u.szeth,   "...Understood."},
      {u.kaladin, "My dress uniform is the one thing I actually have sorted."},
      {u.adolin,  "Windrunner blue suits you."},
      {u.kaladin, "Don't make it weird."},
      {u.adolin,  "I'm complimenting your uniform."},
      {u.kaladin, "It always sounds weird when you do it."},
      {u.navani,  "I'll need the resonance readings before the fifth. The summit is connected."},
      {u.shallan, "I'll go to the deposits tomorrow then. Early. Before Adolin wants to 'pop by' the armory."},
      {u.adolin,  "I was only going to take a few minutes—"},
      {u.shallan, "Adolin."},
      {u.adolin,  "Twenty minutes max."},
      {u.shallan, "We can do fifteen."},
      {u.adolin,  "Done."},
      {u.dalinar, "I'm glad you two communicate."},
      {u.kaladin, "They've gotten better at it."},
      {u.szeth,   "I communicate through silence primarily."},
      {u.navani,  "We've noticed."},
      {u.szeth,   "Is that a problem?"},
      {u.navani,  "No, Szeth. We're used to it."},
      {u.szeth,   "Good."},
      {u.kaladin, "Rock is making stew tonight. Everyone's invited."},
      {u.adolin,  "Rock's stew is the best thing about this whole war."},
      {u.shallan, "I won't argue with that."},
      {u.dalinar, "I'll attend."},
      {u.navani,  "Dalinar, you actually like Rock's stew?"},
      {u.dalinar, "I respect any cook who treats their work as sacred."},
      {u.kaladin, "He does treat it as sacred."},
      {u.szeth,   "I will attend also. The stew was... comforting. Last time."},
      {u.shallan, "Szeth, that might be the most human thing you've ever said."},
      {u.szeth,   "I am human."},
      {u.shallan, "I know. That's what I mean."},
      {u.adolin,  "This is going to be a good evening."},
      {u.kaladin, "Don't jinx it."},
      {u.adolin,  "I'm not jinxing anything."},
      {u.navani,  "Someone always jinxes it."},
      {u.dalinar, "Then no one say anything until the stew."},
      {u.shallan, "Deal."},
      {u.szeth,   "Agreed."},
      {u.kaladin, "...Fine."},
      {u.adolin,  "This is the most discipline we've shown all day."},
      {u.dalinar, "Don't ruin it."},
    ]

    base = ~U[2026-01-01 08:00:00Z]
    messages |> Enum.zip(timestamps(base, length(messages))) |> Enum.each(fn {{user, body}, ts} ->
      insert_message(channel, user, body, ts)
    end)

    IO.puts("Seeded #{length(messages)} messages into #general.")
  end

  # ─── #random ────────────────────────────────────────────────────────────────

  defp seed_random(channel, u) do
    IO.puts("Seeding #random (Simpsons)...")

    messages = [
      {u.moe,   "Is there a Hugh Jass here? I'm looking for a Hugh Jass."},
      {u.homer, "D'oh! I am so smart. S-M-R-T."},
      {u.bart,  "I didn't do it. Nobody saw me do it. You can't prove anything."},
      {u.lisa,  "Can everyone please use this channel responsibly? It's called #random, not #chaos."},
      {u.bart,  "Lisa, chaos IS random."},
      {u.marge, "Bart, that is not a philosophy. Homer, put down the donut."},
      {u.homer, "But Marge, this donut has BOTH chocolate AND sprinkles. It's like it was made for me specifically."},
      {u.burns, "Smithers, who are all these people and why are they on my channel?"},
      {u.moe,   "Mr. Burns, you don't own this channel."},
      {u.burns, "Not yet."},
      {u.homer, "To alcohol! The cause of, and solution to, all of life's problems."},
      {u.marge, "Homer, it is nine in the morning."},
      {u.homer, "Okay, to breakfast alcohol."},
      {u.bart,  "Cowabunga! Anybody want to come to the skate park? I found a new gap over by the Kwik-E-Mart dumpsters."},
      {u.lisa,  "Please don't go near the Kwik-E-Mart dumpsters, Bart."},
      {u.bart,  "Too late. Anyway 8 out of 10, would gap again."},
      {u.moe,   "I've been called ugly, pug-ugly, fugly, pug-fugly, but never ugly-ugly. There is a difference, people."},
      {u.homer, "Moe, you're not ugly. You're... lived-in."},
      {u.moe,   "Homer that somehow made it worse."},
      {u.burns, "What good is money if it can't inspire terror in your fellow man?"},
      {u.lisa,  "Mr. Burns, that's not a healthy relationship with wealth."},
      {u.burns, "Young lady, I have had a healthy relationship with wealth for over 100 years. The wealth is healthy. I am... fine."},
      {u.bart,  "Ay caramba, did anyone see that thing on TV last night? The one with the thing?"},
      {u.homer, "Yes! And then the other thing happened!"},
      {u.marge, "I don't think either of you actually watched the same show."},
      {u.homer, "Marge, we watched TV together. In the same room. You were there."},
      {u.marge, "You both fell asleep at 8pm."},
      {u.homer, "In the same room. Counts."},
      {u.lisa,  "I finished my essay on the socioeconomic impact of the Shelbyville-Springfield rivalry. Does anyone want to proofread it?"},
      {u.bart,  "Hard pass."},
      {u.marge, "I would love to, sweetie!"},
      {u.homer, "College? Pfft. I didn't go to college and look how I turned out."},
      {u.burns, "I went to Yale. Twice. Once as a student, once to purchase the endowment."},
      {u.moe,   "Anybody seen Barney? He left his tab open again. Third time this week."},
      {u.homer, "Barney's a free spirit, Moe. You gotta respect that."},
      {u.moe,   "Homer, your tab is literally longer than my arm and I am not a small man."},
      {u.homer, "Put it on my tab."},
      {u.bart,  "Nobody better lay a finger on my Butterfinger."},
      {u.lisa,  "No one was going to, Bart."},
      {u.bart,  "Good. Just so we're clear."},
      {u.burns, "Release the hounds."},
      {u.moe,   "Mr. Burns there are no hounds in this chat."},
      {u.burns, "Then I shall release a strongly worded message."},
      {u.homer, "Facts are meaningless. You could use facts to prove anything that's even remotely true."},
      {u.lisa,  "Dad, that's... I actually don't know where to begin."},
      {u.marge, "Homer, that's not how facts work."},
      {u.homer, "Marge, I have used it successfully many times."},
      {u.bart,  "He's not wrong about the outcomes, to be fair."},
      {u.lisa,  "Bart, do not encourage him."},
      {u.moe,   "You know what I always say. \"If you can't beat 'em, arrange to have them beaten.\" Legally. Allegedly."},
    ]

    base = ~U[2026-01-01 09:00:00Z]
    messages |> Enum.zip(timestamps(base, length(messages), 75)) |> Enum.each(fn {{user, body}, ts} ->
      insert_message(channel, user, body, ts)
    end)

    IO.puts("Seeded #{length(messages)} messages into #random.")
  end

  defp completion_message do
    """

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
    """
  end
end
