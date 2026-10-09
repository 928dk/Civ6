------------------------------------------------------------------------------
-- FILE:    MiddleEarth.lua
-- PURPOSE: Middle-earth — fixed 106x66 (Large-selected) no-wrap map script
--          (spec 143). Hand-shaped world with scripted faction starts, an OP
--          hand-engraved Gondor homeland for the human player, Mount Doom in
--          Mordor, Aman/Valinor as a separate western continent (Voyage of
--          the Mayflower), tuned for Steam achievement clearing (Ten
--          Commandments: "Win a regular game on a Large Map").
--
-- CONVENTION: plotTypes[]/terrainTypes[] are 0-indexed: index = y * g_iW + x.
--             Blueprint cells: each column = 2 x-tiles, each row = 2 y-tiles.
--
-- BLUEPRINT LEGEND (53 chars wide, 33 rows):
--   ~  ocean           .  shallow sea (supported, unused)
--   #  temperate land  T  tundra land      S  snow land
--   d  desert land     h  hills land       m  mountain
--
-- CIV -> FACTION MAPPING (forced starts; anchors are cell-precise):
--   Rome            -> Gondor   (52,43)  human / OP homeland
--   Scythia         -> Rohan    (59,32)  plains between Misty Mtns and Fangorn
--   France (Eleanor)-> Lóthlórien (56,23) Golden Wood
--   Germany         -> Erebor   (69,17)  Lonely Mountain (hills)
--   Cree            -> Shire    (35,21)  Hobbiton
--   Aztec           -> Mordor   (64,41)  Barad-dûr (Gorgoroth)
--   Arabia          -> Harad    (48,56)  South Harad desert coast
--   Mongolia        -> Rhûn     (84,23)  East-way steppe
-- Any unmapped human civ is forced onto Gondor (OP homeland always lands on
-- the human). Mount Doom (62,41) is engraved as a mountain inside the
-- Ered Lithui / Ephel Dúath ring.
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

-- XLOC = X-tile from blueprint column (2 tiles per column)
local function XLOC(c) return 2 * c; end
-- YLOC = Y-tile from blueprint row (2 tiles per row)
local function YLOC(r) return 2 * r; end

------------------------------------------------------------------------------
-- ASCII worldshape blueprint (north at top). Each entry must be exactly 53
-- chars. Validated generically by scripts/validate-mod.sh (legend derived
-- from the cellType table). Column bands:
--   c0-1 west ocean | c2-7 Aman | c8-13 Belegaer | c14-15 Ered Luin/coast
--   c16-22 Eriador/Shire-Gondor | c23-25 Misty-White Mtns/Gulf
--   c26-27 Anduin corridor | c28-30 Ithilien/Ephel Dúath/Rohan
--   c31-33 Mirkwood/Emyn Muil/Mordor | c34-36 Erebor/Núrnen/Khand
--   c37-40 Sea of Rhûn | c41-46 Rhûn east | c47-52 east ocean
------------------------------------------------------------------------------
local g_BLUEPRINT = {
    --  y0-3    polar ocean
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    --  y4-7    Forodwaith snow (north); the world ocean curls round
    "~~~~~~~~~~~~~~~~SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS~~~~~~",
    --  y6-9    Forodwaith tundra, Ered Mithrin spine c23-30
    "~~~~~~~~~~~~~~~~TTTTTTTTTTSSSSSSSSSSSTTTTTTTTTT~~~~~~",
    "~~~~~~~~~~~~~~~~TTTTTTTmmmmmmmmTTTTTTTTTTTTTTTT~~~~~~",
    "~~~~~~~~~~~~~~~~TTTTTTTmmmmmmmmTTTTTTTTTTTTTTTT~~~~~~",
    --  y12-15  Northern wastes; Misty Mountains begin c23-25
    "~~~~~~~~~~~~~~~~#######mmm#####################~~~~~~",
    --  y14-17  Erebor (c34 h, c35 m); Misty Mtns
    "~~~~~~~~~~~~~~~~#######mmm########hm###########~~~~~~",
    --  y16-19  Long Lake c32-33; Sea of Rhûn opens c37-40 r9-12
    "~~~~~~~~~~~~~~~~#######mmm######~~hm###########~~~~~~",
    "~~~~~~~~~~~~~~~~#######mmm######~~hm#~~~~######~~~~~~",
    --  y20-23  Shire (c17,r10); Lórien (c28,r11); Rhûn anchor (c42,r11)
    "~~~~~~~~~~~~~~~~#######mmm###########~~~~######~~~~~~",
    "~~##h#mm~~~~~~#########mmm###########~~~~######~~~~~~",
    "~~###hmm~~~~~~#########mmm###########~~~~######~~~~~~",
    --  y26-29  Aman; Misty tail dissolves; Sea of Rhûn ends r13
    "~~###hmm~~~~~~#########mmm#####################~~~~~~",
    "~~###hmm~~~~~~#########hhh#####################~~~~~~",
    "~~###hmm~~~~~~#################################~~~~~~",
    "~~###hmm~~~~~~#################################~~~~~~",
    "~~###hmm~~~~~~#################################~~~~~~",
    --  y36-37  Aman ends r17; Mordor approaches begin
    "~~~~~~~~~~~~~~#################################~~~~~~",
    --  y38-41  White Mtns c23-25; Ered Lithui c32-34; Ephel Dúath c29-30;
    --          Black Gate gap at c30-31
    "~~~~~~~~~~~~~~#########mmm###m##mmm############~~~~~~",
    "~~~~~~~~~~~~~~#########mmhh##mmh##m############~~~~~~",
    --  y42-45  GONDOR CAPITAL (52,43) at c26,r21; Núrnen c34-35; Ithilien
    "~~~~~~~~~~~~~~##########hh###mm###~~###########~~~~~~",
    "~~~~~~~~~~~~~~####################~~###########~~~~~~",
    --  y46-53  south Gondor / Lebennin; Khand; Rhûn far east
    "~~~~~~~~~~~~~~#################################~~~~~~",
    "~~~~~~~~~~~~~~#################################~~~~~~",
    --  y50-53  Gulf of Belfalas c23-26 (Anduin mouth)
    "~~~~~~~~~~~~~~#########~~~~####################~~~~~~",
    "~~~~~~~~~~~~~~#########~~~~####################~~~~~~",
    --  y54-59  Harad desert bands
    "~~~~~~~~~~~~~~~~ddddddddddddddd################~~~~~~",
    "~~~~~~~~~~~~~~~~ddddddddddddddd################~~~~~~",
    "~~~~~~~~~~~~~~~~ddddddddddddddd################~~~~~~",
    --  y60-65  southern polar ocean
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
};

