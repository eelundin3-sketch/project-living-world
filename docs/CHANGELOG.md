# Changelog

## Title screen, sheriffs, backpack, beds, crouching, forests and sun shadows — 2026-11-16

- **Title screen.** Launching the game opens a menu (Start Game, Options, Quit
  Game) over the live world while the camera drifts slowly across the map.
  Start fades the menu, flies the camera down to the player and zooms in; you
  take control once it lands. Options is a placeholder layout (not wired up).
- **Crouch (X).** Hips sink, the trunk leans in and the arms come up; walking
  crouched is a slower, shorter, quieter stride. Crouching eases down and back up
  instead of snapping. Sprinting stands you up. Robbing a sleeper while crouched
  doesn't wake them; standing up, they wake and fight. The shotgun no longer uses
  X (ready it from its hotbar key).
- **Idle life.** People standing still breathe and shift their weight.
- **Rifle low ready.** With the gun equipped but not aimed, the stock sits at the
  right side of the chest and the barrel angles down across the body.
- **Backpack and inventory.** The player wears a backpack. Opening the inventory
  makes them kneel, swing the pack onto the ground, open it and dig through it;
  closing packs it up, puts it back on and stands them up.
- **Sheriffs.** Each sheriff is called "Sheriff <surname>" and wears a dark
  cattleman hat, a leather vest with a gold star, and carries a slung shotgun.
- **Beds.** Sleepers lie centred on the mattress under the blanket; they sit on
  the edge, swing in and lie back, and get up the same way in reverse.
- **Forests.** Around 1,070 trees now form real woods around Alder Hollow and
  Reedbank, kept clear of houses, doors, workshops, the square, fields and roads.
  Old saves keep their timber (moved away from buildings, not added).
- **Sun shadows.** Trees, buildings, the iron rock, carts and people cast
  shadows from the sun: long to the left in the morning, short and to the north
  at noon, long to the right in the evening, gone at night. No shadows fall on
  building floors (they are under a roof).

## Health window, bruises and smoother reactions — 2026-11-16

- New health window: vitals across the top (health, pain, bleeding, stamina),
  your own figure with wounds marked where they are, injury cards with status
  pills, and a detail panel with large treatment buttons that show supplies and
  say why an action is unavailable. While treating, a progress card replaces the
  buttons and the figure acts it out.
- Self-treatment is animated in the world too: the hurt arm is held up while the
  other hand winds the bandage on (or dabs antiseptic, or unwinds a dressing);
  leg wounds make the character crouch, head wounds bring both hands up.
- Bandaging needs a bandage in the inventory, and nothing can be treated while
  unconscious (being knocked down also interrupts a treatment).
- Punches are blunt damage: they bruise the body part they land on (mostly the
  face and body) instead of cutting; only a blow to the face can draw blood.
- Hit and stagger reactions snap the trunk and head back with the feet planted
  instead of rotating the whole figure. People who die now fall forward with the
  full fall; felled trees creak over, accelerate, and bounce once on landing.
- Lying and falling legs are kept straight and parallel.

## Forward falls in eight directions — 2026-11-16

- Every fall is now a forward fall along the direction of the blow (or of the run
  that ended in a collapse): a knocked trunk, a stumbling step, knees giving way,
  arms thrown up over the head, hands hitting the ground, the chest landing with a
  small rebound, then lying face down with the arms stretched out overhead.
- Getting up is a full sequence: hands under the shoulders, a push-up, knees drawn
  in to hands-and-knees, sitting back to kneel, one foot planted, and pushing up
  off the front knee to stand on the same spot.
- The poses are 3D keyframes projected along the fall direction, so the same
  animation plays correctly in all eight directions; the head, coat and boots turn
  with the trunk instead of the whole figure folding over like a flat cutout.
- The fall now takes 1.4 s and the get-up 2.6 s (was 1.0 s and 2.0 s).
- Review sheets: `docs/screenshots/animation-falls.png` and
  `docs/screenshots/animation-getup.png` (`tests/fall_sheet_capture.gd`).

