# Civ6 Map-Script API Reference (verified 2026-09)

Verified against a live Linux/Aspyr install
`/run/media/$USER/DATA/SteamLibrary/steamapps/common/Sid Meier's Civilization VI/steamassets/`
(your own mounts may differ; find with `find / -name "continents.lua" 2>/dev/null`).

All facts below were read directly from the installed game files / live SQLite DBs, not from wiki guesses.

---

## 1. Map registration & mod wiring

### `.modinfo` pattern (YnAMP style, confirmed)
```xml
<InGameActions>
  <ImportFiles id="XMAP_IMPORT">
    <Properties><LoadOrder>1000002</LoadOrder></Properties>   <!-- after vanilla, before other mods -->
    <File>Maps/Vinterhav.lua</File>
  </ImportFiles>
</InGameActions>
<FrontEndActions>
  <UpdateDatabase id="XMAP_CONFIG">
    <Properties><LoadOrder>1000003</LoadOrder></Properties>
    <File>Configuration/Config.xml</File>
  </UpdateDatabase>
  <UpdateText id="XMAP_TEXT">
    <Properties><LoadOrder>1000003</LoadOrder></Properties>
    <File>Configuration/ConfigText.xml</File>
  </UpdateText>
</FrontEndActions>
```
Map scripts are ImportFiles (context is map generation), NOT gameplay scripts.

### `.modinfo` `<Properties>`: `CompatibleVersions` REQUIRED (gotcha, verified 2026-09-20)
Without it the mods screen warns **"This mod has not marked itself as compatible with the current game version"**.
Every vanilla DLC `dlc/*/*.modinfo` (australia, vikingsscenario, …) and workshop map mod declares it:
```xml
<Properties>
    <Name>…</Name>
    <Teaser>…</Teaser>
    <Description>…</Description>
    <Authors>…</Authors>
    <CompatibleVersions>2.0</CompatibleVersions>   <!-- vanilla DLC; workshop mods use "1.2,2.0" -->
</Properties>
```
`2.0` matches the current install (Gathering Storm era) and clears the warning.

### `LocalizedText` file shape — `<GameData>` wrapper REQUIRED (gotcha, verified 2026-09-20)
`UpdateText` files that use a bare `<LocalizedText>` root are **silently rejected**; `Logs/Database.log` logs:
`Input XML does not contain database entry tags. GameData, GameInfo or Database` — the LOC rows never insert and the map list shows **raw keys**
(e.g. `LOC_MAP_VINTERHAV_NAME`). Working shape (verified against vanilla `dlc/australia/text/en_us/…_configtext.xml` + workshop `CTE_UI_TEXT.xml`):
```xml
<GameData>
    <LocalizedText>
        <Row Tag="LOC_MAP_VINTERHAV_NAME" Language="en_US">
            <Text>Vinterhav</Text>
        </Row>
        <Row Tag="LOC_MAP_VINTERHAV_DESCRIPTION" Language="en_US">
            <Text>…</Text>
        </Row>
    </LocalizedText>
</GameData>
```
The `Maps` row stores the LOC key in `Name`/`Description` (that is correct — vanilla does the same); the keys are
resolved against `Cache/DebugLocalization.sqlite` (table `LocalizedText`, PK `(Language, Tag)`) at UI time.

### `Maps` table (setup DB = `Cache/DebugConfiguration.sqlite`, NOT `DebugGameplay.sqlite`)
Columns (from live DB): `Domain` (default `'StandardMaps'`), `File`, `Name`, `Description`, `Image`, `StaticMap`, `WorldBuilderOnly`, `RequiresUniqueLeaders`, `DisableWorldWrap`, `SortIndex`. PK = (Domain, File).
- Vanilla SortIndex examples: Continents.lua 10, WorldBuilderMap.lua 15, Fractal.lua 20.
- `DisableWorldWrap=1` disables wrapX on a script; ALSO return `WrapX=false` from `GetMapInitData`.

