# Nozmie

**Nozmie** is an addon that intelligently detects teleport, portal, and utility requests from chat messages and displays an interactive banner for instant one-click casting or item usage. Also includes an Utility Page functionality to show all your utilities in one place. 

---

## Features

### Core Functionality
- **Smart Chat Detection**: Automatically scans Say, Party, Party Leader, Raid, Guild, Whisper, and Battle.net Whisper messages for teleport and utility requests.
- **One-Click Banner**: Instantly cast spells or use items, with cooldown feedback and optional announcements to your group.
- **Keyword Matching**: Whole-word pattern detection to prevent false positives from partial matches.
- **Multi-Select Chat Channels**: Choose which chat channels to monitor via the settings panel.
- **Player Targeting**: Automatically targets the player who made the request when applicable.
- **Instance-Aware**: Different suppression filter settings for dungeons, raids, and open world content.
- **Stacked Banners**: Display multiple options when several matches are found.
- **Portal Prioritization**: Optionally prioritize portal spells over regular teleports.
- **Persistent Blacklist**: Exclude messages containing specific words to reduce noise.
- **Utility Page UI**: Browse all available teleports, portals, utilities, and hearthstones through an organized tabbed interface with search functionality.

### Customization
- **Global & Instance Suppression Filters**: Suppress categories globally or only in instances (dungeons, raids).
- **Suppression Categories**:
  - Mounts
  - Class Utilities
  - Teleports & Portals
  - Utility Services (Repair, Mailbox, Anvil, Transmog)
- **Banner Timeout**: Auto-hide banner after a configurable duration.
- **Minimap Icon**: Toggle minimap button on or off.
- **Group Announcements**: Optionally announce used spells to your current group.

### Supported Content

#### Teleportation
- **Mythic+ Dungeon Teleports**: All M+ dungeons across multiple expansions. Including Midnight!
- **Raid Teleports**: All current and legacy raid teleportation spells.
- **Mage Portals & Teleports**: Conjure Portal and Teleport spells for all locations.
- **Hearthstones**: Hearthstone items and hearthstone toy variants.

#### Class Utilities
- **Mage**: Conjure Refreshment (food tables), Arcane Intellect, Slow Fall.
- **Warlock**: Ritual of Summoning, Create Soulwell, Soulstone.
- **Priest**: Power Word: Fortitude, Levitate.
- **Ressurrection Spells**: On all classes that supports them!

#### Items & Toys
- **Teleportation Toys**: Portable items that grant instant teleportation.
- **Portal Generators**: Items that create portals to various locations.
- **Mounts**: Repair and Auction Mounts included!

#### Special Services
- **Repair Services**: Detection for NPC repair services and engineering repair bots.
- **Mailbox Access**: Portable mailbox items.
- **Transmog Services**: Transmog Pedestal and similar items.
- **Anvil Access**: Engineering anvils and portable forges.

---

## Commands

| Command | Description |
|---------|-------------|
| `/noz` or `/nozmie` | Open the Utility UI. |
| `/noz settings` | Open the settings panel. |
| `/noz minimap` | Toggle the minimap icon visibility. |
| `/noz last` | Display the last banner again. |
| `/noz blacklist` | Show the current blacklist. |
| `/noz blacklist <words>` | Set the blacklist (comma-separated words). |

---

## Utility Page

The Utility Page provides a comprehensive browsable interface for all your available teleports, portals, utilities, and hearthstones. Access it with `/noz utility`.

### Tabs
- **Current Dungeons**: Mythic+ dungeons currently in rotation
- **Legacy Dungeons**: Mythic+ dungeons from previous seasons
- **Teleports**: Raid teleports, Delve access, and teleportation toys
- **Utility**: Utility spells and services (buffs, summons, repairs, etc.)
- **Hearthstone**: All hearthstone items and variants you own

### Features
- **Item Grid**: Visual display of all available items with icons and cooldown tracking
- **Search Bar**: Quickly search across all items by name, category, or keywords
- **One-Click Casting**: Click any item to instantly cast the spell or use the item
- **Smart Filtering**: Only shows items and spells you can actually use
- **Cooldown Display**: Real-time cooldown timers on spell icons

---

## How It Works

1. **Chat Monitoring**: Nozmie listens to your configured chat channels and analyzes messages for keywords matching known spells and items.
2. **Keyword Matching**: Uses intelligent whole-word detection to find exact matches (e.g., searching for "portal" won't match "portable").
3. **Availability Check**: Verifies that you own the spell, item, or toy before displaying it in the banner or utility page.
4. **Banner Display**: Shows a classic WoW-style dialog banner with the matched option(s) and their icons.
5. **One-Click Action**: Click the banner or utility page item to instantly cast the spell or use the item.

---

## Localization

Nozmie supports the following languages:
- English (enUS)
- German (deDE)
- Spanish (esES)
- French (frFR)
- Russian (ruRU)
- Simplified Chinese (zhCN)
- Traditional Chinese (zhTW)
- Korean (koKR)
- Portuguese (ptBR)

---

## Notes & Tips

- **Only your spells/items are shown**: The addon only displays actions you can actually perform (owned spells, items, or toys).
- **Whole-word matching**: Prevents false positives; "portal" will not match "portable" or "portalstone".
- **Minimap button enabled by default**: The minimap icon is now enabled by default for easier access.
- **/noz and /nozmie open Utility UI**: You can now use `/noz` or `/nozmie` to open the Utility UI directly.
- **Stacking**: If multiple actions match a single message, they'll all be displayed in a stacked banner format.
- **Instance-specific suppression**: Use instance filters to hide unwanted categories in dungeons/raids while keeping them visible in open world.
- **Cooldown-aware**: Icons fade or display cooldown timers when spells are on cooldown.
- **Position persistence**: Banner position is saved between sessions.

---

## Future improvements
- Nozmie may not detect localized dungeon names for now, but its in the radar.
