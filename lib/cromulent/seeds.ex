defmodule Cromulent.Seeds do
  alias Cromulent.Repo
  alias Cromulent.Accounts
  alias Cromulent.Accounts.User
  alias Cromulent.Channels
  alias Cromulent.Channels.Channel
  alias Cromulent.Messages.Message

  def run do
    IO.puts("Seeds starting...")

    # ─── Channels ───────────────────────────────────────────────────────────────

    IO.puts("Creating channels...")

    general_channel =
      find_or_create_channel(%{
        name: "general",
        type: :text,
        is_default: true,
        is_private: false,
        write_permission: :everyone
      })

    random_channel =
      find_or_create_channel(%{
        name: "random",
        type: :text,
        is_default: true,
        is_private: false,
        write_permission: :everyone
      })

    announcements_channel =
      find_or_create_channel(%{
        name: "announcements",
        type: :text,
        is_default: true,
        is_private: false,
        write_permission: :admin_only
      })

    wow_channel =
      find_or_create_channel(%{
        name: "world-of-warcraft",
        type: :text,
        is_default: false,
        is_private: false,
        write_permission: :everyone
      })

    _voice_main =
      find_or_create_channel(%{
        name: "voice-main",
        type: :voice,
        is_default: true,
        is_private: false,
        write_permission: :everyone
      })

    _voice_gaming =
      find_or_create_channel(%{
        name: "voice-gaming",
        type: :voice,
        is_default: false,
        is_private: false,
        write_permission: :everyone
      })

    IO.puts("Channels ready.")

    # ─── Users ──────────────────────────────────────────────────────────────────

    IO.puts("Creating users...")

    homer   = find_or_create_user(%{email: "homer@springfield.gov",   username: "homer_s",        password: "donutsdonuts123"})
    marge   = find_or_create_user(%{email: "marge@springfield.gov",   username: "marge_s",        password: "donutsdonuts123"})
    bart    = find_or_create_user(%{email: "bart@springfield.gov",     username: "el_barto",       password: "donutsdonuts123"})
    lisa    = find_or_create_user(%{email: "lisa@springfield.gov",     username: "lisa_s",         password: "donutsdonuts123"})
    burns   = find_or_create_user(%{email: "burns@montsimco.com",      username: "mrburns",        password: "donutsdonuts123"})
    moe     = find_or_create_user(%{email: "moe@moestav.com",          username: "moe_szys",       password: "donutsdonuts123"})

    kaladin = find_or_create_user(%{email: "kaladin@windrunners.org",  username: "kaladin",        password: "goblessedbythestorms1"})
    shallan = find_or_create_user(%{email: "shallan@house-davar.com",  username: "shallan_d",      password: "goblessedbythestorms1"})
    dalinar = find_or_create_user(%{email: "dalinar@kholin.com",       username: "the_blackthorn", password: "goblessedbythestorms1"})
    adolin  = find_or_create_user(%{email: "adolin@kholin.com",        username: "adolin_k",       password: "goblessedbythestorms1"})
    szeth   = find_or_create_user(%{email: "szeth@truthless.net",      username: "szeth",          password: "goblessedbythestorms1"})
    navani  = find_or_create_user(%{email: "navani@kholin.com",        username: "navani_k",       password: "goblessedbythestorms1"})

    IO.puts("Users created.")

    # ─── Opt-in memberships ─────────────────────────────────────────────────────

    IO.puts("Setting up opt-in memberships...")

    for user <- [homer, bart, moe, kaladin, adolin] do
      Channels.join_channel(user, wow_channel)
    end

    IO.puts("Memberships ready.")

    # ─── #general ───────────────────────────────────────────────────────────────

    IO.puts("Seeding #general...")

    base = ~U[2026-02-16 10:00:00Z]
    times = timestamps(base, 200)

    general_messages = [
      {kaladin, "Another highstorm last night. Lost two practice dummies off the plateau. Bridge Four is fine though."},
      {shallan, "I sketched the storm from the window. There's something beautiful about the destruction if you catch it at the right angle."},
      {dalinar, "Beauty in destruction is how wars start, Shallan."},
      {navani,  "Dalinar, she's talking about art."},
      {dalinar, "I know. I'm talking about the mindset."},
      {adolin,  "Good morning everyone. Anyone want to spar? I've been up since the fourth bell."},
      {kaladin, "I'll pass. I've had enough of people swinging things at me this week."},
      {szeth,   "I will spar."},
      {adolin,  "...I'm good actually."},
      {shallan, "Smart choice Adolin."},
      {kaladin, "Has anyone seen Pattern? He keeps trying to have philosophical debates with the spren in the courtyard."},
      {shallan, "He's fine, he's just very interested in lies. He says the Parshmen tell fascinating ones."},
      {dalinar, "That's worth documenting. Navani, add it to the research log."},
      {navani,  "Already done. I've been watching them for weeks."},
      {szeth,   "I have observed that humans lie about small things as frequently as large ones."},
      {adolin,  "Szeth, buddy, that's kind of unsettling when you phrase it like that."},
      {szeth,   "I am often told this."},
      {kaladin, "I grew up in Hearthstone. We lied about harvests and debts. Never about anything that mattered."},
      {shallan, "My family lied about everything that mattered. I lied about everything too. Still do sometimes."},
      {navani,  "Honesty is a practice. Not a state."},
      {dalinar, "The most honest thing I ever did was stop pretending I was a good man and start trying to be one."},
      {adolin,  "Father, that was unexpectedly profound."},
      {dalinar, "Don't get used to it."},
      {kaladin, "We got new recruits this morning. Twelve of them. Most look like they've never held a spear."},
      {adolin,  "Give them to Bridge Four. You'll have them ready in a week."},
      {kaladin, "Three weeks, realistically. One of them held the spear upside down."},
      {shallan, "To be fair, I held a Shardblade the wrong way the first time."},
      {adolin,  "You did not."},
      {shallan, "I absolutely did. I thought the pointy end went up."},
      {navani,  "It does go up when it's sheathed."},
      {shallan, "See? Reasonable mistake."},
      {szeth,   "I have never made a mistake with a blade."},
      {kaladin, "We know, Szeth."},
      {szeth,   "I am simply saying."},
      {dalinar, "Let's focus. The Parshendi summit is in four days. I need everyone sharp."},
      {adolin,  "Sharp like a Shardblade or sharp like a tactician?"},
      {dalinar, "Both. Preferably."},
      {kaladin, "What's the threat assessment?"},
      {navani,  "Unknown. Which is the concerning part."},
      {shallan, "I can try to sketch their body language during the meeting. Sometimes the nonverbal tells more."},
      {dalinar, "Good idea. Bring Pattern. He can verify if they're being truthful."},
      {shallan, "He'll be thrilled. He loves detecting lies."},
      {szeth,   "I will stand in the corner and look threatening."},
      {adolin,  "That is genuinely your best skill in diplomatic settings."},
      {szeth,   "Thank you."},
      {adolin,  "It wasn't a compliment."},
      {szeth,   "I am aware. I choose to receive it as one."},
      {kaladin, "I like that about Szeth, honestly."},
      {shallan, "Kaladin, you're going soft."},
      {kaladin, "I'm not going soft. I'm just... recalibrating."},
      {navani,  "That's what going soft looks like from the outside."},
      {dalinar, "Leave Kaladin alone. He's earned some peace."},
      {kaladin, "Thank you, Brightlord."},
      {dalinar, "Don't thank me. It makes me uncomfortable."},
      {adolin,  "Father, you're the one who said—"},
      {dalinar, "Next topic."},
      {shallan, "I've been working on a new series of sketches. The Unmade. I want to capture what they feel like, not just what they look like."},
      {navani,  "That's a fascinating distinction. Do you think they have a feel?"},
      {shallan, "Everything has a feel. Even the void."},
      {szeth,   "The void feels like nothing. Which is its own kind of feeling."},
      {kaladin, "Szeth, are you doing okay?"},
      {szeth,   "I am functional."},
      {kaladin, "That's not what I asked."},
      {szeth,   "...I am managing."},
      {adolin,  "That's more honest than most answers I get."},
      {navani,  "The fabrials are responding to the new storm patterns. We're getting readings we've never seen before."},
      {dalinar, "Favorable?"},
      {navani,  "Uncertain. The Everstorm is changing the baseline. We need more data."},
      {shallan, "Can I come to the fabrial lab? I want to sketch the readings."},
      {navani,  "Of course. Bring Pattern, I want to see if he responds to the output frequencies."},
      {shallan, "He's going to be so excited he might vibrate into a wall."},
      {kaladin, "Has he done that before?"},
      {shallan, "Once. When he found out that fish lie to each other."},
      {adolin,  "...Fish lie?"},
      {shallan, "Apparently. Something about camouflage being a form of deception."},
      {szeth,   "This is philosophically significant."},
      {kaladin, "Only to Pattern."},
      {szeth,   "And to me."},
      {dalinar, "I am now genuinely concerned about this meeting."},
      {adolin,  "The summit or the fish?"},
      {dalinar, "Both, now."},
      {navani,  "I'll add 'piscine deception' to the research log."},
      {shallan, "You're my favorite person, Navani."},
      {navani,  "I know."},
      {kaladin, "Lopen wants to know if he can join the summit delegation."},
      {adolin,  "...Why?"},
      {kaladin, "He says he has 'diplomatic presence' now that he has two arms."},
      {shallan, "I mean, he's not wrong?"},
      {dalinar, "Absolutely not."},
      {kaladin, "I told him that. He said to tell you he 'understands and respects your position, gancho.'"},
      {dalinar, "He called me gancho?"},
      {kaladin, "He calls everyone gancho."},
      {adolin,  "He called me gancho at my own Shardplate ceremony."},
      {szeth,   "He called me gancho when I nearly killed him."},
      {shallan, "Lopen is unkillable through sheer force of friendliness."},
      {navani,  "Add him to the reserve list. If someone drops out, he's in."},
      {kaladin, "He's going to be so happy."},
      {dalinar, "He's not going to be happy because he's not going."},
      {kaladin, "He's going to be so happy about being on the reserve list."},
      {dalinar, "...Fine."},
      {adolin,  "Father, Lopen has beaten you twice now."},
      {dalinar, "I am aware."},
      {shallan, "The highstorm from last week left some incredible deposits on the eastern face. I want to go sketch them."},
      {kaladin, "I'll assign a guard detail."},
      {shallan, "I don't need a guard detail."},
      {kaladin, "You absolutely need a guard detail."},
      {shallan, "I have Pattern and a Shardblade."},
      {kaladin, "Two guards and Pattern and a Shardblade."},
      {shallan, "One guard."},
      {kaladin, "Two."},
      {adolin,  "I'll go."},
      {shallan, "...Okay, Adolin can go."},
      {kaladin, "That's not how guard assignments work."},
      {adolin,  "I want to see the deposits too."},
      {dalinar, "Let them go, Kaladin. Adolin is perfectly capable."},
      {szeth,   "I will also attend."},
      {adolin,  "Great, it's a field trip."},
      {navani,  "Bring one of my resonance meters. I want readings from those deposits."},
      {shallan, "This went from 'quick sketch' to 'expedition' very quickly."},
      {kaladin, "This is what happens when you announce plans in group chat."},
      {dalinar, "Is that what this is? Group chat?"},
      {navani,  "Effectively, yes."},
      {dalinar, "Hm."},
      {adolin,  "Father, are you okay?"},
      {dalinar, "I'm fine. I just didn't expect to have something called a 'group chat' at my age."},
      {szeth,   "I did not expect to be alive at any age. This is an improvement."},
      {kaladin, "Szeth..."},
      {szeth,   "That was meant to be optimistic."},
      {shallan, "We took it that way."},
      {navani,  "Dalinar, stop overthinking and eat something. You skipped breakfast again."},
      {dalinar, "I was reviewing the maps."},
      {navani,  "Eat and review. You're capable of both."},
      {adolin,  "She has a point."},
      {dalinar, "I know she has a point. She always has a point."},
      {navani,  "That's why you married me."},
      {dalinar, "Among other reasons."},
      {shallan, "This is actually very sweet."},
      {adolin,  "Don't tell them that, they'll get worse."},
      {kaladin, "Bridgemen report the new patrols are working. No incidents overnight."},
      {dalinar, "Good. Keep the eastern routes doubled until we have better intelligence."},
      {kaladin, "Already done."},
      {adolin,  "You two are terrifyingly efficient."},
      {szeth,   "Efficiency in the field prevents death."},
      {kaladin, "What Szeth said."},
      {shallan, "Can someone remind me when the summit actually starts? I have conflicting notes."},
      {navani,  "Four days. The sixth."},
      {shallan, "And the reception dinner?"},
      {adolin,  "Fifth. Formal dress."},
      {shallan, "I don't own formal dress."},
      {adolin,  "We'll get you something."},
      {shallan, "Adolin, last time you picked my outfit I looked like a Horneater wedding cake."},
      {adolin,  "You looked wonderful."},
      {shallan, "I looked like a pastry."},
      {dalinar, "The Kholins wear blue. The color is non-negotiable."},
      {szeth,   "I do not own blue."},
      {dalinar, "We'll find you something."},
      {szeth,   "I do not require formal dress."},
      {dalinar, "You're standing in a corner at a summit. You require dress."},
      {szeth,   "...Understood."},
      {kaladin, "My dress uniform is the one thing I actually have sorted."},
      {adolin,  "Windrunner blue suits you."},
      {kaladin, "Don't make it weird."},
      {adolin,  "I'm complimenting your uniform."},
      {kaladin, "It always sounds weird when you do it."},
      {navani,  "I'll need the resonance readings before the fifth. The summit is connected."},
      {shallan, "I'll go to the deposits tomorrow then. Early. Before Adolin wants to 'pop by' the armory."},
      {adolin,  "I was only going to take a few minutes—"},
      {shallan, "Adolin."},
      {adolin,  "Twenty minutes max."},
      {shallan, "We can do fifteen."},
      {adolin,  "Done."},
      {dalinar, "I'm glad you two communicate."},
      {kaladin, "They've gotten better at it."},
      {szeth,   "I communicate through silence primarily."},
      {navani,  "We've noticed."},
      {szeth,   "Is that a problem?"},
      {navani,  "No, Szeth. We're used to it."},
      {szeth,   "Good."},
      {kaladin, "Rock is making stew tonight. Everyone's invited."},
      {adolin,  "Rock's stew is the best thing about this whole war."},
      {shallan, "I won't argue with that."},
      {dalinar, "I'll attend."},
      {navani,  "Dalinar, you actually like Rock's stew?"},
      {dalinar, "I respect any cook who treats their work as sacred."},
      {kaladin, "He does treat it as sacred."},
      {szeth,   "I will attend also. The stew was... comforting. Last time."},
      {shallan, "Szeth, that might be the most human thing you've ever said."},
      {szeth,   "I am human."},
      {shallan, "I know. That's what I mean."},
      {adolin,  "This is going to be a good evening."},
      {kaladin, "Don't jinx it."},
      {adolin,  "I'm not jinxing anything."},
      {navani,  "Someone always jinxes it."},
      {dalinar, "Then no one say anything until the stew."},
      {shallan, "Deal."},
      {szeth,   "Agreed."},
      {kaladin, "...Fine."},
      {adolin,  "This is the most discipline we've shown all day."},
      {dalinar, "Don't ruin it."},
    ]


    general_messages
    |> Enum.zip(times)
    |> Enum.each(fn {{user, body}, ts} ->
      insert_message(general_channel, user, body, ts)
    end)

    # ─── #random ────────────────────────────────────────────────────────────────

    IO.puts("Seeding #random...")

    base2 = ~U[2026-02-16 09:00:00Z]
    times2 = timestamps(base2, 20, 75)

    random_messages = [
      {moe,   "Is there a Hugh Jass here? I'm looking for a Hugh Jass."},
      {homer, "D'oh! I am so smart. S-M-R-T."},
      {bart,  "I didn't do it. Nobody saw me do it. You can't prove anything."},
      {lisa,  "Can everyone please use this channel responsibly? It's called #random, not #chaos."},
      {bart,  "Lisa, chaos IS random."},
      {marge, "Bart, that is not a philosophy. Homer, put down the donut."},
      {homer, "But Marge, this donut has BOTH chocolate AND sprinkles."},
      {moe,   "Homer your tab is literally longer than my arm."},
      {homer, "Put it on my tab."},
      {bart,  "Nobody better lay a finger on my Butterfinger."},
      {lisa,  "No one was going to, Bart."},
      {burns, "Release the hounds."},
      {moe,   "Mr. Burns there are no hounds in this chat."},
      {burns, "Then I shall release a strongly worded message."},
      {homer, "Facts are meaningless. You could use facts to prove anything that's even remotely true."},
      {lisa,  "Dad, that's... I actually don't know where to begin."},
      {marge, "Homer, that's not how facts work."},
      {homer, "Marge, I have used it successfully many times."},
      {bart,  "He's not wrong about the outcomes, to be fair."},
      {moe,   "If you can't beat 'em, arrange to have them beaten. Legally. Allegedly."},
    ]

    random_messages
    |> Enum.zip(times2)
    |> Enum.each(fn {{user, body}, ts} ->
      insert_message(random_channel, user, body, ts)
    end)

    # ─── #announcements ─────────────────────────────────────────────────────────

    IO.puts("Seeding #announcements...")

    base3 = ~U[2026-02-15 08:00:00Z]
    times3 = timestamps(base3, 3, 3600)

    announcement_messages = [
      {dalinar, "Welcome to Cromulent. This channel is for announcements only. Use #general for discussion."},
      {dalinar, "Voice channels are now available. Join voice-main to get started. Push-to-talk is enabled by default."},
      {dalinar, "New opt-in channel added: #world-of-warcraft. Join from the channel browser."},
    ]

    announcement_messages
    |> Enum.zip(times3)
    |> Enum.each(fn {{user, body}, ts} ->
      insert_message(announcements_channel, user, body, ts)
    end)

    IO.puts("""

    ✅ Seeds complete!

    Channels:
      #announcements       — default, admin-only write
      #general             — default, open
      #random              — default, open
      #world-of-warcraft   — opt-in, open
      voice-main           — default voice
      voice-gaming         — opt-in voice

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
  end

  # ─── Private helpers ──────────────────────────────────────────────────────────

  defp find_or_create_user(attrs) do
    case Repo.get_by(User, email: attrs.email) do
      nil ->
        {:ok, user} =
          Accounts.register_user(%{
            email: attrs.email,
            password: attrs.password,
            username: attrs.username
          })

        user

      user ->
        user
    end
  end

  defp find_or_create_channel(attrs) do
    case Channels.get_channel_by_name(attrs.name) do
      nil ->
        {:ok, ch} = Channels.create_channel(attrs)
        ch

      ch ->
        ch
        |> Channel.changeset(attrs)
        |> Repo.update!()
    end
  end

  defp insert_message(channel, user, body, inserted_at) do
    %Message{}
    |> Message.changeset(%{
      channel_id: channel.id,
      user_id: user.id,
      body: body
    })
    |> Ecto.Changeset.put_change(:inserted_at, inserted_at)
    |> Repo.insert!(on_conflict: :nothing)
  end

  defp timestamps(base_datetime, count, spacing_seconds \\ 90) do
    for i <- 0..(count - 1) do
      jitter = rem(i * 37 + i * i, 45)
      DateTime.add(base_datetime, i * spacing_seconds + jitter, :second)
    end
  end
end
