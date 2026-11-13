# Decisions

This is the single record of what is settled on this project. It has four parts: **Confirmed** decisions (do not change without Derek's say-so), **Proposals** and what became of them, **Open questions**, and a **Change log**.

Rules for this file:

- Any change to an architectural or design decision must be recorded here in the same change that alters code or docs.
- Never edit or delete a confirmed decision in place. Add a new entry that supersedes it and mark the old one `Superseded by D-xxx`.
- A proposal becomes confirmed only when Derek says so. It then gets a new D-number; the proposal row stays, pointing to it.
- Each entry has an ID, a date and a source. Longer reasoning lives in the linked doc.

Last updated: 2026-11-13 (M1-A delivered for review)

## Confirmed

### From the project brief

| ID | Date | Decision | Source |
|---|---|---|---|
| D-001 | 2026-11-13 | The game is set in the Linden neighborhood of Malden, Massachusetts, in the 1950s. | Project brief |
| D-002 | 2026-11-13 | Gameplay progresses through the entire decade, 1950–1959, and the neighborhood evolves over that period. Time progression is foundational to the architecture, not an add-on. | Project brief |
| D-003 | 2026-11-13 | The game is original, not a clone of The Sims, but its playability and style are in a similar vein: open neighborhood, direct interaction with residents and places, everyday-life focus. | Project brief |
| D-004 | 2026-11-13 | Historical authenticity informs the world; gameplay and emergent storytelling take priority when the two conflict. | Project brief |
| D-005 | 2026-11-13 | No invented historical streets, buildings, businesses or demographic statistics. Verified fact, hypothesis and fictional game content must always be distinguishable. | Project brief |
| D-006 | 2026-11-13 | Residents are fictional, informed by documented historical patterns. The game does not recreate identifiable historical individuals. | Project brief |
| D-007 | 2026-11-13 | Build incrementally: a small, coherent, playable prototype comes before broad simulation systems. Avoid premature optimization, unnecessary dependencies and overengineering. | Project brief |
| D-008 | 2026-11-13 | Claude Code is the primary implementation environment. ChatGPT is a complementary product, design, research and review partner. Project documentation is the shared record between them. | Project brief |
| D-009 | 2026-11-13 | Pre-production comes first: design document, research plan, data model, time model, decision record and first prototype milestone are established before game code. | Project brief |

### From Derek, after the first documentation pass

| ID | Date | Decision | Source |
|---|---|---|---|
| D-010 | 2026-11-13 | The game may use documented business names. Proprietors and staff remain fictional (D-006). Resolves Q-003. | Derek |
| D-011 | 2026-11-13 | The repository will be hosted under Derek's personal GitHub account, `derekmurphypersonal`. It must not touch the `iuvonauts` organization, and the iuvo repository template does not apply to it. Resolves Q-010. | Derek |
| D-012 | 2026-11-13 | For now, research uses online and digital sources only. Where a source would need an in-person visit, find a suitable online or digital alternative; if none exists, record the gap rather than plan a visit. Resolves Q-012. | Derek |

### From the initial design review

| ID | Date | Decision | Source |
|---|---|---|---|
| D-013 | 2026-11-13 | **Continuous time.** The game runs on one continuous calendar from 1 January 1950 through 31 December 1959. The player can pause, adjust simulation speed and fast-forward. There is no mandatory seasonal chapter structure. Important events continue to resolve during fast-forward. Summaries can tell the player what happened during periods they skipped. The calendar is persistent: skipping time never resets or disconnects the world. Replaces the seasonal-chapter structure originally proposed as P-004. Detail: [TIME_AND_LIFECYCLE.md](docs/TIME_AND_LIFECYCLE.md). | Derek (design review) |
| D-014 | 2026-11-13 | **Household-focused gameplay.** The player adopts and controls one household and can direct its individual members. Other households operate autonomously. Other residents have independent routines, goals, finances, relationships and life events. Household switching is deferred until after the first playable milestone. From P-006. Detail: [GAME_DESIGN.md §3](docs/GAME_DESIGN.md). | Derek (design review) |
| D-015 | 2026-11-13 | **Engine:** Godot 4, latest stable 4.x, using statically typed GDScript. From P-001. The exact version is pinned here when code begins. | Design review |
| D-016 | 2026-11-13 | **Presentation:** isometric 2D, with world geometry stored independently of presentation using real-world measurements. From P-002. | Design review |
| D-017 | 2026-11-13 | **Separate simulation core,** independent of rendering and scenes, supporting reproducible simulation using explicit random seeds. From P-003. | Design review |
| D-018 | 2026-11-13 | **Three categories of historical content:** fixed, anchored and free. From P-007. Whether anchored content may actually diverge in play remains open (Q-005). | Design review |
| D-019 | 2026-11-13 | **Mandatory historical provenance** for historical records. From P-008. | Design review |
| D-020 | 2026-11-13 | **JSON world data,** separated into historical, fictional, tuning and development fixture content. From P-009. | Design review |
| D-021 | 2026-11-13 | **The first playable milestone remains "A Week on the Block".** From P-011. Implementation of it has not been authorized yet. | Design review |
| D-022 | 2026-11-13 | **Fictional development fixtures** are used until the actual Linden geography and buildings are sufficiently documented. From P-012. | Design review |

### Architectural requirements from the initial design review

| ID | Date | Requirement | Source |
|---|---|---|---|
| D-023 | 2026-11-13 | Separate immutable historical identity from mutable simulation state. | Design review |
| D-024 | 2026-11-13 | Preserve source provenance when player actions cause historical divergence. | Design review |
| D-025 | 2026-11-13 | Support reproducible simulations through seeded randomness. | Design review |
| D-026 | 2026-11-13 | Simulate distant residents and households at an appropriate abstraction level. | Design review |
| D-027 | 2026-11-13 | Allow more detailed simulation when the player interacts with nearby residents. | Design review |
| D-028 | 2026-11-13 | Avoid simulating every movement and conversation across the entire neighborhood. | Design review |
| D-029 | 2026-11-13 | The continuous calendar works independently of rendering and presentation. | Design review |

### From the second design review

| ID | Date | Decision | Source |
|---|---|---|---|
| D-030 | 2026-11-13 | **Date-of-birth-based aging.** Each resident has a date of birth, and age is calculated against the current simulation date. Birthdays and meaningful life-stage transitions are supported, without elaborate biological simulation. From P-005 rev. 1. | Derek |
| D-031 | 2026-11-13 | **Lightweight in-repository test runner** using Godot's built-in capabilities. No GUT or other dependency at this stage. The approach is to be verified against the pinned Godot version. From P-010 rev. 1. Verified on Godot 4.7.2 on 2026-11-13: test scripts run headless with `--script`, and the process exit code reports pass or fail. | Derek |
| D-032 | 2026-11-13 | **Modular fictional interiors** appropriate to documented exterior building types. Historical provenance is preserved for exteriors; interiors are marked fictional. From P-013 rev. 1. | Derek |
| D-033 | 2026-11-13 | **Player-driven divergence of anchored historical content is allowed.** The historical record remains immutable while game state can diverge. Divergences are recorded with dates, causes and source references. Resolves Q-005. | Derek |
| D-034 | 2026-11-13 | **The full game calendar begins 1 January 1950. The first playable scenario begins in spring 1950,** using scenario data to establish the initial household and world state. Resolves Q-014. | Derek |
| D-035 | 2026-11-13 | **Fictional Fixture Street is approved as a temporary fallback for the first playable milestone** if historical research is incomplete. The fixture must be explicitly identified as fictional and must never be represented as actual Linden geography. Resolves Q-015. | Derek |
| D-036 | 2026-11-13 | **Engine version pinned: Godot 4.7.2 stable** (standard build), the latest stable release listed on godotengine.org when code began, as D-015 requires. Changing it needs a new entry here. | Pinned by Claude under D-015 |

### From the M0 review and M1 planning

| ID | Date | Decision | Source |
|---|---|---|---|
| D-037 | 2026-11-13 | **The first playable area is on Maynard Street,** at its Oliver Street end, about eight to ten houses on both sides. Resolves Q-001. Nothing is entered as historical data until the map readings are confirmed (finding F-058); until then the game runs on Fixture Street (D-035). | Derek |
| D-038 | 2026-11-13 | **M1 is delivered in two parts** with a review between them: M1-A, a small playable loop, and M1-B, the complete first week. The M1 milestone and its outcome (D-021) are unchanged. Scope and order are in [M1_PLAN.md](docs/M1_PLAN.md). | Derek |
| D-039 | 2026-11-13 | **Area and scenario are separate data, loaded through one world loader.** An area is streets, lots and building exteriors, in the same record shapes whether placeholder or researched. A scenario is always fictional: start date, which area, starting households and residents, seed. The simulation core never knows which area it is running. | Derek |
| D-040 | 2026-11-13 | **Saves are exact and built before the systems that use them.** A save holds the clock, random-stream states, households, residents (including the action in progress), relationships, event history, pending orders, and fingerprints of the data it was made from. "Reproducible" is defined by tests: save at an arbitrary moment, load and continue must give the same state hash as running straight through. | Derek |

### From the M1-A review

| ID | Date | Decision | Source |
|---|---|---|---|
| D-041 | 2026-11-13 | **The M1-A loop is good and worth extending.** Derek played the build and accepted the loop. Requested and added before M1-B: what each resident is doing shown as pop-up bubbles; clearer indication when something happens; background music. | Derek |

## Proposals

Awaiting Derek's confirmation:

| ID | Proposal | Why |
|---|---|---|
| P-014 | **Simulation records stay plain dictionaries, defined in one file, under a strict rule that simulation state holds no fractional numbers** (money in cents, positions in inches, needs and time as whole units). This replaces the "small typed state classes" suggested in the M1 plan. | The risk the plan identified was numbers changing type across a save. The no-fractions rule removes that risk directly and is checked by a test; typed classes would have added a great deal of repetitive code without removing it. Already implemented this way in M1-A; revisit if records grow behavior of their own. |

### Closed proposals

Kept so that older references resolve.

| ID | Original proposal (summary) | Outcome |
|---|---|---|
| P-001 | Godot 4, statically typed GDScript | Confirmed as D-015 |
| P-002 | 2D isometric; geometry stored in real-world feet | Confirmed as D-016 |
| P-003 | Separate, deterministic simulation core | Confirmed as D-017 |
| P-004 | Real calendar played as seasonal chapters: one live week per season, with fast "interlude" simulation between | **Not adopted.** Replaced by continuous time, D-013. |
| P-005 | Original: "Residents age one year per calendar year." Revised (rev. 1): age derived from date of birth, changing on each resident's own birthday; meaningful stage transitions; no elaborate biological simulation | Revised wording confirmed as D-030 |
| P-006 | Player adopts one household; others autonomous; switching deferred | Confirmed, with added detail, as D-014 |
| P-007 | Fixed, anchored and free history | Confirmed as D-018 |
| P-008 | Provenance on every historical record | Confirmed as D-019 |
| P-009 | JSON data in four separated layers | Confirmed as D-020 |
| P-010 | Original: "GUT (Godot Unit Test) as the one accepted add-on, run headless." Revised (rev. 1): no framework yet; start with what the engine provides; evaluate frameworks when code exists | Revised wording confirmed as D-031 |
| P-011 | First playable: "A Week on the Block" | Confirmed as D-021 |
| P-012 | Fictional dev fixture until research is ready | Confirmed as D-022 |
| P-013 | Original: "Interiors are openly fictional… room layouts are typical-of-type designs marked `fictional`." Revised (rev. 1): modular fictional floor plans matched to documented exterior building types, kept distinct from verified exteriors | Revised wording confirmed as D-032 |

## Open questions

| ID | Question | Direction so far | Resolve when |
|---|---|---|---|
| Q-002 | **What are the boundaries of "Linden" for this game?** | Requires historical research: a sourced definition, or an explicit statement that the boundary is a design choice. One period definition to weigh: the streets the Sanborn index marks "at Linden" (finding F-051). | Before the map widens (M4) |
| Q-004 | **How long should a full playthrough be?** | Determine through playtesting. Under continuous time (D-013) this depends on speed settings and how players use fast-forward. | From M1 playtests onward |
| Q-006 | **How are the social realities of the 1950s represented?** | Research before implementing resident-generation rules. Do not model by assumption. | Before resident generation uses real patterns |
| Q-007 | **Household switching.** | Deferred until after the first playable (D-014). | After M1 |
| Q-008 | **Final art direction.** | Deferred. M1 uses plain placeholder art. | After M1 |
| Q-009 | **Final commercial game title.** | Deferred. "The Neighborhood" is the working title; the project and folder are named "LindenSims". | Before any public release |
| Q-011 | **Source licensing.** Which maps and photographs may be reproduced, versus only consulted? | Document rights and reproduction restrictions per source in [SOURCES.md](docs/research/SOURCES.md). | Ongoing; before any source image is bundled |
| Q-016 | **Where do data files and saves live in an exported build?** | Data is read from beside the project folder, which works when running from the repository. Saves go to the engine's per-user folder. | Before the first exported build |
| Q-017 | **How are the scenario's fictional residents named and described before the research for Q-006 is done?** | Recommendation: plainly invented names from an authored pool, with no assumptions about ethnicity or religion built in. The fixture uses obviously artificial names. | Before the Maynard Street scenario is written |
| Q-018 | **Should a player's order interrupt a conversation already under way?** | At present the resident finishes talking (at most 25 minutes) and then obeys. | M1-A review |
| Q-019 | **What should the game's real music be?** | The current music is an original placeholder waltz generated by a script, with no claim to period authenticity. Period recordings raise rights questions (see Q-011); commissioned or original period-style music avoids them. | Before any public release |
| Q-020 | **Should the assistant push to GitHub directly, and should the repository be private?** | The assistant's GitHub connection can read `neighborhood-sim` but was refused write access (tested 2026-11-13). Access is granted through GitHub's app permissions, never by sharing a password or token in chat. A private repository works once access is granted. Until then the assistant commits locally and Derek pushes. | Derek's choice |

### Resolved questions

| ID | Question | Resolution |
|---|---|---|
| Q-001 | Which block of Linden is the first playable area? | The Oliver Street end of Maynard Street: D-037 |
| Q-003 | May documented business names be used? | Yes: D-010 |
| Q-010 | Repository hosting and the iuvo template | Personal GitHub, not iuvonauts: D-011. Creating the repository is a pending task. |
| Q-012 | Who does archive work that cannot be done online? | Nobody for now; online alternatives: D-012 |
| Q-005 | May anchored history diverge? | Yes, player-driven, with the record immutable and divergences recorded: D-033 |
| Q-013 | What does "Godot's built-in testing capabilities" mean in practice? | Headless script execution, checks written in plain GDScript and process exit codes, wrapped in a small in-repo runner. Confirmed by running it on the pinned version: D-031 |
| Q-014 | Does M1 start on 1 January 1950 or on a spring date? | Calendar starts 1 January 1950; the first playable scenario starts in spring 1950: D-034 |
| Q-015 | May M1 be played on the fictional fixture? | Yes, as a temporary fallback, always identified as fictional: D-035 |

## Change log

| Date | Change |
|---|---|
| 2026-11-13 | File created. D-001–D-009 recorded from the project brief; P-001–P-013 proposed; Q-001–Q-012 opened. |
| 2026-11-13 | D-010 (business names allowed), D-011 (personal GitHub, not iuvonauts) and D-012 (online-only research for now) confirmed by Derek. Q-003, Q-010, Q-012 resolved. |
| 2026-11-13 | Initial design review applied. D-013 (continuous time; P-004's seasonal chapters not adopted) and D-014 (household-focused play) confirmed by Derek. P-001, P-002, P-003, P-007, P-008, P-009, P-011, P-012 approved and recorded as D-015–D-022. Seven architectural requirements recorded as D-023–D-029. P-005, P-010, P-013 revised and left as proposals. Q-013, Q-014 and Q-015 opened. Docs updated to match, including `CLAUDE.md`. |
| 2026-11-13 | Second design review applied. P-005, P-010, P-013 (revised wording) confirmed as D-030–D-032. Q-005, Q-014, Q-015 resolved as D-033–D-035. Engine pinned at Godot 4.7.2 (D-036). Q-013 resolved by running the test approach on the pinned version. M0 foundation built; see `docs/ROADMAP.md`. |
| 2026-11-13 | No new decisions. Sanborn sheets for Linden obtained through the Library of Congress data package; Q-001 and Q-002 notes updated with what they show. |
| 2026-11-13 | M0 review and M1 plan approved by Derek. D-037 (Maynard Street), D-038 (M1 in two parts), D-039 (area and scenario data), D-040 (exact saves) confirmed. Q-001 resolved. P-014 proposed. Q-016, Q-017, Q-018 opened. M1-A built; see `docs/ROADMAP.md`. |
| 2026-11-13 | M1-A reviewed by Derek: loop accepted (D-041). Activity bubbles, clearer event indication and placeholder background music added. Q-019 (music) and Q-020 (GitHub access) opened. P-014 and Q-018 still await an answer. |
