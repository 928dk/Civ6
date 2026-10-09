-- MiddleEarthStartGold.lua — Middle-earth mod (spec 143).
-- Grants the HUMAN player a starting gold bump at game start (turn 0 only).
-- AI players are never affected (OP-for-human design, Vinterhav parity).
--
-- Choice B (user, 2026-09-20): cap the grant at 90,909 gold (additive on the
-- normal start gold). Tune `g_iStartGold` below if you want a different amount.
--
-- Timing (choice C, user, 2026-09-20): applied on the very first turn, before
-- the human's first end-of-turn, via the same one-shot guard used by
-- MiddleEarthStartUnits.lua so it cannot be missed by AI turn order.

local g_iStartGold = 90909

local function ApplyStartGold(player)
    local pPlayer = Players[player]
    if pPlayer == nil then
        return
    end

    local treasury = pPlayer:GetTreasury()
    if treasury == nil then
        print("MiddleEarth: no treasury for player " .. player .. "; gold grant skipped")
        return
    end

    treasury:ChangeGoldBalance(g_iStartGold)
    print("MiddleEarth: granted " .. g_iStartGold .. " starting gold to human player " .. player)
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
    ApplyStartGold(player)
    -- this is a one-shot grant; unhook so it never fires again
    Events.PlayerTurnActivated.Remove(OnPlayerTurnActivated)
end

Events.PlayerTurnActivated.Add(OnPlayerTurnActivated)