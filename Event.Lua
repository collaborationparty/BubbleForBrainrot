-- ================================================
-- EVENT TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local EventTab = Window:Tab({ Title = "Event", Icon = "calendar" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local HttpService = game:GetService("HttpService")

local RemoteContainer = ReplicatedStorage.Shared.Framework.Network.Remote
local RemoteFunction = RemoteContainer.RemoteFunction
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)

local request = http_request or request or (syn and syn.request)

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.event then settings.event = {} end
local eventSettings = settings.event

-- ======================================
-- SETTINGS
-- ======================================
local selectedEvents = eventSettings.selectedEvents or {"Luck Event"}
if type(selectedEvents) == "string" then
    selectedEvents = {selectedEvents}
end

local eventRunning = false
local eventThread = nil

local autoHatchRiftEnabled = eventSettings.autoHatchRift or false
local autoHatchRiftThread = nil
local autoSummonRiftEnabled = eventSettings.autoSummonRift or false
local autoSummonRiftThread = nil

local HATCH_AMOUNT = 12
local riftName = "cloud-rift"
local riftEgg = "Cloudy Rift Egg"
local riftWorld = "The Overworld"

local EVENTS = {
    "Luck Event", "Shiny Event", "Mythic Event", "Celestial Event",
    "Secret Event", "Infinity Event", "XL Event", "Super Palooza"
}

-- ======================================
-- AUTUMN UPGRADES
-- ======================================
local AUTUMN_UPGRADES = {
    "Currency",
    "Luck",
    "SecretLuck",
    "InfinityLuck",
    "AutoRebirth",
}

local selectedUpgrades = eventSettings.selectedUpgrades or {}
if type(selectedUpgrades) == "string" then selectedUpgrades = {selectedUpgrades} end

-- ======================================
-- REBIRTH SHOP (14 items)
-- ======================================
local REBIRTH_SHOP_ITEMS = {
    "Lucky Lvl 7",
    "Speed Lvl 7",
    "Mythic Lvl 7",
    "Infinity Elixir x25",
    "Secret Elixir x25",
    "Ultra Infinity Elixir x25",
    "Purple Fragment",
    "Rainbow Fragment",
    "Shrine Ticket",
    "Autumn Elixir Lvl 4 x10",
    "Sinister Jack O' Lantern",
    "Illusionary King Mush",
    "Illusionary King Mush Mythic",
    "Illusionary King Mush XL",
}

local selectedRebirthItems = eventSettings.selectedRebirthItems or {}
if type(selectedRebirthItems) == "string" then selectedRebirthItems = {selectedRebirthItems} end

-- ======================================
-- AUTUMN SHOP (13 items)
-- ======================================
local AUTUMN_SHOP_ITEMS = {
    "Autumn Elixir Lvl 4",
    "Shadow Crystal",
    "Lucky Lvl 7",
    "Speed Lvl 7",
    "Mythic Lvl 7",
    "Infinity Elixir",
    "Secret Elixir",
    "Ultra Infinity Elixir",
    "Green Fragment",
    "Blue Fragment",
    "Boost Crystal",
    "Angelic Pumpkin",
    "Angelic Pumpkin XL",
}

local selectedShopItems = eventSettings.selectedShopItems or {}
if type(selectedShopItems) == "string" then selectedShopItems = {selectedShopItems} end

-- ======================================
-- THREAD HANDLES
-- ======================================
local autumnUpgradeBuying = false
local autumnUpgradeThread = nil
local rebirthShopBuying = false
local rebirthShopThread = nil
local autumnShopBuying = false
local autumnShopThread = nil
local autumnRebirthAuto = false
local autumnRebirthThread = nil

-- ======================================
-- EVENT BOARD READER
-- ======================================
local function getAllActiveEvents()
    local events = {}
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local screenGui = playerGui:FindFirstChild("ScreenGui")
        if screenGui then
            local eventBoard = screenGui:FindFirstChild("EventBoard")
            if eventBoard then
                local activeEvents = eventBoard:FindFirstChild("Frame") and eventBoard.Frame:FindFirstChild("Main") and eventBoard.Frame.Main:FindFirstChild("ActiveEvents")
                if activeEvents then
                    local container = activeEvents:FindFirstChild("Container")
                    if container then
                        local list = container:FindFirstChild("List")
                        if list then
                            for _, child in ipairs(list:GetChildren()) do
                                if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
                                    local frame = child:FindFirstChild("Frame")
                                    if frame then
                                        local title = frame:FindFirstChild("Title")
                                        if title then
                                            local eventLabel = title:FindFirstChild("Event")
                                            if eventLabel then
                                                local eventText = eventLabel.Text
                                                if eventText and eventText ~= "" then
                                                    table.insert(events, eventText)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return events
end

local function getActiveEventDisplay()
    local events = getAllActiveEvents()
    if #events == 0 then return "No Event" end
    return table.concat(events, ", ")
end

-- ======================================
-- SPAWNABLE RIFT FUNCTIONS
-- ======================================
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

local function teleportToBestRift(riftName)
    local bestRift, bestLuck = getHighestLuckRift(riftName)
    if bestRift then
        local spawn = bestRift:FindFirstChild("EggPlatformSpawn")
        if spawn then
            local part = spawn:FindFirstChild("Part")
            if part then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
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

local function summonRift()
    pcall(function()
        RemoteFunction:InvokeServer("SummonRift", {
            Type = "Egg",
            Name = riftEgg,
            Time = 5,
            Luck = 5,
            World = riftWorld
        })
    end)
end

-- ======================================
-- SUMMON WEBHOOK
-- ======================================
local lastSummonState = ""

local function sendSummonWebhook(success)
    local webhookURL = settings.activity and settings.activity.webhookURL or ""
    local discordID = settings.activity and settings.activity.userId or ""
    
    if webhookURL == "" then return end
    if not request then return end
    
    local content = ""
    local color = 0
    
    if success then
        content = "Summon Cloud Rift Success✅"
        color = 0x00FF00
    else
        if discordID ~= "" then
            content = "Failed Summoning Cloud Rift❌ <@" .. discordID .. ">"
        else
            content = "Failed Summoning Cloud Rift❌"
        end
        color = 0xFF0000
    end
    
    if content == lastSummonState then return end
    lastSummonState = content
    
    pcall(function()
        request({
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                content = content,
                embeds = {{
                    title = success and "✅ Rift Summoned" or "❌ Summon Failed",
                    description = "**" .. player.Name .. "**",
                    color = color,
                    footer = {text = "Renoa Hub * " .. os.date("%Y-%m-%d %H:%M:%S")}
                }}
            })
        })
    end)
