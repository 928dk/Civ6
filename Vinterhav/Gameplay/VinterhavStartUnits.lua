-- VinterhavStartUnits.lua — Vinterhav mod (spec 140).
-- Grants the HUMAN player extra starting units at game start (turn 0 only).
-- AI players are never affected (OP-for-human design).
--
-- Config: edit `extraUnits` below. Set any amount to 0 to skip that unit.
-- Unit type names are registered in GameInfo.Units (Base/Assets/Gameplay/
-- Units.xml; Gathering Storm additions in DLC/Expansion2/Expansion2_Units_Major).
--
-- Placement: each unit spawns on a free non-water, non-impassable tile in
-- ring 1, then ring 2 of the human start plot. If no free tile is found the
-- unit is placed on the start plot itself (stacked, like the settler+warrior).

local extraUnits = {
    UNIT_WARRIOR = 2,   -- escorts the settler / early barb defense
    UNIT_SCOUT   = 2,   -- exploration + goody hut reach
    UNIT_BUILDER = 2,   -- early improvement head start
    UNIT_SLINGER = 2,
    UNIT_SPEARMAN = 2,
    UNIT_TRADER = 2,
    UNIT_SETTLER = 2,   -- OP start buff (user, 2026-09-21): 2× every class
}

local function IsValidSpawnPlot(pPlot)
    if pPlot == nil then
        return false
    end
    if pPlot:IsWater() or pPlot:IsImpassable() then
        return false
    end
    -- occupied by an existing unit? (start plot holds the settler+warrior)
    if Units.GetUnitCountInPlot(pPlot) > 0 then
        return false
    end
    return true
end

local function FindSpawnPlot(anchorPlot)
    -- ring 1: all 6 direct neighbours
    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local pPlot = Map.GetAdjacentPlot(anchorPlot:GetX(), anchorPlot:GetY(), direction)
        if IsValidSpawnPlot(pPlot) then
            return pPlot
        end
    end
    -- ring 2: step out one more from each direction (skip water/impassable)
    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local ring1 = Map.GetAdjacentPlot(anchorPlot:GetX(), anchorPlot:GetY(), direction)
        if ring1 ~= nil then
            local pPlot = Map.GetAdjacentPlot(ring1:GetX(), ring1:GetY(), direction)
            if IsValidSpawnPlot(pPlot) then
                return pPlot
            end
        end
    end
    return nil
end

local function GrantStartUnits(player)
    local pPlayer = Players[player]
    if pPlayer == nil or not pPlayer:IsHuman() then
        return
    end

    local startPlot = pPlayer:GetStartingPlot()
    if startPlot == nil then
        print("Vinterhav: no starting plot for human player " .. player .. "; skipping unit grant")
        return
    end

    local playerUnits = pPlayer:GetUnits()
    local placed = 0
    for unitName, amount in pairs(extraUnits) do
        if amount ~= nil and amount > 0 then
            local unitDef = GameInfo.Units[unitName]
            if unitDef ~= nil then
                for i = 1, amount, 1 do
                    local pPlot = FindSpawnPlot(startPlot)
                    if pPlot == nil then
                        pPlot = startPlot  -- fallback: stack on the start tile
                    end
                    playerUnits:Create(unitDef.Index, pPlot:GetX(), pPlot:GetY())
                    placed = placed + 1
                end
            else
                print("Vinterhav: unknown unit type " .. unitName .. "; skipped")
            end
        end
    end
    print("Vinterhav: granted " .. placed .. " extra starting unit(s) to human player " .. player)
end

local function OnPlayerTurnActivated(player, bIsFirstTime)
    -- only the very first turn of the game; wait until the HUMAN player's
    -- turn activates (AI activations pass through without unhooking)
    if Game.GetCurrentGameTurn() ~= GameConfiguration.GetStartTurn() then
        return
    end
    local pPlayer = Players[player]
    if pPlayer == nil or not pPlayer:IsHuman() then
        return
    end
    GrantStartUnits(player)
    -- this is a one-shot grant; unhook so it never fires again
    Events.PlayerTurnActivated.Remove(OnPlayerTurnActivated)
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated)