g_BLUEPRINT_ROWS = #g_BLUEPRINT;         -- 33
g_BLUEPRINT_COLS = 53;                    -- 106 / 2

------------------------------------------------------------------------------
-- Keep-out box around the Gondor homeland + god-site so coastline/lake
-- passes never destroy the hand-built OP capital. Declared before every
-- pass that references it (Lua locals are only visible after declaration).
------------------------------------------------------------------------------
local function InGondorKeepOut(x, y)
    return x >= 48 and x <= 58 and y >= 38 and y <= 48;
end

------------------------------------------------------------------------------
-- Small debug helper (python-esque rjust for log alignment)
------------------------------------------------------------------------------
local function Pad(s, w)
    while #s < w do s = " " .. s; end
    return s;
end

------------------------------------------------------------------------------
-- GetMapInitData: fixed 106x66 grid, no wrap. The user selects "Large" in
-- the setup dropdown (that choice is what the achievement records); the
-- script always returns this fixed grid (Ten Commandments target).
------------------------------------------------------------------------------
function GetMapInitData(MapSize)
    return { Width = 106, Height = 66, WrapX = false };
end

------------------------------------------------------------------------------
-- GetMapScriptInfo: setup-screen metadata. Fixed grid, hardcoded climate,
-- so no advanced custom options are exposed.
------------------------------------------------------------------------------
function GetMapScriptInfo()
    return {
        Name = "LOC_MAP_MIDDLEEARTH_NAME",
        Description = "LOC_MAP_MIDDLEEARTH_DESCRIPTION",
        IconIndex = 0,
        SortIndex = 46,
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
        for x = XLOC(c), XLOC(c) + 1 do
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
        ["d"] = g_PLOT_TYPE_LAND,
        ["h"] = g_PLOT_TYPE_HILLS,
        ["m"] = g_PLOT_TYPE_MOUNTAIN,
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
-- The Gondor keep-out box is protected from the jitter.
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

    -- protect the Gondor homeland (god-site + district footprint)
    local function InCapBox(x, y)
        return InGondorKeepOut(x, y);
    end

    for y = 0, g_iH - 1 do
        for x = 0, g_iW - 1 do
            if not InCapBox(x, y) then
                local i = y * g_iW + x;
                if prototype[i] == g_PLOT_TYPE_LAND and AdjacentOcean(x, y) then
                    -- ~25% of coastal land gets washed away (rough coastline)
                    if TerrainBuilder.GetRandomNumber(4, "ME coast wash") == 0 then
                        plotTypes[i] = g_PLOT_TYPE_OCEAN;
                    end
                elseif prototype[i] == g_PLOT_TYPE_OCEAN and AdjacentLand(x, y) then
                    -- ~12% of near-shore water becomes a speckle islet
                    if TerrainBuilder.GetRandomNumber(8, "ME islet speck") == 0 then
                        plotTypes[i] = g_PLOT_TYPE_LAND;
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- Detail pass D: mountains & hills (after water shaping so coast adjacency
-- is final). Includes the Gondor Campus/HS mountain spur, Mount Doom, and
-- the Misty/White range re-roll for a bit of natural variety.
------------------------------------------------------------------------------
local CAP_X, CAP_Y = 52, 43;   -- Gondor capital (god-site anchor)

function PlaceMountainsAndHills(plotTypes)
    local T = TerrainBuilder;
    -- Misty Mountains / Ered Mithrin skeleton (from `m` cells): mostly
    -- mountain, ~1-in-3 becomes hills for passable gaps
    for y = 8, 27 do
        for x = 46, 51 do
            if plotTypes[y * g_iW + x] ~= g_PLOT_TYPE_OCEAN then
                if T.GetRandomNumber(3, "ME misty") == 0 then
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_HILLS;
                else
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_MOUNTAIN;
                end
            end
        end
    end
    -- White Mountains south-east spur towards Minas Tirith (Campus/HS
    -- neighbours, expressed in delta space relative to the capital):
    local function SetPlotByDelta(dx, dy, pt)
        local p = Map.GetPlotXY(CAP_X, CAP_Y, dx, dy, 8);
        if p ~= nil then
            local px, py = p:GetX(), p:GetY();
            plotTypes[py * g_iW + px] = pt;
        end
    end
    SetPlotByDelta( 2, -1, g_PLOT_TYPE_MOUNTAIN);  -- Campus N
    SetPlotByDelta( 2, -2, g_PLOT_TYPE_MOUNTAIN);  -- Campus NE
    SetPlotByDelta( 2,  1, g_PLOT_TYPE_MOUNTAIN);  -- HS
    SetPlotByDelta( 3,  0, g_PLOT_TYPE_MOUNTAIN);  -- decorative ridge E
    -- elevated river source (N of the god-site) so PaintMiddleEarthRivers works
    SetPlotByDelta( 0, -2, g_PLOT_TYPE_HILLS);
    -- Anduin east-flank source (hills) for the Ithilien river
    SetPlotByDelta( 4, -1, g_PLOT_TYPE_HILLS);
    -- home natural wonder tile (HILLS -> Crater Lake-valid; single-tile wonder)
    SetPlotByDelta(-2, -1, g_PLOT_TYPE_HILLS);

    -- MOUNT DOOM: single engraved mountain in the Mordor interior ring
    -- (62,41) is cell (31,20), currently hills in the blueprint
    local doomX, doomY = 62, 41;
    if plotTypes[doomY * g_iW + doomX] ~= g_PLOT_TYPE_OCEAN then
        plotTypes[doomY * g_iW + doomX] = g_PLOT_TYPE_MOUNTAIN;
    end

    -- Ered Lithui / Ephel Dúath already `m` in blueprint; re-roll to hills
    -- occasionally so the ring is not an unbroken wall
    for y = 38, 45 do
        for x = 58, 61 do
            if plotTypes[y * g_iW + x] == g_PLOT_TYPE_MOUNTAIN then
                if T.GetRandomNumber(5, "ME ephel") == 0 then
                    plotTypes[y * g_iW + x] = g_PLOT_TYPE_HILLS;
                end
            end
        end
    end

    -- generic hills scatter on all remaining land (avoid Gondor keep-out)
    for i = 0, (g_iW * g_iH) - 1 do
        if plotTypes[i] == g_PLOT_TYPE_LAND then
            local px = i % g_iW;
            local py = (i - px) / g_iW;
            if not InGondorKeepOut(px, py) then
                if T.GetRandomNumber(8, "ME hills") == 0 then
                    plotTypes[i] = g_PLOT_TYPE_HILLS;
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- Terrain overrides: after GenerateTerrainTypes + ApplyTerrain, repaint land
-- by region so the Middle-earth climate matches the plan (snow Forodwaith,
-- tundra wastes, temperate Eriador/Gondor/Valinor, plains Mordor/Rhûn,
-- desert Harad). Mountains keep their latitude terrain.
------------------------------------------------------------------------------
local TERRAIN_GRASS  = g_TERRAIN_TYPE_GRASS;
local TERRAIN_PLAINS = g_TERRAIN_TYPE_PLAINS;
local TERRAIN_TUNDRA = g_TERRAIN_TYPE_TUNDRA;
local TERRAIN_SNOW   = g_TERRAIN_TYPE_SNOW;
local TERRAIN_DESERT = g_TERRAIN_TYPE_DESERT;

function IsForodwaith(x, y)  return x >= 30 and x <= 93 and y >= 4  and y <= 7;  end
function IsNorthWastes(x, y) return x >= 30 and x <= 93 and y >= 8  and y <= 15; end
function IsAman(x, y)        return x >= 2  and x <= 15 and y >= 22 and y <= 35; end
function IsPelori(x, y)      return x >= 8  and x <= 15 and y >= 27 and y <= 32; end
function IsEredLuin(x, y)    return x >= 28 and x <= 31 and y >= 14 and y <= 21; end
function IsEriador(x, y)     return x >= 32 and x <= 53 and y >= 16 and y <= 27; end
function IsMirkwood(x, y)    return x >= 58 and x <= 65 and y >= 18 and y <= 29; end
function IsFangorn(x, y)     return x >= 60 and x <= 63 and y >= 28 and y <= 33; end
function IsRohan(x, y)       return x >= 46 and x <= 57 and y >= 28 and y <= 37; end
function IsEmynMuil(x, y)    return x >= 58 and x <= 71 and y >= 28 and y <= 37; end
function IsGondor(x, y)      return x >= 40 and x <= 57 and y >= 38 and y <= 49; end
function IsErebor(x, y)      return x >= 62 and x <= 77 and y >= 14 and y <= 23; end
function IsRhun(x, y)        return x >= 74 and x <= 93 and y >= 16 and y <= 53; end
function IsMordor(x, y)      return x >= 62 and x <= 73 and y >= 36 and y <= 45; end
function IsKhand(x, y)       return x >= 62 and x <= 77 and y >= 44 and y <= 53; end
function IsHarad(x, y)       return x >= 40 and x <= 93 and y >= 54 and y <= 59; end
function IsSouthGondor(x, y) return x >= 32 and x <= 55 and y >= 44 and y <= 53; end

function OverrideTerrain(plotTypes, terrainTypes)
    local T = TerrainBuilder;
    for i = 0, (g_iW * g_iH) - 1 do
        if plotTypes[i] ~= g_PLOT_TYPE_OCEAN and plotTypes[i] ~= g_PLOT_TYPE_MOUNTAIN then
            local px = i % g_iW;
            local py = (i - px) / g_iW;
            local base = TERRAIN_GRASS;   -- default temperate band

            if IsForodwaith(px, py) then
                base = TERRAIN_SNOW;
            elseif IsNorthWastes(px, py) then
                base = TERRAIN_TUNDRA;
            elseif IsPelori(px, py) then
                -- snowy summit of Mount Pelóri (Eyja strides there)
                base = TERRAIN_SNOW;
            elseif IsAman(px, py) then
                -- Valinor: temperate, light plains for the Eldar pastures
                base = TERRAIN_GRASS;
                if T.GetRandomNumber(6, "ME aman plain") == 0 then base = TERRAIN_PLAINS; end
            elseif IsEredLuin(px, py) then
                base = TERRAIN_GRASS;
            elseif IsEriador(px, py) then
                -- Shire / Eriador: temperate with plains scatter
                base = TERRAIN_GRASS;
                if T.GetRandomNumber(5, "ME eriador") == 0 then base = TERRAIN_PLAINS; end
            elseif IsFangorn(px, py) then
                base = TERRAIN_GRASS;
            elseif IsMirkwood(px, py) then
                base = TERRAIN_GRASS;
            elseif IsRohan(px, py) then
                -- Riddermark: green plains
                base = TERRAIN_GRASS;
                if T.GetRandomNumber(4, "ME rohan") == 0 then base = TERRAIN_PLAINS; end
            elseif IsEmynMuil(px, py) then
                -- Brown Lands / Emyn Muil: barren plains
                base = TERRAIN_PLAINS;
            elseif IsGondor(px, py) then
                -- Gondor / Anórien / Ithilien: temperate heartland
                base = TERRAIN_GRASS;
                if T.GetRandomNumber(4, "ME gondor") == 0 then base = TERRAIN_PLAINS; end
            elseif IsErebor(px, py) then
                -- Dale and the Lonely Mountain region
                base = TERRAIN_GRASS;
                if T.GetRandomNumber(5, "ME dale") == 0 then base = TERRAIN_PLAINS; end
            elseif IsMordor(px, py) then
                -- Gorgoroth / Nurn: barren volcanic plains
                base = TERRAIN_PLAINS;
            elseif IsKhand(px, py) then
                base = TERRAIN_PLAINS;
                if T.GetRandomNumber(5, "ME khand") == 0 then base = TERRAIN_DESERT; end
            elseif IsRhun(px, py) then
                -- Rhûn steppes: plains
                base = TERRAIN_PLAINS;
                if T.GetRandomNumber(8, "ME rhun") == 0 then base = TERRAIN_GRASS; end
            elseif IsHarad(px, py) then
                -- The great Harad desert
                base = TERRAIN_DESERT;
            elseif IsSouthGondor(px, py) then
                -- Lebennin coast
                base = TERRAIN_GRASS;
                if T.GetRandomNumber(4, "ME lebennin") == 0 then base = TERRAIN_PLAINS; end
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
-- Hand-paint the forest regions: Mirkwood, Fangorn, the Golden Wood
-- (Lórien), the Old Forest/Shire woods, and the woods of Ithilien.
-- Runs after FeatureGenerator so hand forests are not double-featured;
-- district/delta tiles near the capital are skipped.
------------------------------------------------------------------------------
local FEATURE_FOREST = nil;

function GetFeatureIndex(featureType)
    local f = GameInfo.Features[featureType];
    if f ~= nil then return f.Index; end
    return -1;
end

function PaintMiddleEarthForests()
    FEATURE_FOREST = GetFeatureIndex("FEATURE_FOREST");
    if FEATURE_FOREST == -1 then
        print("MiddleEarth: WARNING — FEATURE_FOREST index not found, forests skipped");
        return;
    end

    local function PaintRect(cx, cy, rx, ry)
        for y = math.max(0, cy - ry), math.min(g_iH - 1, cy + ry) do
            for x = math.max(0, cx - rx), math.min(g_iW - 1, cx + rx) do
                local p = Map.GetPlot(x, y);
                if p ~= nil and not p:IsWater() and not p:IsMountain() and not p:IsImpassable() then
                    -- never forest a district-template tile of the homeland
                    local dx, dy = x - CAP_X, y - CAP_Y;
                    if not (dx >= -2 and dx <= 3 and dy >= -2 and dy <= 3) then
                        if TerrainBuilder.CanHaveFeature(p, FEATURE_FOREST, false) then
                            TerrainBuilder.SetFeatureType(p, FEATURE_FOREST);
                        end
                    end
                end
            end
        end
    end

    -- Mirkwood (southern half + heart); keep away from the Long Lake
    PaintRect(60, 22, 3, 3);
    -- Fangorn forest
    PaintRect(61, 31, 2, 1);
    -- Golden Wood (Lórien)
    PaintRect(57, 23, 1, 1);
    -- Shire woods (Old Forest vibes, west of Hobbiton)
    PaintRect(34, 22, 1, 1);
    -- Ithilien woods (east of the capital, east of the river)
    PaintRect(56, 43, 1, 1);
end

------------------------------------------------------------------------------
-- Hand-paint rivers: the god-site river N of the capital (feeds the CH +
-- capital adjacency), plus an Anduin east-flank river through Ithilien.
------------------------------------------------------------------------------
function PaintMiddleEarthRivers()
    -- primary: source on the hills N/NW of the capital, flows south through
    -- the district column
    local sourcePlot = Map.GetPlotXY(CAP_X, CAP_Y, 0, -2, 8);
    if sourcePlot ~= nil and not sourcePlot:IsWater() then
        local p = TerrainBuilder.GetInlandCorner(sourcePlot);
        if p ~= nil then
            DoRiver(p, FlowDirectionTypes.FLOWDIRECTION_SOUTH);
        end
    end
    -- secondary short river on the Ithilien flank (SE of the capital)
    local alt = Map.GetPlotXY(CAP_X, CAP_Y, 4, -1, 8);
    if alt ~= nil and not alt:IsWater() then
        local p2 = TerrainBuilder.GetInlandCorner(alt);
        if p2 ~= nil then
            DoRiver(p2, FlowDirectionTypes.FLOWDIRECTION_SOUTH);
        end
    end
end

------------------------------------------------------------------------------
-- Hand-place natural wonders: exactly 1 subtle single-tile home wonder within
-- 3 tiles of the Gondor capital (Crater Lake in the White spur), plus the
-- multi-tile Lysefjorden (fjord, PLACEMENT_PIOPIOTAHI) on the Gulf of Belfalas
-- coast (Dol Amroth) and Eyja (PLACEMENT_YOSEMITE) on the snowy Pelóri summit
-- of Aman for scouting/Mayflower. Lysefjorden + Eyja use the custom multi-tile
-- path below - a plain single-tile SetFeatureType silently fails for them
-- (swap fix, spec 143).
------------------------------------------------------------------------------
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

-----------------------------------------------------------------------------
-- Multi-tile natural-wonder support (ported from the vanilla
-- NaturalWonderGenerator CustomGetMultiTileFeaturePlotList / CustomSetFeature
-- Type / SetNaturalCliff / ResetTerrain). Lysefjorden (3 tiles) and Eyja
-- (2 tiles) need this path.
-----------------------------------------------------------------------------
local function ME_ResetTerrain(iPlot)
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

local function ME_SetNaturalCliff(iPlot)
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

-----------------------------------------------------------------------------
-- Mirror of vanilla CustomGetMultiTileFeaturePlotList: returns true and fills
-- aPlots (plot indices) when the tile satisfies the wonder's custom geometry.
-- Branches kept (verbatim): YOSEMITE/TORRES (2 E-W inland), CLIFFS_DOVER
-- (2 coast), GIANTS_CAUSEWAY (2 land+water), PIOPIOTAHI (3 coastal triangle,
-- used by Lysefjorden). Nil-guards added to the PIOPIOTAHI water checks.
-----------------------------------------------------------------------------
local function ME_CanMultiTile(pPlot, eFeatureType, aPlots)
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

        -- all 6 hexes around must be land
        if pNWPlot == nil or pNEPlot == nil or pWPlot == nil or pSWPlot == nil or pSEPlot == nil or pEPlot == nil or
           pNWPlot:IsWater() or pNEPlot:IsWater() or pWPlot:IsWater() or pSWPlot:IsWater() or pSEPlot:IsWater() or pEPlot:IsWater() then
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

-----------------------------------------------------------------------------
-- Scan around (cX,cY) for the first tile that satisfies the wonder's custom
-- multi-tile geometry; places the full multi-tile feature via
-- SetMultiPlotFeatureType. Returns the anchor plot or nil.
-----------------------------------------------------------------------------
local function PlaceMultiTileWonder(featureIndex, cX, cY, radius)
    for range = 0, radius do
        for dx = -range, range do
            for dy = -range, range do
                local p = Map.GetPlotXY(cX, cY, dx, dy, radius + 2);
                if p ~= nil then
                    local aPlots = {};
                    if ME_CanMultiTile(p, featureIndex, aPlots) then
                        TerrainBuilder.SetMultiPlotFeatureType(aPlots, featureIndex);
                        for k = 1, #aPlots do
                            ME_SetNaturalCliff(aPlots[k]);
                            ME_ResetTerrain(aPlots[k]);
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
    local lyse   = GetFeatureIndex("FEATURE_LYSEFJORDEN");
    local eyja   = GetFeatureIndex("FEATURE_EYJAFJALLAJOKULL");
    local crater = GetFeatureIndex("FEATURE_CRATER_LAKE");

    -- 1) subtle home wonder 2-3 tiles NW of the Gondor capital: single-tile
    --    CRATER LAKE (swap - Lysefjorden is a multi-tile coastal wonder and
    --    cannot sit on an inland hill).
    local home = PlaceWonderWanted(crater, CAP_X - 2, CAP_Y - 1, 3);
    if home ~= nil then
        print("MiddleEarth: home wonder at (" .. tostring(home:GetX()) .. "," .. tostring(home:GetY()) .. ")");
    else
        print("MiddleEarth: WARNING — home wonder tile invalid, skipped");
    end
    -- 2) Lysefjorden on the Gulf of Belfalas coast (Dol Amroth): 3-tile fjord,
    --    PLACEMENT_PIOPIOTAHI custom placement, water triangle facing the Gulf.
    local fjord = PlaceMultiTileWonder(lyse, 44, 51, 4);
    if fjord ~= nil then
        print("MiddleEarth: Lysefjorden at (" .. tostring(fjord:GetX()) .. "," .. tostring(fjord:GetY()) .. ")");
    else
        print("MiddleEarth: WARNING - Lysefjorden placement failed (no coastal fjord tile)");
    end
    -- 3) Eyja on the snowy Pelori summit of Aman (PLACEMENT_YOSEMITE, 2 tiles
    --    east-west; Aman's east ridge is painted snow so the Eyja terrain
    --    adjacency rule is satisfied).
    local volcano = PlaceMultiTileWonder(eyja, 12, 30, 3);
    if volcano ~= nil then
        print("MiddleEarth: Eyja at (" .. tostring(volcano:GetX()) .. "," .. tostring(volcano:GetY()) .. ")");
    else
        print("MiddleEarth: WARNING - Eyja placement failed");
    end
