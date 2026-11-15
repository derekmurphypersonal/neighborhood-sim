# Game Design Document

Working title: **The Neighborhood**. Status: updated 2026-11-13 after the second design review; the systems table's "Built so far" column updated 2026-11-15 for M1-B steps 1 to 10.

Items marked *(confirmed)* trace to a confirmed decision in [DECISIONS.md](../DECISIONS.md). Items marked *(proposed)* are recommendations not yet confirmed. Everything else is design intent that will be tested by the prototype.

## 1. Vision

The player lives through the 1950s in one real American neighborhood: Linden, in Malden, Massachusetts *(confirmed, D-001)*. The streets, buildings and institutions come from the historical record. The people are fictional, and their lives are the game *(confirmed, D-006)*.

The appeal is the pleasure of an ordinary street observed closely over a long time: who moved in upstairs, whose son came back from the service, which shop changed hands, who married whom. The decade is the arc. A player who starts in January 1950 and finishes in December 1959 should be able to stand on the same corner and feel how much has changed, and know which changes were theirs.

## 2. Design pillars

1. **Everyday life is the content.** Work, meals, errands, school, church suppers, front-stoop conversation. No combat, no disasters for spectacle.
2. **The neighborhood is the main character.** Households are connected; what happens in one is felt in others.
3. **Time leaves marks.** People age, children grow up, businesses change, buildings change. Nothing resets *(confirmed, D-002, D-013)*.
4. **The place is real; the people are invented.** The map can be checked against the record. The residents cannot be found in it *(confirmed, D-005, D-006)*.
5. **Small and alive beats large and empty.** A dozen residents who remember each other are worth more than a thousand who do not *(confirmed, D-007)*.
6. **Decisions have consequences that last.** The player's choices should still be visible years later.

## 3. Player role *(confirmed, D-014)*

- The player adopts and controls **one household**.
- The player can direct **individual members** of that household: where they go, what they do, whom they talk to, how they spend money and time.
- **Other households operate autonomously.** Their residents have their own routines, goals, finances, relationships and life events, which proceed whether or not the player is watching.
- **Household switching is deferred** until after the first playable milestone (Q-007).

The player's influence on the wider neighborhood is indirect and social: friendships, favors, feuds, patronage of a shop, turning up (or not) to a community event. The player is a neighbor, not a mayor or a god.

## 4. Core loop

Time is continuous *(confirmed, D-013)*. There are no chapters or turns; the player moves between watching closely and letting time run.

**Watching closely** (paused or at watching speeds):

1. Members of the player's household have needs, obligations (work, school) and wants.
2. The player directs them, or lets them act on their own.
3. They move through the neighborhood, meet people and interact. Interactions change relationships, mood, money and knowledge.
4. The day ends; the household's situation has shifted slightly.

**Letting time run** (fast-forward):

5. The same calendar advances quickly. Routines continue, and important events across the neighborhood still resolve: births, jobs gained and lost, courtships, moves, openings and closings.
6. Fast-forward stops when something important happens to the player's household.
7. The player can read a summary of what happened while they were not watching, framed as neighborhood news.

**Across the decade:**

8. Goals are pursued and met or abandoned. Children grow up. The built environment and local economy follow the documented history, and the player sees their household's place in it change.

How time works in detail is in [TIME_AND_LIFECYCLE.md](TIME_AND_LIFECYCLE.md).

## 5. Simulation systems

Listed in the order they are expected to be built. Each must justify itself by what the player experiences *(confirmed, D-007)*. The last column says what exists in code, all of it on the fictional Fixture Street; where it rests on a proposal not yet confirmed, the proposal is named.

| System | What the player experiences | First needed | Built so far |
|---|---|---|---|
| Clock and calendar | Continuous days, weekdays versus Sundays, seasons, years; pause, speeds, fast-forward | M0 (core), M1 (controls) | Calendar and clock; pause and three watching speeds. No fast-forward in play yet. |
| Needs | Residents get hungry, tired, lonely, bored, and act to fix it | M1 | Hunger, rest, company and fun, each met by particular actions in particular places |
| Schedules | People go to work and school; shops keep hours | M1 | Weekday, Saturday and Sunday timetables with Sunday dinner (P-016); the store keeps hours (P-017) |
| Movement and places | Walking the block, entering buildings | M1 | Walking the street; going into the store; rooms in the player's home (P-017) |
| Social interaction and relationships | Conversations that build or damage ties; people remember | M1 | Conversations outdoors, at the door and inside the store; regard each way; a history of conversation events per pair; a talk holds up what it interrupts (P-018) |
| Household economy | Wages, rent, groceries, running short before payday | M1 (simple) | Wages for days worked, paid Friday; rent on Monday with shortfall carried forward; a pantry restocked at the store; thin meals when it is empty (P-019). All amounts invented. |
| Building information | What is documented about a building and where it comes from, kept apart from invented interiors and residents | M1 (simple view) | Right-click any building (P-021) |
| Personality and goals | Residents differ, and want different lives | M1 (traits), M2 (goals) | Traits only |
| Life-event log and summaries | "While you were away" news; residents' memories | M1 (log), M2 (summaries) | The log; the end-of-week summary for the player's household (P-021). No summaries of skipped time yet. |
| Lifecycle | Birthdays, growing up, births, marriage, death, moving | M2 | Birthdays only |
| Detail levels | A neighborhood that carries on out of sight without slowing the game | M2 | Close and abstract levels; money agrees between them only roughly (P-020). No routine level or hand-off. |
| Employment | Getting, losing and changing jobs; commuting | M2 | Fixed jobs from the scenario only |
| Businesses | Shops with owners, staff, customers and fortunes | M2 | One fictional store with a storekeeper and customers; no fortunes |
| Community events | Recurring traditions and one-off gatherings | M2 | Not started |
| Historical timeline | Documented changes arrive on their dates | M3 | Not started |
| Neighborhood memory | Reputation, gossip, shared history | M4 | Not started |

