-- ================================================
-- WEBHOOK TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local WebhookTab = Window:Tab({ Title = "Webhook", Icon = "webhook" })

-- ======================================
-- SERVICES
-- ======================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.webhook then settings.webhook = {} end

-- ======================================
-- WEBHOOK SETTINGS
-- ======================================
local HATCH_WEBHOOK_URL = settings.webhook.hatchURL or ""
local ONLINE_WEBHOOK_URL = settings.webhook.onlineURL or ""
local DISCORD_USER_ID = settings.webhook.userId or ""
local PUBLIC_WEBHOOK_URL = "https://discord.com/api/webhooks/1522161241064345691/6plklhELLd8n_zYdwTjTqwTSRdklmffPHXseqPdI-UD25jDUpD2NZRy4FKmvYByfY5fA"

local request = http_request or request or (syn and syn.request)
if not request then
    WebhookTab:Section({ Title = "Error" })
    WebhookTab:Paragraph({
        Title = "Error",
        Desc = "Your executor doesn't support webhooks!",
    })
    return
end

-- ======================================
-- SETTINGS
-- ======================================
local hideUsername = settings.webhook.hideUsername or false
local rareEggNotify = settings.webhook.rareEggNotify
if rareEggNotify == nil then rareEggNotify = true end
local autoRejoinEnabled = settings.webhook.autoRejoin or false

local oddsThresholdInput = settings.webhook.oddsThreshold or ""

-- ======================================
-- TRUE RARITY DETECTION
-- ======================================
local function getTrueRarity(info)
    if not info then return "Unknown" end
    
    if info.Void then
        return "Void"
    elseif info.Infinity then
        return "Infinity"
    elseif info.Celestial then
        return "Celestial"
    elseif info.Rarity then
        return info.Rarity
    end
    
    return "Unknown"
end

local function isTrackedRarity(info)
    local rarity = getTrueRarity(info)
    if not rarity then return false end
    
    if rarity == "Void" or rarity == "Infinity" or rarity == "Celestial" then
        return true
    end
    
    if rarity:find("Secret") then return true end
    if rarity:find("Super Legendary") then return true end
    
    return false
end

-- ======================================
-- ORIGIN DETECTOR
-- ======================================
local function getPetOrigin(info)
    if not info then return "Unknown" end
    
    local egg = info.Egg or ""
    local tag = info.Tag or ""
    
    if tag:find("Rebirth Machine") then
        return "Rebirth Machine"
    elseif tag:find("Secret Bounty") then
        return "Bounty"
    elseif tag:find("Leaderboard") then
        return "Leaderboard"
    elseif tag:find("Season") or tag:find("Mega Shop") then
        return "Season Pass"
    elseif tag:find("Competitive") or tag:find("Comp") then
        return "Competitive"
    elseif tag:find("Global") or tag:find("Incentive") then
        return "Global Incentive"
    elseif tag:find("Admin") or info.AdminAbuse then
        return "Admin Abuse Egg"
    end
    
    if egg and egg ~= "" and egg ~= "Unknown" then
        return egg
    end
    
    return "Unknown"
end

local function isOriginBypass(origin, rarity)
    if origin == "Rebirth Machine" and (rarity == "Celestial" or rarity == "Infinity") then
        return true
    end
    
    if origin == "Bounty" then
        return true
    end
    
    if origin == "Season Pass" and (rarity == "Celestial" or rarity == "Infinity" or rarity == "Void") then
        return true
    end
    
    if origin == "Competitive" then
        return true
    end
    
    if origin == "Leaderboard" then
        return true
    end
    
    return false
end

local function shouldSkipPet(origin, rarity)
    if origin == "Season Pass" and rarity == "Secret" then
        return true
    end
    return false
end

