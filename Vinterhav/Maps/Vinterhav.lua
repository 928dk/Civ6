------------------------------------------------------------------------------
-- FILE:    Vinterhav.lua
-- PURPOSE: Vinterhav — hand-shaped fantasy-Scandinavia map script (spec 140).
--          Fixed 84x54 grid, NO wrap. OP hand-engraved human homeland; cold,
--          sparse AI hemispheres. Tuned for Steam achievement clearing.
--
-- CONVENTION: plotTypes[]/terrainTypes[] are 0-indexed: index = y * g_iW + x.
--             Blueprint cells: each column = 6 x-tiles, each row = 2 y-tiles.
--
-- BLUEPRINT LEGEND (14 chars wide, 27 rows):
--   ~  deep ocean      .  shallow sea (speckles islets along coasts)
--   #  temperate land  T  tundra land      S  snow land
--   h  hills land      m  mountain
--   f  fjord anchor    g  god-site anchor (human OP cape is built here)
------------------------------------------------------------------------------

include "MapEnums"
include "MapUtilities"
include "MountainsCliffs"
include "RiversLakes"
include "FeatureGenerator"
include "TerrainGenerator"
include "ResourceGenerator"
include "AssignStartingPlots"

local g_iW, g_iH;
local g_iFlags = {};

-- XLOC = X-tile from blueprint column
local function XLOC(c) return 6 * c; end
-- YLOC = Y-tile from blueprint row
local function YLOC(r) return 2 * r; end

