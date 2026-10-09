# Plan: "Vinterhav" — fantasy-Scandinavia map script for Civ 6

> Status: **IMPLEMENTED & DEPLOYED** (2026-09-20) — map authored, statically validated, deployed to live `Mods/`.
> In-game T015: map generates & plays (user ran 33 turns as Norway); UI gotchas fixed (see `docs/civ6-map-script-reference.md` §1).
> This file tracks the original base-map plan; the OP/achievement build is `Plan V2.md`.

## Goal
Hand-shaped, seed-varied **fantasy Scandinavia** map as a Civ 6 **Lua map script** for the native Linux/Aspyr build (R&F + Gathering Storm). Fixed grid (~standard size), no map wrap, tuned for **6–8 players**.

## Map design (fixed topology + seeded jitter)
- **Grid:** ~84×54 via `GetMapInitData(MapSize)` → `{ Width, Height, WrapX = false }`. Decide exact W/H at implementation.
- **Climate bands:** north = Arctic (snow/tundra + ice), south = temperate (grass/plains; Denmark at bottom). **No desert.**
- **Landmasses (recognizable fantasy Nords):**
  - **West ridge:** long N–S Norwegian mountain/hill spine with carved **fjords** opening west to a North Sea / Atlantic ocean.
  - **South-center:** low rolling **Denmark** + small island scatter (Fyn/Sjælland analogues), separated by coastal straits (Kattegat/Sund).
  - **East-center:** larger **Swedish** landmass with interior lakes (Vänern/Vättern analogues) and an east Baltic **archipelago** (Gotland/Öland analogues).
  - **Northeast:** tundra **Finnmark/Lappland** analogue fading to snow.
- **Coastline:** authored Lua "blueprint" (coastline decision table) + seed-varied jitter via `TerrainBuilder.GetRandomNumber` — shape preserved between games, detail varies.
- **Fill:** `plotTypes` built directly (like `continents.lua`) with HILLS/MOUNTAIN; forests/features/resources/start-plot fairness left to the stock seed-random generators for replayability.
- **Optional:** hardcoded **True-Start-Location** entry list for classic civs (Norway, Russia, Germany, Poland, England, France, Netherlands, Rome…) used when those civs are selected.

## Deliverables (files to create)
```
Vinterhav/                          (mod folder; name TBD with user)
├── Vinterhav.modinfo               # Properties + FrontEnd UpdateDatabase (Maps table) + InGame ImportFiles (.lua)
├── Configuration/
│   ├── Config.xml                  # Maps table row (File→Vinterhav.lua, Name, Description, SortIndex, Domain [+Parameters])
│   └── ConfigText.xml              # LOC_ strings (en_US)
└── Maps/
    └── Vinterhav.lua               # the map script (GenerateMap / GetMapScriptInfo / GetMapInitData)
```
- Canonical source (version-controlled) in this repository, plus a deployed copy into the live `Mods/` folder.

## Implementation steps
1. **Confirm live user-data dir** (`Documents/My Games/…/Mods` vs `~/.local/share/aspyr-media/…/Mods`) — check which the Aspyr build loads.
2. **Dump vanilla `Maps` table schema** from the game config DB (`Cache/DebugConfiguration.sqlite` under `aspyr-media/…`) to copy exact columns/values (`Domain`, `SortIndex`, `Group`).
3. **Author `Vinterhav.lua`** (mirror vanilla includes + order):
   - include MapEnums, MapUtilities, MountainsCliffs, RiversLakes, FeatureGenerator, TerrainGenerator, NaturalWonderGenerator, ResourceGenerator, AssignStartingPlots, SetDefaultAssignedStartingPlots.
   - `GetMapInitData(size)` → fixed W/H, `WrapX=false`.
   - `GenerateMap()` → blueprint-driven `plotTypes` + jitter → `GenerateTerrainTypes(temp)` → `ApplyTerrain` → `AreaBuilder.Recalculate()` → `AddRivers()` → `AddLakes()` → `AddFeatures()` → `AddCliffs()` → ResourceGenerator → `AssignStartingPlots(n)` + `SetDefaultAssignedStartingPlots()` → optional TSL override.
   - `GetMapScriptInfo()` → name/description + core map options.
4. **Write `Config.xml` + `.modinfo`** (Maps insert with `Domain`, loc text, `ImportFiles`, full `Files` list).
5. **Validate before shipping:** `xmllint --noout` on XML; Lua syntax check (`luac -p` / `lua -e 'loadfile(...)'`, or in-game `lua.log` fallback).
6. **Deploy** to live `Mods/`; user enables mod in Additional Content (restart) → selects Vinterhav in Advanced Setup → generates → check `lua.log`/`database.log`, iterate on reported issues.
7. Keep source under `~/projects/Client/Civ6/` for the existing Git topology.

## Verification
- XML well-formed; Lua syntax valid; constants match installed `mapenums.lua`.
- In-game: dropdown entry appears → generation without errors → starts on land → playable.

## Open decisions (defaults unless user objects)
1. **Map name:** "Vinterhav" (default) vs "Nordgavlen" / "Midgard-Mare" / user's own.
2. **Start positions:** default = fair random; optional TSL table — default **include**.
3. **Grid:** fixed ~84×54 (hand-shaped feel, no wrap) — default; vs draggable across standard sizes.
4. **Spec folder:** create `~/.opencode/specs/140-civ6-vinterhav/` per AGENTS.MD Gate 3 before implementation.

## Related references
- `~projects/Client/Civ6/research.md` — verified API + registration details.
- Game: the install's `steamassets` `base/assets/maps/` + `utility/` (see research.md §1–§4).