# M1 Playtest: the first week

Status: 2026-11-15. **Pacing observations only. Nobody has played M1-B by hand.** Everything below comes from unattended runs of the simulation and from screenshots taken under a virtual display. This is M1-B step 11 as far as it can go without a person; the final M1 judgment is Derek's and is left blank at the end of this file.

All of it is on the fictional Fixture Street. Every household, resident, wage, rent and price is invented for play and says nothing about Linden or the 1950s.

## 1. How the week was measured

Run on Linux with Godot 4.7.2 stable, on the code as of M1-B step 10, from the repository root:

| Command | What it does | Result |
|---|---|---|
| `godot --headless --path game --script res://tools/playtest_week.gd` | Runs the scenario's first week, Monday 3 April 1950 06:00 to Monday 10 April 06:00, minute by minute, with seed 1950 and nobody giving orders, and prints where the time went, how low needs fell, conversations and money | State hash `109ad66bc899bdf3db4356d62c3913b40abf64999e34050c683832868f176911` |
| The same week, through a one-off script (not in the repository) that prints the player's household's week summary and the strongest neighbor relationships | Gives the player-household figures in §2 | The same state hash, so it is the same week |
| Four weeks from the same start and seed, through a one-off script (not in the repository) that sums each household's week summaries | Gives the four-week money figures in §2 | Ran to Monday 1 May 1950 06:00 |
| `godot --path game -- --screenshot <file> --minutes 600`, under a virtual display | A picture of the screen at Monday 16:00 | Used to check the panel with seventeen residents |

What these runs cannot show: whether the week is enjoyable, whether what happens is visible and readable at playing speed, whether the controls feel right, and whether the music and chimes suit it.

## 2. What the unattended week showed

**Needs.** Nobody's needs bottomed out. The lowest any need fell for anyone was 15 (hunger). Over the week there were 4 person-hours with hunger below 20 out of 100, and none for rest, company or fun.

**Where the time went** (all seventeen residents together, 2,856 person-hours): sleep 1,141 h (39%), at home 651 h (22%), sitting out front 257 h (9%), work 251 h (8%), school 174 h (6%), eating 166 h (5%), talking 115 h (4%), pastimes 34 h, choosing what to do next 30 h, inside the store 19 h, children playing outdoors 7 h, shopping 2 h, visiting 2 h.

**Conversation.** 209 conversations in the week: Monday 26, Tuesday 28, Wednesday 26, Thursday 19, Friday 25, Saturday 49, Sunday 36. By the end, 52 pairs of neighbors had met. Regard between them ranged from -11 to 62, with a middle value of 5.

**The player's household** (the Oneworths) had 87 conversations with people outside it, 1,391 minutes in all, and 22 first meetings. Testa Oneworth and Dummy Twoson talked 14 times and ended the week at +40 and +62 regard for each other. The next strongest pair, Proxy Threeley and Draft Fivesmith, reached +29 and +40, also after 14 talks.

**Quiet stretches.** For 42% of the daytime (07:00 to 22:00) none of the player's household was out on the street, talking or shopping.

**Money in the first week** (invented amounts, in cents):

| Household | Wages | Other income | Rent | Groceries | Net | At the end |
|---|---|---|---|---|---|---|
| Oneworth (player) | 4,400 | 0 | 0 | 1,298 (2 trips) | +3,102 | 2,902; 15 meals in the pantry |
| Twoson | 0 | 1,700 | 0 | 880 (3 trips) | +820 | 820; 4 meals |
| Threeley | 4,800 | 0 | 0 | 1,782 (3 trips) | +3,018 | 4,218; 27 meals |
| Fourman | 7,600 | 0 | 0 | 374 (1 trip) | +7,226 | 7,526; 2 meals |
| Fivesmith | 4,000 | 0 | 0 | 1,562 (2 trips) | +2,438 | 2,338; 17 meals |

No household paid rent in the first week. That is not because rent is free: the game starts on Monday at 06:00, after that Monday's rent has fallen due at midnight, and the start of a game does not run the day-level work for its first day. The first rent is collected on Monday 10 April, which belongs to the second week. Every household ending the first week ahead is partly a result of that. Nobody missed work, and no household ran short.

**Money over four weeks** (to Monday 1 May): the Twoson household, whose only income is other income, had six days with an empty pantry and twice could not afford all the groceries it wanted; it ended with 272 cents. The Fourman household, with two earners, ended with 35,970 cents and had one day with an empty pantry, because its only member free to shop on weekdays gets home at 17:30, half an hour before the store shuts at 18:00. The other three households had no empty-pantry days and were never short.

**The screen.** With seventeen residents the neighbor list in the panel scrolls, and the money panel shows only the player's household. The screenshot at Monday 16:00 shows the cutaway of the home labelled as an invented layout, the store marked open, and the banner saying the street is not a real place.

## 3. Open pacing questions for Derek

These are questions, not findings. They need someone playing the week to answer.

1. **Relationships may grow too fast for a decade.** A pair reached +62 in seven days. At that rate most neighbors who meet often would be close friends within a month or two of a ten-year game. Should regard change more slowly, or should frequent talk matter less after the first few times?
2. **Is there too much talk, or the right amount?** 209 conversations a week, 87 of them involving the player's household, is lively to watch but may be noise at higher speeds.
3. **Children's play is rare.** Seven hours of outdoor play across the week against 257 hours of sitting out front. Play may be too rare to notice.
4. **The player's household is off the street much of the day.** For 42% of the daytime there is nothing of theirs to watch outdoors. Is that a natural rhythm or dead time?
5. **Money is loose for most households.** Wages comfortably exceed rent and groceries for four of the five; the two-earner household piles up money quickly. Only the household on other income feels any pressure, and only after several weeks. Is that the intended feel for M1, or should money be tighter?
6. **The first week has no rent** because the game starts after Monday's rent time (see §2). Should the scenario start earlier, or should the first day's day-level work run at the start of a game? Changing either would change behavior and the hashes, so it waits for Derek.
7. **Shopping can be squeezed by timetables.** The Fourmans' one free shopper reaches home half an hour before the store closes. Should store hours or timetables give more room?

How long a whole playthrough should be (Q-004) cannot be judged from one unattended week; it needs fast-forward, which is M2 work.

## 4. M1 judgment

*To be given by Derek after playing the week (M1 "done when" item 7 in [ROADMAP.md](ROADMAP.md)). Not yet given.*

Played on:

Judgment:

Pacing notes:
