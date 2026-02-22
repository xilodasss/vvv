-- ========================================================================== --
--                            SERVICES & MODULES                               --
-- ========================================================================== --

local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")
local player             = Players.LocalPlayer
local UserInputService   = game:GetService("UserInputService")
local TeleportService    = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser        = game:GetService("VirtualUser")
local TweenService       = game:GetService("TweenService")
local GuiService         = game:GetService("GuiService")
local StarterGui         = game:GetService("StarterGui")
local Lighting           = game:GetService("Lighting")
local placeId            = game.PlaceId
local jobId              = game.JobId

-- -------------------------------------------------------------------------- --
--                            NOTIFICATION FUNCTION                           --
-- -------------------------------------------------------------------------- --

local function Success(title, message, duration)
    local success, err = pcall(function()
        WindUI:Notify({
            Title = title,
            Content = message,
            Duration = duration,
            Icon = "circle-check"
        })
    end)
    if not success then
        warn("Failed to show notification:", err)
    end
end

local function Error(title, message, duration)
    local success, err = pcall(function()
        WindUI:Notify({
            Title = title,
            Content = message,
            Duration = duration,
            Icon = "ban"
        })
    end)
    if not success then
        warn("Failed to show error:", err)
    end
end

local function Info(title, message, duration)
    local success, err = pcall(function()
        WindUI:Notify({
            Title = title,
            Content = message,
            Duration = duration,
            Icon = "info"
        })
    end)
    if not success then
        warn("Failed to show info:", err)
    end
end

local function Warning(title, message, duration)
    local success, err = pcall(function()
        WindUI:Notify({
            Title = title,
            Content = message,
            Duration = duration,
            Icon = "triangle-alert"
        })
    end)
    if not success then
        warn("Failed to show warning:", err)
    end
end

-- -------------------------------------------------------------------------- --
--                         AUTO SELF REVIVE MODULE                            --
-- -------------------------------------------------------------------------- --

local AutoSelfReviveModule = (function()
    local enabled = false
    local method = "Spawnpoint"
    local connections = {}
    local lastSavedPosition = nil
    local hasRevived = false
    local isReviving = false

    local function cleanupConnections()
        for _, conn in pairs(connections) do
            if conn and conn.Disconnect then
                pcall(function() conn:Disconnect() end)
            end
        end
        connections = {}
    end

    local function handleDowned(character)
        local success, isDowned = pcall(function()
            return character:GetAttribute("Downed")
        end)
        
        if success and isDowned and not isReviving then
            isReviving = true

            if method == "Spawnpoint" then
                if not hasRevived then
                    hasRevived = true
                    pcall(function()
                        ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
                    end)
                    Success("Auto Self Revive", "Reviving at spawnpoint...", 2)

                    task.delay(10, function()
                        hasRevived = false
                    end)
                    task.delay(1, function()
                        isReviving = false
                    end)
                else
                    isReviving = false
                end
            elseif method == "Fake Revive" then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    lastSavedPosition = hrp.Position
                end

                task.spawn(function()
                    pcall(function()
                        ReplicatedStorage:WaitForChild("Events"):WaitForChild("Player"):WaitForChild("ChangePlayerMode")
                            :FireServer(true)
                    end)

                    Success("Auto Self Revive", "Saving position and reviving...", 2)

                    local newCharacter
                    repeat
                        newCharacter = player.Character
                        task.wait()
                    until newCharacter and newCharacter:FindFirstChild("HumanoidRootPart") and newCharacter ~= character

                    if newCharacter then
                        local newHRP = newCharacter:FindFirstChild("HumanoidRootPart")
                        if lastSavedPosition and newHRP then
                            task.wait(0.1)
                            pcall(function()
                                newHRP.CFrame = CFrame.new(lastSavedPosition)
                            end)
                            Success("Auto Self Revive", "Teleported back to saved position!", 2)
                        end
                    end

                    isReviving = false
                end)
            end
        end
    end

    local function setupCharacter(character)
        if not character then return end

        task.wait(0.5)

        local downedConnection = character:GetAttributeChangedSignal("Downed"):Connect(function()
            handleDowned(character)
        end)

        table.insert(connections, downedConnection)
    end

    local function start()
        if enabled then return end
        enabled = true

        cleanupConnections()

        local character = player.Character
        if character then
            setupCharacter(character)
        end

        local charAddedConnection = player.CharacterAdded:Connect(function(newChar)
            setupCharacter(newChar)
        end)

        table.insert(connections, charAddedConnection)

        Success("Auto Self Revive", "Enabled with method: " .. method, 2)
    end

    local function stop()
        if not enabled then return end
        enabled = false

        cleanupConnections()
        hasRevived = false
        isReviving = false
        lastSavedPosition = nil

        Info("Auto Self Revive", "Disabled", 2)
    end

    return {
        Start = start,
        Stop = stop,
        SetMethod = function(newMethod)
            method = newMethod
            if enabled then
                Info("Auto Self Revive", "Method changed to: " .. newMethod, 2)
            end
        end,
        IsEnabled = function()
            return enabled
        end
    }
end)()

-- -------------------------------------------------------------------------- --
--                         FAST REVIVE MODULE                                 --
-- -------------------------------------------------------------------------- --

local FastReviveModule = (function()
    local enabled = false
    local method = "Interact"
    local reviveRange = 10
    local loopDelay = 0.15
    local reviveLoopHandle = nil
    local interactHookConnection = nil
    local keyboardConnection = nil
    local interactEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("Interact")

    local function isPlayerDowned(plr)
        local success, result = pcall(function()
            local char = plr.Character
            if char and char:FindFirstChild("Humanoid") then
                local humanoid = char.Humanoid
                return humanoid.Health <= 0 or char:GetAttribute("Downed") == true
            end
            return false
        end)
        return success and result or false
    end

    local function startAutoMethod()
        if reviveLoopHandle then return end

        reviveLoopHandle = task.spawn(function()
            while enabled and method == "Auto" do
                local success, myChar = pcall(function()
                    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                end)
                
                if success and myChar then
                    local myHRP = player.Character.HumanoidRootPart
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= player then
                            local char = plr.Character
                            if char and char:FindFirstChild("HumanoidRootPart") then
                                if isPlayerDowned(plr) then
                                    local hrp = char.HumanoidRootPart
                                    local distSuccess, dist = pcall(function()
                                        return (myHRP.Position - hrp.Position).Magnitude
                                    end)
                                    if distSuccess and dist and dist <= reviveRange then
                                        pcall(function()
                                            interactEvent:FireServer("Revive", true, plr.Name)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(loopDelay)
            end
            reviveLoopHandle = nil
        end)
    end

    local function stopAutoMethod()
        if reviveLoopHandle then
            pcall(function() task.cancel(reviveLoopHandle) end)
            reviveLoopHandle = nil
        end
    end

    local function startInteractMethod()
        if interactHookConnection then return end

        local success, eventsFolder = pcall(function()
            return player.PlayerScripts:WaitForChild("Events")
        end)
        
        if not success or not eventsFolder then return end
        
        local tempEventsFolder = eventsFolder:WaitForChild("temporary_events")
        local useKeybind = tempEventsFolder:WaitForChild("UseKeybind")

        interactHookConnection = useKeybind.Event:Connect(function(...)
            local args = { ... }

            if args[1] and type(args[1]) == "table" then
                local keyData = args[1]

                if keyData.Key == "Interact" and keyData.Down == true and enabled then
                    task.spawn(function()
                        for _, plr in pairs(Players:GetPlayers()) do
                            if plr ~= player then
                                pcall(function()
                                    interactEvent:FireServer("Revive", true, plr.Name)
                                end)
                                task.wait(0.1)
                            end
                        end
                    end)
                end
            end
        end)

        keyboardConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not enabled then return end

            if input.KeyCode == Enum.KeyCode.E then
                task.spawn(function()
                    for _, plr in pairs(Players:GetPlayers()) do
                        if plr ~= player then
                            pcall(function()
                                interactEvent:FireServer("Revive", true, plr.Name)
                            end)
                            task.wait(0.1)
                        end
                    end
                end)
            end
        end)
    end

    local function stopInteractMethod()
        if interactHookConnection then
            pcall(function() interactHookConnection:Disconnect() end)
            interactHookConnection = nil
        end
        if keyboardConnection then
            pcall(function() keyboardConnection:Disconnect() end)
            keyboardConnection = nil
        end
    end

    local function start()
        enabled = true
        if method == "Auto" then
            stopInteractMethod()
            startAutoMethod()
        elseif method == "Interact" then
            stopAutoMethod()
            startInteractMethod()
        end
    end

    local function stop()
        enabled = false
        stopAutoMethod()
        stopInteractMethod()
    end

    local function setMethod(newMethod)
        local wasEnabled = enabled
        stop()
        method = newMethod
        if wasEnabled then
            start()
        end
    end

    return {
        Start = start,
        Stop = stop,
        SetMethod = setMethod,
        IsEnabled = function()
            return enabled
        end
    }
end)()

-- -------------------------------------------------------------------------- --
--                         TELEPORT MODULE (EXTERNAL)                          --
--                    Dengan Auto Map Detection & Notif                        --
-- -------------------------------------------------------------------------- --

local TeleportModule = (function()
    -- GANTI URL INI dengan raw GitHub kamu
    local TELEPORT_MODULE_URL = "https://raw.githubusercontent.com/xilodasss/vvv/refs/heads/main/TeleportModule.lua"
    
    local moduleData = nil
    local loadError = nil
    local lastLoadTime = nil
    local currentMap = "Unknown"
    local mapCheckConnection = nil
    
    -- ==================== MAP DETECTION & NOTIFICATION ====================
    
    -- Fungsi untuk cek map saat ini
    local function detectCurrentMap()
        local gameFolder = workspace:FindFirstChild("Game")
        if gameFolder then
            local mapFolder = gameFolder:FindFirstChild("Map")
            if mapFolder then
                local mapName = mapFolder:GetAttribute("MapName")
                if mapName and mapName ~= "" then
                    return mapName
                end
            end
        end
        return "Unknown"
    end
    
    -- Fungsi untuk handle perubahan map
    local function handleMapChange(newMap)
    if newMap == "Unknown" then
        Warning("Map Detection", "Could not detect current map!", 3)
        return
    end
    
    if not moduleData then
        return
    end
    
    -- Cek apakah map ada di database
    if moduleData and moduleData.HasMapData and moduleData.HasMapData(newMap) then
        -- Map ADA di database
        local mapCount = moduleData.GetMapCount and moduleData.GetMapCount() or 0
        
        Success("Map Detected", newMap .. " (" .. mapCount .. " maps available)", 3)
            
    else
        -- Map TIDAK ADA di database
        if moduleData then
            Warning("Map Not Found", newMap .. " - Please refresh database", 4)
        end
    end
end
    
    -- Fungsi untuk start monitoring map
    local function startMapMonitoring()
        if mapCheckConnection then
            mapCheckConnection:Disconnect()
        end
        
        -- Cek map setiap 2 detik
        mapCheckConnection = RunService.Heartbeat:Connect(function()
            local newMap = detectCurrentMap()
            if newMap ~= currentMap then
                currentMap = newMap
                handleMapChange(newMap)
            end
        end)
    end
    
    -- Fungsi untuk stop monitoring
    local function stopMapMonitoring()
        if mapCheckConnection then
            mapCheckConnection:Disconnect()
            mapCheckConnection = nil
        end
    end
    
    -- ==================== LOAD MODULE ====================
    
    local function loadFromGitHub()
        loadError = nil
        local success, result = pcall(function()
            print("📡 Loading Teleport Module from GitHub...")
            local script = game:HttpGet(TELEPORT_MODULE_URL)
            return loadstring(script)()
        end)
        
        if success and result then
            moduleData = result
            lastLoadTime = os.time()
            
            -- Deteksi map setelah load
            currentMap = detectCurrentMap()
            handleMapChange(currentMap)
            
            print("✅ Teleport Module loaded! Maps: " .. (result.GetMapCount and result.GetMapCount() or "?"))
            return true
        else
            loadError = tostring(result)
            warn("❌ Failed to load Teleport Module:", loadError)
            Error("Teleport Module", "Failed to load: " .. loadError, 5)
            return false
        end
    end
    
    -- Load pertama kali
    loadFromGitHub()
    
    -- Mulai monitoring map
    startMapMonitoring()
    
    -- Stop monitoring saat player keluar
    game:GetService("Players").PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            stopMapMonitoring()
        end
    end)
    
    -- ==================== FUNGSI UTAMA ====================
    
    local function validateCharacter()
        local char = player.Character
        if not char then
            Error("Teleport", "Character not found!", 2)
            return nil, nil
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Error("Teleport", "HumanoidRootPart not found!", 2)
            return nil, nil
        end

        return char, hrp
    end

    local function safeTeleport(hrp, targetPosition, filterInstances)
        filterInstances = filterInstances or {}
        local teleportPos = targetPosition + Vector3.new(0, 5, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = filterInstances
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local ray = workspace:Raycast(teleportPos, Vector3.new(0, -10, 0), raycastParams)
        if ray then
            teleportPos = ray.Position + Vector3.new(0, 3, 0)
        end

        hrp.CFrame = CFrame.new(teleportPos)
        return true
    end

    local function getCurrentMap()
        return currentMap
    end

    local function placeTeleporter(cframe)
        if not cframe then
            Error("Teleport", "Invalid teleporter position!", 2)
            return false
        end

        task.spawn(function()
            pcall(function()
                local args = { [1] = 0, [2] = 16 }
                ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("ToolAction"):FireServer(unpack(args))
            end)

            task.wait(1)

            pcall(function()
                local args2 = { [1] = 1, [2] = { [1] = "Teleporter", [2] = cframe } }
                ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("ToolAction"):FireServer(unpack(args2))
            end)

            task.wait(1)

            pcall(function()
                local args3 = { [1] = 0, [2] = 15 }
                ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("ToolAction"):FireServer(unpack(args3))
            end)

            Success("Teleporter Placed", "Teleporter successfully placed!", 2)
        end)

        return true
    end

    -- ==================== PUBLIC API ====================
    return {
        -- Status Module
        IsLoaded = function() return moduleData ~= nil end,
        GetError = function() return loadError end,
        GetLastLoad = function() return lastLoadTime end,
        GetCurrentMap = getCurrentMap,
        
        -- Manual Refresh
        Refresh = function()
            stopMapMonitoring() -- Stop dulu
            local success = loadFromGitHub()
            startMapMonitoring() -- Mulai lagi
            if success then
                Success("Teleport Module", "Refreshed successfully! Maps: " .. (moduleData.GetMapCount and moduleData.GetMapCount() or "?"), 3)
            else
                Error("Teleport Module", "Refresh failed: " .. (loadError or "Unknown error"), 5)
            end
            return success
        end,
        
        -- Fungsi Map
        HasMapData = function(mapName)
            return moduleData and moduleData.HasMapData and moduleData.HasMapData(mapName) or false
        end,
        GetMapSpot = function(mapName, spotType)
            return moduleData and moduleData.GetMapSpot and moduleData.GetMapSpot(mapName, spotType) or nil
        end,
        GetAllMapNames = function()
            return moduleData and moduleData.GetAllMapNames and moduleData.GetAllMapNames() or {}
        end,
        GetMapCount = function()
            return moduleData and moduleData.GetMapCount and moduleData.GetMapCount() or 0
        end,
        GetLastUpdate = function()
            return moduleData and moduleData.GetLastUpdate and moduleData.GetLastUpdate() or "Unknown"
        end,
        
        -- Fungsi Utama Teleport
        TeleportPlayer = function(spotType)
            if not moduleData then
                Error("Teleport", "Module not loaded! Click Refresh first.", 3)
                return false
            end
            
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end
            
            local mapName = currentMap
            if mapName == "Unknown" then
                Error("Teleport", "Could not detect map name!", 2)
                return false
            end

            if not moduleData.HasMapData(mapName) then
                Error("Teleport", "Map '" .. mapName .. "' not in database! Click Refresh to update.", 4)
                return false
            end

            local cframe = moduleData.GetMapSpot(mapName, spotType)
            if not cframe then
                Error("Teleport", "No " .. spotType .. " spot found for " .. mapName, 3)
                return false
            end

            Info("Teleporting", "Teleporting to " .. spotType .. " for " .. mapName .. "...", 2)
            return safeTeleport(hrp, cframe.Position, { char })
        end,
        
        PlaceTeleporter = function(spotType)
            if not moduleData then
                Error("Teleport", "Module not loaded! Click Refresh first.", 3)
                return false
            end
            
            local mapName = currentMap
            if mapName == "Unknown" then
                Error("Teleport", "Could not detect map name!", 2)
                return false
            end

            if not moduleData.HasMapData(mapName) then
                Error("Teleport", "Map '" .. mapName .. "' not in database! Click Refresh to update.", 4)
                return false
            end

            local cframe = moduleData.GetMapSpot(mapName, spotType)
            if not cframe then
                Error("Teleport", "No " .. spotType .. " spot found for " .. mapName, 3)
                return false
            end

            Info("Placing Teleporter", "Placing " .. spotType .. " teleporter for " .. mapName .. "...", 2)
            return placeTeleporter(cframe)
        end
    }
end)()