------------------------------------------------------------------------------
-- ASCII worldshape blueprint (north at top). Each entry must be exactly 14
-- chars. Validated by scripts/validate-mod.sh (legend: ~.#TShmfg).
------------------------------------------------------------------------------
local g_BLUEPRINT = {
    --  y0-1   Arctic polar sea
    "~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~",
    --  y4-7   Finnmark tundra/snow NE
    "~~~~~~~~~~TTTT",
    "~~~~~~~~~~STTT",
    --  y8-13  Norway north (c2 land, c3 spine); Finnmark c10-13
    "~~#h~~~~~~TTTT",
    "~~#m~~~~~~TTTT",
    "~~fm~~~~~~TTTT",
    --  y14-17 Islandia island (c0, channel c1); fjord anchor r8; Karelia bridge
    "T~fm~.~~~.~~TT",        -- c10-11 Bay of Bothnia; c12-13 Karelia bridge
    "T~fh~.~~~#.###",        -- Aaland isle c9; Sweden starts c11-13
    --  y18-21 Sweden mainland c10-13; Gotland (c6)
    "T~hh~.~~~~####",
    "T~fh~.h.~~####",
    --  y22-25
    "T~hh~.h.~~####",
    "T~fh~.h.~~####",
    --  y26-29  Vattern/Malaren painted later (lakes pass)
    "T~fh~.h.~~####",
    "T~hh~..~~~####",
    --  y30-33 Baltic opens; Sweden c10-13
    "~~hh~~~~~~####",
    "~~hh~~~~~~####",
    --  y34-37 Skane isthmus c9; sound c8; fjord carves r18
    "~~hh~~~~~#####",
    "~~ff~~~~~#####",
    --  y38-41 CAPITAL (57,39) at g (c9,r19); Denmark chain r20; cape notch
    "~~hh~~~~~g####",        -- god-site anchor = capital tile floor (57,39)
    "~~.#.###~.####",        -- Denmark chain c3-7 (Bornholm c6); sound c8
    --  y42-43 Sweden SE tip; buildcape point at x57-59 y42
    "~~~~~~~~~~####",
    --  y44-45 Channel (Denmark vs South continent)
    "~~~~~~~~~.....",
    --  y46-53 South continent (rivals) + central range m
    "~###TTTmm###~~",
    "~###TTTmm###~~",
    "~.##TTTmm###.~",
    "~..##TT###....",
};

g_BLUEPRINT_ROWS = #g_BLUEPRINT;         -- 27
g_BLUEPRINT_COLS = 14;                    -- 84 / 6

------------------------------------------------------------------------------
-- Keep-out box around the Skåne cape + god-site so coastline/lake passes
-- never destroy the hand-built OP homeland. Declared before the passes that
-- reference it (Lua locals are only visible after their declaration).
------------------------------------------------------------------------------
local function InCapeKeepOut(x, y)
    return x >= 52 and x <= 66 and y >= 34 and y <= 44;
end

------------------------------------------------------------------------------
-- Small debug helper (python-esque rjust for log alignment)
------------------------------------------------------------------------------
local function Pad(s, w)
    while #s < w do s = " " .. s; end
    return s;
end

------------------------------------------------------------------------------
-- GetMapInitData: fixed 84x54 grid, no wrap. Called by the engine before
-- GenerateMap(). Also mirrored in the Maps table row: DisableWorldWrap=1.
------------------------------------------------------------------------------
function GetMapInitData(MapSize)
    return { Width = 84, Height = 54, WrapX = false };
end

-----------------------------------------------------------------------------
-- GetMapScriptInfo: setup-screen metadata. Map is fixed 84x54, no wrap;
-- climate bands are hardcoded, so no advanced custom options are exposed.
-----------------------------------------------------------------------------
function GetMapScriptInfo()
    return {
        Name = "LOC_MAP_VINTERHAV_NAME",
        Description = "LOC_MAP_VINTERHAV_DESCRIPTION",
        IconIndex = 0,
        SortIndex = 45,
        CustomOptions = {},
    };
end

------------------------------------------------------------------------------
-- ApplyTerrain: required global (mirrors continents.lua). Hills get +1
-- (base -> *_HILLS); mountains were already typed by GenerateTerrainTypes.
------------------------------------------------------------------------------
function ApplyTerrain(plotTypes, terrainTypes)
    for i = 0, (g_iW * g_iH) - 1, 1 do
        local pPlot = Map.GetPlotByIndex(i);
        if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
            terrainTypes[i] = terrainTypes[i] + 1;
        end
        TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
    end
end

------------------------------------------------------------------------------
-- Rasterize the blueprint into plotTypes[] with light coastal jitter.
------------------------------------------------------------------------------
function RasterizeBlueprint(plotTypes)
    -- default: everything water
    for i = 0, (g_iW * g_iH) - 1 do plotTypes[i] = g_PLOT_TYPE_OCEAN; end

    local function SetCell(c, r, plotType)
        for x = XLOC(c), XLOC(c) + 5 do
            for y = YLOC(r), YLOC(r) + 1 do
                if x >= 0 and x < g_iW and y >= 0 and y < g_iH then
                    plotTypes[y * g_iW + x] = plotType;
                end
            end
        end
    end

    local cellType = {
        ["~"] = g_PLOT_TYPE_OCEAN,
        ["."] = g_PLOT_TYPE_OCEAN,
        ["#"] = g_PLOT_TYPE_LAND,
        ["T"] = g_PLOT_TYPE_LAND,
        ["S"] = g_PLOT_TYPE_LAND,
        ["h"] = g_PLOT_TYPE_HILLS,
        ["m"] = g_PLOT_TYPE_MOUNTAIN,
        ["f"] = g_PLOT_TYPE_LAND,
        ["g"] = g_PLOT_TYPE_LAND,
    };

    for r = 0, g_BLUEPRINT_ROWS - 1 do
        local row = g_BLUEPRINT[r + 1];
        for c = 0, g_BLUEPRINT_COLS - 1 do
            local ch = row:sub(c + 1, c + 1);
            local t = cellType[ch];
            if t ~= nil then SetCell(c, r, t); end
        end
    end
end

------------------------------------------------------------------------------
-- Coastal detail pass: roughen coastlines, speckle islands.
-- The `g` god-site cell and a keep-out box around the cape are protected.
------------------------------------------------------------------------------
function DetailCoastline(plotTypes)
    local prototype = {};
    for i = 0, (g_iW * g_iH) - 1 do prototype[i] = plotTypes[i]; end

    local function IsLandPlot(x, y)
        if x < 0 or x >= g_iW or y < 0 or y >= g_iH then return false; end
        return prototype[y * g_iW + x] ~= g_PLOT_TYPE_OCEAN;
    end

    local function AdjacentOcean(x, y)
        for d = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
            local p = Map.GetAdjacentPlot(x, y, d);
            if p ~= nil and p:IsWater() then return true; end
        end
        return false;
    end

    local function AdjacentLand(x, y)
        for d = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
            local p = Map.GetAdjacentPlot(x, y, d);
            if p ~= nil and not p:IsWater() then return true; end
        end
        return false;
    end

    -- protect the god-site cell and the cape keep-out box
    local function InCapBox(x, y)
        return InCapeKeepOut(x, y);
    end

    for y = 0, g_iH - 1 do
        for x = 0, g_iW - 1 do
            if not InCapBox(x, y) then
                local i = y * g_iW + x;
                if prototype[i] == g_PLOT_TYPE_LAND and AdjacentOcean(x, y) then
                    -- ~25% of coastal land gets washed away (rough coastline)
                    if TerrainBuilder.GetRandomNumber(4, "VH coast wash") == 0 then
                        plotTypes[i] = g_PLOT_TYPE_OCEAN;
                    end
                elseif prototype[i] == g_PLOT_TYPE_OCEAN and AdjacentLand(x, y) then
                    -- ~12% of near-shore water becomes a speckle islet
                    if TerrainBuilder.GetRandomNumber(8, "VH islet speck") == 0 then
                        plotTypes[i] = g_PLOT_TYPE_LAND;
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- Detail pass A: carve fjord inlets into the western ridge (Norway).
-- For each `f` anchor cell we carve 2 tiles deep from the west ocean flank.
------------------------------------------------------------------------------
function CarveFjords(plotTypes)
    local function IsSea(x, y)
        if x < 0 or x >= g_iW or y < 0 or y >= g_iH then return true; end
        return plotTypes[y * g_iW + x] == g_PLOT_TYPE_OCEAN;
    end

    -- anchor cells: column 2 at selected rows (west-facing ridge flank)
    local anchors = { 6, 8, 10, 13, 16, 18, 20 };
    for _, r in ipairs(anchors) do
        local c = 2;
        local y0 = YLOC(r);
        -- carve west->east for 2 tiles at each anchor band
        for dy = 0, 1 do
            local y = y0 + dy;
            for dx = 0, 1 do
                local x = XLOC(c) + dx;
                if IsSea(x - 1, y) and not InCapeKeepOut(x, y) then
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_OCEAN;
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- Detail pass B: hand-paint interior lakes (Mälaren / Vättern analogues)
-- and east-Baltic archipelago speckles. Lakes are enclosed ocean -> coast.
------------------------------------------------------------------------------
function PaintLakesAndArchipelago(plotTypes)
    local function PaintEllipse(cx, cy, rx, ry, plotType)
        for y = math.max(0, cy - ry), math.min(g_iH - 1, cy + ry) do
            for x = math.max(0, cx - rx), math.min(g_iW - 1, cx + rx) do
                local dx = (x - cx) / rx;
                local dy = (y - cy) / ry;
                if dx * dx + dy * dy <= 1.0 then
                    plotTypes[y * g_iW + x] = plotType;
                end
            end
        end
    end

    -- Mälaren (central Sweden)
    PaintEllipse(73, 23, 4, 2, g_PLOT_TYPE_OCEAN);
    PaintEllipse(74, 22, 2, 1, g_PLOT_TYPE_OCEAN);
    -- Vättern (southern Sweden)
    PaintEllipse(68, 28, 1, 3, g_PLOT_TYPE_OCEAN);
    -- small meltwater ponds in Finnmark
    PaintEllipse(72, 9, 2, 1, g_PLOT_TYPE_OCEAN);
    PaintEllipse(78, 12, 1, 2, g_PLOT_TYPE_OCEAN);

    -- east-Baltic archipelago (Stockholm skärgård): deterministic specks
    local specks = { {78,26},{80,28},{77,31},{81,33},{79,35},{82,37},{76,24},{80,40} };
    for _, s in ipairs(specks) do
        if s[1] < g_iW and s[2] < g_iH then
            plotTypes[s[2] * g_iW + s[1]] = g_PLOT_TYPE_LAND;
        end
    end
end

------------------------------------------------------------------------------
-- Detail pass C: build the Skåne cape + god-site (protect from coastline
-- jitter). The cape extends SW from the Swedish mainland toward the strait.
------------------------------------------------------------------------------
local CAP_X, CAP_Y = 57, 39;   -- capital tile (god-site anchor cell center)

function BuildCape(plotTypes)
    -- cape shape (roughly): land x56..63 y36..42, tapering toward tip (56,41)
    local function SetLand(x, y)
        if x >= 0 and x < g_iW and y >= 0 and y < g_iH then
            plotTypes[y * g_iW + x] = g_PLOT_TYPE_LAND;
        end
    end
    for y = 36, 42 do
        local x0, x1;
        if y == 36 then x0, x1 = 56, 63;
        elseif y == 37 then x0, x1 = 56, 63;
        elseif y == 38 then x0, x1 = 56, 62;
        elseif y == 39 then x0, x1 = 56, 62;
        elseif y == 40 then x0, x1 = 57, 61;
        elseif y == 41 then x0, x1 = 57, 60;
        else x0, x1 = 57, 59; end
        for x = x0, x1 do SetLand(x, y); end
    end
    -- connect cape to mainland (bridge at y35 / y36 NE)
    for x = 61, 66 do SetLand(x, 36); end
end

------------------------------------------------------------------------------
-- Detail pass D: mountains & hills (after water shaping so coast adjacency
-- is final). Includes the god-site Campus/HS mountain ridge.
------------------------------------------------------------------------------
function PlaceMountainsAndHills(plotTypes)
    local T = TerrainBuilder;
    -- Norway ridge skeleton (from `m` cells): widen jitter, keep spine solid
    for y = 8, 43 do
        local x = 20;
        if plotTypes[y * g_iW + x] ~= g_PLOT_TYPE_OCEAN then
            if T.GetRandomNumber(3, "VH mtn jitter") == 0 then
                plotTypes[y * g_iW + x] = g_PLOT_TYPE_HILLS;
            else
                plotTypes[y * g_iW + x] = g_PLOT_TYPE_MOUNTAIN;
            end
        end
    end
    -- Sweden west-coast fjord cliffs (Campus/HS neighbours, expressed in
    -- delta space relative to the capital at (CAP_X, CAP_Y)):
    local function SetPlotByDelta(dx, dy, pt)
        local p = Map.GetPlotXY(CAP_X, CAP_Y, dx, dy, 8);
        if p ~= nil then
            local px, py = p:GetX(), p:GetY();
            plotTypes[py * g_iW + px] = pt;
        end
    end
    SetPlotByDelta(2, -1, g_PLOT_TYPE_MOUNTAIN);  -- Campus N
    SetPlotByDelta(2, -2, g_PLOT_TYPE_MOUNTAIN);  -- Campus NE
    SetPlotByDelta(2,  1, g_PLOT_TYPE_MOUNTAIN);  -- HS
    -- decorative capes ridges near the cape
    SetPlotByDelta(3,  0, g_PLOT_TYPE_MOUNTAIN);
    -- elevated river source (NE of the god-site) so PaintGodSiteRiver works
    SetPlotByDelta(3, -1, g_PLOT_TYPE_HILLS);

    -- South-continent central range (rival hemisphere)
    for y = 46, 50 do
        for x = 38, 44 do
            if plotTypes[y * g_iW + x] ~= g_PLOT_TYPE_OCEAN then
                if T.GetRandomNumber(3, "VH south mtn") == 0 then
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_MOUNTAIN;
                else
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_HILLS;
                end
            end
        end
    end
    -- Islandia volcanic cluster
    for y = 14, 20 do
        for x = 1, 5 do
            if plotTypes[y * g_iW + x] ~= g_PLOT_TYPE_OCEAN then
                if T.GetRandomNumber(3, "VH islandia") == 0 then
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_MOUNTAIN;
                end
            end
        end
    end
    -- generic hills scatter on all remaining land (avoid cape keep-out)
    for i = 0, (g_iW * g_iH) - 1 do
        if plotTypes[i] == g_PLOT_TYPE_LAND then
            local px = i % g_iW;
            local py = (i - px) / g_iW;
            if not InCapeKeepOut(px, py) then
                if T.GetRandomNumber(8, "VH hills") == 0 then
                    plotTypes[i] = g_PLOT_TYPE_HILLS;
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- Terrain overrides: after GenerateTerrainTypes + ApplyTerrain, repaint land
-- by region so the fantasy climate matches the plan (tundra Finnmark,
-- temperate home, cold rivals). Mountains keep their latitude terrain.
------------------------------------------------------------------------------
local TERRAIN_GRASS  = g_TERRAIN_TYPE_GRASS;
local TERRAIN_PLAINS = g_TERRAIN_TYPE_PLAINS;
local TERRAIN_TUNDRA = g_TERRAIN_TYPE_TUNDRA;
local TERRAIN_SNOW   = g_TERRAIN_TYPE_SNOW;

function IsFinnmark(x, y)      return x >= 60 and y <= 15 and y >= 4; end
function IsIslandia(x, y)      return x <= 10 and y >= 12 and y <= 34; end
function IsNorway(x, y)        return x >= 12 and x <= 23 and y >= 8 and y <= 45; end
function IsSweden(x, y)        return x >= 55 and y >= 14 and y <= 47; end
function IsDenmark(x, y)       return x >= 14 and x <= 54 and y >= 37 and y <= 44; end
function IsSouthContinent(x, y) return x >= 4 and x <= 72 and y >= 45 and y <= 53; end

function OverrideTerrain(plotTypes, terrainTypes)
    local T = TerrainBuilder;
    for i = 0, (g_iW * g_iH) - 1 do
        if plotTypes[i] ~= g_PLOT_TYPE_OCEAN and plotTypes[i] ~= g_PLOT_TYPE_MOUNTAIN then
            local px = i % g_iW;
            local py = (i - px) / g_iW;
            local base = TERRAIN_GRASS;   -- default temperate band

            if IsFinnmark(px, py) then
                base = (py <= 6) and TERRAIN_SNOW or TERRAIN_TUNDRA;
            elseif IsIslandia(px, py) then
                base = TERRAIN_TUNDRA;
            elseif IsNorway(px, py) then
                if py < 26 then base = TERRAIN_TUNDRA;
                elseif py < 34 then base = TERRAIN_GRASS;
                else base = TERRAIN_PLAINS; end
            elseif IsSweden(px, py) then
                if InCapeKeepOut(px, py) then
                    -- cape + god-site: warm flat PLAINS (home Giant's
                    -- Causeway needs non-hill coastal land)
                    base = TERRAIN_PLAINS;
                elseif py < 20 then base = TERRAIN_PLAINS;
                elseif py > 38 then
                    base = TERRAIN_GRASS;
                    if T.GetRandomNumber(4, "VH sw plain") == 0 then base = TERRAIN_PLAINS; end
                else
                    base = TERRAIN_GRASS;
                    if T.GetRandomNumber(5, "VH sw plains2") == 0 then base = TERRAIN_PLAINS; end
                end
            elseif IsDenmark(px, py) then
                base = TERRAIN_GRASS;
            elseif IsSouthContinent(px, py) then
                if py > 50 then base = TERRAIN_TUNDRA;
                elseif py < 48 then base = TERRAIN_GRASS;
                else base = TERRAIN_PLAINS; end
            end

            if plotTypes[i] == g_PLOT_TYPE_HILLS then
                base = base + 1;   -- *_HILLS variant (delta is 1)
            end
            terrainTypes[i] = base;
        end
    end
    -- re-apply anything that changed
    for i = 0, (g_iW * g_iH) - 1 do
        local pPlot = Map.GetPlotByIndex(i);
        TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
    end
end

------------------------------------------------------------------------------
-- Hand-paint a river through the god-site: source on the NE hills, flows
-- toward the strait south-west, passing the capital and CH tiles.
------------------------------------------------------------------------------
function PaintGodSiteRiver()
    local sourcePlot = Map.GetPlotXY(CAP_X, CAP_Y, 3, -1, 8);   -- NE hills
    if sourcePlot ~= nil and not sourcePlot:IsWater() then
        local p = TerrainBuilder.GetInlandCorner(sourcePlot);
        if p ~= nil then
            DoRiver(p, FlowDirectionTypes.FLOWDIRECTION_SOUTH);
        end
    end
    -- secondary short river SE of the cape for the CH backup
    local alt = Map.GetPlotXY(CAP_X, CAP_Y, 1, 1, 4);
    if alt ~= nil and not alt:IsWater() then
        local p2 = TerrainBuilder.GetInlandCorner(alt);
        if p2 ~= nil then
            DoRiver(p2, FlowDirectionTypes.FLOWDIRECTION_SOUTH);
        end
    end
end

------------------------------------------------------------------------------
-- Hand-place natural wonders: exactly 1 subtle wonder near the capital, plus
-- 1 on Islandia and 1 on the South continent for scouting achievements.
-- Giant's Causeway (2 tiles) and Eyja (2 tiles) are multi-tile custom-
-- placement wonders: they go through the VH_ multi-tile path (vanilla port).
------------------------------------------------------------------------------
function GetFeatureIndex(featureType)
    local f = GameInfo.Features[featureType];
    if f ~= nil then return f.Index; end
    return -1;
end

function PlaceWonderWanted(featureIndex, cX, cY, radius)
    -- scan around (cX,cY) for the first tile that passes the engine validity
    -- rules; places the wonder there. Returns the plot or nil.
    for range = 0, radius do
        for dx = -range, range do
            for dy = -range, range do
                local p = Map.GetPlotXY(cX, cY, dx, dy, radius + 2);
                if p ~= nil then
                    if TerrainBuilder.CanHaveFeature(p, featureIndex, false) then
                        TerrainBuilder.SetFeatureType(p, featureIndex);
                        return p;
                    end
                end
            end
        end
    end
    return nil;
end

--------------------------------------------------------------------------------
-- Multi-tile natural-wonder support (ported from the vanilla
-- NaturalWonderGenerator CustomGetMultiTileFeaturePlotList / CustomSetFeature
-- Type / SetNaturalCliff / ResetTerrain). Giant's Causeway (2 tiles,
-- GIANTS_CAUSEWAY) and Eyja (2 tiles, YOSEMITE) need this path; Crater Lake
-- is single-tile.
--------------------------------------------------------------------------------
local function VH_ResetTerrain(iPlot)
    local pPlot = Map.GetPlotByIndex(iPlot);
    local iTerrain = pPlot:GetTerrainType();
    if iTerrain == g_TERRAIN_TYPE_SNOW_HILLS or iTerrain == g_TERRAIN_TYPE_SNOW_MOUNTAIN then
        TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_SNOW);
    elseif iTerrain == g_TERRAIN_TYPE_DESERT_HILLS or iTerrain == g_TERRAIN_TYPE_DESERT_MOUNTAIN then
        TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);
    elseif iTerrain == g_TERRAIN_TYPE_PLAINS_HILLS or iTerrain == g_TERRAIN_TYPE_PLAINS_MOUNTAIN then
        TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_PLAINS);
    elseif iTerrain == g_TERRAIN_TYPE_GRASS_HILLS or iTerrain == g_TERRAIN_TYPE_GRASS_MOUNTAIN then
        TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_GRASS);
    elseif iTerrain == g_TERRAIN_TYPE_TUNDRA_HILLS or iTerrain == g_TERRAIN_TYPE_TUNDRA_MOUNTAIN then
        TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_TUNDRA);
    end