-- ======================================
-- ODDS THRESHOLD PARSER
-- ======================================
local function parseOddsInput(input)
    if not input or input == "" then return nil end
    
    local text = string.lower(string.gsub(input, "%s+", ""))
    local num, suffix = text:match("^(%d+%.?%d*)([bmtk]?)$")
    
    if not num then return nil end
    
    num = tonumber(num)
    
    if suffix == "t" then
        return num * 1e12
    elseif suffix == "b" then
        return num * 1e9
    elseif suffix == "m" then
        return num * 1e6
    elseif suffix == "k" then
        return num * 1e3
    else
        return num
    end
end

local function getOneInX(chance)
    if not chance then return math.huge end
    local chanceNum = tonumber(chance) or 0
    if chanceNum > 0 then
        return 100 / chanceNum
    end
    return math.huge
end

local function getThreshold()
    return parseOddsInput(oddsThresholdInput)
end

-- ======================================
-- ENCHANT DISPLAY NAMES
-- ======================================
local ENCHANT_NAMES = {
    ["super-burst"] = "Burst Blessing",
    ["super-shiny"] = "Shiny Blessing",
    ["super-luck"] = "Luck Boost",
    ["super-hatch"] = "Hatch Blessing",
    ["super-bubble"] = "Bubble Machine",
    ["super-infinity"] = "Infinity Blessing",
    ["super-duplication"] = "Duplication",
}

-- ======================================
-- COLOR SCHEME
-- ======================================
local function getColorForPet(rarity, variant, isXL, origin)
    if isXL then
        if variant == "Normal" then return 0x808000 end
        if variant == "Shiny" then return 0x87CEEB end
        if variant == "Mythic" then return 0x8B008B end
        if variant == "ShinyMythic" then return 0x006400 end
    end
    
    if origin == "Bounty" and rarity == "Secret" then
        if variant == "Normal" then return 0xDC143C end
        if variant == "Shiny" then return 0xFFBF00 end
        if variant == "Mythic" then return 0xFF69B4 end
        if variant == "ShinyMythic" then return 0x50C878 end
    end
    
    if rarity == "Secret" then
        return 0x808080
    end
    
    if rarity == "Celestial" then
        if variant == "Normal" then return 0x00BFFF end
        if variant == "Shiny" then return 0xFFFF00 end
        if variant == "Mythic" then return 0xFF00FF end
        if variant == "ShinyMythic" then return 0x00FF00 end
    end
    
    if rarity == "Infinity" then
        if variant == "Normal" then return 0x000080 end
        if variant == "Shiny" then return 0xFFFF00 end
        if variant == "Mythic" then return 0xFF00FF end
        if variant == "ShinyMythic" then return 0x00FF00 end
    end
    
    if rarity == "Void" then
        if variant == "Normal" then return 0x8A2BE2 end
        if variant == "Shiny" then return 0xFFFF00 end
        if variant == "Mythic" then return 0xFF00FF end
        if variant == "ShinyMythic" then return 0x00FF00 end
    end
    
    if rarity == "Super Legendary" then
        if variant == "Normal" then return 0x1E90FF end
        if variant == "Shiny" then return 0xFFFF00 end
        if variant == "Mythic" then return 0xFF00FF end
        if variant == "ShinyMythic" then return 0x00FF00 end
    end
    
    return 16777215
end

-- ======================================
-- DATA
-- ======================================
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)

-- ======================================
-- FORMAT
-- ======================================
local function formatNum(n)
    if not n then return "0" end
    if n>=1e9 then return string.format("%.1fB",n/1e9)
    elseif n>=1e6 then return string.format("%.1fM",n/1e6)
    elseif n>=1e3 then return string.format("%.1fK",n/1e3)
    else return tostring(n) end
end

local function formatExist(n)
    if not n then return "0" end
    local s = tostring(math.floor(n))
    return s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end

