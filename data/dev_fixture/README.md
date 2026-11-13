# data/dev_fixture

**Everything in this directory is fictional.** "Fixture Street" is an invented place used to build and test the game before historical research is complete. It is not Linden, it is not in Malden, and it must never be presented as real geography.

`areas/fixture_street/area.json` holds the street, lots, buildings and exits. The file declares `"fictional": true` with a notice, every record carries `"provenance": {"status": "placeholder"}`, and the validator rejects any fixture record that uses the real place names. The game shows a "fictional test street" banner whenever this area is loaded.

The people who live on it are in the scenario, under `data/fiction/scenarios/`.
