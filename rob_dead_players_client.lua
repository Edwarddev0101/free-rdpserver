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

-- Check if player is dead
local function IsPlayerDead(playerId)
    local player = GetPlayerFromServerId(playerId)
    if player == -1 then return false end
    
    local playerPed = GetPlayerPed(player)
    if not DoesEntityExist(playerPed) then return false end
    
    -- Multiple checks for different death states
    return IsEntityDead(playerPed) or 
           IsPedDeadOrDying(playerPed, true) or 
           IsPedFatallyInjured(playerPed) or
           GetEntityHealth(playerPed) <= 0 or
           GetPedHealth(playerPed) <= 0
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
            -- Use same comprehensive death check
            local isDead = IsEntityDead(targetPed) or 
                          IsPedDeadOrDying(targetPed, true) or 
                          IsPedFatallyInjured(targetPed) or
                          GetEntityHealth(targetPed) <= 0 or
                          GetPedHealth(targetPed) <= 0
                          
            if isDead then
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

-- Rob animation
local function PlayRobAnimation()
    local playerPed = PlayerPedId()
    
    LoadAnimDict("amb@medic@standing@kneel@base")
    LoadAnimDict("anim@gangops@facility@servers@bodysearch@")
    
    TaskPlayAnim(playerPed, "amb@medic@standing@kneel@base", "base", 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(3000)
    
    TaskPlayAnim(playerPed, "anim@gangops@facility@servers@bodysearch@", "player_search", 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(5000)
    
    ClearPedTasks(playerPed)
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
                    return IsEntityDead(entity) or IsPedDeadOrDying(entity, true)
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
    
    -- Check if target is actually dead
    if not (IsEntityDead(targetEntity) or IsPedDeadOrDying(targetEntity, true)) then
        QBCore.Functions.Notify("This player is not dead!", "error")
        return
    end
    
    -- Check distance
    local playerCoords = GetEntityCoords(PlayerPedId())
    local targetCoords = GetEntityCoords(targetEntity)
    local distance = #(playerCoords - targetCoords)
    
    if distance > 3.0 then
        QBCore.Functions.Notify("You are too far away", "error")
        return
    end
    
    -- Start robbing process
    QBCore.Functions.Progressbar("robbing_player", "Robbing dead player...", 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerServerEvent('rob:server:robDeadPlayer', targetServerId)
    end, function() -- Cancel
        QBCore.Functions.Notify("Robbing cancelled", "error")
        ClearPedTasks(PlayerPedId())
    end)
    
    -- Play animation
    PlayRobAnimation()
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
    
    -- Start robbing process
    QBCore.Functions.Progressbar("robbing_player", "Robbing dead player...", 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerServerEvent('rob:server:robDeadPlayer', closestServerId)
    end, function() -- Cancel
        QBCore.Functions.Notify("Robbing cancelled", "error")
        ClearPedTasks(PlayerPedId())
    end)
    
    -- Play animation
    PlayRobAnimation()
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