local function getPetChance(petInfo)
    if petInfo.Chance then
        local chance = tonumber(petInfo.Chance) or 0
        if chance >= 1 then return chance .. "%"
        elseif chance > 0 then
            local oneIn = 100 / chance
            if oneIn >= 1e9 then return "1/" .. string.format("%.0f", oneIn / 1e9) .. "B"
            elseif oneIn >= 1e6 then return "1/" .. string.format("%.1f", oneIn / 1e6) .. "M"
            elseif oneIn >= 1e3 then return "1/" .. string.format("%.1f", oneIn / 1e3) .. "K"
            else return "1/" .. string.format("%.0f", oneIn) end
        end
    end
    return "Unknown"
end

local function getExists(petName, variant)
    local name = petName
    if variant and variant ~= "Normal" then name = variant .. " " .. petName end
    local ok, result = pcall(function() return Remote:InvokeServer("GetExisting", name) end)
    if ok and result then
        local num = tonumber(result) or 0
        if num > 0 then return formatExist(num) end
    end
    return "N/A"
end

local function getVariantText(v)
    if v=="ShinyMythic" then return "Shiny Mythic"
    elseif v=="Shiny" then return "Shiny"
    elseif v=="Mythic" then return "Mythic"
    else return "Normal" end
end

local function getImage(petName, ex)
    local n = petName:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
    local prefix = ""
    if ex.Shiny and ex.Mythic then prefix = "shiny-mythic-"
    elseif ex.Shiny then prefix = "shiny-"
    elseif ex.Mythic then prefix = "mythic-" end
    return "https://cdn.bgsi.gg/items/" .. prefix .. n .. ".png"
end

-- ======================================
-- BUFF TIMER
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
                            if label and label.Text ~= "" then
                                local text = label.Text
                                if buffName == "Lucky" then
                                    if text:find("^%d+:%d+$") then
                                    else
                                        return text
                                    end
                                else
                                    return text
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return "N/A"
end

local function getBuffTimesForEmbed()
    local buffs = {
        {"Secret Elixir", "Secret Elixir"},
        {"Ultra Infinity Elixir", "Ultra Infinity Elixir"},
        {"Infinity Elixir", "Infinity Elixir"},
        {"Lucky Potion", "Lucky"},
        {"Speed Potion", "Speed"},
        {"Mythic Potion", "Mythic"},
    }
    local lines = {}
    for _, buff in ipairs(buffs) do
        local time = getBuffTime(buff[2])
        if time and time ~= "N/A" and time ~= "0s" then
            table.insert(lines, buff[1] .. ": " .. time)
        end
    end
    if #lines == 0 then return "No active buffs" end
    return table.concat(lines, "\n")
end

-- ======================================
-- DEBUG STATS
-- ======================================
local function getDebugStats()
    local stats = {
        TotalLuck = "N/A",
        InfinityLuck = "N/A",
        SecretLuck = "N/A",
        HatchSpeed = "N/A",
    }
    Remote:FireServer("SetSetting", "Debug", true)
    task.wait(0.5)
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("TextLabel") then
                local text = obj.Text
                text = text:gsub("<[^>]+>", "")
                if stats.TotalLuck == "N/A" and text:find("🍀 Lucky") then stats.TotalLuck = text end
                if stats.InfinityLuck == "N/A" and text:find("♾️ Ultra Infinity Luck") then stats.InfinityLuck = text end
                if stats.SecretLuck == "N/A" and text:find("❓ Secret/Infinity Luck") then stats.SecretLuck = text end
                if stats.HatchSpeed == "N/A" and text:find("⚡ Hatch Speed") then stats.HatchSpeed = text end
            end
        end
    end
    return stats
end

-- ======================================
-- WEBHOOK SYSTEM
-- ======================================
local hatchQueue={}
local onlineQueue={}
local publicQueue={}
local hatchProcessing=false
local onlineProcessing=false
local publicProcessing=false

local function sendToWebhook(queue, url)
    if url == "" then return end
    while #queue > 0 do
        local p = table.remove(queue, 1)
        pcall(function()
            request({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(p)
            })
        end)
        task.wait(1)
    end
end

