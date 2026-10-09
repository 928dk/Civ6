# Plan V2: "Vinterhav" — OP player experience + Steam achievement run

> Status: **IMPLEMENTED & DEPLOYED** (2026-09-20). Supersedes `PLAN.md` for the OP/achievement build; base map drafting
> (blueprint, grid, registration) still follows `PLAN.md` §Map design + §Deliverables. OP homeland (river-delta cape),
> fixed 84×54 no-wrap grid, human-only engraving, AI sparse — all in the shipped `Vinterhav.lua`.

## Decisions locked in (user, 2026-09-19)
1. **OP for the human player only.** AI civs get standard/sparse resources + standard fertility; no hand-engraved batteries on rival continents.
2. **No civ preference — map must maximize Steam achievement clearing.** Human start is civ-agnostic (no start-bias dependence); `IGNORESTARTBIAS=true` so the God-site is pure. See §Achievements.
3. **Natural wonders near home: SUBTLE — exactly 1** placed within 3 tiles of the capital (era score + HS/Theater adjacency, not blatant).
4. **Ley lines: OFF** (`AddLeyLines()` not called; no Secret Societies dependency).

## OP mechanics — verified in the installed game (steamassets)
| Lever | API / knob | Source |
|---|---|---|
| Force human start | `Players[i]:SetStartingPlot(plot)` — engine commit, call AFTER `AssignStartingPlots.Create(...)` | `utility/assignstartingplots.lua:199` |
| Legendary start resources | `START_CONFIG = 3` → `__AddResourcesLegendary()` (bonus+lux spawned around every major start) | `assignstartingplots.lua:187-191,2007` |
| Global resource density | `ResourceGenerator.Create({resources=…})` → `iTargetPercentage` (base 29) | `utility/resourcegenerator.lua:140` |
| District adjacency | IZ↔mines/quarries, Campus↔mountains, HS↔mountains/NW, CH↔river, Theater↔wonder, Harbor↔sea res, GovPlaza↔all | GS rules |
| (OFF) Ley lines | `AddLeyLines()` +1 to every adjacent district | `dlc/Expansion2/maps/earthmaps/tslmediterraneanlarge_xp2.lua` |

**Key move:** force `START_CONFIG = 3` in BOTH `ResourceGenerator.Create` and `AssignStartingPlots.Create` → human gets Legendary no matter the setup screen.

## 1. Hand-engraved "Vinterhav Homeland" (human-only OP)
After `AssignStartingPlots.Create(...)`, get `Players[GameConfiguration.GetLocalPlayer()]` and `:SetStartingPlot()` onto a pre-painted God-site (river-delta: plains+hills cape on the coast near the Danish strait). Then, within the workable **3-ring**:

- **Luxuries (amenity headroom + sellable):** 4–5 copies of 2–3 types in ring 1–2 (e.g. Wine on river, Truffles in forest, Crabs on coast).
- **Strategics (progressive curve):** Iron+1 Horses ring 1–2; Niter, Coal, Oil ring 2–3 (reveal via tech — fuels domination→industrial→modern).
- **Bonus (food + chops):** Wheat/Rice on floodplains, Deer in woods, 2–3 Stone (quarry → also feeds IZ adjacency).
- **1 Natural Wonder** within 3 tiles (subtle).
- **Rivers:** at least one river under/adjacent to the capital and one to the Commercial Hub tile.

## 2. District ↔ resource distance blueprint (adjacency = immediate-neighbor hexes)
Reserve district footprints BEFORE engraving resources — never put a district *on* a resource tile.

- **Industrial Zone:** flanked by 2–3 mine/quarry hexes (+4–6); resources adjacent to IZ, not on it.
- **Campus:** against a 2-hex mountain ridge (+1) → near the natural wonder for more.
- **Holy Site:** mountain-adjacent + natural wonder adjacent (+2–3).
- **Commercial Hub:** on/adjacent the river (+2), next to the Harbor.
- **Harbor:** city-center + 2 adjacent sea resources (+3).
- **Theater Square:** adjacent to the natural wonder (+2).
- **Government Plaza:** hub position so the above cluster all get +1.
- Keep the river-bank district strip resource-free; wrap resources one ring *around* the districts.

