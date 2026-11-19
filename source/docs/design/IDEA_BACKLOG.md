# Project Solo: idea backlog and build plan

To build any of this later, paste the section you want into a new Claude conversation. Each idea is written to stand on its own.

---

## Context for whoever builds this

- **Game:** Project Solo, a deterministic living-world sim in Godot 4.6 (GDScript). Three towns (Alder Hollow, Reedbank, Dustvale) are joined by roads with signposts. The game already has:
  - families with shared purses, professions, paydays and morning shopping;
  - stall keepers who hurry over, plus haggling;
  - traders between towns;
  - sheriffs who move from cover to cover;
  - bleeding and bandages;
  - high and low cover;
  - sleep, auto-travel and a drawn medieval map;
  - crops, a jail and a shotgun.
- **Code:** all game files are in `source/`:
  - `sim/` holds the deterministic simulation;
  - `view/` holds the drawing, animation and UI;
  - `tests/` holds the test scripts.
- **Rules that must hold:**
  - The sim stays deterministic. Use integer tick maths and the seeded RNG streams (`sim.random_int(stream, lo, hi)`). Derived caches are never saved.
  - Save, load and continue must give the same state hash. The soak test checks this.
  - Money is conserved (`sim/diagnostics/invariants.gd`), and names stay unique.
  - New state fields need safe defaults for old saves.
  - Every new `*_test.gd` must be listed in `scripts/test.sh` (checked by `tools/check_layout.py`).
  - Run the suite from `source/` with `GODOT_BIN=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot sh scripts/test.sh`. All tests must pass.
- **Git:** commit locally only. Don't push, open PRs or merge until the owner asks for "the big push".

---

## Part 1: chosen ideas (build these)

### 1. Carrying weight and encumbrance (size S)
- **In play:** every item has a weight. Above your carry limit you walk slower, can't run, and tire faster. The inventory shows your weight against the limit.
- **Builds on:**
  - `sim/inventory/inventory_store.gd`: add an item weight table and a `weight(s, holder)` function.
  - `sim/movement/pace.gd`: lower the stride gain when over the limit.
  - `sim/entities/needs.gd`: fatigue builds faster when over the limit.
  - NPC carriers (traders, people carrying cargo) can use the same rule.
- **Tests:** an overloaded player moves fewer cells in N ticks and can't run. Save and load keeps the state hash the same.

### 2. Body carrying (size S)
- **In play:** pick up someone who is knocked out or dead, walk slowly, and put them down somewhere. A body put down out of sight (a shed, a bush, behind a building) is never found by witnesses. A body left in the open is found, and the finder reports it.
- **Builds on:**
  - the knock-out state in `sim/combat/brawl.gd`;
  - the sight checks in `sim/entities/fear.gd` and `sim/combat/cover.gd` (`line_clear`);
  - item 1, because a body is heavy and you walk slower carrying it.
  - Add the actions "Pick up" and "Put down" in `sim/player/context_actions.gd`.
  - Add a carry pose in `view/actors/animation_director.gd`.
- **Tests:**
  - A carried body moves with the player.
  - A hidden body isn't reported.
  - A body in the open is reported.
  - A knocked-out person who wakes while carried breaks free.

### 3. People claim their space (size S)
- **In play:** walk into someone's home uninvited and they say "Get out of my house." If you stay, their anger rises. After two warnings, or at night, they call the sheriff, and trespassing becomes a crime.
  - Welcome guests are family, people who like you a lot, and anyone who invited you in.
  - Shops are open during the day only.
- **Builds on:**
  - the household or home building on residents (`sim/entities/households.gd`);
  - speech (`sim/entities/speech.gd`);
  - `sim/law/law.gd` for the new crime "trespass";
  - anger and liking already on NPCs.
- **Tests:**
  - Uninvited entry gets a warning, then anger, then a sheriff call.
  - A guest is welcome.
  - A shop is fine during the day but not at night.

### 4. Your look changes (size S)
- **In play:**
  - Hair and beard grow over days.
  - Clothes get dirty from work, roads and mud, bloody from fights, and wet from rain or rivers.
  - People react to your look:
    - a filthy or bloody look worsens greetings and prices, and the sheriff becomes suspicious;
    - a clean, good outfit helps when haggling.
  - You can wash at a well or bathhouse, pay a barber, and buy clothes from a tailor or stall.
- **Builds on:**
  - `sim/entities/outfits.gd` (outfit data);
  - new player fields `hair_days`, `dirt`, `blood`, `wet` (0–100, integer);
  - `sim/economy/stall_service.gd` `price()` (adds a look modifier);
  - speech greetings;
  - the view draws the player's beard, hair and dirt and blood tint.
