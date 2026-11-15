# World Data Model

Status: updated 2026-11-15 for M1-B steps 1 to 10. Confirmed: layer separation (D-020), provenance (D-019), geometry independent of presentation (D-016), historical identity apart from simulation state (D-023), provenance-preserving divergence (D-024), fictional interiors (D-032), date-of-birth aging (D-030), player-driven divergence (D-033), area and scenario data (D-039), exact saves (D-040). Also confirmed: plain-dictionary records with no fractional numbers (D-042). Sections 13 and 14 describe what is built, including shapes introduced in M1-B under proposals P-016, P-017 and P-019, which await Derek's confirmation; the rest is the agreed design, of which only part exists in code. See [DECISIONS.md](../DECISIONS.md).

## 1. Layers *(confirmed, D-020, D-023)*

World data is kept in four separate authored layers, plus generated simulation state.

| Layer | Directory | Contents | Changes at runtime? |
|---|---|---|---|
| **Historical** | `data/historical/` | Streets, parcels, buildings, establishments, institutions, timeline events, pattern tables. Every record has provenance. | Never |
| **Fiction** | `data/fiction/` | Authored game content: interior floor-plan modules, name pools, interaction definitions, invented events, trait and goal definitions | Never |
| **Tuning** | `data/tuning/` | Numbers that shape play: need rates, event chances, prices where unsourced. Each value labeled `sourced` or `gameplay_tuned`. | Never |
| **Dev fixture** | `data/dev_fixture/` | A made-up street for development before research is ready (D-022). Everything `placeholder`. | Never |
| **Simulation state** | (in memory; saved to save files) | Residents, households, relationships, jobs, business state, the life-event log, divergences | Constantly |

**Historical identity is immutable; simulation state is mutable** (D-023). The historical layer says what a place *is* according to the record. Simulation state says what is *happening* there in this playthrough. State refers to historical records by ID and never copies or alters them. Nothing the player or the simulation does can write to `data/historical/`.

Files are JSON, each of the form `{"layer": "<layer>", "records": [...]}`, where the layer must match the directory *(implemented and enforced by the validator)*. A fixture file must also declare `"fictional": true` with a notice, and may not contain the real place names (D-035). One file per entity type per area (for example `data/historical/blocks/<block_id>/buildings.json`), so a research change shows up as a small, reviewable diff.

## 2. Provenance *(confirmed, D-019)*

Every record in the historical layer includes:

```json
"provenance": {
  "status": "verified | probable | hypothesis",
  "sources": [
    { "source_id": "S-...", "locator": "vol., sheet, page or issue date", "finding_id": "F-..." }
  ],
  "reasoning": "required when status is hypothesis",
  "entered_by": "who",
  "entered_on": "YYYY-MM-DD"
}
```

Rules, enforced by a validation tool ([ARCHITECTURE.md §6](ARCHITECTURE.md)):

- A record in `data/historical/` must have `status` of `verified`, `probable` or `hypothesis`, and at least one source whose `source_id` exists in [research/SOURCES.md](research/SOURCES.md).
- `hypothesis` requires `reasoning`.
- Records in `data/fiction/` carry `"status": "fictional"`. Records in `data/dev_fixture/` carry `"status": "placeholder"`. Neither status may appear in `data/historical/`.
- Tertiary sources may not be the only source for a record.
- Provenance can be attached to an individual field when one attribute is less certain than the rest of the record.

Status meanings are defined in [HISTORICAL_RESEARCH_PLAN.md §2](HISTORICAL_RESEARCH_PLAN.md).

## 3. Space *(confirmed, D-016)*

Geometry is stored in **feet in a local flat coordinate system**, with an origin and orientation documented per area and tied to a real-world reference point. Tiles, pixels and isometric projection belong to the presentation layer. This keeps map research valid whatever the art style becomes, and matches how the main map source is drawn.

- A **point** is `[x_ft, y_ft]`.
- A **polygon** is a list of points, counter-clockwise.
- Each area file records how its coordinates were derived (which sheet, how georeferenced) in its own provenance.

## 4. Time validity

The neighborhood changes over the decade, so every historical entity that can change carries a validity interval:

```json
"valid": { "from": "1950-01-01", "to": null, "from_precision": "before_start", "to_precision": "unknown" }
```

- `from` / `to` are dates; `null` for `to` means "through the end of 1959 as far as known".
- Precision says how well the date is known: `exact`, `month`, `year`, `between_sources`, `before_start`, `unknown`.
- When an entity changes rather than appears or disappears, that is a new record with its own interval, linked to the old one by `replaces`.

This lets the continuous calendar ask "what does the record say was at this address on this date?" for any day of the decade.