local function processHatch() if not hatchProcessing then hatchProcessing = true task.spawn(function() sendToWebhook(hatchQueue, HATCH_WEBHOOK_URL) hatchProcessing = false end) end end
local function processPublic() if not publicProcessing then publicProcessing = true task.spawn(function() sendToWebhook(publicQueue, PUBLIC_WEBHOOK_URL) publicProcessing = false end) end end
local function processOnline() if not onlineProcessing then onlineProcessing = true task.spawn(function() sendToWebhook(onlineQueue, ONLINE_WEBHOOK_URL) onlineProcessing = false end) end end

-- ======================================
-- STUCK DETECTION + REJOIN
-- ======================================
local lastHatchesForStuck = 0
local zeroHatchCount = 0
local stuckNotified = false
local isRejoining = false
local ZERO_WINDOW_THRESHOLD = 3

local leaderstats = player:FindFirstChild("leaderstats")
if leaderstats then
    for _, stat in ipairs(leaderstats:GetChildren()) do
        if stat.Name:find("Hatches") then lastHatchesForStuck = tonumber(stat.Value) or 0 end
    end
end

task.spawn(function()
    while true do
        task.wait(120)
        if ONLINE_WEBHOOK_URL == "" then continue end
        if isRejoining then continue end
        if not autoRejoinEnabled then continue end
        
        local currentHatches = 0
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if stat.Name:find("Hatches") then currentHatches = tonumber(stat.Value) or 0 end
            end
        end
        
        local hatchesInWindow = currentHatches - lastHatchesForStuck
        lastHatchesForStuck = currentHatches
        
        if hatchesInWindow == 0 then
            zeroHatchCount = zeroHatchCount + 1
            
            if zeroHatchCount >= ZERO_WINDOW_THRESHOLD and not stuckNotified then
                stuckNotified = true
                isRejoining = true
                
                local pingMsg = ""
                if DISCORD_USER_ID ~= "" then
                    pingMsg = "<@" .. DISCORD_USER_ID .. "> Trying to rejoin, Please Still keep an eye on your roblox!"
                else
                    pingMsg = "Trying to rejoin, Please Still keep an eye on your roblox!"
                end
                
                table.insert(onlineQueue, {
                    content = pingMsg,
                    embeds = {{
                        title = "⚠️ STUCK DETECTED - REJOINING!",
                        description = "**" .. player.Name .. "** has no hatches for " .. (zeroHatchCount * 2) .. " minutes! Rejoining...",
                        color = 0xFF0000,
                        footer = {text = "Renoa Hub * " .. os.date("%Y-%m-%d %H:%M:%S")}
                    }}
                })
                processOnline()
                
                task.spawn(function()
                    task.wait(5)
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, player)
                    end)
                end)
            end
        else
            zeroHatchCount = 0
            stuckNotified = false
            isRejoining = false
        end
    end
end)

-- ======================================
-- REGULAR ONLINE PING
-- ======================================
local startTime = os.time()
local lastPingTime = os.time()
local lastHatchesForPing = 0
local regularStuckNotified = false

local leaderstats2 = player:FindFirstChild("leaderstats")
if leaderstats2 then
    for _, stat in ipairs(leaderstats2:GetChildren()) do
        if stat.Name:find("Hatches") then lastHatchesForPing = tonumber(stat.Value) or 0 end
    end
end

