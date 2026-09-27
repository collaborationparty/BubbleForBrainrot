-- ================================================
-- QUEST TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local QuestTab = Window:Tab({ Title = "Quest", Icon = "scroll-text" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local constants = require(ReplicatedStorage.Shared.Constants)
local RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local HttpService = game:GetService("HttpService")

local request = http_request or request or (syn and syn.request)

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.quest then settings.quest = {} end
local questSettings = settings.quest

-- ======================================
-- NOTES
-- ======================================
QuestTab:Section({ Title = "Notes" })

QuestTab:Paragraph({
    Title = "Note #1",
    Desc = "Please make sure you have 1 Pearl and 1 Ticket currency pet in your hatching team to make it easier.",
})

QuestTab:Paragraph({
    Title = "Note #2",
    Desc = "Make sure you have Wooden Crate, Steel Crate, Golden Crate, Classic Crate, or Galaxy Crate. BUT if you don't have any of these it's okay — it will just skip the pearl collect quest and continue to next quest.",
})

-- ======================================
-- TELEPORT LOCATIONS
-- ======================================
local COIN_AREA = Vector3.new(36, 15971, 41)
local GEM_AREA = Vector3.new(2286, 3158, 842)
local TICKET_AREA = Vector3.new(9888, 20089, 242)
local SEVENSEAS_SPAWN = Vector3.new(-23663, 7, -80)

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
    ["Spikey Egg"] = Vector3.new(-128, 10, 9),
    ["Magma Egg"] = Vector3.new(-137, 11, 3),
    ["Crystal Egg"] = Vector3.new(-144, 10, -5),
    ["Lunar Egg"] = Vector3.new(-148, 11, -15),
    ["Void Egg"] = Vector3.new(-150, 11, -26),
    ["Hell Egg"] = Vector3.new(-149, 11, -37),
    ["Secret Egg"] = Vector3.new(-19438, 8, 18839),
    ["Showman Egg"] = Vector3.new(-130, 10, -60),
    ["Popcorn Egg"] = Vector3.new(-3601, 162, 882),
    ["Sweet Egg"] = Vector3.new(-3586, 162, 883),
    ["Exotic Egg"] = Vector3.new(-3576, 162, 882),
}

local originalRadius = constants.DefaultPickupRadius
local PEARL_CRATES = {"Wooden Crate", "Steel Crate", "Golden Crate", "Classic Crate", "Galaxy Crate"}

-- ======================================
-- SETTINGS
-- ======================================
local seasonRunning = false
local seasonThread = nil
local globalRunning = false
local globalThread = nil
local claimRunning = false
local claimThread = nil
local HATCH_AMOUNT = questSettings.hatchAmount or 12
local COIN_CAP = 5000000000000
local skippedQuests = {}

-- ======================================
-- FUNCTIONS
-- ======================================
local function getRoot()
    local char = player.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
end

local function teleportTo(pos)
    local root = getRoot()
    if root then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

local function savePosition()
    local root = getRoot()
    return root and root.Position or nil
end

local function restorePosition(pos)
    if pos then
        local root = getRoot()
        if root then
            root.CFrame = CFrame.new(pos)
        end
    end
end

local function getSellPosition()
    local overworld = workspace.Worlds["The Overworld"]
    if overworld then
        local sell = overworld:FindFirstChild("Sell")
        if sell then
            local ring = sell:FindFirstChild("Ring")
            if ring then
                return ring.Position
            end
        end
    end
    return Vector3.new(77, 6, -113)
end

local function getActiveQuests(filter)
    local data = LocalData:Get()
    local quests = {}
    if data and data.Quests then
        for _, quest in pairs(data.Quests) do
            if not quest.Claimed then
                local name = quest.Id or ""
                if name:find(filter) and not name:find("bubble") then
                    local task = quest.Tasks and quest.Tasks[1]
                    if task then
                        table.insert(quests, {
                            id = quest.Id,
                            type = task.Type,
                            amount = task.Amount or 0,
                            rarity = task.Rarity,
                            egg = task.Egg,
                            currency = task.Currency or (task.Item and task.Item.Currency),
                        })
                    end
                end
            end
        end
    end
    return quests
end

local function getAvailableCrate()
    local data = LocalData:Get()
    if data and data.Powerups then
        for _, crateName in ipairs(PEARL_CRATES) do
            local amount = data.Powerups[crateName] or 0
            if amount > 0 then
                return crateName, amount
            end
        end
    end
    return nil, 0
end

local function completeQuest(quest)
    getgenv().questActive = true
    
    if quest.type == "Bubbles" then
        getgenv().questEgg = nil
        local prevPos = savePosition()
        local sellPos = getSellPosition()
        local root = getRoot()
        if root then root.CFrame = CFrame.new(sellPos) end
        task.wait(0.5)
        while true do
            pcall(function() Remote:FireServer("BlowBubble") end)
            task.wait(0.01)
            local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
            local stillActive = false
            for _, q in ipairs(newQuests) do
                if q.id == quest.id then stillActive = true; break end
            end
            if not stillActive then break end
        end
        restorePosition(prevPos)
        
    elseif quest.type == "Hatch" then
        if quest.egg then
            local eggName = quest.egg
            getgenv().questEgg = eggName
            local prevPos = savePosition()
            local pos = EGG_LOCATIONS[eggName] or EGG_LOCATIONS["Magma Egg"]
            if pos then teleportTo(pos) end
            task.wait(0.5)
            while true do
                pcall(function() Remote:InvokeServer("HatchEgg", eggName, HATCH_AMOUNT) end)
                task.wait(1)
                local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
                local stillActive = false
                for _, q in ipairs(newQuests) do
                    if q.id == quest.id then stillActive = true; break end
                end
                if not stillActive then break end
            end
            restorePosition(prevPos)
        elseif quest.rarity then
            getgenv().questEgg = "Nightmare Egg"
            local prevPos = savePosition()
            local pos = EGG_LOCATIONS["Nightmare Egg"]
            if pos then teleportTo(pos) end
            task.wait(0.5)
            while true do
                pcall(function() Remote:InvokeServer("HatchEgg", "Nightmare Egg", HATCH_AMOUNT) end)
                task.wait(1)
                local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
                local stillActive = false
                for _, q in ipairs(newQuests) do
                    if q.id == quest.id then stillActive = true; break end
                end
                if not stillActive then break end
            end
            restorePosition(prevPos)
        else
            getgenv().questActive = false
            getgenv().questEgg = nil
            task.wait(5)
        end
        
    elseif quest.type == "Collect" then
        local curr = quest.currency or ""
        
        if curr:lower():find("pearl") then
            local crateName, crateAmount = getAvailableCrate()
            
            if crateName and crateAmount > 0 then
                getgenv().questEgg = nil
                local prevPos = savePosition()
                teleportTo(SEVENSEAS_SPAWN)
                task.wait(0.5)
                
                local VIM = game:GetService("VirtualInputManager")
                
                while true do
                    crateName, crateAmount = getAvailableCrate()
                    if not crateName then break end
                    
                    local openAmount = math.min(crateAmount, 10)
                    pcall(function() RE:FireServer("UseGift", crateName, openAmount) end)
                    
                    for i = 1, openAmount do
                        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                        task.wait(0.02)
                    end
                    
                    task.wait(0.5)
                    
                    local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
                    local stillActive = false
                    for _, q in ipairs(newQuests) do
                        if q.id == quest.id then stillActive = true; break end
                    end
                    if not stillActive then break end
                end
                
                restorePosition(prevPos)
            else
                skippedQuests[quest.id] = true
                getgenv().questActive = false
                getgenv().questEgg = nil
                task.wait(1)
                return
            end
            
        elseif curr:lower():find("gem") then
            getgenv().questEgg = nil
            local prevPos = savePosition()
            
            constants.DefaultPickupRadius = math.huge
            
            local orbThread = task.spawn(function()
                while getgenv().questActive do
                    pcall(function() Remote:FireServer("UseGoldenOrb") end)
                    task.wait(1)
                end
            end)
            
            local shopThread = task.spawn(function()
                while getgenv().questActive do
                    local shops = {"shadow-shop", "alien-shop", "shard-shop", "dice-shop"}
                    for _, shop in ipairs(shops) do
                        for item = 1, 3 do
                            pcall(function() RE:FireServer("BuyShopItem", shop, item, true) end)
                        end
                    end
                    task.wait(0.8)
                end
            end)
            
            teleportTo(GEM_AREA)
            
            while true do
                task.wait(3)
                local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
                local stillActive = false
                for _, q in ipairs(newQuests) do
                    if q.id == quest.id then stillActive = true; break end
                end
                if not stillActive then break end
            end
            
            task.cancel(orbThread)
            task.cancel(shopThread)
            constants.DefaultPickupRadius = originalRadius
            restorePosition(prevPos)
            
        elseif curr:lower():find("ticket") then
            getgenv().questEgg = nil
            local prevPos = savePosition()
            constants.DefaultPickupRadius = math.huge
            
            local orbThread = task.spawn(function()
                while getgenv().questActive do
                    pcall(function() Remote:FireServer("UseGoldenOrb") end)
                    task.wait(1)
                end
            end)
            
            teleportTo(TICKET_AREA)
            
            while true do
                task.wait(3)
                local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
                local stillActive = false
                for _, q in ipairs(newQuests) do
                    if q.id == quest.id then stillActive = true; break end
                end
                if not stillActive then break end
            end
            
            task.cancel(orbThread)
            constants.DefaultPickupRadius = originalRadius
            restorePosition(prevPos)
            
        else
            getgenv().questEgg = nil
            local prevPos = savePosition()
            
            constants.DefaultPickupRadius = math.huge
            
            local orbThread = task.spawn(function()
                while getgenv().questActive do
                    pcall(function() Remote:FireServer("UseGoldenOrb") end)
                    task.wait(1)
                end
            end)
            
            teleportTo(COIN_AREA)
            
            while true do
                local data = LocalData:Get()
                local coins = data and data.Coins or 0
                if coins >= COIN_CAP then
                    local rainbowPos = EGG_LOCATIONS["Rainbow Egg"]
                    if rainbowPos then teleportTo(rainbowPos) end
                    task.wait(0.5)
                    for i = 1, 3 do
                        pcall(function() Remote:FireServer("HatchEgg", "Rainbow Egg", 12) end)
                        task.wait(1)
                    end
                    teleportTo(COIN_AREA)
                    task.wait(0.5)
                end
                task.wait(3)
                local newQuests = getActiveQuests(quest.id:match("^(.-)%d+$") or "")
                local stillActive = false
                for _, q in ipairs(newQuests) do
                    if q.id == quest.id then stillActive = true; break end
                end
                if not stillActive then break end
            end
            
            task.cancel(orbThread)
            constants.DefaultPickupRadius = originalRadius
            restorePosition(prevPos)
        end
    end
    
    getgenv().questActive = false
    getgenv().questEgg = nil
end

local function questLoop(filter)
    return function()
        while true do
            local quests = getActiveQuests(filter)
            if #quests == 0 then
                skippedQuests = {}
                getgenv().questActive = false
                getgenv().questEgg = nil
                task.wait(10)
                continue
            end
            
            local questToDo = nil
            for _, q in ipairs(quests) do
                local curr = q.currency or ""
                if q.type == "Hatch" and not q.egg and not q.rarity then
                elseif q.type == "Collect" and curr:lower():find("pearl") then
                    if not skippedQuests[q.id] then
                        questToDo = q
                        break
                    end
                else
                    questToDo = q
                    break
                end
            end
            
            if questToDo then
                getgenv().ActivityStatus.current = "Doing Season Pass now..."
                getgenv().ActivityStatus.trigger = true
                completeQuest(questToDo)
                getgenv().ActivityStatus.current = "Season Pass done!"
                getgenv().ActivityStatus.trigger = true
            else
                getgenv().questActive = false
                getgenv().questEgg = nil
                task.wait(30)
            end
        end
    end
end

-- ======================================
-- SEASON CLAIM FUNCTIONS
-- ======================================
local function getPetTrueRarity(petName)
    local info = Pets[petName]
    if not info then return nil end
    if info.Void then return "Void"
    elseif info.Infinity then return "Infinity"
    elseif info.Celestial then return "Celestial"
    end
    return nil
end

local function checkSeasonPremiumPet()
    local data = LocalData:Get()
    if not data or not data.Season then return nil end
    
    if data.Season.Premium then
        return nil
    end
    
    local currentLevel = data.Season.Level
    
    if data.Season.InfinityTiers then
        for _, tier in ipairs(data.Season.InfinityTiers) do
            if tier.Tier == currentLevel and tier.Premium and tier.Premium.Type == "Pet" then
                local rarity = getPetTrueRarity(tier.Premium.Name)
                if rarity then
                    return {
                        name = tier.Premium.Name,
                        rarity = rarity,
                        xl = tier.Premium.XL,
                        tier = tier.Tier,
                    }
                end
            end
        end
    end
    
    return nil
end

local function sendSeasonPremiumWebhook(premiumPet)
    local webhookURL = settings.activity and settings.activity.webhookURL or ""
    local discordID = settings.activity and settings.activity.userId or ""
    
    if webhookURL == "" then return end
    if not request then return end
    
    local rarityText = premiumPet.rarity
    if premiumPet.xl then rarityText = rarityText .. " XL" end
    
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
                content = pingMsg .. "🚨 STOP! Premium Season Pet Found!",
                embeds = {{
                    title = "🚨 PREMIUM SEASON PET FOUND!",
                    description = "**Auto Claim has STOPPED!**\n\n" ..
                                  "**Pet:** " .. premiumPet.name .. "\n" ..
                                  "**Rarity:** " .. rarityText .. "\n" ..
                                  "**Tier:** " .. premiumPet.tier .. "\n\n" ..
                                  "⚠️ Buy the Premium Pass before claiming to get this pet!",
                    color = 0xFF0000,
                    footer = {text = "Renoa Hub * " .. os.date("%Y-%m-%d %H:%M:%S")}
                }}
            })
        })
    end)