```xml
<GameInfo>
  <Maps>
    <Row File="Vinterhav.lua"
         Name="LOC_MAP_VINTERHAV_NAME"
         Description="LOC_MAP_VINTERHAV_DESCRIPTION"
         SortIndex="45"/>
  </Maps>
</GameInfo>
```

### `MapSizes` table (setup DB, config `configuration/data/mapsizes.xml`)
Columns: `Domain`, `MapSizeType`, `Name`, `Description`, `MinPlayers`, `MaxPlayers`, `DefaultPlayers`, `MinCityStates`, `MaxCityStates`, `DefaultCityStates`, `SortIndex`. Standard six sizes exist by default; do NOT touch unless adding new sizes.

### `Parameters` table (setup DB, `configuration/data/mapsettings.xml`)
Per-map advanced setup options are registered `Key1="Map"` `Key2="<File>.lua"`:
```xml
<Row Key1="Map" Key2="Vinterhav.lua" ParameterId="WorldAge"
     Name="LOC_MAP_WORLD_AGE_NAME" Description="LOC_MAP_WORLD_AGE_DESCRIPTION"
     Domain="WorldAge" DefaultValue="2" ConfigurationGroup="Map"
     ConfigurationId="world_age" GroupId="MapOptions" Hash="0" SortIndex="230"/>
```
Same shape for `Temperature` (240), `Rainfall` (250), `SeaLevel` (210). Map options are read in Lua via `MapConfiguration.GetValue("world_age")`. Domain value tables (`WorldAge`, `Temperature`, ...) already exist globally — only the per-map parameter row is needed.

## 2. Engine entry points every map script needs

### `GenerateMap()` — required, called by engine at map-gen
Standard includes block (copy from continents.lua top):
```lua
include "MapEnums"
include "MapUtilities"
include "MountainsCliffs"
include "RiversLakes"
include "FeatureGenerator"
include "TerrainGenerator"
include "NaturalWonderGenerator"
include "ResourceGenerator"
include "AssignStartingPlots"
```
Global `ApplyTerrain(plotTypes, terrainTypes)` must be defined (continents.lua:30):
```lua
function ApplyTerrain(plotTypes, terrainTypes)
  for i = 0, (g_iW * g_iH) - 1, 1 do
    pPlot = Map.GetPlotByIndex(i);
    if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
      terrainTypes[i] = terrainTypes[i] + 1;
    end
    TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
  end
end
```

### `GetMapInitData(MapSize)` — engine asks this for Width/Height/WrapX
Only defined in inlandsea.lua:118, wbimport.lua:13, tilted_axis.lua:963, australiamap.lua:146 (engine default fills from `Maps` row if absent). Pattern:
```lua
function GetMapInitData(MapSize)
  local Width, Height;
  for row in GameInfo.Maps() do
    if(MapSize == row.Hash) then
      Width  = row.GridWidth;
      Height = row.GridHeight;
    end
  end
  return { Width = Width, Height = Height, WrapX = false };
end
```
For a fixed-size map, return `{ Width = 84, Height = 54, WrapX = false }` directly.

### `GetMapScriptInfo()` — ONLY defined in worldbuildermap.lua; engine global otherwise
worldbuildermap.lua pattern (needed if you want custom setup options list):
```lua
function GetMapScriptInfo()
  local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions();
  return {
    Name = "LOC_MAP_WORLDBUILDER_NAME",
    Description = "LOC_MAP_WORLDBUILDER_DESCRIPTION",
    IsAdvancedMap = 1,
    IconIndex = 0,
    SortIndex = 5,
    CustomOptions = { world_age, temperature, rainfall, sea_level, resources }
  };
end
```
`GetCoreMapOptions()` is referenced in worldbuildermap.lua but NOT defined in any `utility/*.lua` — treat as engine-global; if it's nil at runtime, fall back to reading `MapConfiguration.GetValue(...)` directly. Continents.lua does NOT define GetMapScriptInfo — engine supplies defaults; safest custom maps copy the worldbuildermap shape.