task.spawn(function()
    while true do
        task.wait(1800)
        if ONLINE_WEBHOOK_URL == "" then continue end
        if isRejoining then continue end
        
        local elapsed = os.time() - startTime
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local data = LocalData:Get()
        local coins = data and formatNum(data.Coins or 0) or "0"
        local gems = data and formatNum(data.Gems or 0) or "0"
        local leaderstats = player:FindFirstChild("leaderstats")
        local bubbles = "0"
        local currentHatches = 0
        if leaderstats then
            for _, stat in ipairs(leaderstats:GetChildren()) do
                if stat.Name:find("Bubble") then bubbles = formatNum(stat.Value) end
                if stat.Name:find("Hatches") then currentHatches = tonumber(stat.Value) or 0 end
            end
        end
        
        local timeSinceLastPing = (os.time() - lastPingTime) / 60
        local hatchesSinceLastPing = currentHatches - lastHatchesForPing
        local perMin = timeSinceLastPing > 0 and math.floor(hatchesSinceLastPing / timeSinceLastPing) or 0
        local perHour = perMin * 60
        lastHatchesForPing = currentHatches
        lastPingTime = os.time()
        
        local debugStats = getDebugStats()
        
        local fragData = data and data.Fragments
        local fragmentText = "N/A"
        if fragData then
            fragmentText = 
                "Green: " .. (fragData.Green or 0) .. "/250\n" ..
                "Blue: " .. (fragData.Blue or 0) .. "/250\n" ..
                "Purple: " .. (fragData.Purple or 0) .. "/250\n" ..
                "Rainbow: " .. (fragData.Rainbow or 0) .. "/250"
        end

        local isStuck = false
        if autoRejoinEnabled then
            isStuck = (perMin == 0 and perHour == 0)
        end
        
        local pingMsg = ""
        local embedColor = 3447003
        
        if isStuck and not regularStuckNotified then
            if DISCORD_USER_ID ~= "" then
                pingMsg = "<@" .. DISCORD_USER_ID .. "> Please check your roblox!"
            else
                pingMsg = "⚠️ Please check your roblox!"
            end
            embedColor = 0xFF0000
            regularStuckNotified = true
        elseif not isStuck then
            regularStuckNotified = false
        end

        table.insert(onlineQueue, {
            content = pingMsg,
            embeds = {{
                title = isStuck and "⚠️ STUCK DETECTED!" or "Still Online!",
                description =
                    "**" .. player.Name .. "** is " .. (isStuck and "STUCK!" or "still online!") .. "\n\n" ..
                    "Online: " .. hours .. "h " .. minutes .. "m\n" ..
                    "Coins: " .. coins .. "\nGems: " .. gems .. "\nBubbles: " .. bubbles .. "\n\n" ..
                    "**Hatch Rate**\nPer Minute: " .. perMin .. "\nPer Hour: " .. perHour .. "\n\n" ..
                    "**Fragments**\n" .. fragmentText .. "\n\n" ..
                    "**Stats**\n" .. debugStats.TotalLuck .. "\n" .. debugStats.InfinityLuck .. "\n" .. debugStats.SecretLuck .. "\n" .. debugStats.HatchSpeed,
                color = embedColor,
                footer = {text = "Renoa Hub * " .. os.date("%Y-%m-%d %H:%M:%S")}
            }}
        })
        processOnline()
    end
end)

-- ======================================
-- FULL INVENTORY SCANNER
-- ======================================
local knownPets = {}

