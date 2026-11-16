# Gameplay screenshots

These captures come from the game running in Godot. Click an image for the
full-size version. Capture scripts live in `tests/*_capture.gd` and run with a
graphical display, for example `godot --path . --script res://tests/menu_capture.gd`.

## Title screen

| Title over the live world | Options (placeholder) | Flying down to the player |
|---|---|---|
| [![Title screen](screenshots/menu-title.png)](screenshots/menu-title.png) | [![Options](screenshots/menu-options.png)](screenshots/menu-options.png) | [![Zooming in](screenshots/menu-zooming.png)](screenshots/menu-zooming.png) |

## Day and the land

| | |
|---|---|
| [![Alder Hollow in the morning](screenshots/hero-day.png)](screenshots/hero-day.png) **Alder Hollow in the morning** | [![Forests around the town](screenshots/forest-overview.png)](screenshots/forest-overview.png) **Forests kept clear of houses and roads** |
| [![07:00](screenshots/shadows-07h00.png)](screenshots/shadows-07h00.png) **07:00 — long shadows to the left** | [![12:30](screenshots/shadows-12h30.png)](screenshots/shadows-12h30.png) **12:30 — short noon shadows** |
| [![17:30](screenshots/shadows-17h30.png)](screenshots/shadows-17h30.png) **17:30 — long shadows to the right** | [![Tree shadows in the afternoon](screenshots/forest-16h.png)](screenshots/forest-16h.png) **Tree shadows swing with the sun** |

## People and animation

| | |
|---|---|
| [![Forward falls in eight directions](screenshots/animation-falls.png)](screenshots/animation-falls.png) **Falling forward, every direction** | [![Getting up](screenshots/animation-getup.png)](screenshots/animation-getup.png) **Push-up, hands and knees, kneel, stand** |
| [![Crouching](screenshots/animation-crouch.png)](screenshots/animation-crouch.png) **Crouching and sneaking** | [![Rifle, sheriff, backpack, bed](screenshots/animation-poses.png)](screenshots/animation-poses.png) **Rifle at low ready, sheriffs, kneeling at the backpack** |
| [![Hit reactions and self-treatment](screenshots/animation-reactions.png)](screenshots/animation-reactions.png) **Hit reactions and bandaging yourself** | [![Fatigue](screenshots/animation-fatigue.png)](screenshots/animation-fatigue.png) **Winded breathing and a tired run** |
| [![Sheriff](screenshots/sheriff-in-town.png)](screenshots/sheriff-in-town.png) **Sheriff on duty** | [![Outfits](screenshots/outfits.png)](screenshots/outfits.png) **Clothes that can be taken off (or stolen)** |

## Windows

| | |
|---|---|
| [![Health window](screenshots/health-window.png)](screenshots/health-window.png) **Health: figure, injury cards, treatments** | [![Bandaging](screenshots/health-window-bandaging.png)](screenshots/health-window-bandaging.png) **Bandaging in progress** |
| [![Inventory grid](screenshots/inventory-grid.png)](screenshots/inventory-grid.png) **Inventory: 6×6 grid and clothing squares** | [![Looting](screenshots/loot-window-person.png)](screenshots/loot-window-person.png) **Searching someone who is out cold** |
| [![Context menu](screenshots/context-menu-person.png)](screenshots/context-menu-person.png) **Click a person for actions** | [![Map](screenshots/map-three-towns.png)](screenshots/map-three-towns.png) **The map with all three towns** |

## Earlier captures

## Character redesign

| Drawn character details | In the village |
|---|---|
| [![Revised character proportions, clothing and action poses](screenshots/character-detail.png)](screenshots/character-detail.png) | [![The player and a villager wearing the redesigned artwork](screenshots/character-gameplay.png)](screenshots/character-gameplay.png) |

[Eight-direction turnaround](screenshots/character-design.png) · [Movement preview](screenshots/character-motion.gif)

Run `godot --path . --script res://tests/character_detail_capture.gd` to reproduce these two images.

## Village life

| Village life | Making and trading |
|---|---|
| [![The village of Alder Hollow](screenshots/market-stalls.png)](screenshots/market-stalls.png) **Alder Hollow and its market square** | [![A sawyer operates the mill next to its stock rack](screenshots/workshop-production.png)](screenshots/workshop-production.png) **The sawmill turning logs into planks** |
| [![A villager chopping a tree in the forest](screenshots/forest-harvest.png)](screenshots/forest-harvest.png) **Harvesting timber in the woodland** | [![The timber stall trading screen](screenshots/market-trading.png)](screenshots/market-trading.png) **Buying stock at the timber stall** |
| [![Cutaway view of an enterable lodge](screenshots/room-design.png)](screenshots/room-design.png) **Inside the common lodge** | [![Builder beside a partly finished wall](screenshots/construction-progress.png)](screenshots/construction-progress.png) **Wall construction from the central stockpile** |
| [![Golden clearings and dark woodland at regional zoom](screenshots/world-landscape.png)](screenshots/world-landscape.png) **Alder Hollow, Reedbank, and the road between them** | [![The body health window showing an injury list](screenshots/player-health.png)](screenshots/player-health.png) **Examining injuries and bandages** |

[Character turnaround](screenshots/character-design.png) ·
[Walk, sprint and handling animation](screenshots/character-motion.gif) ·
[Close-ups of props and furniture](screenshots/prop-detail.png)

The forest, workshop, and trading screenshots can be regenerated by running
`godot --path . --script res://tests/screenshots_capture.gd` with a graphical
display. The [current game guide](CURRENT_GAME.md#visual-examples-and-how-to-reproduce-them)
lists the other capture scripts.

## Rye, households, trades, weapons and indicators

| | |
|---|---|
| [![Six rye growth stages](screenshots/rye-growth.png)](screenshots/rye-growth.png) **Rye from planting to harvest-ready** | [![Market plaza with well and stalls](screenshots/market-plaza.png)](screenshots/market-plaza.png) **The market plaza with a ripe rye field beside it** |
| [![Sheriff's office rack](screenshots/sheriff-office.png)](screenshots/sheriff-office.png) **The sheriff's office and weapon rack** | [![Beds against walls](screenshots/lodge-beds.png)](screenshots/lodge-beds.png) **Beds in all four orientations, heads against walls** |
| [![Bakery oven](screenshots/bakery.png)](screenshots/bakery.png) **The bakery** | [![Needs indicators](screenshots/needs-indicators.png)](screenshots/needs-indicators.png) **Top-left condition indicators and name tags** |
| [![Shotgun aimed](screenshots/shotgun-fire.png)](screenshots/shotgun-fire.png) **Shotgun aimed, pellets in flight** | [![Household garden](screenshots/household-garden.png)](screenshots/household-garden.png) **A household garden behind the lodge** |