-- -------------------------------------------------------------------------- --
--                         TELEPORT FEATURES MODULE                           --
-- -------------------------------------------------------------------------- --

local TeleportFeaturesModule = (function()
    local function validateCharacter()
        local success, char = pcall(function()
            return player.Character
        end)
        
        if not success or not char then
            Error("Teleport", "Character not found!", 2)
            return nil, nil
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Error("Teleport", "HumanoidRootPart not found!", 2)
            return nil, nil
        end

        return char, hrp
    end

    local function safeTeleport(hrp, targetPosition, filterInstances)
        filterInstances = filterInstances or {}
        local teleportPos = targetPosition + Vector3.new(0, 5, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = filterInstances
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local raySuccess, ray = pcall(function()
            return workspace:Raycast(teleportPos, Vector3.new(0, -10, 0), raycastParams)
        end)
        
        if raySuccess and ray then
            teleportPos = ray.Position + Vector3.new(0, 3, 0)
        end

        local setSuccess, setErr = pcall(function()
            hrp.CFrame = CFrame.new(teleportPos)
        end)
        
        return setSuccess
    end

    local function findNearestTicketInternal()
        local success, gameFolder = pcall(function()
            return workspace:FindFirstChild("Game")
        end)
        
        if not success or not gameFolder then return nil end

        local effects = gameFolder:FindFirstChild("Effects")
        if not effects then return nil end

        local tickets = effects:FindFirstChild("Tickets")
        if not tickets then return nil end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

        local hrp = char.HumanoidRootPart
        local nearestTicket = nil
        local nearestDistance = math.huge

        for _, ticket in pairs(tickets:GetChildren()) do
            if ticket:IsA("BasePart") or ticket:IsA("Model") then
                local ticketPart = ticket:IsA("Model") and ticket:FindFirstChild("HumanoidRootPart") or ticket
                if ticketPart and ticketPart:IsA("BasePart") then
                    local distSuccess, dist = pcall(function()
                        return (hrp.Position - ticketPart.Position).Magnitude
                    end)
                    if distSuccess and dist and dist < nearestDistance then
                        nearestDistance = dist
                        nearestTicket = ticketPart
                    end
                end
            end
        end

        return nearestTicket
    end

    local function isPlayerDowned(pl)
        local success, result = pcall(function()
            if not pl or not pl.Character then return false end
            local char = pl.Character
            if char:GetAttribute("Downed") then return true end
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health <= 0 then return true end
            return false
        end)
        return success and result or false
    end

    local function findNearestDownedPlayer()
        local char, hrp = validateCharacter()
        if not char or not hrp then return nil end

        local nearestPlayer = nil
        local nearestDistance = math.huge

        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                if isPlayerDowned(pl) then
                    local distSuccess, dist = pcall(function()
                        return (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
                    end)
                    if distSuccess and dist and dist < nearestDistance then
                        nearestDistance = dist
                        nearestPlayer = pl
                    end
                end
            end
        end

        return nearestPlayer, nearestDistance
    end

    local function getPlayerList()
        local playerNames = {}
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= player then
                table.insert(playerNames, pl.Name)
            end
        end
        table.sort(playerNames)
        return #playerNames > 0 and playerNames or { "No players available" }
    end

    return {
        GetPlayerList = getPlayerList,
        TeleportToPlayer = function(playerName)
            if not playerName or playerName == "No players available" then
                Error("Teleport", "No player selected!", 2)
                return false
            end

            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local targetPlayer = Players:FindFirstChild(playerName)
            if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                Error("Teleport", playerName .. " not found or no character!", 2)
                return false
            end

            local targetHRP = targetPlayer.Character.HumanoidRootPart
            safeTeleport(hrp, targetHRP.Position, { char, targetPlayer.Character })
            Success("Teleport", "Teleported to " .. playerName, 2)
            return true
        end,
        TeleportToRandomPlayer = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local players = {}
            for _, pl in pairs(Players:GetPlayers()) do
                if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(players, pl)
                end
            end

            if #players == 0 then
                Error("Teleport", "No other players found!", 2)
                return false
            end

            local randomPlayer = players[math.random(1, #players)]
            local targetHRP = randomPlayer.Character.HumanoidRootPart
            safeTeleport(hrp, targetHRP.Position, { char, randomPlayer.Character })
            Success("Teleport", "Teleported to " .. randomPlayer.Name, 2)
            return true
        end,
        TeleportToNearestDowned = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local nearestPlayer, distance = findNearestDownedPlayer()
            if not nearestPlayer then
                Error("Teleport", "No downed players found!", 2)
                return false
            end

            local targetHRP = nearestPlayer.Character.HumanoidRootPart
            safeTeleport(hrp, targetHRP.Position, { char, nearestPlayer.Character })
            Success("Teleport", "Teleported to " .. nearestPlayer.Name .. " (" .. math.floor(distance) .. " studs)", 2)
            return true
        end,
        TeleportToRandomObjective = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local objectives = {}
            local gameFolder = workspace:FindFirstChild("Game")
            if not gameFolder then
                Error("Teleport", "Game folder not found!", 2)
                return false
            end

            local mapFolder = gameFolder:FindFirstChild("Map")
            if not mapFolder then
                Error("Teleport", "Map folder not found!", 2)
                return false
            end

            local partsFolder = mapFolder:FindFirstChild("Parts")
            if not partsFolder then
                Error("Teleport", "Parts folder not found!", 2)
                return false
            end

            local objectivesFolder = partsFolder:FindFirstChild("Objectives")
            if not objectivesFolder then
                Error("Teleport", "Objectives folder not found!", 2)
                return false
            end

            for _, obj in pairs(objectivesFolder:GetChildren()) do
                if obj:IsA("Model") then
                    local primaryPart = obj.PrimaryPart
                    if not primaryPart then
                        for _, part in pairs(obj:GetChildren()) do
                            if part:IsA("BasePart") then
                                primaryPart = part
                                break
                            end
                        end
                    end

                    if primaryPart then
                        table.insert(objectives, {
                            Name = obj.Name,
                            Part = primaryPart
                        })
                    end
                end
            end

            if #objectives == 0 then
                Error("Teleport", "No objectives found!", 2)
                return false
            end

            local selectedObjective = objectives[math.random(1, #objectives)]
            safeTeleport(hrp, selectedObjective.Part.Position, { char })
            Success("Teleport", "Teleported to " .. selectedObjective.Name, 2)
            return true
        end,
        TeleportToNearestTicket = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local ticket = findNearestTicketInternal()
            if not ticket then
                Error("Teleport", "No tickets found!", 2)
                return false
            end

            safeTeleport(hrp, ticket.Position, { char })
            Success("Teleport", "Teleported to nearest ticket!", 2)
            return true
        end
    }
end)()

-- -------------------------------------------------------------------------- --
--                         SERVER UTILITIES MODULE                            --
-- -------------------------------------------------------------------------- --

local ServerUtils = (function()
    local function getServerLink()
        return string.format("https://www.roblox.com/games/start?placeId=%d&jobId=%s", placeId, jobId)
    end

    local function joinServerByPlaceId(targetPlaceId, modeName)
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                targetPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Join Failed", "Could not fetch " .. modeName .. " servers!", 3)
            return
        end

        local availableServers = {}
        for _, server in ipairs(servers.data) do
            if server.playing < server.maxPlayers then
                table.insert(availableServers, server)
            end
        end

        if #availableServers == 0 then
            Error("Join Failed", "No available " .. modeName .. " servers found!", 3)
            return
        end

        table.sort(availableServers, function(a, b) return a.playing > b.playing end)
        local targetServer = availableServers[1]

        WindUI:Notify({
            Title = "Joining " .. modeName,
            Content = "Teleporting to server with " ..
                targetServer.playing .. "/" .. targetServer.maxPlayers .. " players",
            Duration = 3
        })

        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(targetPlaceId, targetServer.id, player)
        end)

        if not teleportSuccess then
            Error("Join Failed", "Teleport error: " .. tostring(teleportErr), 3)
        end
    end

    local function serverHop(minPlayers)
        minPlayers = minPlayers or 5
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Server Hop", "Failed to fetch servers!", 3)
            return false
        end

        local filteredServers = {}
        for _, server in ipairs(servers.data) do
            if server.playing >= minPlayers and server.playing < server.maxPlayers then
                table.insert(filteredServers, server)
            end
        end

        if #filteredServers == 0 then
            Info("Server Hop", "No servers with " .. minPlayers .. "+ players", 3)
            return false
        end

        local randomServer = filteredServers[math.random(1, #filteredServers)]
        
        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, randomServer.id, player)
        end)

        if not teleportSuccess then
            Error("Server Hop", "Teleport failed: " .. tostring(teleportErr), 3)
            return false
        end

        return true
    end

    local function hopToSmallestServer()
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Server Hop", "Failed to fetch servers!", 3)
            return false
        end

        table.sort(servers.data, function(a, b) return a.playing < b.playing end)
        if not servers.data[1] then
            Error("Server Hop", "No servers found!", 3)
            return false
        end

        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, servers.data[1].id, player)
        end)

        if not teleportSuccess then
            Error("Server Hop", "Teleport failed: " .. tostring(teleportErr), 3)
            return false
        end

        return true
    end

    return {
        GetServerLink = getServerLink,
        JoinServerByPlaceId = joinServerByPlaceId,
        ServerHop = serverHop,
        HopToSmallestServer = hopToSmallestServer
    }
end)()

-- -------------------------------------------------------------------------- --
--                         AUTO PLACE TELEPORTER SYSTEM                       --
-- -------------------------------------------------------------------------- --

local autoPlaceTeleporterEnabled = false
local autoPlaceTeleporterType = "Far"
local gameStats = workspace:WaitForChild("Game"):WaitForChild("Stats")
local gameMap = workspace:WaitForChild("Game"):WaitForChild("Map")

gameStats:GetAttributeChangedSignal("RoundStarted"):Connect(function()
    if not autoPlaceTeleporterEnabled then return end
    local roundStarted = gameStats:GetAttribute("RoundStarted")
    local roundsCompleted = gameStats:GetAttribute("RoundsCompleted") or 0
    if not roundStarted and roundsCompleted < 3 then
        task.spawn(function()
            task.wait(3)
            local character = player.Character or player.CharacterAdded:Wait()
            character:WaitForChild("HumanoidRootPart")
            task.wait(1)
            TeleportModule.PlaceTeleporter(autoPlaceTeleporterType)
            Info("Auto Place", "Round " .. roundsCompleted .. " done", 2)
        end)
    end
end)

-- -------------------------------------------------------------------------- --
--                         NEW FEATURES MODULES                               --
-- -------------------------------------------------------------------------- --

-- 1. NOCLIP MODULE
local NoclipModule = (function()
    local enabled = false
    local connection = nil
    
    local function toggleNoclip(state)
        enabled = state
        
        if enabled then
            if connection then
                pcall(function() connection:Disconnect() end)
            end
            
            connection = RunService.Stepped:Connect(function()
                local character = player.Character
                if character then
                    for _, part in pairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            pcall(function() part.CanCollide = false end)
                        end
                    end
                end
            end)
        else
            if connection then
                pcall(function() connection:Disconnect() end)
                connection = nil
            end
            
            local character = player.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part.CanCollide = true end)
                    end
                end
            end
        end
    end
    
    return {
        Start = function() toggleNoclip(true) end,
        Stop = function() toggleNoclip(false) end,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(0.5)
                toggleNoclip(false)
                task.wait(0.1)
                toggleNoclip(true)
            end
        end
    }
end)()

-- 2. BUG EMOTE (FORCE SIT) MODULE
local BugEmoteModule = (function()
    local enabled = false
    local connection = nil
    
    local function updateSit()
        if not enabled then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not humanoid then
            local gamePlayers = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players")
            if gamePlayers then
                local playerModel = gamePlayers:FindFirstChild(player.Name)
                if playerModel then
                    humanoid = playerModel:FindFirstChild("Humanoid")
                end
            end
        end
        
        if humanoid then
            pcall(function() humanoid.Sit = true end)
        end
    end
    
    local function start()
        if enabled then return end
        enabled = true
        
        if connection then
            pcall(function() connection:Disconnect() end)
        end
        
        connection = RunService.Heartbeat:Connect(updateSit)
        updateSit()
        Success("Bug Emote", "Force sit enabled", 2)
    end
    
    local function stop()
        if not enabled then return end
        enabled = false
        
        if connection then
            pcall(function() connection:Disconnect() end)
            connection = nil
        end
        
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid then
                local gamePlayers = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players")
                if gamePlayers then
                    local playerModel = gamePlayers:FindFirstChild(player.Name)
                    if playerModel then
                        humanoid = playerModel:FindFirstChild("Humanoid")
                    end
                end
            end
            if humanoid then
                pcall(function() humanoid.Sit = false end)
            end
        end
        
        Info("Bug Emote", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(1)
                updateSit()
            end
        end
    }
end)()

-- 3. REMOVE BARRIERS MODULE
local RemoveBarriersModule = (function()
    local enabled = false
    
    local function toggleBarriers(state)
        local success, invisParts = pcall(function()
            return workspace:FindFirstChild("Game") and 
                   workspace.Game:FindFirstChild("Map") and 
                   workspace.Game.Map:FindFirstChild("InvisParts")
        end)
        
        if not success or not invisParts then
            return
        end
        
        local objectsChanged = 0
        
        for _, obj in ipairs(invisParts:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.CanCollide = not state
                    obj.CanQuery = not state
                end)
                objectsChanged = objectsChanged + 1
            end
        end
        
        if state then
            Success("Remove Barriers", "Barriers removed for " .. objectsChanged .. " objects", 2)
        else
            Info("Remove Barriers", "Barriers restored for " .. objectsChanged .. " objects", 2)
        end
    end
    
    return {
        Start = function()
            enabled = true
            toggleBarriers(true)
        end,
        Stop = function()
            enabled = false
            toggleBarriers(false)
        end,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(1)
                toggleBarriers(true)
            end
        end
    }
end)()

-- 4. BARRIERS VISIBLE MODULE
local BarriersVisibleModule = (function()
    local enabled = false
    local descendantConnection = nil
    local barrierColor = Color3.fromRGB(255, 0, 0)
    local barrierTransparency = 0
    
    local function setTransparency(transparent)
        local success, invisParts = pcall(function()
            return workspace:FindFirstChild("Game") and 
                   workspace.Game:FindFirstChild("Map") and 
                   workspace.Game.Map:FindFirstChild("InvisParts")
        end)
        
        if not success or not invisParts then
            return 0
        end
        
        local changed = 0
        
        if transparent then
            for _, obj in ipairs(invisParts:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") then
                        obj.Transparency = barrierTransparency
                        obj.Color = barrierColor
                        obj.Material = Enum.Material.Neon
                        changed = changed + 1
                    elseif obj:IsA("Decal") then
                        obj.Transparency = barrierTransparency
                        changed = changed + 1
                    end
                end)
            end
            Success("Barriers Visible", "Made " .. changed .. " barriers visible (" .. math.floor(barrierTransparency * 100) .. "% transparency)", 2)
        else
            for _, obj in ipairs(invisParts:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") or obj:IsA("Decal") then
                        obj.Transparency = 1
                        if obj:IsA("BasePart") then
                            obj.Color = Color3.fromRGB(255, 255, 255)
                            obj.Material = Enum.Material.Plastic
                        end
                        changed = changed + 1
                    end
                end)
            end
            Info("Barriers Visible", "Made " .. changed .. " barriers invisible", 2)
        end
        
        return changed
    end
    
    local function setupDescendantListener()
        if descendantConnection then
            pcall(function() descendantConnection:Disconnect() end)
        end
        
        local success, invisParts = pcall(function()
            return workspace:FindFirstChild("Game") and 
                   workspace.Game:FindFirstChild("Map") and 
                   workspace.Game.Map:FindFirstChild("InvisParts")
        end)
        
        if success and invisParts and enabled then
            descendantConnection = invisParts.DescendantAdded:Connect(function(obj)
                if enabled then
                    task.wait(0.05)
                    pcall(function()
                        if obj:IsA("BasePart") then
                            obj.Transparency = barrierTransparency
                            obj.Color = barrierColor
                            obj.Material = Enum.Material.Neon
                        elseif obj:IsA("Decal") then
                            obj.Transparency = barrierTransparency
                        end
                    end)
                end
            end)
        end
    end
    
    local function setColor(color)
        barrierColor = color
        if enabled then
            setTransparency(true)
        end
    end
    
    local function setTransparencyLevel(level)
        local transparencyMap = {
            [1] = 0,     [2] = 0.2,   [3] = 0.4,   [4] = 0.5,   [5] = 0.6,
            [6] = 0.7,   [7] = 0.8,   [8] = 0.85,  [9] = 0.9,   [10] = 0.95,
        }
        
        barrierTransparency = transparencyMap[level] or 0
        if enabled then
            setTransparency(true)
        end
        return barrierTransparency
    end
    
    return {
        Start = function()
            enabled = true
            setTransparency(true)
            setupDescendantListener()
        end,
        Stop = function()
            enabled = false
            setTransparency(false)
            if descendantConnection then
                pcall(function() descendantConnection:Disconnect() end)
                descendantConnection = nil
            end
        end,
        SetColor = setColor,
        SetTransparencyLevel = setTransparencyLevel,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(1)
                setTransparency(true)
            end
        end
    }
end)()


-- 6. GRAPPLEHOOK MODULE (DENGAN ERROR HANDLING)
local GrapplehookModule = (function()
    local function enhanceGrappleHook()
        local success, result = pcall(function()
            local GrappleHook = require(ReplicatedStorage.Tools["GrappleHook"])
            
            if not GrappleHook then
                error("GrappleHook module not found")
            end
            
            local grappleTask = GrappleHook.Tasks[2]
            if not grappleTask then
                error("GrappleTask not found")
            end
            
            local shootMethod = grappleTask.Functions[1].Activations[1].Methods[1]
            if not shootMethod then
                error("Shoot method not found")
            end

            shootMethod.Info.Speed = 10000
            shootMethod.Info.Lifetime = 10.0
            shootMethod.Info.Gravity = Vector3.new(0, 0, 0)
            shootMethod.Info.SpreadIncrease = 0
            shootMethod.Info.Cooldown = 0.2

            grappleTask.MethodReferences.Projectile.Info.SpreadInfo.MaxSpread = 0
            grappleTask.MethodReferences.Projectile.Info.SpreadInfo.MinSpread = 0
            grappleTask.MethodReferences.Projectile.Info.SpreadInfo.ReductionRate = 100

            local checkMethod = grappleTask.AutomaticFunctions[1].Methods[1]
            if checkMethod then
                checkMethod.Info.Cooldown = 0.2
                checkMethod.CooldownInfo.TestCooldown = 0.2
            end

            grappleTask.ResourceInfo.Cap = 200
            grappleTask.ResourceInfo.Reserve = 200

            return true
        end)
        
        if success then
            Success("Grapplehook", "Enhanced successfully!", 2)
            return true
        else
            Error("Grapplehook", "Failed to enhance: " .. tostring(result), 3)
            warn("Grapplehook error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceGrappleHook()
        end
    }
end)()

-- 7. BREACHER MODULE (DENGAN ERROR HANDLING)
local BreacherModule = (function()
    local function enhanceBreacher()
        local success, result = pcall(function()
            local Breacher = require(ReplicatedStorage.Tools.Breacher)
            
            if not Breacher then
                error("Breacher module not found")
            end

            local portalTask
            for i, task in ipairs(Breacher.Tasks) do
                if task.ResourceInfo and task.ResourceInfo.Type == "Clip" then
                    portalTask = task
                    break
                end
            end

            if not portalTask then
                portalTask = Breacher.Tasks[2]
            end

            portalTask.ResourceInfo.Cap = 400

            local blueShoot = portalTask.Functions[1].Activations[1].Methods[1]
            local yellowShoot = portalTask.Functions[2].Activations[1].Methods[1]

            blueShoot.Info.Range = 99999999
            yellowShoot.Info.Range = 99999999

            blueShoot.Info.SpreadIncrease = 0
            yellowShoot.Info.SpreadIncrease = 0

            portalTask.MethodReferences.Portal.Info.SpreadInfo.MaxSpread = 0
            portalTask.MethodReferences.Portal.Info.SpreadInfo.MinSpread = 0
            portalTask.MethodReferences.Portal.Info.SpreadInfo.ReductionRate = 100

            blueShoot.Info.Cooldown = 0.4
            yellowShoot.Info.Cooldown = 0.4

            blueShoot.CooldownInfo = {}
            yellowShoot.CooldownInfo = {}
            blueShoot.Requirements = {}
            yellowShoot.Requirements = {}

            Breacher.Actions.ADS.Enabled = false

            portalTask.Functions[1].Activations[1].CanHoldDown = true
            portalTask.Functions[2].Activations[1].CanHoldDown = true

            return true
        end)
        
        if success then
            Success("Breacher", "Portal Gun enhanced successfully!", 2)
            return true
        else
            Error("Breacher", "Failed to enhance: " .. tostring(result), 3)
            warn("Breacher error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceBreacher()
        end
    }
end)()

-- 8. SMOKE GRENADE MODULE (DENGAN ERROR HANDLING)
local SmokeGrenadeModule = (function()
    local function enhanceSmokeGrenade()
        local success, result = pcall(function()
            local SmokeGrenade = require(ReplicatedStorage.Tools["SmokeGrenade"])
            
            if not SmokeGrenade then
                error("SmokeGrenade module not found")
            end

            SmokeGrenade.RequiresOwnedItem = false

            local throwMethod = SmokeGrenade.Tasks[1].Functions[1].Activations[1].Methods[1]

            throwMethod.ItemUseIncrement = {"SmokeGrenade", 0}
            throwMethod.Info.Cooldown = 0.5
            throwMethod.Info.ThrowVelocity = 200

            SmokeGrenade.Tasks[1].Functions[1].Activations[1].CanHoldDown = true

            throwMethod.Info.SmokeDuration = 999
            throwMethod.Info.SmokeRadius = 100
            throwMethod.Info.FadeTime = 60

            local equipMethod = SmokeGrenade.Tasks[1].AutomaticFunctions[1].Methods[1]
            local unequipMethod = SmokeGrenade.Tasks[1].AutomaticFunctions[2].Methods[1]
            equipMethod.Info.Cooldown = 0.5
            unequipMethod.Info.Cooldown = 0.5

            throwMethod.CooldownInfo = {}

            return true
        end)
        
        if success then
            Success("Smoke Grenade", "Enhanced successfully!", 2)
            return true
        else
            Error("Smoke Grenade", "Failed to enhance: " .. tostring(result), 3)
            warn("Smoke Grenade error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceSmokeGrenade()
        end
    }
end)()


-- -------------------------------------------------------------------------- --
--                        9. MOVEMENT FEATURES MODULE                          --
--                       Infinite Slide & Bunny Hop                            --
-- -------------------------------------------------------------------------- --

local MovementFeaturesModule = (function()
    -- ==================== VARIABEL ====================
    -- Infinite Slide
    local infiniteSlideEnabled = false
    local slideFrictionValue = -8
    local movementTables = {}
    local infiniteSlideHeartbeat = nil
    local infiniteSlideCharacterConn = nil
    
    -- Bunny Hop
    local bhopEnabled = false
    local bhopMode = "Bounce"
    local jumpCooldown = 0.7
    local bhopConnection = nil
    local lastJump = 0
    local bhopHoldActive = false
    
    -- Constants
    local GROUND_CHECK_OFFSET = 3.5
    local GROUND_CHECK_RAY_LENGTH = 4
    local MAX_SLOPE_ANGLE = 45
    
    -- Required keys
    local requiredKeys = {
        "Friction", "AirStrafeAcceleration", "JumpHeight", "RunDeaccel",
        "JumpSpeedMultiplier", "JumpCap", "SprintCap", "WalkSpeedMultiplier",
        "BhopEnabled", "Speed", "AirAcceleration", "RunAccel", "SprintAcceleration"
    }
    
    -- ==================== INFINITE SLIDE FUNCTIONS ====================
    
    local function hasRequiredFields(tbl)
        if typeof(tbl) ~= "table" then return false end
        for _, key in ipairs(requiredKeys) do
            if rawget(tbl, key) == nil then return false end
        end
        return true
    end
    
    local function findMovementTables()
        movementTables = {}
        for _, obj in ipairs(getgc(true)) do
            if hasRequiredFields(obj) then
                table.insert(movementTables, obj)
            end
        end
        return #movementTables > 0
    end
    
    local function setSlideFriction(value)
        local appliedCount = 0
        for _, tbl in ipairs(movementTables) do
            pcall(function()
                tbl.Friction = value
                appliedCount = appliedCount + 1
            end)
        end
        return appliedCount
    end
    
    local function getPlayerModel()
        local gameFolder = workspace:FindFirstChild("Game")
        if not gameFolder then return nil end
        local playersFolder = gameFolder:FindFirstChild("Players")
        if not playersFolder then return nil end
        return playersFolder:FindFirstChild(player.Name)
    end
    
    local function infiniteSlideHeartbeatFunc()
        if not infiniteSlideEnabled then return end
        local playerModel = getPlayerModel()
        if not playerModel then return end
        local state = playerModel:GetAttribute("State")
        
        if state == "Slide" then
            pcall(function()
                playerModel:SetAttribute("State", "EmotingSlide")
            end)
        elseif state == "EmotingSlide" then
            setSlideFriction(slideFrictionValue)
        else
            setSlideFriction(5)
        end
    end
    
    local function onCharacterAddedSlide(character)
        if not infiniteSlideEnabled then return end
        for i = 1, 5 do
            task.wait(0.5)
            if getPlayerModel() then break end
        end
        task.wait(0.5)
        findMovementTables()
    end
    
    local function toggleInfiniteSlide(state)
        infiniteSlideEnabled = state
        
        if state then
            findMovementTables()
            if not infiniteSlideCharacterConn then
                infiniteSlideCharacterConn = player.CharacterAdded:Connect(onCharacterAddedSlide)
            end
            if player.Character then
                task.spawn(function() onCharacterAddedSlide(player.Character) end)
            end
            if infiniteSlideHeartbeat then infiniteSlideHeartbeat:Disconnect() end
            infiniteSlideHeartbeat = RunService.Heartbeat:Connect(infiniteSlideHeartbeatFunc)
            Success("Infinite Slide", "Activated (Speed: " .. slideFrictionValue .. ")", 2)
        else
            if infiniteSlideHeartbeat then
                infiniteSlideHeartbeat:Disconnect()
                infiniteSlideHeartbeat = nil
            end
            setSlideFriction(5)
            movementTables = {}
            Info("Infinite Slide", "Deactivated", 2)
        end
        return infiniteSlideEnabled
    end
    
    local function setSlideSpeed(value)
        local num = tonumber(value)
        if num then
            slideFrictionValue = num
            if infiniteSlideEnabled then
                setSlideFriction(slideFrictionValue)
                Success("Slide Speed", "Set to: " .. num, 1)
            end
            return true
        end
        return false
    end
    
    -- ==================== BUNNY HOP FUNCTIONS ====================
    
    local function IsOnGround(character, humanoid, rootPart)
        if not character or not humanoid or not rootPart then return false end
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Jumping or 
           state == Enum.HumanoidStateType.Freefall or
           state == Enum.HumanoidStateType.Swimming then
            return false
        end
        if humanoid:GetState() == Enum.HumanoidStateType.Running then
            return true
        end
        
        local rayOrigin = rootPart.Position
        local rayDirection = Vector3.new(0, -GROUND_CHECK_RAY_LENGTH, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {character}
        raycastParams.IgnoreWater = true
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        if raycastResult then
            local surfaceNormal = raycastResult.Normal
            local angle = math.deg(math.acos(surfaceNormal:Dot(Vector3.new(0, 1, 0))))
            if angle <= MAX_SLOPE_ANGLE then
                local heightDiff = math.abs(rayOrigin.Y - raycastResult.Position.Y)
                return heightDiff <= GROUND_CHECK_OFFSET
            end
        end
        if rootPart.Velocity.Y > -1 and rootPart.Velocity.Y < 1 then
            return true
        end
        return false
    end
    
    local function updateBhop()
        if not bhopEnabled and not bhopHoldActive then return end
        local character = player.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return end
        if humanoid:GetState() == Enum.HumanoidStateType.Dead then return end
        
        local now = tick()
        if IsOnGround(character, humanoid, rootPart) and (now - lastJump) > jumpCooldown then
            if bhopMode == "Realistic" then
                pcall(function()
                    player.PlayerScripts.Events.temporary_events.JumpReact:Fire()
                    task.wait(0.05)
                    player.PlayerScripts.Events.temporary_events.EndJump:Fire()
                end)
            else
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            lastJump = now
        end
    end
    
    local function toggleBhop(state)
        bhopEnabled = state
        if state or bhopHoldActive then
            if not bhopConnection then
                bhopConnection = RunService.Heartbeat:Connect(updateBhop)
            end
        else
            if bhopConnection and not bhopHoldActive then
                bhopConnection:Disconnect()
                bhopConnection = nil
            end
        end
        return bhopEnabled
    end
    
    local function setBhopMode(mode)
        bhopMode = mode
        if bhopEnabled then
        end
        return true
    end
    
    local function setJumpCooldown(value)
        local num = tonumber(value)
        if num and num > 0 then
            jumpCooldown = num
            if bhopEnabled then
            end
            return true
        end
        return false
    end
    
    local function setBhopHoldActive(active)
        bhopHoldActive = active
        toggleBhop(bhopEnabled)
    end
    
    -- ==================== SETUP ====================
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Space then
            setBhopHoldActive(true)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space then
            setBhopHoldActive(false)
        end
    end)
    
    player.CharacterAdded:Connect(function(character)
        onCharacterAddedSlide(character)
        if bhopEnabled or bhopHoldActive then
            task.wait(1)
            lastJump = 0
        end
    end)
    
    player.CharacterRemoving:Connect(function()
        lastJump = 0
    end)
    
    Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            if infiniteSlideHeartbeat then infiniteSlideHeartbeat:Disconnect() end
            if infiniteSlideCharacterConn then infiniteSlideCharacterConn:Disconnect() end
            if bhopConnection then bhopConnection:Disconnect() end
        end
    end)
    
    task.spawn(function()
        task.wait(2)
        findMovementTables()
    end)
    
    -- ==================== PUBLIC API ====================
    return {
        ToggleInfiniteSlide = toggleInfiniteSlide,
        SetSlideSpeed = setSlideSpeed,
        IsInfiniteSlideEnabled = function() return infiniteSlideEnabled end,
        GetSlideSpeed = function() return slideFrictionValue end,
        
        ToggleBhop = toggleBhop,
        SetBhopMode = setBhopMode,
        SetJumpCooldown = setJumpCooldown,
        IsBhopEnabled = function() return bhopEnabled end,
        GetBhopMode = function() return bhopMode end,
        GetJumpCooldown = function() return jumpCooldown end,
    }
end)()

-- -------------------------------------------------------------------------- --
--                        10. UNLOCK LEADERBOARD MODULE                        --
--                         (Front View & Leaderboard Only)                     --
--                              (Layout di Kiri)                                --
-- -------------------------------------------------------------------------- --

local UnlockLeaderboardModule = (function()
    local buttonGui = nil
    local player = game:GetService("Players").LocalPlayer
    local TweenService = game:GetService("TweenService")
    local StarterGui = game:GetService("StarterGui")
    
    local function createLeaderboardUI()
        -- Hapus GUI lama jika ada
        if buttonGui and buttonGui.Parent then
            pcall(function() buttonGui:Destroy() end)
        end
        
        local playerGui = player:WaitForChild("PlayerGui")
        
        -- Cek apakah sudah ada
        local existing = playerGui:FindFirstChild("CustomTopGui")
        if existing then
            existing:Destroy()
        end
        
        -- Nonaktifkan topbar bawaan
        pcall(function()
            StarterGui:SetCore("TopbarEnabled", false)
        end)
        
        -- Buat ScreenGui utama
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CustomTopGui"
        screenGui.IgnoreGuiInset = false
        screenGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
        screenGui.DisplayOrder = 100
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
        buttonGui = screenGui
        
        -- Container untuk button (di kiri)
        local container = Instance.new("Frame")
        container.Name = "ButtonContainer"
        container.Parent = screenGui
        container.BackgroundTransparency = 1
        container.Size = UDim2.new(1, -20, 1, 0)
        container.Position = UDim2.new(0, 10, 0, 10)
        
        -- Layout horizontal dengan alignment kiri
        local layout = Instance.new("UIListLayout")
        layout.Parent = container
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Padding = UDim.new(0, 8)
        
        -- Konfigurasi button (hanya 2)
        local buttonsConfig = {
            {
                name = "FrontViewButton",
                icon = "rbxassetid://78648212535999",
                label = "Front View",
                keys = {"Reload", "FrontView", "View"},
                color = Color3.fromRGB(45, 45, 45)
            },
            {
                name = "LeaderboardButton",
                icon = "rbxassetid://5107166345",
                label = "Leaderboard",
                keys = {"Leaderboard", "Scoreboard"},
                color = Color3.fromRGB(45, 45, 45)
            }
        }
        
        -- Fungsi untuk trigger keybind
        local function triggerKey(key, state)
            pcall(function()
                local useKeybind = player.PlayerScripts.Events.temporary_events.UseKeybind
                if useKeybind then
                    useKeybind:Fire({Key = key, Down = state})
                end
            end)
        end
        
        -- Buat button
        for _, config in ipairs(buttonsConfig) do
            -- Frame button utama
            local btnFrame = Instance.new("Frame")
            btnFrame.Name = config.name
            btnFrame.Parent = container
            btnFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            btnFrame.BackgroundTransparency = 0.3
            btnFrame.BorderSizePixel = 0
            btnFrame.Size = UDim2.new(0, 44, 0, 44)
            btnFrame.ZIndex = 10
            
            -- Sudut bulat
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = btnFrame
            
            -- Icon
            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.Parent = btnFrame
            icon.BackgroundTransparency = 1
            icon.Size = UDim2.new(0.7, 0, 0.7, 0)
            icon.Position = UDim2.new(0.15, 0, 0.15, 0)
            icon.Image = config.icon
            icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            icon.ZIndex = 11
            
            -- Tombol klik
            local clickBtn = Instance.new("TextButton")
            clickBtn.Name = "ClickButton"
            clickBtn.Parent = btnFrame
            clickBtn.BackgroundTransparency = 1
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.ZIndex = 20
            clickBtn.Text = ""
            clickBtn.AutoButtonColor = false
            
            -- Label yang muncul saat hover
            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.Parent = btnFrame
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 0, 1, 5)
            label.Size = UDim2.new(1, 0, 0, 16)
            label.Font = Enum.Font.GothamBold
            label.Text = config.label
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextSize = 12
            label.TextStrokeTransparency = 0.5
            label.ZIndex = 12
            label.Visible = false
            
            -- Hover effect
            clickBtn.MouseEnter:Connect(function()
                btnFrame.BackgroundTransparency = 0
                label.Visible = true
            end)
            
            clickBtn.MouseLeave:Connect(function()
                btnFrame.BackgroundTransparency = 0.3
                label.Visible = false
            end)
            
            -- Klik handler
            clickBtn.MouseButton1Down:Connect(function()
                btnFrame.BackgroundTransparency = 0.5
                for _, key in ipairs(config.keys) do
                    triggerKey(key, true)
                end
            end)
            
            clickBtn.MouseButton1Up:Connect(function()
                btnFrame.BackgroundTransparency = 0
                for _, key in ipairs(config.keys) do
                    triggerKey(key, false)
                end
            end)
            
            clickBtn.MouseLeave:Connect(function()
                btnFrame.BackgroundTransparency = 0.3
                label.Visible = false
                for _, key in ipairs(config.keys) do
                    triggerKey(key, false)
                end
            end)
        end
        
        return screenGui
    end
    
    local function destroyLeaderboardUI()
        if buttonGui and buttonGui.Parent then
            pcall(function() buttonGui:Destroy() end)
            buttonGui = nil
        end
        
        -- Kembalikan topbar bawaan
        pcall(function()
            StarterGui:SetCore("TopbarEnabled", true)
        end)
    end
    
    return {
        Create = function()
            local success, err = pcall(createLeaderboardUI)
            if success then
                Success("Leaderboard", "Custom UI created!", 2)
                return true
            else
                Error("Leaderboard", "Failed: " .. tostring(err), 3)
                return false
            end
        end,
        Destroy = destroyLeaderboardUI,
        Toggle = function()
            if buttonGui and buttonGui.Parent then
                destroyLeaderboardUI()
                Info("Leaderboard", "Custom UI destroyed", 2)
            else
                createLeaderboardUI()
                Success("Leaderboard", "Custom UI created!", 2)
            end
        end
    }
end)()