end

-- ======================================
-- TRUE SECRET DETECTION
-- ======================================
local function isTrueSecret(info)
    if not info then return false end
    if info.Rarity ~= "Secret" then return false end
    if info.Celestial then return false end
    if info.Infinity then return false end
    if info.Void then return false end
    return true
end

-- ======================================
-- SKY ALTAR FUNCTIONS
-- ======================================
local function getSkyAltarPets()
    local groups = {
        Celestial = {
            Normal = {}, Shiny = {}, Mythic = {}, ShinyMythic = {}, XL = {},
        },
        Secret = {
            Normal = {}, Shiny = {}, Mythic = {}, ShinyMythic = {}, XL = {},
        },
    }
    
    local data = LocalData:Get()
    if data and data.Pets then
        for _, pet in pairs(data.Pets) do
            if not pet.Locked then
                local info = Pets[pet.Name]
                if info and info.Egg == "Stratus Egg" then
                    local variantGroup = "Normal"
                    if pet.XL then
                        variantGroup = "XL"
                    elseif pet.Shiny and pet.Mythic then
                        variantGroup = "ShinyMythic"
                    elseif pet.Mythic then
                        variantGroup = "Mythic"
                    elseif pet.Shiny then
                        variantGroup = "Shiny"
                    end
                    
                    if info.Celestial then
                        table.insert(groups.Celestial[variantGroup], pet)
                    elseif isTrueSecret(info) then
                        table.insert(groups.Secret[variantGroup], pet)
                    end
                end
            end
        end
    end
    
    return groups
end

local function getCooldownText()
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local skyAltar = playerGui:FindFirstChild("ScreenGui") and playerGui.ScreenGui:FindFirstChild("SkyAltar")
        if skyAltar then
            local cooldown = skyAltar:FindFirstChild("Frame") and skyAltar.Frame:FindFirstChild("Main") and skyAltar.Frame.Main:FindFirstChild("Cooldown")
            if cooldown then
                local current = cooldown:FindFirstChild("Current")
                if current then
                    return current.Text
                end
            end
        end
    end
    return nil
