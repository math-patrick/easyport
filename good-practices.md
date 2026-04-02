# Nozmie Developer Guide

Practical architecture and coding standards for a World of Warcraft addon focused on portals, teleports, and utility tracking.

## 1. Project Overview

Nozmie detects utility-related signals (chat, spells, items), tracks state (keys, favourites, cooldowns), and renders fast actionable UI.

Core systems:
- UI rendering
- Data detection (chat, spells, items)
- State management (keys, favourites, cooldowns)

## 2. Recommended Folder Structure

Use this structure for scalable feature growth:

```text
AddonName/
|-- AddonName.toc
|-- core/
|   |-- init.lua
|   |-- events.lua
|   `-- state.lua
|
|-- ui/
|   |-- main_frame.lua
|   |-- components/
|   `-- tabs/
|
|-- features/
|   |-- keys.lua
|   |-- favourites.lua
|   `-- cooldowns.lua
|
|-- data/
|   |-- dungeons.lua
|   `-- utilities.lua
|
|-- utils/
|   |-- helpers.lua
|   `-- constants.lua
|
`-- db/
    `-- savedvariables.lua
```

Folder responsibilities:
- `core/`: app lifecycle, event bus, state orchestration
- `ui/`: frames, components, tabs, visual logic only
- `features/`: feature modules (keys, favourites, cooldowns)
- `data/`: static datasets and lookup tables
- `utils/`: pure helpers and constants
- `db/`: SavedVariables schema and migration helpers

## 3. Code Organization Principles

- Keep UI, logic, and data separate
- Avoid god files
- Avoid mixing rendering + parsing + persistence in one module
- Prefer small modules with one clear purpose

## 4. Naming Conventions

- Functions: `camelCase`
- Variables: `camelCase`
- Constants: `UPPER_CASE`
- Files: `snake_case.lua`

Examples:

```lua
local MAX_PORTALS = 50

local function getPlayerKeyLevel()
    return 0
end

local isFavourite = false
```

## 5. Event Handling Best Practices

- Centralize event registration in `core/events.lua`
- Use one frame/event bus to dispatch handlers
- Avoid many frames listening to the same event

Example:

```lua
EventBus:Register("CHAT_MSG_LOOT", handleLootMessage)
EventBus:Register("GROUP_ROSTER_UPDATE", handleGroupUpdate)
```

## 6. State Management

- Use one state module as the source of truth (`core/state.lua`)
- Avoid scattered globals
- Cache frequently read values

Typical state buckets:
- Detected keys
- Favourites
- Cooldowns

## 7. UI Guidelines

- Keep UI lightweight and modular
- Keep rendering non-blocking
- Each component should do one thing
- Components receive data; they do not fetch game data directly

## 8. SavedVariables Structure

- Keep schema flat and predictable
- Avoid deep nesting unless needed
- Store stable IDs, not display names

Example:

```lua
MyAddonDB = {
    favourites = {},
    settings = {},
    keys = {}
}
```

## 9. Performance Guidelines

- Avoid heavy logic in `OnUpdate`
- Prefer event-driven UI refreshes
- Cache expensive lookups
- Throttle bursty events when needed
- Avoid rebuilding full UI when a partial update is enough

## 10. Clean Code Rules

- Prefer short functions (target < 50 lines)
- Prefer early returns over deep nesting
- Replace magic numbers with constants
- Comment why, not what

Bad:

```lua
-- add 1
x = x + 1
```

Good:

```lua
-- Increment to match Blizzard index offset
x = x + 1
```

## 11. Extensibility Guidelines

- Add new systems under `features/`
- Keep `core/` stable and minimal
- Integrate features through clear interfaces
- Design modules to be plug-and-play

Example pattern:
- `features/favourites.lua` exports `toggle`, `isFavourite`, `sortWithFavourites`
- UI calls feature APIs without owning persistence logic

## 12. Example Flow

```text
Chat message
  -> Parse key data
  -> Update state cache
  -> Persist if needed
  -> Refresh affected UI rows
```

Minimal event flow sample:

```lua
local parsed = keyParser.parseChatMessage(message, sender)
if not parsed then
    return
end

state.keys:upsert(parsed)
ui.utilityList:refreshDungeon(parsed.dungeonID)
```

---

If you add a feature, add it in `features/`, expose a small API, and wire it through `core/events.lua` + `core/state.lua` before touching UI.