-- -------------------------------------------------------------------------- --
--                         FLY MODULE                                         --
-- -------------------------------------------------------------------------- --

local FlyModule = (function()
    local flying = false
    local bodyVelocity = nil
    local bodyGyro = nil
    local flyLoop = nil
    local characterAddedConnection = nil
    local flySpeed = 50
    
    local function startFlying()
        local character = player.Character
        if not character then 
            Error("Fly System", "No character found!", 2)
            return false 
        end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then 
            Error("Fly System", "Humanoid or RootPart not found!", 2)
            return false 
        end
        
        flying = true
        
        local success, err = pcall(function()
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.Parent = rootPart
            
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bodyGyro.CFrame = rootPart.CFrame
            bodyGyro.Parent = rootPart
            
            humanoid.PlatformStand = true
        end)
        
        if success then
            Success("Fly System", "Flying activated! (Speed: " .. flySpeed .. ")", 2)
        else
            Error("Fly System", "Failed to start: " .. tostring(err), 2)
            return false
        end
        
        return true
    end
    
    local function stopFlying()
        flying = false
        
        if bodyVelocity then
            pcall(function() bodyVelocity:Destroy() end)
            bodyVelocity = nil
        end
        if bodyGyro then
            pcall(function() bodyGyro:Destroy() end)
            bodyGyro = nil
        end
        
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                pcall(function() humanoid.PlatformStand = false end)
            end
        end
        
        Info("Fly System", "Flying deactivated", 2)
    end
    
    local function updateFly()
        if not flying then return end
        if not bodyVelocity or not bodyGyro then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then return end
        
        local camera = workspace.CurrentCamera
        if not camera then return end
        
        local cameraCFrame = camera.CFrame
        local direction = Vector3.new(0, 0, 0)
        local moveDirection = humanoid.MoveDirection
        
        if moveDirection.Magnitude > 0 then
            local forwardVector = cameraCFrame.LookVector
            local rightVector = cameraCFrame.RightVector
            local forwardComponent = moveDirection:Dot(forwardVector) * forwardVector
            local rightComponent = moveDirection:Dot(rightVector) * rightVector
            direction = direction + (forwardComponent + rightComponent).Unit * moveDirection.Magnitude
        end
        
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            direction = direction - Vector3.new(0, 1, 0)
        end
        
        pcall(function()
            if direction.Magnitude > 0 then
                bodyVelocity.Velocity = direction.Unit * (flySpeed * 2)
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
            bodyGyro.CFrame = cameraCFrame
        end)
    end
    
    local function toggleFly(state)
        if state then
            if characterAddedConnection then
                pcall(function() characterAddedConnection:Disconnect() end)
            end
            
            characterAddedConnection = player.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                if flying == false and state then
                    startFlying()
                end
            end)
            
            startFlying()
            
            if not flyLoop then
                flyLoop = RunService.RenderStepped:Connect(function()
                    if state then
                        updateFly()
                    end
                end)
            end
            
        else
            stopFlying()
            
            if flyLoop then
                pcall(function() flyLoop:Disconnect() end)
                flyLoop = nil
            end
            
            if characterAddedConnection then
                pcall(function() characterAddedConnection:Disconnect() end)
                characterAddedConnection = nil
            end
        end
    end
    
    local function setFlySpeed(speed)
        local num = tonumber(speed)
        if num and num > 0 then
            flySpeed = num
            if flying then
                Success("Fly System", "Speed set to: " .. flySpeed, 1)
            end
            return true
        end
        return false
    end
    
    player.CharacterRemoving:Connect(function()
        if flying then
            stopFlying()
            if flyLoop then
                pcall(function() flyLoop:Disconnect() end)
                flyLoop = nil
            end
        end
    end)
    
    return {
        Toggle = toggleFly,
        SetSpeed = setFlySpeed,
        GetSpeed = function() return flySpeed end,
        IsFlying = function() return flying end,
        Stop = function() 
            if flying then
                toggleFly(false)
            end
        end,
        OnCharacterAdded = function()
            if flying then
                task.wait(1)
                startFlying()
            end
        end
    }
