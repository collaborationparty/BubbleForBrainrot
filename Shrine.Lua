-- ================================================
-- SHRINE TAB (WINDUI VERSION) - BUBBLE & DREAMER
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local ShrineTab = Window:Tab({ Title = "Shrine", Icon = "landmark" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

local request = http_request or request or (syn and syn.request)

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.shrine then settings.shrine = {} end
local shrineSettings = settings.shrine

-- ======================================
-- SETTINGS
-- ======================================
local bubbleEnabled = false
local dreamerEnabled = false

local bubbleThread = nil
local dreamerThread = nil

local CHECK_INTERVAL = 300  -- 5 minutes

-- Bubble Shrine potion list
local BUBBLE_POTION_OPTIONS = {}
do
    local POTION_TYPES = {"Lucky", "Speed", "Coins", "Mythic", "Tickets"}
    local POTION_LEVELS = {1, 2, 3}
    for _, name in ipairs(POTION_TYPES) do
        for _, level in ipairs(POTION_LEVELS) do
            table.insert(BUBBLE_POTION_OPTIONS, { Name = name, Level = level })
        end
    end
end

local BUBBLE_AMOUNT = 500
local DREAMER_AMOUNT = 15

local bubbleNotified = false
local dreamerNotified = false

-- ======================================
-- BUFF DETECTION
-- ======================================
local function isBubbleShrineBuffActive()
    local pg = player:FindFirstChild("PlayerGui")
    local sg = pg and pg:FindFirstChild("ScreenGui")
    local buffs = sg and sg:FindFirstChild("Buffs")
    local clip = buffs and buffs:FindFirstChild("Clip")
    local items = clip and clip:FindFirstChild("Items")
    if not items then return false end
    return items:FindFirstChild("ShrineBlessing") ~= nil
end

local function isDreamerShrineBuffActive()
    local pg = player:FindFirstChild("PlayerGui")
    local sg = pg and pg:FindFirstChild("ScreenGui")
    local buffs = sg and sg:FindFirstChild("Buffs")
    local clip = buffs and buffs:FindFirstChild("Clip")
    local items = clip and clip:FindFirstChild("Items")
    if not items then return false end
    return items:FindFirstChild("DreamerBlessing") ~= nil
end

-- ======================================
-- INVENTORY SCAN FOR BUBBLE SHRINE
-- ======================================
local function findBubblePotion()
    local data = LocalData:Get()
    if not data or not data.Potions then return nil end
    
    for _, option in ipairs(BUBBLE_POTION_OPTIONS) do
        for _, potion in pairs(data.Potions) do
            if potion.Name == option.Name and potion.Level == option.Level then
                if (potion.Amount or 0) >= BUBBLE_AMOUNT then
                    return potion
                end
                break
            end
        end
    end
    return nil
end

-- ======================================
-- WEBHOOK NOTIFY
-- ======================================
local function notifyUser(shrineName, message)
    local webhookURL = settings.webhook and settings.webhook.onlineURL or ""
    local discordID = settings.webhook and settings.webhook.userId or ""
    
    if webhookURL == "" then return end
    if not request then return end
    
    local pingMsg = ""
    if discordID ~= "" then
        pingMsg = "<@" .. discordID .. "> "
    end
    
    pcall(function()
        request({
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                content = pingMsg .. message,
                allowed_mentions = {parse = {"users"}},
                embeds = {{
                    title = "⚠️ " .. shrineName .. " Out of Stock",
                    description = "**" .. player.Name .. "** - " .. message,
                    color = 0xFF0000,
                    footer = {text = "Renoa Hub * " .. os.date("%Y-%m-%d %H:%M:%S")}
                }}
            })
        })
    end)
end