end

-- ======================================
-- UI - SEASON PASS
-- ======================================
QuestTab:Section({ Title = "Season Pass" })

QuestTab:Input({
    Title = "Hatch Amount",
    Value = tostring(HATCH_AMOUNT),
    Placeholder = "12",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            HATCH_AMOUNT = n
            questSettings.hatchAmount = n
            getgenv().HubSettings.quest = questSettings
            saveHubSettings()
        end
    end,
})

QuestTab:Toggle({
    Title = "Auto Season Quests",
    Desc = "Completes season quests automatically",
    Value = questSettings.autoSeason or false,
    Callback = function(v)
        seasonRunning = v
        questSettings.autoSeason = v
        getgenv().HubSettings.quest = questSettings
        saveHubSettings()
        if v then
            seasonThread = task.spawn(questLoop("challenge"))
        else
            if seasonThread then task.cancel(seasonThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
            constants.DefaultPickupRadius = originalRadius
        end
    end,
})

QuestTab:Paragraph({
    Title = "Auto Claim Season Pass Info",
    Desc = "Will STOP if there's a Celestial/Infinity/Void pet on Premium side! (Only works if you DON'T have Premium Pass)",
})

local seasonStatusParagraph = QuestTab:Paragraph({
    Title = "Season Auto Claim",
    Desc = "OFF",
})

QuestTab:Toggle({
    Title = "Auto Claim Season Pass",
    Desc = "Claims season rewards automatically",
    Value = claimRunning,
    Callback = function(v)
        claimRunning = v
        if v then
            pcall(function()
                seasonStatusParagraph:SetDesc("ON")
            end)
            
            claimThread = task.spawn(function()
                while claimRunning do
                    local playerGui = player:FindFirstChild("PlayerGui")
                    local screenGui = playerGui and playerGui:FindFirstChild("ScreenGui")
                    local seasonUI = screenGui and screenGui:FindFirstChild("Season")
                    if seasonUI and seasonUI.Visible then
                        seasonUI.Visible = false
                        task.wait(1.5)
                    end
                    
                    local premiumPet = checkSeasonPremiumPet()
                    
                    if premiumPet then
                        claimRunning = false
                        
                        local rarityText = premiumPet.rarity
                        if premiumPet.xl then rarityText = rarityText .. " XL" end
                        
                        getgenv().ActivityStatus.current = "🚨 Season Premium Pet: " .. premiumPet.name .. " [" .. rarityText .. "]!"
                        getgenv().ActivityStatus.trigger = true
                        
                        pcall(function()
                            seasonStatusParagraph:SetTitle("🚨 STOPPED")
                            seasonStatusParagraph:SetDesc(premiumPet.name .. " [" .. rarityText .. "] at Tier " .. premiumPet.tier)
                        end)
                        
                        sendSeasonPremiumWebhook(premiumPet)
                        break
                    end
                    
                    pcall(function() RE:FireServer("ClaimSeason") end)
                    task.wait(5)
                end
            end)
        else
            if claimThread then task.cancel(claimThread) end
            pcall(function()
                seasonStatusParagraph:SetTitle("Season Auto Claim")
                seasonStatusParagraph:SetDesc("OFF")
            end)
        end
    end,
})

-- ======================================
-- UI - GLOBAL INCENTIVE
-- ======================================
QuestTab:Section({ Title = "Global Incentive" })

QuestTab:Toggle({
    Title = "Auto Global Incentive",
    Desc = "Completes global incentive quests automatically",
    Value = questSettings.autoGlobal or false,
    Callback = function(v)
        globalRunning = v
        questSettings.autoGlobal = v
        getgenv().HubSettings.quest = questSettings
        saveHubSettings()
        if v then
            globalThread = task.spawn(function()
                while globalRunning do
                    local quests = getActiveQuests("global")
                    if #quests == 0 then
                        pcall(function() Remote:FireServer("ClaimGlobalIncentiveQuest") end)
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                        task.wait(60)
                    else
                        local questToDo = nil
                        for _, q in ipairs(quests) do
                            local curr = q.currency or ""
                            if q.type == "Collect" and curr:lower():find("pearl") then
                                if not skippedQuests[q.id] then
                                    questToDo = q
                                    break
                                end
                            elseif q.type == "Hatch" and not q.egg and not q.rarity then
                            else
                                questToDo = q
                                break
                            end
                        end
                        if questToDo then
                            getgenv().ActivityStatus.current = "Doing Global Incentive..."
                            getgenv().ActivityStatus.trigger = true
                            completeQuest(questToDo)
                            getgenv().ActivityStatus.current = "Global Incentive done!"
                            getgenv().ActivityStatus.trigger = true
                        else
                            getgenv().questActive = false
                            getgenv().questEgg = nil
                            task.wait(30)
                        end
                    end
                end
            end)
        else
            if globalThread then task.cancel(globalThread) end
            getgenv().questActive = false
            getgenv().questEgg = nil
            constants.DefaultPickupRadius = originalRadius
        end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1.5)
    
    -- Auto Season Quests
    if questSettings.autoSeason then
        seasonRunning = true
        seasonThread = task.spawn(questLoop("challenge"))
    end
    
    -- Auto Global Incentive
    if questSettings.autoGlobal then
        globalRunning = true
        globalThread = task.spawn(function()
            while globalRunning do
                local quests = getActiveQuests("global")
                if #quests == 0 then
                    pcall(function() Remote:FireServer("ClaimGlobalIncentiveQuest") end)
                    getgenv().questActive = false
                    getgenv().questEgg = nil
                    task.wait(60)
                else
                    local questToDo = nil
                    for _, q in ipairs(quests) do
                        local curr = q.currency or ""
                        if q.type == "Collect" and curr:lower():find("pearl") then
                            if not skippedQuests[q.id] then
                                questToDo = q
                                break
                            end
                        elseif q.type == "Hatch" and not q.egg and not q.rarity then
                        else
                            questToDo = q
                            break
                        end
                    end
                    if questToDo then
                        getgenv().ActivityStatus.current = "Doing Global Incentive..."
                        getgenv().ActivityStatus.trigger = true
                        completeQuest(questToDo)
                        getgenv().ActivityStatus.current = "Global Incentive done!"
                        getgenv().ActivityStatus.trigger = true
                    else
                        getgenv().questActive = false
                        getgenv().questEgg = nil
                        task.wait(30)
                    end
                end
            end
        end)
    end
    
    -- NOTE: Auto Claim Season Pass is NOT persisted (no settings save),
    -- so it never auto-starts. User must toggle it manually each session.
    
    print("[Quest] Auto-started saved toggles!")
end)

print("[Quest] Loaded!")
