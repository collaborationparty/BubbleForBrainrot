-- ================================================
-- EGGS TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local EggsTab = Window:Tab({ Title = "Eggs", Icon = "egg" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- ======================================
-- DATA MODULES
-- ======================================
local SecretBountyUtil = require(ReplicatedStorage.Shared.Utils.Stats.SecretBountyUtil)
local XLEggUtil = require(ReplicatedStorage.Shared.Utils.XLEggUtil)
local Rifts = require(ReplicatedStorage.Shared.Data.Rifts)
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.eggs then settings.eggs = {} end
local eggSettings = settings.eggs

-- ======================================
-- EGG LOCATIONS (permanent hardcoded list)
-- ======================================
local EGG_LOCATIONS = {
    ["Common Egg"] = Vector3.new(-80, 7, 5),
    ["Classic Egg"] = Vector3.new(-90, 13, 30),
    ["Vine Egg"] = Vector3.new(-61, 13, 11),
    ["Lava Egg"] = Vector3.new(-69, 14, 19),
    ["Icy Egg"] = Vector3.new(-55, 14, 0),
    ["Iceshard Egg"] = Vector3.new(-119, 11, 13),
    ["Spotted Egg"] = Vector3.new(-11, 10, -69),
    ["Atlantis Egg"] = Vector3.new(-79, 14, 25),
    ["Mining Egg"] = Vector3.new(-122, 11, -69),
    ["Neon Egg"] = Vector3.new(-81, 10, -61),
    ["Cyber Egg"] = Vector3.new(-92, 10, -67),
    ["Rainbow Egg"] = Vector3.new(-140, 10, -57),
    ["Nightmare Egg"] = Vector3.new(-146, 10, -47),
    ["Infinity Egg"] = Vector3.new(-106, 12, -28),
    ["Secret Egg"] = Vector3.new(-19438, 8, 18839),
    ["Showman Egg"] = Vector3.new(-130, 10, -60),
    ["Spikey Egg"] = Vector3.new(-128, 10, 9),
    ["Magma Egg"] = Vector3.new(-137, 11, 3),
    ["Crystal Egg"] = Vector3.new(-144, 10, -5),
    ["Lunar Egg"] = Vector3.new(-148, 11, -15),
    ["Void Egg"] = Vector3.new(-150, 11, -26),
    ["Hell Egg"] = Vector3.new(-149, 11, -37),
    ["Harvest Egg"] = Vector3.new(292, 9, 197),
    ["Neon Pumpkin Egg"] = Vector3.new(284, 9, 207),
}

local EGG_WORLDS = {
    ["Common Egg"] = "The Overworld",
    ["Classic Egg"] = "The Overworld",
    ["Vine Egg"] = "The Overworld",
    ["Lava Egg"] = "The Overworld",
    ["Icy Egg"] = "The Overworld",
    ["Iceshard Egg"] = "The Overworld",
    ["Spotted Egg"] = "The Overworld",
    ["Atlantis Egg"] = "The Overworld",
    ["Mining Egg"] = "Minigame Paradise",
    ["Neon Egg"] = "Minigame Paradise",
    ["Cyber Egg"] = "Minigame Paradise",
    ["Rainbow Egg"] = "The Overworld",
    ["Nightmare Egg"] = "The Overworld",
    ["Infinity Egg"] = "The Overworld",
    ["Secret Egg"] = "The Overworld",
    ["Showman Egg"] = "The Overworld",
    ["Spikey Egg"] = "The Overworld",
    ["Magma Egg"] = "The Overworld",
    ["Crystal Egg"] = "The Overworld",
    ["Lunar Egg"] = "The Overworld",
    ["Void Egg"] = "The Overworld",
    ["Hell Egg"] = "The Overworld",
    ["Harvest Egg"] = "The Overworld",
    ["Neon Pumpkin Egg"] = "The Overworld",
}

local discoveredEggs = {}

-- Restore saved discovered eggs from settings
if eggSettings.discoveredEggs then
    for name, posData in pairs(eggSettings.discoveredEggs) do
        if type(posData) == "table" and #posData == 3 then
            discoveredEggs[name] = Vector3.new(posData[1], posData[2], posData[3])
        end
    end
end

-- ======================================
-- INVENTORY EGGS LIST
-- ======================================
local function getInventoryEggs()
    local eggs = {}
    local data = LocalData:Get()
    if data and data.Powerups then
        for name, amount in pairs(data.Powerups) do
            if name:find("Egg") and amount > 0 and name ~= "Royal Egg" then
                table.insert(eggs, name)
            end
        end
    end
    if #eggs == 0 then
        eggs = {"Dominus Egg", "Stellaris Egg", "Neon Crystal Egg"}
    end
    table.sort(eggs)
    return eggs
end

-- ======================================
-- AUTO-DISCOVERY FROM workspace.Rendered.Generic
-- ======================================
local function isRiftEggName(name)
    return name:lower() == name and name:find("%-egg$") ~= nil
end

local function is4xEgg(name)
    return name:lower():find("^4x") ~= nil or name:lower():find("4x luck") ~= nil
end

local function isPlaceholderEgg(name)
    return name == "Egg" or name == "ShadowEgg" or name == "CelestialEgg"
end

-- Scan current world — returns fresh list (doesn't merge with saved)
local function scanAndDiscoverEggs()
    local found = {}
    local rendered = workspace:FindFirstChild("Rendered")
    if not rendered then return found end

    local generic = rendered:FindFirstChild("Generic")
    if not generic then return found end

    for _, obj in ipairs(generic:GetChildren()) do
        if obj:IsA("Model") and obj.Name:lower():find("egg") then
            local name = obj.Name

            if isRiftEggName(name) then continue end
            if is4xEgg(name) then continue end
            if isPlaceholderEgg(name) then continue end

            local ok, pivot = pcall(function() return obj:GetPivot() end)
            if ok and pivot then
                found[name] = pivot.Position
            end
        end
    end

    return found
end

-- ======================================
-- VARIABLES
-- ======================================
local HATCH_AMOUNT = eggSettings.hatchAmount or 12
local selectedEgg = eggSettings.selectedEgg or "Common Egg"
local currentBountyPet = "Unknown"
local currentBountyEgg = "Unknown"
local currentBountyChance = "Unknown"

local corruptShadowEnabled = eggSettings.autoCorruptShadow or false
local overlordEnabled = eggSettings.autoOverlord or false
local fourXEnabled = eggSettings.auto4x or false
local shadowEnabled = eggSettings.autoShadow or false
local doodleEnabled = eggSettings.autoDoodle or false
local autoHatchEnabled = eggSettings.autoHatch or false
local spamEEnabled = eggSettings.autoSpamE or false
local hideAnimEnabled = eggSettings.hideAnim or false
local inventoryEnabled = false
local bountyEnabled = eggSettings.autoBounty or false
local riftEnabled = eggSettings.autoRiftBounty or false
local xlBountyRunning = false

local corruptShadowThread = nil
local overlordThread = nil
local fourXThread = nil
local shadowThread = nil
local doodleThread = nil
local autoHatchThread = nil
local spamEThread = nil
local inventoryThread = nil
local bountyThread = nil
local riftThread = nil
local xlBountyThread = nil

local inventoryEggList = getInventoryEggs()
local selectedInventoryEgg = eggSettings.inventoryEgg or inventoryEggList[1] or "Dominus Egg"

local lastTeleportTime = 0

local selectedXLEgg = ""

local function getXLEggs()
    local eggs = {}
    pcall(function()
        local xlEggs = XLEggUtil:GetEggs()
        if xlEggs then
            for _, egg in ipairs(xlEggs) do
                table.insert(eggs, egg)
            end
        end
    end)
    if #eggs == 0 then
        eggs = {"Rainbow Egg", "Crystal Ore Egg"}
    end
    return eggs
end

local xlEggList = getXLEggs()
selectedXLEgg = xlEggList[1]

-- ======================================
-- FUNCTIONS
-- ======================================
local function getRoot()
    local char = player.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
end

local function getDistance(pos)
    local root = getRoot()
    if root and pos then
        return (root.Position - pos).Magnitude
    end
    return 999999
end

local function eggNameToKey(name)
    return name:lower():gsub("%s+", "-")
end

-- ======================================
-- HIGHEST LUCK RIFT
-- ======================================
local function getRiftLuck(rift)
    local display = rift:FindFirstChild("Display")
    if display then
        local surfaceGui = display:FindFirstChild("SurfaceGui")
        if surfaceGui then
            for _, child in ipairs(surfaceGui:GetDescendants()) do
                if child:IsA("TextLabel") and child.Name == "Luck" then
                    local luck = child.Text:match("x(%d+)")
                    if luck then
                        return tonumber(luck)
                    end
                end
            end
        end
    end
    return 0
end

local function getHighestLuckRift(riftName)
    local riftFolder = workspace:FindFirstChild("Rendered")
    if riftFolder then
        riftFolder = riftFolder:FindFirstChild("Rifts")
        if riftFolder then
            local bestRift = nil
            local bestLuck = 0
            
            for _, rift in ipairs(riftFolder:GetChildren()) do
                if rift.Name == riftName then
                    local luck = getRiftLuck(rift)
                    if luck > bestLuck then
                        bestLuck = luck
                        bestRift = rift
                    end
                end
            end
            
            return bestRift, bestLuck
        end
    end
    return nil, 0
end

local function teleportToBestRift(eggName)
    local riftKey = eggNameToKey(eggName)
    local bestRift, bestLuck = getHighestLuckRift(riftKey)
    if bestRift then
        local spawn = bestRift:FindFirstChild("EggPlatformSpawn")
        if spawn then
            local part = spawn:FindFirstChild("Part")
            if part then
                local root = getRoot()
                if root then
                    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 5, 0))
                    root.Velocity = Vector3.zero
                    root.RotVelocity = Vector3.zero
                    return bestLuck
                end
            end
        end
    end
    return 0
end

local function teleportToEgg(eggName)
    local pos = EGG_LOCATIONS[eggName] or discoveredEggs[eggName]
    if not pos then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == eggName and obj:IsA("Model") then
                pos = obj:GetPivot().Position
                discoveredEggs[eggName] = pos
                break
            end
        end
    end
    if pos then
        local dist = getDistance(pos)
        if dist > 10 then
            local root = getRoot()
            if root then root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end
        end
        return true
    end
    return false
end

local function isRiftExists(riftName)
    local riftFolder = workspace:FindFirstChild("Rendered")
    if riftFolder then
        riftFolder = riftFolder:FindFirstChild("Rifts")
        if riftFolder and riftFolder:FindFirstChild(riftName) then
            return true
        end
    end
    return false
end

local function getRiftPositionByName(riftName)
    local riftFolder = workspace:FindFirstChild("Rendered")
    if riftFolder then
        local rifts = riftFolder:FindFirstChild("Rifts")
        if rifts then
            local rift = rifts:FindFirstChild(riftName)
            if rift then
                local spawn = rift:FindFirstChild("EggPlatformSpawn")
                if spawn then
                    local part = spawn:FindFirstChild("Part")
                    if part then return part.Position end
                end
                for _, child in ipairs(rift:GetDescendants()) do
                    if child:IsA("BasePart") then
                        return child.Position
                    end
                end
            end
        end
    end
    return nil
end

local function teleportToRiftSafely(riftName)
    local riftPos = getRiftPositionByName(riftName)
    if not riftPos then
        pcall(function() Remote:FireServer("TeleportToRift", riftName) end)
        return
    end
    
    local root = getRoot()
    if not root then return end
    
    root.CFrame = CFrame.new(riftPos + Vector3.new(0, 5, 0))
    root.Velocity = Vector3.zero
    root.RotVelocity = Vector3.zero
end

local function getAllEggNames()
    local eggs = {}
    local seen = {}
    
    for name, _ in pairs(EGG_LOCATIONS) do
        seen[name] = true
        table.insert(eggs, name)
    end
    
    for name, _ in pairs(EGG_WORLDS) do
        if not seen[name] then
            seen[name] = true
            table.insert(eggs, name)
        end
    end
    
    for name, _ in pairs(discoveredEggs) do
        if not seen[name] then
            seen[name] = true
            table.insert(eggs, name)
        end
    end
    
    table.sort(eggs)
    return eggs
end

local function updateBountyInfo()
    local ok, bounty = pcall(function()
        return SecretBountyUtil:Get()
    end)
    if ok and bounty then
        currentBountyPet = bounty.Name or "Unknown"
        currentBountyEgg = bounty.Egg or "Unknown"
        currentBountyChance = bounty.Chance and "1/" .. tostring(math.floor(1/bounty.Chance)) or "Unknown"
        return true
    end
    return false
end

local function getTimeUntilReset()
    local sign = workspace:FindFirstChild("Worlds")
    if sign then
        sign = sign:FindFirstChild("The Overworld")
        if sign then
            sign = sign:FindFirstChild("SecretBounty")
            if sign then
                local label = sign:FindFirstChild("Counter")
                if label then
                    label = label:FindFirstChild("Display")
                    if label then
                        label = label:FindFirstChild("SurfaceGui")
                        if label then
                            label = label:FindFirstChild("Label")
                            if label then
                                return label.Text
                            end
                        end
                    end
                end
            end
        end
    end
    return "Unknown"
end

local function toggleAutoHatchR()
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local screenGui = playerGui:FindFirstChild("ScreenGui")
        if screenGui then
            local hud = screenGui:FindFirstChild("HUD")
            if hud then
                local lootPool = hud:FindFirstChild("LootPoolViewer")
                if lootPool then
                    local keybinds = lootPool:FindFirstChild("Keybinds")
                    if keybinds then
                        local key2 = keybinds:FindFirstChild("2")
                        if key2 then
                            local btn = key2:FindFirstChild("Button")
                            if btn then
                                firesignal(btn.Activated)
                            end
                        end
                    end
                end
            end
        end
    end
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
end

-- ======================================
-- 4X EGG DETECTION
-- ======================================
local function find4xEgg()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("4x") then
            return obj
        end
    end
    return nil
end

-- ======================================
-- UI - SPECIAL EGGS
-- ======================================
EggsTab:Section({ Title = "------- Special Eggs -------" })

EggsTab:Toggle({
    Title = "Auto CorruptShadow Rift",
    Desc = "Priority 1 — Hatching Dark Rift Egg",
    Value = corruptShadowEnabled,
    Callback = function(v)
        corruptShadowEnabled = v
        eggSettings.autoCorruptShadow = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            corruptShadowThread = task.spawn(function()
                while corruptShadowEnabled do
                    if isRiftExists("corruptshadow-rift") then
                        getgenv().questActive = true
                        getgenv().questEgg = "Dark Rift Egg"
                        getgenv().ActivityStatus.current = "Doing CorruptShadow Rift right now"
                        getgenv().ActivityStatus.trigger = true
                        teleportToRiftSafely("corruptshadow-rift")
                        lastTeleportTime = tick()
                        task.wait(0.3)
                        while corruptShadowEnabled and isRiftExists("corruptshadow-rift") do
                            getgenv().questActive = true
                            getgenv().questEgg = "Dark Rift Egg"
                            if tick() - lastTeleportTime >= 3 then
                                teleportToRiftSafely("corruptshadow-rift")
                                lastTeleportTime = tick()
                            end
                            pcall(function() Remote:FireServer("HatchEgg", "Dark Rift Egg", HATCH_AMOUNT) end)
                            task.wait(0.05)
                        end
                        getgenv().ActivityStatus.current = "Finished CorruptShadow Rift"
                        getgenv().ActivityStatus.trigger = true
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                    end
                    task.wait(1)
                end
            end)
        else
            if corruptShadowThread then task.cancel(corruptShadowThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto Overlord Rift",
    Desc = "Priority 2 — Hatching Overlord Egg",
    Value = overlordEnabled,
    Callback = function(v)
        overlordEnabled = v
        eggSettings.autoOverlord = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            overlordThread = task.spawn(function()
                while overlordEnabled do
                    if isRiftExists("overlord-rift") and not isRiftExists("corruptshadow-rift") then
                        getgenv().questActive = true
                        getgenv().questEgg = "Overlord Egg"
                        getgenv().ActivityStatus.current = "Doing Overlord Rift right now"
                        getgenv().ActivityStatus.trigger = true
                        teleportToRiftSafely("overlord-rift")
                        lastTeleportTime = tick()
                        task.wait(0.3)
                        while overlordEnabled and isRiftExists("overlord-rift") do
                            getgenv().questActive = true
                            getgenv().questEgg = "Overlord Egg"
                            if tick() - lastTeleportTime >= 3 then
                                teleportToRiftSafely("overlord-rift")
                                lastTeleportTime = tick()
                            end
                            pcall(function() Remote:FireServer("HatchEgg", "Overlord Egg", HATCH_AMOUNT) end)
                            task.wait(0.05)
                        end
                        getgenv().ActivityStatus.current = "Finished Overlord Rift"
                        getgenv().ActivityStatus.trigger = true
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                    end
                    task.wait(1)
                end
            end)
        else
            if overlordThread then task.cancel(overlordThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto 4x Egg",
    Desc = "Priority 3 — Hatching 4x Luck Egg (auto-detects event name)",
    Value = fourXEnabled,
    Callback = function(v)
        fourXEnabled = v
        eggSettings.auto4x = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            fourXThread = task.spawn(function()
                local current4x = nil
                local last4xTeleport = 0
                while fourXEnabled do
                    if not isRiftExists("corruptshadow-rift") and not isRiftExists("overlord-rift") then
                        local egg = find4xEgg()
                        if egg then
                            current4x = egg
                            getgenv().questActive = true
                            getgenv().questEgg = egg.Name
                            getgenv().ActivityStatus.current = "Doing 4x " .. egg.Name .. " right now"
                            getgenv().ActivityStatus.trigger = true

                            local now = tick()
                            if now - last4xTeleport >= 3 then
                                local root = getRoot()
                                if root then
                                    local ok, pivot = pcall(function() return egg:GetPivot() end)
                                    if ok and pivot then
                                        root.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 5, 0))
                                        root.Velocity = Vector3.zero
                                        root.RotVelocity = Vector3.zero
                                    end
                                end
                                last4xTeleport = now
                            end

                            pcall(function() Remote:FireServer("HatchEgg", egg.Name, HATCH_AMOUNT) end)
                            task.wait(0.05)
                        else
                            if current4x then
                                getgenv().ActivityStatus.current = "Finished 4x Egg"
                                getgenv().ActivityStatus.trigger = true
                                getgenv().questActive = false
                                getgenv().questEgg = nil
                                current4x = nil
                            end
                            task.wait(1)
                        end
                    else
                        current4x = nil
                        task.wait(1)
                    end
                end
            end)
        else
            if fourXThread then task.cancel(fourXThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto Shadow Rift",
    Desc = "Priority 4 — Hatching Dark Rift Egg",
    Value = shadowEnabled,
    Callback = function(v)
        shadowEnabled = v
        eggSettings.autoShadow = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            shadowThread = task.spawn(function()
                while shadowEnabled do
                    local fourXExists = find4xEgg() ~= nil
                    if isRiftExists("shadow-rift") and not isRiftExists("corruptshadow-rift") and not isRiftExists("overlord-rift") and not fourXExists then
                        getgenv().questActive = true
                        getgenv().questEgg = "Dark Rift Egg"
                        getgenv().ActivityStatus.current = "Doing Shadow Rift right now"
                        getgenv().ActivityStatus.trigger = true
                        teleportToRiftSafely("shadow-rift")
                        lastTeleportTime = tick()
                        task.wait(0.3)
                        while shadowEnabled and isRiftExists("shadow-rift") do
                            getgenv().questActive = true
                            getgenv().questEgg = "Dark Rift Egg"
                            if tick() - lastTeleportTime >= 3 then
                                teleportToRiftSafely("shadow-rift")
                                lastTeleportTime = tick()
                            end
                            pcall(function() Remote:FireServer("HatchEgg", "Dark Rift Egg", HATCH_AMOUNT) end)
                            task.wait(0.05)
                        end
                        getgenv().ActivityStatus.current = "Finished Shadow Rift"
                        getgenv().ActivityStatus.trigger = true
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                    end
                    task.wait(1)
                end
            end)
        else
            if shadowThread then task.cancel(shadowThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto Doodle Rift",
    Desc = "Priority 5 — Hatching Doodle Egg",
    Value = doodleEnabled,
    Callback = function(v)
        doodleEnabled = v
        eggSettings.autoDoodle = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            doodleThread = task.spawn(function()
                while doodleEnabled do
                    local fourXExists = find4xEgg() ~= nil
                    if isRiftExists("doodle-rift") and not isRiftExists("corruptshadow-rift") and not isRiftExists("overlord-rift") and not isRiftExists("shadow-rift") and not fourXExists then
                        getgenv().questActive = true
                        getgenv().questEgg = "Doodle Egg"
                        getgenv().ActivityStatus.current = "Doing Doodle Rift right now"
                        getgenv().ActivityStatus.trigger = true
                        teleportToRiftSafely("doodle-rift")
                        lastTeleportTime = tick()
                        task.wait(0.3)
                        while doodleEnabled and isRiftExists("doodle-rift") do
                            getgenv().questActive = true
                            getgenv().questEgg = "Doodle Egg"
                            if tick() - lastTeleportTime >= 3 then
                                teleportToRiftSafely("doodle-rift")
                                lastTeleportTime = tick()
                            end
                            pcall(function() Remote:FireServer("HatchEgg", "Doodle Egg", HATCH_AMOUNT) end)
                            task.wait(0.05)
                        end
                        getgenv().ActivityStatus.current = "Finished Doodle Rift"
                        getgenv().ActivityStatus.trigger = true
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                    end
                    task.wait(1)
                end
            end)
        else
            if doodleThread then task.cancel(doodleThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
        end
    end,
})

-- ======================================
-- UI - HATCH SELECTED EGG (DYNAMIC DROPDOWN)
-- ======================================
EggsTab:Section({ Title = "------- Hatch Selected Egg -------" })

local eggDropdown = EggsTab:Dropdown({
    Title = "Select Egg",
    Values = getAllEggNames(),
    Value = selectedEgg,
    Callback = function(v)
        selectedEgg = v
        eggSettings.selectedEgg = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
    end,
})

local eggListParagraph = EggsTab:Paragraph({
    Title = "Egg List",
    Desc = "Eggs loaded. Click Rescan to refresh.",
})

EggsTab:Button({
    Title = "Re Scan The Egg Dropdown",
    Desc = "Auto-discovers new eggs from the world (replaces saved list)",
    Callback = function()
        -- Scan current world
        local found = scanAndDiscoverEggs()
        local newCount = 0

        -- REPLACE discovered eggs with fresh scan
        discoveredEggs = {}
        for name, pos in pairs(found) do
            discoveredEggs[name] = pos
            if not EGG_LOCATIONS[name] then
                newCount = newCount + 1
                print("[Eggs] Discovered: " .. name)
            end
        end

        -- Save to settings (replace old saved list)
        eggSettings.discoveredEggs = {}
        for name, pos in pairs(discoveredEggs) do
            eggSettings.discoveredEggs[name] = {pos.X, pos.Y, pos.Z}
        end
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()

        -- Mutate eggDropdown.Values IN PLACE (don't reassign)
        local newEggs = getAllEggNames()
        for i = #eggDropdown.Values, 1, -1 do
            eggDropdown.Values[i] = nil
        end
        for _, eggName in ipairs(newEggs) do
            table.insert(eggDropdown.Values, eggName)
        end

        -- Trigger WindUI rebuild
        local currentValue = eggDropdown.Value
        pcall(function() eggDropdown:Select(currentValue) end)

        local text = "Found " .. #newEggs .. " eggs"
        if newCount > 0 then
            text = text .. " (" .. newCount .. " new discovered + saved!)"
        else
            text = text .. " (saved list refreshed)"
        end
        pcall(function() eggListParagraph:SetDesc(text) end)
        print("[Eggs] Rescan: " .. text)
    end,
})

EggsTab:Input({
    Title = "Hatch Amount",
    Value = tostring(HATCH_AMOUNT),
    Placeholder = "12",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            HATCH_AMOUNT = n
            eggSettings.hatchAmount = n
            getgenv().HubSettings.eggs = eggSettings
            saveHubSettings()
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto Hatch (Teleport + Hatch)",
    Desc = "Hatches selected egg (pauses when special rift or quest is active)",
    Value = autoHatchEnabled,
    Callback = function(v)
        autoHatchEnabled = v
        eggSettings.autoHatch = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            autoHatchThread = task.spawn(function()
                local wasActive = false
                local currentLuck = 0
                local lastCheckTime = 0
                local riftExists = false
                local lastEgg = ""
                
                while autoHatchEnabled do
                    while getgenv().questActive and autoHatchEnabled do
                        wasActive = false
                        task.wait(0.5)
                    end
                    
                    local now = tick()
                    if now - lastCheckTime >= 5 or selectedEgg ~= lastEgg then
                        lastCheckTime = now
                        lastEgg = selectedEgg
                        local riftKey = eggNameToKey(selectedEgg)
                        riftExists = isRiftExists(riftKey)
                        if riftExists then
                            currentLuck = teleportToBestRift(selectedEgg)
                        end
                    end
                    
                    if riftExists then
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Auto Hatching " .. selectedEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        pcall(function() Remote:FireServer("HatchEgg", selectedEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    else
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Auto Hatching " .. selectedEgg
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        teleportToEgg(selectedEgg)
                        pcall(function() Remote:FireServer("HatchEgg", selectedEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                end
            end)
        else
            if autoHatchThread then task.cancel(autoHatchThread) end
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto Spam E",
    Desc = "Spams E key and hatches continuously",
    Value = spamEEnabled,
    Callback = function(v)
        spamEEnabled = v
        eggSettings.autoSpamE = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            spamEThread = task.spawn(function()
                local lastAutoHatchR = 0
                while spamEEnabled do
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    
                    local eggToHatch = nil
                    if getgenv().questActive and getgenv().questEgg then
                        eggToHatch = getgenv().questEgg
                    elseif bountyEnabled then
                        eggToHatch = currentBountyEgg
                    else
                        eggToHatch = selectedEgg
                    end
                    
                    if eggToHatch then
                        pcall(function() Remote:FireServer("HatchEgg", eggToHatch, HATCH_AMOUNT) end)
                    end
                    
                    if tick() - lastAutoHatchR >= 60 then
                        lastAutoHatchR = tick()
                        toggleAutoHatchR()
                    end
                    
                    task.wait(0.05)
                end
            end)
        else
            if spamEThread then task.cancel(spamEThread) end
        end
    end,
})

EggsTab:Toggle({
    Title = "Hide Hatch Animation",
    Desc = "Hides the hatch animation for better performance",
    Value = hideAnimEnabled,
    Callback = function(v)
        hideAnimEnabled = v
        eggSettings.hideAnim = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        getgenv().animationHidden = v
    end,
})

-- ======================================
-- UI - INVENTORY EGG
-- ======================================
EggsTab:Section({ Title = "------- Inventory Egg -------" })

EggsTab:Dropdown({
    Title = "Select Inventory Egg",
    Values = inventoryEggList,
    Value = selectedInventoryEgg,
    Callback = function(v)
        selectedInventoryEgg = v
        eggSettings.inventoryEgg = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
    end,
})

local invListParagraph = EggsTab:Paragraph({
    Title = "Inventory Eggs",
    Desc = "Inventory eggs loaded. Click Rescan to refresh.",
})

EggsTab:Button({
    Title = "Re Scan Inventory Eggs",
    Desc = "Refresh the inventory egg list",
    Callback = function()
        inventoryEggList = getInventoryEggs()
        selectedInventoryEgg = inventoryEggList[1]
        local text = "Found " .. #inventoryEggList .. " inventory eggs"
        pcall(function() invListParagraph:SetDesc(text) end)
        print("[Eggs] Inventory Rescan: " .. text)
    end,
})

EggsTab:Toggle({
    Title = "Auto Open Inventory Egg",
    Desc = "Automatically opens selected inventory egg",
    Value = false,
    Callback = function(v)
        inventoryEnabled = v
        if v then
            inventoryThread = task.spawn(function()
                while inventoryEnabled do
                    pcall(function() Remote:FireServer("HatchPowerupEgg", selectedInventoryEgg, HATCH_AMOUNT) end)
                    task.wait(0.5)
                end
            end)
        else
            if inventoryThread then task.cancel(inventoryThread) end
        end
    end,
})

-- ======================================
-- UI - BOUNTY HATCH
-- ======================================
updateBountyInfo()

EggsTab:Section({ Title = "------- Bounty Hatch -------" })

local bountyPetParagraph = EggsTab:Paragraph({
    Title = "Bounty Pet: " .. currentBountyPet,
    Desc = "Egg: " .. currentBountyEgg .. " | Chance: " .. currentBountyChance,
})

local bountyResetParagraph = EggsTab:Paragraph({
    Title = "Resets in: " .. getTimeUntilReset(),
    Desc = "Automatically updates",
})

local function refreshBountyLabels()
    updateBountyInfo()
    pcall(function() 
        bountyPetParagraph:SetTitle("Bounty Pet: " .. currentBountyPet)
        bountyPetParagraph:SetDesc("Egg: " .. currentBountyEgg .. " | Chance: " .. currentBountyChance)
    end)
    pcall(function() bountyResetParagraph:SetTitle("Resets in: " .. getTimeUntilReset()) end)
end

EggsTab:Toggle({
    Title = "Auto Bounty (Teleport + Hatch)",
    Desc = "Hatches current bounty egg (pauses when special rift or quest is active)",
    Value = bountyEnabled,
    Callback = function(v)
        bountyEnabled = v
        eggSettings.autoBounty = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            refreshBountyLabels()
            bountyThread = task.spawn(function()
                local wasActive = false
                local currentLuck = 0
                local lastCheckTime = 0
                local riftExists = false
                local lastEgg = ""
                
                while bountyEnabled do
                    while getgenv().questActive and bountyEnabled do
                        wasActive = false
                        task.wait(0.5)
                    end
                    
                    refreshBountyLabels()
                    
                    local now = tick()
                    if now - lastCheckTime >= 5 or currentBountyEgg ~= lastEgg then
                        lastCheckTime = now
                        lastEgg = currentBountyEgg
                        local riftKey = eggNameToKey(currentBountyEgg)
                        riftExists = isRiftExists(riftKey)
                        if riftExists then
                            currentLuck = teleportToBestRift(currentBountyEgg)
                        end
                    end
                    
                    if riftExists then
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Auto Hatching Bounty: " .. currentBountyPet .. " from " .. currentBountyEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        pcall(function() Remote:FireServer("HatchEgg", currentBountyEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    else
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Auto Hatching Bounty: " .. currentBountyPet .. " from " .. currentBountyEgg
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        teleportToEgg(currentBountyEgg)
                        pcall(function() Remote:FireServer("HatchEgg", currentBountyEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                end
            end)
        else
            if bountyThread then task.cancel(bountyThread) end
        end
    end,
})

EggsTab:Toggle({
    Title = "Auto Summon Rift for Bounty",
    Desc = "Summons bounty rift every 31 minutes",
    Value = riftEnabled,
    Callback = function(v)
        riftEnabled = v
        eggSettings.autoRiftBounty = v
        getgenv().HubSettings.eggs = eggSettings
        saveHubSettings()
        if v then
            refreshBountyLabels()
            local world = EGG_WORLDS[currentBountyEgg] or "The Overworld"
            pcall(function()
                RemoteFunction:InvokeServer("SummonRift", {
                    Type = "Egg",
                    Name = currentBountyEgg,
                    Time = 5,
                    Luck = 5,
                    World = world
                })
            end)
            riftThread = task.spawn(function()
                while riftEnabled do
                    task.wait(1860)
                    refreshBountyLabels()
                    pcall(function()
                        RemoteFunction:InvokeServer("SummonRift", {
                            Type = "Egg",
                            Name = currentBountyEgg,
                            Time = 5,
                            Luck = 5,
                            World = EGG_WORLDS[currentBountyEgg] or "The Overworld"
                        })
                    end)
                end
            end)
        else
            if riftThread then task.cancel(riftThread) end
        end
    end,
})

-- ======================================
-- UI - XL EGG BOUNTY
-- ======================================
EggsTab:Section({ Title = "------- XL Egg Bounty -------" })

EggsTab:Dropdown({
    Title = "Select XL Egg",
    Values = xlEggList,
    Value = selectedXLEgg,
    Callback = function(v)
        selectedXLEgg = v
    end,
})

EggsTab:Button({
    Title = "Re Scan XL Eggs",
    Callback = function()
        xlEggList = getXLEggs()
        selectedXLEgg = xlEggList[1]
        print("[XL Bounty] Found " .. #xlEggList .. " XL eggs")
    end,
})

EggsTab:Toggle({
    Title = "Auto XL Bounty (Teleport + Hatch)",
    Desc = "Hatches XL bounty eggs automatically",
    Value = false,
    Callback = function(v)
        xlBountyRunning = v
        if v then
            xlBountyThread = task.spawn(function()
                local wasActive = false
                local currentLuck = 0
                local lastCheckTime = 0
                local riftExists = false
                local lastEgg = ""
                
                while xlBountyRunning do
                    while getgenv().questActive and xlBountyRunning do
                        wasActive = false
                        task.wait(0.5)
                    end
                    
                    local now = tick()
                    if now - lastCheckTime >= 5 or selectedXLEgg ~= lastEgg then
                        lastCheckTime = now
                        lastEgg = selectedXLEgg
                        local riftKey = eggNameToKey(selectedXLEgg)
                        riftExists = isRiftExists(riftKey)
                        if riftExists then
                            currentLuck = teleportToBestRift(selectedXLEgg)
                        end
                    end
                    
                    if riftExists then
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Auto Hatching XL Bounty: " .. selectedXLEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        pcall(function() Remote:FireServer("HatchEgg", selectedXLEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    else
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Auto Hatching XL Bounty: " .. selectedXLEgg
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        teleportToEgg(selectedXLEgg)
                        pcall(function() Remote:FireServer("HatchEgg", selectedXLEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                end
            end)
        else
            if xlBountyThread then task.cancel(xlBountyThread) end
        end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1.5)
    
    if corruptShadowEnabled then
        corruptShadowThread = task.spawn(function()
            while corruptShadowEnabled do
                if isRiftExists("corruptshadow-rift") then
                    getgenv().questActive = true
                    getgenv().questEgg = "Dark Rift Egg"
                    getgenv().ActivityStatus.current = "Doing CorruptShadow Rift right now"
                    getgenv().ActivityStatus.trigger = true
                    teleportToRiftSafely("corruptshadow-rift")
                    lastTeleportTime = tick()
                    task.wait(0.3)
                    while corruptShadowEnabled and isRiftExists("corruptshadow-rift") do
                        getgenv().questActive = true
                        getgenv().questEgg = "Dark Rift Egg"
                        if tick() - lastTeleportTime >= 3 then
                            teleportToRiftSafely("corruptshadow-rift")
                            lastTeleportTime = tick()
                        end
                        pcall(function() Remote:FireServer("HatchEgg", "Dark Rift Egg", HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                    getgenv().ActivityStatus.current = "Finished CorruptShadow Rift"
                    getgenv().ActivityStatus.trigger = true
                    getgenv().questActive = false
                    getgenv().questEgg = nil
                end
                task.wait(1)
            end
        end)
    end
    
    if overlordEnabled then
        overlordThread = task.spawn(function()
            while overlordEnabled do
                if isRiftExists("overlord-rift") and not isRiftExists("corruptshadow-rift") then
                    getgenv().questActive = true
                    getgenv().questEgg = "Overlord Egg"
                    getgenv().ActivityStatus.current = "Doing Overlord Rift right now"
                    getgenv().ActivityStatus.trigger = true
                    teleportToRiftSafely("overlord-rift")
                    lastTeleportTime = tick()
                    task.wait(0.3)
                    while overlordEnabled and isRiftExists("overlord-rift") do
                        getgenv().questActive = true
                        getgenv().questEgg = "Overlord Egg"
                        if tick() - lastTeleportTime >= 3 then
                            teleportToRiftSafely("overlord-rift")
                            lastTeleportTime = tick()
                        end
                        pcall(function() Remote:FireServer("HatchEgg", "Overlord Egg", HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                    getgenv().ActivityStatus.current = "Finished Overlord Rift"
                    getgenv().ActivityStatus.trigger = true
                    getgenv().questActive = false
                    getgenv().questEgg = nil
                end
                task.wait(1)
            end
        end)
    end
    
    if fourXEnabled then
        fourXThread = task.spawn(function()
            local current4x = nil
            local last4xTeleport = 0
            while fourXEnabled do
                if not isRiftExists("corruptshadow-rift") and not isRiftExists("overlord-rift") then
                    local egg = find4xEgg()
                    if egg then
                        current4x = egg
                        getgenv().questActive = true
                        getgenv().questEgg = egg.Name
                        getgenv().ActivityStatus.current = "Doing 4x " .. egg.Name .. " right now"
                        getgenv().ActivityStatus.trigger = true

                        local now = tick()
                        if now - last4xTeleport >= 3 then
                            local root = getRoot()
                            if root then
                                local ok, pivot = pcall(function() return egg:GetPivot() end)
                                if ok and pivot then
                                    root.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 5, 0))
                                    root.Velocity = Vector3.zero
                                    root.RotVelocity = Vector3.zero
                                end
                            end
                            last4xTeleport = now
                        end

                        pcall(function() Remote:FireServer("HatchEgg", egg.Name, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    else
                        if current4x then
                            getgenv().ActivityStatus.current = "Finished 4x Egg"
                            getgenv().ActivityStatus.trigger = true
                            getgenv().questActive = false
                            getgenv().questEgg = nil
                            current4x = nil
                        end
                        task.wait(1)
                    end
                else
                    current4x = nil
                    task.wait(1)
                end
            end
        end)
    end
    
    if shadowEnabled then
        shadowThread = task.spawn(function()
            while shadowEnabled do
                local fourXExists = find4xEgg() ~= nil
                if isRiftExists("shadow-rift") and not isRiftExists("corruptshadow-rift") and not isRiftExists("overlord-rift") and not fourXExists then
                    getgenv().questActive = true
                    getgenv().questEgg = "Dark Rift Egg"
                    getgenv().ActivityStatus.current = "Doing Shadow Rift right now"
                    getgenv().ActivityStatus.trigger = true
                    teleportToRiftSafely("shadow-rift")
                    lastTeleportTime = tick()
                    task.wait(0.3)
                    while shadowEnabled and isRiftExists("shadow-rift") do
                        getgenv().questActive = true
                        getgenv().questEgg = "Dark Rift Egg"
                        if tick() - lastTeleportTime >= 3 then
                            teleportToRiftSafely("shadow-rift")
                            lastTeleportTime = tick()
                        end
                        pcall(function() Remote:FireServer("HatchEgg", "Dark Rift Egg", HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                    getgenv().ActivityStatus.current = "Finished Shadow Rift"
                    getgenv().ActivityStatus.trigger = true
                    getgenv().questActive = false
                    getgenv().questEgg = nil
                end
                task.wait(1)
            end
        end)
    end
    
    if doodleEnabled then
        doodleThread = task.spawn(function()
            while doodleEnabled do
                local fourXExists = find4xEgg() ~= nil
                if isRiftExists("doodle-rift") and not isRiftExists("corruptshadow-rift") and not isRiftExists("overlord-rift") and not isRiftExists("shadow-rift") and not fourXExists then
                    getgenv().questActive = true
                    getgenv().questEgg = "Doodle Egg"
                    getgenv().ActivityStatus.current = "Doing Doodle Rift right now"
                    getgenv().ActivityStatus.trigger = true
                    teleportToRiftSafely("doodle-rift")
                    lastTeleportTime = tick()
                    task.wait(0.3)
                    while doodleEnabled and isRiftExists("doodle-rift") do
                        getgenv().questActive = true
                        getgenv().questEgg = "Doodle Egg"
                        if tick() - lastTeleportTime >= 3 then
                            teleportToRiftSafely("doodle-rift")
                            lastTeleportTime = tick()
                        end
                        pcall(function() Remote:FireServer("HatchEgg", "Doodle Egg", HATCH_AMOUNT) end)
                        task.wait(0.05)
                    end
                    getgenv().ActivityStatus.current = "Finished Doodle Rift"
                    getgenv().ActivityStatus.trigger = true
                    getgenv().questActive = false
                    getgenv().questEgg = nil
                end
                task.wait(1)
            end
        end)
    end
    
    if autoHatchEnabled then
        autoHatchThread = task.spawn(function()
            local wasActive = false
            local currentLuck = 0
            local lastCheckTime = 0
            local riftExists = false
            local lastEgg = ""
            
            while autoHatchEnabled do
                while getgenv().questActive and autoHatchEnabled do
                    wasActive = false
                    task.wait(0.5)
                end
                
                local now = tick()
                if now - lastCheckTime >= 5 or selectedEgg ~= lastEgg then
                    lastCheckTime = now
                    lastEgg = selectedEgg
                    local riftKey = eggNameToKey(selectedEgg)
                    riftExists = isRiftExists(riftKey)
                    if riftExists then
                        currentLuck = teleportToBestRift(selectedEgg)
                    end
                end
                
                if riftExists then
                    if not wasActive then
                        getgenv().ActivityStatus.current = "Auto Hatching " .. selectedEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                        getgenv().ActivityStatus.trigger = true
                        wasActive = true
                    end
                    pcall(function() Remote:FireServer("HatchEgg", selectedEgg, HATCH_AMOUNT) end)
                    task.wait(0.05)
                else
                    if not wasActive then
                        getgenv().ActivityStatus.current = "Auto Hatching " .. selectedEgg
                        getgenv().ActivityStatus.trigger = true
                        wasActive = true
                    end
                    teleportToEgg(selectedEgg)
                    pcall(function() Remote:FireServer("HatchEgg", selectedEgg, HATCH_AMOUNT) end)
                    task.wait(0.05)
                end
            end
        end)
    end
    
    if spamEEnabled then
        spamEThread = task.spawn(function()
            local lastAutoHatchR = 0
            while spamEEnabled do
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                
                local eggToHatch = nil
                if getgenv().questActive and getgenv().questEgg then
                    eggToHatch = getgenv().questEgg
                elseif bountyEnabled then
                    eggToHatch = currentBountyEgg
                else
                    eggToHatch = selectedEgg
                end
                
                if eggToHatch then
                    pcall(function() Remote:FireServer("HatchEgg", eggToHatch, HATCH_AMOUNT) end)
                end
                
                if tick() - lastAutoHatchR >= 60 then
                    lastAutoHatchR = tick()
                    toggleAutoHatchR()
                end
                
                task.wait(0.05)
            end
        end)
    end
    
    if hideAnimEnabled then
        getgenv().animationHidden = true
    end
    
    if bountyEnabled then
        refreshBountyLabels()
        bountyThread = task.spawn(function()
            local wasActive = false
            local currentLuck = 0
            local lastCheckTime = 0
            local riftExists = false
            local lastEgg = ""
            
            while bountyEnabled do
                while getgenv().questActive and bountyEnabled do
                    wasActive = false
                    task.wait(0.5)
                end
                
                refreshBountyLabels()
                
                local now = tick()
                if now - lastCheckTime >= 5 or currentBountyEgg ~= lastEgg then
                    lastCheckTime = now
                    lastEgg = currentBountyEgg
                    local riftKey = eggNameToKey(currentBountyEgg)
                    riftExists = isRiftExists(riftKey)
                    if riftExists then
                        currentLuck = teleportToBestRift(currentBountyEgg)
                    end
                end
                
                if riftExists then
                    if not wasActive then
                        getgenv().ActivityStatus.current = "Auto Hatching Bounty: " .. currentBountyPet .. " from " .. currentBountyEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                        getgenv().ActivityStatus.trigger = true
                        wasActive = true
                    end
                    pcall(function() Remote:FireServer("HatchEgg", currentBountyEgg, HATCH_AMOUNT) end)
                    task.wait(0.05)
                else
                    if not wasActive then
                        getgenv().ActivityStatus.current = "Auto Hatching Bounty: " .. currentBountyPet .. " from " .. currentBountyEgg
                        getgenv().ActivityStatus.trigger = true
                        wasActive = true
                    end
                    teleportToEgg(currentBountyEgg)
                    pcall(function() Remote:FireServer("HatchEgg", currentBountyEgg, HATCH_AMOUNT) end)
                    task.wait(0.05)
                end
            end
        end)
    end
    
    if riftEnabled then
        refreshBountyLabels()
        local world = EGG_WORLDS[currentBountyEgg] or "The Overworld"
        pcall(function()
            RemoteFunction:InvokeServer("SummonRift", {
                Type = "Egg",
                Name = currentBountyEgg,
                Time = 5,
                Luck = 5,
                World = world
            })
        end)
        riftThread = task.spawn(function()
            while riftEnabled do
                task.wait(1860)
                refreshBountyLabels()
                pcall(function()
                    RemoteFunction:InvokeServer("SummonRift", {
                        Type = "Egg",
                        Name = currentBountyEgg,
                        Time = 5,
                        Luck = 5,
                        World = EGG_WORLDS[currentBountyEgg] or "The Overworld"
                    })
                end)
            end
        end)
    end
end)

print("[Eggs] Loaded!")
