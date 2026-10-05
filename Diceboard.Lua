-- ================================================
-- MINIGAME TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local DiceBoardTab = Window:Tab({ Title = "Minigame", Icon = "gamepad-2" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Board = require(ReplicatedStorage.Client.Gui.Frames.Board)
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.diceboard then settings.diceboard = {} end
local diceSettings = settings.diceboard

-- ======================================
-- TILE TYPES
-- ======================================
local TILE_TYPES = {
    ["Chance"] = {5,13,25,29,32,36,39,40,44,50,53,55,60,61,62,72,76,78,79,83},
    ["Dice-Key"] = {19,21,34,47,80},
    ["Dice"] = {4,12,16,41,42,54,59},
    ["Giant-Dice"] = {69},
    ["Golden-Dice"] = {10,20,26,28,45,49,75,86},
    ["Infinity-Elixir"] = {17,64},
    ["Special-Egg"] = {27,57,63,71,82},
    ["Super-Ticket"] = {8,11,18,52,65,66},
    ["Basic"] = {1,6,7,9,14,15,22,23,24,30,31,35,37,48,51,56,58,67,68,70,73,74,81,84,85,87},
}

local targetTile = diceSettings.targetTile or "Chance"
local running = false
local thread = nil

-- ======================================
-- FUNCTIONS
-- ======================================
local function getNode()
    for name, piece in pairs(Board.Pieces) do
        if name == player.Name then
            local raw = piece.Node.Part
            if typeof(raw) == "number" then return raw
            elseif typeof(raw) == "string" then return tonumber(raw)
            elseif typeof(raw) == "Instance" then return tonumber(raw.Name)
            end
        end
    end
    return nil
end

local function getClosest(current, list)
    local closest = nil
    local dist = math.huge
    for _, num in ipairs(list) do
        local d = (num >= current) and (num - current) or (88 - current + num)
        if d < dist then
            dist = d
            closest = num
        end
    end
    return closest, dist
end

local function hasGoldenDice()
    if getgenv().remainingItems and getgenv().remainingItems["Golden Dice"] then
        return getgenv().remainingItems["Golden Dice"] > 0
    end
    return false
end

local function getBoardHUD()
    local ok, playerGui = pcall(function() return player.PlayerGui end)
    if not ok then return nil end
    local screenGui = playerGui:FindFirstChild("ScreenGui")
    if not screenGui then return nil end
    return screenGui:FindFirstChild("BoardHUD")
end

local function selectDice(diceName)
    local hud = getBoardHUD()
    if not hud then return false end
    local diceFrame = hud.Dice.Inventory:FindFirstChild(diceName)
    if not diceFrame then return false end
    local button = diceFrame:FindFirstChild("Button")
    if not button then return false end
    firesignal(button.Activated)
    return true
end

local function pressRoll()
    local hud = getBoardHUD()
    if not hud then return false end
    local rollButton = hud.Dice.Actions.Roll.Button
    if not rollButton then return false end
    firesignal(rollButton.Activated)
    return true
end

local function waitForNodeChange(oldNode, timeout)
    local elapsed = 0
    while elapsed < timeout do
        task.wait(0.3)
        elapsed = elapsed + 0.3
        local current = getNode()
        if current and current ~= oldNode then return current end
    end
    return getNode()
end

local function loop()
    while running do
        local node = getNode()
        if not node then
            task.wait(2)
            continue
        end

        local target, dist = getClosest(node, TILE_TYPES[targetTile])
        local goldenAvailable = hasGoldenDice()
        local diceName = "Dice"
        local waitTime = 2.5

        if goldenAvailable and dist <= 2 then
            diceName = "Golden Dice"
            waitTime = 1.5
        elseif dist >= 10 then
            diceName = "Giant Dice"
            waitTime = 4.5
        else
            diceName = "Dice"
            waitTime = 2.5
        end

        local selected = selectDice(diceName)
        if not selected then
            diceName = "Dice"
            waitTime = 2.5
            selectDice("Dice")
        end

        task.wait(0.3)
        pressRoll()
        waitForNodeChange(node, waitTime + 2)
        task.wait(1)
    end
end

local function startDiceLoop()
    if running then return end
    running = true
    if not getBoardHUD() then
        running = false
        return
    end
    thread = task.spawn(loop)
end

local function stopDiceLoop()
    running = false
    if thread then 
        task.cancel(thread)
        thread = nil
    end
end

-- ======================================
-- MINIGAME SETUP
-- ======================================
local MINIGAMES = {
    "Cart Escape",
    "Hyper Darts",
    "Pet Match",
    "Circus Pet Match",
}

local DIFFICULTIES = {"Easy", "Medium", "Hard", "Insane"}

local selectedMinigame = diceSettings.selectedMinigame or "Cart Escape"
local selectedDifficulty = diceSettings.selectedDifficulty or "Easy"
local autoMinigameRunning = false
local autoMinigameThread = nil
local currentLoopId = 0

local function getMinigameCooldownRemaining(minigameName)
    local data = LocalData:Get()
    if data and data.Cooldowns then
        local cd = data.Cooldowns[minigameName]
        if cd then
            return math.max(0, cd - os.time())
        end
    end
    return 0
end

local function getSuperTicketCount()
    local data = LocalData:Get()
    if data and data.Powerups then
        return data.Powerups["Super Ticket"] or 0
    end
    return 0
end

local function minigameLoop(myLoopId, targetMinigame, targetDifficulty)
    while autoMinigameRunning and currentLoopId == myLoopId do
        local remaining = getMinigameCooldownRemaining(targetMinigame)

        if remaining > 0 then
            if diceSettings.autoSuperTicket then
                local tickets = getSuperTicketCount()
                if tickets > 0 then
                    pcall(function()
                        Remote:FireServer("SkipMinigameCooldown", targetMinigame)
                    end)
                    task.wait(1.5)
                    remaining = getMinigameCooldownRemaining(targetMinigame)
                    if remaining > 0 then
                        task.wait(2)
                        continue
                    end
                else
                    task.wait(5)
                    continue
                end
            else
                task.wait(5)
                continue
            end
        end

        -- Start minigame
        pcall(function()
            Remote:FireServer("StartMinigame", targetMinigame, targetDifficulty)
        end)
        task.wait(1)

        -- Spam FinishMinigame until cooldown set
        local attempts = 0
        while autoMinigameRunning and currentLoopId == myLoopId and attempts < 30 do
            attempts = attempts + 1
            pcall(function()
                Remote:FireServer("FinishMinigame")
            end)
            task.wait(0.3)

            local cd = getMinigameCooldownRemaining(targetMinigame)
            if cd > 0 then
                break
            end
        end

        task.wait(2)
    end
end

local function startMinigameLoop()
    if autoMinigameRunning then
        autoMinigameRunning = false
        currentLoopId = currentLoopId + 1
        task.wait(0.5)
    end

    autoMinigameRunning = true
    currentLoopId = currentLoopId + 1
    local myLoopId = currentLoopId
    local targetMinigame = selectedMinigame
    local targetDifficulty = selectedDifficulty

    -- ActivityStatus webhook
    getgenv().ActivityStatus.current = "Auto Start " .. targetMinigame .. " Minigame"
    getgenv().ActivityStatus.trigger = true

    autoMinigameThread = task.spawn(function()
        minigameLoop(myLoopId, targetMinigame, targetDifficulty)
    end)
end

local function stopMinigameLoop()
    autoMinigameRunning = false
    currentLoopId = currentLoopId + 1
    if autoMinigameThread then
        pcall(function() task.cancel(autoMinigameThread) end)
        autoMinigameThread = nil
    end
end

-- ======================================
-- HIDE SCREENS SETUP
-- ======================================
local HIDE_TARGETS = {"TeleportingGui", "TransitionGui", "LoadingGui"}
local hookedGuis = {}
local hideScreensRunning = false
local hideScreensConnections = {}

local function hookGuiForHiding(gui)
    if hookedGuis[gui] then return end
    hookedGuis[gui] = true

    -- Instant hide on Enabled change
    local conn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if gui.Enabled then
            gui.Enabled = false
        end
    end)
    table.insert(hideScreensConnections, conn)

    -- Also hook ChildAdded
    local conn2 = gui.ChildAdded:Connect(function()
        task.wait()
        if gui.Enabled then
            gui.Enabled = false
        end
    end)
    table.insert(hideScreensConnections, conn2)

    -- Hide immediately
    if gui.Enabled then
        gui.Enabled = false
    end
end

local function unhookAllGuis()
    for _, conn in ipairs(hideScreensConnections) do
        pcall(function() conn:Disconnect() end)
    end
    hideScreensConnections = {}
    hookedGuis = {}
end

local function startHideScreens()
    if hideScreensRunning then return end
    hideScreensRunning = true

    local pg = player:WaitForChild("PlayerGui")

    -- Hook existing GUIs
    for _, name in ipairs(HIDE_TARGETS) do
        local gui = pg:FindFirstChild(name)
        if gui then
            hookGuiForHiding(gui)
        end
    end

    -- Hook new GUIs (in case they get recreated)
    local pgConn = pg.ChildAdded:Connect(function(child)
        for _, name in ipairs(HIDE_TARGETS) do
            if child.Name == name then
                task.wait(0.05)
                hookGuiForHiding(child)
            end
        end
    end)
    table.insert(hideScreensConnections, pgConn)
end

local function stopHideScreens()
    hideScreensRunning = false
    unhookAllGuis()

    -- Restore GUIs
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        for _, name in ipairs(HIDE_TARGETS) do
            local gui = pg:FindFirstChild(name)
            if gui then
                pcall(function() gui.Enabled = true end)
            end
        end
    end
end

-- ======================================
-- UI - SETTINGS
-- ======================================
DiceBoardTab:Section({ Title = "Settings" })

DiceBoardTab:Dropdown({
    Title = "Target Tile",
    Values = {
        "Chance", "Dice-Key", "Dice", "Giant-Dice", "Golden-Dice",
        "Infinity-Elixir", "Special-Egg", "Super-Ticket", "Basic"
    },
    Value = targetTile,
    Callback = function(v)
        targetTile = v
        diceSettings.targetTile = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()
    end,
})

DiceBoardTab:Toggle({
    Title = "Auto Dice Board",
    Desc = "Automatically rolls dice to reach the target tile",
    Value = diceSettings.autoDice or false,
    Callback = function(v)
        diceSettings.autoDice = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()
        if v then
            startDiceLoop()
        else
            stopDiceLoop()
        end
    end,
})

-- ======================================
-- UI - AUTO MINIGAME
-- ======================================
DiceBoardTab:Section({ Title = "Auto Minigame" })

DiceBoardTab:Dropdown({
    Title = "Select Minigame",
    Values = MINIGAMES,
    Value = selectedMinigame,
    Callback = function(v)
        selectedMinigame = v
        diceSettings.selectedMinigame = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()

        if autoMinigameRunning then
            startMinigameLoop()
        end
    end,
})

DiceBoardTab:Dropdown({
    Title = "Select Difficulty",
    Values = DIFFICULTIES,
    Value = selectedDifficulty,
    Callback = function(v)
        selectedDifficulty = v
        diceSettings.selectedDifficulty = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()

        if autoMinigameRunning then
            startMinigameLoop()
        end
    end,
})

DiceBoardTab:Toggle({
    Title = "Auto Play Minigame",
    Desc = "Plays the selected minigame on repeat",
    Value = diceSettings.autoMinigame or false,
    Callback = function(v)
        diceSettings.autoMinigame = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()
        if v then
            startMinigameLoop()
        else
            stopMinigameLoop()
        end
    end,
})

DiceBoardTab:Toggle({
    Title = "Use Super Ticket to Skip Cooldown",
    Desc = "Automatically uses Super Ticket when on cooldown",
    Value = diceSettings.autoSuperTicket or false,
    Callback = function(v)
        diceSettings.autoSuperTicket = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()
    end,
})

-- ======================================
-- UI - HIDE SCREENS
-- ======================================
DiceBoardTab:Section({ Title = "Hide Screens" })

DiceBoardTab:Toggle({
    Title = "Hide Teleporting / Returning Home / Loading Screens",
    Desc = "Instantly hides transition GUIs during minigames",
    Value = diceSettings.hideScreens or false,
    Callback = function(v)
        diceSettings.hideScreens = v
        getgenv().HubSettings.diceboard = diceSettings
        saveHubSettings()
        if v then
            startHideScreens()
        else
            stopHideScreens()
        end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1.5)

    if diceSettings.autoDice then
        startDiceLoop()
    end

    if diceSettings.autoMinigame then
        startMinigameLoop()
    end

    if diceSettings.hideScreens then
        startHideScreens()
    end
end)

print("[Minigame] Loaded!")
