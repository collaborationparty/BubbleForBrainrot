-- ================================================
-- MISC / OTHER TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local OtherTab = Window:Tab({ Title = "Misc", Icon = "settings" })

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

-- ======================================
-- STATS TRACKER
-- ======================================
local statsEnabled = false
local screenGui = nil
local frame = nil
local hatchedLabel = nil
local rateLabel = nil
local timeLabel = nil
local bestHatchLabel = nil

local startTime = 0
local startHatches = 0
local currentHatches = 0

local TRACKED_RARITIES = {"Secret", "Celestial", "Infinity", "Void"}
local seenPetIds = {}
local bestHatchReady = false
local bestHatchName = "None"
local bestHatchChance = math.huge
local bestHatchVariant = "Normal"
local bestHatchDisplay = "Best Hatch: None\nOdds: N/A"

local function getHatches()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat.Name:find("Hatches") then
                return tonumber(stat.Value) or 0
            end
        end
    end
    return 0
end

local function getChanceDisplay(chance)
    if chance >= 1 then return chance .. "%"
    elseif chance > 0 then
        local oneIn = 100 / chance
        if oneIn >= 1e9 then return "1/" .. string.format("%.0f", oneIn / 1e9) .. "B"
        elseif oneIn >= 1e6 then return "1/" .. string.format("%.1f", oneIn / 1e6) .. "M"
        elseif oneIn >= 1e3 then return "1/" .. string.format("%.1f", oneIn / 1e3) .. "K"
        else return "1/" .. string.format("%.0f", oneIn) end
    end
    return "Unknown"
end

local function checkForBestHatch()
    if not bestHatchReady then return end
    local data = LocalData:Get()
    if not data or not data.Pets then return end
    for _, pet in pairs(data.Pets) do
        if not seenPetIds[pet.Id] then
            seenPetIds[pet.Id] = true
            local info = Pets[pet.Name]
            if info and info.Rarity and info.Chance then
                local rarity = info.Rarity
                local isTracked = false
                for _, r in ipairs(TRACKED_RARITIES) do
                    if rarity:find(r) then isTracked = true; rarity = r; break end
                end
                if isTracked then
                    local chance = tonumber(info.Chance) or 0
                    if chance > 0 and chance < bestHatchChance then
                        bestHatchChance = chance
                        bestHatchName = pet.Name
                        if pet.Shiny and pet.Mythic then bestHatchVariant = "Shiny Mythic"
                        elseif pet.Shiny then bestHatchVariant = "Shiny"
                        elseif pet.Mythic then bestHatchVariant = "Mythic"
                        else bestHatchVariant = "Normal" end
                        local odds = getChanceDisplay(chance)
                        bestHatchDisplay = "Best Hatch: " .. bestHatchVariant .. " " .. bestHatchName .. "\nOdds: " .. odds
                        if bestHatchLabel then pcall(function() bestHatchLabel.Text = bestHatchDisplay end) end
                    end
                end
            end
        end
    end
end

local function updateStats()
    currentHatches = getHatches()
    local elapsed = os.clock() - startTime
    local minutes = elapsed / 60
    local hours = elapsed / 3600
    local hatchedSinceStart = currentHatches - startHatches
    local perMin = minutes > 0 and math.floor(hatchedSinceStart / minutes) or 0
    local perHour = hours > 0 and math.floor(hatchedSinceStart / hours) or 0
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local s = math.floor(elapsed % 60)
    local timeStr = string.format("%02d:%02d:%02d", h, m, s)
    if hatchedLabel then hatchedLabel.Text = "Hatched: " .. hatchedSinceStart end
    if rateLabel then rateLabel.Text = "Rate: " .. perMin .. "/min | " .. perHour .. "/hr" end
    if timeLabel then timeLabel.Text = "Time: " .. timeStr end
    checkForBestHatch()
end

