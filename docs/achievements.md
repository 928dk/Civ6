# Vinterhav — Steam Achievement Map (verified against install data 2026-09-20)

Achievement → map-feature mapping for the Vinterhav map-script mod
(`~/projects/Client/Civ6/Vinterhav/`, spec packet `~/.opencode/specs/140-civ6-vinterhav/`).

All achievement names and requirements below were extracted from the 320-achievement
pool defined for this install's game version (R&F + GS; sources: Steam Global
Achievements + `civilization.fandom.com` Steam achievements in Civ6 page).
Game-modes-off default (ley lines, Secret Societies, Heroes, Monopolies,
Apocalypse, Dramatic Ages) is assumed throughout — the spec locks those OFF.

**Eligibility caveat (spec packet §Risks, item 2):** Steam achievement grant with a
map-script mod active on the Aspyr Linux build is **unverified until T015**.
The tiers below are *achievable targets*, not guaranteed-granted. Confirm the
first win grants achievements during T015 before relying on this list.

**Account-wide caveat:** already-unlocked achievements do not re-unlock. Check your
Steam progress (Steam → Civ 6 → Global Achievements) first; tick the ones still
missing and target only those.

---

## Map features that do the work

| Feature | Detail |
|---|---|
| Fixed grid, no wrap | 84×54, never wraps — sailing "around the world" is impossible (see Elcano anti-pick) |
| OP human homeland | forced start on hand-engraved cape; ring 1–3 lux/strategic/bonus battery; 9-tile district-adjacency template (cap/IZ/Campus/HS/CH/Harbor/Theater/GovPlaza/spare) |
| 1 subtle natural wonder ≤3 tiles of capital | Giant's Causeway (home, sound-side cape NW of capital — swapped from Lysefjorden 2026-09-21 as Lyse can't fit), Eyja (Islandia), Crater (South continent) — exactly 3 in total |
| Nerfed AI hemispheres | sparse resources, standard starts, `IGNORESTARTBIAS=true` (civ-agnostic) |
| Human-only starting bonuses | +2 of every unit class (Warrior/Scout/Builder/Slinger/Spearman/Trader/Settler — user OP buff 2026-09-21), 900,909 gold t0 (VinterhavStartGold.lua) |
| 6–8 player setup | Standard-sized game, Ancient era start default |

---

## Tier 1 — Win ladder (one Immortal win unlocks 8)

| Achievement | Requirement | Enabler |
|---|---|---|
| Game, Settler, Match | Win at Settler or harder | OP homeland snowball |
| Irish Heartbeat | Win at Chieftain or harder | ^ |
| Warlording Over Others | Win at Warlord or harder | ^ |
| Machiavelli's Great Work | Win at Prince or harder | ^ |
| The Divine Right of Kings | Win at King or harder | ^ |
| Emperor's New Groove | Win at Emperor or harder | ^ |
| 12 Labors of Hercules | Win at Immortal or harder (no Deity-only achievement exists) | ^ |
| The Test of Time | Win with an Ancient Era start | default start era — free with any win |

**Strategy:** one comfortable Immortal (or Deity) game on Vinterhav clears the entire
difficulty ladder at once. Difficulty does not change the map's OP homeland, so the
only difference from Settler is AI aggression — safe with 90k gold and 3 extra units.

**Victory-type wins (separate games — one each, any difficulty):**

| Achievement | Requirement | Enabler |
|---|---|---|
| Mission to Mars | Science victory, any leader | campus battery + home production |
| Buying Your Blue Jeans and Listening to Your Pop Music | Culture victory, any leader | theater/gov-plaza template + early wonder tempo |
| Veni, vidi, vici | Domination victory, any leader | t0 army + gold economy vs sparse AI |
| Nirvana | Religious victory, any leader | holy-site adjacency + faith buys |
| The Art of Telling Plain Truths | Diplomatic victory (GS) | gold buys diplomatic favor via suzerainty/events |

---

## Tier 2 — Turn-1–50 mechanicals (near-guaranteed)

| Achievement | Requirement | Enabler |
|---|---|---|
| If You Build It, They Will Come | 6 improvements at one time | t0 Builder + 90k gold |
| Escort Service | put two units into a formation | t0 Warrior + Scout |
| Everything is Awesome!!! | Ecstatic city at start of turn | ring 2–3 lux battery + gold-bought luxes |
| New Orleans Style Spanish Rice | become Suzerain of a city-state | 90k gold = instant suzerainty |
| Naming Rights | name a unit | any first promotion |
| Investment Banking | enemy city under siege at start of turn | Warrior/Scout + gold-rush army |
| Victory Belongs to the Most Persevering | achieve a Heroic Age (R&F, on by default) | early era-score burst from battery/template |
| A Revolution Without Dancing | change your government | civics by t2+ |

---

## Tier 3 — Map-specific or conditional

| Achievement | Requirement | Condition / enabler |
|---|---|---|
| Eight is Enough | Win on a Standard Map | map size must show "Standard" in setup (84×54 grid; confirm label at T015) |
| Varangian Guard | Win as Harald Hardrada | included only while playing Norway — the intended lead |
| Silver Anniversary | 6 Silver luxuries at turn start | only if homeland battery includes Silver; otherwise N/A |
| Man on the Moon | Science victory + captured Egyptian city + Newton & Darwin activated | possible but fiddly; optional |
| Selfie | Culture victory with your leader in the game as opponent | possible; optional |
| Robber Baron / Top Hat and Monocle | Monopolies game mode, Standard+ map | **mode-gated** — out of default scope; noted for future mode runs |

---

## Anti-recommendations (why these are NOT targets on Vinterhav)

| Achievement | Why not |
|---|---|
| Elcano's Revenge (first circumnavigation) | **impossible on a no-wrap map** — never wraps east↔west |
| Dirty Dozen (Huge), Ten Commandments (Large), Island Hopping (Huge Island Plates) | map size/type differs from Vinterhav's fixed 84×54 Standard |
| After Antiquity / Out of the Dark Ages / Renaissance Man / Captain of Industry / Modern Major General / Splitting the Atom / Through the Digital Age | need Classical→Information era starts; Vinterhav plays Ancient (The Test of Time is the freebie) |
| Scenario achievements (Gifts of the Nile, Vikings/Traders/Raiders, Red Death, …) | scenarios, not map games |
| Game-mode achievements (Secret Societies, Heroes, Apocalypse, Dramatic Ages, Monopolies) | modes are locked OFF per spec |
| Civ-specific wins for other leaders | only relevant if you pick that leader; Varangian Guard covers Norway |

---

## How to run a clean achievement game

1. In-game → Advanced Setup → Map: **Vinterhav**, size Standard, 6–8 players,
   Ancient era, all game modes OFF, difficulty Immortal or Deity.
2. Turn 0: verify 900,909 gold + **2× every unit class** (incl. 2 settlers) in
   `Logs/lua.log` (`Vinterhav: granted …` lines) — human only, AI untouched.
   (Aspyr Linux never writes `lua.log` — verify visually instead: gold counter + unit list.)
3. Victory ladder: pick Science/Culture/Domination/Religious/Diplomatic per run.
4. After each win: confirm the Steam achievement fired (see eligibility caveat).