end

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
    print("MiddleEarth: WARNING — no SS_HUMAN slot found; assuming player 0");
    return 0;
end

------------------------------------------------------------------------------
-- Faction -> anchor map (cell-precise). Non-mapped civs keep whatever the
-- generator assigned (the map is otherwise civ-agnostic).
------------------------------------------------------------------------------
local FACTION_ANCHORS = {
    ["CIVILIZATION_ROME"]     = { 52, 43 },   -- Gondor (human; OP homeland)
    ["CIVILIZATION_SCYTHIA"]  = { 59, 32 },   -- Rohan
    ["CIVILIZATION_FRANCE"]   = { 56, 23 },   -- Lóthlórien (Eleanor)
    ["CIVILIZATION_GERMANY"]  = { 69, 17 },   -- Erebor
    ["CIVILIZATION_CREE"]     = { 35, 21 },   -- Shire
    ["CIVILIZATION_AZTEC"]    = { 64, 41 },   -- Mordor
    ["CIVILIZATION_ARABIA"]   = { 48, 56 },   -- Harad
    ["CIVILIZATION_MONGOLIA"] = { 84, 23 },   -- Rhûn
};

local function GetCivName(slot)
    local cfg = PlayerConfigurations[slot];
    if cfg == nil then return nil; end
    return cfg:GetCivilizationTypeName();
