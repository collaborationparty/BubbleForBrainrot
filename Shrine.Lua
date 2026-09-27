-- ================================================
-- SHRINE TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local ShrineTab = Window:Tab({ Title = "Shrine", Icon = "landmark" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local RemoteFunction = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteFunction
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local RemoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

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

-- Bubble Shrine
local POTION_TYPES = {"Lucky", "Speed", "Coins", "Mythic", "Tickets"}
local POTION_LEVELS = {1, 2, 3}

local potionOptions = {}
for _, name in ipairs(POTION_TYPES) do
    for _, level in ipairs(POTION_LEVELS) do
        table.insert(potionOptions, name .. " " .. level)
    end
end

local BUBBLE = {
    Level = 1,
    Type = "Potion",
    Name = shrineSettings.bubbleType or "Lucky 1",
    Amount = shrineSettings.bubbleAmount or 500
}

local DREAMER_AMOUNT = shrineSettings.dreamerAmount or 15

-- Perm Shrine
local permSelectedPotion = shrineSettings.permPotion or "Lucky 6"
local permSelectedEgg = shrineSettings.permEgg or "Cyber Egg"
local permTargetBuff = shrineSettings.permTargetBuff or "Luck"
local permRerollEnabled = shrineSettings.permReroll or false
local permRerollNotified = false

-- ======================================
-- FUNCTIONS
-- ======================================
local function getBuffTime(buffName)
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local screenGui = playerGui:FindFirstChild("ScreenGui")
        if screenGui then
            local buffs = screenGui:FindFirstChild("Buffs")
            if buffs then
                for _, buff in ipairs(buffs:GetChildren()) do
                    if buff.Name == buffName then
                        local button = buff:FindFirstChild("Button")
                        if button then
                            local label = button:FindFirstChild("Label")
                            if label and label.Text ~= "" then return label.Text end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function isBuffExpired(buffName)
    local time = getBuffTime(buffName)
    if not time then return true end
    if time == "0:00:00" or time == "0s" then return true end
    return false
end

-- Perm Shrine functions
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

-- Old shrine functions
local function bubble()
    local parts = {}
    for part in string.gmatch(BUBBLE.Name, "%S+") do
        table.insert(parts, part)
    end
    local potionName = table.concat(parts, " ", 1, #parts - 1)
    local level = tonumber(parts[#parts]) or 1
    
    BUBBLE.Level = level
    BUBBLE.Name = potionName
    
    pcall(function() Remote:InvokeServer("DonateToShrine", BUBBLE) end)
end

local function dreamer()
    pcall(function() Remote:InvokeServer("DonateToDreamerShrine", DREAMER_AMOUNT) end)
end

-- ======================================
-- UI - BUBBLE SHRINE
-- ======================================
ShrineTab:Section({ Title = "Bubble Shrine" })

ShrineTab:Dropdown({
    Title = "Potion Type (Level 1-3)",
    Values = potionOptions,
    Value = BUBBLE.Name,
    Callback = function(v)
        BUBBLE.Name = v
        shrineSettings.bubbleType = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
    end,
})

ShrineTab:Input({
    Title = "Amount",
    Value = tostring(BUBBLE.Amount),
    Placeholder = "500",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            BUBBLE.Amount = n
            shrineSettings.bubbleAmount = n
            getgenv().HubSettings.shrine = shrineSettings
            saveHubSettings()
        end
    end,
})

ShrineTab:Toggle({
    Title = "Auto Bubble",
    Desc = "Donates to Bubble Shrine every 60 seconds",
    Value = shrineSettings.autoBubble or false,
    Callback = function(v)
        bubbleEnabled = v
        shrineSettings.autoBubble = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
        if v then
            getgenv().ActivityStatus.current = "Bubble Shrine Activated"
            getgenv().ActivityStatus.trigger = true
            bubble()
            bubbleThread = task.spawn(function()
                while bubbleEnabled do
                    task.wait(60)
                    if isBuffExpired("ShrineBlessing") then
                        getgenv().ActivityStatus.current = "Bubble Shrine Activated"
                        getgenv().ActivityStatus.trigger = true
                        bubble()
                    end
                end
            end)
        else
            if bubbleThread then task.cancel(bubbleThread); bubbleThread = nil end
        end
    end,
})

-- ======================================
-- UI - DREAMER SHRINE
-- ======================================
ShrineTab:Section({ Title = "Dreamer Shrine" })

ShrineTab:Input({
    Title = "Amount",
    Value = tostring(DREAMER_AMOUNT),
    Placeholder = "15",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            DREAMER_AMOUNT = n
            shrineSettings.dreamerAmount = n
            getgenv().HubSettings.shrine = shrineSettings
            saveHubSettings()
        end
    end,
})

ShrineTab:Toggle({
    Title = "Auto Dreamer",
    Desc = "Donates to Dreamer Shrine every 60 seconds",
    Value = shrineSettings.autoDreamer or false,
    Callback = function(v)
        dreamerEnabled = v
        shrineSettings.autoDreamer = v
        getgenv().HubSettings.shrine = shrineSettings
        saveHubSettings()
        if v then
            getgenv().ActivityStatus.current = "Dreamer Shrine Activated"
            getgenv().ActivityStatus.trigger = true
            dreamer()
            dreamerThread = task.spawn(function()
                while dreamerEnabled do
                    task.wait(60)
                    if isBuffExpired("DreamerBlessing") then
                        getgenv().ActivityStatus.current = "Dreamer Shrine Activated"
                        getgenv().ActivityStatus.trigger = true
                        dreamer()
                    end
                end
            end)
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
    
    -- Auto Bubble
    if shrineSettings.autoBubble then
        bubbleEnabled = true
        getgenv().ActivityStatus.current = "Bubble Shrine Activated"
        getgenv().ActivityStatus.trigger = true
        bubble()
        bubbleThread = task.spawn(function()
            while bubbleEnabled do
                task.wait(60)
                if isBuffExpired("ShrineBlessing") then
                    getgenv().ActivityStatus.current = "Bubble Shrine Activated"
                    getgenv().ActivityStatus.trigger = true
                    bubble()
                end
            end
        end)
    end
    
    -- Auto Dreamer
    if shrineSettings.autoDreamer then
        dreamerEnabled = true
        getgenv().ActivityStatus.current = "Dreamer Shrine Activated"
        getgenv().ActivityStatus.trigger = true
        dreamer()
        dreamerThread = task.spawn(function()
            while dreamerEnabled do
                task.wait(60)
                if isBuffExpired("DreamerBlessing") then
                    getgenv().ActivityStatus.current = "Dreamer Shrine Activated"
                    getgenv().ActivityStatus.trigger = true
                    dreamer()
                end
            end
        end)
    end
    
    -- Auto Perm Shrine
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
    
    print("[Shrine] Auto-started saved toggles!")
end)

print("[Shrine] Loaded!")
