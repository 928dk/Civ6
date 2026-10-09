# Middle-earth — Steam Achievement Map (spec 143, mirrors Vinterhav doc 2026-09-21)

Achievement → map-feature mapping for the Middle-earth map-script mod
(`~/projects/Client/Civ6/MiddleEarth/`, spec packet `~/.opencode/specs/143-civ6-middleearth/`).

All achievement names and requirements below come from the same 320-achievement
pool used by the Vinterhav doc (`docs/achievements.md`, verified 2026-09-20 against
this install's R&F + GS game version). Game-modes-off default (ley lines, Secret
Societies, Heroes, Monopolies, Apocalypse, Dramatic Ages) is assumed throughout —
the spec locks those OFF. See `docs/game_forensics.md` for the Steam-verification
situation: took the map into the shop, `x?xml=1` verified local/steam-side evidence
collection, and Achievements.log is the accepted proof surface on this Aspyr Linux
build.

**Eligibility caveat (spec packet §Risks, item 2):** Steam achievement grant with a
map-script mod active on the Aspyr Linux build is **unverified until T016**. The
tiers below are *achievable targets*, not guaranteed-granted. Confirm the first win
grants achievements during T016 before relying on this list.

**Account-wide caveat:** already-unlocked achievements do not re-unlock. Check your
Steam progress (Steam → Civ 6 → Global Achievements) first; tick the ones still
missing and target only those.

---

## Map features that do the work

| Feature | Detail |
|---|---|
| Fixed grid, no wrap | 106×66, never wraps — sailing "around the world" is impossible (see Elcano anti-pick) |
| **Large map** | the map-size dropdown must show **Large** (records the size the win-ladder + Ten Commandments key on); the script always returns the fixed 106×66 grid |
| OP Gondor homeland | human forced to Gondor (52,43); hand-engraved 3-ring battery + district template (cap/IZ/Campus/HS/CH/Theater/GovPlaza + 2 spares — **no Harbor: Gondor is inland**); 4 White-spur mountains for Campus/HS adjacency; river through the district column; home wonder (Crater Lake) 2–3 tiles NW at ~(50,42) |
| 3 natural wonders | **Crater Lake** (home, single-tile, ~2W 1N of the capital (50,42)), **Eyjafjallajökull** on the snowy Pelóri summit of Aman/Valinor (~(12,30)), **Lysefjorden** on the Gulf of Belfalas coast, Dol Amroth (~(44,51), 3-tile fjord facing the Gulf) — exactly 3 in total *(v2 swap: Lysefjorden is a multi-tile coastal wonder — it cannot sit on an inland hill; primary home wonder swapped to single-tile Crater Lake)* |
| Scripted faction starts | Rome→Gondor (human), Scythia→Rohan, France(Eleanor)→Lothlórien, Germany→Erebor, Cree→Shire, Aztec→Mordor, Arabia→Harad, Mongolia→Rhûn; all AI anchors hand-spaced ≥12 hex from the capital |
| Separate western continent | Aman/Valinor is its own landmass (Stamped) — enables Voyage of the Mayflower |
| Mount Doom | engraved single mountain inside the Ered Lithui + Ephel Dúath Mordor ring at (62,41) |
| Nerfed AI | sparse resources, standard starts, `IGNORESTARTBIAS=true` (civ-agnostic) |
| Human-only starting bonuses | +1 Warrior, +1 Scout, +1 Builder (MiddleEarthStartUnits.lua), 90,909 gold t0 (MiddleEarthStartGold.lua) |
| 8 player setup | Large-sized game, Ancient era start default |

---

## Tier 1 — Win ladder (one Immortal win unlocks 8)

| Achievement | Requirement | Enabler |
|---|---|---|
| Game, Settler, Match | Win at Settler or harder | OP Gondor snowball |
| Irish Heartbeat | Win at Chieftain or harder | ^ |
| Warlording Over Others | Win at Warlord or harder | ^ |
| Machiavelli's Great Work | Win at Prince or harder | ^ |
| The Divine Right of Kings | Win at King or harder | ^ |
| Emperor's New Groove | Win at Emperor or harder | ^ |
| 12 Labors of Hercules | Win at Immortal or harder (no Deity-only achievement exists) | ^ |
| The Test of Time | Win with an Ancient Era start | default start era — free with any win |

**Strategy:** one comfortable Immortal (or Deity) game on Middle-earth clears the
entire difficulty ladder at once. Difficulty does not change the map's OP Gondor
homeland, so the only difference from Settler is AI aggression — safe with 90k gold
and 3 extra units.

**Victory-type wins (separate games — one each, any difficulty):**

| Achievement | Requirement | Enabler |
|---|---|---|
| Mission to Mars | Science victory, any leader | campus battery + home production |
| Buying Your Blue Jeans and Listening to Your Pop Music | Culture victory, any leader | theater square + gov-plaza template + early wonder tempo |
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
| **Ten Commandments** | Win a regular game on a **Large Map** | set the map-size dropdown to **Large** in Advanced Setup (the script returns the fixed 106×66 grid regardless); confirm the in-game size label at T016 |
| **Voyage of the Mayflower** | Found or conquer a city on a different continent | found or conquer on **Aman/Valinor** — a distinct Stamped continent a short naval trip west (or any jitter islet) |
| **Eight is Enough** | Win on a **Standard** Map | size dropdown = Standard instead of Large — conflicts with Ten Commandments in the same run (one size per game) |
| The End of the World | Win on a map with Volcanoes | natural wonder Eyja/volcano presence is aesthetic — **volcanoes option** may need enabling; conditional |
| Civ-specific wins | e.g. Varangian Guard (Norway) | only while playing that leader — Gondor play targets generic + Rome-specific columns only |

---

## Anti-recommendations (why these are NOT targets on Middle-earth)

| Achievement | Why not |
|---|---|
| Elcano's Revenge (first circumnavigation) | **impossible on a no-wrap map** — never wraps east↔west |
| Dirty Dozen (Huge map) | the dropdown shows Large; ME grid is fixed via GetMapInitData |
| Island Hopping (Huge Island Plates), maps by type | ME is a custom script, not a vanilla map type |
| After Antiquity / Out of the Dark Ages / Renaissance Man / Captain of Industry / Modern Major General / Splitting the Atom / Through the Digital Age | need Classical→Information era starts; ME plays Ancient (The Test of Time is the freebie) |
| Scenario achievements (Gifts of the Nile, Vikings/Traders/Raiders, Red Death, …) | scenarios, not map games |
| Game-mode achievements (Secret Societies, Heroes, Apocalypse, Dramatic Ages, Monopolies, Ley Lines) | modes are locked OFF per spec — ley lines explicitly disabled |
| Civ-specific wins for leaders not in the game | competitive Ai picks the mapped set; only those civs appear | 

---

## How to run a clean achievement game

1. In-game → Advanced Setup → Map: **Middle-earth**, size **Large** (Ten
   Commandments) → 8 players, Ancient era, all game modes OFF (incl. **ley lines**),
   difficulty Immortal or Deity.
2. Turn 0: verify 90,909 gold + Warrior/Scout/Builder in `Logs/lua.log`
   (`MiddleEarth: granted …` lines) — human only, AI untouched. Verify the faction
   force lines (`MiddleEarth: forced CIVILIZATION_* to (x,y)`).
3. Victory ladder: pick Science/Culture/Domination/Religious/Diplomatic per run;
   Mayflower via any cross-sea settle/conquest on Aman.
4. After each win: confirm the Steam achievement fired (see eligibility caveat).