## 3. Other OP considerations
- **Fresh water + coast for every planned city site** (river/lake/oasis/coast) → housing; lay out 6–8 kingdom settle spots, each with its own lux+strategic+food combo.
- **Temperate band wide for human; harsh tundra/snow/ice on rival continents** (fantasy-Nord theme: keep the player's Denmark/Sweden landmass warm).
- **Natural moats:** sea + border mountain spine → chokepoints vs AI/barb first 60 turns.
- **AI hemisphere nerf:** standard resources + low fertility thresholds vs human's engraving.
- **2–3 city-states within short trade reach** (early suzerain bonuses; also feeds suzerain achievements).
- **Goody huts** on the early exploration paths out of the capital.
- **Appeal chain:** coast+forest up the human shore → Seaside Resorts/Preserves; keep a high-appeal woods pocket for National Parks.
- **Balance for fun:** don't remove *all* forest (chop queue), keep ~8 buildable empties in ring 2–3 so districts aren't blocked.
- **Victory diversity in homeland:** Science (mountain campus), Production (hills/IZ chain), Faith (big HS), Culture (wonder adjacency) — no re-rolling per civ.

## 4. Achievements (no-civ-preference focus)
All builds assume 6–8 players (default), no map wrap, standard size. Map levers chosen to make these clearable in one or a few runs:

**Exploration / discovery**
- **Distant Shores** (land on another continent) — ensure player landmass ≠ rival landmasses; wide oceans with islands.
- **Can't We Be Friends / Stop Right There** (meeting civs) — 6–8 civs on separate landmasses.
- Natural-wonder discovery + **"Sunnyside Up" style discovery chains** — 1 subtle home wonder + more distributed so early scouts hit 2–3.
- **Goody-hut achievements** (e.g. ancient tribal village bonuses) — huts on the two primary scout directions.

**Empire / yields**
- **High adjacency chains** (e.g. big IZ/HS/Campus adjacency achievements) — guaranteed by the blueprint above.
- **Religion (shared belief / pantheon) achievements** — big HS + faith yields from start.
- **Hustler/gold achievements** — CH river + harbor + luxury sale economy.

**Domination**
- **Rapid-conquest achievements** — humans has Iron+Horses ring 1–2 for early units; AI hemisphand underpowered; chokepoints make siege quick.
- **Conquer a capital / cap a continent** — rival landmasses reachable by mid-game.

**Science / culture / quantity**
- **Space race fast** — production-rich IZ chain homeland.
- **Culture/tourism, Great People** — wonder adjacency + appeal pocket.

> Note: verify exact current achievement list at implementation time and tag each chosen one to a map feature. Achievements dependent on game modes (Barbarian Clans, Secret Societies, etc.) are out of scope unless user opts in.

## 5. Implementation delta to PLAN.md
1. After `AssignStartingPlots.Create(...)` and before `SetDefaultAssignedStartingPlots()`: force human start onto God-site: `Players[GameConfiguration.GetLocalPlayer()]:SetStartingPlot(sitePlot)`.
2. Pass `START_CONFIG = 3` to both ResourceGenerator and AssignStartingPlots Create args. Optionally `IGNORESTARTBIAS=true`.
3. Add ring-1/2/3 resource placement tables (direct `ResourceBuilder.SetResourceType(plot, type, amount)`).
4. Add fixed 9-tile capital "district adjacency template".
5. AI-hemisphere nerf pass (sparse luxury/strategic near rival continents, low `MIN_MAJOR_CIV_FERTILITY` on their landmasses).
6. No `AddLeyLines()`.
7. Achievement → map-feature table in `docs/achievements.md` at implementation time.
8. Keep `PLAN.md` §1–§4 (blueprint, grid, registration, validation, deploy) unchanged as base.

## Open items (carried from PLAN.md)
- Map name: "Vinterhav" (default; alternates Nordgavlen / Midgard-Mare).
- Grid: fixed ~84×54, no wrap (default) vs draggable standard sizes.
- Live Mods dir confirmation + Maps-table schema dump (PLAN.md implementation steps 1–2).
- Spec folder: `~/.opencode/specs/140-civ6-vinterhav/` per AGENTS.MD Gate 3 before implementation.