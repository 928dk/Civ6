# Civ 6 Map Script — Research Notes

> Target: a Lua **map script** for Sid Meier's Civilization VI (native Linux/Aspyr build, R&F + Gathering Storm active).

## 1. Environment (verified on 2026-09-19)

- **Game version:** 1.0.12.9, build 363760 (`com.aspyr.civ6.version.json`).
- **DLC present:** XP1 (Rise & Fall, `libGameCore_XP1.so`) + XP2 (Gathering Storm, `libGameCore_XP2.so`).
- **Steam library:** `/run/media/$USER/DATA/SteamLibrary/`
- **Game install:** `steamapps/common/Sid Meier's Civilization VI/` — content root is `steamassets/` (lowercase `base/`, `dlc/`).
- **Vanilla map scripts:** `steamassets/base/assets/maps/*.lua` (continents, fractal, pangaea, lakes, terra, seven_seas, inland_sea, island_plates, small_continents, shuffle, wbimport, worldbuildermap).
- **Shared generators/utilities:** `steamassets/base/assets/maps/utility/`:
  - `mapenums.lua`, `maputilities.lua`, `terraingenerator.lua`, `riverslakes.lua`,
  - `mountainscliffs.lua`, `featuregenerator.lua`, `naturalwondergenerator.lua`,
  - `resourcegenerator.lua`, `assignstartingplots.lua`, `setdefaultassignedstartingplots.lua`, `plotfiltering.lua`.
- **User data locations (both exist, both empty `Mods/`):**
  - `~/Documents/My Games/Sid Meier's Civilization VI/Mods/`
  - `~/.local/share/aspyr-media/Sid Meier's Civilization VI/Mods/`
  - → must confirm which one the Aspyr build actually loads before deploying.

## 2. Map-script API (from installed vanilla scripts + utility/*.lua)

### Entrypoints the engine calls
| Function | Required? | Purpose |
|----------|-----------|---------|
| `GenerateMap()` | **YES** | Main build; engine errors `Cannot find map script entry point GenerateMap()` if missing. |
| `GetMapScriptInfo()` | optional | Returns table: `Name`, `Description`, `IsAdvancedMap`, `IconIndex`, `SortIndex`, `CustomOptions`. From `WorldBuilderMap.lua` / PerfectWorld precedent: `CustomOptions = { world_age, temperature, rainfall, sea_level, resources }` via `GetCoreMapOptions()`. |
| `GetMapInitData(MapSize)` | optional | Return `{ Width = w, Height = h, WrapX = bool }`. `Map.GetGridSize()` then returns these. Used to force a fixed grid / no wrap. |

### Key globals (from `mapenums.lua`)
- Plot types: `g_PLOT_TYPE_NONE/MOUNTAIN/HILLS/LAND/OCEAN`
- Terrains: `g_TERRAIN_TYPE_GRASS, _GRASS_HILLS, _PLAINS(+HILLS), _DESERT(+HILLS), _TUNDRA(+HILLS), _SNOW(+HILLS), _COAST, _OCEAN` (+ `*_MOUNTAIN` variants)
- Features: `g_FEATURE_NONE, _FLOODPLAINS, _ICE, _JUNGLE, _FOREST, _OASIS, _MARSH` + natural wonder constants
- Yields: `g_YIELD_FOOD/PRODUCTION/GOLD/SCIENCE/CULTURE/FAITH`
- `DirectionTypes = { NORTHEAST=0, EAST=1, SOUTHEAST=2, SOUTHWEST=3, WEST=4, NORTHWEST=5 }`

