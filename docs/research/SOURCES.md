# Source Register

Every source cited anywhere in this project is registered here first. IDs are permanent.

"Checked" describes how far the source itself has been examined: **located** (a catalog entry or link was found), **opened** (the item was viewed), **read** (the relevant part was read and findings logged).

Last updated: 2026-11-13 (third pass: Sanborn sheets obtained)

**Access note.** Research is online-only for now (D-012). In two passes on 2026-11-13, Claude could not open three important sites because each stopped at an automated bot check, which Claude does not bypass: the Library of Congress website (`loc.gov`, tried through page fetch and through the in-app browser; its Sanborn images were then obtained through the Library's own bulk data package, S-SANBORN-DATA), and Digital Commonwealth and the Leventhal Map Center (both through page fetch). A person using a normal browser should be able to open them. Until someone does, the sources held there remain "located only".

## Primary sources

| ID | Source | Held by / access | Checked | Rights | Notes |
|---|---|---|---|---|---|
| S-SANBORN-LOC | Sanborn Map Company, *Sanborn Fire Insurance Map from Malden, Middlesex County, Massachusetts*. Seven editions held: June 1887 (10 sheets), May 1892 (20), July 1897 (36), 1904 (66), 1904 corrected to 1943 (78), **1904 corrected to March 1951 (79 sheets; item `sanborn03774_006`)**, and **1957 (95 sheets; item `sanborn03774_007`)**. | Library of Congress, Sanborn Maps Collection, items `https://www.loc.gov/item/sanborn03774_001/` through `_007/`. Reached through S-SANBORN-DATA, not through loc.gov (bot check; site also reported down on 2026-11-13). | **Read in part.** Editions listed from catalog metadata. For the 1951 volume: street index and sheets 62 and 70 read by Claude from medium-resolution images. For the 1957 volume: sheet 62 viewed. | Not yet determined. Sheets carry Sanborn Map Co. copyright lines (1957 on the 1957 volume). See Q-011. | The two editions that matter bracket most of the decade: March 1951 and 1957. Working copies in `research/sanborn/`. Full-resolution images are still needed for fine detail (street numbers, building notes). |
| S-SANBORN-DATA | Library of Congress, LC Labs, "Sanborn maps" data package: `metadata.csv` for all atlases and medium-resolution JPEGs by state | https://loc-sanborn-maps.s3.amazonaws.com/ (README at `/README.pdf`; Massachusetts files under `maps-by-state/Massachusetts/`) | Read: README (via summary), `metadata.csv` (Malden rows), Massachusetts manifest; 176 Malden images downloaded for the 1951 and 1957 volumes with checksums matching the manifest. | Published by the Library of Congress for computational use; rights for individual maps not stated in what was read. | The access route for S-SANBORN-LOC. |
| S-SANBORN-BPL | *Insurance maps of Malden, Middlesex Co., Massachusetts* | Norman B. Leventhal Map & Education Center, Boston Public Library: https://collections.leventhalmap.org/search/commonwealth:bv73fv734 | Located only (site blocked automated access). | Not yet determined. | Publisher and date unknown until opened. |
| S-ATLAS-1897 | *Maplewood and Linden, Massachusetts, 1897* | Leventhal Map Center: https://collections.leventhalmap.org/search/commonwealth:wd3760108 | Located only. | Not yet determined. | Pre-period; useful for street origins, not for 1950s state. |
| S-WALKER | G.H. Walker & Co., *Atlas of the City of Malden*, 1885 and 1897 | Malden Public Library (per its local history page, S-MPL) | Located only. | — | Pre-period background. |
| S-DIRECTORIES | Malden city directories | Malden Public Library holds 1869–1985 with some issues missing (per S-MPL). Digitization status unknown. | Located only. No digitized 1950s copy found: an Internet Archive title search on 2026-11-13 returned only combined Malden directories for 1872–1885 (identifiers seen, items not opened). | Facts usable; scans TBD. | **Main gap.** Need to establish which years 1949–1960 exist anywhere in digital form (try genealogy sites' city-directory collections, which usually need an account) and whether a street directory section is included. |
| S-NEWS-INDEX | Malden local newspaper index, 1860–2001, with microfilm | Malden Public Library (per S-MPL). Covers fourteen Malden newspapers; titles not listed on the page. | Located only. | — | |
| S-CENSUS-1950 | 1950 U.S. Census population schedules | National Archives: https://www.archives.gov/1950census . A catalog record for one Malden enumeration district (ED 23-91) appears at https://dp.la/item/c45aa64bb6def345ae2837bdea07ebde (title seen in search results; page not readable). | Located only. | U.S. government work. | Individual records are public. Enumeration districts for Linden not yet identified. Use for patterns only (see research plan §1.5). |
| S-AERIAL-HARV | Aerial photography of part of Middlesex County, U.S. Department of Agriculture, 1952 (as titled in a search result) | Harvard Library, aerial photography collections: https://library.harvard.edu/collections/aerial-photography-and-remotely-sensed-images | Lead only. Not opened. | Unknown. | Whether Malden/Linden is covered is unknown. |
| S-USGS-TOPO | USGS topographic quadrangle "Boston North", editions listed as 1943, 1946, 1949 and 1956 | Listed by an aggregator (pastmaps.com). Originals should be obtained from USGS directly. | Lead only. | U.S. government work. | Edition dates as listed by the aggregator; verify against the USGS map collar. |
| S-YEARBOOKS | Malden High School yearbooks, annual volumes (identifiers begin `maldonianyearboo`; title not confirmed) | Internet Archive, Malden Public Library collection: https://archive.org/details/maldenpubliclibrary . Identifiers for every year 1940–1965 were seen in the collection listing on 2026-11-13 (for example `maldonianyearboo1950mald`). | Located only; no volume opened. | Not yet determined. | Possible source for dated local business advertisements with addresses, if the volumes carry them (not confirmed). Contains names and photographs of real private individuals, including minors: use for places and businesses only, never for people. |

## Secondary sources

| ID | Source | Access | Checked | Notes |
|---|---|---|---|---|
| S-MHC-1980 | Massachusetts Historical Commission, *MHC Reconnaissance Survey Town Report: Malden*, 1980 | https://www.sec.state.ma.us/divisions/mhc/preservation/survey/town-reports/mal.pdf | Opened via an automated summary on 2026-11-13; **not yet read directly** by a person or line by line. | Says little about Linden after 1940. Statements drawn from it are logged as leads until the PDF is read and page-cited. |
| S-MPL | Malden Public Library, "Local History" page | https://maldenpubliclibrary.org/browse-mpl/local-history | Opened via an automated summary on 2026-11-13. | Describes holdings and how to arrange a visit (appointment required; local history hours on Wednesdays, as of the access date). |

## Tertiary sources (leads only; never cite as evidence in game data)

| ID | Source | Access | Notes |
|---|---|---|---|
| S-WP-SAUGUS | Wikipedia, "Saugus Branch Railroad" | https://en.wikipedia.org/wiki/Saugus_Branch_Railroad | Read via automated summary 2026-11-13. Follow its footnotes to primary or secondary sources. |
| S-WP-US1 | Wikipedia, "U.S. Route 1 in Massachusetts" | https://www.wikiwand.com/en/U.S._Route_1_(Massachusetts) (mirror) | Same. |
| S-WP-MALDEN | Wikipedia, "Malden, Massachusetts" | https://wikiwand.com/en/articles/Malden,_Massachusetts (mirror) | Lists Linden as a neighborhood and Linden Square as a square. No 1950s detail. |
| S-MEMOIR-WEST | A 2013 personal blog post recalling an early-1950s childhood near Linden Square | https://westinnewengland.blogspot.com/2013/10/memories-of-malden.html | Read via automated summary 2026-11-13. Personal recollection written decades later. It concerns a real private family: do not copy names, addresses or personal details. Useful only as a pointer to what to look for in primary sources. |

## Sources to look for (not yet located)

- 1950 census enumeration district maps and descriptions for Malden.
- Published 1950 and 1960 census tract reports covering Malden.
- Massachusetts Cultural Resource Information System (MACRIS) inventory forms for Linden buildings.
- Dated photographs of Linden (Malden Public Library photograph collection; Digital Commonwealth).
- Boston & Maine Railroad and street-railway/bus timetables for the 1950s.
- City of Malden annual reports, assessor's records and building permits for the 1950s.
- State and federal aerial surveys beyond the single lead above.
