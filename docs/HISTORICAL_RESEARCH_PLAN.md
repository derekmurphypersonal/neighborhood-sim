# Historical Research Plan

Status: final for M0, 2026-11-13. It will change only as research shows a need.

This document says what counts as evidence, how findings are recorded, and in what order research is done. The registers it refers to are [research/SOURCES.md](research/SOURCES.md) and [research/FINDINGS.md](research/FINDINGS.md).

## 1. Principles

1. **Nothing historical enters the game without a source.** No invented streets, buildings, businesses or statistics (D-005).
2. **An assistant's recollection is not a source.** Anything Claude or ChatGPT "knows" about Linden is a lead to check, not a finding. It is recorded as a lead until tied to a source someone has actually read.
3. **Record what the source says, where, and who read it.** A finding without a sheet number, page or date of issue cannot be rechecked.
4. **Keep fact, inference and fiction apart**, in documents and in data, using the statuses in §2.
5. **Patterns, not persons.** Records about individuals (census sheets, directory listings) are used to learn patterns. Names, addresses and personal details of real residents are not copied into game data or into this repository (D-006).
6. **Gaps are acceptable.** "Unknown" is a valid research result and is better than a plausible guess.

## 2. Evidence statuses

These are the same values used in the data model's provenance field ([WORLD_DATA_MODEL.md §2](WORLD_DATA_MODEL.md)).

| Status | Meaning | May appear in game as history? |
|---|---|---|
| `verified` | Stated by at least one primary source that has been read directly, with a precise citation. Ideally corroborated by a second. | Yes |
| `probable` | Stated by a credible secondary source, or by one primary source with some ambiguity (illegible, undated, conflicting). | Yes, flagged |
| `hypothesis` | An inference from evidence (for example, "this building appears on the 1949 map and the 1956 map, so it stood throughout"). The reasoning is written down. | Yes, flagged, and only if needed |
| `fictional` | Game content with no claim to be historical. | Never as history |
| `placeholder` | Development stand-in. Must not ship. | No |

