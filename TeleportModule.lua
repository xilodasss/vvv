-- TeleportModule.lua
-- External module untuk Draconic Hub

return function(Window, Fluent, Options, Players, LocalPlayer, RunService, ReplicatedStorage)
    
    -- ==================== TELEPORT MODULE ====================
    local TeleportModule = (function()
        -- MAP DATABASE
        local mapSpots = {
            ["DesertBus"] = {
                Far = CFrame.new(1350.6390380859375, -66.57595825195312, 913.889404296875, 0.08861260116100311, 0,
                    0.9960662126541138, 0, 1.0000001192092896, 0, -0.9960662126541138, 0, 0.08861260116100311),
                Sky = CFrame.new(29.76473045349121, 69.4240493774414, -178.1037139892578, 0.6581460237503052, 0,
                    0.7528902888298035, 0, 1, 0, -0.752890408039093, 0, 0.6581459641456604)
            },
            ["Factory"] = {
                Far = CFrame.new(-150.246, 118.088, -404.699),
                Sky = CFrame.new(-87.682, 308.5, -320.956)
            },
            ["Maze"] = {
                Far = CFrame.new(-266.328, 46.229, -230.914),
                Sky = CFrame.new(-184.603, 246.5, -104.985)
            }
        }

        local function validateCharacter()
            local char = LocalPlayer.Character
            if not char then
                Fluent:Notify({
                    Title = "Teleport Error",
                    Content = "Character not found!",
                    Duration = 2
                })
                return nil, nil
            end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                Fluent:Notify({
                    Title = "Teleport Error",
                    Content = "HumanoidRootPart not found!",
                    Duration = 2
                })
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

        return {
            GetCurrentMap = getCurrentMap,
            HasMapData = function(mapName)
                return mapSpots[mapName] ~= nil
            end,
            GetMapSpot = function(mapName, spotType)
                if not mapSpots[mapName] then return nil end
                return mapSpots[mapName][spotType]
            end,
            TeleportPlayer = function(spotType)
                local char, hrp = validateCharacter()
                if not char or not hrp then return false end
                local mapName = getCurrentMap()

                if mapName == "Unknown" then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "Could not detect map name!",
                        Duration = 2
                    })
                    return false
                end

                if not mapSpots[mapName] then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "Map '" .. mapName .. "' not in database!",
                        Duration = 3
                    })
                    return false
                end

                local cframe = mapSpots[mapName][spotType]
                if not cframe then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "No " .. spotType .. " spot found for " .. mapName,
                        Duration = 3
                    })
                    return false
                end

                Fluent:Notify({
                    Title = "Teleporting",
                    Content = "Teleporting to " .. spotType .. " for " .. mapName .. "...",
                    Duration = 2
                })
                
                safeTeleport(hrp, cframe.Position, { char })
                
                Fluent:Notify({
                    Title = "Success",
                    Content = "Teleported to " .. spotType .. " spot!",
                    Duration = 2
                })
                return true
            end
        }
    end)()

    -- ==================== TELEPORT FEATURES MODULE ====================
    local TeleportFeaturesModule = (function()
        local function validateCharacter()
            local char = LocalPlayer.Character
            if not char then
                Fluent:Notify({
                    Title = "Teleport Error",
                    Content = "Character not found!",
                    Duration = 2
                })
                return nil, nil
            end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                Fluent:Notify({
                    Title = "Teleport Error",
                    Content = "HumanoidRootPart not found!",
                    Duration = 2
                })
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

        local function findNearestTicketInternal()
            local gameFolder = workspace:FindFirstChild("Game")
            if not gameFolder then return nil end

            local effects = gameFolder:FindFirstChild("Effects")
            if not effects then return nil end

            local tickets = effects:FindFirstChild("Tickets")
            if not tickets then return nil end

            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

            local hrp = char.HumanoidRootPart
            local nearestTicket = nil
            local nearestDistance = math.huge

            for _, ticket in pairs(tickets:GetChildren()) do
                if ticket:IsA("BasePart") or ticket:IsA("Model") then
                    local ticketPart = ticket:IsA("Model") and ticket:FindFirstChild("HumanoidRootPart") or ticket
                    if ticketPart and ticketPart:IsA("BasePart") then
                        local dist = (hrp.Position - ticketPart.Position).Magnitude
                        if dist < nearestDistance then
                            nearestDistance = dist
                            nearestTicket = ticketPart
                        end
                    end
                end
            end

            return nearestTicket
        end

        local function isPlayerDowned(pl)
            if not pl or not pl.Character then return false end
            local char = pl.Character
            if char:GetAttribute("Downed") then return true end
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health <= 0 then return true end
            return false
        end

        local function findNearestDownedPlayer()
            local char, hrp = validateCharacter()
            if not char or not hrp then return nil end

            local nearestPlayer = nil
            local nearestDistance = math.huge

            for _, pl in pairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                    if isPlayerDowned(pl) then
                        local dist = (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
                        if dist < nearestDistance then
                            nearestDistance = dist
                            nearestPlayer = pl
                        end
                    end
                end
            end

            return nearestPlayer, nearestDistance
        end

        return {
            TeleportToRandomObjective = function()
                local char, hrp = validateCharacter()
                if not char or not hrp then return false end

                local objectives = {}
                local gameFolder = workspace:FindFirstChild("Game")
                if not gameFolder then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "Game folder not found!",
                        Duration = 2
                    })
                    return false
                end

                local mapFolder = gameFolder:FindFirstChild("Map")
                if not mapFolder then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "Map folder not found!",
                        Duration = 2
                    })
                    return false
                end

                local partsFolder = mapFolder:FindFirstChild("Parts")
                if not partsFolder then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "Parts folder not found!",
                        Duration = 2
                    })
                    return false
                end

                local objectivesFolder = partsFolder:FindFirstChild("Objectives")
                if not objectivesFolder then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "Objectives folder not found!",
                        Duration = 2
                    })
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
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "No objectives found!",
                        Duration = 2
                    })
                    return false
                end

                local selectedObjective = objectives[math.random(1, #objectives)]
                safeTeleport(hrp, selectedObjective.Part.Position, { char })
                
                Fluent:Notify({
                    Title = "Success",
                    Content = "Teleported to " .. selectedObjective.Name,
                    Duration = 2
                })
                return true
            end,

            TeleportToNearestTicket = function()
                local char, hrp = validateCharacter()
                if not char or not hrp then return false end

                local ticket = findNearestTicketInternal()
                if not ticket then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "No tickets found!",
                        Duration = 2
                    })
                    return false
                end

                safeTeleport(hrp, ticket.Position, { char })
                
                Fluent:Notify({
                    Title = "Success",
                    Content = "Teleported to nearest ticket!",
                    Duration = 2
                })
                return true
            end,

            GetPlayerList = function()
                local playerNames = {}
                for _, pl in pairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer then
                        table.insert(playerNames, pl.Name)
                    end
                end
                table.sort(playerNames)
                return #playerNames > 0 and playerNames or { "No players available" }
            end,

            TeleportToPlayer = function(playerName)
                if not playerName or playerName == "No players available" then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "No player selected!",
                        Duration = 2
                    })
                    return false
                end

                local char, hrp = validateCharacter()
                if not char or not hrp then return false end

                local targetPlayer = Players:FindFirstChild(playerName)
                if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = playerName .. " not found or no character!",
                        Duration = 2
                    })
                    return false
                end

                local targetHRP = targetPlayer.Character.HumanoidRootPart
                safeTeleport(hrp, targetHRP.Position, { char, targetPlayer.Character })
                
                Fluent:Notify({
                    Title = "Success",
                    Content = "Teleported to " .. playerName,
                    Duration = 2
                })
                return true
            end,

            TeleportToRandomPlayer = function()
                local char, hrp = validateCharacter()
                if not char or not hrp then return false end

                local players = {}
                for _, pl in pairs(Players:GetPlayers()) do
                    if pl ~= LocalPlayer and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                        table.insert(players, pl)
                    end
                end

                if #players == 0 then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "No other players found!",
                        Duration = 2
                    })
                    return false
                end

                local randomPlayer = players[math.random(1, #players)]
                local targetHRP = randomPlayer.Character.HumanoidRootPart
                safeTeleport(hrp, targetHRP.Position, { char, randomPlayer.Character })
                
                Fluent:Notify({
                    Title = "Success",
                    Content = "Teleported to " .. randomPlayer.Name,
                    Duration = 2
                })
                return true
            end,

            TeleportToNearestDowned = function()
                local char, hrp = validateCharacter()
                if not char or not hrp then return false end

                local nearestPlayer, distance = findNearestDownedPlayer()
                if not nearestPlayer then
                    Fluent:Notify({
                        Title = "Teleport Error",
                        Content = "No downed players found!",
                        Duration = 2
                    })
                    return false
                end

                local targetHRP = nearestPlayer.Character.HumanoidRootPart
                safeTeleport(hrp, targetHRP.Position, { char, nearestPlayer.Character })
                
                Fluent:Notify({
                    Title = "Success",
                    Content = "Teleported to " .. nearestPlayer.Name .. " (" .. math.floor(distance) .. " studs)",
                    Duration = 2
                })
                return true
            end,
        }
    end)()

    -- ==================== CREATE TELEPORT TAB ====================
    local TeleportTab = Window:AddTab({ Title = "Teleport", Icon = "navigation" })
    local selectedPlayerName = nil

    -- Map Teleports Section
    TeleportTab:AddSection("Map Teleports")
    
    TeleportTab:AddButton({
        Title = "Teleport to Sky",
        Description = "Teleport to sky position for current map",
        Callback = function()
            TeleportModule.TeleportPlayer("Sky")
        end
    })

    TeleportTab:AddButton({
        Title = "Teleport to Far",
        Description = "Teleport to far position for current map",
        Callback = function()
            TeleportModule.TeleportPlayer("Far")
        end
    })

    TeleportTab:AddDivider()

    -- Objective Teleports Section
    TeleportTab:AddSection("Objective Teleports")

    TeleportTab:AddButton({
        Title = "Teleport to Random Objective",
        Description = "Teleport to a random objective",
        Callback = function()
            TeleportFeaturesModule.TeleportToRandomObjective()
        end
    })

    TeleportTab:AddButton({
        Title = "Teleport to Nearest Ticket",
        Description = "Teleport to the closest ticket",
        Callback = function()
            TeleportFeaturesModule.TeleportToNearestTicket()
        end
    })

    TeleportTab:AddDivider()

    -- Player Teleports Section
    TeleportTab:AddSection("Player Teleports")

    -- Player Dropdown
    local playerList = TeleportFeaturesModule.GetPlayerList()
    
    local PlayerDropdown = TeleportTab:AddDropdown("PlayerDropdown", {
        Title = "Select Player",
        Values = playerList,
        Multi = false,
        Default = playerList[1] or "No players available",
    })

    PlayerDropdown:OnChanged(function(value)
        if value ~= "No players available" then
            selectedPlayerName = value
        end
    end)

    -- Refresh Player List Button
    TeleportTab:AddButton({
        Title = "Refresh Player List",
        Description = "Update the player list",
        Callback = function()
            playerList = TeleportFeaturesModule.GetPlayerList()
            PlayerDropdown:SetValues(playerList)
            
            Fluent:Notify({
                Title = "Player List",
                Content = "Player list refreshed!",
                Duration = 2
            })
        end
    })

    TeleportTab:AddButton({
        Title = "Teleport to Selected Player",
        Description = "Teleport to the selected player",
        Callback = function()
            TeleportFeaturesModule.TeleportToPlayer(selectedPlayerName)
        end
    })

    TeleportTab:AddButton({
        Title = "Teleport to Random Player",
        Description = "Teleport to a random player",
        Callback = function()
            TeleportFeaturesModule.TeleportToRandomPlayer()
        end
    })

    TeleportTab:AddDivider()

    -- Downed Player Teleports Section
    TeleportTab:AddSection("Downed Player Teleports")

    TeleportTab:AddButton({
        Title = "Teleport to Nearest Downed Player",
        Description = "Teleport to the closest downed player",
        Callback = function()
            TeleportFeaturesModule.TeleportToNearestDowned()
        end
    })

    -- Auto-refresh player list
    task.spawn(function()
        while task.wait(10) do
            if TeleportTab and PlayerDropdown then
                playerList = TeleportFeaturesModule.GetPlayerList()
                PlayerDropdown:SetValues(playerList)
            end
        end
    end)

    -- Listen to player changes
    Players.PlayerAdded:Connect(function()
        task.wait(0.5)
        playerList = TeleportFeaturesModule.GetPlayerList()
        if PlayerDropdown then
            PlayerDropdown:SetValues(playerList)
        end
    end)

    Players.PlayerRemoving:Connect(function()
        task.wait(0.1)
        playerList = TeleportFeaturesModule.GetPlayerList()
        if PlayerDropdown then
            PlayerDropdown:SetValues(playerList)
        end
    end)

    Fluent:Notify({
        Title = "Teleport Module",
        Content = "Teleport features loaded successfully!",
        Duration = 3
    })

    return {
        Tab = TeleportTab,
        Module = TeleportModule,
        Features = TeleportFeaturesModule
    }
end