end)()

-- -------------------------------------------------------------------------- --
--                         VISUAL FEATURES MODULE                             --
-- -------------------------------------------------------------------------- --

local VisualFeaturesModule = (function()
    local originalValues = {
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        GlobalShadows = Lighting.GlobalShadows,
        Atmospheres = {}
    }

    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then
            table.insert(originalValues.Atmospheres, v:Clone())
        end
    end

    -- FAKE STREAKS
    local function setFakeStreak(value)
        local num = tonumber(value)
        if num then
            local success, err = pcall(function()
                player:SetAttribute("Streak", num)
            end)
            if success then
                Success("Fake Streak", "Streak set to: " .. num, 1)
                return true
            else
                Error("Fake Streak", "Failed to set streak", 1)
                return false
            end
        end
        return false
    end

    local function resetStreak()
        local success, err = pcall(function()
            player:SetAttribute("Streak", nil)
        end)
        if success then
            Success("Fake Streak", "Streak has been reset", 1)
        else
            Error("Fake Streak", "Failed to reset streak", 1)
        end
    end

    -- CAMERA STRETCH
    local cameraStretchConnection = nil
    local stretchHorizontal = 0.80
    local stretchVertical = 0.80
    local stretchEnabled = false

    local function applyCameraStretch()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CFrame = Camera.CFrame * CFrame.new(
                0, 0, 0,
                stretchHorizontal, 0, 0,
                0, stretchVertical, 0,
                0, 0, 1
            )
        end
    end

    local function setupCameraStretch()
        if cameraStretchConnection then
            pcall(function() cameraStretchConnection:Disconnect() end)
        end
        cameraStretchConnection = RunService.RenderStepped:Connect(applyCameraStretch)
    end

    local function toggleCameraStretch(state)
        stretchEnabled = state
        if state then
            setupCameraStretch()
            Success("Camera Stretch", "Activated (H: " .. stretchHorizontal .. ", V: " .. stretchVertical .. ")", 2)
        else
            if cameraStretchConnection then
                pcall(function() cameraStretchConnection:Disconnect() end)
                cameraStretchConnection = nil
            end
            Info("Camera Stretch", "Deactivated", 2)
        end
    end

    local function setStretchHorizontal(value)
        local num = tonumber(value)
        if num and num > 0 then
            stretchHorizontal = num
            if stretchEnabled then
                Success("Stretch H", "Set to: " .. stretchHorizontal, 1)
            end
            return true
        end
        return false
    end

    local function setStretchVertical(value)
        local num = tonumber(value)
        if num and num > 0 then
            stretchVertical = num
            if stretchEnabled then
                Success("Stretch V", "Set to: " .. stretchVertical, 1)
            end
            return true
        end
        return false
    end

    -- FULL BRIGHT
    local fullBrightEnabled = false

    local function applyFullBright()
        pcall(function()
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.new(1, 1, 1)
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
            Lighting.ColorShift_Top = Color3.new(1, 1, 1)
            Lighting.GlobalShadows = false
            
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    v:Destroy()
                end
            end
        end)
    end

    local function restoreLighting()
        pcall(function()
            Lighting.Brightness = originalValues.Brightness
            Lighting.Ambient = originalValues.Ambient
            Lighting.OutdoorAmbient = originalValues.OutdoorAmbient
            Lighting.ColorShift_Bottom = originalValues.ColorShift_Bottom
            Lighting.ColorShift_Top = originalValues.ColorShift_Top
            Lighting.GlobalShadows = originalValues.GlobalShadows
            
            for _, atmosphere in ipairs(originalValues.Atmospheres) do
                local newAtmosphere = Instance.new("Atmosphere")
                for _, prop in pairs({"Density", "Offset", "Color", "Decay", "Glare", "Haze"}) do
                    if atmosphere[prop] then
                        newAtmosphere[prop] = atmosphere[prop]
                    end
                end
                newAtmosphere.Parent = Lighting
            end
        end)
    end

    local function toggleFullBright(state)
        fullBrightEnabled = state
        
        if state then
            applyFullBright()
            Success("Full Bright", "Activated", 2)
        else
            restoreLighting()
            Info("Full Bright", "Deactivated", 2)
        end
    end

    -- ANTI LAG
    local function antiLag1()
        task.spawn(function()
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 1e10
                Lighting.Brightness = 1
                
                local Terrain = workspace:FindFirstChildOfClass("Terrain")
                if Terrain then
                    Terrain.WaterWaveSize = 0
                    Terrain.WaterWaveSpeed = 0
                    Terrain.WaterReflectance = 0
                    Terrain.WaterTransparency = 1
                end
                
                local partsChanged = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.Material = Enum.Material.Plastic
                        obj.Reflectance = 0
                        partsChanged = partsChanged + 1
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj:Destroy()
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                        obj.Enabled = false
                    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                        obj.Enabled = false
                    end
                end
                
                Success("Anti Lag 1", "Optimasi ringan selesai! (" .. partsChanged .. " parts)", 3)
            end)
        end)
    end

    local function antiLag2()
        task.spawn(function()
            pcall(function()
                local stats = {
                    parts = 0, particles = 0, effects = 0, textures = 0, sky = 0
                }
                
                for _, v in next, game:GetDescendants() do
                    if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("BasePart") then
                        v.Material = Enum.Material.SmoothPlastic
                        stats.parts = stats.parts + 1
                    end
                    
                    if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Explosion") or v:IsA("Sparkles") or v:IsA("Fire") then
                        v.Enabled = false
                        stats.particles = stats.particles + 1
                    end
                    
                    if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
                        v.Enabled = false
                        stats.effects = stats.effects + 1
                    end
                    
                    if v:IsA("Decal") or v:IsA("Texture") then
                        v.Texture = ""
                        stats.textures = stats.textures + 1
                    end
                    
                    if v:IsA("Sky") then
                        v.Parent = nil
                        stats.sky = stats.sky + 1
                    end
                end
                
                Success("Anti Lag 2", "Optimasi agresif selesai!", 3)
            end)
        end)
    end

    local function antiLag3()
        task.spawn(function()
            pcall(function()
                local texturesRemoved = 0
                local decalsRemoved = 0
                
                for _, part in ipairs(workspace:GetDescendants()) do
                    if part:IsA("Part") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
                        if part:IsA("Part") then
                            part.Material = Enum.Material.SmoothPlastic
                        end
                        
                        local texture = part:FindFirstChildWhichIsA("Texture")
                        if texture then
                            texture.Texture = "rbxassetid://0"
                            texturesRemoved = texturesRemoved + 1
                        end
                        
                        local decal = part:FindFirstChildWhichIsA("Decal")
                        if decal then
                            decal.Texture = "rbxassetid://0"
                            decalsRemoved = decalsRemoved + 1
                        end
                    end
                end
                
                Success("Anti Lag 3", "Textures: " .. texturesRemoved .. ", Decals: " .. decalsRemoved .. " cleared", 3)
            end)
        end)
    end

    -- REMOVE FOG
    local removeFogEnabled = false

    local function applyRemoveFog()
        pcall(function()
            Lighting.FogEnd = 1000000
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    v:Destroy()
                end
            end
        end)
    end

    local function restoreFog()
        pcall(function()
            Lighting.FogEnd = originalValues.FogEnd
            for _, atmosphere in ipairs(originalValues.Atmospheres) do
                local newAtmosphere = Instance.new("Atmosphere")
                for _, prop in pairs({"Density", "Offset", "Color", "Decay", "Glare", "Haze"}) do
                    if atmosphere[prop] then
                        newAtmosphere[prop] = atmosphere[prop]
                    end
                end
                newAtmosphere.Parent = Lighting
            end
        end)
    end

    local function toggleRemoveFog(state)
        removeFogEnabled = state
        
        if state then
            applyRemoveFog()
            Success("Remove Fog", "Activated", 2)
        else
            restoreFog()
            Info("Remove Fog", "Deactivated", 2)
        end
    end

    -- RESPAWN HANDLER
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if fullBrightEnabled then
            applyFullBright()
        end
        if removeFogEnabled then
            applyRemoveFog()
        end
    end)

    return {
        -- Fake Streak
        SetFakeStreak = setFakeStreak,
        ResetStreak = resetStreak,
        
        -- Camera Stretch
        ToggleCameraStretch = toggleCameraStretch,
        SetStretchH = setStretchHorizontal,
        SetStretchV = setStretchVertical,
        IsStretchEnabled = function() return stretchEnabled end,
        
        -- Full Bright
        ToggleFullBright = toggleFullBright,
        IsFullBright = function() return fullBrightEnabled end,
        
        -- Anti Lag
        AntiLag1 = antiLag1,
        AntiLag2 = antiLag2,
        AntiLag3 = antiLag3,
        
        -- Remove Fog
        ToggleRemoveFog = toggleRemoveFog,
        IsRemoveFog = function() return removeFogEnabled end,
    }
