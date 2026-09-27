-- ================================================
-- AUTO TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local AutoTab = Window:Tab({ Title = "Auto", Icon = "zap" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local constants = require(ReplicatedStorage.Shared.Constants)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

local RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

local function fire(action, ...)
    if RE then RE:FireServer(action, ...) end
end

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.auto then settings.auto = {} end
local autoSettings = settings.auto

-- ======================================
-- SETTINGS
-- ======================================
local presentEnabled = false
local bubbleEnabled = false
local sellEnabled = false
local powerOrbEnabled = false
local orbEnabled = false
local pickupEnabled = false
local boxEnabled = false
local presentThread = nil
local bubbleThread = nil
local sellThread = nil
local powerOrbThread = nil
local orbThread = nil
local boxThread = nil

local originalRadius = constants.DefaultPickupRadius
local BUBBLE_CAP = 650000000
local SELL_POS = Vector3.new(77, 6, -113)

-- Rune
local rune1Type = "Luck"
local rune1Tier = "1"
local rune1Amount = autoSettings.luckRuneAmount or 200
local rune1Running = false
local rune1Thread = nil

local rune2Type = "Secret"
local rune2Tier = "1"
local rune2Amount = autoSettings.secretRuneAmount or 200
local rune2Running = false
local rune2Thread = nil

local rune3Type = "Bubble"
local rune3Tier = "1"
local rune3Amount = autoSettings.bubbleRuneAmount or 200
local rune3Running = false
local rune3Thread = nil

-- Fragment
local fragRunning = false
local fragThread = nil

-- Playtime
local playtimeRunning = false
local playtimeThread = nil

-- Daily streak
local dailyRunning = false
local dailyThread = nil
local forfeitRunning = false
local forfeitThread = nil

-- Fishing
local fishRunning = false

-- ======================================
-- GET BOXES
-- ======================================
local function getBoxes()
    local boxes = {}
    local data = LocalData:Get()
    if data and data.Powerups then
        for name, amount in pairs(data.Powerups) do
            if (name:find("Box") or name:find("Crate") or name:find("Giftbox") or name:find("Present")) and amount > 0 then
                table.insert(boxes, name)
            end
        end
    end
    if #boxes == 0 then
        boxes = {"Mystery Box", "Golden Crate", "Wooden Crate"}
    end
    table.sort(boxes)
    return boxes
end

local boxList = getBoxes()
local selectedBox = autoSettings.selectedBox or boxList[1] or "Mystery Box"

-- ======================================
-- FUNCTIONS
-- ======================================
local function getRoot()
    local char = player.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
end

local function getBubbles()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if stat.Name:find("Bubble") then
                return tonumber(stat.Value) or 0
            end
        end
    end
    return 0
end

local function collectAllPresents()
    local rendered = workspace:FindFirstChild("Rendered")
    if not rendered then return 0 end
    local presentRain = rendered:FindFirstChild("PresentRain")
    if not presentRain then return 0 end
    local root = getRoot()
    local previousPos = root and root.Position or nil
    local collected = 0
    for _, model in ipairs(presentRain:GetChildren()) do
        if model:IsA("Model") then
            for _, part in ipairs(model:GetChildren()) do
                if part:IsA("BasePart") then
                    local root = getRoot()
                    if root then
                        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
                        collected = collected + 1
                        task.wait(0.02)
                    end
                    break
                end
            end
        end
    end
    if previousPos then
        local root = getRoot()
        if root then root.CFrame = CFrame.new(previousPos) end
    end
    return collected
end

-- ======================================
-- START/STOP FUNCTIONS
-- ======================================
local function startAutoPresent()
    if presentThread then return end
    presentEnabled = true
    local wasCollecting = false
    presentThread = task.spawn(function()
        while presentEnabled do
            if getgenv().questActive then
                task.wait(0.5)
                continue
            end
            
            local count = collectAllPresents()
            if count > 0 then
                if not wasCollecting then
                    getgenv().ActivityStatus.current = "Collecting Presents (" .. count .. " found)"
                    getgenv().ActivityStatus.trigger = true
                    wasCollecting = true
                end
            else
                if wasCollecting then
                    getgenv().ActivityStatus.current = "Done collecting presents"
                    getgenv().ActivityStatus.trigger = true
                    wasCollecting = false
                end
            end
            task.wait(0.5)
        end
    end)
end

local function stopAutoPresent()
    presentEnabled = false
    if presentThread then task.cancel(presentThread); presentThread = nil end
end

local function startAutoBubble()
    if bubbleThread then return end
    bubbleEnabled = true
    bubbleThread = task.spawn(function()
        while bubbleEnabled do
            pcall(function() fire("BlowBubble") end)
            task.wait(0.01)
        end
    end)
end

local function stopAutoBubble()
    bubbleEnabled = false
    if bubbleThread then task.cancel(bubbleThread); bubbleThread = nil end
end

local function startAutoSell()
    if sellThread then return end
    sellEnabled = true
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local returnCFrame = root and root.CFrame or nil
    
    sellThread = task.spawn(function()
        local needsSell = false
        
        while sellEnabled do
            local bubbles = getBubbles()
            
            if bubbles >= BUBBLE_CAP then
                needsSell = true
            elseif bubbles < 100000000 then
                needsSell = false
            end
            
            if needsSell and bubbles >= BUBBLE_CAP then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                
                if root then root.CFrame = CFrame.new(SELL_POS) end
                task.wait(0.2)
                
                for i = 1, 3 do
                    local before = getBubbles()
                    pcall(function() fire("SellBubble") end)
                    task.wait(0.3)
                    local after = getBubbles()
                    if after < before then break end
                end
                
                if returnCFrame and root then
                    root.CFrame = returnCFrame
                    root.Velocity = Vector3.zero
                    root.RotVelocity = Vector3.zero
                end
                task.wait(3)
            end
            task.wait(1)
        end
    end)
end

local function stopAutoSell()
    sellEnabled = false
    if sellThread then task.cancel(sellThread); sellThread = nil end
end

local function startAutoFragment()
    if fragThread then return end
    fragRunning = true
    fragThread = task.spawn(function()
        while fragRunning do
            pcall(function() RE:FireServer("UseFragment", "Green", 1) end)
            pcall(function() RE:FireServer("UseFragment", "Blue", 1) end)
            pcall(function() RE:FireServer("UseFragment", "Purple", 1) end)
            pcall(function() RE:FireServer("UseFragment", "Rainbow", 1) end)
            task.wait(2)
        end
    end)
end

local function stopAutoFragment()
    fragRunning = false
    if fragThread then task.cancel(fragThread); fragThread = nil end
end

local function startAutoGoldenOrb()
    if orbThread then return end
    orbEnabled = true
    orbThread = task.spawn(function()
        while orbEnabled do
            pcall(function() fire("UseGoldenOrb") end)
            task.wait(1)
        end
    end)
end

local function stopAutoGoldenOrb()
    orbEnabled = false
    if orbThread then task.cancel(orbThread); orbThread = nil end
end

local function startAutoPlaytime()
    if playtimeThread then return end
    playtimeRunning = true
    playtimeThread = task.spawn(function()
        while playtimeRunning do
            pcall(function() RE:FireServer("ClaimAllPlaytime") end)
            task.wait(60)
        end
    end)
end

local function stopAutoPlaytime()
    playtimeRunning = false
    if playtimeThread then task.cancel(playtimeThread); playtimeThread = nil end
end

local function startAutoBox()
    if boxThread then return end
    boxEnabled = true
    boxThread = task.spawn(function()
        local VIM = game:GetService("VirtualInputManager")
        while boxEnabled do
            local data = LocalData:Get()
            local amount = data and data.Powerups and data.Powerups[selectedBox] or 0
            if amount > 0 then
                local openAmount = math.min(amount, 25)
                getgenv().ActivityStatus.current = "Opening " .. selectedBox .. " x" .. openAmount
                getgenv().ActivityStatus.trigger = true
                pcall(function() fire("UseGift", selectedBox, openAmount) end)
                for i = 1, openAmount do
                    if not boxEnabled then break end
                    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end
                task.wait(0.1)
            else
                task.wait(5)
            end
        end
    end)
end

local function stopAutoBox()
    boxEnabled = false
    if boxThread then task.cancel(boxThread); boxThread = nil end
end

local function startAutoDaily()
    if dailyThread then return end
    dailyRunning = true
    dailyThread = task.spawn(function()
        while dailyRunning do
            local playerGui = player:FindFirstChild("PlayerGui")
            
            if playerGui then
                local screenGui = playerGui:FindFirstChild("ScreenGui")
                if screenGui then
                    local hud = screenGui:FindFirstChild("HUD")
                    if hud then
                        local left = hud:FindFirstChild("Left")
                        if left then
                            local buttons = left:FindFirstChild("Buttons")
                            if buttons then
                                local dailyBtn = buttons:FindFirstChild("DailyRewards")
                                if dailyBtn then
                                    local btn = dailyBtn:FindFirstChild("Button")
                                    if btn then firesignal(btn.Activated) end
                                end
                            end
                        end
                    end
                end
            end
            
            task.wait(0.5)
            
            local streakText = "Unknown"
            if playerGui then
                local screenGui = playerGui:FindFirstChild("ScreenGui")
                if screenGui then
                    local dailyRewards = screenGui:FindFirstChild("DailyRewards")
                    if dailyRewards then
                        local shop = dailyRewards:FindFirstChild("Shop")
                        if shop then
                            local streak = shop:FindFirstChild("Streak")
                            if streak then
                                local label = streak:FindFirstChild("Label")
                                if label then streakText = label.Text end
                            end
                        end
                    end
                end
            end
            
            local claimed = false
            if playerGui then
                local screenGui = playerGui:FindFirstChild("ScreenGui")
                if screenGui then
                    local dailyRewards = screenGui:FindFirstChild("DailyRewards")
                    if dailyRewards then
                        local login = dailyRewards:FindFirstChild("Login")
                        if login then
                            local loginFrame = login:FindFirstChild("Frame")
                            if loginFrame then
                                local claim = loginFrame:FindFirstChild("Claim")
                                if claim then
                                    local claimBtn = claim:FindFirstChild("Button")
                                    if claimBtn and claimBtn.Visible then
                                        firesignal(claimBtn.Activated)
                                        claimed = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            pcall(function() RE:FireServer("DailyRewardClaimStars") end)
            claimed = true
            
            task.wait(0.3)
            
            if playerGui then
                local screenGui = playerGui:FindFirstChild("ScreenGui")
                if screenGui then
                    local hud = screenGui:FindFirstChild("HUD")
                    if hud then
                        local left = hud:FindFirstChild("Left")
                        if left then
                            local buttons = left:FindFirstChild("Buttons")
                            if buttons then
                                local dailyBtn = buttons:FindFirstChild("DailyRewards")
                                if dailyBtn then
                                    local btn = dailyBtn:FindFirstChild("Button")
                                    if btn then firesignal(btn.Activated) end
                                end
                            end
                        end
                    end
                end
            end
            
            if claimed then
                getgenv().ActivityStatus.current = "Signed in for your Daily Streak! (" .. streakText .. ")"
                getgenv().ActivityStatus.trigger = true
                print("[Auto] Daily streak claimed! (" .. streakText .. ")")
            end
            
            task.wait(86400)
        end
    end)
end

local function stopAutoDaily()
    dailyRunning = false
    if dailyThread then task.cancel(dailyThread); dailyThread = nil end
end

local function startAutoFishing()
    fishRunning = true
    getgenv().ActivityStatus.current = "Starting Fishing quest..."
    getgenv().ActivityStatus.trigger = true
    
    getgenv().RdotAfishingConfig = {
        Mode = "Quest",
        Zone = "Fisher's Island",
    }
    loadstring(game:HttpGet("https://raw.githubusercontent.com/IRdotAI/Rcash-Hub/main/random-shit/autofish.lua"))()
    
    task.wait(1)
    local camera = workspace.CurrentCamera
    if camera then
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            camera.CameraType = Enum.CameraType.Scriptable
            local forward = root.CFrame.LookVector
            local right = root.CFrame.RightVector
            local leftPos = root.Position + (-right * 10) + (forward * 5)
            camera.CFrame = CFrame.new(root.Position + Vector3.new(0, 2, 0), leftPos)
            task.wait(0.3)
            camera.CameraType = Enum.CameraType.LockFirstPerson
        end
    end
end

local function stopAutoFishing()
    fishRunning = false
    getgenv().ActivityStatus.current = "Done Fishing Quest"
    getgenv().ActivityStatus.trigger = true
    
    getgenv().RdotAfishingConfig = {
        Mode = "Off",
        Zone = "Fisher's Island",
        Enabled = false
    }
    getgenv().RdotAfishingStop = true
    task.wait(0.5)
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame + Vector3.new(0, 50, 0)
    end
end

-- ======================================
-- UI - PRESENT RAIN
-- ======================================
AutoTab:Section({ Title = "Present Rain" })

AutoTab:Toggle({
    Title = "Auto Collect Presents",
    Desc = "Collects all presents in the Present Rain event",
    Value = autoSettings.presentRain or false,
    Callback = function(v)
        autoSettings.presentRain = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoPresent() else stopAutoPresent() end
    end,
})

-- ======================================
-- UI - RUNE / FRAGMENT
-- ======================================
AutoTab:Section({ Title = "Auto Rune/Fragment" })

AutoTab:Dropdown({
    Title = "Luck Rune Tier",
    Values = {"Luck Tier 1", "Luck Tier 2", "Luck Tier 3"},
    Value = autoSettings.luckRuneTier or "Luck Tier 1",
    Callback = function(v)
        local split = string.split(v, " ")
        rune1Type = split[1]
        rune1Tier = split[3]
        autoSettings.luckRuneTier = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
    end,
})

AutoTab:Input({
    Title = "Luck Rune Amount",
    Value = tostring(rune1Amount),
    Placeholder = "200",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            rune1Amount = n
            autoSettings.luckRuneAmount = n
            getgenv().HubSettings.auto = autoSettings
            saveHubSettings()
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Use Luck Rune",
    Desc = "Uses specified amount once",
    Value = false,
    Callback = function(v)
        rune1Running = v
        if v then
            rune1Thread = task.spawn(function()
                getgenv().ActivityStatus.current = "Using " .. rune1Type .. " Rune " .. rune1Amount
                getgenv().ActivityStatus.trigger = true
                pcall(function() RE:FireServer("UseRune", rune1Type, tonumber(rune1Tier), rune1Amount) end)
                rune1Running = false
            end)
        else
            if rune1Thread then task.cancel(rune1Thread) end
        end
    end,
})

AutoTab:Dropdown({
    Title = "Secret Rune Tier",
    Values = {"Secret Tier 1", "Secret Tier 2", "Secret Tier 3"},
    Value = autoSettings.secretRuneTier or "Secret Tier 1",
    Callback = function(v)
        local split = string.split(v, " ")
        rune2Type = split[1]
        rune2Tier = split[3]
        autoSettings.secretRuneTier = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
    end,
})

AutoTab:Input({
    Title = "Secret Rune Amount",
    Value = tostring(rune2Amount),
    Placeholder = "200",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            rune2Amount = n
            autoSettings.secretRuneAmount = n
            getgenv().HubSettings.auto = autoSettings
            saveHubSettings()
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Use Secret Rune",
    Desc = "Uses specified amount once",
    Value = false,
    Callback = function(v)
        rune2Running = v
        if v then
            rune2Thread = task.spawn(function()
                getgenv().ActivityStatus.current = "Using " .. rune2Type .. " Rune " .. rune2Amount
                getgenv().ActivityStatus.trigger = true
                pcall(function() RE:FireServer("UseRune", rune2Type, tonumber(rune2Tier), rune2Amount) end)
                rune2Running = false
            end)
        else
            if rune2Thread then task.cancel(rune2Thread) end
        end
    end,
})

AutoTab:Dropdown({
    Title = "Bubble Rune Tier",
    Values = {"Bubble Tier 1", "Bubble Tier 2", "Bubble Tier 3"},
    Value = autoSettings.bubbleRuneTier or "Bubble Tier 1",
    Callback = function(v)
        local split = string.split(v, " ")
        rune3Type = split[1]
        rune3Tier = split[3]
        autoSettings.bubbleRuneTier = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
    end,
})

AutoTab:Input({
    Title = "Bubble Rune Amount",
    Value = tostring(rune3Amount),
    Placeholder = "200",
    Callback = function(v)
        local n = tonumber(v)
        if n then
            rune3Amount = n
            autoSettings.bubbleRuneAmount = n
            getgenv().HubSettings.auto = autoSettings
            saveHubSettings()
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Use Bubble Rune",
    Desc = "Uses specified amount once",
    Value = false,
    Callback = function(v)
        rune3Running = v
        if v then
            rune3Thread = task.spawn(function()
                getgenv().ActivityStatus.current = "Using " .. rune3Type .. " Rune " .. rune3Amount
                getgenv().ActivityStatus.trigger = true
                pcall(function() RE:FireServer("UseRune", rune3Type, tonumber(rune3Tier), rune3Amount) end)
                rune3Running = false
            end)
        else
            if rune3Thread then task.cancel(rune3Thread) end
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Use All Fragment",
    Desc = "Uses 1 of each fragment every 2 seconds",
    Value = autoSettings.autoFragment or false,
    Callback = function(v)
        autoSettings.autoFragment = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoFragment() else stopAutoFragment() end
    end,
})

-- ======================================
-- UI - AUTO
-- ======================================
AutoTab:Section({ Title = "Auto" })

AutoTab:Toggle({
    Title = "Auto Blow Bubble",
    Desc = "Blows bubble 100 times per second",
    Value = autoSettings.autoBubble or false,
    Callback = function(v)
        autoSettings.autoBubble = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoBubble() else stopAutoBubble() end
    end,
})

AutoTab:Toggle({
    Title = "Auto Sell Bubble",
    Desc = "Sells when Bubbles reach 650M (returns after)",
    Value = autoSettings.autoSell or false,
    Callback = function(v)
        autoSettings.autoSell = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoSell() else stopAutoSell() end
    end,
})

AutoTab:Toggle({
    Title = "Auto Daily Streak",
    Desc = "Claims daily rewards every 24 hours",
    Value = autoSettings.dailyStreak or false,
    Callback = function(v)
        autoSettings.dailyStreak = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoDaily() else stopAutoDaily() end
    end,
})

AutoTab:Toggle({
    Title = "Auto Forfeit Streak",
    Desc = "Resets your daily streak (one-time)",
    Value = autoSettings.autoForfeit or false,
    Callback = function(v)
        forfeitRunning = v
        autoSettings.autoForfeit = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then
            forfeitThread = task.spawn(function()
                local playerGui = player:FindFirstChild("PlayerGui")
                local hasStreak = false
                if playerGui then
                    local screenGui = playerGui:FindFirstChild("ScreenGui")
                    if screenGui then
                        local dailyRewards = screenGui:FindFirstChild("DailyRewards")
                        if dailyRewards then
                            local streak = dailyRewards:FindFirstChild("Streak")
                            if streak then
                                local label = streak:FindFirstChild("Label")
                                if label and label.Text ~= "" and label.Text ~= "0" then
                                    hasStreak = true
                                end
                            end
                        end
                    end
                end
                
                if hasStreak then
                    pcall(function() RE:FireServer("DailyRewardsForfeitStreak") end)
                    getgenv().ActivityStatus.current = "Forfeited Daily Streak!"
                    getgenv().ActivityStatus.trigger = true
                end
                
                forfeitRunning = false
            end)
        else
            if forfeitThread then task.cancel(forfeitThread) end
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Claim XL Index",
    Desc = "Claims XL Index rewards automatically",
    Value = autoSettings.autoXLIndex or false,
    Callback = function(v)
        autoSettings.autoXLIndex = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then
            task.spawn(function()
                local XLIndexTasks = require(ReplicatedStorage.Shared.Data.XLIndexTasks)
                local totalTasks = 0
                for _ in pairs(XLIndexTasks) do totalTasks = totalTasks + 1 end
                
                while v do
                    local data = LocalData:Get()
                    local claimed = data and data.XLIndexClaimed
                    local beforeCount = claimed and #claimed or 0
                    
                    if beforeCount < totalTasks then
                        pcall(function() RE:FireServer("ClaimXLIndexRewards") end)
                        task.wait(1)
                        
                        local data2 = LocalData:Get()
                        local afterClaimed = data2 and data2.XLIndexClaimed
                        local afterCount = afterClaimed and #afterClaimed or 0
                        
                        if afterCount > beforeCount then
                            getgenv().ActivityStatus.current = "Claimed XL Index Reward! (" .. afterCount .. "/" .. totalTasks .. ")"
                            getgenv().ActivityStatus.trigger = true
                            task.wait(5)
                        else
                            task.wait(600)
                        end
                    else
                        break
                    end
                end
            end)
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Use Power Orb",
    Desc = "Uses Power Orb on 13 hardcoded pet IDs (one-time)",
    Value = false,
    Callback = function(v)
        powerOrbEnabled = v
        if v then
            powerOrbThread = task.spawn(function()
                local petIDs = {
                    "a0a3c245-ff67-4723-b85c-5d141d0a9649",
                    "2ac153c7-11b7-49c1-85e3-354f80941818",
                    "bd2d105a-1fcb-4e81-a420-80224d8830ad",
                    "10ee81b6-f9c3-4ec3-a829-9b2f868b6400",
                    "8a69932e-e1bf-4f0f-b23d-16d2c0449eb",
                    "d89b08da-0523-4598-9640-eae1cd880e70",
                    "a67d8c44-1c52-4787-8f55-81bb9bdafa",
                    "16a93d1f-a19a-4057-860b-bcf0c227d2kd",
                    "ac52d576-fcbe-4502-9753-57e271a16e00",
                    "742c65af-b0e9-43e5-b107-0e3a3fd6e57",
                    "d4142051-aecc-4c3f-8339-149f4cbb95a7",
                    "4a9c203f-8d7e-49ae-abe1-e07bb7559980",
                    "1b809029-dee6-4eb4-8414-7139037kb19",
                }
                for i = 1, #petIDs do
                    if not powerOrbEnabled then break end
                    pcall(function() fire("UsePowerOrb", petIDs[i]) end)
                    task.wait(0.5)
                end
                powerOrbEnabled = false
            end)
        else
            if powerOrbThread then task.cancel(powerOrbThread) end
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Use Golden Orb",
    Desc = "Uses Golden Orb every 1 second",
    Value = autoSettings.autoGoldenOrb or false,
    Callback = function(v)
        autoSettings.autoGoldenOrb = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoGoldenOrb() else stopAutoGoldenOrb() end
    end,
})

AutoTab:Toggle({
    Title = "Auto Collect Pickup",
    Desc = "Sets pickup radius to infinite (re-equip a pet to apply)",
    Value = autoSettings.autoPickup or false,
    Callback = function(v)
        pickupEnabled = v
        autoSettings.autoPickup = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then
            constants.DefaultPickupRadius = math.huge
        else
            constants.DefaultPickupRadius = originalRadius
        end
    end,
})

AutoTab:Toggle({
    Title = "Auto Playtime",
    Desc = "Claims playtime rewards every 60 seconds",
    Value = autoSettings.autoPlaytime or false,
    Callback = function(v)
        autoSettings.autoPlaytime = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoPlaytime() else stopAutoPlaytime() end
    end,
})

-- ======================================
-- UI - AUTO OPEN BOX
-- ======================================
AutoTab:Section({ Title = "Auto Open Box" })

AutoTab:Dropdown({
    Title = "Select Box",
    Values = boxList,
    Value = selectedBox,
    Callback = function(v)
        selectedBox = v
        autoSettings.selectedBox = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
    end,
})

local boxListParagraph = AutoTab:Paragraph({
    Title = "Box List",
    Desc = "Boxes loaded. Click Rescan to refresh.",
})

AutoTab:Button({
    Title = "Re Scan Boxes",
    Desc = "Refresh the list of available boxes",
    Callback = function()
        boxList = getBoxes()
        selectedBox = boxList[1] or "Mystery Box"
        local text = "Found " .. #boxList .. " boxes"
        pcall(function() boxListParagraph:SetDesc(text) end)
    end,
})

AutoTab:Toggle({
    Title = "Auto Open Box (don't use near egg)",
    Desc = "Opens selected box 25 at a time",
    Value = autoSettings.autoOpenBox or false,
    Callback = function(v)
        autoSettings.autoOpenBox = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoBox() else stopAutoBox() end
    end,
})

-- ======================================
-- UI - FISHING
-- ======================================
AutoTab:Section({ Title = "Fishing" })

AutoTab:Paragraph({
    Title = "Instructions",
    Desc = "After you turn it on, go first person POV and look to your left side, then you can leave it.",
})

AutoTab:Toggle({
    Title = "Auto Fishing Quest",
    Desc = "Loads external auto-fishing script",
    Value = autoSettings.autoFishing or false,
    Callback = function(v)
        autoSettings.autoFishing = v
        getgenv().HubSettings.auto = autoSettings
        saveHubSettings()
        if v then startAutoFishing() else stopAutoFishing() end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1)
    
    if autoSettings.presentRain then startAutoPresent() end
    if autoSettings.autoBubble then startAutoBubble() end
    if autoSettings.autoSell then startAutoSell() end
    if autoSettings.autoFragment then startAutoFragment() end
    if autoSettings.dailyStreak then startAutoDaily() end
    if autoSettings.autoGoldenOrb then startAutoGoldenOrb() end
    if autoSettings.autoPlaytime then startAutoPlaytime() end
    if autoSettings.autoOpenBox then startAutoBox() end
    if autoSettings.autoFishing then startAutoFishing() end
    
    if autoSettings.autoPickup then
        pickupEnabled = true
        constants.DefaultPickupRadius = math.huge
    end
end)