end

local function parseCooldown(text)
    if not text then return nil end
    local minutes, seconds = text:match("(%d+):(%d+)")
    if minutes and seconds then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end
    local secondsOnly = text:match("(%d+)s")
    if secondsOnly then
        return tonumber(secondsOnly)
    end
    return nil
end

local function useSkyAltar(pets)
    local playerGui = player:FindFirstChild("PlayerGui")
    local skyAltar = playerGui and playerGui:FindFirstChild("ScreenGui") and playerGui.ScreenGui:FindFirstChild("SkyAltar")
    
    if skyAltar then
        skyAltar.Visible = true
        task.wait(0.5)
        
        local payload = {}
        for i = 1, 3 do
            table.insert(payload, tostring(pets[i].Id))
        end
        
        local ok = pcall(function()
            RemoteFunction:InvokeServer("UseRebirthMachine", "SkyAltar", payload)
        end)
        
        task.wait(2)
        
        skyAltar.Visible = false
        
        return ok
    end
    return false
end

-- ======================================
-- UI - EVENT BOARD
-- ======================================
EventTab:Section({ Title = "Event Board" })

local activeEventParagraph = EventTab:Paragraph({
    Title = "Active: " .. getActiveEventDisplay(),
    Desc = "Updates every 15 min or when event changes",
})

local lastEventDisplay = getActiveEventDisplay()
local lastEventUpdate = tick()
local EVENT_UPDATE_INTERVAL = 900

task.spawn(function()
    while true do
        task.wait(30)
        
        local display = getActiveEventDisplay()
        local now = tick()
        
        local shouldUpdateUI = (now - lastEventUpdate) >= EVENT_UPDATE_INTERVAL
        local eventChanged = (display ~= lastEventDisplay)
        
        if eventChanged then
            pcall(function() activeEventParagraph:SetTitle("Active: " .. display) end)
            lastEventDisplay = display
            lastEventUpdate = now
            
            if display == "No Event" then
                getgenv().ActivityStatus.current = "Event Board = No Event (removed)"
            else
                getgenv().ActivityStatus.current = "Event Board = " .. display .. " (activated)"
            end
            getgenv().ActivityStatus.trigger = true
        elseif shouldUpdateUI then
            pcall(function() activeEventParagraph:SetTitle("Active: " .. display) end)
            lastEventUpdate = now
        end
    end
end)

EventTab:Dropdown({
    Title = "Select Events (Multi-Select)",
    Values = EVENTS,
    Value = selectedEvents,
    Multi = true,
    Callback = function(v)
        if type(v) == "table" then
            selectedEvents = v
        else
            selectedEvents = {v}
        end
        eventSettings.selectedEvents = selectedEvents
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
    end,
})

EventTab:Toggle({
    Title = "Auto Add Event",
    Desc = "Adds selected events to the Event Board every 15 minutes",
    Value = eventSettings.autoAddEvent or false,
    Callback = function(v)
        eventRunning = v
        eventSettings.autoAddEvent = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            eventThread = task.spawn(function()
                while eventRunning do
                    for _, eventName in ipairs(selectedEvents) do
                        if not eventRunning then break end
                        local value = type(eventName) == "table" and eventName[1] or eventName
                        pcall(function() RE:FireServer("PurchaseEventBoard", value) end)
                        task.wait(1)
                    end
                    task.wait(900)
                end
            end)
        else
            if eventThread then task.cancel(eventThread) end
        end
    end,
})

-- ======================================
-- UI - EVENT CHEST
-- ======================================
EventTab:Section({ Title = "Event Chest" })

local autumnChestClaiming = false
local autumnChestThread = nil

EventTab:Toggle({
    Title = "Auto Claim Autumn Chest",
    Desc = "Claims Autumn Chest when cooldown is ready",
    Value = eventSettings.autoClaimAutumnChest or false,
    Callback = function(v)
        autumnChestClaiming = v
        eventSettings.autoClaimAutumnChest = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            autumnChestThread = task.spawn(function()
                while autumnChestClaiming do
                    local data = LocalData:Get()
                    local cooldowns = data and data.Cooldowns
                    local cd = cooldowns and cooldowns["Autumn Chest"]

                    if cd and os.time() >= cd then
                        pcall(function()
                            Remote:FireServer("ClaimChest", "Autumn Chest")
                        end)
                    end
                    task.wait(5)
                end
            end)
        else
            if autumnChestThread then task.cancel(autumnChestThread) end
        end
    end,
})