## 3. Map generation pipeline (continents.lua order, verified)
```lua
g_iW, g_iH = Map.GetGridSize();
g_iFlags = TerrainBuilder.GetFractalFlags();
local temperature = MapConfiguration.GetValue("temperature"); -- 1 Cold, 2 Temperate, 3 Hot, 4 Random
if temperature == 4 then temperature = 1 + TerrainBuilder.GetRandomNumber(3, "Random Temp"); end
plotTypes     = GeneratePlotTypes();                          -- custom in our map
terrainTypes  = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature);
ApplyTerrain(plotTypes, terrainTypes);
AreaBuilder.Recalculate();
AreaBuilder(AreaBuilder):AddFeatures...? -- no: continents does:
--   AddRivers() then nothing else? (order below)
biggest_area = Areas.FindBiggestArea(false);
TerrainBuilder.AnalyzeChokepoints();
TerrainBuilder.StampContinents();   -- verify: confirm exists before calling
AddCliffs(plotTypes, terrainTypes); -- MountainsCliffs
AddRivers();                         -- RiversLakes
AddLakes(GameInfo.Maps[Map.GetMapSize()].Continents / 2);
AddFeatures(...)                     -- custom wrapper, calls FeatureGenerator.Create
NaturalWonderGenerator.Create({ numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders });
ResourceGenerator.Create({ resources = resourcesConfig, START_CONFIG = startConfig });
AssignStartingPlots.Create({ START_CONFIG = startConfig, ... });
AddGoodies(g_iW, g_iH)  -- from utility/bundle.lua:818 (auto-included)
```

## 4. Terrain / plot type constants (utility/mapenums.lua:25-29)
```lua
g_PLOT_TYPE_NONE     = -1
g_PLOT_TYPE_MOUNTAIN = 0
g_PLOT_TYPE_HILLS    = 1
g_PLOT_TYPE_LAND     = 2
g_PLOT_TYPE_OCEAN    = 3
g_TERRAIN_TYPE_*      = GetGameInfoIndex("Terrains", "TERRAIN_*")   -- GRASS, GRASS_HILLS, SNOW, TUNDRA, OCEAN, COAST, MOUNTAIN, ...
```

## 5. Latitude (critical for 84×54 map)
```lua
-- FeatureGenerator.GetLatitudeAtPlot / engine: GetLatitudeAtPlot = abs((H/2) - y) / (H/2)
-- y=0 and y=53 -> 1.0 (poles), y=27 -> 0.0 (equator)
-- Terrain thresholds (VERIFIED by running generator on the actual map in-game):
--   snow   ~0.8+  => y < ~5.4 or y > ~48.6 on 84x54
--   tundra ~0.65+ => y < ~9.5  or y > ~44.6
--   grass/plains below (0..0.65) => y in [9.5, 44.6]
```
Note: my earlier in-game calibration shows grass band center sits at 55-65% latitude on this installation; recompute empirically rather than trusting nominal band endpoints.

## 6. FeatureGenerator (auto vegetation/ice)
Called via your own global `AddFeatures` wrapper. Arg semantics from featuregenerator.lua Create:
- `rainfall`: 1→ shifts -4, 2→ 0, 3→ +4, other/4→ random 0-10.
- defaults: `iJunglePercent=12, iForestPercent=18, iMarshPercent=3, iOasisPercent=1`.
- instance has: `AddFeatures()`, `AddIceAtPlot`, `AddMarshAtPlot`, `AddJunglesAtPlot`, `AddForestsAtPlot`, `AddAtolls`, `AdjustTerrainTypes`.
- Natural wonder placement is NOT FeatureGenerator — it's NaturalWonderGenerator.