- **Tests:**
  - Dirt rises with work and roads.
  - Washing resets it.
  - A dirty player pays more.
  - Old saves load with clean defaults.

### 5. Rain matters to farmers; professions thrive by region (size S–M)
- **In play:**
  - Each town has its own climate:
    - Reedbank: wet, by the river, good for farming and fishing;
    - Alder Hollow: mild, with woods, good for timber and crafts;
    - Dustvale: dry, with rock and ore, good for mining and smithing.
  - Weather is rolled daily per region from a seeded stream.
  - A dry spell ruins crops. Farmers worry, pray, and after a bad season some families move to a town where their trade does better.
  - When a family picks a profession, the region's strengths count.
- **Builds on:**
  - `sim/farming/crops.gd` (growth gets a rain factor);
  - `sim/entities/family_economy.gd` and `sim/entities/households.gd` (moving away and choosing a profession);
  - a new `sim/world/weather.gd`, which pairs with weather visuals later.
- **Tests:**
  - A forced drought lowers the harvest.
  - A starving farming family moves to another town.
  - Money and names are conserved through the move.
  - The weather is the same for the same seed.

### 6. Each town has a mood (size M)
- **In play:** every town has three values, 0–100:
  - **prosperity**, from trade volume, purses and payday wages;
  - **safety**, from crime, killings and outlaws nearby;
  - **loyalty**, from how fair the law and the mayor are.

  These values drift daily. They show on the drawn map (a small seal or icon per town) and come up in "Ask for news". They change prices, how readily people help, and how many people walk the streets at night.
- **Builds on:**
  - `sim/factions/society.gd` and `sim/factions/risk_system.gd`;
  - `sim/economy/market.gd` (trade counts);
  - `sim/law/law.gd` (crime records);
  - the `daily()` hook in households.
- **Tests:**
  - Crime lowers safety.
  - Trade raises prosperity.
  - The values are clamped, deterministic, and the same after save and load.

### 7. Town policies (size M; needs item 6)
- **In play:** each town gets a mayor, chosen from the residents and given a name. The mayor can set:
  - **Curfew:** nobody on the streets after dark. The sheriff warns, then fines.
  - **Trade tax:** a % of each sale goes to the town treasury. Prices rise and prosperity falls slightly.
  - **Gun ban:** carrying a drawn shotgun in town is a crime, and sheriffs confiscate it or fine you.

  The mayor changes policy when the mood shifts, for example a gun ban when safety drops, or lifting the tax when prosperity falls. Policies are posted on a notice board and mentioned in "Ask for news".
- **Builds on:** item 6, `sim/law/law.gd`, `sim/law/sheriff.gd`, `sim/economy/market.gd`, and the town treasury account.
- **Tests:**
  - A gun ban makes carrying a crime.
  - The tax goes to the treasury, and money is conserved.
  - Under curfew, residents are indoors at night.
  - Policy changes follow the mood.

### 8. Towns change hands (size L; needs items 6 and 7)
- **In play:** an outlaw gang lives in a camp in the wilds. When a town's safety and loyalty fall low enough, the gang raids it, and if the sheriffs lose, they take it over.
  - Under outlaw rule:
    - townsfolk either flee to the other towns or stay and pay tribute;
    - the jail is theirs;
    - prices and mood change.
  - Sheriffs from the other towns gather a posse of armed townspeople to win it back, using the cover-to-cover tactics.
  - The player can join the posse, side with the outlaws, or stay out.
- **Builds on:**
  - the cover-cycle engagement in `sim/combat/gunfire.gd`;
  - `sim/law/sheriff.gd` (rosters and posse);
  - item 6 (trigger);
  - item 7 (the outlaws set their own policies);
  - `sim/entities/households.gd` (families fleeing).
- **Tests:**
  - A forced takeover changes the town's controller.
  - Families flee or stay.
  - A posse can retake the town.
  - Determinism and save/load hold through the whole cycle.

### 9. Play as your heir (size L; needs the player to have a family)
- **In play:** when you die, you continue as your spouse or eldest child, and the camera moves to them. You inherit:
  - the family purse;
  - the home;
  - the reputation;
  - the debts and the enemies, so people who hated you also distrust your heir.

  With no heir, a drawn "Last of the line" ending page summarises your life and what became of each town.