## 5. Historical entities

Minimal fields; all also have `id`, `provenance`, and where applicable `valid`. None of these change during play.

**Area** — a researched unit, initially one block. `name`, `boundary`, `coordinate_reference`.

**Street** — `name`, `centerline`, `width_ft`, `surface` if documented.

**Parcel** — `boundary`, `street_address_numbers`, `street_id`.

**Building** — the **exterior** only: `parcel_id`, `footprint`, `stories`, `construction` (as mapped), `building_type` (single-family, two-family, multi-family, store, store-with-dwellings, church, school, factory, garage…; the list is set by what the sources show), `units` (number of dwelling units, if documented), `mapped_use`. No interior information is stored here (§7).

**Establishment** — a documented business or organization at a place and time. `name` (as documented; allowed by D-010), `category`, `building_id`, `unit` if any, and its documented dates as the validity interval. Proprietors and staff are not recorded here; they are fictional and live in simulation state.

**Institution** — school, church, station, fire house, club. Like an establishment, with `institution_type` and any documented schedule, each with its own provenance.

**TransitService** — a documented route or line with stops and service level, valid over an interval.

**TimelineEvent** — a documented dated event. `date` and precision, `category` (`fixed` or `anchored`, per D-018), `scope`, `summary`, `effects` (data changes or simulation hooks it triggers).

**PatternTable** — a distribution used to generate fictional residents. `describes`, `geography`, `as_of`, `method`, `values`, and provenance. See [HISTORICAL_RESEARCH_PLAN.md §5](HISTORICAL_RESEARCH_PLAN.md).

**OffMapPlace** — a destination outside the playable area. `name`, `kind`, how it is reached.

## 6. Simulation entities

Generated and mutable. None of these make historical claims.

**Person** — `id`, `given_name`, `family_name`, `sex`, `birth_date`, `traits`, `needs`, `skills`, `goals`, `household_id`, `occupation` (job or school reference), `health` (simple), `memories` (references to life events), `alive`, `location`, `detail_level`.

- **Age and life stage are not stored.** They are computed from `birth_date` and the current date (D-030).
- `detail_level` is `close`, `routine` or `abstract` ([TIME_AND_LIFECYCLE.md §3](TIME_AND_LIFECYCLE.md)). At `close`, `location` is a position and `needs` are tracked minute by minute. At coarser levels, `location` is a place or "off-map" and needs are summarized. Everything else on the record is the same at every level.

**Household** — `id`, `members` with roles, `dwelling` (building + unit), `tenure`, `funds`, `recurring_income`, `recurring_expenses`, `formed_on`, `dissolved_on`, `player_controlled` (true for exactly one household, per D-014).

**Relationship** — directed pair `from_person`, `to_person`, `kinds`, `affinity`, `familiarity`, `history` (references to life events).

**Job** — `employer` (establishment, institution or off-map place), `title`, `wage`, `schedule`, `holder`.

**BusinessState** — the simulated side of an establishment: `establishment_id`, `owner` (person), `staff`, `finances`, `reputation`, `status` (operating, struggling, closed), `divergence_id` if its fate has departed from the record.

**DwellingOccupancy** — which household occupies which unit over which dates.

**InteriorAssignment** — which fictional floor plan a building uses in this world (§7).

**LifeEvent** — `date`, `type`, `participants`, `place`, `cause`, `importance`. Logged at every detail level. Feeds memories, summaries of skipped time, relationship histories and the end-of-decade retrospective.

**Divergence** — see §8.

## 7. Interiors *(confirmed, D-032)*

Exteriors are verified history; interiors are fiction. The data keeps them apart in three steps.

1. **Floor-plan modules** live in `data/fiction/interiors/`. Each module is a fictional layout (rooms, doors, stairs, fixture positions) designed for one **exterior building type**, with the range of footprint dimensions and number of stories it suits. Every module carries `"status": "fictional"`. A module may note what general evidence informed it, but that never makes it historical.
2. **Assignment.** A building gets an interior by matching its documented `building_type`, `footprint` and `stories` to a suitable module. The match is stored as an `InteriorAssignment` (building ID, module ID, any fitting adjustments), chosen deterministically from the seed or authored by hand.
3. **Separation.** The historical `Building` record is never given interior fields. Anything shown to the player about a building's documented facts is drawn from the historical record; the interior is always identified as invented.

If a real floor plan for a specific building were ever found and its use decided on, it would enter through the normal research workflow as a historical record with provenance, not by editing a fictional module.

## 8. Divergence *(confirmed requirement, D-024)*