local initData = LocalData:Get()
if initData and initData.Pets then
    for _, pet in pairs(initData.Pets) do
        if pet.Super then knownPets[pet.Id] = true
        else
            local info = Pets[pet.Name]
            if info and isTrackedRarity(info) then
                knownPets[pet.Id] = true
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(5)
        local data = LocalData:Get()
        if data and data.Pets then
            for _, pet in pairs(data.Pets) do
                if not knownPets[pet.Id] then
                    local isSuper = pet.Super
                    local info = Pets[pet.Name]
                    local isXL = pet.XL
                    
                    if isSuper and not info then
                        local baseName = pet.Name:gsub("^Shiny ", ""):gsub("^Mythic ", ""):gsub("^Shiny Mythic ", ""):gsub("^XL ", "")
                        info = Pets[baseName]
                    end
                    
                    local shouldTrack = false
                    if isSuper then shouldTrack = true
                    elseif info and isTrackedRarity(info) then
                        shouldTrack = true
                    end
                    
                    if shouldTrack then
                        local rarity = isSuper and "Super Legendary" or getTrueRarity(info)
                        knownPets[pet.Id] = true
                        
                        local origin = getPetOrigin(info)
                        
                        if shouldSkipPet(origin, rarity) then
                            continue
                        end
                        
                        local threshold = getThreshold()
                        local shouldSendPrivate = true
                        
                        if threshold and not isSuper and not isXL then
                            if not isOriginBypass(origin, rarity) then
                                local oneInX = getOneInX(info and info.Chance)
                                if oneInX <= threshold then
                                    shouldSendPrivate = false
                                end
                            end
                        end
                        
                        local debugStats = getDebugStats()
                        local statsStr = debugStats.TotalLuck .. "\n" .. debugStats.InfinityLuck .. "\n" .. debugStats.SecretLuck .. "\n" .. debugStats.HatchSpeed
                        local buffStr = getBuffTimesForEmbed()
                        
                        if isSuper then
                            local enchantNames = {}
                            if pet.Enchants then
                                for _, enchant in pairs(pet.Enchants) do
                                    if enchant.Id then table.insert(enchantNames, enchant.Id) end
                                end
                            end
                            local displayEnchants = {}
                            for _, id in ipairs(enchantNames) do table.insert(displayEnchants, ENCHANT_NAMES[id] or id) end
                            local displayStr = #displayEnchants > 0 and table.concat(displayEnchants, ", ") or "None"
                            local variant = "Normal"
                            if pet.Shiny and pet.Mythic then variant = "Shiny Mythic"
                            elseif pet.Shiny then variant = "Shiny"
                            elseif pet.Mythic then variant = "Mythic" end
                            local displayName = hideUsername and "Hidden" or player.Name
                            local coins = formatNum(data.Coins or 0)
                            local gems = formatNum(data.Gems or 0)
                            
                            if shouldSendPrivate then
                                local embed = {
                                    title = "Congrats You Hatched A "..variant.." Super Legendary "..pet.Name.."!",
                                    color = 0x1E90FF,
                                    fields = {
                                        {name = "* User Info", value = "Name : "..displayName.."\nCoin : "..coins.."\nGems : "..gems, inline = false},
                                        {name = "Ultra Legendary Enchant", value = displayStr, inline = false},
                                        {name = "Stats", value = statsStr, inline = false},
                                        {name = "Buff Time Left", value = buffStr, inline = false}
                                    },
                                    footer = {text = "Renoa The Finest has Blessed You! * "..os.date("%Y-%m-%d %H:%M:%S")}
                                }
                                local pingMsg = "<@"..DISCORD_USER_ID..">"
                                if displayStr ~= "None" then pingMsg = "<@"..DISCORD_USER_ID..">, You Got "..displayStr.."!" end
                                
                                table.insert(hatchQueue, {content = DISCORD_USER_ID ~= "" and pingMsg or nil, embeds = {embed}})
                                processHatch()
                            end
                            
                            local publicEmbed = {
                                title = "Congrats You Hatched A "..variant.." Super Legendary "..pet.Name.."!",
                                color = 0x1E90FF,
                                fields = {
                                    {name = "* User Info", value = "Name : Hidden", inline = false},
                                    {name = "Ultra Legendary Enchant", value = displayStr, inline = false},
                                    {name = "Stats", value = statsStr, inline = false}
                                },
                                footer = {text = "Renoa The Finest has Blessed You! * "..os.date("%Y-%m-%d %H:%M:%S")}
                            }
                            table.insert(publicQueue, {embeds = {publicEmbed}})
                            processPublic()
                        else
                            local variant = "Normal"
                            local variantKey = "Normal"
                            if isXL and pet.Shiny and pet.Mythic then variant = "XL Shiny Mythic"; variantKey = "ShinyMythic"
                            elseif isXL and pet.Shiny then variant = "XL Shiny"; variantKey = "Shiny"
                            elseif isXL and pet.Mythic then variant = "XL Mythic"; variantKey = "Mythic"
                            elseif isXL then variant = "XL"; variantKey = "Normal"
                            elseif pet.Shiny and pet.Mythic then variant = "Shiny Mythic"; variantKey = "ShinyMythic"
                            elseif pet.Shiny then variant = "Shiny"; variantKey = "Shiny"
                            elseif pet.Mythic then variant = "Mythic"; variantKey = "Mythic" end
                            
                            local color = getColorForPet(rarity, variantKey, isXL, origin)
                            local img = getImage(pet.Name, {Shiny=pet.Shiny, Mythic=pet.Mythic})
                            local displayName = hideUsername and "Hidden" or player.Name
                            local coins = formatNum(data.Coins or 0)
                            local gems = formatNum(data.Gems or 0)
                            local opened = formatNum(data.EggsOpened and data.EggsOpened["Common Egg"] or 0)
                            local chance = info and getPetChance(info) or "Unknown"
                            local existStr = getExists(pet.Name, variant ~= "Normal" and getVariantText(variantKey) or nil)
                            local displayRarity = isXL and ("XL " .. rarity) or rarity
                            
                            if shouldSendPrivate then
                                local embed = {
                                    title = "Congrats You Hatched A "..variant.." "..displayRarity.." "..pet.Name.."!",
                                    color = color,
                                    fields = {
                                        {name = "* User Info", value = "Name : "..displayName.."\nCoin : "..coins.."\nGems : "..gems.."\nEgg Hatched : "..opened, inline = false},
                                        {name = "Pet Info", value = "Chance : "..chance.."\nExist : "..existStr.."\nOrigin : "..origin, inline = false},
                                        {name = "Stats", value = statsStr, inline = false},
                                        {name = "Buff Time Left", value = buffStr, inline = false}
                                    },
                                    footer = {text = "Renoa The Finest has Blessed You! * "..os.date("%Y-%m-%d %H:%M:%S")}
                                }
                                if img then embed.thumbnail = {url = img} end
                                
                                local pingContent = nil
                                if DISCORD_USER_ID ~= "" then
                                    pingContent = "<@"..DISCORD_USER_ID..">"
                                end
                                
                                table.insert(hatchQueue, {
                                    content = pingContent,
                                    embeds = {embed}
                                })
                                processHatch()
                            end
                            
                            local publicEmbed = {
                                title = "Congrats You Hatched A "..variant.." "..displayRarity.." "..pet.Name.."!",
                                color = color,
                                fields = {
                                    {name = "* User Info", value = "Name : Hidden", inline = false},
                                    {name = "Pet Info", value = "Chance : "..chance.."\nExist : "..existStr.."\nOrigin : "..origin, inline = false},
                                    {name = "Stats", value = statsStr, inline = false}
                                },
                                footer = {text = "Renoa The Finest has Blessed You! * "..os.date("%Y-%m-%d %H:%M:%S")}
                            }
                            if img then publicEmbed.thumbnail = {url = img} end
                            table.insert(publicQueue, {embeds = {publicEmbed}})
                            processPublic()
                        end
                    end
                end
            end
        end
    end
