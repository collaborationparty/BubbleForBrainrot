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
local SpecialEventUtil = require(ReplicatedStorage.Shared.Utils.SpecialEventUtil)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.eggs then settings.eggs = {} end
local eggSettings = settings.eggs

-- ======================================
-- EGG LOCATIONS
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

if eggSettings.discoveredEggs then
    for name, posData in pairs(eggSettings.discoveredEggs) do
        if type(posData) == "table" and #posData == 3 then
            discoveredEggs[name] = Vector3.new(posData[1], posData[2], posData[3])
        end
    end
end

-- ======================================
-- FUNCTIONS
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

local function isRiftEggName(name)
    return name:lower() == name and name:find("%-egg$") ~= nil
end

local function isMultiplierEgg(name)
    return name:lower():find("^4x") ~= nil or name:lower():find("^5x") ~= nil or name:lower():find("4x luck") ~= nil or name:lower():find("5x luck") ~= nil
end

local function isPlaceholderEgg(name)
    return name == "Egg" or name == "ShadowEgg" or name == "CelestialEgg"
end

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
            if isMultiplierEgg(name) then continue end
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
local currentBountyPet, currentBountyEgg, currentBountyRarity = "None", "None", "None"

local BOUNTY_RARITY_OPTIONS = {"Current", "Void", "Infinity", "Celestial", "Secret"}
local bountyRarityFilter = eggSettings.bountyRarityFilter or "Current"

local multiEggEnabled = eggSettings.autoMultiEgg or false
local adminShadowEnabled = eggSettings.autoAdminShadow or false
local doodleEnabled = eggSettings.autoDoodle or false
local autoHatchEnabled = eggSettings.autoHatch or false
local spamEEnabled = eggSettings.autoSpamE or false
local hideAnimEnabled = eggSettings.hideAnim or false
local inventoryEnabled = false
local bountyEnabled = eggSettings.autoBounty or false
local riftEnabled = eggSettings.autoRiftBounty or false
local xlBountyRunning = false

local multiEggThread, adminShadowThread, doodleThread, autoHatchThread, spamEThread, inventoryThread, bountyThread, riftThread, xlBountyThread

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

local function getTrueRarity(info)
    if not info then return "None" end
    if info.Void then return "Void" end
    if info.Infinity then return "Infinity" end
    if info.Celestial then return "Celestial" end
    if info.Rarity == "Secret" then return "Secret" end
    return info.Rarity or "None"
end

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
        
        local info = Pets[currentBountyPet]
        currentBountyRarity = getTrueRarity(info)
        return true
    end
    return false
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
                                pcall(function() firesignal(btn.Activated) end)
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

local function findMultiEgg()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local name = obj.Name:lower()
            if name:find("^4x") or name:find("^5x") or name:find("4x luck") or name:find("5x luck") then
                return obj
            end
        end
    end
    return nil
end

local function findAdminShadowEgg()
    local rendered = workspace:FindFirstChild("Rendered")
    if rendered then
        local generic = rendered:FindFirstChild("Generic")
        if generic then
            for _, obj in ipairs(generic:GetChildren()) do
                if obj:IsA("Model") and obj.Name == "Admin Shadow Egg" then
                    return obj
                end
            end
        end
    end
    return nil
end

