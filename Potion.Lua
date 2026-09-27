-- ================================================
-- POTION TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local PotionTab = Window:Tab({ Title = "Potions", Icon = "flask-conical" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

local RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.potions then settings.potions = {} end
local potionSettings = settings.potions

-- ======================================
-- NORMAL POTION
-- ======================================
local NORMAL_POTIONS = {"Lucky", "Speed", "Mythic", "Coins", "Tickets"}
local NORMAL_LEVELS = {1, 2, 3, 4, 5, 6, 7}

local normalOptions = {}
for _, name in ipairs(NORMAL_POTIONS) do
    for _, level in ipairs(NORMAL_LEVELS) do
        table.insert(normalOptions, name .. " " .. level)
    end
end

local selectedNormal = potionSettings.normalSelected or "Lucky 1"
local normalAmount = potionSettings.normalAmount or 250
local normalRunning = false
local normalThread = nil

-- ======================================
-- SPECIAL POTION
-- ======================================
local SPECIAL_POTIONS = {"Infinity Elixir", "Ultra Infinity Elixir", "Egg Elixir", "Star Elixir", "Secret Elixir"}

local selectedSpecial = potionSettings.specialSelected or "Infinity Elixir"
local specialAmount = potionSettings.specialAmount or 250
local specialRunning = false
local specialThread = nil

-- ======================================
-- EVENT POTION
-- ======================================
local eventPotions = {}
local selectedEvent = potionSettings.eventSelected or ""
local eventAmount = potionSettings.eventAmount or 250
local eventRunning = false
local eventThread = nil

local function getEventPotions()
    local events = {}
    local normalSpecial = {
        Lucky=true, Speed=true, Mythic=true, Coins=true, Tickets=true,
        ["Infinity Elixir"]=true, ["Ultra Infinity Elixir"]=true,
        ["Egg Elixir"]=true, ["Star Elixir"]=true, ["Secret Elixir"]=true
    }
    local data = LocalData:Get()
    if data and data.Potions then
        for _, potion in pairs(data.Potions) do
            local name = potion.Name
            if not normalSpecial[name] and potion.Amount > 0 then
                if not table.find(events, name) then
                    table.insert(events, name)
                end
            end
        end
    end
    if #events == 0 then
        events = {"Festive Elixir", "Carnival Elixir", "Heaven Elixir"}
    end
    table.sort(events)
    return events
end

eventPotions = getEventPotions()
if selectedEvent == "" then selectedEvent = eventPotions[1] or "" end

-- ======================================
-- UI - NORMAL POTION
-- ======================================
PotionTab:Section({ Title = "Normal Potion" })

PotionTab:Dropdown({
    Title = "Select Potion",
    Values = normalOptions,
    Value = selectedNormal,
    Callback = function(v)
        selectedNormal = v
        potionSettings.normalSelected = v
        getgenv().HubSettings.potions = potionSettings
        saveHubSettings()
    end,
})

PotionTab:Input({
    Title = "Amount (Max 250)",
    Value = tostring(normalAmount),
    Placeholder = "250",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            normalAmount = math.min(n, 250)
            potionSettings.normalAmount = normalAmount
            getgenv().HubSettings.potions = potionSettings
            saveHubSettings()
        end
    end,
})

PotionTab:Toggle({
    Title = "Auto Use Normal Potion",
    Desc = "Uses the selected potion continuously",
    Value = potionSettings.normalRunning or false,
    Callback = function(v)
        normalRunning = v
        potionSettings.normalRunning = v
        getgenv().HubSettings.potions = potionSettings
        saveHubSettings()
        if v then
            getgenv().ActivityStatus.current = "Start Auto use " .. selectedNormal
            getgenv().ActivityStatus.trigger = true
            
            normalThread = task.spawn(function()
                while normalRunning do
                    local parts = {}
                    for part in string.gmatch(selectedNormal, "%S+") do
                        table.insert(parts, part)
                    end
                    local potionName = table.concat(parts, " ", 1, #parts - 1)
                    local level = tonumber(parts[#parts]) or 1
                    
                    local data = LocalData:Get()
                    local actualAmount = normalAmount
                    if data and data.Potions then
                        for _, potion in pairs(data.Potions) do
                            if potion.Name == potionName and potion.Level == level then
                                if potion.Amount < normalAmount then
                                    actualAmount = potion.Amount
                                end
                                break
                            end
                        end
                    end
                    
                    if actualAmount > 0 then
                        pcall(function() RE:FireServer("UsePotion", potionName, level, actualAmount) end)
                    end
                    task.wait(0.1)
                end
            end)
        else
            if normalThread then task.cancel(normalThread) end
            getgenv().ActivityStatus.current = "Stopped Auto use " .. selectedNormal
            getgenv().ActivityStatus.trigger = true
        end
    end,
})

-- ======================================
-- UI - SPECIAL POTION
-- ======================================
PotionTab:Section({ Title = "Special Potion" })

PotionTab:Dropdown({
    Title = "Select Potion",
    Values = SPECIAL_POTIONS,
    Value = selectedSpecial,
    Callback = function(v)
        selectedSpecial = v
        potionSettings.specialSelected = v
        getgenv().HubSettings.potions = potionSettings
        saveHubSettings()
    end,
})

PotionTab:Input({
    Title = "Amount (Max 250)",
    Value = tostring(specialAmount),
    Placeholder = "250",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            specialAmount = math.min(n, 250)
            potionSettings.specialAmount = specialAmount
            getgenv().HubSettings.potions = potionSettings
            saveHubSettings()
        end
    end,
})

PotionTab:Toggle({
    Title = "Auto Use Special Potion",
    Desc = "Uses the selected special elixir continuously",
    Value = potionSettings.specialRunning or false,
    Callback = function(v)
        specialRunning = v
        potionSettings.specialRunning = v
        getgenv().HubSettings.potions = potionSettings
        saveHubSettings()
        if v then
            getgenv().ActivityStatus.current = "Start Auto use " .. selectedSpecial
            getgenv().ActivityStatus.trigger = true
            
            specialThread = task.spawn(function()
                while specialRunning do
                    local data = LocalData:Get()
                    local actualAmount = specialAmount
                    if data and data.Potions then
                        for _, potion in pairs(data.Potions) do
                            if potion.Name == selectedSpecial then
                                if potion.Amount < specialAmount then
                                    actualAmount = potion.Amount
                                end
                                break
                            end
                        end
                    end
                    
                    if actualAmount > 0 then
                        pcall(function() RE:FireServer("UsePotion", selectedSpecial, 1, actualAmount) end)
                    end
                    task.wait(0.1)
                end
            end)
        else
            if specialThread then task.cancel(specialThread) end
            getgenv().ActivityStatus.current = "Stopped Auto use " .. selectedSpecial
            getgenv().ActivityStatus.trigger = true
        end
    end,
})

-- ======================================
-- UI - EVENT POTION
-- ======================================
PotionTab:Section({ Title = "Event Potion" })

if #eventPotions > 0 then
    PotionTab:Dropdown({
        Title = "Select Event Potion",
        Values = eventPotions,
        Value = selectedEvent,
        Callback = function(v)
            selectedEvent = v
            potionSettings.eventSelected = v
            getgenv().HubSettings.potions = potionSettings
            saveHubSettings()
        end,
    })

    PotionTab:Input({
        Title = "Amount (Max 250)",
        Value = tostring(eventAmount),
        Placeholder = "250",
        Callback = function(v)
            local n = tonumber(v)
            if n then
                eventAmount = math.min(n, 250)
                potionSettings.eventAmount = eventAmount
                getgenv().HubSettings.potions = potionSettings
                saveHubSettings()
            end
        end,
    })

    PotionTab:Button({
        Title = "Re Scan Event Potions",
        Desc = "Refresh the list of detected event potions",
        Callback = function()
            eventPotions = getEventPotions()
            selectedEvent = eventPotions[1] or ""
            print("[Potions] Found " .. #eventPotions .. " event potions")
        end,
    })

    PotionTab:Toggle({
        Title = "Auto Use Event Potion",
        Desc = "Uses the selected event potion continuously",
        Value = potionSettings.eventRunning or false,
        Callback = function(v)
            eventRunning = v
            potionSettings.eventRunning = v
            getgenv().HubSettings.potions = potionSettings
            saveHubSettings()
            if v then
                getgenv().ActivityStatus.current = "Start Auto use " .. selectedEvent
                getgenv().ActivityStatus.trigger = true
                
                eventThread = task.spawn(function()
                    while eventRunning do
                        local data = LocalData:Get()
                        local actualAmount = eventAmount
                        local potionLevel = 1
                        if data and data.Potions then
                            for _, potion in pairs(data.Potions) do
                                if potion.Name == selectedEvent then
                                    potionLevel = potion.Level
                                    if potion.Amount < eventAmount then
                                        actualAmount = potion.Amount
                                    end
                                    break
                                end
                            end
                        end
                        
                        if actualAmount > 0 then
                            pcall(function() RE:FireServer("UsePotion", selectedEvent, potionLevel, actualAmount) end)
                        end
                        task.wait(0.1)
                    end
                end)
            else
                if eventThread then task.cancel(eventThread) end
                getgenv().ActivityStatus.current = "Stopped Auto use " .. selectedEvent
                getgenv().ActivityStatus.trigger = true
            end
        end,
    })
else
    PotionTab:Paragraph({
        Title = "No Event Potions Detected",
        Desc = "Click the rescan button to look for event potions in your inventory.",
    })

    PotionTab:Button({
        Title = "Re Scan Event Potions",
        Callback = function()
            eventPotions = getEventPotions()
            selectedEvent = eventPotions[1] or ""
            print("[Potions] Found " .. #eventPotions .. " event potions")
        end,
    })
end

print("[Potions] Loaded!")