end

local function VH_SetNaturalCliff(iPlot)
    local pPlot = Map.GetPlotByIndex(iPlot);
    local iX, iY = pPlot:GetX(), pPlot:GetY();
    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
        local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
        if adjacentPlot ~= nil and adjacentPlot:IsWater() then
            if direction == DirectionTypes.DIRECTION_NORTHEAST then
                TerrainBuilder.SetNEOfCliff(adjacentPlot, true);
            elseif direction == DirectionTypes.DIRECTION_EAST then
                TerrainBuilder.SetWOfCliff(pPlot, true);
            elseif direction == DirectionTypes.DIRECTION_SOUTHEAST then
                TerrainBuilder.SetNWOfCliff(pPlot, true);
            elseif direction == DirectionTypes.DIRECTION_SOUTHWEST then
                TerrainBuilder.SetNEOfCliff(pPlot, true);
            elseif direction == DirectionTypes.DIRECTION_WEST then
                TerrainBuilder.SetWOfCliff(adjacentPlot, true);
            elseif direction == DirectionTypes.DIRECTION_NORTHWEST then
                TerrainBuilder.SetNWOfCliff(adjacentPlot, true);
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Mirror of vanilla CustomGetMultiTileFeaturePlotList: returns true and fills
-- aPlots (plot indices) when the tile satisfies the wonder's custom geometry.
-- Branches kept (verbatim): YOSEMITE/TORRES (2 E-W inland), CLIFFS_DOVER
-- (2 coast), GIANTS_CAUSEWAY (2 land+water), PIOPIOTAHI (3 coastal triangle).
-- Nil-guards added to the PIOPIOTAHI water checks.
--------------------------------------------------------------------------------
local function VH_CanMultiTile(pPlot, eFeatureType, aPlots)
    -- First check this plot itself
    if not TerrainBuilder.CanHaveFeature(pPlot, eFeatureType, true) then
        return false;
    else
        table.insert(aPlots, pPlot:GetIndex());
    end

    local customPlacement = GameInfo.Features[eFeatureType].CustomPlacement;

    -- 2 tiles inland, east-west facing camera (first tile is the western one)
    if customPlacement == "PLACEMENT_TORRES_DEL_PAINE" or
       customPlacement == "PLACEMENT_YOSEMITE" then
        local pAdjacentPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
        if pAdjacentPlot ~= nil and TerrainBuilder.CanHaveFeature(pAdjacentPlot, eFeatureType, true) then
            table.insert(aPlots, pAdjacentPlot:GetIndex());
            return true;
        end

    -- 2 tiles on coast, roughly facing camera
    elseif customPlacement == "PLACEMENT_CLIFFS_DOVER" then
        local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
        local pWPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);
        local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
        local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
        local pEPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
        local pSecondPlot;
        if pWPlot ~= nil and pSWPlot ~= nil and pWPlot:IsWater() and not pWPlot:IsLake() and pSWPlot:IsWater() and not pSWPlot:IsLake() then
            pSecondPlot = pSEPlot;
        elseif pSWPlot ~= nil and pSEPlot ~= nil and pSWPlot:IsWater() and not pSWPlot:IsLake() and pSEPlot:IsWater() and not pSEPlot:IsLake() then
            pSecondPlot = pEPlot;
        elseif pSWPlot ~= nil and pEPlot ~= nil and pSEPlot:IsWater() and not pSEPlot:IsLake() and pEPlot:IsWater() and not pEPlot:IsLake() then
            pSecondPlot = pNEPlot;
        else
            return false;
        end
        if pSecondPlot ~= nil and TerrainBuilder.CanHaveFeature(pSecondPlot, eFeatureType, true) then
            table.insert(aPlots, pSecondPlot:GetIndex());
            return true;
        end

    -- 2 tiles, one on coastal land and one in water
    elseif customPlacement == "PLACEMENT_GIANTS_CAUSEWAY" then
        if pPlot:IsWater() or pPlot:IsHills() then
            return false;
        end
        local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
        if pSWPlot ~= nil and pSWPlot:IsWater() and not pSWPlot:IsLake() then
            table.insert(aPlots, pSWPlot:GetIndex());
            return true;
        end
        local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
        if pSEPlot ~= nil and pSEPlot:IsWater() and not pSEPlot:IsLake() then
            table.insert(aPlots, pSEPlot:GetIndex());
            return true;
        end
        local pWPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);
        if pWPlot ~= nil and pWPlot:IsWater() and not pWPlot:IsLake() then
            table.insert(aPlots, pWPlot:GetIndex());
            return true;
        end
        local pEPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
        if pEPlot ~= nil and pEPlot:IsWater() and not pEPlot:IsLake() then
            table.insert(aPlots, pEPlot:GetIndex());
            return true;
        end
        local pNWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
        if pNWPlot ~= nil and pNWPlot:IsWater() and not pNWPlot:IsLake() then
            table.insert(aPlots, pNWPlot:GetIndex());
            return true;
        end
        local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
        if pNEPlot ~= nil and pNEPlot:IsWater() and not pNEPlot:IsLake() then
            table.insert(aPlots, pNEPlot:GetIndex());
            return true;
        end

    -- 3 tiles in triangle coast on front edge, land behind (with any rotation)
    elseif customPlacement == "PLACEMENT_PIOPIOTAHI" then
        local pWPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);
        local pNWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
        local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
        local pEPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
        local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
        local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);

        -- all 6 hexes around must be land (nil-checks verbatim)
        if (pNWPlot == nil or pNEPlot == nil or pWPlot == nil or pSWPlot == nil or pSEPlot == nil or pEPlot == nil or
            (pNWPlot:IsWater() or pNEPlot:IsWater() or pWPlot:IsWater() or pSWPlot:IsWater() or pSEPlot:IsWater() or pEPlot:IsWater())) then
            return false;
        else
            local bWValid  = TerrainBuilder.CanHaveFeature(pWPlot, eFeatureType, true);
            local bNWValid = TerrainBuilder.CanHaveFeature(pNWPlot, eFeatureType, true);
            local bNEValid = TerrainBuilder.CanHaveFeature(pNEPlot, eFeatureType, true);
            local bEValid  = TerrainBuilder.CanHaveFeature(pEPlot, eFeatureType, true);
            local bSEValid = TerrainBuilder.CanHaveFeature(pSEPlot, eFeatureType, true);
            local bSWValid = TerrainBuilder.CanHaveFeature(pSWPlot, eFeatureType, true);

            if bSEValid == true and bSWValid == true then
                local p1 = Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
                local p2 = Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
                local p3 = Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
                if p1 ~= nil and p2 ~= nil and p3 ~= nil and p1:IsWater() and p2:IsWater() and p3:IsWater() then
                    table.insert(aPlots, pSEPlot:GetIndex());
                    table.insert(aPlots, pSWPlot:GetIndex());
                    return true;
                end
            end

            if bEValid == true and bSEValid == true then
                local p1 = Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_EAST);
                local p2 = Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_EAST);
                local p3 = Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
                if p1 ~= nil and p2 ~= nil and p3 ~= nil and p1:IsWater() and p2:IsWater() and p3:IsWater() then
                    table.insert(aPlots, pEPlot:GetIndex());
                    table.insert(aPlots, pSEPlot:GetIndex());
                    return true;
                end
            end

            if bSWValid == true and bWValid == true then
                local p1 = Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
                local p2 = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
                local p3 = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_WEST);
                if p1 ~= nil and p2 ~= nil and p3 ~= nil and p1:IsWater() and p2:IsWater() and p3:IsWater() then
                    table.insert(aPlots, pSWPlot:GetIndex());
                    table.insert(aPlots, pWPlot:GetIndex());
                    return true;
                end
            end

            if bWValid == true and bNWValid == true then
                local p1 = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_WEST);
                local p2 = Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_WEST);
                local p3 = Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
                if p1 ~= nil and p2 ~= nil and p3 ~= nil and p1:IsWater() and p2:IsWater() and p3:IsWater() then
                    table.insert(aPlots, pWPlot:GetIndex());
                    table.insert(aPlots, pNWPlot:GetIndex());
                    return true;
                end
            end

            if bNEValid == true and bEValid == true then
                local p1 = Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
                local p2 = Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
                local p3 = Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_EAST);
                if p1 ~= nil and p2 ~= nil and p3 ~= nil and p1:IsWater() and p2:IsWater() and p3:IsWater() then
                    table.insert(aPlots, pNEPlot:GetIndex());
                    table.insert(aPlots, pEPlot:GetIndex());
                    return true;
                end
            end

            if bNWValid == true and bNEValid == true then
                local p1 = Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
                local p2 = Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
                local p3 = Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
                if p1 ~= nil and p2 ~= nil and p3 ~= nil and p1:IsWater() and p2:IsWater() and p3:IsWater() then
                    table.insert(aPlots, pNWPlot:GetIndex());
                    table.insert(aPlots, pNEPlot:GetIndex());
                    return true;
                end
            end
        end
    end

    return false;