-- ======================================
-- UI BUILDER
-- ======================================
task.spawn(function()
    task.wait(0.5)

    -- PART 1
    EggsTab:Section({ Title = "------- Special Eggs -------" })

    EggsTab:Toggle({
        Title = "Auto 4x / 5x Egg",
        Value = multiEggEnabled,
        Callback = function(v)
            multiEggEnabled = v
            eggSettings.autoMultiEgg = v
            saveHubSettings()
            if v then
                if multiEggThread then task.cancel(multiEggThread) end
                multiEggThread = task.spawn(function()
                    while multiEggEnabled do
                        local egg = findMultiEgg()
                        if egg then
                            getgenv().questActive = true
                            getgenv().questEgg = egg.Name
                            local root = getRoot()
                            if root then
                                local ok, pivot = pcall(function() return egg:GetPivot() end)
                                if ok and pivot then
                                    root.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 5, 0))
                                end
                            end
                            pcall(function() Remote:FireServer("HatchEgg", egg.Name, HATCH_AMOUNT) end)
                            task.wait(0.1)
                        else
                            -- REMOVED: getgenv().questActive = false
                            task.wait(1)
                        end
                    end
                end)
            elseif multiEggThread then
                task.cancel(multiEggThread)
            end
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Admin Shadow Egg",
        Value = adminShadowEnabled,
        Callback = function(v)
            adminShadowEnabled = v
            eggSettings.autoAdminShadow = v
            saveHubSettings()
            if v then
                if adminShadowThread then task.cancel(adminShadowThread) end
                adminShadowThread = task.spawn(function()
                    while adminShadowEnabled do
                        local egg = findAdminShadowEgg()
                        if egg then
                            getgenv().questActive = true
                            getgenv().questEgg = "Admin Shadow Egg"
                            local root = getRoot()
                            if root then
                                local ok, pivot = pcall(function() return egg:GetPivot() end)
                                if ok and pivot then
                                    root.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 5, 0))
                                end
                            end
                            pcall(function() Remote:FireServer("HatchEgg", "Admin Shadow Egg", HATCH_AMOUNT) end)
                            task.wait(0.1)
                        elseif SpecialEventUtil.IsEventActive("event-shadowadmin") then
                            local root = getRoot()
                            if root then root.CFrame = CFrame.new(128, 10, 89) end
                            task.wait(3)
                        else
                            -- REMOVED: getgenv().questActive = false
                            task.wait(1)
                        end
                    end
                end)
            elseif adminShadowThread then
                task.cancel(adminShadowThread)
            end
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Doodle Rift",
        Value = doodleEnabled,
        Callback = function(v)
            doodleEnabled = v
            eggSettings.autoDoodle = v
            saveHubSettings()
            if v then
                if doodleThread then task.cancel(doodleThread) end
                doodleThread = task.spawn(function()
                    while doodleEnabled do
                        if isRiftExists("doodle-rift") then
                            getgenv().questActive = true
                            getgenv().questEgg = "Doodle Egg"
                            teleportToRiftSafely("doodle-rift")
                            task.wait(0.3)
                            while doodleEnabled and isRiftExists("doodle-rift") do
                                pcall(function() Remote:FireServer("HatchEgg", "Doodle Egg", HATCH_AMOUNT) end)
                                task.wait(0.1)
                            end
                            -- REMOVED: getgenv().questActive = false
                        end
                        task.wait(1)
                    end
                end)
            elseif doodleThread then
                task.cancel(doodleThread)
            end
        end,
    })

    EggsTab:Section({ Title = "------- Hatch Selected Egg -------" })

    EggsTab:Dropdown({
        Title = "Select Egg",
        Values = getAllEggNames(),
        Value = selectedEgg,
        Callback = function(v)
            selectedEgg = v
            eggSettings.selectedEgg = v
            saveHubSettings()
        end,
    })

    EggsTab:Button({
        Title = "Re Scan The Egg Dropdown",
        Callback = function()
            local found = scanAndDiscoverEggs()
            discoveredEggs = {}
            for name, pos in pairs(found) do
                discoveredEggs[name] = pos
            end
            eggSettings.discoveredEggs = {}
            for name, pos in pairs(discoveredEggs) do
                eggSettings.discoveredEggs[name] = {pos.X, pos.Y, pos.Z}
            end
            saveHubSettings()
        end,
    })

    EggsTab:Input({
        Title = "Hatch Amount",
        Value = tostring(HATCH_AMOUNT),
        Callback = function(v)
            local n = tonumber(v)
            if n then
                HATCH_AMOUNT = n
                eggSettings.hatchAmount = n
                saveHubSettings()
            end
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Hatch",
        Value = autoHatchEnabled,
        Callback = function(v)
            autoHatchEnabled = v
            eggSettings.autoHatch = v
            saveHubSettings()
            if v then
                if autoHatchThread then task.cancel(autoHatchThread) end
                autoHatchThread = task.spawn(function()
                    while autoHatchEnabled do
                        local bountyOverride = bountyEnabled and (bountyRarityFilter == "Current" or currentBountyRarity == bountyRarityFilter)
                        while (getgenv().questActive or bountyOverride) and autoHatchEnabled do
                            task.wait(0.5)
                            bountyOverride = bountyEnabled and (bountyRarityFilter == "Current" or currentBountyRarity == bountyRarityFilter)
                        end
                        teleportToEgg(selectedEgg)
                        pcall(function() Remote:FireServer("HatchEgg", selectedEgg, HATCH_AMOUNT) end)
                        task.wait(0.1)
                    end
                end)
            elseif autoHatchThread then
                task.cancel(autoHatchThread)
            end
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Spam E",
        Value = spamEEnabled,
        Callback = function(v)
            spamEEnabled = v
            eggSettings.autoSpamE = v
            saveHubSettings()
            if v then
                if spamEThread then task.cancel(spamEThread) end
                spamEThread = task.spawn(function()
                    while spamEEnabled do
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(0.1)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        
                        local eggToHatch = getgenv().questActive and getgenv().questEgg or (bountyEnabled and currentBountyEgg or selectedEgg)
                        if eggToHatch then
                            pcall(function() Remote:FireServer("HatchEgg", eggToHatch, HATCH_AMOUNT) end)
                        end
                        task.wait(0.1)
                    end
                end)
            elseif spamEThread then
                task.cancel(spamEThread)
            end
        end,
    })

    EggsTab:Toggle({
        Title = "Hide Hatch Animation",
        Value = hideAnimEnabled,
        Callback = function(v)
            hideAnimEnabled = v
            eggSettings.hideAnim = v
            saveHubSettings()
            getgenv().animationHidden = v
        end,
    })

    task.wait(1)

    -- PART 2
    EggsTab:Section({ Title = "------- Inventory Egg -------" })

    EggsTab:Dropdown({
        Title = "Select Inventory Egg",
        Values = inventoryEggList,
        Value = selectedInventoryEgg,
        Callback = function(v)
            selectedInventoryEgg = v
            eggSettings.inventoryEgg = v
            saveHubSettings()
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Open Inventory Egg",
        Value = false,
        Callback = function(v)
            inventoryEnabled = v
            if v then
                if inventoryThread then task.cancel(inventoryThread) end
                inventoryThread = task.spawn(function()
                    while inventoryEnabled do
                        pcall(function() Remote:FireServer("HatchPowerupEgg", selectedInventoryEgg, HATCH_AMOUNT) end)
                        task.wait(0.5)
                    end
                end)
            elseif inventoryThread then
                task.cancel(inventoryThread)
            end
        end,
    })

    EggsTab:Section({ Title = "------- Bounty Hatch -------" })

    EggsTab:Dropdown({
        Title = "Prioritize Bounty Rarity",
        Values = BOUNTY_RARITY_OPTIONS,
        Value = bountyRarityFilter,
        Callback = function(v)
            bountyRarityFilter = v
            eggSettings.bountyRarityFilter = v
            saveHubSettings()
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Bounty",
        Value = bountyEnabled,
        Callback = function(v)
            bountyEnabled = v
            eggSettings.autoBounty = v
            saveHubSettings()
            if v then
                if bountyThread then task.cancel(bountyThread) end
                bountyThread = task.spawn(function()
                    while bountyEnabled do
                        updateBountyInfo()
                        local matchesFilter = (bountyRarityFilter == "Current") or (currentBountyRarity == bountyRarityFilter)
                        if matchesFilter and currentBountyEgg ~= "None" then
                            teleportToEgg(currentBountyEgg)
                            pcall(function() Remote:FireServer("HatchEgg", currentBountyEgg, HATCH_AMOUNT) end)
                            task.wait(0.1)
                        else
                            task.wait(2)
                        end
                    end
                end)
            elseif bountyThread then
                task.cancel(bountyThread)
            end
        end,
    })

    EggsTab:Toggle({
        Title = "Auto Summon Rift for Bounty",
        Value = riftEnabled,
        Callback = function(v)
            riftEnabled = v
            eggSettings.autoRiftBounty = v
            saveHubSettings()
            if v then
                if riftThread then task.cancel(riftThread) end
                riftThread = task.spawn(function()
                    while riftEnabled do
                        pcall(function()
                            RemoteFunction:InvokeServer("SummonRift", {
                                Type = "Egg",
                                Name = currentBountyEgg,
                                Time = 5,
                                Luck = 5,
                                World = EGG_WORLDS[currentBountyEgg] or "The Overworld"
                            })
                        end)
                        task.wait(1860)
                    end
                end)
            elseif riftThread then
                task.cancel(riftThread)
            end
        end,
    })

    EggsTab:Section({ Title = "------- XL Egg Bounty -------" })

    EggsTab:Dropdown({
        Title = "Select XL Egg",
        Values = xlEggList,
        Value = selectedXLEgg,
        Callback = function(v)
            selectedXLEgg = v
        end,
    })

    EggsTab:Toggle({
        Title = "Auto XL Bounty",
        Value = false,
        Callback = function(v)
            xlBountyRunning = v
            if v then
                if xlBountyThread then task.cancel(xlBountyThread) end
                xlBountyThread = task.spawn(function()
                    while xlBountyRunning do
                        teleportToEgg(selectedXLEgg)
                        pcall(function() Remote:FireServer("HatchEgg", selectedXLEgg, HATCH_AMOUNT) end)
                        task.wait(0.1)
                    end
                end)
            elseif xlBountyThread then
                task.cancel(xlBountyThread)
            end
        end,
    })

    -- ======================================
    -- AUTO-START SAVED TOGGLES
    -- ======================================
    task.wait(0.5)
    
    if multiEggEnabled then
        multiEggThread = task.spawn(function()
            while multiEggEnabled do
                local egg = findMultiEgg()
                if egg then
                    getgenv().questActive = true
                    getgenv().questEgg = egg.Name
                    local root = getRoot()
                    if root then
                        local ok, pivot = pcall(function() return egg:GetPivot() end)
                        if ok and pivot then root.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 5, 0)) end
                    end
                    pcall(function() Remote:FireServer("HatchEgg", egg.Name, HATCH_AMOUNT) end)
                    task.wait(0.1)
                else
                    task.wait(1)
                end
            end
        end)
    end

    if adminShadowEnabled then
        adminShadowThread = task.spawn(function()
            while adminShadowEnabled do
                local egg = findAdminShadowEgg()
                if egg then
                    getgenv().questActive = true
                    getgenv().questEgg = "Admin Shadow Egg"
                    local root = getRoot()
                    if root then
                        local ok, pivot = pcall(function() return egg:GetPivot() end)
                        if ok and pivot then root.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 5, 0)) end
                    end
                    pcall(function() Remote:FireServer("HatchEgg", "Admin Shadow Egg", HATCH_AMOUNT) end)
                    task.wait(0.1)
                elseif SpecialEventUtil.IsEventActive("event-shadowadmin") then
                    local root = getRoot()
                    if root then root.CFrame = CFrame.new(128, 10, 89) end
                    task.wait(3)
                else
                    task.wait(1)
                end
            end
        end)
    end

    if doodleEnabled then
        doodleThread = task.spawn(function()
            while doodleEnabled do
                if isRiftExists("doodle-rift") then
                    getgenv().questActive = true
                    getgenv().questEgg = "Doodle Egg"
                    teleportToRiftSafely("doodle-rift")
                    task.wait(0.3)
                    while doodleEnabled and isRiftExists("doodle-rift") do
                        pcall(function() Remote:FireServer("HatchEgg", "Doodle Egg", HATCH_AMOUNT) end)
                        task.wait(0.1)
                    end
                end
                task.wait(1)
            end
        end)
    end

    if autoHatchEnabled then
        autoHatchThread = task.spawn(function()
            while autoHatchEnabled do
                local bountyOverride = bountyEnabled and (bountyRarityFilter == "Current" or currentBountyRarity == bountyRarityFilter)
                while (getgenv().questActive or bountyOverride) and autoHatchEnabled do
                    task.wait(0.5)
                    bountyOverride = bountyEnabled and (bountyRarityFilter == "Current" or currentBountyRarity == bountyRarityFilter)
                end
                teleportToEgg(selectedEgg)
                pcall(function() Remote:FireServer("HatchEgg", selectedEgg, HATCH_AMOUNT) end)
                task.wait(0.1)
            end
        end)
    end

    if spamEEnabled then
        spamEThread = task.spawn(function()
            while spamEEnabled do
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                local eggToHatch = getgenv().questActive and getgenv().questEgg or (bountyEnabled and currentBountyEgg or selectedEgg)
                if eggToHatch then
                    pcall(function() Remote:FireServer("HatchEgg", eggToHatch, HATCH_AMOUNT) end)
                end
                task.wait(0.1)
            end
        end)
    end

    if hideAnimEnabled then
        getgenv().animationHidden = true
    end

    if bountyEnabled then
        bountyThread = task.spawn(function()
            while bountyEnabled do
                updateBountyInfo()
                local matchesFilter = (bountyRarityFilter == "Current") or (currentBountyRarity == bountyRarityFilter)
                if matchesFilter and currentBountyEgg ~= "None" then
                    teleportToEgg(currentBountyEgg)
                    pcall(function() Remote:FireServer("HatchEgg", currentBountyEgg, HATCH_AMOUNT) end)
                    task.wait(0.1)
                else
                    task.wait(2)
                end
            end
        end)
    end

    if riftEnabled then
        riftThread = task.spawn(function()
            while riftEnabled do
                pcall(function()
                    RemoteFunction:InvokeServer("SummonRift", {
                        Type = "Egg",
                        Name = currentBountyEgg,
                        Time = 5,
                        Luck = 5,
                        World = EGG_WORLDS[currentBountyEgg] or "The Overworld"
                    })
                end)
                task.wait(1860)
            end
        end)
    end
end)

print("[Eggs] Loaded!")