The findings log has one further status, `lead`: a claim that has been reported (by a tertiary source, an automated page summary, or an assistant's recollection) but not yet checked against the source itself. A lead is never a basis for game data and never appears in a data file.

Primary sources for this project: fire insurance maps, aerial photographs, city directories, census schedules and published census reports, contemporary newspapers, city records, dated photographs. Secondary: later histories, survey reports, encyclopedias. Tertiary (leads only): Wikipedia and similar; real-estate and "old maps" aggregator sites.

## 3. Sources and what each one answers

Priority order follows the project brief. Availability notes are in [research/SOURCES.md](research/SOURCES.md).

| Source | Answers | Limits |
|---|---|---|
| **Sanborn fire insurance maps** | Street layout and names, lot lines, building footprints, stories, construction material, use (dwelling, store, church, factory), street numbers | Snapshot of the sheet's revision date; no interiors; no occupants. Coverage and correction dates for Malden must be established. |
| **Historical aerial photography** | What was actually on the ground in a given year; vacant lots, new construction, demolition; trees, yards, rail lines | No names or uses; resolution varies |
| **Malden city directories** | Who and what was at each address year by year: businesses by name and type, institutions, householders and occupations; often a street-by-street listing | Self-reported; a year or so stale; lists real private individuals (use for patterns only) |
| **Census** | Household composition, ages, occupations, birthplaces, housing tenure for 1950 (individual schedules are public); published tract and city statistics for 1950 and 1960 | The 1960 individual schedules are not public; only published statistics can be used for the end of the decade. Lists real individuals. |
| **Historical newspapers** | Dated events: openings, closings, fires, meetings, parades, sports, church and school news, advertisements with prices | Uneven coverage; needs index or microfilm |
| **Malden Public Library local history** | Directories, newspaper index and microfilm, atlases, photographs, yearbooks | Appointment needed; limited staff time |
| **Photographs and local records** | Appearance: signs, storefronts, clothing, vehicles, street furniture | Often undated or unlocated |
| **USGS topographic maps** | Streets, rail, wetlands, major buildings at a few dates across the 1940s–1950s | Coarse scale |
| **MHC survey report and inventory (MACRIS)** | Development history; surviving buildings with construction dates | Written decades later; secondary |

## 4. Research questions, in order

### Phase A: establish the sources (before any map data is entered)

- A1. Which Sanborn volumes and sheets cover Linden, and what are their publication and correction dates? Is there a sheet state close to 1950?
- A2. Which aerial photographs cover Linden between about 1945 and 1960, from whom, at what dates?
- A3. Which Malden city directory years exist for 1949–1960, and are any digitized? Do they include a street directory section?
- A4. Which 1950 census enumeration districts cover Linden? Which census tracts in the published 1950 and 1960 reports?
- A5. Which Malden newspapers were published in the 1950s and how are they accessed?
- A6. How was "Linden" bounded at the time (Q-002)?
- A7. Rights status of each source for reproduction versus consultation (Q-011).

### Phase B: one block (for milestone M1)

- B1. Choose the block (Q-001) using the criteria in [ROADMAP.md](ROADMAP.md).
- B2. Streets, lots, footprints, stories, construction and use for every building on it, from the Sanborn sheet, checked against an aerial.
- B3. What occupied each address in 1950, from the nearest directory years: business names and types, institutions, and number of households per building (counts only for private residences).
- B4. Patterns for that block and its surroundings from the 1950 census: household sizes, age structure, occupations, renting versus owning. Aggregated; no names.
- B5. What changed on that block between 1950 and 1959, from later directories, aerials and map corrections.

### Phase C: the decade's timeline

- C1. Dated external events that reached Linden: transit changes, road construction, school changes, major storms, national events with local effect.
- C2. Business and institution openings and closings across the neighborhood.
- C3. Recurring community events and traditions.
- C4. Prices, wages and rents suitable for the household economy.

### Phase D: widen the map

Repeat Phase B block by block, outward from the first, as milestones require.

## 5. From records to fictional residents

Fictional residents are generated from **pattern tables**: distributions of household size, composition, age, occupation, tenure and similar. Each pattern table records:

- the source (for example, published 1950 census tract tables, or a tally from enumeration sheets),
- the geography and date it describes,
- the method used to derive it,
- its status. A table derived from a source is `verified` or `probable`. A table that is a designer's judgement is labeled `gameplay_tuned` and makes no historical claim.

Names for fictional residents come from name pools. A pool is either sourced as a pattern (for example, frequency of given names nationally by birth decade) or labeled as authored. Generated full names are checked so that a fictional resident does not reproduce a real person recorded at the same address.

Demographic composition by ethnicity, religion and national origin is not to be assumed. It waits on Q-006 and on sources.

## 6. Working before research is done

Code development should not wait on archives, and must not be allowed to fill gaps with guesses. Until Phase B is complete, development uses a **fictional fixture** (D-022): a made-up street with made-up buildings, stored in `data/dev_fixture/`, with every record marked `placeholder`. The fixture never uses real Linden street or business names. When Phase B data is ready it replaces the fixture.

## 7. Workflow

1. **Register the source** in [SOURCES.md](research/SOURCES.md) before citing it: ID, full citation, where it is held, how accessed, rights.
2. **Log the finding** in [FINDINGS.md](research/FINDINGS.md): what the source says, the exact location in it (sheet, page, issue date), who read it and when, and the status.
3. **Enter data** only from logged findings, with the finding's source IDs in the record's provenance.
4. **Review.** A second reader (Derek, or the other assistant working from the same scan) confirms before a finding is raised to `verified`. Disagreements between sources are logged, not silently resolved.

### Division of work

- **Derek:** final say on what is verified.
- **In-person archive work is not planned for now (D-012).** Where a source is only available on site (for example directories or microfilm held at the library), look for a digitized copy or an online equivalent first: the Library of Congress, Digital Commonwealth, the Leventhal Map Center, the Internet Archive, the National Archives' 1950 census site, USGS map and aerial downloads, state GIS and inventory sites, and digitized newspaper and directory collections. Each must be checked and registered before use; this list is where to look, not a statement of what they hold. If nothing digital exists, record the gap.
- **ChatGPT:** locating sources, reading scans supplied to it, drafting findings, reviewing Claude's.
- **Claude:** maintaining the registers, turning findings into data with provenance, validation tooling, flagging gaps.

Both assistants follow §1 rule 2. A finding contributed by an assistant must include the source location so a person can check it.

## 8. Status after three passes (2026-11-13)

- **Done:** the source register and findings log exist and are in use; the provenance rules in §2 are enforced by an automated validator; candidate areas for the first block are listed in [research/CANDIDATE_BLOCKS.md](research/CANDIDATE_BLOCKS.md).
- **Done since:** question A1 is answered in outline. The Library of Congress's own bulk data package gave the list of Malden Sanborn editions and medium-resolution images; Linden is on sheets 62 and 70 of the volume corrected to March 1951, with a 1957 volume to compare (findings F-050 to F-057, all `probable`).
- **Not done:** the rest of Phase A. No aerial, no 1950s directory, no census districts for Linden. The Digital Commonwealth and Leventhal Map Center sites, and loc.gov itself, could not be opened by Claude.
- **Needs a person:** choosing a block (Q-001), confirming the map readings, and fetching full-resolution sheets from loc.gov when it is reachable.
- **Unresolved historical questions are preserved** in the "Known unknowns" list in [research/FINDINGS.md](research/FINDINGS.md) and as Q-001, Q-002, Q-006 and Q-011 in `DECISIONS.md`.

### First pass, for the record

A short online survey to learn which sources exist. Results are in the two registers. In summary: the main source types all appear to exist for Malden, but none has yet been read at the level of an individual Linden block, and several catalog pages could not be opened from Claude's environment. Nothing in the game's historical layer can be entered yet. The immediate next step is Phase A.
