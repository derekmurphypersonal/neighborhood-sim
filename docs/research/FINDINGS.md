# Findings Log

What sources say, with where and who. Game data may be entered only from findings here. Statuses are defined in [../HISTORICAL_RESEARCH_PLAN.md §2](../HISTORICAL_RESEARCH_PLAN.md).

**Nothing in this log is `verified` yet.** Entries F-001 to F-036 came from online passes in which Claude read automated summaries of web pages rather than the documents themselves; they have the status `lead` and may not be used as the basis for game data. Entries F-050 onward were read by Claude directly from images of a primary source (Sanborn sheets) and have the status `probable`: the images are medium resolution, small lettering is uncertain, and no person has yet confirmed the readings.

Last updated: 2026-11-13 (third pass)

## Entry format

```
F-nnn | status (lead / probable / verified / hypothesis) | date logged | logged by
Claim:    one statement, as the source puts it
Source:   source ID + exact location (sheet / page / issue date / URL section)
Read by:  who examined the source, how (in person, scan, automated summary)
Notes:    conflicts, ambiguity, what would raise the status
```

## Leads from the first pass

### Development of Linden (from S-MHC-1980, via automated summary; page numbers not yet captured)

| ID | Status | Claim as reported | To raise status |
|---|---|---|---|
| F-001 | lead | The Saugus Branch of the Eastern Railroad ran through Linden from 1854. | Read the PDF; cite page. Corroborate with a railroad history. |
| F-002 | lead | The Newburyport Turnpike passed through the Linden area in the early 19th century, and a secondary focus developed at a turnpike junction at Linden. The summary associated the turnpike with Broadway and Lynn Street. | Read the PDF; the street association in particular needs the original wording. |
| F-003 | lead | In 1870–1915, trolley routes ran through Linden toward Everett and Saugus, with lines on Broadway, Eastern Avenue and Beach Street, and Linden was a secondary commercial center. | Read the PDF. Whether any streetcar service remained by 1950 is a separate, open question. |
| F-004 | lead | In 1915–1940, multiple-family housing extended along trolley lines and an industrial corridor at Linden–Eastern Avenue. | Read the PDF. |
| F-005 | lead | Industry on Eastern Avenue, mostly from the 1920s–1930s, included Revere Knitting Mills, Malden Knitting Mills, the Friend Bros. canning factory and the Samuel Jordan Brush Co. | Read the PDF. Whether each was operating in the 1950s, and whether each lies inside "Linden" (Q-002), must be established from directories. |
| F-006 | lead | Route 1 ran north–south through Linden on Broadway in 1915–1940, and the report (writing in 1980) says the impact of Route 1 in Linden continued to affect adjacent neighborhoods. | Read the PDF. The 1950s alignment and construction history need a highway source. |

### Rail service (from S-WP-SAUGUS, tertiary, via automated summary)

| ID | Status | Claim as reported | To raise status |
|---|---|---|---|
| F-010 | lead | The Saugus Branch had a station named Linden, at Lynn Street near Beach Street. | Confirm on a Sanborn sheet and in a B&M timetable. |
| F-011 | lead | The Boston & Maine petitioned to end passenger service on the branch in 1948; the state Department of Public Utilities rejected this on 18 November 1949. | Follow the article's citations; newspaper coverage. |
| F-012 | lead | By 1954 service was two morning trips to Boston and two evening returns. In 1956 steam operation ended in favor of Budd Rail Diesel Cars. | B&M timetables; newspapers. |
| F-013 | lead | The last scheduled passenger train on the Saugus Branch ran on 16 May 1958, after D.P.U. approval on 18 April 1958. Freight continued for decades. | Newspaper of that week; D.P.U. records. If confirmed, this is a strong candidate for a fixed-history event inside the game's decade. |

### Highways (from S-WP-US1, tertiary, via automated summary)

| ID | Status | Claim as reported | To raise status |
|---|---|---|---|
| F-020 | lead | The first section of the Northeast Expressway, the bridge over the Mystic River, opened in 1950; Chelsea and Revere portions opened in stages from 1956 to 1958. | Highway department records; newspapers. What, if anything, was built in or beside Linden during the 1950s is **unknown** and must not be assumed. |

