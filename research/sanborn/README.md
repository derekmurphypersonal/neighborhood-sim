# research/sanborn

Working copies of Sanborn fire insurance map images for Malden, for research only. See `docs/research/SOURCES.md` (S-SANBORN-LOC, S-SANBORN-DATA) and Q-011 in `DECISIONS.md`: reproduction rights have not been settled, so **image files here are excluded from version control** by `.gitignore`.

Source: the Library of Congress "Sanborn maps" data package published by LC Labs (https://loc-sanborn-maps.s3.amazonaws.com/), folder `maps-by-state/Massachusetts/data/`. File names are unchanged. Downloaded 2026-11-13; MD5 checksums matched the package manifest. These are medium-resolution JPEGs (about 1,650 pixels wide for the 1951 volume, 1,100 for the 1957 volume). Full-resolution images are on loc.gov.

| File | What it is |
|---|---|
| `malden_editions.csv` | The seven Malden entries from the package's `metadata.csv` |
| `sanborn03774_006_62.jpg` | Volume corrected to March 1951, sheet 62 (labelled "Linden") |
| `sanborn03774_006_70.jpg` | Volume corrected to March 1951, sheet 70 (labelled "Linden") |
| `sanborn03774_006_79.jpg` | Same volume: additional street indexes (March 1951 and March 1938) |
| `sanborn03774_006_80.jpg` | Same volume: title page and street index (April 1932) |
| `sanborn03774_007_19.jpg` | 1957 volume, sheet 20 (marked "N.E.", December 1956, adjoining sheets 62 and 70) |
| `sanborn03774_007_71.jpg` | 1957 volume, sheet 62 |
| `sanborn03774_007_79.jpg` | 1957 volume, sheet 70 |

In the 1951 volume, image number equals sheet number for sheets 60 to 75. In the 1957 volume the images are not in sheet order and many sheets appear twice.