-- ======================================
-- BUBBLE SHRINE LOOP
-- ======================================
local function bubbleLoop()
    while bubbleEnabled do
        -- Check IMMEDIATELY on loop start, then wait 5 mins
        if isBubbleShrineBuffActive() then
            -- Buff still active, skip
        else
            local potion = findBubblePotion()
            if potion then
                local payload = {
                    Level = potion.Level,
                    Type = "Potion",
                    Name = potion.Name,
                    Amount = BUBBLE_AMOUNT
                }
                pcall(function() Remote:InvokeServer("DonateToShrine", payload) end)
                
                getgenv().ActivityStatus.current = "Donated " .. BUBBLE_AMOUNT .. " " .. potion.Name .. " " .. potion.Level .. " to Bubble Shrine"
                getgenv().ActivityStatus.trigger = true
                
                bubbleNotified = false
                task.wait(2) -- Wait for UI to update buffs
            else
                if not bubbleNotified then
                    bubbleNotified = true
                    notifyUser("Bubble Shrine", "No potion has enough stock to donate 500.")
                end
            end
        end
        
        task.wait(CHECK_INTERVAL)
    end
end

-- ======================================
-- DREAMER SHRINE LOOP
-- ======================================
local function dreamerLoop()
    while dreamerEnabled do
        -- Check IMMEDIATELY on loop start, then wait 5 mins
        if isDreamerShrineBuffActive() then
            -- Buff still active, skip
        else
            pcall(function() Remote:InvokeServer("DonateToDreamerShrine", DREAMER_AMOUNT) end)
            
            getgenv().ActivityStatus.current = "Donated " .. DREAMER_AMOUNT .. " to Dreamer Shrine"
            getgenv().ActivityStatus.trigger = true
            task.wait(2) -- Wait for UI to update buffs
            
            -- Check if donation actually worked
            if not isDreamerShrineBuffActive() then
                if not dreamerNotified then
                    dreamerNotified = true
                    notifyUser("Dreamer Shrine", "Dreamer Shrine donation failed - ran out of Dreamer Shards.")
                end
            else
                dreamerNotified = false
            end
        end
        
        task.wait(CHECK_INTERVAL)
    end
end

-- ======================================
-- UI - BUBBLE SHRINE
-- ======================================
ShrineTab:Section({ Title = "Bubble Shrine" })

ShrineTab:Paragraph({
    Title = "How it works",
    Desc = "Donates 500 of the first potion that has enough stock (Lucky/Speed/Coins/Mythic/Tickets levels 1-3). Auto-repeats when the buff expires. Pings you via online webhook if no potion has 500+.",
})

ShrineTab:Toggle({
    Title = "Auto Bubble Shrine",
    Desc = "Donates 500 of an available potion when buff expires (checks every 5 min)",
    Value = shrineSettings.autoBubble or false,
    Callback = function(v)
        bubbleEnabled = v
        shrineSettings.autoBubble = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
        if v then
            if bubbleThread then task.cancel(bubbleThread); bubbleThread = nil end
            bubbleNotified = false
            bubbleThread = task.spawn(bubbleLoop)
        else
            if bubbleThread then task.cancel(bubbleThread); bubbleThread = nil end
        end
    end,
})

-- ======================================
-- UI - DREAMER SHRINE
-- ======================================
ShrineTab:Section({ Title = "Dreamer Shrine" })

ShrineTab:Paragraph({
    Title = "How it works",
    Desc = "Donates 15 Dreamer currency when buff expires (checks every 5 min). Pings you via online webhook when it runs out.",
})

ShrineTab:Toggle({
    Title = "Auto Dreamer Shrine",
    Desc = "Donates 15 to Dreamer Shrine when buff expires (checks every 5 min)",
    Value = shrineSettings.autoDreamer or false,
    Callback = function(v)
        dreamerEnabled = v
        shrineSettings.autoDreamer = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
        if v then
            if dreamerThread then task.cancel(dreamerThread); dreamerThread = nil end
            dreamerNotified = false
            dreamerThread = task.spawn(dreamerLoop)
        else
            if dreamerThread then task.cancel(dreamerThread); dreamerThread = nil end
        end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1.5)
    
    if shrineSettings.autoBubble then
        bubbleEnabled = true
        bubbleNotified = false
        bubbleThread = task.spawn(bubbleLoop)
    end
    
    if shrineSettings.autoDreamer then
        dreamerEnabled = true
        dreamerNotified = false
        dreamerThread = task.spawn(dreamerLoop)
    end
end)

print("[Shrine] Loaded!")
