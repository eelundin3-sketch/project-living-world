# Project Solo — Game Foundation v0.1

**Status:** Proposed baseline; deliberate design choices, not claims about *Another Dead World's* undisclosed implementation.  
**Target:** Single-player 2D top-down desktop sandbox (Windows first; Linux/macOS later).  
**Engine:** Godot 4.x, pin the exact stable version before coding.  
**Language:** GDScript first, lower-level code only after profiling.  
**Inspiration:** Simulation-driven worlds, persistent residents, systemic production, trade and consequences; all code, art, content and setting should be original.

## 1. One-sentence concept

**A living frontier sandbox where every resident pursues their own needs and work, goods move through real supply chains, settlements adapt, and a single player can explore, trade, work or influence the world without being its centre.**

## 2. Player fantasy and starting scenario

The player begins as an ordinary traveller arriving at a small settlement. They do not start as an all-powerful colony manager. They can walk around, speak with or inspect residents, buy and sell useful goods, accept jobs, and eventually run an enterprise or influence a settlement. Even when the player stays still, the town works, consumes resources, makes mistakes and changes.

**Initial setting decision:** low-tech fictional frontier with forests, farms, towns and caravan routes. This keeps the first economy understandable. Lore, era and visual style are adjustable later without rewriting the simulation.

**Camera and controls:** top-down 2D; WASD movement, mouse inspect/interact, scroll zoom, Space pause, 1/2/3 simulation-speed presets. Player control, not RTS-style omnipotent construction, is the default mode. A debug/observer mode can inspect every simulation system.

## 3. Five experience pillars

1. **Autonomous people.** NPCs choose work and care for their needs without direct player input; every important resident has persistent identity.
2. **Material causality.** Wood cannot appear in a warehouse unless it was gathered, transferred, produced or received from an explicitly modelled external source.
3. **Responsive settlements.** Shortages, surpluses, population, geography and relationships influence what towns build, buy or export.
4. **Legible emergence.** The player can inspect *why* a merchant raised prices, why a worker is idle, why a bakery stopped production, or why a village lacks wood.
5. **Depth through interactions, not sheer size.** New systems should make existing systems more interesting, not merely add disconnected mechanics.

## 4. Core causal loop

```
Nature (trees / fertile land)
   ↓
Gathering & farming (workers require time and food)
   ↓
Inventories and hauling (physical material changes locations)
   ↓
Workshops (recipes consume inputs; outputs enter inventories)
   ↓
Needs and buildings (NPCs eat; housing and capacity grow)
   ↓
Local supply and demand (orders, transactions, price signals)
   ↓
Trade and migration (resources and people cross settlements)
   ↓
Settlement adaptation (build, specialize, negotiate)
   ↺ feedback on labour, demand and resources

The player intervenes at any point.
```

**Illustrative emergent story:** A logging area is depleted. Haulers travel farther and the sawmill gets fewer logs. Planks become scarcer, construction stalls, the town raises its buying price, and a merchant from another town finds the route profitable. The player might deliver logs, buy cheap planks elsewhere, or start a timber business. No scripted quest is required for that chain.

## 5. First playable 'proof of life' vertical slice

**Scene:** a small manually seeded clearing with a village, forest, warehouse and edible food source. It need not have complete world generation.

**Population:** 10 residents initially; scale to 20 once stable.  
**Resources:** logs, food; later planks.  
**Buildings:** warehouse, homes, campfire/food storage; later sawmill.  
**NPC needs:** hunger and fatigue first.  
**Jobs:** gather logs, haul logs, eat, rest.  
**Player actions:** walk, inspect resident/job/tree/warehouse, pause and change speed.  
**Persistence:** save/reload authoritative state.  
**Debugging:** job state, inventory totals, need values and simulation tick visible in overlay.

### Vertical-slice acceptance criteria

- With no player input, residents find jobs, collect logs, deliver them and eat or rest as needed.
- Two residents never claim the same exclusive gathering target simultaneously.
- A failed or interrupted task releases its reservation; no NPC stays trapped in a permanent idle loop.
- Inventory sums are correct before and after all movements.
- Every resident persists across save/reload with the same identity, possessions, needs and current valid task.
- The same seed and scripted commands produce the same authoritative state hash at a specified tick.
- The player can understand at least one full production chain from the interface without reading a log file.

## 6. Experience roadmap (player-facing)

| Stage | New experience | Player-visible evidence |
|---|---|---|
| Proof of life | A single village lives on its own | Workers collect and store resources while the player watches |
| Village economy | Inputs become products; stores run low | Production halts if ingredients are missing |
| Town growth | The village adds buildings and jobs | New homes, workplaces and work opportunities |
| Regional trade | Nearby settlements specialize and exchange goods | A merchant's arrival changes stock and prices |
| Long-lived citizens | People develop skills, relationships and memories | Residents behave differently after meaningful events |
| Larger world | Distant settlements evolve while off screen | The world changes even when the player leaves |
| Political world | Factions pursue interests and affect trade | Embargoes, treaties and migration have economic consequences |
| Late-game depth | Conflict, ecology, major shocks, modding | The player can trace large events back to systemic causes |

## 7. Scope boundaries — deliberately out of v1

- Multiplayer or networking.
- Full 3D, complex physics-driven combat, elaborate character animation.
- Hundreds of handcrafted professions or commodities.
- Large-scale warfare before economy, saving and remote simulation work.
- Full language-model-powered NPC dialogue.
- Unbounded, fully detailed simulation of every distant citizen.
- Arbitrary user-supplied scripts for mods before data contracts stabilise.

## 8. Design questions intentionally open (nonblocking)

- Final theme/era and art direction (temporary graphics are sufficient for now).
- Whether the player can found or directly govern a town (design API should make this possible, but no early UI commitment).
- Whether deeper combat is central or occasional.
- Number of NPC personality dimensions beyond needs and memory.

**Design rule:** none of these unanswered creative choices should block building the first functioning simulation loop.
