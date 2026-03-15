<div align="center">

# AZ-SCHEDULE1 BETA

### Lore-friendly FiveM grow, harvest, bagging, broker, and stock system

<p>
  <img alt="Beta" src="https://img.shields.io/badge/STATUS-BETA-22c55e?style=for-the-badge">
  <img alt="FiveM" src="https://img.shields.io/badge/FiveM-Ready-3ba55d?style=for-the-badge">
  <img alt="Lua 5.4" src="https://img.shields.io/badge/Lua-5.4-2c7a7b?style=for-the-badge">
  <img alt="oxmysql" src="https://img.shields.io/badge/oxmysql-required-1f8f5f?style=for-the-badge">
  <img alt="NUI" src="https://img.shields.io/badge/NUI%20%2B%20DUI-included-14532d?style=for-the-badge">
  <img alt="Bagging" src="https://img.shields.io/badge/Bagging-6x6-22c55e?style=for-the-badge">
</p>

<p>
  <strong>San Andreas Herbal Exchange</strong><br>
  Buy supplies, place equipment, grow strains, care for plants, harvest buds, package product in a 3D bagging scene, and sell through a built-in broker UI.
</p>

</div>

---

<details open>
<summary><strong>Contents</strong></summary>

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Resource Structure](#resource-structure)
- [How Players Use It](#how-players-use-it)
- [Controls](#controls)
- [Permissions & Access Rules](#permissions--access-rules)
- [Configuration Guide](#configuration-guide)
- [Shop Items](#shop-items)
- [Strains & Economy](#strains--economy)
- [Database & Persistence](#database--persistence)
- [Developer Notes](#developer-notes)
- [Known Notes](#known-notes)
- [Coming Soon](#coming-soon)

</details>

---

## Overview

**AZ-SCHEDULE1 BETA** is a self-contained FiveM gameplay resource focused on a full grow-to-sale loop:

- buy tools and supplies
- place pots, lamps, and bagging tables in the world
- add dirt, plant seeds, water and fertilize crops
- trim and harvest mature plants
- package buds into bagged product with a 3D drag-and-drop bagging scene
- sell loose buds or packaged product through a broker tab

The resource uses:

- **NUI** for the player-facing interface
- **oxmysql** for player inventory persistence
- **resource KVP** for world object persistence
- optional **az-econ** support for sales payouts

---

## Features

<details open>
<summary><strong>Gameplay systems included</strong></summary>

### Supply / inventory UI
- themed lore-friendly green market UI
- shop tab for supplies and gear
- inventory tab for seeds, buds, bagged product, and placeables
- broker tab for selling stock

### World placement
- place **pots**
- place **grow lamps**
- place **bagging tables**
- rotation support while placing props
- per-player world limits for each placeable type

### Plant lifecycle
- dirt must be added before planting
- seeds consume inventory and begin growth at 0%
- water and fertilizer affect growth speed
- lamps near pots boost growth speed
- plants can die if water stays too low for too long
- trim action gives a small growth boost once the plant is developed enough
- harvest converts a completed plant into buds

### 3D bagging scene
- up to **6 bud slots** and **6 bag slots** visible at once
- player chooses exactly what loads onto the table
- bagging uses drag/drop style interaction in a dedicated camera scene
- packaged product is stored by strain in inventory
- debug visuals exist in the current build for bagging alignment and pick logic

### Selling / broker
- sell **loose buds**
- sell **bagged product**
- per-strain sell price config
- supports selling one or all units of a product

### Persistence
- player data persists in the `azs1_players` MySQL table
- world objects persist through resource KVP storage
- identifier migration logic attempts to recover data across common identifier changes

</details>

---

## Requirements

<details open>
<summary><strong>Hard requirements</strong></summary>

- **FiveM server** running a Cerulean-compatible build
- **oxmysql**

</details>

<details>
<summary><strong>Optional integrations</strong></summary>

- **az-econ** — only needed if you want sale payouts to go through your economy export instead of the script's local money field

Current config values:

```lua
Config.MoneySystem = 'none'
```

Available money modes in this build:

- `none`
- `az-econ`

</details>

---

## Installation

<details open>
<summary><strong>Step-by-step setup</strong></summary>

### 1) Add the resource
Place the resource folder in your server's resources directory.

### 2) Import the SQL
Run the included `install.sql`:

```sql
CREATE TABLE IF NOT EXISTS azs1_players (
  identifier VARCHAR(64) NOT NULL PRIMARY KEY,
  data LONGTEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 3) Ensure dependencies
In your server config, ensure `oxmysql` starts before this resource.

Example:

```cfg
ensure oxmysql
ensure az-schedule1
```

### 4) Optional economy integration
If you use `az-econ`, set:

```lua
Config.MoneySystem = 'az-econ'
```

And verify these config values:

```lua
Config.AzEcon = {
  ExportName = 'az-econ',
  RemoveMoneyFn = 'removeMoney',
  AddMoneyFn    = 'addMoney'
}
```

### 5) Restart the resource
After the SQL table exists and the config is set, start or restart the resource.

</details>

---

## Resource Structure

```text
az-schedule1/
├─ client/
│  └─ main.lua
├─ server/
│  └─ main.lua
├─ shared/
│  └─ utils.lua
├─ html/
│  ├─ index.html
│  ├─ style.css
│  ├─ app.js
│  ├─ dui.html
│  └─ dui.js
├─ config.lua
├─ fxmanifest.lua
├─ install.sql
└─ README.md
```

---

## How Players Use It

<details open>
<summary><strong>Full gameplay loop</strong></summary>

### 1) Buy supplies
Go to the configured shop location and buy what you need:

- pot
- lamp
- bagging table
- dirt
- fertilizer
- watering can
- water jug
- trimmers
- seeds
- empty bags

### 2) Place equipment
From inventory or the shop panel, place:

- a pot
- optional nearby lamp
- optional bagging table

### 3) Prepare the pot
Open the plant sidebar on a pot and:

- add dirt
- plant a seed

### 4) Care for the plant
Use the plant sidebar to:

- water the plant
- fertilize the plant
- trim once it is far enough along

Growth advances over time on the server tick.

### 5) Harvest
Once a plant reaches 100% growth, harvest it to receive buds.

### 6) Bag product
At a bagging table:

- choose the exact buds and bag count you want to load on the table
- drag a bag and a bud together in the bagging scene
- each completed package consumes **1 loose bud + 1 empty bag** and adds **1 bagged unit** of that strain

### 7) Sell product
Use the inventory or broker tab to sell:

- loose buds
- bagged product

</details>

---

## Controls

<details open>
<summary><strong>Default controls</strong></summary>

### General
- **E** — interact / confirm placement
- **Backspace** — cancel placement or exit some scenes
- **Left Arrow / Right Arrow** — rotate placeables while placing

### Inventory
- **/weedinv** — opens the inventory UI in the current build

### Plant scene
- use the mouse to grab / drag tools in the plant sidebar
- use the mouse wheel to tilt tools while holding them

### Bagging scene
- click the prop you want to drag
- drag bud to bag, or bag to bud
- release to drop
- **Backspace** exits the bagging scene

</details>

---

## Permissions & Access Rules

<details open>
<summary><strong>What permissions exist in this build</strong></summary>

### ACE permissions
This resource **does not enforce any built-in ACE permissions** in the current code.

That means there are **no default `add_ace` / `IsPlayerAceAllowed()` checks** to configure for shop use, grow use, or bagging use.

### Real access rules used by the script
Access is controlled by:

- **proximity** to the shop / pot / table
- **inventory ownership** of required items
- **world object ownership** using the player's stored identifier

### Ownership restrictions
A player can only manage a pot if they own that pot. The server checks ownership for:

- add dirt
- plant seed
- water
- fertilize
- trim
- harvest

### Placement restrictions
A player can only place a world object if they have the corresponding inventory item:

- pot item → place pot
- lamp item → place lamp
- table item → place bagging table

### Per-player world limits
Default limits from `config.lua`:

- `MaxPotsPerPlayer = 20`
- `MaxLampsPerPlayer = 10`
- `MaxBagTablesPerPlayer = 10`

### Bagging restrictions
Bagging requires:

- at least **1 loose bud** of the selected strain
- at least **1 empty bag**

### Selling restrictions
Selling requires:

- at least **1 loose bud** or **1 bagged unit** of the selected strain

</details>

---

## Configuration Guide

<details open>
<summary><strong>Key config sections</strong></summary>

### Debug
```lua
Config.Debug = false
```
Enables console debug output where used.

### Money system
```lua
Config.MoneySystem = 'none'
```
- `none` = internal script value only
- `az-econ` = external economy export for sell payouts

### Shop
```lua
Config.Shop = {
  label = "Seed & Supply Shop",
  coords = vec3(222.68, -806.08, 30.61),
  heading = 0.0,
  blip = { enabled = true, sprite = 496, color = 2, scale = 0.8 }
}
```
Controls the shop entry point and blip.

### World tick / growth
```lua
Config.World = {
  MaxPotsPerPlayer = 20,
  MaxLampsPerPlayer = 10,
  MaxBagTablesPerPlayer = 10,
  TickSeconds = 10,
  WaterDecayPerTick = 0.8,
  FertDecayPerTick  = 0.6,
  BaseGrowthPerTick = 1.2,
  LampRadius = 2.5,
  LampGrowthMultiplier = 1.35,
  DieIfWaterBelow = 2.0,
  DieGraceTicks   = 30,
}
```

### Cameras
```lua
Config.Cameras.Plant
Config.Cameras.Bagging
```
Used for plant care and bagging scene camera tuning.

### Bagging tuning
```lua
Config.Bagging
```
Controls drag detection, pick radius, active bag alignment, insert animation, and output capacity.

Current important values include:

- `OutputMax = 6`
- `PickDist = 0.13`
- `CombineDist = 0.115`
- `ActiveDropDist = 0.15`

### Sell pricing
```lua
Config.SellPrices = {
  buds = { ... },
  bagged = { ... }
}
```

### Strains
```lua
Config.Strains = {
  og_kush = { ... },
  blue_dream = { ... },
  sour_diesel = { ... }
}
```

Each strain stores metadata like label, base yield, grow time, and flavor/effect text.

### Props
```lua
Config.Props = {
  pot = "prop_bucket_02a",
  dirt = "prop_cs_sack_01",
  seedBag = "prop_weed_bottle",
  fertBottle = "prop_feed_sack_01",
  waterBottle = "prop_wateringcan",
  secateurs = "prop_cs_scissors",
  growLamp = "bzzz_world_of_lamps_purple",
  bagTable = "prop_table_03",
  weedBud = "bkr_prop_weed_bud_01b",
  weedBag = "m25_1_prop_m51_bag_weed_01a",
}
```

</details>

---

## Shop Items

<details>
<summary><strong>Default store catalog</strong></summary>

### Placeables
- Plant Pot — `$40`
- LED Grow Lamp — `$150`
- Bagging Table — `$200`

### Tools / supplies
- Trimmers — `$80`
- Watering Can — `$60`
- Water Jug — `$8`
- Bag of Dirt — `$10`
- Fertilizer — `$35`
- Empty Baggies (x10) — `$75`

### Seeds
- OG Kush Seeds — `$50`
- Blue Dream Seeds — `$60`
- Sour Diesel Seeds — `$65`

### Mixers
- Coke Mixer — `$90`
- Energy Mixer — `$90`
- Syrup Mixer — `$90`

</details>

---

## Strains & Economy

<details open>
<summary><strong>Default strains</strong></summary>

### OG Kush
- base yield: `6`
- grow minutes: `45`
- effects: `Calming`

### Blue Dream
- base yield: `7`
- grow minutes: `55`
- effects: `Refreshing`

### Sour Diesel
- base yield: `8`
- grow minutes: `60`
- effects: `Energizing`

</details>

<details>
<summary><strong>Default sell prices</strong></summary>

### Loose buds
- default — `$55`
- OG Kush — `$60`
- Blue Dream — `$68`
- Sour Diesel — `$74`

### Bagged product
- default — `$135`
- OG Kush — `$145`
- Blue Dream — `$155`
- Sour Diesel — `$165`

</details>

---

## Database & Persistence

<details open>
<summary><strong>How data is stored</strong></summary>

### Player data
Stored in MySQL table:

- `azs1_players`

Fields:

- `identifier`
- `data`
- `updated_at`

The `data` field contains serialized player stock/inventory, including:

- buds
- bagged product
- empty bags
- seeds
- mixers
- money
- placeables
- grow supplies

### World data
World props are stored in **resource KVP**, including:

- pots
- lamps
- tables

This means placed world objects are not stored in SQL in the current build.

### Identifier handling
The server attempts to load by:

- `license:`
- `license2:`
- `fivem:`
- `steam:`

and migrates data to the preferred identifier if a matching older record is found.

</details>

---

## Developer Notes

<details>
<summary><strong>Client events / server events used</strong></summary>

Main server-side gameplay events include:

- `azs1:shop:buy`
- `azs1:world:place`
- `azs1:pot:addDirt`
- `azs1:pot:plant`
- `azs1:pot:waterPour`
- `azs1:pot:fertPour`
- `azs1:pot:trim`
- `azs1:pot:harvest`
- `azs1:bag:one`
- `azs1:sell:product`
- `azs1:inventory:request`
- `azs1:player:request`
- `azs1:player:requestSync`

</details>

<details>
<summary><strong>Practical extension points</strong></summary>

Good places to customize:

- `Config.ShopItems` for the store catalog
- `Config.SellPrices` for your economy balance
- `Config.Strains` for custom strains
- `Config.Props` for your preferred models
- `Config.World` for growth speed and world limits
- `html/index.html`, `html/style.css`, `html/app.js` for UI theme and layout

</details>

---

## Known Notes

<details open>
<summary><strong>Important current behavior</strong></summary>

### Inventory open behavior
The current build includes a `/weedinv` command in `client/main.lua`.

A config key exists here:

```lua
Config.Keys = {
  OpenInventory = 47,
}
```

but there is **no active key mapping implementation** in the current code for that config value. If you want keyboard-open behavior, add your preferred command/keybind logic.

### Bagging debug visuals
The current build includes bagging debug drawing used during troubleshooting. If you want a clean production presentation, remove or gate those debug draw calls.

### Mixing system
The resource contains mixing-related UI placeholders and server events, but the current active gameplay loop is primarily:

- grow
- harvest
- bag
- sell

### Money handling
When `Config.MoneySystem = 'none'`, purchases effectively do not block on balance. Sales still add to the script's local money field. If you want live server economy behavior, wire it to your actual money system.

### Beta notice
This is currently a **beta build** and may still have unfinished systems, balancing changes, or UI adjustments while the resource is being expanded.

</details>

---

## Coming Soon

<details open>
<summary><strong>Planned additions</strong></summary>

- more drugs
- full mixing system
- better selling
- more broker options
- more product types
- more polish and balancing
- expanded grow / processing loops

</details>