local function createStatsUI()
    if screenGui then return end
    seenPetIds = {}
    local data = LocalData:Get()
    if data and data.Pets then
        for petId, _ in pairs(data.Pets) do seenPetIds[petId] = true end
    end
    bestHatchReady = true
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StatsTracker"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 135)
    frame.Position = UDim2.new(1, -210, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 22)
    title.Position = UDim2.new(0, 5, 0, 5)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Stats Tracker"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    hatchedLabel = Instance.new("TextLabel")
    hatchedLabel.Size = UDim2.new(1, -10, 0, 18)
    hatchedLabel.Position = UDim2.new(0, 5, 0, 28)
    hatchedLabel.BackgroundTransparency = 1
    hatchedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    hatchedLabel.Text = "Hatched: 0"
    hatchedLabel.Font = Enum.Font.Gotham
    hatchedLabel.TextSize = 12
    hatchedLabel.TextXAlignment = Enum.TextXAlignment.Left
    hatchedLabel.Parent = frame
    
    rateLabel = Instance.new("TextLabel")
    rateLabel.Size = UDim2.new(1, -10, 0, 18)
    rateLabel.Position = UDim2.new(0, 5, 0, 47)
    rateLabel.BackgroundTransparency = 1
    rateLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    rateLabel.Text = "Rate: 0/min | 0/hr"
    rateLabel.Font = Enum.Font.Gotham
    rateLabel.TextSize = 12
    rateLabel.TextXAlignment = Enum.TextXAlignment.Left
    rateLabel.Parent = frame
    
    timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(1, -10, 0, 18)
    timeLabel.Position = UDim2.new(0, 5, 0, 66)
    timeLabel.BackgroundTransparency = 1
    timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeLabel.Text = "Time: 00:00:00"
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextSize = 12
    timeLabel.TextXAlignment = Enum.TextXAlignment.Left
    timeLabel.Parent = frame
    
    bestHatchLabel = Instance.new("TextLabel")
    bestHatchLabel.Size = UDim2.new(1, -10, 0, 36)
    bestHatchLabel.Position = UDim2.new(0, 5, 0, 88)
    bestHatchLabel.BackgroundTransparency = 1
    bestHatchLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    bestHatchLabel.Text = "Best Hatch: None\nOdds: N/A"
    bestHatchLabel.Font = Enum.Font.Gotham
    bestHatchLabel.TextSize = 11
    bestHatchLabel.TextXAlignment = Enum.TextXAlignment.Left
    bestHatchLabel.RichText = true
    bestHatchLabel.Parent = frame
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    title.InputEnded:Connect(function(input)
        dragging = false
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    task.spawn(function()
        while statsEnabled do
            updateStats()
            task.wait(1)
        end
    end)
end

local function destroyStatsUI()
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
end

-- ======================================
-- AUTO BUY SHOP
-- ======================================
local SHOP_ITEMS = {
    ["shadow-shop"] = {1, 2, 3},
    ["alien-shop"] = {1, 2, 3},
    ["shard-shop"] = {1, 2, 3},
    ["dice-shop"] = {1, 2, 3},
    ["traveling-merchant"] = {1, 2, 3},
}

local selectedShop = "shadow-shop"
local shopRunning = false
local shopThread = nil
local buyAllRunning = false
local buyAllThread = nil

local function buyShop(shopName)
    local items = SHOP_ITEMS[shopName]
    if items then
        for _, itemNum in ipairs(items) do
            pcall(function() RE:FireServer("BuyShopItem", shopName, itemNum, true) end)
        end
    end
end

-- ======================================
-- EFFECTS
-- ======================================
local function safeSet(obj, prop, value)
    pcall(function() obj[prop] = value end)
end

local function fpsJMX()
    setfpscap(120)
    Lighting.GlobalShadows = false
    Lighting.ShadowSoftness = 0
    Lighting.FogEnd = 9e9
    sethiddenproperty(Lighting, "Technology", "Compatibility")
    settings().Rendering.QualityLevel = 1
    if workspace.CurrentCamera then
        workspace.CurrentCamera:ClearAllChildren()
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0
            v.CastShadow = false
        end
        if v:IsA("MeshPart") then
            v.MeshId = ""
            v.TextureID = ""
        end
        if v:IsA("SpecialMesh") then
            v.MeshId = ""
            v.TextureId = ""
        end
        if v:IsA("ParticleEmitter") or v:IsA("Explosion") then
            v.Enabled = false
        end
        if v:IsA("Decal") then
            v.Texture = ""
        end
    end
    print("[FPS] JMX FPS Boost applied!")
end

local function fps1_DisableParticles()
    local count = 0
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("BasePart") then
            safeSet(v, "Material", Enum.Material.SmoothPlastic)
            count = count + 1
        end
        if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            safeSet(v, "Enabled", false)
            count = count + 1
        end
        if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
            safeSet(v, "Enabled", false)
            count = count + 1
        end
        if v:IsA("Decal") or v:IsA("Texture") then
            safeSet(v, "Transparency", 1)
            count = count + 1
        end
        if v:IsA("Sky") then
            safeSet(v, "Parent", nil)
            count = count + 1
        end
        if count % 500 == 0 then task.wait(0.01) end
    end
    print("[FPS] Disabled " .. count .. " effects")
end

local function fps2_HidePets()
    local count = 0
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") then
            if v.Enabled then
                v.Enabled = false
                count = count + 1
            end
        end
        if v:IsA("Model") and v.Parent and v.Parent.Name == "Pets" then
            for _, part in ipairs(v:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency < 1 then
                    part.Transparency = 1
                    count = count + 1
                end
            end
        end
        if count % 500 == 0 then task.wait(0.01) end
    end
    print("[FPS] Disabled " .. count .. " pet effects")
end

local function fps3_RemoveTextures()
    local count = 0
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("Decal") or v:IsA("Texture") then
            v.Texture = ""
            count = count + 1
        end
        if v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Sparkles") then
            if v.Enabled then
                v.Enabled = false
                count = count + 1
            end
        end
        if v:IsA("BasePart") and v.Material ~= Enum.Material.SmoothPlastic then
            v.Material = Enum.Material.SmoothPlastic
            count = count + 1
        end
        if v:IsA("BasePart") and v.CastShadow then
            v.CastShadow = false
            count = count + 1
        end
        if count % 1000 == 0 then task.wait(0.01) end
    end
    Lighting.GlobalShadows = false
    Lighting.Outlines = false
    print("[FPS] Disabled " .. count .. " effects")
end

local function fullBright()
    safeSet(Lighting, "Brightness", 5)
    safeSet(Lighting, "Ambient", Color3.fromRGB(255, 255, 255))
    safeSet(Lighting, "OutdoorAmbient", Color3.fromRGB(255, 255, 255))
    safeSet(Lighting, "FogEnd", math.huge)
end

-- ======================================
-- UI
-- ======================================
OtherTab:Section({ Title = "Stats Tracker" })

OtherTab:Toggle({
    Title = "Show Stats UI",
    Desc = "Shows a draggable stats overlay (Hatched, Rate, Time, Best Hatch)",
    Value = false,
    Callback = function(v)
        statsEnabled = v
        if v then
            startTime = os.clock()
            startHatches = getHatches()
            bestHatchName = "None"
            bestHatchChance = math.huge
            bestHatchVariant = "Normal"
            bestHatchDisplay = "Best Hatch: None\nOdds: N/A"
            seenPetIds = {}
            bestHatchReady = false
            createStatsUI()
        else
            destroyStatsUI()
        end
    end,
})

-- ======================================
-- UI - AUTO BUY SHOP
-- ======================================
OtherTab:Section({ Title = "Auto Buy Shop" })

OtherTab:Dropdown({
    Title = "Select Shop",
    Values = {"shadow-shop", "alien-shop", "shard-shop", "dice-shop", "traveling-merchant"},
    Value = selectedShop,
    Callback = function(v)
        selectedShop = v
    end,
})

OtherTab:Toggle({
    Title = "Auto Buy Selected Shop",
    Desc = "Buys all items from selected shop every 1 sec",
    Value = false,
    Callback = function(v)
        shopRunning = v
        if v then
            shopThread = task.spawn(function()
                while shopRunning do
                    buyShop(selectedShop)
                    task.wait(1)
                end
            end)
        else
            if shopThread then task.cancel(shopThread) end
        end
    end,
})

OtherTab:Toggle({
    Title = "Auto Buy All Shop",
    Desc = "Buys all items from ALL shops every 1 sec",
    Value = false,
    Callback = function(v)
        buyAllRunning = v
        if v then
            buyAllThread = task.spawn(function()
                while buyAllRunning do
                    for shopName, _ in pairs(SHOP_ITEMS) do
                        buyShop(shopName)
                    end
                    task.wait(1)
                end
            end)
        else
            if buyAllThread then task.cancel(buyAllThread) end
        end
    end,
})

OtherTab:Button({
    Title = "Reroll Shadow Shop Stock",
    Desc = "Free reroll of Shadow Shop",
    Callback = function()
        pcall(function() RE:FireServer("ShopFreeReroll", "shadow-shop") end)
        print("[Shop] Shadow Shop rerolled!")
    end,
})

OtherTab:Button({
    Title = "Reroll Traveling Merchant Stock",
    Desc = "Free reroll of Traveling Merchant",
    Callback = function()
        pcall(function() RE:FireServer("ShopFreeReroll", "traveling-merchant") end)
        print("[Shop] Traveling Merchant rerolled!")
    end,
})

-- ======================================
-- UI - EFFECTS
-- ======================================
OtherTab:Section({ Title = "Effects" })

OtherTab:Button({
    Title = "JMX FPS Boost (Aggressive)",
    Desc = "Maximum FPS boost — removes shadows, meshes, particles",
    Callback = function()
        fpsJMX()
    end,
})

OtherTab:Button({
    Title = "Disable Particles & Materials",
    Desc = "Removes particles, effects, and forces SmoothPlastic",
    Callback = function()
        fps1_DisableParticles()
    end,
})

OtherTab:Button({
    Title = "Hide Pets & Effects",
    Desc = "Hides all pet models and effects",
    Callback = function()
        fps2_HidePets()
    end,
})

OtherTab:Button({
    Title = "Remove Shadows & Textures",
    Desc = "Removes all decals, textures, and shadows",
    Callback = function()
        fps3_RemoveTextures()
    end,
})

OtherTab:Button({
    Title = "Click for Brightness",
    Desc = "Fullbright — makes everything visible",
    Callback = function()
        fullBright()
    end,
})

print("[Misc] Loaded!")
