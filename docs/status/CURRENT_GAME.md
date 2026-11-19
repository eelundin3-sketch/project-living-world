# Current game guide

Updated 2026-11-16. This guide describes the working game. For older versions of
a feature, see [Decisions](../design/DECISIONS.md) and the [Changelog](CHANGELOG.md).
For launch instructions and the keyboard map, see the [README](../../README.md).

## A first visit to Alder Hollow

A new game starts with **10 residents in Alder Hollow**, plus the player.
Reedbank starts with its own 10 residents. Existing saves keep their resident
identities and population. The compact HUD reports Alder Hollow's local count.

1. Walk out to the square. The **Timber** and **Provisions** stalls have striped
   awnings. Approach a counter from the front and press **F** to trade. The stall
   lists what it handles, how much it has, and the buy and sell price per unit.
2. Follow the supply chain. Gatherers deliver logs to the warehouse. The sawyer
   brings up to four batches' worth of inputs to the workshop rack, works several
   batches at the saw, and carries finished stock to the timber stall when it
   needs planks. Other loads go to the warehouse, where builders can collect them.
   The provisions stall starts with a transfer of food and medical supplies
   from the settlement warehouse and accepts player sales.
3. Enter a building through the south doorway. Walls, furniture, counters, the
   saw, and stock racks occupy real cells. The saw and rack have separate
   approaches, and the middle of each room is left open for circulation.
4. To operate the saw yourself, bring logs, equip them from **I**, and press **F**
   near the saw to load them. With empty hands and a free operator position, press
   **F** to begin a batch. Step away or press **F** again to stop. Finished
   products can be collected with **F**.
5. Watch a construction site. Materials go to the central pile first. The
   builder picks up material, walks beside the target, works while the piece
   builds up, then returns to the pile. New sites build walls, floors, doors,
   and roof tiles in that order. Completed buildings show their interiors
   in cutaway.
6. Press **H** for a selectable silhouette, health meter, and injury list.
   Right-click an injury for treatment. Bandages and antiseptic come from
   inventory. Moving interrupts a treatment before it consumes supplies.

## Trades, households and gardens

- **Rye.** The fields and every household garden grow rye in three game days. Hold
  the crop in view while it grows: it greens, lengthens, forms ears, turns gold and
  finally droops when ready. A farm crew harvests ripe fields; you can also press
  **F** at a ripe field. Grain goes to the storehouse, the baker turns it into food
  for the provisions stall and storehouse.
- **Trades.** Open a resident's inspector to see their occupation. Woodsmen only fell
  trees, farmers only work fields, the baker and the plank maker work at their
  buildings, builders raise homes, and the sheriff patrols the square.
- **Home life.** Each home has a pantry and a garden beside it. Residents tend the
  garden in the morning (06:00-07:30) and evening (17:30-19:30), then go back to
  their trade. Hungry residents eat at home first. Adults pair off and have
  children while there is room.
- **You.** E eats, Q drinks at a well barrel, and F at the sheriff's office rack takes a
  shotgun. X equips it and R reloads. Hold right mouse to raise the shotgun, then
  press left mouse while aiming to fire. It stays in your hands as you walk.
  The top-left circles show how you are doing.

## What is stored and where

| Data | Location | Backup and recovery |
|---|---|---|
| Source, art, game data, tests, and written documentation | This project folder. Use the maps below to find the authoritative files. | Back up the project folder or use version control. Files in your working folder may include changes that have yet to be committed. |
| Runtime game and previous save | Godot `user://project_solo.save` and `user://project_solo.save.bak` | Press **F5** in the running game to save. A subsequent successful save retains the prior file as `.bak`. **F9** checks the main file and falls back to a valid backup. |
| Remapped movement keys | `user://controls.cfg` | Back up alongside the game save if you want to restore your movement key bindings. |
| Optional recipe override | `user://recipe.json` | Keep your original JSON if you use one. Active recipe definitions are embedded in saves. |
| Local builds and generated imports | `builds/` and `.godot/` | Rebuild from source with the pinned engine and export templates. Both folders are ignored by Git. |

On macOS the `user://` folder is
`~/Library/Application Support/Godot/app_userdata/Project Solo/`.
Open it with **Finder → Go → Go to Folder**. Back up the files to another folder
after saving. To restore a manual copy, close the game, set aside the present
save files, copy the backup into this folder, then launch and press **F9**.