### Residents

Each resident has a date of birth (from which age and life stage follow; *confirmed, D-030*), a few personality traits, needs, skills, goals, relationships, a role in a household, and usually an occupation or school. Residents are generated, not hand-copied from records. The patterns that guide generation must come from sources or be labeled as design choices; see [HISTORICAL_RESEARCH_PLAN.md §5](HISTORICAL_RESEARCH_PLAN.md). Rules that depend on the era's social realities wait on research (Q-006).

### Near and far *(confirmed, D-026 to D-028)*

Residents close to the player's household, or interacting with it, are simulated moment by moment. Residents elsewhere are simulated at a coarser level that keeps their routines, money, relationships and life events moving without tracking each step or conversation. When the player turns their attention to someone, that person is brought into full detail in a state consistent with what they have been doing.

### Relationships

A relationship is a directed, remembered tie between two residents with a type (kin, spouse, friend, neighbor, coworker, rival) and a history of notable events. The history matters more than a single score: "lent us money in '52" should be something the simulation can recall.

### Economy

Household-scale, not macro. Income from jobs; fixed and variable expenses; savings and debt; the possibility of moving up or down. Prices and wages must be sourced or labeled as tuning.

### Businesses and institutions

Shops, workplaces, schools, churches and transit are places with hours, staff and a role in residents' routines. Their existence, location, dates and documented names come from the record *(confirmed, D-010)*. Their proprietors, staff and day-to-day fortunes are fictional and simulated.

### Community events

Two kinds: recurring neighborhood traditions and documented one-off events. Both need sources before they are presented as historical. Invented events are allowed if marked fictional.

## 6. World and presentation

**Open neighborhood.** The playable area is one continuous outdoor space. The first prototype is a single block; the footprint grows by milestone ([ROADMAP.md](ROADMAP.md)).

**View** *(confirmed, D-016)*. Isometric 2D. World geometry is stored in real-world measurements, independent of how it is drawn.

**Exteriors and interiors** *(confirmed, D-032)*. The two are treated differently and kept visibly distinct:

- **Exteriors are historical.** A building's position, footprint, height, construction and type come from the record and carry provenance.
- **Interiors are fictional.** Historical maps do not record floor plans. Interiors are assembled from **modular fictional floor plans**, each designed for a documented exterior building type (for example, one set of plans for a given type of multi-family house, another for a small shop). A plan is chosen to fit the verified footprint and number of stories of the particular building.
- The data never mixes them: a historical building record holds no interior information, and an interior is always marked fictional ([WORLD_DATA_MODEL.md §7](WORLD_DATA_MODEL.md)). Any in-game view of a building's documented facts shows the exterior facts with sources and labels the interior as invented.

Buildings the player cannot enter in early milestones are shown from outside only; residents who go in are simply "inside".

**Interface.** Direct selection of residents and objects, context actions, a household panel, a relationships panel, time controls (pause, speeds, fast-forward), and a summary of skipped time. Period flavor in the UI is welcome but must not reduce legibility.

**Tone.** Warm, observant, unsentimental. The 1950s are not presented as a golden age or as a cautionary tale. See Q-006.

## 7. Historical authenticity in play

- Places the player sees were there, where and when the record says *(confirmed, D-005, D-019)*.
- Where the record is silent, the game either leaves a gap or fills it with content labeled fictional.
- History comes in three categories *(confirmed, D-018)*: fixed (always happens), anchored (the record is the default) and free (fictional). The player's actions can change anchored outcomes *(confirmed, D-033)*.
- When play departs from the record, the record itself is untouched and the departure is recorded with its date, causes and the original sources, and shown alongside what the record says *(confirmed, D-024, D-033)*.
- A curious player should be able to see what is documented about a place and where it comes from. Not needed for M1 beyond a simple info view, but supported by the data from the start.
- When authenticity and play conflict, play wins, and the divergence is recorded *(confirmed, D-004)*.

## 8. Replayability

Different starting household; different generated residents from a new seed *(confirmed, D-025)*; different choices; different use of time; anchored history that the player can bend (D-033). The built environment and fixed history stay the same, which gives returning players a familiar stage for a different story.

## 9. Out of scope (for now)

Multiplayer; build/buy mode beyond simple furnishing; character creator beyond choosing a household; household switching (Q-007); modding tools; areas outside Linden as playable space (other places exist as off-map destinations such as "work in Boston"); voice acting; detailed biological or medical simulation.

## 10. Risks

| Risk | Mitigation |
|---|---|
| A continuous decade has long stretches where little happens | Fast-forward with interruptions for important events; summaries; a small, eventful population |
| Players fast-forward past everything and feel no attachment | Interruptions tied to the player's household; goals that need attention; playtest pacing (Q-004) |
| Residents feel inconsistent when they move between near and far simulation | One record per resident; hand-off rules and agreement tests ([TIME_AND_LIFECYCLE.md §3](TIME_AND_LIFECYCLE.md)) |
| Research takes longer than code | Fictional dev fixture (D-022); research one block first; online sources only for now (D-012) |
| Life-sim scope creep | Every system must appear in the "player experiences" column above before it is built |
| History constrains fun | D-004; history categories (D-018) |
| Sensitive subject matter handled carelessly | Q-006 resolved with research before resident-generation rules are implemented |