-- ======================================
-- UI - AUTUMN UPGRADES
-- ======================================
EventTab:Section({ Title = "Autumn Upgrades" })

EventTab:Dropdown({
    Title = "Select Upgrades (Multi-Select)",
    Values = AUTUMN_UPGRADES,
    Value = selectedUpgrades,
    Multi = true,
    Callback = function(v)
        if type(v) == "table" then
            selectedUpgrades = v
        else
            selectedUpgrades = {v}
        end
        eventSettings.selectedUpgrades = selectedUpgrades
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
    end,
})

EventTab:Toggle({
    Title = "Auto Buy Selected Upgrades",
    Desc = "Buys the selected Autumn upgrades continuously",
    Value = eventSettings.autoBuyUpgrades or false,
    Callback = function(v)
        autumnUpgradeBuying = v
        eventSettings.autoBuyUpgrades = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            autumnUpgradeThread = task.spawn(function()
                while autumnUpgradeBuying do
                    for _, upgrade in ipairs(selectedUpgrades) do
                        if not autumnUpgradeBuying then break end
                        local value = type(upgrade) == "table" and upgrade[1] or upgrade
                        pcall(function() RE:FireServer("BuyAutumnUpgrade", value) end)
                        task.wait(0.5)
                    end
                    task.wait(5)
                end
            end)
        else
            if autumnUpgradeThread then task.cancel(autumnUpgradeThread) end
        end
    end,
})

-- ======================================
-- UI - REBIRTH SHOP
-- ======================================
EventTab:Section({ Title = "Rebirth Shop" })

EventTab:Dropdown({
    Title = "Select Items (Multi-Select)",
    Values = REBIRTH_SHOP_ITEMS,
    Value = selectedRebirthItems,
    Multi = true,
    Callback = function(v)
        if type(v) == "table" then
            selectedRebirthItems = v
        else
            selectedRebirthItems = {v}
        end
        eventSettings.selectedRebirthItems = selectedRebirthItems
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
    end,
})

EventTab:Toggle({
    Title = "Auto Buy Selected Items",
    Desc = "Buys the selected Rebirth shop items continuously",
    Value = eventSettings.autoBuyRebirthShop or false,
    Callback = function(v)
        rebirthShopBuying = v
        eventSettings.autoBuyRebirthShop = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            rebirthShopThread = task.spawn(function()
                while rebirthShopBuying do
                    for _, item in ipairs(selectedRebirthItems) do
                        if not rebirthShopBuying then break end
                        local value = type(item) == "table" and item[1] or item
                        local slotIndex = nil
                        for i, name in ipairs(REBIRTH_SHOP_ITEMS) do
                            if name == value then slotIndex = i; break end
                        end
                        if slotIndex then
                            pcall(function() RE:FireServer("BuyShopItem", "rebirth-shop", slotIndex, false) end)
                            task.wait(0.5)
                        end
                    end
                    task.wait(5)
                end
            end)
        else
            if rebirthShopThread then task.cancel(rebirthShopThread) end
        end
    end,
})

-- ======================================
-- UI - AUTUMN SHOP
-- ======================================
EventTab:Section({ Title = "Autumn Shop" })

EventTab:Dropdown({
    Title = "Select Items (Multi-Select)",
    Values = AUTUMN_SHOP_ITEMS,
    Value = selectedShopItems,
    Multi = true,
    Callback = function(v)
        if type(v) == "table" then
            selectedShopItems = v
        else
            selectedShopItems = {v}
        end
        eventSettings.selectedShopItems = selectedShopItems
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
    end,
})