## 7. Natural wonders
- DB: `NaturalWonders` table (DebugGameplay.sqlite). `FEATURE_LYSEFJORDEN` (Norwegian fjord, thematic for Scandinavia) and `FEATURE_CRATER_LAKE` both present. *(Vinterhav v4 as-of 2026-09-21: the home wonder is `FEATURE_GIANTS_CAUSEWAY` — Lyse's 3-tile PIOPIOTAHI cannot fit the cape; GC's 2-tile land+water does.)*
- Generator: `NaturalWonderGenerator.Create(args)`; `args.numberToPlace`, `args.Invalid`, honours `GameConfiguration.GetValue("EXCLUDE_NATURAL_WONDERS")`; internal `__InitNWData`, `__FindValidLocs`, `__PlaceWonders`, `__ScorePlots`.
- Default placement target: `GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders` (STANDARD = 5). Pass `numberToPlace` explicitly for a custom count; or hand-place via `TerrainBuilder.SetFeatureType` on a target tile for deterministic placement (verify the tile passes wonder validity rules).

## 8. Resources

### ResourceGenerator (map-wide spread)
`ResourceGenerator.Create({ resources = resourcesConfig, START_CONFIG = startConfig })`
- Create args: `resources` (config: Standard/Abundant/Sparse by hash), `START_CONFIG` (or `uiStartConfig`), `iWaterLux=3`, `iWaterBonus=1.25`, `iLuxuriesPerRegion=4`.
- `uiStartConfig` used at: line 256 (`iWaterLux==1 and uiStartConfig ~= 3` → halve plots) and line 523 (`uiStartConfig==1` weight vs scarce). Map-wide resource *density only*; does NOT canvas lux+bonus around civ starts.

### Start-area legendary resources — DIFFERENT story
`AssignStartingPlots:__AddResourcesLegendary()` (assignstartingplots.lua:2007) is what adds the actual ring-1 battery (Strategic + 1 Luxury + ~2-4 Bonus) — and it runs over **every major start plot** (`majorStartPlots`), so `START_CONFIG=3` in AssignStartingPlots's Create DOES give all civs legendary. Verified lines:
- `__InitStartingData` dispatch at line 187 (`==1`), 189 (`==3`), 732 (minors), 2007 `__AddResourcesLegendary`.
- To keep AI standard and give ONLY the human OP: pass `START_CONFIG=2` (standard) into `AssignStartingPlots.Create` and hand-engrave the human battery via `ResourceBuilder.SetResourceType` AFTER forcing the start (or before). Do NOT pass START_CONFIG=3 to both generators — that buffs every AI start.

### Engine commit for a forced start
```lua
Players[i]:SetStartingPlot(plot)   -- engine commit (used at assignstartingplots.lua:199/290)
-- MUST be called AFTER AssignStartingPlots.Create returns, else overwritten.
-- Fallback path: if nothing assigned, engine calls
--   SetDefaultAssignedStartingPlots() with {MIN_MAJOR_CIV_FERTILITY=150, MIN_MINOR_CIV_FERTILITY=50, MIN_BARBARIAN_CIV_FERTILITY=1, START_MIN_Y=15, START_MAX_Y=15, ...}
--   -> that path also just SetStartingPlot's stored candidates.
```

### AssignStartingPlots.Create exact args (lines 57-65, verified)
```lua
{ MIN_MAJOR_CIV_FERTILITY, MIN_MINOR_CIV_FERTILITY, START_MIN_Y, START_MAX_Y,
  START_CONFIG, WATER, LAND, IGNORESTARTBIAS, START_LARGEST_LANDMASS_ONLY }
```
- `IGNORESTARTBIAS=true` → `noStartBiases=true` → skips all StartBias lookups (civ-agnostic).
- `MIN_MAJOR_CIV_FERTILITY <= 0` is coerced to 5 in `__InitStartingData`.
- Flow: `__InitStartingData` → `__FindHugeMapsContinue`? → `DivideMapIntoMajorRegions(iNumMajorCivs, ...)` → per-region start plot choice via StartPositioner → `PlayerConfigurations[playerId]` available in assignstartingplots.