end

--------------------------------------------------------------------------------
-- Scan around (cX,cY) for the first tile that satisfies the wonder's custom
-- multi-tile geometry; places the full multi-tile feature via
-- SetMultiPlotFeatureType. Returns the anchor plot or nil.
--------------------------------------------------------------------------------
local function VH_PlaceMultiTileWonder(featureIndex, cX, cY, radius)
    for range = 0, radius do
        for dx = -range, range do
            for dy = -range, range do
                local p = Map.GetPlotXY(cX, cY, dx, dy, radius + 2);
                if p ~= nil then
                    local aPlots = {};
                    if VH_CanMultiTile(p, featureIndex, aPlots) then
                        TerrainBuilder.SetMultiPlotFeatureType(aPlots, featureIndex);
                        for k = 1, #aPlots do
                            VH_SetNaturalCliff(aPlots[k]);
                            VH_ResetTerrain(aPlots[k]);
                        end
                        return p;
                    end
                end
            end
        end
    end
    return nil;
end

function PlaceNaturalWonders()
    local causeway = GetFeatureIndex("FEATURE_GIANTS_CAUSEWAY");
    local eyja     = GetFeatureIndex("FEATURE_EYJAFJALLAJOKULL");
    local crater   = GetFeatureIndex("FEATURE_CRATER_LAKE");

    -- 1) subtle: Giant's Causeway NW of the capital on the sound-side cape.
    --    PLACEMENT_GIANTS_CAUSEWAY: 1 flat coastal land tile + 1 adjacent
    --    open-water tile (the sound); the multi-tile scan lands it a tile or
    --    two off the designed (CAP_X-2, CAP_Y-2) anchor where it fits.
    local home = VH_PlaceMultiTileWonder(causeway, CAP_X - 2, CAP_Y - 2, 3);
    if home ~= nil then
        print("Vinterhav: home wonder at (" .. tostring(home:GetX()) .. "," .. tostring(home:GetY()) .. ")");
    else
        print("Vinterhav: WARNING — home wonder tile invalid, skipped");
    end
    -- 2) Islandia volcanic wonder (2-tile east-west, PLACEMENT_YOSEMITE; the
    --    Islandia tundra satisfies Eyja's SNOW/TUNDRA terrain adjacency).
    local volcano = VH_PlaceMultiTileWonder(eyja, 3, 18, 3);
    if volcano ~= nil then
        print("Vinterhav: Eyja at (" .. tostring(volcano:GetX()) .. "," .. tostring(volcano:GetY()) .. ")");
    else
        print("Vinterhav: WARNING — Eyja tile invalid, skipped");
    end
    -- 3) South-continent crater (single-tile; unchanged path)
    local craterPlot = PlaceWonderWanted(crater, 30, 48, 3);
    if craterPlot ~= nil then
        print("Vinterhav: Crater at (" .. tostring(craterPlot:GetX()) .. "," .. tostring(craterPlot:GetY()) .. ")");
    else
        print("Vinterhav: WARNING — Crater tile invalid, skipped");
    end
