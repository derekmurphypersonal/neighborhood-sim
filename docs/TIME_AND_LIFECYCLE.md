# Time and Lifecycle Model, 1950–1959

Status: updated 2026-11-13 after the second design review. Continuous time is confirmed (D-013), as are the history categories (D-018) and the requirements on detail levels, seeding and presentation-independence (D-025 to D-029). Aging from date of birth (D-030), player-driven divergence (D-033) and the scenario start for the first playable (D-034) are also confirmed. See [DECISIONS.md](../DECISIONS.md).

An earlier draft of this document described seasonal chapters with "interludes". That structure was not adopted and has been removed.

## 1. The calendar *(confirmed, D-013)*

The game runs on one continuous, real calendar from **Sunday 1 January 1950** to **Thursday 31 December 1959**: 3,652 days, with leap days in 1952 and 1956.

- There is a single clock for the whole world. Every resident, household, business and event lives on it.
- The clock only moves forward. It is never reset, and no part of the world is ever "paused in the past" while the player is elsewhere.
- The smallest unit of simulated time is **one minute**. Internally a moment is `(day_index, minute_of_day)`, where day 0 is 1 January 1950.
- Real dates matter because the historical record is dated: a documented event happens on its day; Sundays are Sundays; school is out in summer.
- Seasons are meteorological for simplicity: winter Dec–Feb, spring Mar–May, summer Jun–Aug, fall Sep–Nov.
- The clock belongs to the simulation core and does not depend on rendering, frame rate or any scene (D-029). It can be advanced with nothing on screen.

## 2. Player control of time *(confirmed, D-013)*

| Control | What it does |
|---|---|
| **Pause** | The clock stops. The player can look around and give directions. |
| **Speed** | A small number of speed settings for watching and directing daily life. |
| **Fast-forward** | The clock advances quickly toward a target: a time of day, a date, or "until something important happens". |

There is no mandatory structure of chapters, seasons or turns. The player decides how much of the decade to watch closely and how much to pass over. At normal watching speed the decade would take far longer than anyone would play, so fast-forward is a core feature, not a convenience; how long a typical playthrough ends up being is to be found by playtesting (Q-004).

### What happens during fast-forward

- **The world keeps running on the same calendar.** Wages are paid, rent comes due, children go to school, people meet, businesses trade, residents age.
- **Important events still resolve,** on their dates and in order: life events, timeline events, bills that cannot be met, relationship turning points.
- **Fast-forward can stop itself.** Events above an importance threshold that involve the player's household interrupt fast-forward so the player can respond. The threshold is a setting.
- **Nothing is skipped; it is simulated more coarsely** (see §3).

### Summaries

Whenever the player has passed over a stretch of time, the game can present a summary of what happened in their household and around the neighborhood. Summaries are generated from the life-event log (§7), the same log that feeds residents' memories, so a summary never reports something that did not happen in the simulation.

## 3. Levels of detail *(confirmed requirements D-026, D-027, D-028)*

The simulation does not track every footstep and conversation of every resident. How closely a resident is simulated depends on how close they are to the player's attention.

| Level | Applies to | What is simulated |
|---|---|---|
| **Close** | The player's household, and residents near them or interacting with them, at watching speeds | Minute by minute: movement, individual actions, each conversation, needs rising and falling |
| **Routine** | Other residents of the neighborhood at watching speeds | Where their schedule puts them, hour by hour. Needs, spending and social contact are resolved in aggregate for each block of time. No pathfinding, no individual conversations. |
| **Abstract** | Everyone during fast-forward; households and places far from the player; off-map activity | Day by day: work attended, income and expenses, relationship drift, chances of life events |

Rules:

