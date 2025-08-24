QBCore = exports['qb-core']:GetCoreObject()

-- Configuration
local Config = {
    RobCooldown = 300000, -- 5 minutes cooldown between robs (in milliseconds)
    MinCashSteal = 50,    -- Minimum cash to steal
    MaxCashSteal = 500,   -- Maximum cash to steal
    ItemStealChance = 75, -- Percentage chance to steal items (75%)
    MaxItemsSteal = 3,    -- Maximum number of items to steal
    RequiredJob = nil,    -- Set to job name if you want to restrict to certain jobs (e.g., "police")
}

-- Store rob cooldowns
local robCooldowns = {}

-- Check if player is dead
local function IsPlayerDead(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerPed = GetPlayerPed(source)
    if not playerPed then return false end
    
    return GetEntityHealth(playerPed) <= 0
end

-- Get random items from dead player
local function GetRandomItems(playerItems, maxItems)
    local availableItems = {}
    
    -- Filter out items that can be stolen
    for slot, item in pairs(playerItems) do
        if item and item.amount and item.amount > 0 then
            -- Skip certain items if needed (you can customize this)
            local skipItems = {
                -- "id_card", "driver_license", -- Example items to skip
            }
            
            local shouldSkip = false
            for _, skipItem in ipairs(skipItems) do
                if item.name == skipItem then
                    shouldSkip = true
                    break
                end
            end
            
            if not shouldSkip then
                table.insert(availableItems, {
                    slot = slot,
                    item = item
                })
            end
        end
    end
    
    -- Randomly select items
    local selectedItems = {}
    local numItemsToSteal = math.min(maxItems, #availableItems)
    
    for i = 1, numItemsToSteal do
        if #availableItems > 0 then
            local randomIndex = math.random(1, #availableItems)
            local selectedItem = table.remove(availableItems, randomIndex)
            table.insert(selectedItems, selectedItem)
        end
    end
    
    return selectedItems
end

-- Server event to handle robbing
RegisterServerEvent('rob:server:robDeadPlayer', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not Player then
        TriggerClientEvent('rob:client:robFailed', src, "Unable to identify robber")
        return
    end
    
    if not TargetPlayer then
        TriggerClientEvent('rob:client:robFailed', src, "Target player not found")
        return
    end
    
    -- Check if robber has required job (if configured)
    if Config.RequiredJob and Player.PlayerData.job.name ~= Config.RequiredJob then
        TriggerClientEvent('rob:client:robFailed', src, "You don't have permission to rob players")
        return
    end
    
    -- Check if target is actually dead
    if not IsPlayerDead(targetId) then
        TriggerClientEvent('rob:client:robFailed', src, "Target player is not dead")
        return
    end
    
    -- Check cooldown
    local playerIdentifier = Player.PlayerData.citizenid
    local currentTime = os.time() * 1000
    
    if robCooldowns[playerIdentifier] and (currentTime - robCooldowns[playerIdentifier]) < Config.RobCooldown then
        local remainingTime = math.ceil((Config.RobCooldown - (currentTime - robCooldowns[playerIdentifier])) / 1000)
        TriggerClientEvent('rob:client:robFailed', src, "You must wait " .. remainingTime .. " seconds before robbing again")
        return
    end
    
    -- Check distance between players
    local robberCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetId))
    local distance = #(robberCoords - targetCoords)
    
    if distance > 3.0 then
        TriggerClientEvent('rob:client:robFailed', src, "You are too far away from the target")
        return
    end
    
    -- Start robbing process
    local stolenItems = {}
    local stolenMoney = 0
    
    -- Steal cash
    local targetCash = TargetPlayer.PlayerData.money["cash"] or 0
    if targetCash > 0 then
        stolenMoney = math.random(
            math.min(Config.MinCashSteal, targetCash),
            math.min(Config.MaxCashSteal, targetCash)
        )
        
        TargetPlayer.Functions.RemoveMoney("cash", stolenMoney, "robbed-by-player")
        Player.Functions.AddMoney("cash", stolenMoney, "robbed-from-player")
    end
    
    -- Steal items (with chance)
    if math.random(100) <= Config.ItemStealChance then
        local targetItems = TargetPlayer.PlayerData.items or {}
        local itemsToSteal = GetRandomItems(targetItems, Config.MaxItemsSteal)
        
        for _, itemData in ipairs(itemsToSteal) do
            local item = itemData.item
            local slot = itemData.slot
            
            -- Determine how much to steal (steal between 1 and full amount)
            local amountToSteal = math.random(1, item.amount)
            
            -- Remove from target
            TargetPlayer.Functions.RemoveItem(item.name, amountToSteal, slot)
            
            -- Add to robber
            local success = Player.Functions.AddItem(item.name, amountToSteal, nil, item.info)
            
            if success then
                table.insert(stolenItems, {
                    name = item.name,
                    amount = amountToSteal,
                    label = QBCore.Shared.Items[item.name] and QBCore.Shared.Items[item.name].label or item.name
                })
                
                -- Trigger item box notifications
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[item.name], "add", amountToSteal)
                TriggerClientEvent('qb-inventory:client:ItemBox', targetId, QBCore.Shared.Items[item.name], "remove", amountToSteal)
            else
                -- If can't add to robber, give back to target
                TargetPlayer.Functions.AddItem(item.name, amountToSteal, slot, item.info)
            end
        end
    end
    
    -- Update inventories
    TriggerClientEvent('qb-inventory:client:updateInventory', src)
    TriggerClientEvent('qb-inventory:client:updateInventory', targetId)
    
    -- Set cooldown
    robCooldowns[playerIdentifier] = currentTime
    
    -- Notify both players
    TriggerClientEvent('rob:client:robSuccess', src, stolenItems, stolenMoney)
    
    local targetMessage = "You have been robbed while dead!"
    if stolenMoney > 0 then
        targetMessage = targetMessage .. "\nCash stolen: $" .. stolenMoney
    end
    if #stolenItems > 0 then
        targetMessage = targetMessage .. "\nItems stolen: " .. #stolenItems
    end
    TriggerClientEvent('QBCore:Notify', targetId, targetMessage, "error", 5000)
    
    -- Log the robbery (optional)
    print(string.format("[ROB] %s (%s) robbed %s (%s) - $%d cash, %d items", 
        Player.PlayerData.name, 
        Player.PlayerData.citizenid,
        TargetPlayer.PlayerData.name, 
        TargetPlayer.PlayerData.citizenid,
        stolenMoney, 
        #stolenItems
    ))
    
    -- You can also add webhook logging here if needed
    -- TriggerEvent('qb-log:server:CreateLog', 'robbery', 'Player Robbed', 'red', message, true)
end)

-- Clean up old cooldowns periodically
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        local currentTime = os.time() * 1000
        
        for identifier, lastRob in pairs(robCooldowns) do
            if (currentTime - lastRob) >= Config.RobCooldown then
                robCooldowns[identifier] = nil
            end
        end
    end
end)

-- Command to check rob cooldown (optional admin command)
QBCore.Commands.Add("robcooldown", "Check rob cooldown for a player", {{name = "id", help = "Player ID"}}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('QBCore:Notify', source, "Player not found", "error")
        return
    end
    
    local playerIdentifier = Player.PlayerData.citizenid
    local currentTime = os.time() * 1000
    
    if robCooldowns[playerIdentifier] then
        local remainingTime = math.ceil((Config.RobCooldown - (currentTime - robCooldowns[playerIdentifier])) / 1000)
        if remainingTime > 0 then
            TriggerClientEvent('QBCore:Notify', source, "Player has " .. remainingTime .. " seconds left on rob cooldown", "primary")
        else
            TriggerClientEvent('QBCore:Notify', source, "Player can rob again", "success")
        end
    else
        TriggerClientEvent('QBCore:Notify', source, "Player has no rob cooldown", "success")
    end
end, "admin")