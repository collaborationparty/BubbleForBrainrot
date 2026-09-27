-- ================================================
-- TRADE TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local TradeTab = Window:Tab({ Title = "Trade", Icon = "arrow-left-right" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Remote = require(ReplicatedStorage.Shared.Framework.Network.Remote)

-- ======================================
-- SETTINGS
-- ======================================
local targetPlayerInput = nil
local targetPlayer = ""
local sendRunning = false
local sendThread = nil
local acceptRunning = false
local acceptThread = nil
local confirmRunning = false
local confirmThread = nil
local movePetRunning = false
local movePetThread = nil

-- ======================================
-- FUNCTIONS
-- ======================================
local function findPlayer(name)
    if name == "" then return nil end
    
    local exact = Players:FindFirstChild(name)
    if exact then return exact end
    
    local lowerName = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == lowerName then
            return p
        end
    end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(lowerName) then
            return p
        end
    end
    
    return nil
end

local function getTargetPlayerName()
    if targetPlayer ~= "" then return targetPlayer end
    return targetPlayer
end

-- ======================================
-- UI
-- ======================================
TradeTab:Section({ Title = "Trade" })

TradeTab:Paragraph({
    Title = "Info",
    Desc = "Only 1 player can be input, and send/accept trade only works with the player name you input.",
})

TradeTab:Input({
    Title = "Target Player Name",
    Value = "",
    Placeholder = "PlayerName123",
    Callback = function(v)
        targetPlayer = v
    end,
})

TradeTab:Toggle({
    Title = "Send Trade",
    Desc = "Sends trade request to target player",
    Value = false,
    Callback = function(v)
        sendRunning = v
        if v then
            sendThread = task.spawn(function()
                while sendRunning do
                    local name = getTargetPlayerName()
                    local target = findPlayer(name)
                    if target then
                        pcall(function()
                            Remote:FireServer("TradeRequest", target)
                        end)
                        print("[Trade] Sent request to " .. target.Name)
                    else
                        print("[Trade] Player not found: '" .. name .. "'")
                    end
                    task.wait(0.5)
                end
            end)
        else
            if sendThread then task.cancel(sendThread) end
        end
    end,
})

TradeTab:Toggle({
    Title = "Accept Trade",
    Desc = "Accepts trade request from target player",
    Value = false,
    Callback = function(v)
        acceptRunning = v
        if v then
            acceptThread = task.spawn(function()
                while acceptRunning do
                    local name = getTargetPlayerName()
                    local target = findPlayer(name)
                    if target then
                        pcall(function()
                            Remote:FireServer("TradeAcceptRequest", target)
                        end)
                        print("[Trade] Accepted request from " .. target.Name)
                    else
                        print("[Trade] Player not found: '" .. name .. "'")
                    end
                    task.wait(1)
                end
            end)
        else
            if acceptThread then task.cancel(acceptThread) end
        end
    end,
})

TradeTab:Toggle({
    Title = "Accept And Confirm",
    Desc = "Accepts and confirms trade automatically",
    Value = false,
    Callback = function(v)
        confirmRunning = v
        if v then
            confirmThread = task.spawn(function()
                while confirmRunning do
                    while movePetRunning do
                        task.wait(0.5)
                    end
                    pcall(function()
                        Remote:FireServer("TradeAccept")
                    end)
                    task.wait(0.3)
                    pcall(function()
                        Remote:FireServer("TradeConfirm")
                    end)
                    task.wait(0.3)
                end
            end)
        else
            if confirmThread then task.cancel(confirmThread) end
        end
    end,
})

TradeTab:Section({ Title = "Auto Move Pet" })

TradeTab:Paragraph({
    Title = "Auto Move Pet",
    Desc = "Adds all pets from your inventory to the trade (12 max).",
})

TradeTab:Toggle({
    Title = "Auto Move Pet",
    Value = false,
    Callback = function(v)
        movePetRunning = v
        if v then
            movePetThread = task.spawn(function()
                while movePetRunning do
                    pcall(function()
                        Remote:FireServer("TradeAccept")
                    end)
                    task.wait(1)
                    
                    local data = LocalData:Get()
                    local added = 0
                    local petNames = {}
                    if data and data.Pets then
                        for _, pet in pairs(data.Pets) do
                            if not pet.Locked and added < 12 then
                                pcall(function()
                                    Remote:FireServer("TradeAddPet", pet.Id .. ":0")
                                end)
                                table.insert(petNames, pet.Name)
                                added = added + 1
                                task.wait(0.15)
                            end
                            if added >= 12 then break end
                        end
                    end
                    
                    if #petNames > 0 then
                        getgenv().ActivityStatus.current = "Auto moving pets to trade: " .. table.concat(petNames, ", ")
                        getgenv().ActivityStatus.trigger = true
                    end
                    
                    task.wait(0.5)
                    pcall(function()
                        Remote:FireServer("TradeConfirm")
                    end)
                    
                    task.wait(3)
                end
            end)
        else
            if movePetThread then task.cancel(movePetThread) end
        end
    end,
})

print("[Trade] Loaded!")