The save stores simulation state, including resident identities and needs,
inventories and money, jobs, health and stamina, carried goods, recipe and
construction progress, stall stock, time, random streams, commands, and scheduled
journeys. Animation blends and camera framing are live presentation. The file
uses a checksummed Godot binary envelope. Use the original pinned engine when
loading saves. Older supported saves gain the newer layouts where there is room.
An active construction site keeps its existing plan and pile position.

## Source map

| Area | Authoritative code or source |
|---|---|
| Scene, controls, launch and update loop | [app/](../../app), [project.godot](../../project.godot), [simulation kernel](../../sim/core/simulation.gd) |
| Cells, buildings, collision, forestry, weather and routes | [world systems](../../sim/world), [navigation](../../sim/movement), [regional trade](../../sim/economy/regional_trade.gd) |
| Residents, hauling, and exact inventory transfers | [residents](../../sim/entities), [job board](../../sim/jobs), [inventory](../../sim/inventory) |
| Workshop batching, market stalls and construction | [recipe system](../../sim/production/recipe_system.gd), [market](../../sim/economy/market.gd), [planner](../../sim/settlement/planner.gd), [fixture placement](../../sim/world/fixtures.gd) |
| Health, movement controls, treatment and combat | [player systems](../../sim/player), [local combat](../../sim/combat/local_combat.gd) |
| Save format, validation and invariants | [save manager](../../sim/persistence/save_manager.gd), [invariants](../../sim/diagnostics/invariants.gd) |
| Characters, terrain, objects, HUD and sound | [actor rendering](../../view/actors), [world rendering](../../view/world), [interface](../../view/ui), [audio](../../view/audio) |
| Recipes, items, original art and sound files | [content/](../../content), [generation and build scripts](../../scripts) |
| Automated checks and graphics captures | [tests/](../../tests), [validation record](../validation/VALIDATION.md) |

Simulation tiles are 1 m wide. The current region is 384 × 256 m with 64 m chunks.
New lodges are 17 × 14 m, storehouses 17 × 15 m, and workshops 15 × 13 m.
The simulation advances at 10 ticks per second at 1× speed. Views read the same
records used in the headless simulation.

## Visual examples and how to reproduce them

Run the capture scripts with a graphical Godot window. Run tests headlessly.
See the [screenshot gallery](../SCREENSHOTS.md) for examples. All images live under [docs/screenshots](../screenshots).

| Example | Capture |
|---|---|
| [Regional landscape](../screenshots/world-landscape.png), [larger village](../screenshots/village-design.png), [cutaway lodge](../screenshots/room-design.png) | [village design](../../tests/captures/village_design_capture.gd) |
| [Character detail](../screenshots/character-detail.png), [gameplay close-up](../screenshots/character-gameplay.png) | [detail and gameplay capture](../../tests/captures/character_detail_capture.gd) |
| [Character turnaround](../screenshots/character-design.png), [sprint and handling animation](../screenshots/character-motion.gif) | [turnaround](../../tests/captures/character_design_capture.gd), [motion frames](../../tests/captures/character_motion_capture.gd) |
| [Health menu](../screenshots/player-health.png), [inventory](../screenshots/player-inventory.png) | [player panels](../../tests/captures/player_panels_capture.gd) |
| [Object detail](../screenshots/prop-detail.png), [machine](../screenshots/working-machine.png), [stock handling](../screenshots/stockpile-handling.png) | [prop design](../../tests/captures/prop_design_capture.gd), [live fixtures](../../tests/captures/fixture_capture.gd) |
| [Forest harvesting](../screenshots/forest-harvest.png), [workshop production](../screenshots/workshop-production.png), [stall trading](../screenshots/market-trading.png) | [gameplay gallery](../../tests/captures/screenshots_capture.gd) |
| [Rye growth](../screenshots/rye-growth.png), [plaza](../screenshots/market-plaza.png), [office](../screenshots/sheriff-office.png), [shotgun](../screenshots/shotgun-fire.png) | [rye sheet](../../tests/captures/rye_growth_capture.gd), [update capture](../../tests/captures/update_capture.gd), [needs](../../tests/captures/needs_capture.gd) |
| [Tile under construction](../screenshots/construction-progress.png), [market stalls](../screenshots/market-stalls.png) | [construction](../../tests/captures/construction_capture.gd), [live market](../../tests/captures/market_capture.gd) |

The screenshots are snapshots from different revisions. The latest written
behavior and source take precedence if older screenshots show a different layout.