end

------------------------------------------------------------------------------
-- ForceFactionStarts: after AssignStartingPlots.Create returns, move every
-- mapped civ onto its scripted anchor. Anchors are hand-spaced >= 12 hex
-- apart from the Gondor capital (verified at design time).
------------------------------------------------------------------------------
function ForceFactionStarts()
    for slot = 0, 15 do
        local cfg = PlayerConfigurations[slot];
        if cfg ~= nil then
            local status = cfg:GetSlotStatus();
            if status == SlotStatus.SS_HUMAN or status == SlotStatus.SS_CPU then
                local civ = GetCivName(slot);
                local anchor = FACTION_ANCHORS[civ];
                if anchor ~= nil then
                    local p = Map.GetPlot(anchor[1], anchor[2]);
                    if p ~= nil and not p:IsWater() then
                        Players[slot]:SetStartingPlot(p);
                        print("MiddleEarth: forced " .. tostring(civ) .. " (slot " .. slot .. ") to (" ..
                              anchor[1] .. "," .. anchor[2] .. ")");
                    else
                        print("MiddleEarth: WARNING — anchor invalid for " .. tostring(civ));
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- ForceHumanToGondorIfUnmapped: if the human picked a civ with no faction
-- anchor (e.g. any non-mapped leader), still put the human on Gondor so the
-- OP homeland battery always lands on the human player.
------------------------------------------------------------------------------
function ForceHumanToGondorIfUnmapped()
    local humanIndex = GetHumanPlayerIndex();
    local civ = GetCivName(humanIndex);
    if FACTION_ANCHORS[civ] == nil then
        local p = Map.GetPlot(CAP_X, CAP_Y);
        if p ~= nil and not p:IsWater() then
            Players[humanIndex]:SetStartingPlot(p);
            print("MiddleEarth: human civ " .. tostring(civ) .. " unmapped — forced to Gondor");
        end
    end