end

------------------------------------------------------------------------------
-- AddGoodies wrapper handled by bundle.lua; called at the end of GenerateMap.
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- GetHumanPlayerIndex: find the human slot at map-gen time. In single-player
-- the human is slot 0; scan anyway for robustness.
------------------------------------------------------------------------------
function GetHumanPlayerIndex()
    for slot = 0, 15 do
        local cfg = PlayerConfigurations[slot];
        if cfg ~= nil then
            local status = cfg:GetSlotStatus();
            if status == SlotStatus.SS_HUMAN then
                return slot;
            end
        end
    end
    print("Vinterhav: WARNING — no SS_HUMAN slot found; assuming player 0");
    return 0;
end

------------------------------------------------------------------------------
-- EnforceHumanStartIsolation: after the human start is forced onto the engraved
-- cape, relocate any AI major that ended up within MIN_HUMAN_AI_START_DIST
-- tiles of the capital. AssignStartingPlots buffers civ spacing against the
-- human's ORIGINAL plot (wherever the generator put it first), NOT against the
-- final cape anchor — so a pip-spawned AI can land on the homeland doorstep.
-- The relocated AI goes to the farthest valid land plot (the sparse AI
-- hemisphere), kept >= SPARSE_AI_MIN_SEP tiles from every other major start.
------------------------------------------------------------------------------
local MIN_HUMAN_AI_START_DIST = 22;   -- vanilla major-vs-major start buffer
local SPARSE_AI_MIN_SEP       = 8;    -- min spacing from other AI starts