EventTab:Toggle({
    Title = "Auto Buy Selected Items",
    Desc = "Buys the selected Autumn shop items continuously",
    Value = eventSettings.autoBuyShop or false,
    Callback = function(v)
        autumnShopBuying = v
        eventSettings.autoBuyShop = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            autumnShopThread = task.spawn(function()
                while autumnShopBuying do
                    for _, item in ipairs(selectedShopItems) do
                        if not autumnShopBuying then break end
                        local value = type(item) == "table" and item[1] or item
                        local slotIndex = nil
                        for i, name in ipairs(AUTUMN_SHOP_ITEMS) do
                            if name == value then slotIndex = i; break end
                        end
                        if slotIndex then
                            pcall(function() RE:FireServer("BuyShopItem", "autumn-shop", slotIndex, true) end)
                            task.wait(0.5)
                        end
                    end
                    task.wait(5)
                end
            end)
        else
            if autumnShopThread then task.cancel(autumnShopThread) end
        end
    end,
})

-- ======================================
-- UI - AUTUMN REBIRTH
-- ======================================
EventTab:Section({ Title = "Autumn Rebirth" })

EventTab:Toggle({
    Title = "Auto Autumn Rebirth",
    Desc = "Rebirths when progress is full",
    Value = eventSettings.autoAutumnRebirth or false,
    Callback = function(v)
        autumnRebirthAuto = v
        eventSettings.autoAutumnRebirth = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            autumnRebirthThread = task.spawn(function()
                while autumnRebirthAuto do
                    local playerGui = player:FindFirstChild("PlayerGui")
                    local sg = playerGui and playerGui:FindFirstChild("ScreenGui")
                    local ar = sg and sg:FindFirstChild("AutumnRebirth")

                    if ar then
                        local ok, progressLabel = pcall(function()
                            return ar.Frame.Inner.Frame.Progress.Info.Label
                        end)

                        if ok and progressLabel and progressLabel.Text then
                            local currStr, maxStr = progressLabel.Text:match("([%d,]+)%s*/%s*([%d,]+)")
                            if currStr and maxStr then
                                local currClean = currStr:gsub(",", "")
                                local maxClean = maxStr:gsub(",", "")
                                local current = tonumber(currClean)
                                local max = tonumber(maxClean)

                                if current and max and current >= max then
                                    local rebirthBtn = ar.Frame
                                        and ar.Frame:FindFirstChild("Inner")
                                        and ar.Frame.Inner:FindFirstChild("Frame")
                                        and ar.Frame.Inner.Frame:FindFirstChild("Buttons")
                                        and ar.Frame.Inner.Frame.Buttons:FindFirstChild("Rebirth")
                                        and ar.Frame.Inner.Frame.Buttons.Rebirth:FindFirstChild("Button")

                                    if rebirthBtn and (rebirthBtn:IsA("TextButton") or rebirthBtn:IsA("ImageButton")) then
                                        firesignal(rebirthBtn.Activated)
                                    else
                                        pcall(function()
                                            Remote:FireServer("AutumnRebirth")
                                        end)
                                    end
                                    task.wait(3)
                                end
                            end
                        end
                    end
                    task.wait(2)
                end
            end)
        else
            if autumnRebirthThread then task.cancel(autumnRebirthThread) end
        end
    end,
})

-- ======================================
-- UI - NONE (Spawnable Special Rift)
-- ======================================
EventTab:Section({ Title = "None" })