## Fights, stamina and inventory — 2026-11-16

- A shove and a punch now irritate equally. The first offence sends the villager
  after the player to shove them down and walk away; a second one (within about
  five minutes) is answered with a beating that ends when the player's health
  bar falls below 20%. The health bar now weighs head and torso more heavily.
- Villagers fall unconscious when their health drops below 20% (no more
  punch-count rule). Falling is one continuous stumble-and-drop animation, and
  the get-up is a staged push-up, kneel and stand.
- Bleeding drops blood on the ground until bandaged; villagers' cuts can be
  bandaged from the click menu.
- Hold Shift to run a click-to-walk route or the walk to an action target.
  Double left-click open ground to set a route (double right-click still works).
- Stamina: at the orange part of the bar the run turns laboured and slower; at
  zero the player falls forward, gets up winded, and cannot sprint again until
  stamina is back to halfway. Heavy breathing plays until then.
- The inventory is a 6x6 grid with hat, shirt, trousers and shoes squares on
  its left for quick dressing and undressing.

## Walking foot roll — 2026-11-16

- Boots land heel first, flatten, then roll over the toes on push-off. The
  shin follows the boot through the ankle bend.

## Walking stride — 2026-11-16

- Steps land closer to the hips, pass beneath the body and extend behind it
  before the heel lifts. The knee bends as the foot swings forward.

## Shorter shotgun and lowered carry — 2026-11-16

- Shortened the shotgun artwork on the character by 25%.
- The equipped shotgun stays in both hands during movement. Hold right mouse to
  raise it and press left mouse while aiming to fire. Releasing right mouse
  returns to the lowered pose. Movement and recoil can play together.

## Shorter neck and stronger running kick — 2026-11-16

- Lowered the head and shortened the visible neck, including its health-screen selection.
- Sprinting now extends the trailing leg farther back, raises the recovering heel,
  and returns the foot smoothly to the next landing without a cycle-wrap jump.
- Refreshed character screenshots and the motion preview; rebuilt both Mac apps.

## Drawn character redesign — 2026-11-16

- Rebalanced the figure with longer legs, a defined waist, visible neck, slimmer
  sleeves and relaxed hands beside the body. Foot anchors and world collision are unchanged.
- Replaced overlapping oval limbs with curved cloth silhouettes and restrained
  cel shading. Elbows and knees use fabric folds; tightly folded limbs keep a
  valid joined outline through work, combat and sprint poses.
- Redrew the face with almond-shaped eyes, brows, a softer profile, swept hair,
  ears and small facial details. Added a shaped hat crown, hatband, stitched brim,
  shirt collar, waistcoat pockets, buttons, back strap, boot shafts, soles and laces.
- The same artwork is used by the player, villagers, raiders and the health diagram;
  clothing colours and removable pieces still follow the character's actual outfit.
- Refreshed the turnaround, motion preview, health/inventory screenshots, and added
  a [detail sheet](screenshots/character-detail.png) and
  [gameplay close-up](screenshots/character-gameplay.png).
- Added a headless character-art regression test to the standard test runner.
  macOS release and debug exports rebuilt; Windows/Linux exports not rebuilt.

## Rye, households, trades, shotgun, needs and names — 2026-11-16

- **Farming.** Fields and household gardens grow rye through six visible stages
  (newly sown, early growth, intermediate growth, ripening, fully grown, ready to
  harvest). Height, thickness, colour and the bearded ear change continuously with
  the crop's growth; the ready stage droops and shows a sheaf. A crop takes three
  game days. See `docs/screenshots/rye-growth.png`.
- **Trades.** Demand is derived from what is around a settlement, not fixed: farmers
  follow fields and the food need, a sheriff follows population and road danger,
  woodsmen and plank makers follow trees and the sawmill, a baker follows rye and a
  bakery, miners and a blacksmith follow ore and a forge. Reedbank has iron outcrops,
  a bakery and a forge; Alder Hollow has no ore, so it gets no miners.