end)()

-- -------------------------------------------------------------------------- --
--                         LAG SWITCH MODULE                                   --
-- -------------------------------------------------------------------------- --

local LagSwitchModule = (function()
    -- ==================== VARIABEL ====================
    local enabled = false
    local mode = "Normal" -- "Normal" atau "Demon"
    local delay = 0.1
    local intensity = 1000000
    local demonHeight = 10
    local demonSpeed = 80
    local keybind = "F12"
    local isActive = false
    local buttonGui = nil
    
    -- ==================== NORMAL MODE ====================
    local function performNormalLag()
        local startTime = tick()
        local duration = delay
        
        while tick() - startTime < duration do
            for i = 1, intensity do
                local a = math.random(1, 1000000) * math.random(1, 1000000)
                a = a / math.random(1, 10000)
                local b = math.sqrt(math.random(1, 1000000))
                b = b * math.pi * math.exp(1)
            end
        end
    end
    
    -- ==================== DEMON MODE ====================
    local function performDemonLag()
        local startTime = tick()
        local duration = delay
        
        -- Part 1: Math lag
        task.spawn(function()
            local startLag = tick()
            while tick() - startLag < duration do
                for i = 1, math.floor(intensity / 2) do
                    local a = math.random(1, 1000000) * math.random(1, 1000000)
                    a = a / math.random(1, 10000)
                end
            end
        end)
        
        -- Part 2: Player rise
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            
            if rootPart and humanoid then
                local startHeight = rootPart.Position.Y
                
                -- BodyThrust untuk naik
                local bodyThrust = Instance.new("BodyThrust")
                bodyThrust.Force = Vector3.new(0, demonSpeed * 500, 0)
                bodyThrust.Location = Vector3.new(0, 0, 0)
                bodyThrust.Parent = rootPart
                
                -- BodyVelocity untuk kontrol
                local bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(0, 500000, 0)
                bodyVelocity.Velocity = Vector3.new(0, demonSpeed, 0)
                bodyVelocity.Parent = rootPart
                
                -- Tunggu sampai mencapai ketinggian
                local waitTime = 0
                local maxWait = 5
                
                while waitTime < maxWait do
                    local currentHeight = rootPart.Position.Y
                    if currentHeight - startHeight >= demonHeight then
                        break
                    end
                    task.wait(0.1)
                    waitTime = waitTime + 0.1
                end
                
                -- Bersihkan force
                pcall(function() bodyThrust:Destroy() end)
                pcall(function() bodyVelocity:Destroy() end)
                
                local finalHeight = rootPart.Position.Y
                Success("Demon Mode", string.format("Naik %.1f meter", finalHeight - startHeight), 2)
            end
        end
        
        isActive = false
    end
    
    -- ==================== FUNGSI UTAMA ====================
    local function toggle()
        if not enabled then 
            Warning("Lag Switch", "Aktifkan toggle terlebih dahulu", 2)
            return 
        end
        if isActive then return end
        
        isActive = true
        
        if mode == "Normal" then
            task.spawn(function()
                performNormalLag()
                isActive = false
            end)
            Success("Lag Switch", "Normal mode triggered", 1)
        else
            task.spawn(function()
                performDemonLag()
                isActive = false
            end)
            Success("Lag Switch", "Demon mode triggered", 1)
        end
    end
    
    -- ==================== FUNGSI UPDATE BUTTON ====================
    local function updateButtonDisplay()
        if not buttonGui then return end
        
        local frame = buttonGui:FindFirstChild("Frame")
        if not frame then return end
        
        -- Update mode label
        for _, child in pairs(frame:GetChildren()) do
            if child:IsA("TextLabel") and child.Text:find("Mode:") then
                child.Text = "Mode: " .. mode
                child.TextColor3 = mode == "Normal" and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 100, 100)
            end
            
            -- Update button text
            if child:IsA("TextButton") then
                child.Text = "TRIGGER (" .. keybind .. ")"
            end
        end
    end
    
    -- ==================== SETTERS ====================
    local function setEnabled(state)
        enabled = state
        if state then
            Info("Lag Switch", "Enabled", 1)
        else
            Info("Lag Switch", "Disabled", 1)
        end
        updateButtonDisplay()
    end
    
    local function setMode(newMode)
        mode = newMode
        Info("Lag Switch", "Mode: " .. newMode, 1)
        updateButtonDisplay()
    end
    
    local function setDelay(value)
        local num = tonumber(value)
        if num and num > 0 and num <= 5 then
            delay = num
            Info("Lag Switch", "Delay: " .. delay .. "s", 1)
        end
    end
    
    local function setIntensity(value)
        local num = tonumber(value)
        if num and num >= 1000 and num <= 10000000 then
            intensity = num
        end
    end
    
    local function setDemonHeight(value)
        local num = tonumber(value)
        if num and num >= 10 and num <= 500 then
            demonHeight = num
        end
    end
    
    local function setDemonSpeed(value)
        local num = tonumber(value)
        if num and num >= 20 and num <= 200 then
            demonSpeed = num
        end
    end
    
    local function setKeybind(newKey)
        keybind = newKey
        Info("Lag Switch", "Keybind: " .. newKey, 1)
        updateButtonDisplay()
    end
    
    -- ==================== GUI BUTTON ====================
    local function createButton()
        if buttonGui then
            pcall(function() buttonGui:Destroy() end)
        end
        
        local CoreGui = game:GetService("CoreGui")
        buttonGui = Instance.new("ScreenGui")
        buttonGui.Name = "LagSwitchButton"
        buttonGui.ResetOnSpawn = false
        buttonGui.Parent = CoreGui
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 200, 0, 60)
        frame.Position = UDim2.new(0.5, -100, 0.5, 0)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = buttonGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        -- Status text
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, -10, 0, 20)
        statusLabel.Position = UDim2.new(0, 5, 0, 5)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "⚡ LAG SWITCH"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 12
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.Parent = frame
        
        -- Mode indicator
        local modeLabel = Instance.new("TextLabel")
        modeLabel.Size = UDim2.new(1, -10, 0, 20)
        modeLabel.Position = UDim2.new(0, 5, 0, 25)
        modeLabel.BackgroundTransparency = 1
        modeLabel.Text = "Mode: " .. mode
        modeLabel.TextColor3 = mode == "Normal" and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 100, 100)
        modeLabel.TextSize = 10
        modeLabel.Font = Enum.Font.Gotham
        modeLabel.TextXAlignment = Enum.TextXAlignment.Left
        modeLabel.Parent = frame
        
        -- Trigger button
        local triggerBtn = Instance.new("TextButton")
        triggerBtn.Size = UDim2.new(1, -10, 0, 30)
        triggerBtn.Position = UDim2.new(0, 5, 0, 45)
        triggerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        triggerBtn.Text = "TRIGGER (" .. keybind .. ")"
        triggerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        triggerBtn.TextSize = 14
        triggerBtn.Font = Enum.Font.GothamBold
        triggerBtn.Parent = frame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = triggerBtn
        
        -- Hover effect
        triggerBtn.MouseEnter:Connect(function()
            triggerBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        end)
        
        triggerBtn.MouseLeave:Connect(function()
            triggerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end)
        
        triggerBtn.MouseButton1Click:Connect(function()
            if enabled then
                toggle()
                -- Flash effect
                triggerBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
                task.wait(0.1)
                triggerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            else
                Warning("Lag Switch", "Enable toggle first", 1)
            end
        end)
        
        return buttonGui
    end
    
    local function destroyButton()
        if buttonGui then
            pcall(function() buttonGui:Destroy() end)
            buttonGui = nil
        end
    end
    
    -- ==================== KEYBIND ====================
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode[keybind] then
            if enabled then
                toggle()
            end
        end
    end)
    
    -- ==================== GET STATUS ====================
    local function getStatus()
        return string.format(
            "Enabled: %s\nMode: %s\nDelay: %.1fs\nIntensity: %d\nKey: %s",
            enabled and "✅" or "❌",
            mode,
            delay,
            intensity,
            keybind
        )
    end
    
    -- ==================== PUBLIC API ====================
    return {
        -- Main
        toggle = toggle,
        setEnabled = setEnabled,
        setMode = setMode,
        isEnabled = function() return enabled end,
        
        -- Settings
        setDelay = setDelay,
        setIntensity = setIntensity,
        setDemonHeight = setDemonHeight,
        setDemonSpeed = setDemonSpeed,
        setKeybind = setKeybind,
        
        -- GUI
        createButton = createButton,
        destroyButton = destroyButton,
        
        -- Status
        getStatus = getStatus,
    }