EventTab:Toggle({
    Title = "Auto Hatch",
    Desc = "Hatches Cloudy Rift Egg automatically",
    Value = autoHatchRiftEnabled,
    Callback = function(v)
        autoHatchRiftEnabled = v
        eventSettings.autoHatchRift = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            autoHatchRiftThread = task.spawn(function()
                local wasActive = false
                local currentLuck = 0
                local lastCheckTime = 0
                local riftExists = false
                
                while autoHatchRiftEnabled do
                    while getgenv().questActive and autoHatchRiftEnabled do
                        wasActive = false
                        task.wait(0.5)
                    end
                    
                    local higherPriorityActive = false
                    if isRiftExists("corruptshadow-rift") or isRiftExists("overlord-rift") or isRiftExists("shadow-rift") or isRiftExists("doodle-rift") then
                        higherPriorityActive = true
                    end
                    
                    if higherPriorityActive then
                        wasActive = false
                        riftExists = false
                        task.wait(1)
                        continue
                    end
                    
                    local now = tick()
                    if now - lastCheckTime >= 5 then
                        lastCheckTime = now
                        riftExists = isRiftExists(riftName)
                        if riftExists then
                            currentLuck = teleportToBestRift(riftName)
                        end
                    end
                    
                    if riftExists then
                        if getgenv().questActive then continue end
                        
                        getgenv().questActive = true
                        getgenv().questEgg = riftEgg
                        
                        if not wasActive then
                            getgenv().ActivityStatus.current = "Hatching " .. riftEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                            getgenv().ActivityStatus.trigger = true
                            wasActive = true
                        end
                        
                        pcall(function() RE:FireServer("HatchEgg", riftEgg, HATCH_AMOUNT) end)
                        task.wait(0.05)
                    else
                        if wasActive then
                            getgenv().ActivityStatus.current = "Rift gone, waiting..."
                            getgenv().ActivityStatus.trigger = true
                            wasActive = false
                        end
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                        task.wait(1)
                    end
                end
            end)
        else
            if autoHatchRiftThread then task.cancel(autoHatchRiftThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
        end
    end,
})

EventTab:Toggle({
    Title = "Auto Summon",
    Desc = "Summons Cloudy Rift every 55 minutes",
    Value = autoSummonRiftEnabled,
    Callback = function(v)
        autoSummonRiftEnabled = v
        eventSettings.autoSummonRift = v
        getgenv().HubSettings.event = eventSettings
        saveHubSettings()
        if v then
            autoSummonRiftThread = task.spawn(function()
                while autoSummonRiftEnabled do
                    getgenv().ActivityStatus.current = "Summoning " .. riftName
                    getgenv().ActivityStatus.trigger = true
                    
                    summonRift()
                    task.wait(5)
                    
                    if isRiftExists(riftName) then
                        sendSummonWebhook(true)
                    else
                        sendSummonWebhook(false)
                    end
                    
                    task.wait(3300)
                end
            end)
        else
            if autoSummonRiftThread then task.cancel(autoSummonRiftThread) end
        end
    end,
})

-- ======================================
-- UI - NONE (Event Altar)
-- ======================================
EventTab:Section({ Title = "None" })

EventTab:Paragraph({
    Title = "⚠️ Warning",
    Desc = "Make sure to LOCK your Rainshine if you don't want it to be used!",
})

EventTab:Paragraph({
    Title = "Priority",
    Desc = "Celestial (Rainshine) > Secret (Empyrean Bolt). Groups by variant: Normal, Shiny, Mythic, ShinyMythic, XL.",
})

local altarTrackerParagraph = EventTab:Paragraph({
    Title = "Last Used: None",
    Desc = "Waiting for first conversion",
})

local altarEnabled = false
local altarThread = nil

EventTab:Toggle({
    Title = "Auto Event Altar",
    Value = false,
    Callback = function(v)
        altarEnabled = v
        if v then
            altarThread = task.spawn(function()
                while altarEnabled do
                    local cooldownText = getCooldownText()
                    local cooldownSeconds = parseCooldown(cooldownText)
                    
                    if cooldownSeconds and cooldownSeconds > 0 then
                        pcall(function() altarTrackerParagraph:SetDesc("Cooldown: " .. cooldownText) end)
                        task.wait(math.min(cooldownSeconds + 5, 60))
                    else
                        local groups = getSkyAltarPets()
                        local selectedPets = {}
                        local mode = ""
                        
                        if #groups.Celestial.Normal >= 3 then
                            selectedPets = groups.Celestial.Normal
                            mode = "Celestial Normal"
                        elseif #groups.Celestial.Shiny >= 3 then
                            selectedPets = groups.Celestial.Shiny
                            mode = "Celestial Shiny"
                        elseif #groups.Celestial.Mythic >= 3 then
                            selectedPets = groups.Celestial.Mythic
                            mode = "Celestial Mythic"
                        elseif #groups.Celestial.ShinyMythic >= 3 then
                            selectedPets = groups.Celestial.ShinyMythic
                            mode = "Celestial Shiny Mythic"
                        elseif #groups.Celestial.XL >= 3 then
                            selectedPets = groups.Celestial.XL
                            mode = "Celestial XL"
                        elseif #groups.Secret.Normal >= 3 then
                            selectedPets = groups.Secret.Normal
                            mode = "Secret Normal"
                        elseif #groups.Secret.Shiny >= 3 then
                            selectedPets = groups.Secret.Shiny
                            mode = "Secret Shiny"
                        elseif #groups.Secret.Mythic >= 3 then
                            selectedPets = groups.Secret.Mythic
                            mode = "Secret Mythic"
                        elseif #groups.Secret.ShinyMythic >= 3 then
                            selectedPets = groups.Secret.ShinyMythic
                            mode = "Secret Shiny Mythic"
                        elseif #groups.Secret.XL >= 3 then
                            selectedPets = groups.Secret.XL
                            mode = "Secret XL"
                        end
                        
                        if #selectedPets >= 3 then
                            pcall(function() altarTrackerParagraph:SetTitle("Converting: " .. mode) end)
                            local success = useSkyAltar(selectedPets)
                            if success then
                                getgenv().ActivityStatus.current = "Event Altar used (" .. mode .. ")"
                                getgenv().ActivityStatus.trigger = true
                                task.wait(10)
                            else
                                task.wait(5)
                            end
                        else
                            pcall(function() altarTrackerParagraph:SetDesc("Not enough pets (same variant)") end)
                            task.wait(60)
                        end
                    end
                end
            end)
        else
            if altarThread then task.cancel(altarThread) end
        end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1.5)
    
    -- Auto Add Event
    if eventSettings.autoAddEvent then
        eventRunning = true
        eventThread = task.spawn(function()
            while eventRunning do
                for _, eventName in ipairs(selectedEvents) do
                    if not eventRunning then break end
                    local value = type(eventName) == "table" and eventName[1] or eventName
                    pcall(function() RE:FireServer("PurchaseEventBoard", value) end)
                    task.wait(1)
                end
                task.wait(900)
            end
        end)
    end
    
    -- Auto Claim Autumn Chest
    if eventSettings.autoClaimAutumnChest then
        autumnChestClaiming = true
        autumnChestThread = task.spawn(function()
            while autumnChestClaiming do
                local data = LocalData:Get()
                local cooldowns = data and data.Cooldowns
                local cd = cooldowns and cooldowns["Autumn Chest"]
                if cd and os.time() >= cd then
                    pcall(function() Remote:FireServer("ClaimChest", "Autumn Chest") end)
                end
                task.wait(5)
            end
        end)
    end
    
    -- Auto Buy Selected Upgrades
    if eventSettings.autoBuyUpgrades then
        autumnUpgradeBuying = true
        autumnUpgradeThread = task.spawn(function()
            while autumnUpgradeBuying do
                for _, upgrade in ipairs(selectedUpgrades) do
                    if not autumnUpgradeBuying then break end
                    local value = type(upgrade) == "table" and upgrade[1] or upgrade
                    pcall(function() RE:FireServer("BuyAutumnUpgrade", value) end)
                    task.wait(0.5)
                end
                task.wait(5)
            end
        end)
    end
    
    -- Auto Buy Rebirth Shop Items
    if eventSettings.autoBuyRebirthShop then
        rebirthShopBuying = true
        rebirthShopThread = task.spawn(function()
            while rebirthShopBuying do
                for _, item in ipairs(selectedRebirthItems) do
                    if not rebirthShopBuying then break end
                    local value = type(item) == "table" and item[1] or item
                    local slotIndex = nil
                    for i, name in ipairs(REBIRTH_SHOP_ITEMS) do
                        if name == value then slotIndex = i; break end
                    end
                    if slotIndex then
                        pcall(function() RE:FireServer("BuyShopItem", "rebirth-shop", slotIndex, false) end)
                        task.wait(0.5)
                    end
                end
                task.wait(5)
            end
        end)
    end
    
    -- Auto Buy Autumn Shop Items
    if eventSettings.autoBuyShop then
        autumnShopBuying = true
        autumnShopThread = task.spawn(function()
            while autumnShopBuying do
                for _, item in ipairs(selectedShopItems) do
                    if not autumnShopBuying then break end
                    local value = type(item) == "table" and item[1] or item
                    local slotIndex = nil
                    for i, name in ipairs(AUTUMN_SHOP_ITEMS) do
                        if name == value then slotIndex = i; break end
                    end
                    if slotIndex then
                        pcall(function() RE:FireServer("BuyShopItem", "autumn-shop", slotIndex, true) end)
                        task.wait(0.5)
                    end
                end
                task.wait(5)
            end
        end)
    end
    
    -- Auto Autumn Rebirth
    if eventSettings.autoAutumnRebirth then
        autumnRebirthAuto = true
        autumnRebirthThread = task.spawn(function()
            while autumnRebirthAuto do
                local playerGui = player:FindFirstChild("PlayerGui")
                local sg = playerGui and playerGui:FindFirstChild("ScreenGui")
                local ar = sg and sg:FindFirstChild("AutumnRebirth")
                if ar then
                    local ok, progressLabel = pcall(function()
                        return ar.Frame.Inner.Frame.Progress.Info.Label
                    end)
                    if ok and progressLabel and progressLabel.Text then
                        local currStr, maxStr = progressLabel.Text:match("([%d,]+)%s*/%s*([%d,]+)")
                        if currStr and maxStr then
                            local currClean = currStr:gsub(",", "")
                            local maxClean = maxStr:gsub(",", "")
                            local current = tonumber(currClean)
                            local max = tonumber(maxClean)
                            if current and max and current >= max then
                                local rebirthBtn = ar.Frame
                                    and ar.Frame:FindFirstChild("Inner")
                                    and ar.Frame.Inner:FindFirstChild("Frame")
                                    and ar.Frame.Inner.Frame:FindFirstChild("Buttons")
                                    and ar.Frame.Inner.Frame.Buttons:FindFirstChild("Rebirth")
                                    and ar.Frame.Inner.Frame.Buttons.Rebirth:FindFirstChild("Button")
                                if rebirthBtn and (rebirthBtn:IsA("TextButton") or rebirthBtn:IsA("ImageButton")) then
                                    firesignal(rebirthBtn.Activated)
                                else
                                    pcall(function() Remote:FireServer("AutumnRebirth") end)
                                end
                                task.wait(3)
                            end
                        end
                    end
                end
                task.wait(2)
            end
        end)
    end
    
    -- None section toggles
    if eventSettings.autoHatchRift then
        autoHatchRiftEnabled = true
        autoHatchRiftThread = task.spawn(function()
            local wasActive = false
            local currentLuck = 0
            local lastCheckTime = 0
            local riftExists = false
            
            while autoHatchRiftEnabled do
                while getgenv().questActive and autoHatchRiftEnabled do
                    wasActive = false
                    task.wait(0.5)
                end
                
                local higherPriorityActive = false
                if isRiftExists("corruptshadow-rift") or isRiftExists("overlord-rift") or isRiftExists("shadow-rift") or isRiftExists("doodle-rift") then
                    higherPriorityActive = true
                end
                
                if higherPriorityActive then
                    wasActive = false
                    riftExists = false
                    task.wait(1)
                    continue
                end
                
                local now = tick()
                if now - lastCheckTime >= 5 then
                    lastCheckTime = now
                    riftExists = isRiftExists(riftName)
                    if riftExists then
                        currentLuck = teleportToBestRift(riftName)
                    end
                end
                
                if riftExists then
                    if getgenv().questActive then continue end
                    getgenv().questActive = true
                    getgenv().questEgg = riftEgg
                    if not wasActive then
                        getgenv().ActivityStatus.current = "Hatching " .. riftEgg .. (currentLuck > 0 and " (x" .. currentLuck .. " luck)" or "")
                        getgenv().ActivityStatus.trigger = true
                        wasActive = true
                    end
                    pcall(function() RE:FireServer("HatchEgg", riftEgg, HATCH_AMOUNT) end)
                    task.wait(0.05)
                else
                    if wasActive then
                        getgenv().ActivityStatus.current = "Rift gone, waiting..."
                        getgenv().ActivityStatus.trigger = true
                        wasActive = false
                    end
                    getgenv().questActive = false
                    getgenv().questEgg = nil
                    task.wait(1)
                end
            end
        end)
    end
    
    if eventSettings.autoSummonRift then
        autoSummonRiftEnabled = true
        autoSummonRiftThread = task.spawn(function()
            while autoSummonRiftEnabled do
                getgenv().ActivityStatus.current = "Summoning " .. riftName
                getgenv().ActivityStatus.trigger = true
                summonRift()
                task.wait(5)
                if isRiftExists(riftName) then
                    sendSummonWebhook(true)
                else
                    sendSummonWebhook(false)
                end
                task.wait(3300)
            end
        end)
    end
end)

print("[Event] Loaded!")