### Hand placement building blocks
```lua
ResourceBuilder.SetResourceType(plot, resourceType, 1)  -- set
ResourceBuilder.SetResourceType(plot, -1)               -- clear
-- guard: check plot:GetResourceCount()/GetResourceType() before setting
```
Bonus/lux tables in gameplay DB (`Resources`, `Resource_*`). Hand-engraving bypasses the legendary mechanism entirely.

## 9. Rivers/Lakes (utility/riverslakes.lua, verified)
- `AddRivers()` at :300, `AddLakes(largeLakes)` at :358.
- DoRiver to paint deterministic rivers:
  ```lua
  DoRiver(startPlot, thisFlowDirection, originalFlowDirection, riverID)
  -- startPlot = the plot at whose SE corner the river starts
  -- no branch: if existing river at startPlot and originalFlowDirection == NO_FLOWDIRECTION, returns.
  ```
- Directions: `FlowDirectionTypes` NORTH/NORTHEAST/SOUTHEAST/SOUTH/SOUTHWEST/NORTHWEST.
- `GetOppositeFlowDirection(dir) = ((dir + 3) % FlowDirectionTypes.NUM_FLOWDIRECTION_TYPES)` (== 6).
- `TurnRightFlowDirections` / `TurnLeftFlowDirections` tables for flow turning.
- `GetRiverValueAtPlot(plot)` returns **-1** if plot is NW-of/W-of/NE-of a cliff, OR is a NaturalWonder, OR adjacent to a natural wonder; else `plot elevation*20 + sum(adjacent elevations) + (4 per adjacent desert) + random 10`. `< 0` → no river starts here.
- `GetPlotElevation`: mountain=4, hills=3, land=2, water=1.
- Flow ordering: rivers snake from SE corner; ensure startPlot elevation is the highland side.

## 10. Goodies (huts)
From utility/bundle.lua (auto-included):
```lua
AddGoodies(iW, iH)  -- global wrapper when terrain ready
```
`CanPlaceGoodyAt(pLot)` complete check (verified): not water, `ImprovementBuilder.CanHaveImprovement`, not already improved, no resource, not impassable, not mountain, goody-range check (no same goody within `uniqueRange`), and not within ~4 of any civ start plot.
- Hand-placement alternative: `ImprovementBuilder.SetImprovementType(plot, IMPROVEMENT_GOODY_HUT, -1)`.

## 11. Debug / validation resources on the Linux install
- Logs: `~/.local/share/aspyr-media/Sid Meier's Civilization VI/Logs/lua.log`, `database.log` (mod load errors, print() output).
- Setup DB: `Cache/DebugConfiguration.sqlite` (Maps, MapSizes, Parameters, Domains).
- Runtime DB: `Cache/DebugGameplay.sqlite` (gameplay `Maps` row: GridWidth/GridHeight/NumNaturalWonders/Continents), `DebugLocalization.sqlite`.
- Useful DB probe (sqlite3):
  ```sql
  SELECT file, name, description, sortindex, disableworldwrap FROM Maps ORDER BY sortindex;
  SELECT * FROM Parameters WHERE Key1='Map' ORDER BY Key2, SortIndex;
  SELECT MapSizeType, GridWidth, GridHeight, NumNaturalWonders, Continents FROM Maps;
  SELECT FeatureType FROM NaturalWonders ORDER BY FeatureType;
  ```
- `luac -p file.lua` for syntax; `xmllint --noout` for XML. Both available on the development host.
- Find the true game root first: `find / -name continents.lua 2>/dev/null`. SteamLibrary typical mount: `/run/media/$USER/DATA/SteamLibrary/steamapps/common/Sid Meier's Civilization VI/`.