1. **Same world, same facts.** A resident is one record whatever the level. Levels change how their time is advanced, not who they are.
2. **Moving between levels is seamless.** When the player approaches or interacts with a resident, that resident is raised to close detail and given a specific position, activity and need state consistent with their schedule and recent history. When the player moves away, the resident's state is folded back into the coarser form.
3. **Levels agree with each other.** Over the same span, the three levels should produce similar outcomes on average (money earned, time with friends, needs met). Automated tests check this.
4. **Important events are level-independent.** Life events and timeline events are decided by the same rules at every level and always logged.
5. **Start simple.** The first playable covers one block, where every resident can be simulated closely. Routine and abstract levels are added when the map or the time span requires them ([ROADMAP.md](ROADMAP.md)), but the clock and the systems are designed for them from the start.

**As built (M1-A):** two levels exist. Close detail advances one minute at a time for everyone. The abstract level advances a day at a time and runs only birthdays and the weekly household budget; it is what the headless decade run uses. Both use the same day-level code, and a test checks that they agree. The routine level and moving residents between levels are not built yet.

## 4. Reproducibility *(confirmed, D-017, D-025)*

All randomness comes from seeded generators owned by the simulation, with a separate stream per system. Given the same data, the same seed and the same sequence of player inputs (including where the player's attention was and when they fast-forwarded), the simulation produces the same result.

Because detail levels follow the player's attention, two runs with the same seed but different player behavior will differ in small details. That is expected. What is guaranteed is exact reproduction for identical inputs, and statistical agreement across detail levels (§3 rule 3).

## 5. Residents through the decade

### Age and birthdays *(confirmed, D-030)*

- Every resident has a **date of birth**. It is the only stored fact about their age.
- **Age is always derived** from date of birth and the current date. Residents do not all get older on the same day.
- Each resident has a **birthday** each year: a small event in itself (something households can mark) and the moment age-based eligibility changes.
- A resident born on 29 February has their birthday observed on 1 March in non-leap years. This is a game convention.
- Residents who exist on 1 January 1950 are generated with dates of birth before that day; residents born during play get the date of their birth event.

Over the decade a resident ages at most ten years, so most live through one major transition.

### Life stages and transitions

Stages are game categories, not historical claims. Age boundaries are tuning values.

| Stage | Approx. ages | Daily life |
|---|---|---|
| Infant | 0–2 | Cared for |
| Child | 3–12 | School, play |
| Adolescent | 13–17 | School, part-time work, first independence |
| Young adult | 18–29 | Work or service, courtship, leaving home |
| Adult | 30–59 | Work, raising a family, community roles |
| Elder | 60+ | Retirement, grandchildren, declining health |

The transitions that matter most to play are into childhood (starting school), into adolescence, and into adulthood. Each should be felt: new things the resident can do, new expectations from the household, changed relationships with parents and peers.

Not every transition falls on a birthday. A stage changes on the birthday that crosses its boundary, but related events follow the world's calendar: a child starts school at the start of a school year, and finishes at the end of one.

**What is deliberately not simulated yet:** physical growth, detailed health and medical conditions, genetics or inherited appearance, and any model of fertility beyond simple eligibility and chance. Aging is a date, a stage, and the events that go with them.

### Life events

| Event | Triggers | Effects |
|---|---|---|
| Birth | A couple; chance over time | New person with a date of birth; household needs and expenses change |
| Birthday | The calendar | Age changes; possible stage transition; a household occasion |
| Starting and finishing school | Age and the school calendar | Schedule changes; finishing opens full-time work |
| Reaching adulthood | 18th birthday | May work full-time, court, leave home; eligible for timeline-driven effects |
| Courtship and marriage | Relationship state, age, goals | Households merge or a new one forms; a move |
| Leaving home | Age, marriage, job, housing available | New household; vacancy |
| Getting, changing, losing a job | Skills, openings, business fortunes, timeline events | Income, schedule, status, mood |
| Illness and recovery | Age, chance | Needs, income, care from others |
| Retirement | Age, health, means | Schedule and income change |
| Death | Age, health, chance | Grief in relationships; household change; inheritance |
| Moving in / moving away | Vacancy, income, goals | Population turnover; new neighbors |
| Buying a home | Savings, income, availability | Tenure changes |

These apply to every household, not only the player's (D-014): other residents have their own routines, goals, finances, relationships and life events, and those proceed whether or not the player is watching.

### Where the numbers come from

Every rate that drives a life event is labeled in `data/tuning/` as one of:

- **`sourced`**: taken from a registered source, with the citation.
- **`gameplay_tuned`**: chosen to make a small neighborhood eventful. Never presented as a historical statistic (D-005).

## 6. Households, housing and businesses through the decade

- **Households** form, change and end through the life events above.
- **Dwelling units** are occupied or vacant. Vacancies are how new fictional households enter.
- **Buildings** change only as the record shows: construction, demolition, alteration, change of use, each with a validity interval ([WORLD_DATA_MODEL.md §4](WORLD_DATA_MODEL.md)).
- **Businesses** have a documented identity (existence, place, dates) that never changes, and a simulated state (owner, staff, takings, reputation) that does (D-023).

## 7. The life-event log

Every important thing that happens in the simulation is recorded with its date, type, participants, place and cause, at every level of detail. The log is the single source for:

- summaries of skipped time (§2),
- residents' memories and relationship histories,
- the record of historical divergences (§8),
- the end-of-decade retrospective.

## 8. History and simulation together *(confirmed, D-018, D-033)*

| Category | What it covers | Can the simulation or player change it? |
|---|---|---|
| **Fixed** | The built environment; documented external events; transit and road changes; institutions' existence | No. It happens on its date regardless. The player experiences and responds to it. |
| **Anchored** | Documented businesses and their recorded opening, closing or change of hands | The record is the default outcome. Player-driven divergence is allowed (D-033): game state may depart from the record, the record itself never changes, and each divergence is recorded with its date, causes and source references. |
| **Free** | Fictional residents, their relationships, jobs and fortunes; fictional events | Entirely simulated. |

A timeline event is data: a date, a description with provenance, and a list of effects on the world or hooks into systems. The clock applies events as their dates pass, at any speed. A fixed event that the player is watching is something they witness; one that passes during fast-forward appears in the summary.

### Divergence keeps its provenance *(confirmed requirement, D-024)*

If play departs from an anchored record, the historical record is **not edited**. A divergence entry is added to the simulation state that points to the historical record, states what the record documents (with its sources), what happened in this playthrough instead, when, and why. The player can always see both: what the record says and what their neighborhood did. Details in [WORLD_DATA_MODEL.md §8](WORLD_DATA_MODEL.md).

No timeline events have been verified yet. One lead from the first research pass illustrates the idea: the reported end of passenger trains through Linden in May 1958 (F-013 in [research/FINDINGS.md](research/FINDINGS.md)). If confirmed, residents who commute by train would have to find another way to work that spring.

## 9. The start and the end

- **Start, 1 January 1950.** The world is assembled from historical data valid on that date. Fictional households are generated to fill the documented dwelling units, with dates of birth, relationships, jobs and a short generated past. 
- **Scenarios.** A scenario is data that sets the starting date and the initial household and world state on the same calendar. The full game's scenario starts on 1 January 1950. The first playable's scenario starts in spring 1950 (D-034).
- **End, 31 December 1959.** The game concludes with a retrospective of the household and the neighborhood. Whether play can continue afterward is undecided and out of scope.

## 10. What the architecture must guarantee

1. One persistent clock, owned by the simulation core, independent of rendering (D-013, D-029).
2. Every system can advance at close, routine and abstract detail, and the three agree on average (D-026 to D-028).
3. Residents can be moved between detail levels without losing or contradicting state.
4. Important events resolve identically in kind at every speed and are always logged (D-013).
5. The whole decade can run headless from a seed, with no player, quickly enough to be an automated test (D-017, D-025).
6. Every historical entity can be asked whether it exists on a given date.
7. Age is never stored; it is computed from date of birth (D-030).
8. Historical records are never modified by play; divergence is recorded beside them with provenance intact (D-023, D-024).
