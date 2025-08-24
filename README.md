# Dead Player Robbery System

A QBCore script that allows players to rob dead players using the `/rob` command or qb-target integration.

## Features

- **Command-based robbing**: Use `/rob` to rob the closest dead player
- **Target integration**: Right-click on dead players to rob them using qb-target
- **Realistic animations**: Includes search and rob animations
- **Configurable system**: Cooldowns, steal amounts, and restrictions can be customized
- **Inventory integration**: Works seamlessly with qb-inventory
- **Anti-exploit**: Cooldown system and distance checks prevent abuse

## Installation

1. Place the script files in your resources folder
2. Add `ensure rob-dead-players` to your server.cfg
3. Make sure you have the required dependencies installed

## Dependencies

- qb-core
- qb-inventory
- qb-target

## Usage

### Command Method
- Use `/rob` near a dead player to start robbing them
- Must be within 3 units of the dead player
- Animation will play for 8 seconds while robbing

### Target Method
- Right-click on a dead player
- Select "Rob Dead Player" from the target menu
- Same distance and animation requirements apply

## Configuration

Edit the `Config` table in `rob_dead_players_server.lua` to customize:

```lua
local Config = {
    RobCooldown = 300000, -- 5 minutes cooldown between robs
    MinCashSteal = 50,    -- Minimum cash to steal
    MaxCashSteal = 500,   -- Maximum cash to steal
    ItemStealChance = 75, -- Percentage chance to steal items
    MaxItemsSteal = 3,    -- Maximum number of items to steal
    RequiredJob = nil,    -- Restrict to certain jobs (optional)
}
```

## How It Works

1. Player dies and becomes available for robbing
2. Other players can use `/rob` command or qb-target to initiate robbery
3. Robber must stay close during 8-second animation
4. Random cash amount (within configured range) is stolen
5. Random items may be stolen based on configured chance
6. Both players receive notifications
7. Cooldown prevents spam robbing

## Security Features

- Distance checking (max 3 units)
- Dead player verification
- Cooldown system (5 minutes default)
- Progress bar that can be cancelled
- Item restrictions (can be configured)

## Admin Commands

- `/robcooldown [playerid]` - Check rob cooldown for a player (admin only)

## Notes

- Players must be actually dead (not just downed) to be robbed
- Robbing requires the target to stay close during the animation
- Some items can be excluded from robbery (configure in server file)
- All actions are logged for admin review