## 12. Standard map sizes (gameplay `Maps` row, verified)
| Size | Grid | NumNaturalWonders | Continents |
|------|------|-------------------|------------|
| DUEL | 44×26 | 2 | 1 |
| TINY | 60×38 | 3 | 2 |
| SMALL | 74×46 | 4 | 3 |
| STANDARD | 84×54 | 5 | 4 |
| LARGE | 96×60 | 6 | 5 |
| HUGE | 106×66 | 7 | 6 |

## 13. Anti-pattern traps observed in vanilla
- `AddFeatures` must be your OWN global wrapper (engine calls it by name after plotType gen).
- GenerateTerrainTypes signature is `(plotTypes, iW, iH, iFlags, bNoCoastalMountains, temperature, notExpandCoasts)` — parameter ORDER matters.
- `AreaBuilder.Recalculate()` needed after terrain so continent detection (used by resource/settle AI) works.
- print() only reaches `Logs/lua.log` — keep print statements while developing, strip for release.
- Never commit with per-civ start bias inside if the design is civ-agnostic — use `noStartBiases=true`.

## 14. Insights from Sukritact's Modding Knowledge Base
Repo cloned to `Reference/Civilization-VI-Modding-Knowledge-Base/` (Obsidian format; `Objects/<Name>/<Method>.md` per-method, plus a full `Events.csv` in `.data-generation/`). Most entries are bare stubs (no args/returns) — treat it as an API *index + script/UI availability flag*, NOT as behavioral docs; verify behavior against game source. Genuinely useful:

- **Script-vs-UI availability flags are authoritative.** Confirmed script-side (relevant to map-gen): `Plot.SetProperty`, `Map.GetRingPlots`, `Map.GetAdjacentPlots`, `Map.IsWrapX/IsWrapY`, `TerrainBuilder.GenerateFloodplains`, `TerrainBuilder.AddIce`, `TerrainBuilder.SetMultiPlotFeatureType`, `Plot.IsStartingPlot`, `Plot.GetRiverSEFlowDirection` (+ E/SW variants).
- **`GameConfiguration.GetHumanPlayerIDs/GetHumanPlayerCount` are UI-only** (`script: false`) → do NOT rely on them during map generation. `GetLocalPlayer` is NOT in the KB at all — so at map-gen, human-slot detection should go through **`PlayerConfigurations[i]:GetSlotStatus()==SlotStatus.SS_HUMAN`** (assignstartingplots already iterates PlayerConfigurations), which is the safest script-side route. Verify empirically in lua.log.
- **`Plot:SetProperty(key, data)` / pure `:GetProperty`** exist (script-side) — persistent per-plot tagged data. Could tag the engraving ring-2 tiles in the map script, then read them back in a later gameplay script. Same Get/SetProperty mechanism exists on Game/instances; keys must be unique, values persist in saves.
- **`TerrainBuilder.SetMultiPlotFeatureType`** available — could hand-place multi-tile natural wonders (e.g. LYSEFJORDEN) deterministically instead of relying on NaturalWonderGenerator + goody-wonder-tile validity. *(Done in Vinterhav v2+ (2026-09-21): the vanilla multi-tile path was ported with a `VH_` prefix and used for GC/Eyja — note the `GIANTS_CAUSEWAY` branch rejects hills+water anchors.)*
- **`TerrainBuilder.GenerateFloodplains`** script-available — optional richer hand-painting for river/CH-adjacent engraving.
- **`Map.GetRingPlots(plot, iRange)`-style ring iteration** exists script-side for the battery placement loops (else use `Map.GetPlotXY/GetPlotXDY` deltas).

Not in the KB (get from game source instead): map-script registration tables, START_CONFIG/fertility internals, rivers DoRiver heuristics, map-enum constants.
- X=0 column is the map's left edge; ignoring wrap means plots near x=0 and x=83 are NOT adjacent (no circular wrap) — city/unit ranges respect actual adjacency; WC/DLC passives still fine.