### Key API objects
- `Map.GetGridSize()`, `Map.GetPlotByIndex(i)`, `Map.GetAdjacentPlot(x,y,dir)`, `Map.GetPlotCount()`
- `TerrainBuilder.SetTerrainType(pPlot, terrain)`, `.GetFractalFlags()`, `.GetRandomNumber(n, name)`, `.AnalyzeChokepoints()`, `.StampContinents()`
- `AreaBuilder.Recalculate()`; `Areas.FindBiggestArea(false)` returns area w/ `.GetPlotCount()`
- `riverslakes.lua`: `AddRivers()`, `AddLakes(n)` (n from `GameInfo.Maps[size].Continents`), `AddCliffs(plotTypes, terrainTypes)`
- `featuregenerator.lua`: `AddFeatures()` (uses passed globals)
- `naturalwondergenerator.lua`: `NaturalWonderGenerator.Create({ numberToPlace = GameInfo.Maps[size].NumNaturalWonders })`
- `resourcegenerator.lua`: `ResourceGenerator.Create(args)` + `:Generate()`
- `assignstartingplots.lua`: `AssignStartingPlots:AssignStartingPlots(iNumPlayers)` — called at end of `GenerateMap()`
- `setdefaultassignedstartingplots.lua`: `SetDefaultAssignedStartingPlots()`

### Deviations / notes
- `GetMapScriptInfo`/`GetSupportedMapSizes` are **not** defined in vanilla scripts — they are provided by the engine's Lua support layer. Custom scripts may define `GetMapScriptInfo()` to override the setup screen.

## 3. How a custom Lua map-script mod is registered

Based on PerfectWorld6 / Detailed Worlds / YnAMP precedent (CivFanatics "Getting a map script into Civ 6", 2018; .modinfo structure thread):

- **FrontEnd action** — `UpdateDatabase` with a `Configuration/Config.xml` that inserts a row into the **`Maps` table**:
  - Required columns incl. `File` (path to the .lua, relative to mod folder), `Name`, `Description`, `SortIndex`.
  - **R&F+ requires a `Domain` column** — add it, else the map won't show.
  - Optional `Parameters` table inserts to expose advanced map options (World Age, Temperature, Rainfall, Sea Level, Resources, Start Position).
- **InGame action** — `ImportFiles` shipping the `.lua` map script so the engine can load & run it.
- The `.modinfo` root needs unique `id`, plus `<Properties>` (Name/Teaser/Description/Authors), `<Files>` listing every shipped file.
- YnAMP structure reference (fetched 2026-09-19): `Maps/<MapName>/<MapName>.lua` scripts, FrontEnd `UpdateDatabase` on `Configuration/*.xml`, InGame `ImportFiles` for the scripts, criteria-based components for XP1/XP2.
- **Gotcha (verified in-game 2026-09-20):** `<Properties>` must include `<CompatibleVersions>2.0</CompatibleVersions>` or the mods screen warns the mod is not marked compatible with the game version (vanilla DLC uses `2.0`, workshop "1.2,2.0").
- **Gotcha (verified in-game 2026-09-20):** `UpdateText` text files need a `<GameData>` root wrapper — a bare `<LocalizedText>` root is rejected ("Input XML does not contain database entry tags. GameData, GameInfo or Database" in `Logs/Database.log`) and the map list shows raw LOC keys. Use `<GameData><LocalizedText><Row Tag="…" Language="en_US"><Text>…</Text></Row>…</LocalizedText></GameData>`. See `docs/civ6-map-script-reference.md` §1.

## 4. Reference template — `continents.lua` generation order

1. `g_iW, g_iH = Map.GetGridSize()`
2. `g_iFlags = TerrainBuilder.GetFractalFlags()`
3. `temperature = MapConfiguration.GetValue("temperature")`
4. `plotTypes = GeneratePlotTypes()`  ← custom land/water shape goes here
5. `terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature)`
6. `ApplyTerrain(plotTypes, terrainTypes)` (applies +HILLS delta)
7. `AreaBuilder.Recalculate()`
8. `AddRivers()`
9. `AddLakes(numLargeLakes)`  (after rivers; lakes before rivers block drainage)
10. `AddFeatures()`
11. `AddCliffs(plotTypes, terrainTypes)`
12. NaturalWonderGenerator → `AssignStartingPlots(n)` → `SetDefaultAssignedStartingPlots()`

## 5. Install verification targets (for final QA)

- XML well-formed: `xmllint --noout`
- Lua syntax: `luac -p` / `lua -e 'loadfile(...)'`
- In-game: Additional Content shows mod → Advanced Setup lists map → generate without `lua.log`/`database.log` errors → starts on land.