end

------------------------------------------------------------------------------
-- EnforceHumanStartIsolation: after the human start is forced onto Gondor,
-- relocate any NON-anchored AI major that ended up within
-- MIN_HUMAN_AI_START_DIST tiles of the capital. Hand-anchored civs are
-- deliberately placed (all >= 12 from Gondor) and are skipped here.
------------------------------------------------------------------------------
local MIN_HUMAN_AI_START_DIST = 12;   -- vanilla major-vs-major start buffer
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
            local aisCiv    = GetCivName(aiIndex);
            if FACTION_ANCHORS[aisCiv] ~= nil then
                -- deliberately anchored faction: skip
            elseif startPlot ~= nil and
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
                    print("MiddleEarth: relayed AI " .. aiIndex .. " start (" ..
                          startPlot:GetX() .. "," .. startPlot:GetY() .. ") -> (" ..
                          finalTarget:GetX() .. "," .. finalTarget:GetY() .. ")");
                else
                    print("MiddleEarth: WARNING — no relay target found for AI " .. aiIndex);
                end
            end
        end
    end
end

------------------------------------------------------------------------------
-- District template (delta space, radius <= 1 of the capital):
--    cap  (0,0)      IZ (1,0)     Campus (1,-1)   HS (1,1)
--    CH   (0,-1)     Theater (-1,-1) GovPlaza (-1,0)
--    spare (2,0)     spare (0,2)   (no Harbor — Gondor is an inland capital)
------------------------------------------------------------------------------
local DISTRICT_DELTAS = {
    {  0,  0 },   -- capital
    {  1,  0 },   -- IZ
    {  1, -1 },   -- Campus
    {  1,  1 },   -- Holy Site
    {  0, -1 },   -- Commercial Hub
    { -1, -1 },   -- Theater Square
    { -1,  0 },   -- Government Plaza
    {  2,  0 },   -- spare A (kept empty)
    {  0,  2 },   -- spare B (kept empty)
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
-- Engrave the OP resource battery around the Gondor capital (3-ring),
-- skipping the district template + capital + wonder tiles. LAND ONLY — the
-- capital is inland (no Harbor/sea resources). Uses engine validation guards.
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
    local RES_WHEAT   = Res("RESOURCE_WHEAT");
    local RES_DEER    = Res("RESOURCE_DEER");
    local RES_STONE   = Res("RESOURCE_STONE");
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

    -- === LUXURIES (amenity headroom + sellable): 4 copies, 2 types ===
    TryPlace( 0, -2, RES_WINE);              -- river-bank wine (N)
    TryPlace(-1, -3, RES_WINE);
    TryPlace(-2,  2, RES_TRUFFLES);          -- woods truffles (W-SW)
    TryPlace( 3,  2, RES_TRUFFLES);

    -- === STRATEGICS (progressive curve) ===
    TryPlace(-2,  0, RES_IRON);              -- hills ring 2 (W)
    TryPlace(-3,  1, RES_IRON);
    TryPlace(-1,  2, RES_HORSES);
    TryPlace( 2,  1, RES_HORSES);            -- IZ-adjacent plains (E)
    TryPlace( 1, -3, RES_NITER);             -- ring 2-3 (N-NE)
    TryPlace( 0, -4, RES_NITER);
    TryPlace( 2,  2, RES_COAL);              -- ring 2-3 (E-SE)
    TryPlace( 3,  3, RES_COAL);
    TryPlace(-3,  3, RES_OIL);               -- ring 3 (SW)
    TryPlace( 3, -1, RES_OIL);               -- ring 2-3 (E-NE)

    -- === BONUS (food + chops; stones feed IZ quarries) ===
    TryPlace(-2, -1, RES_STONE);             -- home-wonder flank (W) [wonder tile now; TryPlace skips via IsNaturalWonder]
    TryPlace( 0, -3, RES_STONE);
    TryPlace(-3, -2, RES_STONE);
    TryPlace(-1, -2, RES_WHEAT);             -- river wheat (NW)
    TryPlace(-1, -1, RES_WHEAT);             -- Theater flank (W)
    TryPlace( 1,  3, RES_DEER);              -- south woods (SE)
    TryPlace(-3, -1, RES_DEER);
    TryPlace( 2, -1, RES_RICE);              -- Ithilien paddy (E-NE)

    print("MiddleEarth: god-site engraved at (" .. tostring(capX) .. "," .. tostring(capY) .. ")");
end

------------------------------------------------------------------------------
-- GenerateMap: main pipeline. Mirrors continents.lua ordering with the
-- hand-painted blueprint substituting the fractal landmass pass.
------------------------------------------------------------------------------
function GenerateMap()
    print("Generating MiddleEarth Map");

    -- Set globals
    g_iW, g_iH = Map.GetGridSize();
    g_iFlags = TerrainBuilder.GetFractalFlags();

    ---------------------------------------------------------------------------
    -- 1. Worldshape: blueprint -> plotTypes
    ---------------------------------------------------------------------------
    plotTypes = {};
    RasterizeBlueprint(plotTypes);
    DetailCoastline(plotTypes);
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
    -- 3. Rivers (+ hand Middle-earth rivers), features (incl. hand forests),
    --    lakes, cliffs. No random large lakes: the blueprint already encodes
    --    Sea of Rhûn, Long Lake, the Núrnen and the Gulf of Belfalas.
    ---------------------------------------------------------------------------
    AddRivers();
    PaintMiddleEarthRivers();

    -- feature wrapper (continents-style): rainfall Normal
    local rainfall = 2;
    local featuregen = FeatureGenerator.Create({ rainfall = rainfall });
    featuregen:AddFeatures();

    -- hand-painted forests AFTER the generator so they are not
    -- double-featured and never overridden by random vegetation
    PaintMiddleEarthForests();

    local numLargeLakes = 0;
    AddLakes(numLargeLakes);

    AddCliffs(plotTypes, terrainTypes);

    ---------------------------------------------------------------------------
    -- 4. Natural wonders (hand-placed; exactly 1 subtle home wonder)
    ---------------------------------------------------------------------------
    PlaceNaturalWonders();

    AreaBuilder.Recalculate();
    TerrainBuilder.AnalyzeChokepoints();
    TerrainBuilder.StampContinents();

    ---------------------------------------------------------------------------
    -- 5. Map-wide resources: SPARSE for the AI hemisphere. Hand-engraving
    --    of the human battery happens after the start is forced (step 7).
    ---------------------------------------------------------------------------
    local resourcesConfig = 1;                 -- Sparse (force: ignore setup screen)
    local startConfig     = 2;                 -- Standard start resources for civs
    local resGen = ResourceGenerator.Create({ resources = resourcesConfig, START_CONFIG = startConfig });

    ---------------------------------------------------------------------------
    -- 6. Start plots for all civs (standard START_CONFIG with start bias off
    --    — mapped factions are pushed to anchors afterwards).
    ---------------------------------------------------------------------------
    local args = {
        MIN_MAJOR_CIV_FERTILITY = 150,
        MIN_MINOR_CIV_FERTILITY = 50,
        MIN_BARBARIAN_FERTILITY = 1,
        START_MIN_Y = 8,
        START_MAX_Y = 58,
        START_CONFIG = startConfig,
        IGNORESTARTBIAS = true,
    };
    local start_plot_database = AssignStartingPlots.Create(args);

    ---------------------------------------------------------------------------
    -- 7. Force mapped factions onto anchors + the human onto Gondor (after
    --    AssignStartingPlots returns so the commit is not overwritten), then
    --    engrave the battery, then push stray non-anchored AI away.
    ---------------------------------------------------------------------------
    ForceFactionStarts();
    ForceHumanToGondorIfUnmapped();

    local humanIndex = GetHumanPlayerIndex();
    local capPlot = Players[humanIndex]:GetStartingPlot();
    if capPlot ~= nil and not capPlot:IsWater() then
        EngraveGodSite(capPlot);
        EnforceHumanStartIsolation(capPlot);
    else
        print("MiddleEarth: WARNING — god-site plot invalid, human start unforced");
    end

    ---------------------------------------------------------------------------
    -- 8. Goody huts (bundle.lua), away from the human start.
    ---------------------------------------------------------------------------
    local GoodyGen = AddGoodies(g_iW, g_iH);

    print("MiddleEarth Map complete");
end