end)()

-- ========================================================================== --
--                              LOAD WINDUI                                    --
-- ========================================================================== --

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
WindUI:SetTheme("Violet")

-- ========================================================================== --
--                              CREATE WINDOW                                  --
-- ========================================================================== --

local Window = WindUI:CreateWindow({
    Title = "rzprivate - Evade",
    Icon = "sparkles",
    IconThemed = true,
    Size = UDim2.fromOffset(650, 500),
    Background = "rbxassetid://85878831310179",
    Folder = "rzprivate",
})

-- ========================================================================== --
--                              CREATE SECTIONS                                --
-- ========================================================================== --

local Tabs = {}

Tabs.Imp = Window:Section({
    Title = "Important",
    Icon = "bell-ring",
    Opened = true,
})

Tabs.Main = Window:Section({
    Title = "Main",
    Icon = "zap",
    Opened = false,
})

Tabs.Customise = Window:Section({
    Title = "Appearance",
    Icon = "paintbrush",
    Opened = false,
})

-- ========================================================================== --
--                              CREATE TABS                                    --
-- ========================================================================== --

local CredTab = Tabs.Imp:Tab({ Title = "Credits", Icon = "newspaper" })
local UpadTab = Tabs.Imp:Tab({ Title = "Update Log", Icon = "scroll-text" })

-- Main Section Tabs
local AutoTab = Tabs.Main:Tab({ Title = "Auto", Icon = "zap" })
local TeleportTab = Tabs.Main:Tab({ Title = "Teleport", Icon = "navigation" })
local VisualTab = Tabs.Main:Tab({ Title = "Visual", Icon = "eye" })
-- 👇 TAMBAHKAN INI DI SINI (setelah VisualTab, sebelum MiscTab)
local MovementTab = Tabs.Main:Tab({ Title = "Movement", Icon = "activity" })
local MiscTab = Tabs.Main:Tab({ Title = "Misc", Icon = "package" })
local ServerTab = Tabs.Main:Tab({ Title = "Server", Icon = "server" })

-- Appearance Section Tabs
local SettingsTab = Tabs.Customise:Tab({ Title = "Settings", Icon = "settings" })
local WindowConfigTab = Tabs.Customise:Tab({ Title = "Window Config", Icon = "settings" })

-- ========================================================================== --
--                              CREDITS TAB                                    --
-- ========================================================================== --

CredTab:Paragraph({
    Title = "Credits",
    Desc = "Original rzprivate \nGUI Library: WindUI\nVisual by: iruz",
    Thumbnail = "https://wallpapers.com/images/high/widescreen-darling-in-the-franxx-02-uzmizm4y7lhahvy1.webp",
    ThumbnailSize = 150
})

CredTab:Paragraph({
    Title = "Join our discord server!",
    Desc = "Why waiting? join now!",
    Buttons = {
        {
            Title = "Copy Discord Link",
            Variant = "Primary",
            Icon = "copy",
            Callback = function()
                local success, err = pcall(function()
                    setclipboard("https://discord.gg/QUaWcAK8bx")
                end)
                if success then
                    WindUI:Notify({
                        Title = "Copied!",
                        Content = "Discord link copied to clipboard.",
                        Duration = 2
                    })
                else
                    warn("Failed to copy link:", err)
                end
            end
        }
    }
})

-- ========================================================================== --
--                              UPDATE LOG TAB                                 --
-- ========================================================================== --

UpadTab:Paragraph({
    Title = "Update Log v2.0",
    Desc = [[
• Added Auto Self Revive with methods
• Added Fast Revive with methods
• Added Teleport features (13+ features)
• Added Server Utilities (14+ features)
    ]],
})

UpadTab:Paragraph({
    Title = "Update Log v2.1 - New Features",
    Desc = [[
• Added Noclip
• Added Bug Emote (Force Sit)
• Added Remove Barriers
• Added Barriers Visible (with Color & Transparency)
• Added Unlock Leaderboard (with custom buttons)
• Added Grapplehook Enhancement
• Added Breacher (Portal Gun) Enhancement
• Added Smoke Grenade Enhancement
    ]],
})

UpadTab:Paragraph({
    Title = "Update Log v3.0 - Visual Update!",
    Desc = [[
• NEW TAB: VISUAL!
• Added Full Bright
• Added Remove Fog
• Added Camera Stretch (with Input)
• Added Anti Lag 1/2/3
• Added Fake Streak
• Moved Barrier Features to Visual Tab
• Added Error Handling (PCALL) for all modules
    ]],
})

UpadTab:Paragraph({
    Title = "Original Features",
    Desc = "• All Evade features preserved",
})

-- ========================================================================== --
--                              AUTO TAB                                       --
-- ========================================================================== --

AutoTab:Section({ Title = "Revive Features", TextSize = 20 })
AutoTab:Divider()

AutoTab:Button({
    Title = "Revive Yourself",
    Icon = "heart",
    Desc = "Revive yourself manually when downed",
    Callback = function()
        local char = player.Character
        if char then
            local isDowned = pcall(function() return char:GetAttribute("Downed") end)
            if isDowned then
                pcall(function()
                    ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
                end)
                Success("Revive Yourself", "Revive attempt sent!", 2)
            else
                Warning("Revive Yourself", "You are not downed!", 2)
            end
        end
    end
})

AutoTab:Space()

AutoTab:Dropdown({
    Title = "Self Revive Method",
    Desc = "Choose auto self revive method",
    Values = { "Spawnpoint", "Fake Revive" },
    Value = "Spawnpoint",
    Callback = function(value)
        AutoSelfReviveModule.SetMethod(value)
    end
})

AutoTab:Toggle({
    Title = "Auto Self Revive",
    Desc = "Automatically revive yourself when downed",
    Value = false,
    Callback = function(state)
        if state then
            AutoSelfReviveModule.Start()
        else
            AutoSelfReviveModule.Stop()
        end
    end
})

AutoTab:Space()

AutoTab:Dropdown({
    Title = "Fast Revive Method",
    Desc = "Auto: Auto revive in range | Interact: Press E",
    Values = { "Auto", "Interact" },
    Value = "Interact",
    Callback = function(value)
        FastReviveModule.SetMethod(value)
    end
})

AutoTab:Toggle({
    Title = "Fast Revive",
    Desc = "Quickly revive downed players",
    Value = false,
    Callback = function(state)
        if state then
            FastReviveModule.Start()
            Success("Fast Revive Enabled", "Fast revive activated", 2)
        else
            FastReviveModule.Stop()
            Success("Fast Revive Disabled", "Fast revive disabled", 2)
        end
    end
})

-- ========================================================================== --
--                              TELEPORT TAB                                   --
--                         Version Final - No Emoji                            --
-- ========================================================================== --

-- ==================== TELEPORT MODULE STATUS ====================
TeleportTab:Section({ Title = "Teleport Module Status", TextSize = 20 })
TeleportTab:Divider()

-- Gabungan Current Map + Database + Info dalam 1 paragraph
local moduleStatusPara = TeleportTab:Paragraph({
    Title = "Information",
    Desc = "Loading...",
    ThumbnailSize = 0
})

-- Fungsi untuk update status
local function updateModuleStatus()
    local mapName = TeleportModule.GetCurrentMap()
    local isLoaded = TeleportModule.IsLoaded()
    local hasMap = isLoaded and TeleportModule.HasMapData(mapName)
    local mapCount = TeleportModule.GetMapCount()
    local lastUpdate = TeleportModule.GetLastUpdate()
    
    local statusText = ""
    
    -- Current Map
    statusText = statusText .. "Current Map: " .. mapName
    if mapName == "Unknown" then
        statusText = statusText .. " (not detected)\n"
    elseif hasMap then
        statusText = statusText .. " (in database)\n"
    else
        statusText = statusText .. " (not in database)\n"
    end
    
    -- Database
    statusText = statusText .. "Database: " .. mapCount .. " maps | Last: " .. lastUpdate
    if isLoaded then
        statusText = statusText .. " | Loaded\n\n"
    else
        statusText = statusText .. " | Not Loaded\n\n"
    end
    
    -- Info
    statusText = statusText .. "• Map terdeteksi otomatis\n"
    statusText = statusText .. "• Notifikasi saat ganti map\n"
    statusText = statusText .. "• Klik Refresh untuk update database"
    
    moduleStatusPara:SetDesc(statusText)
end

-- Loop update setiap 2 detik
task.spawn(function()
    while true do
        pcall(updateModuleStatus)
        task.wait(2)
    end
end)

-- Refresh Button
TeleportTab:Button({
    Title = "Refresh Teleport Module",
    Desc = "Update map database dari GitHub",
    Variant = "Primary",
    Callback = function()
        local success = TeleportModule.Refresh()
        if success then
            updateModuleStatus()
            Success("Teleport Module", "Database berhasil diupdate!", 2)
        end
    end
})

-- Tampilkan error jika module gagal load
if not TeleportModule.IsLoaded() and TeleportModule.GetError() then
    TeleportTab:Paragraph({
        Title = "Error",
        Desc = TeleportModule.GetError(),
        ThumbnailSize = 0
    })
end

TeleportTab:Divider()

-- ==================== AUTO PLACE TELEPORTER ====================
TeleportTab:Section({ Title = "Auto Place Teleporter", TextSize = 20 })
TeleportTab:Divider()

-- Auto Place Teleporter Toggle
TeleportTab:Toggle({
    Title = "Auto Place Every Round",
    Desc = "Otomatis place teleporter setiap ronde mulai",
    Value = false,
    Callback = function(value)
        autoPlaceTeleporterEnabled = value
        if value then
            Success("Auto Place", "Akan place " .. autoPlaceTeleporterType .. " teleporter setiap ronde", 3)
        end
    end
})

-- Teleporter Type Dropdown
TeleportTab:Dropdown({
    Title = "Teleporter Type",
    Desc = "Pilih tipe teleporter (Far / Sky)",
    Values = { "Far", "Sky" },
    Value = "Far",
    Callback = function(value)
        autoPlaceTeleporterType = value
        WindUI:Notify({
            Title = "Type Changed",
            Content = "Auto place akan menggunakan " .. value .. " spot",
            Duration = 2
        })
    end
})

TeleportTab:Divider()

-- ==================== PLACE TELEPORTER ====================
TeleportTab:Section({ Title = "Place Teleporter", TextSize = 20 })
TeleportTab:Divider()

if TeleportModule.IsLoaded() then
    -- Place Teleporter Far
    TeleportTab:Button({
        Title = "Place Teleporter Far",
        Desc = "Place di spot Far untuk map saat ini",
        Callback = function()
            TeleportModule.PlaceTeleporter("Far")
        end
    })

    -- Place Teleporter Sky
    TeleportTab:Button({
        Title = "Place Teleporter Sky",
        Desc = "Place di spot Sky untuk map saat ini",
        Callback = function()
            TeleportModule.PlaceTeleporter("Sky")
        end
    })
else
    TeleportTab:Paragraph({
        Title = "Module Not Loaded",
        Desc = "Teleport module belum di-load. Klik Refresh terlebih dahulu.",
        ThumbnailSize = 0
    })
end

TeleportTab:Divider()

-- ==================== TELEPORT PLAYER ====================
TeleportTab:Section({ Title = "Teleport Player", TextSize = 20 })
TeleportTab:Divider()

if TeleportModule.IsLoaded() then
    -- Teleport Player To Sky
    TeleportTab:Button({
        Title = "Teleport Player To Sky",
        Desc = "Teleport player ke spot Sky",
        Callback = function()
            TeleportModule.TeleportPlayer("Sky")
        end
    })

    -- Teleport Player To Far
    TeleportTab:Button({
        Title = "Teleport Player To Far",
        Desc = "Teleport player ke spot Far",
        Callback = function()
            TeleportModule.TeleportPlayer("Far")
        end
    })
else
    TeleportTab:Paragraph({
        Title = "Module Not Loaded",
        Desc = "Teleport module belum di-load. Klik Refresh terlebih dahulu.",
        ThumbnailSize = 0
    })
end

TeleportTab:Divider()

-- ==================== OBJECTIVE TELEPORTS ====================
TeleportTab:Section({ Title = "Objective Teleports", TextSize = 20 })
TeleportTab:Divider()

-- Teleport to Objective
TeleportTab:Button({
    Title = "Teleport to Objective",
    Desc = "Teleport ke objective random",
    Callback = function()
        TeleportFeaturesModule.TeleportToRandomObjective()
    end
})

-- Teleport to Nearest Ticket
TeleportTab:Button({
    Title = "Teleport to Nearest Ticket",
    Desc = "Teleport ke ticket terdekat",
    Callback = function()
        TeleportFeaturesModule.TeleportToNearestTicket()
    end
})

TeleportTab:Divider()

-- ==================== PLAYER TELEPORTS ====================
TeleportTab:Section({ Title = "Player Teleports", TextSize = 20 })
TeleportTab:Divider()

-- Player List Dropdown
local selectedPlayerName = nil
local PlayerListDropdown = nil

-- Fungsi refresh yang SUPER AMAN
local function refreshPlayerDropdown()
    -- Cek dropdown ada
    if not PlayerListDropdown then return end
    
    -- Ambil player list dengan aman
    local playerList = {}
    local success, result = pcall(TeleportFeaturesModule.GetPlayerList)
    if success and result and type(result) == "table" then
        playerList = result
    end
    
    -- Validasi
    if #playerList == 0 then
        playerList = { "No players available" }
    end
    
    -- Refresh dengan pcall terpisah
    local refreshSuccess = pcall(function()
        PlayerListDropdown:Refresh(playerList)
    end)
    
    if not refreshSuccess then
        warn("Dropdown refresh failed - ignoring")
        return
    end
    
    -- Update selected player
    if playerList[1] and playerList[1] ~= "No players available" then
        if not selectedPlayerName or not table.find(playerList, selectedPlayerName) then
            selectedPlayerName = playerList[1]
            pcall(function()
                PlayerListDropdown:Select(selectedPlayerName)
            end)
        end
    else
        selectedPlayerName = nil
    end
end

-- Buat dropdown dengan error handling
local dropdownSuccess, dropdownResult = pcall(function()
    return TeleportTab:Dropdown({
        Title = "Select Player",
        Values = { "Loading..." },  -- Sementara pakai loading
        SearchBarEnabled = true,
        Value = "Loading...",
        Callback = function(value)
            if value and value ~= "No players available" and value ~= "Loading..." then
                selectedPlayerName = value
            end
        end
    })
end)

if dropdownSuccess then
    PlayerListDropdown = dropdownResult
    -- Refresh setelah dropdown jadi
    task.spawn(function()
        task.wait(0.5)
        pcall(refreshPlayerDropdown)
    end)
