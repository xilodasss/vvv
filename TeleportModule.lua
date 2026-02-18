-- ========================================================================== --
--                         TELEPORT MODULE - EXTERNAL                         --
--                    Last Update: 19 Feb 2026                                --
-- ========================================================================== --

local TeleportModule = {}

-- ==================== MAP SPOTS DATABASE ====================
TeleportModule.mapSpots = {
    ["DesertBus"] = {
        Far = CFrame.new(1350.6390380859375, -66.57595825195312, 913.889404296875, 
            0.08861260116100311, 0, 0.9960662126541138, 
            0, 1.0000001192092896, 0, 
            -0.9960662126541138, 0, 0.08861260116100311),
        Sky = CFrame.new(29.76473045349121, 69.4240493774414, -178.1037139892578, 
            0.6581460237503052, 0, 0.7528902888298035, 
            0, 1, 0, 
            -0.752890408039093, 0, 0.6581459641456604)
    },
    
    ["Mansion"] = {
        Far = CFrame.new(100, 10, 200),
        Sky = CFrame.new(50, 100, 150)
    },
    
    ["City"] = {
        Far = CFrame.new(500, 20, 300),
        Sky = CFrame.new(200, 150, 400)
    },
    
    ["Facility"] = {
        Far = CFrame.new(-150, 5, 350),
        Sky = CFrame.new(0, 200, 0)
    },
    
    ["Suburbs"] = {
        Far = CFrame.new(800, 10, -200),
        Sky = CFrame.new(400, 120, -100)
    },
}

-- ==================== FUNGSI ====================

function TeleportModule.GetCurrentMap()
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

function TeleportModule.HasMapData(mapName)
    return TeleportModule.mapSpots[mapName] ~= nil
end

function TeleportModule.GetMapSpot(mapName, spotType)
    if not TeleportModule.mapSpots[mapName] then return nil end
    return TeleportModule.mapSpots[mapName][spotType]
end

function TeleportModule.GetAllMapNames()
    local names = {}
    for name, _ in pairs(TeleportModule.mapSpots) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function TeleportModule.GetMapCount()
    local count = 0
    for _ in pairs(TeleportModule.mapSpots) do
        count = count + 1
    end
    return count
end

function TeleportModule.GetLastUpdate()
    return "19 Feb 2026"
end

return TeleportModule