function EnforceHumanStartIsolation(capPlot)
    local gW, gH     = Map.GetGridSize();
    local capIndex   = capPlot:GetIndex();
    local humanIndex = GetHumanPlayerIndex();
    local majors     = PlayerManager.GetAliveMajorIDs();

    for _, aiIndex in ipairs(majors) do
        if aiIndex ~= humanIndex then
            local aiPlayer  = Players[aiIndex];
            local startPlot = aiPlayer:GetStartingPlot();
            if startPlot ~= nil and
               Map.GetPlotDistance(capIndex, startPlot:GetIndex()) < MIN_HUMAN_AI_START_DIST then

                -- Single pass: track the best valid candidate (>= MIN dist from
                -- the human, >= SPARSE_AI_MIN_SEP from other AI starts) and an
                -- unconditional farthest-land fallback.
                local target, targetDist = nil, 0;
                local fallback, fbDist    = nil, 0;
                for x = 0, gW - 1 do
                    for y = 0, gH - 1 do
                        local plot = Map.GetPlot(x, y);
                        if plot ~= nil and not plot:IsWater() and not plot:IsImpassable() then
                            local pd = Map.GetPlotDistance(capIndex, plot:GetIndex());
                            if pd > fbDist then
                                fallback, fbDist = plot, pd;
                            end
                            if pd >= MIN_HUMAN_AI_START_DIST and pd > targetDist then
                                local ok = true;
                                for _, other in ipairs(majors) do
                                    if other ~= humanIndex and other ~= aiIndex then
                                        local osp = Players[other]:GetStartingPlot();
                                        if osp ~= nil and
                                           Map.GetPlotDistance(osp:GetIndex(), plot:GetIndex()) < SPARSE_AI_MIN_SEP then
                                            ok = false;
                                            break;
                                        end
                                    end
                                end
                                if ok then
                                    target, targetDist = plot, pd;
                                end
                            end
                        end
                    end
                end

                local finalTarget = target or fallback;
                if finalTarget ~= nil then
                    aiPlayer:SetStartingPlot(finalTarget);
                    print("Vinterhav: relayed AI " .. aiIndex .. " start (" ..
                          startPlot:GetX() .. "," .. startPlot:GetY() .. ") -> (" ..
                          finalTarget:GetX() .. "," .. finalTarget:GetY() .. ")");
                else
                    print("Vinterhav: WARNING — no relay target found for AI " .. aiIndex);
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- District template (delta space, radius <= 1 of the capital):
--    cap  (0,0)      IZ (1,0)     Campus (1,-1)   HS (1,1)
--    CH   (0,-1)     Harbor (0,1) Theater (-1,-1) GovPlaza (-1,0)
--    spare (2,0)
------------------------------------------------------------------------------
local DISTRICT_DELTAS = {
    {  0,  0 },   -- capital
    {  1,  0 },   -- IZ
    {  1, -1 },   -- Campus
    {  1,  1 },   -- Holy Site
    {  0, -1 },   -- Commercial Hub
    {  0,  1 },   -- Harbor
    { -1, -1 },   -- Theater Square
    { -1,  0 },   -- Government Plaza
    {  2,  0 },   -- spare (kept empty)
};