### Source availability (from S-MPL, via automated summary)

| ID | Status | Claim | Notes |
|---|---|---|---|
| F-030 | lead | Malden Public Library holds Malden city directories from 1869 to 1985 with some issues missing. | Which 1950s years are present is unknown. |
| F-031 | lead | The library has an index to fourteen Malden newspapers for 1860–2001 with microfilm. | Titles not listed. |
| F-032 | lead | Local history research at the library is by appointment. | Check the page for current hours before planning a visit. |

### Second pass, 2026-11-13 (source availability; all leads)

| ID | Status | Claim | Notes |
|---|---|---|---|
| F-033 | lead | The Internet Archive's Malden Public Library collection holds Malden High School yearbooks, one per year, including every year 1940–1965. | From S-YEARBOOKS: item identifiers seen in a collection listing; no volume opened. |
| F-034 | lead | No digitized Malden city directory for the 1950s is on the Internet Archive under an obvious title; the directories found there are for 1872–1885. | One title search; other spellings and other sites not exhausted. |
| F-035 | lead | A "Linden Square" and a "Linden Creek" existed in the early 1950s. | From S-MEMOIR-WEST, a personal recollection read via automated summary. Place names only; no personal details recorded. |
| F-036 | lead | The 1950 census enumeration districts for Malden include one numbered 23-91. | From a catalog title in search results (S-CENSUS-1950). Which districts cover Linden is unknown. |

Candidate areas for the first block, drawn from these leads, are in [CANDIDATE_BLOCKS.md](CANDIDATE_BLOCKS.md).

### Third pass, 2026-11-13: Sanborn maps (read directly by Claude from medium-resolution images)

Source for all: S-SANBORN-LOC via S-SANBORN-DATA. Working copies are in `research/sanborn/`. "As read" means the lettering was legible at this resolution; anything marked uncertain needs the full-resolution image.

| ID | Status | Claim, as read | Locator | Uncertain / to do |
|---|---|---|---|---|
| F-050 | probable | The Library of Congress holds seven Sanborn editions for Malden, including a volume corrected to March 1951 (79 sheets) and a 1957 volume (95 sheets). | `metadata.csv`, Malden rows (copy in `research/sanborn/malden_editions.csv`) | Catalog metadata, not the title pages. The 1957 volume contains sheets dated December 1956. |
| F-051 | probable | The 1951 volume's street index marks many streets as "at Linden" and assigns them to **sheets 62 and 70**. Examples as read: Arch, Bellvale, Blaine, Davis and Lawrence "at Linden" on sheet 62; Brentwood, Delta Terrace, Grant Road and Hall "at Linden" on sheet 70; Lynn "at Linden" on both. | Item `_006`, image 80 (index dated April 1932); additional indexes March 1938 and March 1951 on image 79 | Very small type: individual entries and house-number ranges need rechecking. The 1938 and 1951 additional indexes have not been read. |
| F-052 | probable | Sheets 62 and 70 of the 1951 volume are each labelled "LINDEN". Sheet 62 is marked "New Sheet" and sheet 70 "Add'l Sheet", each with a 1920s date. | Item `_006`, images 62 and 70, upper right | The year reads as 1926 or 1928. Which corrections on each sheet date to 1951 is not shown at this resolution. |
| F-053 | probable | Streets named on sheet 62 include Beach, Lawrence, Clapp, Oliver, Springdale, Bellvale, Maynard, Claremont, Wescott, Salem, Eastern Av., Lynn, Cleveland, Davis, Andrew, Andrew Ct., Sargent, Arch, Prentiss, Blaine, Hancock Rd., Munroe, Shurtleff, Sherman, Wesley, Hall, and "Cheevers Lane (Clapp), not opened". A multi-track railroad runs through the sheet between Oliver St. and Eastern Av. | Item `_006`, image 62 | Complete street list and spellings to be confirmed. |
| F-054 | probable | Buildings labelled on sheet 62: "Linden Grammar School (Built 1889)" on Oliver between Springdale and Bellvale; "Linden M.E. Church" beside it at Bellvale; "Fire Dept. Hose Co." with "Branch Library" on Oliver between Clapp and Springdale; "Linden Cong'l Church" on Lawrence; "St. Luke's Episc'l Church" near Lynn and Eastern Av. Most other buildings on these blocks are marked as dwellings ("D") of 2 to 2½ stories; one row is marked "11 auto stalls". | Item `_006`, image 62; enlargements examined | The hose company number is not legible. Wall construction colors and all street numbers need the full-resolution image. |
| F-055 | probable | Near where Lynn and Beach streets meet beside the railroad, sheet 62 shows a cluster of buildings marked as stores ("S"), one marked "Rest.", a filling station and an "Auto Body Wks". | Item `_006`, image 62, upper centre | Sanborn sheets give uses, not business names. Whether this is "Linden Square" is not stated on the sheet. The passenger station (lead F-010) has not been located on either sheet. |
| F-056 | probable | Sheet 70 shows the Malden–Revere boundary along Lynn St., a "B & M R.R." line, a watercourse labelled "Linden Brook", a roadway labelled "Bannet Highway" across the north of the sheet, and an industrial building labelled "Hawkridge Bros Co" (steel warehouse) beside the railroad. Streets include Salem, Revere, Grant Rd., Wesmur Rd., Lawrence, Oliver, Barker, Wheeler, Brentwood, Central Av., Fairfield, Traverse Ter., Delta Ter., Vining, Fenwick, Wesley, Beach and Hall. | Item `_006`, image 70 | Whether "Bannet Highway" was built or only laid out is not clear. Spellings to be confirmed. |
| F-057 | probable | The 1957 volume has a redrawn sheet 62 (copyright line 1957) covering the same streets, and a sheet 20 marked "N.E.", December 1956, that adjoins sheets 62 and 70. The school on Oliver St. carries a longer name than in the 1951 volume. | Item `_007`, images 71, 19 | This volume's images are lower resolution; the school's 1957 name is not legible. A sheet-by-sheet comparison of 1951 and 1957 has not been done. |

