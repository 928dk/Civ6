# save-inspect — .Civ6Save binary inspection tools

Inspect and debug Civ 6 save files without opening the game. Built during the
2026-09-21 Vinterhav forensics session (spec 140). Wonder placement is stored as
**numeric feature indices** in saves — never as wonder names — so verifying what a
map script actually placed (e.g. Giant's Causeway on the cape) requires walking the
save's plot array with these tools.

## Quick start

```bash
# dump the plot array (terrain/feature/resource/river per tile) to TSV
node tools/dump_tiles.js <save>.Civ6Save dump.tsv

# extract the serialized DB Features-table region (wonder feature names appear here)
node tools/features_table_extract.js <save>.Civ6Save

# Vinterhav grid helper: locate the 84×54 plot-count markers (4536) in a save
node tools/find_4536.js <save>.Civ6Save

# diff two saves (pre/post change, same game)
node tools/cross_diff.js <save-A>.Civ6Save <save-B>.Civ6Save

# Python variant of dump_tiles (self-contained decompress, no Node needed)
python3 tools/dump_tiles.py <save>.Civ6Save out.tsv
```

## Verifying the Vinterhav wonders in a fresh save

1. Generate a Vinterhav map and save at turn 0 (Aspyr Linux never writes `lua.log`,
   so the save is the only ground truth).
2. `node tools/dump_tiles.js save.Civ6Save out.tsv`
3. Map the plot-array feature indices back to feature names via the `Features`
   table (`Cache/DebugGameplay.sqlite`) or the serialized DB dump
   (`features_table_extract.js`).
4. Confirm: **Giant's Causeway** (2 tiles) on the cape NW of the capital
   (anchor ~(55,38)), **Eyja** 2-tile on Islandia, **Crater** single-tile south
   continent (30,48). (Vinterhav v4, spec 140; exact plot from `Plan V2.md`.)

`string_sweep.js` searches for specific wonder-name strings in a decompressed save —
update its list to `FEATURE_GIANTS_CAUSEWAY` to probe the current home wonder.

Smoke-test the tools against the upstream fixtures in `samples/`:

```bash
node tools/find_4536.js samples/Deity3.Civ6Save   # 84×54 grid → 4536 markers
```

## Tool index

| tool | purpose |
|------|---------|
| `dump_tiles.js` / `dump_tiles.py` | plot-array dump to TSV (terrain/feature/resource/river…) |
| `decode_plots.js` | byte-level decode of specific plots + global flag census |
| `cross_diff.js` / `cross_diff2.js` | diff two saves of the same game (tile walks aligned) |
| `dump_region.js` / `region2.js` | raw tile header bytes for a region (calibration) |
| `features_table_extract.js` | serialized DB Features-table region + wonder-name hits |
| `find_4536.js` | locate 84×54 plot-count markers (Vinterhav grid helper) |
| `find_image.js` | hunt embedded JPEG/PNG/DDS/BMP data |
| `find_triples.js` / `pin_blocks.js` / `team_blocks.js` / `team_dissect.js` | structure probes (count triples / team blocks) |
| `fog_extract.js` / `observe_dump.js` | observing-section headers + fog bitmap hunting |
| `grep_features.js` / `string_sweep.js` | feature-type string scans in the decompressed bin |
| `inspect_layout.js` / `per_row_align.js` / `render_bytes.js` | tile-record stride / alignment / byte→ASCII maps |
| `num_histo.js` / `num_hist2.js` / `num_count_test.js` / `test_sample_walk.js` / `walk_end_ours.js` / `river_scan.js` | record-model + river + census tests (Aspyr-save walk model) |

## Licensing / provenance

- `lib/decompress.js` — copied verbatim from **lucienmaloney/civ6save-editing**
  (https://github.com/lucienmaloney/civ6save-editing), ISC license (declared in its
  package.json; upstream ships no LICENSE file). Only runtime dependency is
  Node's built-in `zlib`.
- `samples/*.Civ6Save` — fixtures from the same upstream repo (`.bin` decompressed
  dumps were dropped; regenerate with any dump tool).
- `tools/*` — authored during the 2026-09-21 Vinterhav forensics (spec 140); all
  take save paths as CLI arguments. Day-specific probes (e.g. the original
  LYSEFJORDEN string list) are kept with their provenance.
- For a full structured parser (players, techs, cities) see the MIT-licensed
  upstream **pydt/civ6-save-parser** (https://github.com/pydt/civ6-save-parser).