end)

-- ======================================
-- 4X EGG SCANNER
-- ======================================
local was4xPlushieActive = false

task.spawn(function()
    while true do
        task.wait(10)
        if not rareEggNotify then continue end
        
        local fourXFound = false
        local rendered = workspace:FindFirstChild("Rendered")
        if rendered then
            for _, obj in ipairs(rendered:GetDescendants()) do
                if obj.Name == "4x Luck Plushie Egg" and obj:IsA("Model") then fourXFound = true; break end
            end
        end
        if not fourXFound then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "4x Luck Plushie Egg" and obj:IsA("Model") then fourXFound = true; break end
            end
        end
        
        if fourXFound and not was4xPlushieActive then
            was4xPlushieActive = true
            if HATCH_WEBHOOK_URL ~= "" then
                pcall(function() request({Url = HATCH_WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({content = (DISCORD_USER_ID ~= "" and "<@"..DISCORD_USER_ID.."> " or "") .. "4x Egg Has Spawned!", embeds = {{title = "4x Egg Spawned!", description = "Go hatch it now!", color = 0xFF4500, footer = {text = "Good Luck Hatching! | Renoa Hub"}}}})}) end)
            end
        elseif not fourXFound then was4xPlushieActive = false end
    end
end)

-- ======================================
-- ANIMATION TOGGLE
-- ======================================
local success, mod = pcall(function() return require(ReplicatedStorage.Client.Effects.HatchEgg) end)
if success and mod then
    local originalPlay = mod.Play
    mod.Play = newcclosure(function(self, data)
        if getgenv().animationHidden then return end
        return originalPlay(self, data)
    end)