- **Households.** Households share a pantry (the home's inventory) and a garden beside
  the house, sized by household and free space (6-28 cells; trees are moved, not
  destroyed). Residents tend it each morning and evening alongside their trade, eat
  from the pantry first and bake rye at home (3 rye -> 2 loaves; the village baker
  gets 4 loaves from 3). Adults pair off, move into a home with room, and have
  children while there is housing and food; children grow up after eight days.
- **Bread chain.** Farm crew harvests rye -> warehouse -> baker -> provisions stall.
- **Shotgun.** Pump shotgun with ready/stow (X), shell-by-shell reload (R), fire
  (aim with right mouse, then click), recoil and muzzle flash, a pellet spread and
  surface effects: small blood flecks on a hit, dust on ground, chips on walls and
  timber, bark on trees, sparks on stone. Stowed, it hangs on the back. Sheriffs
  carry one on a sling and take the ranged defender slot in a raid.
- **Sheriff's office** (each settlement) holds a wall weapon rack stocked with
  shotguns and shells; press F at it to take or return them.
- **Movement.** W+A, W+D, S+A and S+D move diagonally; a diagonal never cuts a
  blocked corner.
- **Markets.** The plaza now has cobbled paving, a well, a notice board, bunting,
  hitching rail and parked cart, with barrels, crates, grain sacks or timber stacks
  at each stall. Drink at the well with Q.
- **Placement.** Furniture has four orientations (0 up, 1 right, 2 down, 3 left; a
  bed's orientation is its head). New homes auto-place beds with the head flush to a
  wall and as many sides as possible along walls. T rotates the nearest item, G moves
  it to its best wall spot; `place_furniture` places one at an exact cell.
- **Characters.** Cartoon-inked figures with heavier outlines and lighter tan hats.
  Each character faces one of eight directions (up, down, left, right and the four
  diagonals); the drawn heading snaps to the nearest 45 degrees. See
  `docs/screenshots/character-design.png`.
- **Bottom bar.** A four-slot hotbar (keys 1-4) sits bottom centre with the stamina
  bar above it and the inventory (I) and health (H) buttons beside it. Assign items
  from the inventory screen (buttons 1-4 on each row); using a slot readies the item
  (the shotgun is raised, anything else is held) and using it again puts it away.
  Bottom right shows the day and hour with slower / x1.0 / pause / faster controls
  (speeds 1, 2, 3 and 5; `,` and `.` also change speed). Speed keys moved off 1-3.
- **World look.** Darker, denser forest, reddish earth around the settlements and
  pinker trunks, following the supplied top-down references (`world-overview.png`).
- **Walking and running.** Fixed the "teleport" while moving: diagonal steps are 1.41
  cells long but the drawn figure followed at straight-line speed, fell behind and was
  snapped forward. It now keeps a constant pace and only catches up on gaps beyond one
  cell, and diagonal walking takes one tick longer per step. The sprint is rebuilt with
  a real run cycle (two-bone legs with a high heel recovery and forward knee drive, flight
  phases, forward lean, arms swinging opposite the legs with bent elbows) and it eases in
  over about 0.3 s when sprinting starts and out over about 0.5 s after Shift is released,
  ending in a braking stance (lean back, wide feet, arms out). See
  `docs/screenshots/animation-run-cycle.png` (`tests/run_sheet_capture.gd`).
- **Scale.** Characters are drawn at half size and the default zoom is 2x (maximum 5x),
  so people are in proportion to doors, furniture and trees; name tags, health bars and
  effect heights were rescaled to match.
- **Map view (M).** M, or the map button beside the hotbar, leaves the character and frames
  every settlement with town names and a "You" marker; WASD pans, the wheel zooms (down to
  0.06x), M returns to the character at the previous zoom. Zoomed out, trees become simple
  canopies and per-object nodes are dropped, so the map stays smooth.
- **HUD.** The top-left info panel (title, counts, speed buttons) was removed. The "F: interact"
  prompt and short messages now appear as a line above the hotbar; the observer tools are still
  on F3. Characters are 25% bigger than in the previous change.
- **Performance tab (F4).** A tab in the top-right corner shows fps; click it or press F4 for
  frame-time average/percentiles and a frame graph, draw calls, objects, nodes, memory,
  simulation tick cost and rate, and entity/sorted-object counts. Record writes one CSV row per
  second to `perf_log.csv` in the save folder.
- **Minimize.** The inventory, health and trading windows have a Minimize button: the window hides,
  play continues, and a tab at the bottom left (or its hotkey) restores it.
- **Building.** Each tile now takes 1.6 s (was 1.0 s) and is animated as a sequence: lift the board
  into place with both hands, three hammer blows (cock back, strike, rebound) with the other hand
  steadying the nail, then lower the tools and check the work. Hammer height follows the part being
  built (floor low, wall chest, roof overhead) and the sound is timed to each blow. See
  `docs/screenshots/animation-building.png`.
- **Fist fights.** A punch now makes a sound, leaves blood on the ground (pools and flung drops that
  darken as they dry and fade over about 2.5 game days) and hurts a little (6 damage; a beating never
  drops anyone below 20 health). Punched villagers get angry (a red "!!" over their head), stop what
  they are doing and come after you, throwing punches and shoves; they give up if you get away, they
  cool off, or you are on the ground. Five punches in quick succession knock someone out: they fall,
  lie still for about 40 seconds (with "z z"), then get up. A shove drops them to the ground for a couple
  of seconds before they climb back up. The same applies to you: their punches injure you (sometimes
  cutting you), a shove puts you on the ground, and too many blows knock you out; you cannot act until you
  are back on your feet.
- **Falling.** New fall, lying and get-up animations with arms flung out, and six lying styles chosen
  by how the blow lands: on the back, face-down, on the side, sprawled, curled up and slumped; the
  head points the way they were pushed. See `docs/screenshots/animation-falls.png`
  (`tests/fall_sheet_capture.gd`). New sounds: punch, shove and a body thud (`scripts/generate_audio.py`).
- **Engaged fights.** A punched villager runs at you, holds a fighting stance between blows and
  keeps swinging until they cool off, you get away, or someone is down; a sheriff nearby joins in to
  break up the fight.
- **Felling trees.** Chopping (F) now fells the tree: it topples with an animation (leaning either
  way) and lies on the ground with its wood. Press F again at the fallen tree to gather the logs, and
  when the last log is taken only the stump remains (a stump sprouts a new tree after a week).
  Woodsmen work the same way: the first chop fells the tree, then they haul the wood.
- **Sleeping.** Tiredness builds more slowly, and at night villagers go to their own bed in their
  home (the lodge has six beds, other houses three; extra people share) and lie on it until morning,
  in the pose that matches the bed's orientation; a daytime nap happens only when exhausted. Being
  punched or hungry wakes them.
- **Dustvale.** A third town to the south, in dry pink-brown country with thin cover, few trees (dead
  trunks and a few in autumn leaf), dry grass and a road up to Alder Hollow. It has a lodge with beds
  and a garden, a storehouse, market stalls with a plaza, a bakery, a sheriff's office with a weapon
  rack, a rye field, and ten residents with trades. See `docs/screenshots/dustvale-town.png`
  and `map-three-towns.png`. It trades only with itself for now (the caravan still runs Alder Hollow
  to Reedbank).
- **Click-to-interact menu.** Left-click a person or thing to open a menu of what you can do to it
  (F stays the fast way). Greyed rows say why something is unavailable. If you are not close enough,
  the character walks over and then does it (moving by hand cancels). Options by target: a villager
  (talk/trade, punch, shove, look at); someone knocked out or asleep (loot, help up, wake up); a
  tree (chop down, or gather wood once fallen); a farm (harvest); the iron rock (mine); dropped items
  (pick up everything or one kind); a stall or storehouse (trade); the sheriff's rack (take/return the
  shotgun); workshops (use/collect); and yourself (eat, drink, inventory, wounds). Looting takes their
  goods and coins. See `docs/screenshots/context-menu-rock.png` and `context-menu-person.png`.
- **Iron rock.** Dustvale has a large iron-bearing rock to the east (600 ore) that blocks its ground.
  Mine it with the menu or F (a pickaxe animation, 5 ore per swing); Dustvale also has a forge and a
  miner who hauls ore. See `docs/screenshots/iron-rock.png`.
- **Click-to-walk.** Double right-click a square and the character finds the shortest route and walks
  there (a pulsing ring marks the goal; a blocked square goes to the nearest free one; moving by hand
  cancels).
- **Five villagers per town.** Every town (Alder Hollow, Reedbank, Dustvale) starts with 5 residents; a
  town of three or more now gets a sheriff.
- **Chests and looting.** Every chest in a house or workshop is a real container: click it (or press F)
  to see what is inside and take things. Searching someone who is knocked out or asleep opens the same
  window and shows what they carry and what they are **wearing**: take any piece, or "Take & wear" to
  dress yourself in it, plus their coins. Stripped people are drawn in pale underclothes, bare feet, or
  without a hat, vest or shirt. Press C (or click yourself > Clothing) to change your own clothes. A
  robbed person remembers: they come round furious and go after you. Clothes are ordinary inventory items
  ("shirt:2"), so the conservation checks cover them. See `docs/screenshots/loot-window-person.png`,
  `loot-window-chest.png` and `outfits.png`.
- **Hotbar selection.** Exactly one slot is always selected (slot 1 to begin with). Pressing a slot
  selects it and puts its item in hand (a shotgun is raised); pressing the same slot again keeps it
  selected, and only choosing another slot changes the selection. A weapon you pick up (rack, chest,
  loot, ground) goes straight into the first free slot, and leaves it when you put the weapon away.
- **Slung shotgun.** A stowed shotgun is now large (about as tall as the character), slung over the
  right shoulder with the barrel up past the shoulder and the stock by the opposite hip, and keeps the
  same on-screen size whichever way the character faces. See `docs/screenshots/shotgun-slung-all-facings.png`.
- **Character art.** Much more detailed figures: thinner, softer outlines with shaded limbs, a larger
  head with ears, brows, eyes (white, iris, pupil, glint), nose, mouth, blush and swept fringe; hair
  colours and eye colours vary by person; a shirt collar, shoulder seams, sleeve cuffs and hands with
  thumbs; knee patches, trouser cuffs and laced boots with soles. See `docs/screenshots/character-design.png`.
- **Health window.** It now shows your own character, wearing your current clothes, standing front-on,
  instead of the generic silhouette. Wound tints, bandage wraps and bleeding marks are drawn over the
  body; hover a part to find it, click to select, right-click to treat. Zones are measured from the
  character's joints. See `docs/screenshots/player-health.png`.
- **Names.** Every person (residents, children, the player, raiders) gets a unique
  American/British first and last name, unique across the whole map and saves, shown
  on a name tag beneath them.
- **Needs and indicators.** Hunger, thirst, tiredness, pain, bleeding, stress, mood,
  wet and cold. Circular indicators in the top-left corner appear only while a
  condition applies; the ring shows severity 1-4 and hovering names the condition and
  gives a hint. E eats, Q drinks (at a well barrel).

## Current village, artwork, and handoff — 2026-11-16

- Alder Hollow now starts with ten residents. Reedbank remains a separate town.
- Furniture occupies real tiles along room edges. The saw and stock rack have
  separate approaches, and the sawyer works through a bulk input load before
  carrying finished stock to market or the warehouse.
- Timber and provisions stalls own their stock and funds. Press **F** at a
  counter to buy or sell. Older saves receive stalls once without duplicating
  stock or cash.
- New construction uses the larger measured plans. Builders stage supplies in
  the middle, build walls first, and return for material after every tile.
  Terrain generation reserves starter expansion plots for the larger homes.
- Regional terrain blends sand and gravel into the ground. The original props,
  2D characters, and cutaway rooms support close zoom. Character transitions
  blend between poses, including a separate sprint cycle.
- The health window now shows an injury silhouette and right-click treatment.
- The [current game guide](CURRENT_GAME.md) consolidates behavior, source locations,
  save and backup instructions, and runnable demonstrations.

## M0 / Task 001 — 2026-11-14

- Added Godot project and Main scene with placeholder ground, observer camera,
  WASD movement, bounded wheel zoom and diagnostic HUD.
- Pinned Godot 4.6 stable and verified official build `89cea1439`.
- Copied all four supplied blueprint documents and adopted contributor rules.
- Established application, simulation, view, content and test directories.
- Added dependency-free headless smoke tests, Git ignores, README and decisions.
- Validation: headless import and smoke tests passed (exit 0); graphical renderer
  initialized without startup errors. Visual inspection timed out; manual
  appearance/physical keyboard verification remains pending.
- M1 and later simulation/gameplay milestones are not implemented.

## Integrated prototype — 2026-11-14

- Implemented the deterministic kernel and seeded physical world, then resident
  needs, job reservations, local navigation, inventory transactions and save/load.
- Added real sawmill labour and input/output hauling, material-funded housing,
  local trade, a second settlement and scheduled cargo-owning merchants.
- Added chunk/fidelity handling, batched distant work, households, bounded social
  memories, policy/treaty changes, migration, guards and non-lethal danger.
- Replaced the bootstrap view with an inspectable game, player movement, trade
  controls, travel, observer tools, larger text and remappable movement.
- Added checksummed saves and backup recovery, v1 migration, external recipe data,
  11 regression suites, benchmarks, CI and six desktop export configurations.
- Actual validation and remaining platform/scale limits are recorded in
  VALIDATION.md and IMPLEMENTATION_STATUS.md; supplied design documents are intact.

## Character graphics update — 2026-11-14

- Replaced resident/player dots with original outlined frontier figures inspired
  by the supplied visual reference: earthy clothing, hats, faces, boots and skin
  tone variations, plus walking poses, carried goods and occupation details.
- Kept character artwork in a presentation-only drawing helper; simulation data
  and saved identities are unchanged. Character picking follows the taller art.
- Verified native rendered screenshot and UI smoke test; rebuilt desktop exports.

## Map art and enterable buildings — 2026-11-14

- Restyled ground, paths, trees/stumps, rocks, farms/crops, storage crates, barrels,
  carts, construction sites and all buildings in the characters' outlined earth palette.
- Replaced building icons with multi-cell cutaway rooms: homes have beds/tables,
  stores have supplies, and sawmills have workbenches. Furnishings are decorative.
- Added authoritative solid perimeter walls and open south-facing door cells.
  Player and NPC navigation respects walls; footprints persist in save snapshots.
- Construction reserves a full footprint and a clearance margin. Initial villages
  have more space between buildings; earlier saves gain missing building layouts
  while retaining entity identities and inventories.
- Added building entry/wall/navigation/save-upgrade tests and an actual indoor
  player capture at docs/screenshots/interior.png. The regression runner now has
  12 suites. Desktop builds are regenerated for this update.

## Forests, animation and audio — 2026-11-15

- Increased the initial forest from 78 to 420 spaced trees across both settlements,
  preserving road/building clearings and upgrading older saves once.
- Added distance-based walking, visible cargo, axe strikes, saw strokes, building
  motions, pickup/drop bends, wind sway and falling trees. Motion reads simulation
  state and pauses with it; movement and camera following are interpolated.
- Gathering now uses explicit pickup/deposit phases around atomic inventory
  transfers. Sawyers work inside their mill; other haulers pause to handle goods.
- Added ten original synthesized sounds, positional mixing, surface-dependent
  footsteps, contact-timed work cues, wind, saved sound toggle and reduced motion.
- Added animation unit and actual-scene integration tests (14 suites total), and
  made the runner reject runtime errors even when a test exits successfully.

## Reference-inspired scenery — 2026-11-15

- Added original seeded earth textures and four layered green canopy variants,
  warmer wooden floors and light timber walls, collar and belt details.
- Replaced per-frame canopy polygon construction with imported reusable textures;
  existing wind, harvesting, carrying and tree-fall presentation is retained.
- Assets are generated by scripts/generate_scenery.py; no screenshot assets copied.

## Village streetscape and figure redesign

- Replaced oval coats with outlined tailored silhouettes; enlarged figures, added
  paired eyes, hair, collar and belt details while preserving action-driven poses.
- Replaced flat wall strips with shaded beveled cutaway sections aligned to existing
  collision cells and doors. Added lamps, chairs, banded chests and boardwalk porches.
- Added open storehouse squares, edge benches and differentiated home/workplace
  frontages. Existing building positions and simulation ownership are retained.
- Added `tests/village_design_capture.gd`, a runnable unobstructed village preview.
  Building/navigation and live animation suites passed; native capture inspected.

## Comprehensive reference-led redesign — 2026-11-15

- Replanned the initial settlements and construction plots around a public lane,
  storehouse square, domestic plots and a separate workshop/farm side.
- Expanded homes to 11×9 cells, warehouses to 13×10 and mills to 13×8. Added
  authoritative internal walls and two-cell passages; every room is reachable.
- Rebuilt furnishings with beds, pillows, blankets, rugs, tables, place settings,
  shelves, stoves, saw benches, chairs, banded chests and shaded supply crates.
- Added original grain-textured planks, grassy verges, layered paths, lamp halos,
  and time-of-day tinting. F8 toggles compact HUD status hints; time/speed controls
  remain visible.
- Reworked figure proportions, segmented arms/legs, coat silhouettes, faces, hair,
  hats and boots, retaining tool and cargo animations.
- Older saves receive a one-time architecture reflow preserving goods and IDs.
  New architecture regression checks every room, wall, overlap and upgrade replay.
- New runnable close-up and mature-village captures live under tests/; no assets
  or source code were copied from the reference game.

## Physical machines and stock handling

- Added solid saw benches and stockpile footprints, reachable interaction positions,
  navigation-aware worker routing, and stockpiles for construction materials.
- Removed decorative stand-in logs and machines from work areas. Real building
  inventory drives rack quantities, machine input and finished planks on the outfeed.
- Added independent blade rotation, input feed and sawdust during attended work;
  disabled/interrupted machines stop and pause freezes machine/item animation.
- Actual committed transfers animate between worker hands and the relevant storage
  slot. Presentation cannot create goods; saves do not replay historic transfers.
- Existing saves gain fixtures once, preserving inventory and relocating any actor
  standing in a new solid footprint. Rendering avoids interpolating feet through
  solid cells at accelerated simulation speeds.
- Added fixtures_test.gd and fixture_capture.gd; the runner now has 16 suites.

## Player controls, health and movement

- Added I inventory, F contextual drop/pickup/gather/work/talk, and H body health.
  People trade their own inventories and real money; nearby stores use existing
  markets. Physical transfers, selected hand stack and medical supplies are saved.
- Added 17 selectable body parts, bleeding, pain, dirty/clean bandages, infection,
  timed bandaging/cleaning, natural recovery and movement/work effects from injury.
- Added Shift sprint with a distinct run gait, a visible stamina bar, deterministic
  stamina use per sprint step and regeneration after release.
- Mouse wheel and trackpad pinch zoom work across the entire window, including
  when inventory, health or interaction panels are open.

## Metric tiles, incremental building and compact HUD

- Defined each integer world cell as 1 m (24 px at default zoom). Ground, interior
  floors and walls now render as visible block/tile units on that measured grid.
- Construction collects deliveries at its central site fixture, then spends material
  and places floor, wall, door and roof tiles in sequence. Walls become collision
  cells as they are built; the doorway stays open until the structure is finished.
- Replaced the persistent inspection/sidebar/footer layout with a compact upper-left
  clock, stock and stamina strip. Pause, 1×, 2× and 3× buttons stay visible; tools
  open only when requested.
- Removed character ground shadows and the circular selection marker. Walking now
  has clearer alternating knees/feet, opposing arm swings, torso sway and bounce.