else
    warn("Failed to create dropdown")
    PlayerListDropdown = { Refresh = function() end, Select = function() end }
end

-- Auto refresh dengan delay lebih lama
Players.PlayerAdded:Connect(function()
    task.wait(1.5)  -- Delay lebih lama
    pcall(refreshPlayerDropdown)
end)

Players.PlayerRemoving:Connect(function()
    task.wait(1)
    pcall(refreshPlayerDropdown)
end)

-- Teleport to Selected Player
TeleportTab:Button({
    Title = "Teleport to Selected Player",
    Desc = "Teleport ke player yang dipilih",
    Variant = "Primary",
    Callback = function()
        if selectedPlayerName and selectedPlayerName ~= "No players available" then
            pcall(function()
                TeleportFeaturesModule.TeleportToPlayer(selectedPlayerName)
            end)
        else
            Error("Teleport", "Pilih player terlebih dahulu!", 2)
        end
    end
})

-- Refresh Player List Button
TeleportTab:Button({
    Title = "Refresh Player List",
    Desc = "Update daftar player manual",
    Variant = "Secondary",
    Callback = function()
        pcall(refreshPlayerDropdown)
        Info("Player List", "Daftar player diupdate!", 2)
    end
})

-- Teleport to Random Player
TeleportTab:Button({
    Title = "Teleport to Random Player",
    Desc = "Teleport ke player random",
    Callback = function()
        pcall(TeleportFeaturesModule.TeleportToRandomPlayer)
    end
})


-- ==================== DOWNED PLAYER TELEPORTS ====================
TeleportTab:Section({ Title = "Downed Player Teleports", TextSize = 20 })
TeleportTab:Divider()

-- Teleport to Nearest Downed Player
TeleportTab:Button({
    Title = "Teleport to Nearest Downed Player",
    Desc = "Teleport ke player downed terdekat",
    Callback = function()
        TeleportFeaturesModule.TeleportToNearestDowned()
    end
})

-- ========================================================================== --
--                              VISUAL TAB                                    --
-- ========================================================================== --

VisualTab:Section({ Title = "Barrier Features", TextSize = 18 })
VisualTab:Divider()

VisualTab:Toggle({
    Title = "Remove Barriers",
    Desc = "Disable collision on invisible barriers",
    Value = false,
    Callback = function(state)
        if state then
            RemoveBarriersModule.Start()
        else
            RemoveBarriersModule.Stop()
        end
    end
})

-- ========== TARUH KEYBIND DI SINI ==========
VisualTab:Keybind({
    Title = "Remove Barriers Keybind",
    Desc = "Tekan untuk toggle Remove Barriers",
    Callback = function()
        -- Toggle tanpa notifikasi
        if RemoveBarriersModule.IsEnabled() then
            RemoveBarriersModule.Stop()
        else
            RemoveBarriersModule.Start()
        end
    end,
    ChangedCallback = function(newKey)
        Success("Keybind", "Remove Barriers keybind: " .. newKey, 1)
    end
})

-- ========== TAMBAHKAN KEYBIND BARRIERS VISIBLE DI SINI ==========
VisualTab:Keybind({
    Title = "Barriers Visible Keybind",
    Desc = "Tekan untuk toggle Barriers Visible",
    Callback = function()
        if BarriersVisibleModule.IsEnabled() then
            BarriersVisibleModule.Stop()
        else
            BarriersVisibleModule.Start()
        end
    end,
    ChangedCallback = function(newKey)
        Success("Keybind", "Barriers Visible keybind: " .. newKey, 1)
    end
})
-- =================================================================

-- Barriers Visible Toggle
VisualTab:Toggle({
    Title = "Barriers Visible",
    Desc = "Make invisible barriers visible with color",
    Value = false,
    Callback = function(state)
        if state then
            BarriersVisibleModule.Start()
        else
            BarriersVisibleModule.Stop()
        end
    end
})

VisualTab:Dropdown({
    Title = "Barriers Color",
    Desc = "Pilih warna untuk barriers",
    Values = { 
        "Merah", "Biru", "Hijau", "Kuning", "Ungu", 
        "Pink", "Cyan", "Oranye", "Putih", "Hitam"
    },
    Value = "Merah",
    Callback = function(value)
        local color
        if value == "Merah" then
            color = Color3.fromRGB(255, 0, 0)
        elseif value == "Biru" then
            color = Color3.fromRGB(0, 100, 255)
        elseif value == "Hijau" then
            color = Color3.fromRGB(0, 255, 0)
        elseif value == "Kuning" then
            color = Color3.fromRGB(255, 255, 0)
        elseif value == "Ungu" then
            color = Color3.fromRGB(150, 0, 255)
        elseif value == "Pink" then
            color = Color3.fromRGB(255, 0, 255)
        elseif value == "Cyan" then
            color = Color3.fromRGB(0, 255, 255)
        elseif value == "Oranye" then
            color = Color3.fromRGB(255, 128, 0)
        elseif value == "Putih" then
            color = Color3.fromRGB(255, 255, 255)
        elseif value == "Hitam" then
            color = Color3.fromRGB(0, 0, 0)
        end
        BarriersVisibleModule.SetColor(color)
        Success("Color Changed", "Barriers color: " .. value, 1)
    end
})

VisualTab:Dropdown({
    Title = "Barriers Transparency",
    Desc = "Pilih tingkat transparansi",
    Values = { 
        "1 - Solid (0%)", 
        "2 - Sedikit Transparan (20%)", 
        "3 - Transparan (40%)", 
        "4 - Setengah (50%)", 
        "5 - Agak Transparan (60%)",
        "6 - Transparan (70%)", 
        "7 - Sangat Transparan (80%)", 
        "8 - Hampir Tak Terlihat (85%)", 
        "9 - Nyaris Invisible (90%)", 
        "10 - Super Transparan (95%)" 
    },
    Value = "1 - Solid (0%)",
    Callback = function(value)
        local level = tonumber(value:match("%d+"))
        if level then
            BarriersVisibleModule.SetTransparencyLevel(level)
            if BarriersVisibleModule.IsEnabled() then
                local percent = value:match("%((%d+)%%%)")
                Success("Transparency", "Barriers: " .. percent .. "% transparan", 1)
            end
        end
    end
})

VisualTab:Space()
VisualTab:Divider()
VisualTab:Section({ Title = "Lighting & Atmosphere", TextSize = 18 })
VisualTab:Divider()

VisualTab:Toggle({
    Title = "Full Bright",
    Desc = "Maksimalkan pencahayaan game",
    Value = false,
    Callback = function(state)
        VisualFeaturesModule.ToggleFullBright(state)
    end
})

VisualTab:Toggle({
    Title = "Remove Fog",
    Desc = "Hilangkan efek fog/kabut",
    Value = false,
    Callback = function(state)
        VisualFeaturesModule.ToggleRemoveFog(state)
    end
})

VisualTab:Space()
VisualTab:Divider()
VisualTab:Section({ Title = "Camera Effects", TextSize = 18 })
VisualTab:Divider()

VisualTab:Toggle({
    Title = "Camera Stretch",
    Desc = "Regangkan tampilan kamera",
    Value = false,
    Callback = function(state)
        VisualFeaturesModule.ToggleCameraStretch(state)
    end
})

VisualTab:Input({
    Title = "Stretch Horizontal",
    Desc = "Nilai stretch horizontal (0.1 - 2.0)",
    Placeholder = "Contoh: 0.8",
    Value = "0.8",
    Callback = function(value)
        VisualFeaturesModule.SetStretchH(value)
    end
})

VisualTab:Input({
    Title = "Stretch Vertical",
    Desc = "Nilai stretch vertical (0.1 - 2.0)",
    Placeholder = "Contoh: 0.8",
    Value = "0.8",
    Callback = function(value)
        VisualFeaturesModule.SetStretchV(value)
    end
})

VisualTab:Space()
VisualTab:Divider()
VisualTab:Section({ Title = "Anti Lag Optimization", TextSize = 18 })
VisualTab:Divider()

VisualTab:Button({
    Title = "Anti Lag 1 - Ringan",
    Desc = "Optimasi ringan (shadows, fog, material)",
    Callback = function()
        VisualFeaturesModule.AntiLag1()
    end
})

VisualTab:Button({
    Title = "Anti Lag 2 - Agresif",
    Desc = "Optimasi agresif (textures, effects, particles)",
    Callback = function()
        VisualFeaturesModule.AntiLag2()
    end
})

VisualTab:Button({
    Title = "Anti Lag 3 - Remove Textures",
    Desc = "Fokus penghapusan texture dan decal",
    Callback = function()
        VisualFeaturesModule.AntiLag3()
    end
})

-- ==================== FIELD OF VIEW (FOV) ====================
VisualTab:Space()
VisualTab:Divider()
VisualTab:Section({ Title = "Field of View (FOV)", TextSize = 18 })
VisualTab:Divider()

-- Variable untuk mencegah callback pertama
local firstTime = true

-- FOV Dropdown
local fovDropdown = VisualTab:Dropdown({
    Title = "FOV Presets",
    Desc = "Pilih FOV (langsung work)",
    Values = { "100 FOV", "110 FOV", "120 FOV", "130 FOV", "140 FOV", "150 FOV" },
    Value = "100 FOV",
    Callback = function(value)
        -- SKIP callback pertama saat inisialisasi
        if firstTime then
            firstTime = false
            return
        end
        
        local inputValue = 150
        
        if value == "100 FOV" then
            inputValue = 150
        elseif value == "110 FOV" then
            inputValue = 200
        elseif value == "120 FOV" then
            inputValue = 250
        elseif value == "130 FOV" then
            inputValue = 300
        elseif value == "140 FOV" then
            inputValue = 350
        elseif value == "150 FOV" then
            inputValue = 400
        end
        
        -- Apply FOV
        game:GetService("ReplicatedStorage").Events.Data.ChangeSetting:InvokeServer(2, inputValue)
        
        Success("FOV", "Changed to " .. value, 2)
    end
})

-- Info
VisualTab:Paragraph({
    Title = "⚠️ PENTING!",
    Desc = "• FOV hanya berubah saat DIPILIH\n• Execute ulang script TIDAK mengubah FOV\n• WAJIB REJOIN agar stabil",
    ThumbnailSize = 0
})

VisualTab:Space()
VisualTab:Divider()
VisualTab:Section({ Title = "Player Visual", TextSize = 18 })
VisualTab:Divider()

VisualTab:Input({
    Title = "Fake Streak",
    Desc = "Palsukan nilai streak player (visual only)",
    Placeholder = "Masukkan angka streak",
    Value = "",
    Callback = function(value)
        VisualFeaturesModule.SetFakeStreak(value)
    end
})

VisualTab:Button({
    Title = "Reset Streak",
    Desc = "Hapus fake streak kembali ke normal",
    Callback = function()
        VisualFeaturesModule.ResetStreak()
    end
})

-- ========================================================================== --
--                              MOVEMENT TAB                                   --
--                    Noclip | Bug Emote | Fly | Slide | Bhop                  --
-- ========================================================================== --

-- ==================== MOVEMENT FEATURES ====================
MovementTab:Section({ Title = "Movement Features", TextSize = 20 })
MovementTab:Divider()

-- Noclip Toggle
MovementTab:Toggle({
    Title = "Noclip",
    Desc = "Walk through walls and objects",
    Value = false,
    Callback = function(state)
        if state then NoclipModule.Start() else NoclipModule.Stop() end
    end
})

-- Bug Emote Toggle
MovementTab:Toggle({
    Title = "Bug Emote",
    Desc = "Force your character to sit",
    Value = false,
    Callback = function(state)
        if state then BugEmoteModule.Start() else BugEmoteModule.Stop() end
    end
})

MovementTab:Space()
MovementTab:Divider()

-- ==================== INFINITE SLIDE ====================
MovementTab:Section({ Title = "Infinite Slide", TextSize = 20 })
MovementTab:Divider()

-- Infinite Slide Toggle
MovementTab:Toggle({
    Title = "Infinite Slide",
    Desc = "Slide tanpa batas (hold Shift saat lari)",
    Value = false,
    Callback = function(state)
        MovementFeaturesModule.ToggleInfiniteSlide(state)
    end
})

-- Slide Speed Input
MovementTab:Input({
    Title = "Slide Speed",
    Desc = "Nilai negatif = akselerasi (contoh: -8)",
    Placeholder = "Masukkan nilai",
    Value = "-8",
    Callback = function(value)
        MovementFeaturesModule.SetSlideSpeed(value)
    end
})

-- Info Slide
MovementTab:Paragraph({
    Title = "Cara Pakai Slide",
    Desc = "• Berlari (hold Shift)\n• Slide akan terus tanpa batas\n• Atur speed untuk akselerasi",
    ThumbnailSize = 0
})

MovementTab:Space()
MovementTab:Divider()

-- ==================== BUNNY HOP ====================
MovementTab:Section({ Title = "Bunny Hop", TextSize = 20 })
MovementTab:Divider()

-- Bhop Toggle
MovementTab:Toggle({
    Title = "Bunny Hop",
    Desc = "Lompat otomatis saat berlari",
    Value = false,
    Callback = function(state)
        MovementFeaturesModule.ToggleBhop(state)
    end
})

-- Bhop Mode Dropdown
MovementTab:Dropdown({
    Title = "Bhop Mode",
    Desc = "Pilih mode lompat",
    Values = { "Bounce", "Realistic" },
    Value = "Bounce",
    Callback = function(value)
        MovementFeaturesModule.SetBhopMode(value)
    end
})

-- Jump Cooldown Input
MovementTab:Input({
    Title = "Jump Cooldown",
    Desc = "Jeda antar lompatan (detik)",
    Placeholder = "Contoh: 0.7",
    Value = "0.7",
    Callback = function(value)
        MovementFeaturesModule.SetJumpCooldown(value)
    end
})

-- Info Bhop
MovementTab:Paragraph({
    Title = "Cara Pakai Bhop",
    Desc = "• Aktifkan toggle\n• Berlari (hold Shift)\n• Hold Space untuk temporary Bhop\n• Mode Bounce = cepat, Realistic = mirip human",
    ThumbnailSize = 0
})

MovementTab:Space()
MovementTab:Divider()

-- ==================== FLY SYSTEM ====================
MovementTab:Section({ Title = "Fly System", TextSize = 20 })
MovementTab:Divider()

-- Fly Toggle
MovementTab:Toggle({
    Title = "Activate Fly",
    Desc = "Enable/disable flying mode (WASD + Space/Shift)",
    Value = false,
    Callback = function(state)
        FlyModule.Toggle(state)
    end
})

-- Fly Speed Input
MovementTab:Input({
    Title = "Fly Speed",
    Desc = "Set flying speed (10-500)",
    Placeholder = "Enter speed",
    Value = "50",
    Callback = function(value)
        local success = FlyModule.SetSpeed(value)
        if not success then
            Error("Fly System", "Invalid speed value!", 1)
        end
    end
})