*(Player-driven divergence confirmed, D-033.)* When play departs from an anchored historical record, the historical record stays exactly as it is and a **Divergence** is added to simulation state:

```json
{
  "id": "dv_...",
  "historical_ref": "es_...",
  "documented": {
    "summary": "what the record says happened, and when",
    "provenance_ref": "the historical record's own provenance: status and sources"
  },
  "actual": { "summary": "what happened in this playthrough", "date": "YYYY-MM-DD" },
  "cause": ["le_...", "le_..."],
  "player_driven": true
}
```

- `documented` points to the same sources as the historical record, so the player (and a developer) can always see what the evidence says, even after the simulated world has gone another way.
- `cause` lists the life events that led to the divergence.
- Fixed history cannot diverge and never has a Divergence.
- The validity interval of the historical record is unchanged. Whether the place is operating *in this playthrough* is answered by simulation state; what the *record* says is answered by the historical layer. The two questions are always asked separately.

## 9. Identity and references

- IDs are stable strings with a type prefix: `st_`, `pc_`, `bd_`, `es_`, `in_`, `ev_`, `pt_` for historical; `p_`, `hh_`, `job_`, `le_`, `dv_` for simulation; `fp_` for floor-plan modules.
- Historical IDs never change once committed; saves refer to them.
- Simulation IDs are generated deterministically from the seed (D-025).

## 10. Dates

A single date type is used everywhere: a calendar date plus minutes since midnight, convertible to a day index counted from 1950-01-01 (day 0, a Sunday). See [TIME_AND_LIFECYCLE.md §1](TIME_AND_LIFECYCLE.md).

## 11. Saves

A save contains the seed and generator states, the current date-time, the full simulation state including the life-event log and divergences, and the version of each data layer it was created against. Historical data is not copied into saves. JSON to begin with; compactness is a later concern.

## 12. Privacy rule for data

No file in this repository contains the name of a real private individual taken from a census sheet, directory or similar record. Documented establishment names are allowed as recorded (D-010), including those that contain a personal name; the people behind them are not recorded.

## 13. Areas and scenarios as built *(confirmed, D-039)*

**An area** is a directory of JSON files holding the place. Record types, with coordinates in feet:

| Type | Fields |
|---|---|
| `street` | `id`, `name`, `centerline` (list of points), `width_ft` |
| `lot` | `id`, `boundary` |
| `building` | `id`, `lot_id`, `footprint`, `stories`, `building_type`, `label` |
| `exit` | `id`, `point`: where residents leave the playable area for work or school |
| `institution` | `id`, `building_id`, `name`, `kind` (the fixture has one, `store`), `hours`: for each of `weekday`, `saturday` and `sunday`, `[open, close]` in minutes after midnight, or `null` when closed. A building other people may enter during opening hours (P-017). |

- The placeholder area is `data/dev_fixture/areas/fixture_street/`; its file declares `"fictional": true`, a notice and an `area_name`, and every record is `placeholder`. It has five houses, one store building, and an institution record for the store, "Fixture Store", all invented.
- An institution is area data because a real one would be documented with the place: a researched area would give it sourced provenance like any other record. The fixture's store is a placeholder and documents nothing.
- A researched area would be `data/historical/areas/<name>/`, same record types, each record with sourced provenance.
- **Doors and fronts are derived, not authored.** On loading, each building gets a "door" (middle of the footprint edge nearest the street) and a "front" (the point on the street edge opposite it). These are walking aids computed from the footprint and street line. They are not historical claims and are not stored in the data, so a researched area needs nothing beyond what a map shows.
- On loading, feet become whole inches.

**A scenario** is one file in `data/fiction/scenarios/`, always `fictional`:

| Type | Fields |
|---|---|
| `scenario` | `id`, `title`, `area` (path under `data/`), `start_date`, `start_minute`, `default_seed` |
| `household` | `id`, `name`, `home_id` (a building in the area), `funds_cents`, `weekly_rent_cents`, `other_weekly_income_cents` (income not from work, paid on Fridays), `pantry_meals` (meals in the house at the start), `player_controlled` (exactly one). Money fields are whole numbers, zero or more. |
| `person` | `id`, `given_name`, `family_name`, `birth_date`, `household_id`, `schedule_id`, `traits`; optionally `workplace_id` (a building in the area, for a job on the street itself) and `daily_wage_cents` (earned for each day actually worked) |
| `interior_assignment` | `id`, `building_id`, `floor_plan_id`: which fictional floor plan a building uses in this scenario (P-017). The loader refuses a plan whose `for_building_types` does not include the building's type. |

Every wage, rent, starting sum and pantry figure in a scenario is invented for play and is never presented as historical (P-019).