end

-- ======================================
-- UI
-- ======================================
WebhookTab:Section({ Title = "Webhook Settings" })

WebhookTab:Input({
    Title = "Hatch Webhook URL",
    Value = HATCH_WEBHOOK_URL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(v)
        HATCH_WEBHOOK_URL = v
        settings.webhook.hatchURL = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Input({
    Title = "Online Ping Webhook URL",
    Value = ONLINE_WEBHOOK_URL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(v)
        ONLINE_WEBHOOK_URL = v
        settings.webhook.onlineURL = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Input({
    Title = "Discord User ID",
    Value = DISCORD_USER_ID,
    Placeholder = "Discord_User_ID",
    Callback = function(v)
        DISCORD_USER_ID = v
        settings.webhook.userId = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Section({ Title = "Odds Threshold (Private Only)" })

WebhookTab:Paragraph({
    Title = "How it works",
    Desc = "Only sends private webhook if pet is RARER than this. Format: 10B = 1/10B, 100M = 1/100M, 1T = 1/1T. Leave empty to send ALL pets. Does NOT affect: Super Legendary & XL pets (always send).",
})

WebhookTab:Paragraph({
    Title = "Origin Bypass",
    Desc = "Rebirth(Cel+Inf), Bounty, Season(Cel+Inf+Void), Comp, Leaderboard — always send regardless of threshold.",
})

WebhookTab:Input({
    Title = "Only Notify Above (e.g., 10B)",
    Value = oddsThresholdInput,
    Placeholder = "10B / 100M / 1T (empty = off)",
    Callback = function(v)
        oddsThresholdInput = v
        settings.webhook.oddsThreshold = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Section({ Title = "Settings" })

WebhookTab:Toggle({
    Title = "Hide Username",
    Desc = "Shows 'Hidden' instead of your name",
    Value = hideUsername,
    Callback = function(v)
        hideUsername = v
        settings.webhook.hideUsername = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Toggle({
    Title = "On/Off Rare Egg Notification",
    Desc = "Alerts for 4x Egg spawn",
    Value = rareEggNotify,
    Callback = function(v)
        rareEggNotify = v
        settings.webhook.rareEggNotify = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Toggle({
    Title = "Auto Rejoin When Stuck",
    Desc = "Rejoins automatically after 6 min of no hatches",
    Value = autoRejoinEnabled,
    Callback = function(v)
        autoRejoinEnabled = v
        settings.webhook.autoRejoin = v
        getgenv().HubSettings.webhook = settings.webhook
        saveHubSettings()
    end,
})

WebhookTab:Section({ Title = "Status" })

WebhookTab:Paragraph({
    Title = "Active",
    Desc = "Tracking: Secret, Celestial, Infinity, Void, Super Legendary, XL\nAlerts: 4x Egg\nOnline ping: Every 30 minutes\nStuck detection: Every 2 min, rejoin after 6 min\nFragments + Stats + Buff Times\nOdds Threshold: Private only, XL & Super exempt",
})

WebhookTab:Paragraph({
    Title = "Ping Status",
    Desc = DISCORD_USER_ID ~= "" and ("ON <@" .. DISCORD_USER_ID .. ">") or "OFF",
})

print("[Webhook] Loaded!")