-- Reset Fly Button
MovementTab:Button({
    Title = "Reset Fly",
    Desc = "Force stop fly if stuck",
    Callback = function()
        FlyModule.Stop()
        Success("Fly System", "Fly has been reset", 2)
    end
})

-- Fly Controls Info
MovementTab:Paragraph({
    Title = "Fly Controls",
    Desc = "W/A/S/D = Move\nSpace = Fly Up\nShift = Fly Down\nCamera = Direction",
    ThumbnailSize = 0
})

-- ========================================================================== --
--                              MISC TAB (RINGAN)                              --
-- ========================================================================== --

MiscTab:Section({ Title = "Weapon Enhancements", TextSize = 18 })
MiscTab:Divider()

-- Grapplehook Button
MiscTab:Button({
    Title = "Grapplehook",
    Desc = "Enhance Grapplehook (infinite ammo, speed)",
    Callback = function()
        GrapplehookModule.Execute()
    end
})

-- Breacher Button
MiscTab:Button({
    Title = "Breacher (Portal Gun)",
    Desc = "Enhance Breacher (infinite range, no cooldown)",
    Callback = function()
        BreacherModule.Execute()
    end
})

-- Smoke Grenade Button
MiscTab:Button({
    Title = "Smoke Grenade",
    Desc = "Enhance Smoke Grenade (bigger cloud, faster)",
    Callback = function()
        SmokeGrenadeModule.Execute()
    end
})

MiscTab:Divider()
MiscTab:Section({ Title = "Lag Switch", TextSize = 18 })
MiscTab:Divider()

-- Toggle utama
MiscTab:Toggle({
    Title = "Enable Lag Switch",
    Desc = "Aktifkan fitur lag switch",
    Value = false,
    Callback = function(state)
        LagSwitchModule.setEnabled(state)
    end
})

-- Mode dropdown
MiscTab:Dropdown({
    Title = "Mode",
    Desc = "Normal = lag biasa | Demon = lag + naik",
    Values = { "Normal", "Demon" },
    Value = "Normal",
    Callback = function(value)
        LagSwitchModule.setMode(value)
    end
})

-- Delay
MiscTab:Input({
    Title = "Delay (seconds)",
    Desc = "Durasi lag (0.1 - 5 detik)",
    Placeholder = "Contoh: 0.1",
    Value = "0.1",
    Callback = function(value)
        LagSwitchModule.setDelay(value)
    end
})

-- Intensity
MiscTab:Input({
    Title = "Intensity",
    Desc = "Kekuatan lag (1000 - 10.000.000)",
    Placeholder = "Contoh: 1000000",
    Value = "1000000",
    Callback = function(value)
        LagSwitchModule.setIntensity(value)
    end
})

-- Demon Height
MiscTab:Input({
    Title = "Demon Height (m)",
    Desc = "Tinggi naik (10-500m)",
    Placeholder = "Contoh: 10",
    Value = "10",
    Callback = function(value)
        LagSwitchModule.setDemonHeight(value)
    end
})

-- Demon Speed
MiscTab:Input({
    Title = "Demon Speed",
    Desc = "Kecepatan naik (20-200)",
    Placeholder = "Contoh: 80",
    Value = "80",
    Callback = function(value)
        LagSwitchModule.setDemonSpeed(value)
    end
})

-- Keybind (SATU-SATUNYA CARA TRIGGER)
MiscTab:Keybind({
    Title = "Trigger Key",
    Desc = "Tekan untuk trigger lag",
    Callback = function()
        if LagSwitchModule.isEnabled() then
            LagSwitchModule.toggle()
        end
    end,
    ChangedCallback = function(new)
        LagSwitchModule.setKeybind(new)
    end
})



MiscTab:Divider()
MiscTab:Section({ Title = "UI Features", TextSize = 18 })
MiscTab:Divider()

-- Unlock Leaderboard Button
MiscTab:Button({
    Title = "Unlock Leaderboard",
    Desc = "Buat custom button untuk Zoom, Front View, dan Leaderboard",
    Callback = function()
        UnlockLeaderboardModule.Create()
    end
})

-- Destroy Leaderboard Button (opsional)
MiscTab:Button({
    Title = "Remove Leaderboard UI",
    Desc = "Hapus custom button dan kembalikan topbar normal",
    Callback = function()
        UnlockLeaderboardModule.Destroy()
    end
})

-- Toggle Leaderboard (alternatif)
MiscTab:Toggle({
    Title = "Toggle Leaderboard UI",
    Desc = "Aktifkan/nonaktifkan custom button",
    Value = false,
    Callback = function(state)
        if state then
            UnlockLeaderboardModule.Create()
        else
            UnlockLeaderboardModule.Destroy()
        end
    end
})

-- ========================================================================== --
--                              SERVER TAB                                     --
-- ========================================================================== --

ServerTab:Section({ Title = "Server Info", TextSize = 20 })
ServerTab:Divider()

local gameModeName = "Loading..."
local GameModeParagraph = ServerTab:Paragraph({
    Title = "Game Mode",
    Desc = gameModeName
})

task.spawn(function()
    local success, productInfo = pcall(function()
        return MarketplaceService:GetProductInfo(placeId)
    end)
    if success and productInfo then
        local fullName = productInfo.Name
        if fullName:find("Evade %- ") then
            gameModeName = fullName:match("Evade %- (.+)") or fullName
        else
            gameModeName = fullName
        end
        if GameModeParagraph and GameModeParagraph.SetDesc then
            pcall(function() GameModeParagraph:SetDesc(gameModeName) end)
        end
    else
        gameModeName = "Unknown"
        if GameModeParagraph and GameModeParagraph.SetDesc then
            pcall(function() GameModeParagraph:SetDesc(gameModeName) end)
        end
    end
end)

ServerTab:Button({
    Title = "Copy Server Link",
    Desc = "Copy the current server's join link",
    Icon = "link",
    Callback = function()
        local serverLink = ServerUtils.GetServerLink()
        local success, errorMsg = pcall(function()
            setclipboard(serverLink)
        end)

        if success then
            Info("Link Copied", "Server invite link copied to clipboard!", 3)
        else
            Error("Copy Failed", "Your executor doesn't support setclipboard", 3)
            warn("Failed to copy link:", errorMsg)
        end
    end
})

ServerTab:Paragraph({
    Title = "Current Players",
    Desc = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
})

ServerTab:Paragraph({
    Title = "Server ID",
    Desc = jobId
})

ServerTab:Paragraph({
    Title = "Place ID",
    Desc = tostring(placeId)
})

ServerTab:Divider()
ServerTab:Section({ Title = "Quick Actions", TextSize = 20 })
ServerTab:Divider()

ServerTab:Button({
    Title = "Rejoin Server",
    Desc = "Rejoin the current server",
    Icon = "refresh-cw",
    Callback = function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end
})

ServerTab:Button({
    Title = "Server Hop",
    Desc = "Join a random server with 5+ players",
    Icon = "shuffle",
    Callback = function()
        local success = ServerUtils.ServerHop(5)
        if not success then
            WindUI:Notify({
                Title = "Server Hop Failed",
                Content = "No servers with 5+ players found!",
                Duration = 3
            })
        end
    end
})

ServerTab:Button({
    Title = "Hop to Small Server",
    Desc = "Hop to the emptiest available server",
    Icon = "minimize",
    Callback = function()
        local success = ServerUtils.HopToSmallestServer()
        if not success then
            WindUI:Notify({
                Title = "Server Hop Failed",
                Content = "Could not fetch servers!",
                Duration = 3
            })
        end
    end
})

ServerTab:Divider()
ServerTab:Section({ Title = "Join Server", TextSize = 20 })
ServerTab:Divider()

ServerTab:Button({
    Title = "Join Big Team",
    Desc = "Join the most populated Big Team server",
    Icon = "users",
    Callback = function()
        ServerUtils.JoinServerByPlaceId(10324346056, "Big Team")
    end
})

ServerTab:Button({
    Title = "Join Casual",
    Desc = "Join the most populated Casual server",
    Icon = "coffee",
    Callback = function()
        ServerUtils.JoinServerByPlaceId(10662542523, "Casual")
    end
})

ServerTab:Button({
    Title = "Join Social Space",
    Desc = "Join the most populated Social Space server",
    Icon = "message-square",
    Callback = function()
        ServerUtils.JoinServerByPlaceId(10324347967, "Social Space")
    end
})

ServerTab:Button({
    Title = "Join Player Nextbots",
    Desc = "Join the most populated Player Nextbots server",
    Icon = "ghost",
    Callback = function()
        ServerUtils.JoinServerByPlaceId(121271605799901, "Player Nextbots")
    end
})

ServerTab:Button({
    Title = "Join VC Only",
    Desc = "Join the most populated VC Only server",
    Icon = "mic",
    Callback = function()
        ServerUtils.JoinServerByPlaceId(10808838353, "VC Only")
    end
})

ServerTab:Button({
    Title = "Join Pro",
    Desc = "Join the most populated Pro server",
    Icon = "award",
    Callback = function()
        ServerUtils.JoinServerByPlaceId(11353528705, "Pro")
    end
})

ServerTab:Divider()

local customServerCode = ""

ServerTab:Input({
    Title = "Custom Server Code",
    Placeholder = "Enter custom server passcode",
    Value = "",
    Callback = function(value)
        customServerCode = value
    end
})

ServerTab:Button({
    Title = "Join Custom Server",
    Desc = "Join custom server with the code above",
    Icon = "key",
    Callback = function()
        if customServerCode == "" then
            WindUI:Notify({
                Title = "Join Failed",
                Content = "Please enter a custom server code!",
                Duration = 3
            })
            return
        end

        local success, result = pcall(function()
            return game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("CustomServers")
                :WaitForChild("JoinPasscode"):InvokeServer(customServerCode)
        end)

        if success then
            WindUI:Notify({
                Title = "Joining Custom Server",
                Content = "Attempting to join with code: " .. customServerCode,
                Duration = 3
            })
        else
            WindUI:Notify({
                Title = "Join Failed",
                Content = "Invalid code or server unavailable!",
                Duration = 3
            })
        end
    end
})

-- ========================================================================== --
--                              SETTINGS TAB                                   --
-- ========================================================================== --

SettingsTab:Section({ Title = "Keybinds", TextSize = 20 })

SettingsTab:Keybind({
    Title = "Toggle UI",
    Desc = "Keybind to open/close UI",
    Value = "RightControl",
    Callback = function(keyName)
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then
            Window:SetToggleKey(keyCode)
        end
    end
})

-- ========================================================================== --
--                              WINDOW CONFIG TAB                              --
-- ========================================================================== --

WindowConfigTab:Section({ Title = "Window Settings", TextSize = 20 })

local themeValues = {}
for name, _ in pairs(WindUI:GetThemes()) do
    table.insert(themeValues, name)
end

local themeDropdown = WindowConfigTab:Dropdown({
    Title = "Select Theme",
    Multi = false,
    AllowNone = false,
    Values = themeValues,
    Callback = function(theme)
        WindUI:SetTheme(theme)
    end
})
themeDropdown:Select(WindUI:GetCurrentTheme())

local BackgroundInput = WindowConfigTab:Input({
    Title = "Background Image/Video",
    Value = "85878831310179",
    Placeholder = "Asset ID or Video Link",
    Callback = function(input)
        if input:match("^%d+$") then
            Window:SetBackgroundImage("rbxassetid://" .. input)
        else
            Window:SetBackgroundImage(input)
        end
    end
})

WindowConfigTab:Dropdown({
    Title = "Recommended Backgrounds",
    Values = {
        "79199183782805",
        "85878831310179",
        "easter egg ig >:3"
    },
    Default = "easter egg ig >:3",
    Callback = function(option)
        if option:match("^%d+$") then
            Window:SetBackgroundImage("rbxassetid://" .. option)
            BackgroundInput:SetValue(option)
        else
            Window:SetBackgroundImage(option)
            BackgroundInput:SetValue(option)
        end
    end
})

WindowConfigTab:Button({
    Title = "Remove Background",
    Callback = function()
        Window:SetBackgroundImage("")
        BackgroundInput:SetValue("")
    end
})

local ToggleTransparency = WindowConfigTab:Toggle({
    Title = "Toggle Window Transparency",
    Callback = function(state)
        Window:ToggleTransparency(state)
    end,
    Value = WindUI:GetTransparency()
})

-- ========================================================================== --
--                      SIMPLE INFO DISPLAY (POJOK KANAN BAWAH)               --
-- ========================================================================== --

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

-- Nonaktifkan topbar agar tidak ganggu
StarterGui:SetCore("TopbarEnabled", false)

-- Buat ScreenGui sederhana
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleInfoDisplay"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Frame utama (transparan)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Parent = screenGui
mainFrame.BackgroundTransparency = 1
mainFrame.Size = UDim2.new(0, 200, 0, 80)
mainFrame.Position = UDim2.new(1, -210, 0, 10)  -- Pojok kanan atas
mainFrame.ZIndex = 10

-- TextLabel untuk informasi
local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Parent = mainFrame
infoLabel.Size = UDim2.new(1, 0, 1, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
infoLabel.TextStrokeTransparency = 0.5
infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
infoLabel.Font = Enum.Font.GothamBold
infoLabel.TextSize = 14
infoLabel.TextXAlignment = Enum.TextXAlignment.Right
infoLabel.TextYAlignment = Enum.TextYAlignment.Bottom
infoLabel.Text = ""
infoLabel.ZIndex = 11

-- Variabel untuk FPS (session time dihapus)
local frameCount = 0
local lastFPSUpdate = tick()
local currentFPS = 0
local fpsUpdateInterval = 0.5

-- Update setiap frame
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    
    -- Update FPS setiap interval
    local currentTime = tick()
    if currentTime - lastFPSUpdate >= fpsUpdateInterval then
        currentFPS = math.floor(frameCount / (currentTime - lastFPSUpdate))
        frameCount = 0
        lastFPSUpdate = currentTime
    end
    
    -- Ambil timer game dari Stats
    local timerText = "0:00"
    local gameStats = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Stats")
    if gameStats then
        local timerValue = gameStats:GetAttribute("Timer")
        if timerValue then
            local mins = math.floor(timerValue / 60)
            local secs = timerValue % 60
            timerText = string.format("%d:%02d", mins, secs)
        end
    end
    
    -- Format teks (session dihapus)
    infoLabel.Text = string.format(
        "FPS: %d\nTimer: %s",
        currentFPS,
        timerText
    )
end)

-- Auto hide/show saat respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)

-- ========================================================================== --
--                              CHARACTER CONNECTIONS                          --
-- ========================================================================== --

player.CharacterAdded:Connect(function(character)
    NoclipModule.OnCharacterAdded()
    BugEmoteModule.OnCharacterAdded()
    RemoveBarriersModule.OnCharacterAdded()
    BarriersVisibleModule.OnCharacterAdded()
    FlyModule.OnCharacterAdded()
end)

-- ========================================================================== --
--                              FINAL SETUP                                    --
-- ========================================================================== --

Window:SelectTab(1)
Success("rzprivate", "Evade script loaded successfully with " .. 
       "Auto | Teleport | Visual | Movement | Misc | Server", 3)