The fixture scenario, `fixture_street_spring_1950`, has five households and seventeen residents, starts on Monday 3 April 1950 at 06:00 with seed 1950, and assigns the one floor plan to the player's home.

**Schedules** (`data/fiction/schedules.json`) have three day plans (P-016): `weekday` (Monday to Friday), `saturday` and `sunday`. Each plan gives `wake` and `bed` times, an optional `away` period (`kind` work or school, `leave` and `back` times), and optional `meals`, fixed household mealtimes (every fixture schedule has Sunday dinner at 13:00). A schedule may also be `housebound`, for the very young. Times are minutes after midnight. They are game design, not historical claims.

**Floor plans** (`data/fiction/interiors/floor_plans.json`, D-032) are records of type `floor_plan`: `id` (prefix `fp_`), `name`, `for_building_types`, `fits_ft` (the footprint size it suits), and `rooms`, each with `id`, `name`, `kind` (`kitchen`, `bedroom`, `living`, or another kind no action uses yet) and `rect_ft` (`[x, y, width, depth]` in feet from the footprint's south-west corner). Every plan is `fictional`. One plan exists, for a small house, with one floor shown. On loading, room rectangles become whole inches in world coordinates.

**Tuning** (`data/tuning/daily_life.json`, `data/tuning/economy.json`) holds the rates and thresholds for needs, talking and idle choices, and the invented meal price, pantry levels, shopping time, minimum shopping age and the minutes of work that count as a day worked. Every value is labelled `gameplay_tuned`.

**Replacing the fixture with Maynard Street** means adding the area files and a scenario that names that area and places households in its buildings. No simulation code changes; a test guards this.

## 14. Simulation records and saves as built *(confirmed, D-040, D-042)*

Record shapes are defined in one file, `game/sim/state/records.gd`. Differences from the design in §6, to be reconciled when the design is next revised:

- **Person** stores `birth_day` (a day index) instead of a date; holds `needs` (hunger, rest, company and fun, each 0 to 100,000), where they are (`at`: inside a building, outside at `x`, `y` in inches, or off the map; `place_id`; and `spot`, the room they are in where the building has an interior), `schedule_id`, `workplace_id`, `daily_wage_cents`, `worked_minutes_today`, `last_set_meal_day` (so a fixed meal is eaten once), the current `action`, and queued `orders`. No skills, goals, health or memories yet.
- **Household** holds `home_id`, `member_ids`, `funds_cents` (never below zero), `weekly_rent_cents`, `rent_owed_cents` (unpaid rent carried forward), `other_weekly_income_cents`, `wages_due_cents` (earned, paid on Friday), `pantry_meals`, `last_empty_pantry_day` and `player_controlled`. The design's recurring income and expenses (§6) are, for now, rent, other income, wages by attendance and groceries.
- **Action** records what a person is doing: `kind`, `source` (schedule, need, errand, idle, player, social), `where`, `place_id`, target point, path, start and end, `other_id` for a conversation, `room_kind` (the kind of room it is done in), and `resume` (for a conversation, the action it interrupted, to be taken up again; P-018).
- **Relationship** is one record per pair holding both directions (`a_to_b`, `b_to_a`, each -100 to 100), `familiarity`, `kin`, and a `history` of event numbers.
- **Life events** carry a running `id`, `day`, `minute`, `type` and `importance`, plus fields for their type. Types logged now: `birthday`, `conversation`, `payday`, `rent_paid`, `shopping`, `missed_work`, `empty_pantry`, `household_short_of_money`, `order_failed`. The week summary is computed from these alone.
- **`last_abstract_day`** is the last day advanced at the abstract level. Wages for a day are settled at midnight only if that day was followed minute by minute, so a day is never paid twice.
- **No fractional numbers anywhere in state.**

**A save** is JSON text: `format_version`, `engine_version`, `scenario_id`, `fingerprints` (a hash of every data file the world was built from), and `simulation` (clock; random-stream seeds and states as text, with the seeding method named; all people, households and relationships, with every field listed above; the event log and next event number; `last_abstract_day`). Pending orders are saved with the person they were given to. On loading, every number is restored as a whole number, and changed data files are reported. The state hash is taken from this same form.

**Loading contract (D-047).** A save is loaded with `SaveGame.restore(text, world)`. It refuses, with a reason and without crashing, text that is not a save, a different format version, a save missing any required part (`format_version`, `scenario_id`, `fingerprints`, `simulation`, and within `simulation` the `clock`, `rng` and `state` sections with their fields), and a save from a different scenario. A save whose data fingerprints differ still loads, and the differing files are listed for the caller to act on.
