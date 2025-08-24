QBCore = exports['qb-core']:GetCoreObject()
PlayerData = nil

-- Initialize
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
    end
end)

-- Animation function
function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

-- Check if player is dead using server callback (compatible with ambulance job)
local function IsPlayerReallyDead(playerPed, callback)
    if not DoesEntityExist(playerPed) then 
        if callback then callback(false) end
        return false 
    end
    
    -- Get the server ID from the ped
    local playerId = NetworkGetPlayerIndexFromPed(playerPed)
    if playerId == -1 then 
        if callback then callback(false) end
        return false 
    end
    
    local serverId = GetPlayerServerId(playerId)
    
    -- Use server callback to check death status (includes ambulance metadata)
    if callback then
        QBCore.Functions.TriggerCallback('rob:server:isPlayerDead', function(isDead)
            callback(isDead)
        end, serverId)
    else
        -- Fallback to entity checks for immediate response
        return IsEntityDead(playerPed) or 
               IsPedDeadOrDying(playerPed, true) or 
               IsPedFatallyInjured(playerPed) or
               GetEntityHealth(playerPed) <= 0
    end
end

-- Get closest dead player
local function GetClosestDeadPlayer()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        if DoesEntityExist(targetPed) and targetPed ~= playerPed then
            if IsPlayerReallyDead(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)
                
                if closestDistance == -1 or distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    
    return closestPlayer, closestDistance
end

-- Simple search animation function
local function PlaySearchAnimation()
    local playerPed = PlayerPedId()
    LoadAnimDict("anim@gangops@facility@servers@bodysearch@")
    TaskPlayAnim(playerPed, "anim@gangops@facility@servers@bodysearch@", "player_search", 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- Target integration for dead players
CreateThread(function()
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                type = "client",
                event = "rob:client:robDeadPlayer",
                icon = "fas fa-hand-paper",
                label = "Rob Dead Player",
                canInteract = function(entity)
                    -- Use fallback entity checks for immediate response (qb-target needs sync response)
                    return IsPlayerReallyDead(entity)
                end,
            },
        },
        distance = 2.5,
    })
end)

-- Client event for robbing via target
RegisterNetEvent('rob:client:robDeadPlayer', function(data)
    local targetEntity = data.entity
    if not targetEntity then return end
    
    local targetPlayerId = NetworkGetPlayerIndexFromPed(targetEntity)
    if targetPlayerId == -1 then 
        QBCore.Functions.Notify("Unable to identify player", "error")
        return 
    end
    
    local targetServerId = GetPlayerServerId(targetPlayerId)
    
    -- Check distance first
    local playerCoords = GetEntityCoords(PlayerPedId())
    local targetCoords = GetEntityCoords(targetEntity)
    local distance = #(playerCoords - targetCoords)
    
    if distance > 3.0 then
        QBCore.Functions.Notify("You are too far away", "error")
        return
    end
    
    -- Check if target is actually dead using server callback (more accurate)
    IsPlayerReallyDead(targetEntity, function(isDead)
        if not isDead then
            QBCore.Functions.Notify("This player is not dead!", "error")
            return
        end
        
        -- Start robbing process with animation
        QBCore.Functions.Progressbar("robbing_player", "Searching dead player...", 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            -- Open inventory directly like admin menu
            TriggerServerEvent('rob:server:openDeadPlayerInventory', targetServerId)
        end, function() -- Cancel
            QBCore.Functions.Notify("Search cancelled", "error")
            ClearPedTasks(PlayerPedId())
        end)
        
        -- Play search animation
        PlaySearchAnimation()
    end)
end)

-- Command for robbing closest dead player
RegisterCommand('rob', function(source, args)
    local closestPlayer, distance = GetClosestDeadPlayer()
    
    if closestPlayer == -1 then
        QBCore.Functions.Notify("No dead players nearby", "error")
        return
    end
    
    if distance > 3.0 then
        QBCore.Functions.Notify("You are too far away from the dead player", "error")
        return
    end
    
    local closestServerId = GetPlayerServerId(closestPlayer)
    local closestPed = GetPlayerPed(closestPlayer)
    
    -- Double-check if player is actually dead using server callback
    IsPlayerReallyDead(closestPed, function(isDead)
        if not isDead then
            QBCore.Functions.Notify("This player is not dead!", "error")
            return
        end
        
        -- Start robbing process with animation
        QBCore.Functions.Progressbar("robbing_player", "Searching dead player...", 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            -- Open inventory directly like admin menu
            TriggerServerEvent('rob:server:openDeadPlayerInventory', closestServerId)
        end, function() -- Cancel
            QBCore.Functions.Notify("Search cancelled", "error")
            ClearPedTasks(PlayerPedId())
        end)
        
        -- Play search animation
        PlaySearchAnimation()
    end)
end, false)

-- Success notification
RegisterNetEvent('rob:client:robSuccess', function(items, money)
    local message = "You successfully robbed the dead player!"
    if money and money > 0 then
        message = message .. "\nCash stolen: $" .. money
    end
    if items and #items > 0 then
        message = message .. "\nItems stolen: " .. #items
    end
    QBCore.Functions.Notify(message, "success", 5000)
end)

-- Failed notification
RegisterNetEvent('rob:client:robFailed', function(reason)
    QBCore.Functions.Notify(reason or "Failed to rob player", "error")
end)