local function IsDistrictDelta(dx, dy)
    for _, d in ipairs(DISTRICT_DELTAS) do
        if d[1] == dx and d[2] == dy then return true; end
    end
    return false;
end

------------------------------------------------------------------------------
-- Hex-distance in delta space: d = (|dx|+|dy|+|dx+dy|) / 2
------------------------------------------------------------------------------
local function HexDist(dx, dy)
    return (math.abs(dx) + math.abs(dy) + math.abs(dx + dy)) / 2;
end

------------------------------------------------------------------------------
-- Engrave the OP resource battery around the capital (3-ring), skipping the
-- district template + capital + wonder tiles. Uses engine validation guards.
------------------------------------------------------------------------------
function EngraveGodSite(capPlot)
    local capX, capY = capPlot:GetX(), capPlot:GetY();
    local R = ResourceBuilder;
    local T = TerrainBuilder;

    local function Res(resourceType)
        local row = GameInfo.Resources[resourceType];
        if row == nil then return -1; end
        return row.Hash;
    end

    local RES_IRON    = Res("RESOURCE_IRON");
    local RES_HORSES  = Res("RESOURCE_HORSES");
    local RES_NITER   = Res("RESOURCE_NITER");
    local RES_COAL    = Res("RESOURCE_COAL");
    local RES_OIL     = Res("RESOURCE_OIL");
    local RES_WINE    = Res("RESOURCE_WINE");
    local RES_TRUFFLES= Res("RESOURCE_TRUFFLES");
    local RES_CRABS   = Res("RESOURCE_CRABS");
    local RES_WHEAT   = Res("RESOURCE_WHEAT");
    local RES_DEER    = Res("RESOURCE_DEER");
    local RES_STONE   = Res("RESOURCE_STONE");
    local RES_FISH    = Res("RESOURCE_FISH");
    local RES_RICE    = Res("RESOURCE_RICE");

    local function TryPlace(dx, dy, eRes)
        if eRes == -1 then return false; end
        local p = Map.GetPlotXY(capX, capY, dx, dy, 4);
        if p == nil then return false; end
        if p:IsWater() or p:IsMountain() or p:IsNaturalWonder() then return false; end
        if p:GetResourceCount() > 0 then return false; end
        if IsDistrictDelta(dx, dy) then return false; end
        if R.CanHaveResource(p, eRes) then
            R.SetResourceType(p, eRes, 1);
            return true;
        end
        return false;
    end

    local function TryPlaceSea(dx, dy, eRes)
        if eRes == -1 then return false; end
        local p = Map.GetPlotXY(capX, capY, dx, dy, 4);
        if p == nil then return false; end
        if not p:IsWater() then return false; end
        if p:GetResourceCount() > 0 then return false; end
        if R.CanHaveResource(p, eRes) then
            R.SetResourceType(p, eRes, 1);
            return true;
        end
        return false;
    end

    -- === LUXURIES (amenity headroom + sellable): 4-5 copies, 2-3 types ===
    TryPlace( 0, -2, RES_WINE);              -- river-bank wine
    TryPlace(-1, -3, RES_WINE);
    TryPlace(-2,  2, RES_TRUFFLES);          -- woods truffles
    TryPlace( 3,  0, RES_TRUFFLES);
    TryPlaceSea( 2,  1, RES_CRABS);          -- coastal crabs
    TryPlaceSea(-1,  2, RES_CRABS);

    -- === STRATEGICS (progressive curve) ===
    TryPlace(-2,  0, RES_IRON);              -- hills ring 2
    TryPlace(-3,  1, RES_IRON);
    TryPlace(-2,  2, RES_HORSES);
    TryPlace( 2,  1, RES_HORSES);            -- IZ-adjacent plains
    TryPlace( 3, -1, RES_NITER);             -- ring 2-3
    TryPlace( 0, -4, RES_NITER);
    TryPlace( 2,  2, RES_COAL);
    TryPlace( 3,  3, RES_COAL);
    TryPlace(-3,  3, RES_OIL);
    TryPlace( 3,  2, RES_OIL);

    -- === BONUS (food + chops; stones feed IZ quarries) ===
    TryPlace( 2,  0, RES_STONE);             -- IZ flank
    TryPlace( 0, -3, RES_STONE);
    TryPlace(-3, -2, RES_STONE);
    TryPlace(-1, -2, RES_WHEAT);             -- river wheat
    TryPlace( 1, -3, RES_WHEAT);
    TryPlace( 1,  3, RES_DEER);              -- north woods
    TryPlace(-3, -1, RES_DEER);
    TryPlace( 3,  -2, RES_RICE);

    -- === SEA BONUS for the Harbor (+2) ===
    TryPlaceSea(-1,  1, RES_FISH);
    TryPlaceSea( 0,  2, RES_FISH);

    print("Vinterhav: god-site engraved at (" .. tostring(capX) .. "," .. tostring(capY) .. ")");