- **Before this:** the player needs a family. Pair it with "Marry into a family" from Part 2 (court someone, marry, have children).
- **Builds on:**
  - `sim/entities/households.gd` and `sim/entities/family_economy.gd`;
  - death handling in `sim/combat/brawl.gd` (`kill`);
  - the player id in `s.player`.
- **Tests:**
  - Death switches control to the heir.
  - The heir has the purse, home and reputation.
  - There's an ending when no heir exists.
  - Save, load and continue after inheriting gives the same hash.

### Build order
1. Item 1, then item 2 (quick, and item 2 uses item 1).
2. Item 3, then item 4 (social reactions).
3. Item 5 (weather and regions).
4. Item 6, then item 7, then item 8. These form a chain: mood, then policies, then takeovers.
5. Marry into a family (Part 2), then item 9.

Each item gets its own local commit, with the full test suite passing before the next one starts.

---

## Part 2: other ideas, not chosen yet

★ marks ideas that would improve the game most for the effort.

**People and talking**
- ★ **Memory of you:** people remember what you did, and it changes prices, greetings and help.
- ★ **Gossip and rumours:** news spreads from town to town, sometimes exaggerated.
- **Relationships between townspeople:** friends, rivals and couples.
- **Life cycle:** aging, births, weddings, funerals and inheritance.
- **Weekly rhythm:** a rest day and a market day.
- **Idle life:** sweeping, chopping wood, chatting, children playing.
- **Named characters with small story chains.**
- **Animals:** horses, livestock, dogs, wildlife.
- ★ **Dialogue choices with tone:** friendly, firm or threatening.
- **Persuade, bribe or intimidate.**
- **Requests and favours** based on what the sim says people really need.
- **Hire people:** guards, farmhands, guides.
- **Rent, then buy, a home.**
- **Marry into a family** (needed for item 9).
- **Gifts with likes and dislikes.**

**Economy**
- ★ **Prices that follow supply between towns.**
- **Your own stall.**
- **Caravans to escort or rob.**
- **Loans and debts.**
- **Player crafting.**
- **Item quality and wear.**
- **Seasons and harvest.**
- **Food that spoils.**
- **Hunting with pelt quality.**

**Law, crime and stealth**
- ★ **Witnesses, evidence and wanted posters.**
- **Bounties.**
- **Outlaw gangs and posses** (partly covered by item 8).
- **Trials and bail.**
- **Jail escape.**
- **More weapons.**
- **Stealth with light and noise.**
- ★ **Visible view cones and noise rings.**
- **Distractions.**
- **Disguises.**
- **Investigating a crime with clues.**
- **Hit reactions.**
- **Surrender and mercy.**
- **Non-lethal takedowns.**

**World**
- ★ **Weather:** rain, fog, snow and mud (pairs with item 5).
- **Places between towns.**
- **Homesteads or a fourth town.**
- **Fire.**
- **Rivers and bridges.**
- **Mining, foraging and fishing.**
- **Buried caches and treasure maps.**
- ★ **An event storyteller** that paces incidents.
- ★ **Pre-simulated history (20 years) and a legends book.**
- **Chance encounters on the road, as story cards.**
- **Festivals with contests.**
- **Mood breaks.**
- **Illness spreading.**
- **Elections for sheriff and mayor** (pairs with item 7).
- **Rival factions.**
- **Being beaten and robbed instead of dying.**
- **Your own camp.**
- **A horse bond.**
- **Cold and shelter.**

**Player**
- ★ **Starting stories.**
- **Reputation per town.**
- **Skills that grow by use.**
- **Journal.**
- **Long goals.**
- **Inner thoughts.**
- **Scars become traits.**
- **Ending summary pages.**
- **Learning to read.**

**Animation, visuals and sound**
- ★ **Blended walk, run and idle.**
- **Interaction animations.**
- **Combat animations.**
- **Secondary motion.**
- **Mood icons.**
- **Footprints.**
- **Carts.**
- **Camera feel.**
- ★ **Night lighting with lamps.**
- **Seasonal colours.**
- **Particles.**
- **Richer interiors.**
- **Bullet holes.**
- **Map markers and routes.**
- ★ **Adaptive music.**
- **Town and nature ambience** (varied, not looping).
- **Mumble voices.**
- **Footsteps by surface.**

**Interface and technical**
- ★ **A first-hour tutorial.**
- **Settings.**
- **Save slots and autosave.**
- **A parchment inventory.**
- **Tooltips.**
- **A notice log.**
- **Controller support.**
- **Accessibility.**
- **A Windows build.**
- **A first GitHub Release.**
- **Crash-safe saves.**
- **Room for more towns and people.**
- **Data files for items and names.**
