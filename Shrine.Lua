-- ================================================
-- SHRINE TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local ShrineTab = Window:Tab({ Title = "Shrine", Icon = "landmark" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
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
local permEnabled = false

local bubbleThread = nil
local dreamerThread = nil
local permThread = nil

local CHECK_INTERVAL = 300  -- 5 minutes

-- Bubble Shrine potion list (no dropdown, hardcoded)
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

-- Notification dedupe
local bubbleNotified = false
local dreamerNotified = false

-- Perm Shrine
local permSelectedPotion = shrineSettings.permPotion or "Lucky 6"
local permSelectedEgg = shrineSettings.permEgg or "Cyber Egg"
local permTargetBuff = shrineSettings.permTargetBuff or "Luck"
local permRerollEnabled = shrineSettings.permReroll or false
local permRerollNotified = false

-- ======================================
-- FUNCTIONS
-- ======================================
local function getPermShrineData()
    local data = LocalData:Get()
    if data and data.PermanentShrine then
        return data.PermanentShrine
    end
    return nil
end

local function getPermShrineRemaining()
    local shrine = getPermShrineData()
    if shrine and shrine.StartTime and shrine.StartTime > 0 then
        local currentTime = os.time()
        local elapsed = currentTime - shrine.StartTime
        local totalDuration = 12 * 3600
        return math.max(0, totalDuration - elapsed)
    end
    return 0
end

local function getPermShrineBuff()
    local shrine = getPermShrineData()
    return shrine and shrine.Buff or "Unknown"
end

local function getPermShrineXP()
    local shrine = getPermShrineData()
    return shrine and shrine.XPOffered or 0
end

local function forceShrineUIVisible()
    local playerGui = player:FindFirstChild("PlayerGui")
    local screenGui = playerGui and playerGui:FindFirstChild("ScreenGui")
    local shrineUI = screenGui and screenGui:FindFirstChild("PermanentShrine")
    
    if shrineUI and not shrineUI.Visible then
        shrineUI.Visible = true
        return true
    end
    return false
end

local function donatePermShrine(potionName)
    local parts = {}
    for part in string.gmatch(potionName, "%S+") do
        table.insert(parts, part)
    end
    local name = table.concat(parts, " ", 1, #parts - 1)
    local level = tonumber(parts[#parts]) or 6
    
    local currentXP = getPermShrineXP()
    
    if currentXP >= 1000000 then return true end
    
    local neededXP = 1000000 - currentXP
    local xpPerPotion = 2500
    local amountNeeded = math.ceil(neededXP / xpPerPotion)
    
    forceShrineUIVisible()
    task.wait(0.5)
    
    pcall(function()
        RemoteFunction:InvokeServer("DonateToPermanentShrine", name, level, amountNeeded)
    end)
    task.wait(2)
    
    return getPermShrineXP() >= 1000000
end

local function claimPermShrineBuff(eggName)
    forceShrineUIVisible()
    task.wait(0.5)
    
    pcall(function()
        RemoteEvent:FireServer("ClaimPermanentShrineBuff", eggName)
    end)
end

local function rerollPermShrine()
    forceShrineUIVisible()
    task.wait(0.5)
    
    pcall(function()
        RemoteEvent:FireServer("RerollPermanentShrine")
    end)
end

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
        task.wait(CHECK_INTERVAL)
        if not bubbleEnabled then break end
        
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
                task.wait(2)
            else
                if not bubbleNotified then
                    bubbleNotified = true
                    notifyUser("Bubble Shrine", "No potion has enough stock to donate 500.")
                end
            end
        end
    end
end

-- ======================================
-- DREAMER SHRINE LOOP
-- ======================================
local function dreamerLoop()
    while dreamerEnabled do
        task.wait(CHECK_INTERVAL)
        if not dreamerEnabled then break end
        
        if isDreamerShrineBuffActive() then
            -- Buff still active, skip
        else
            pcall(function() Remote:InvokeServer("DonateToDreamerShrine", DREAMER_AMOUNT) end)
            
            getgenv().ActivityStatus.current = "Donated " .. DREAMER_AMOUNT .. " to Dreamer Shrine"
            getgenv().ActivityStatus.trigger = true
            task.wait(2)
            
            if not isDreamerShrineBuffActive() then
                if not dreamerNotified then
                    dreamerNotified = true
                    notifyUser("Dreamer Shrine", "Dreamer Shrine donation failed - ran out of Dreamer Shards.")
                end
            else
                dreamerNotified = false
            end
        end
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
-- UI - PERM SHRINE
-- ======================================
ShrineTab:Section({ Title = "Perm Shrine" })

local permInfoParagraph = ShrineTab:Paragraph({
    Title = "Current Buff Info",
    Desc = "Buff: None | Egg: None | XP: 0/1M",
})

task.spawn(function()
    while true do
        task.wait(10)
        local shrine = getPermShrineData()
        if shrine then
            local buff = shrine.Buff or "None"
            local egg = shrine.Egg or "None"
            local xp = shrine.XPOffered or 0
            local remaining = getPermShrineRemaining()
            
            local timeText = ""
            if remaining > 0 then
                local hours = math.floor(remaining / 3600)
                local minutes = math.floor((remaining % 3600) / 60)
                timeText = " | " .. hours .. "h " .. minutes .. "m"
            end
            
            pcall(function() 
                permInfoParagraph:SetTitle("Current Buff: " .. tostring(buff))
                permInfoParagraph:SetDesc("Egg: " .. tostring(egg) .. " | XP: " .. tostring(xp) .. "/1M" .. timeText)
            end)
        end
    end
end)

ShrineTab:Dropdown({
    Title = "Donate Potion (Level 6 Only)",
    Values = {"Lucky 6", "Speed 6", "Coins 6", "Mythic 6", "Tickets 6"},
    Value = permSelectedPotion,
    Callback = function(v)
        permSelectedPotion = v
        shrineSettings.permPotion = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
    end,
})

ShrineTab:Dropdown({
    Title = "Egg",
    Values = {"Common Egg", "Cyber Egg", "Nightmare Egg", "Neon Egg", "Atlantis Egg", "Lava Egg", "Icy Egg", "Rainbow Egg", "Mining Egg", "Vine Egg", "Classic Egg"},
    Value = permSelectedEgg,
    Callback = function(v)
        permSelectedEgg = v
        shrineSettings.permEgg = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
    end,
})

ShrineTab:Dropdown({
    Title = "Target Buff",
    Values = {"Luck", "Secret", "Infinity", "Mythic", "Shiny"},
    Value = permTargetBuff,
    Callback = function(v)
        permTargetBuff = v
        shrineSettings.permTargetBuff = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
    end,
})

ShrineTab:Toggle({
    Title = "Reroll Until Target Buff",
    Desc = "Keeps rerolling until the target buff is obtained",
    Value = permRerollEnabled,
    Callback = function(v)
        permRerollEnabled = v
        shrineSettings.permReroll = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
        if not v then
            permRerollNotified = false
        end
    end,
})

ShrineTab:Toggle({
    Title = "Auto Perm Shrine",
    Desc = "Automatically donates + claims + rerolls Perm Shrine",
    Value = shrineSettings.autoPermShrine or false,
    Callback = function(v)
        permEnabled = v
        shrineSettings.autoPermShrine = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
        
        if v then
            permRerollNotified = false
            
            permThread = task.spawn(function()
                forceShrineUIVisible()
                task.wait(1)
                
                while permEnabled do
                    local remaining = getPermShrineRemaining()
                    local currentBuff = getPermShrineBuff()
                    local currentXP = getPermShrineXP()
                    
                    if remaining > 0 then
                        if permRerollEnabled and currentBuff ~= permTargetBuff then
                            getgenv().ActivityStatus.current = "Rerolling for " .. permTargetBuff .. " (current: " .. currentBuff .. ")"
                            getgenv().ActivityStatus.trigger = true
                            
                            forceShrineUIVisible()
                            rerollPermShrine()
                            task.wait(3)
                            
                            local newBuff = getPermShrineBuff()
                            if newBuff == currentBuff then
                                if not permRerollNotified then
                                    permRerollNotified = true
                                    
                                    local discordID = settings.activity and settings.activity.userId or ""
                                    local pingMsg = ""
                                    if discordID ~= "" then
                                        pingMsg = "<@" .. discordID .. "> "
                                    end
                                    
                                    getgenv().ActivityStatus.current = pingMsg .. "Perm Shrine: Out of rerolls! Final buff: " .. currentBuff
                                    getgenv().ActivityStatus.trigger = true
                                end
                                task.wait(30)
                            end
                        elseif currentBuff == permTargetBuff then
                            getgenv().ActivityStatus.current = "Perm Shrine got target buff: " .. currentBuff .. "!"
                            getgenv().ActivityStatus.trigger = true
                            
                            task.wait(math.min(remaining + 5, 300))
                            permRerollNotified = false
                        else
                            task.wait(math.min(remaining + 5, 300))
                        end
                    else
                        getgenv().ActivityStatus.current = "Perm Shrine: Starting new cycle"
                        getgenv().ActivityStatus.trigger = true
                        
                        forceShrineUIVisible()
                        task.wait(1)
                        
                        local xp = getPermShrineXP()
                        if xp < 1000000 then
                            getgenv().ActivityStatus.current = "Donating " .. permSelectedPotion .. " to Perm Shrine"
                            getgenv().ActivityStatus.trigger = true
                            
                            donatePermShrine(permSelectedPotion)
                            task.wait(3)
                        end
                        
                        getgenv().ActivityStatus.current = "Claiming Perm Shrine for " .. permSelectedEgg
                        getgenv().ActivityStatus.trigger = true
                        
                        forceShrineUIVisible()
                        task.wait(1)
                        claimPermShrineBuff(permSelectedEgg)
                        task.wait(5)
                        
                        permRerollNotified = false
                    end
                    
                    task.wait(2)
                end
            end)
        else
            if permThread then task.cancel(permThread) end
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
    
    if shrineSettings.autoPermShrine then
        permEnabled = true
        permRerollNotified = false
        
        permThread = task.spawn(function()
            forceShrineUIVisible()
            task.wait(1)
            
            while permEnabled do
                local remaining = getPermShrineRemaining()
                local currentBuff = getPermShrineBuff()
                local currentXP = getPermShrineXP()
                
                if remaining > 0 then
                    if permRerollEnabled and currentBuff ~= permTargetBuff then
                        getgenv().ActivityStatus.current = "Rerolling for " .. permTargetBuff .. " (current: " .. currentBuff .. ")"
                        getgenv().ActivityStatus.trigger = true
                        
                        forceShrineUIVisible()
                        rerollPermShrine()
                        task.wait(3)
                        
                        local newBuff = getPermShrineBuff()
                        if newBuff == currentBuff then
                            if not permRerollNotified then
                                permRerollNotified = true
                                
                                local discordID = settings.activity and settings.activity.userId or ""
                                local pingMsg = ""
                                if discordID ~= "" then
                                    pingMsg = "<@" .. discordID .. "> "
                                end
                                
                                getgenv().ActivityStatus.current = pingMsg .. "Perm Shrine: Out of rerolls! Final buff: " .. currentBuff
                                getgenv().ActivityStatus.trigger = true
                            end
                            task.wait(30)
                        end
                    elseif currentBuff == permTargetBuff then
                        getgenv().ActivityStatus.current = "Perm Shrine got target buff: " .. currentBuff .. "!"
                        getgenv().ActivityStatus.trigger = true
                        
                        task.wait(math.min(remaining + 5, 300))
                        permRerollNotified = false
                    else
                        task.wait(math.min(remaining + 5, 300))
                    end
                else
                    getgenv().ActivityStatus.current = "Perm Shrine: Starting new cycle"
                    getgenv().ActivityStatus.trigger = true
                    
                    forceShrineUIVisible()
                    task.wait(1)
                    
                    local xp = getPermShrineXP()
                    if xp < 1000000 then
                        getgenv().ActivityStatus.current = "Donating " .. permSelectedPotion .. " to Perm Shrine"
                        getgenv().ActivityStatus.trigger = true
                        
                        donatePermShrine(permSelectedPotion)
                        task.wait(3)
                    end
                    
                    getgenv().ActivityStatus.current = "Claiming Perm Shrine for " .. permSelectedEgg
                    getgenv().ActivityStatus.trigger = true
                    
                    forceShrineUIVisible()
                    task.wait(1)
                    claimPermShrineBuff(permSelectedEgg)
                    task.wait(5)
                    
                    permRerollNotified = false
                end
                
                task.wait(2)
            end
        end)
    end
end)

print("[Shrine] Loaded!")