| F-058 | probable | "Maynard St. (Av.)" runs between Salem St. and Oliver St., with Sanborn block 24 on its north side (toward Bellvale) and block 25 on its south side (toward Claremont). Every building fronting it is marked as a dwelling, mostly 1½ to 2½ stories, with small outbuildings marked "A"; roughly twenty-five to thirty houses. No stores or institutions front it. A watercourse crosses both blocks near the Salem St. end. | Item `_006`, image 62; enlargement examined | House count is approximate. Street numbers, stories and construction for the Oliver St. end (the chosen area, D-037) need the full-resolution image and a person's confirmation before any data is entered. The same stretch in the 1957 volume has not been compared. |

What this supports: Linden is covered by two editions that bracket most of the decade; candidate blocks can now be named (see [CANDIDATE_BLOCKS.md](CANDIDATE_BLOCKS.md)); and the index's "at Linden" usage is one period definition of the neighborhood's extent to weigh for Q-002.

### Calendar facts (computed, not historical research)

| ID | Status | Claim |
|---|---|---|
| F-040 | verified (arithmetic) | 1 January 1950 was a Sunday; 31 December 1959 was a Thursday; the span 1 Jan 1950 – 31 Dec 1959 inclusive is 3,652 days (leap years 1952 and 1956). Also checked by the automated calendar tests. |

## Known unknowns

These are deliberately recorded so nobody fills them in from memory.

- The boundaries of Linden.
- Verified street layout, lot or building detail for any Linden block. (Probable readings now exist for sheets 62 and 70 of the 1951 Sanborn volume: F-052 to F-056.)
- The name, type or location of any Linden business in the 1950s.
- Confirmed names and dates of Linden's schools and churches through the 1950s. (Labels as read from the 1951 Sanborn volume are in F-054; whether each was still in use, and under what name, through 1959 is unknown.)
- Where "Linden Square" is, and where the railroad station stood.
- Population and demographic figures for Malden or Linden in 1950 and 1960.
- Bus or streetcar service in the 1950s.
- Community events and traditions.
- Period prices, wages and rents.