end

------------------------------------------------------------------------------
-- GenerateMap: main pipeline. Mirrors continents.lua ordering with the
-- hand-painted blueprint substituting the fractal landmass pass.
------------------------------------------------------------------------------
function GenerateMap()
    print("Generating Vinterhav Map");

    -- Set globals
    g_iW, g_iH = Map.GetGridSize();
    g_iFlags = TerrainBuilder.GetFractalFlags();

    ---------------------------------------------------------------------------
    -- 1. Worldshape: blueprint -> plotTypes
    ---------------------------------------------------------------------------
    plotTypes = {};
    RasterizeBlueprint(plotTypes);
    DetailCoastline(plotTypes);
    CarveFjords(plotTypes);
    PaintLakesAndArchipelago(plotTypes);
    BuildCape(plotTypes);
    PlaceMountainsAndHills(plotTypes);

    ---------------------------------------------------------------------------
    -- 2. Terrain (hand climate band = Temperate), then a region repaint pass
    ---------------------------------------------------------------------------
    local temperature = 2;                     -- force Temperate
    terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature);
    ApplyTerrain(plotTypes, terrainTypes);
    OverrideTerrain(plotTypes, terrainTypes);

    AreaBuilder.Recalculate();

    ---------------------------------------------------------------------------
    -- 3. Rivers (+ hand god-site river), lakes, features, cliffs
    ---------------------------------------------------------------------------
    AddRivers();
    PaintGodSiteRiver();
    local numLargeLakes = 2;
    AddLakes(numLargeLakes);

    -- feature wrapper (continents-style): rainfall Normal
    local rainfall = 2;
    local featuregen = FeatureGenerator.Create({ rainfall = rainfall });
    featuregen:AddFeatures();

    AddCliffs(plotTypes, terrainTypes);

    ---------------------------------------------------------------------------
    -- 4. Natural wonders (hand-placed; exactly 1 subtle home wonder)
    ---------------------------------------------------------------------------
    PlaceNaturalWonders();

    AreaBuilder.Recalculate();
    TerrainBuilder.AnalyzeChokepoints();
    TerrainBuilder.StampContinents();

    ---------------------------------------------------------------------------
    -- 5. Map-wide resources: SPARSE for the AI hemispheres. Hand-engraving
    --    of the human battery happens after the start is forced (step 7).
    ---------------------------------------------------------------------------
    local resourcesConfig = 1;                 -- Sparse (force: ignore setup screen)
    local startConfig     = 2;                 -- Standard start resources for civs
    local resGen = ResourceGenerator.Create({ resources = resourcesConfig, START_CONFIG = startConfig });

    ---------------------------------------------------------------------------
    -- 6. Start plots for all civs (standard START_CONFIG with start bias off
    --    — the map is civ-agnostic by design).
    ---------------------------------------------------------------------------
    local args = {
        MIN_MAJOR_CIV_FERTILITY = 150,
        MIN_MINOR_CIV_FERTILITY = 50,
        MIN_BARBARIAN_FERTILITY = 1,
        START_MIN_Y = 15,
        START_MAX_Y = 15,
        START_CONFIG = startConfig,
        IGNORESTARTBIAS = true,
    };
    local start_plot_database = AssignStartingPlots.Create(args);

    ---------------------------------------------------------------------------
    -- 7. Force the human onto the engraved god-site (after AssignStartingPlots
    --    returns so the commit is not overwritten), then engrave the battery.
    ---------------------------------------------------------------------------
    local humanIndex = GetHumanPlayerIndex();
    local capPlot = Map.GetPlot(CAP_X, CAP_Y);
    if capPlot ~= nil and not capPlot:IsWater() then
        Players[humanIndex]:SetStartingPlot(capPlot);
        EngraveGodSite(capPlot);
        -- 7b. Push any AI that pip-spawned too close to the forced start into
        --     the sparse AI hemisphere (AssignStartingPlots spaced civs against
        --     the human's ORIGINAL plot, not the engraved cape).
        EnforceHumanStartIsolation(capPlot);
    else
        print("Vinterhav: WARNING — god-site plot invalid, human start unforced");
    end

    ---------------------------------------------------------------------------
    -- 8. Goody huts (bundle.lua), away from the human start.
    ---------------------------------------------------------------------------
    local GoodyGen = AddGoodies(g_iW, g_iH);

    print("Vinterhav Map complete");
end
