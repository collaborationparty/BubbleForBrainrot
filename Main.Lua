-- ======================================
-- RENOA HUB | MAIN LOADER (WINDUI VERSION)
-- ======================================

-- ANTI AFK
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- GLOBAL SAVE/LOAD SYSTEM
local HttpService = game:GetService("HttpService")

function saveHubSettings()
    pcall(function()
        writefile("renoa_hub_settings.json", HttpService:JSONEncode(getgenv().HubSettings))
    end)
end

function loadHubSettings()
    local ok, data = pcall(function()
        return readfile("renoa_hub_settings.json")
    end)
    if ok and data then
        getgenv().HubSettings = HttpService:JSONDecode(data)
    else
        getgenv().HubSettings = {}
    end
end

loadHubSettings()

-- LOAD WINDUI
print("[Hub] Loading WindUI...")

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Renoa Hub",
    Icon = "door-open",
    Author = "Bubblegum Simulator Infinity",
    Folder = "RenoaHub",
    Size = UDim2.fromOffset(420, 320),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 160,
    HasOutline = true,
    User = {
        Enabled = true,
        Anonymous = false,
    },
})

Window:EditOpenButton({
    Title = "Renoa Hub",
    Icon = "monitor",
    CornerRadius = UDim.new(0, 16),
    StrokeThickness = 2,
    Color = ColorSequence.new(Color3.fromHex("8B00FF"), Color3.fromHex("B84DFF")),
    OnlyMobile = false,
})

getgenv().Window = Window
getgenv().WindUI = WindUI

-- ACTIVITY STATUS SYSTEM
if not getgenv().ActivityStatus then
    getgenv().ActivityStatus = {
        current = "Idle",
        trigger = false,
    }
end

-- TAB LOADER
local BASE_URL = "https://raw.githubusercontent.com/collaborationparty/BubbleForBrainrot/refs/heads/main/"

local function loadTab(fileName, name)
    local ok, err = pcall(function()
        loadstring(game:HttpGet(BASE_URL .. fileName))()
    end)
    
    if ok then
        print("[Hub] ✅ " .. name)
        return true
    else
        warn("[Hub] ❌ Failed: " .. name .. " - " .. tostring(err))
        return false
    end
end

-- LOAD TABS SEQUENTIALLY
task.spawn(function()
    loadTab("Info.Lua", "Info")
    task.wait(0.3)
    
    loadTab("ActivityInfo.Lua", "Activity Info")
    task.wait(0.3)
    
    loadTab("Webhook.Lua", "Webhook")
    task.wait(0.3)
    
    loadTab("Auto.Lua", "Auto")
    task.wait(0.3)
    
    loadTab("Eggs.Lua", "Eggs")
    task.wait(0.3)
    
    loadTab("Rift.Lua", "Rift")
    task.wait(0.3)
    
    loadTab("Event.Lua", "Event")
    task.wait(0.3)
    
    loadTab("Enchant.Lua", "Enchant")
    task.wait(0.3)
    
    loadTab("Potion.Lua", "Potions")
    task.wait(0.3)
    
    loadTab("Pets.Lua", "Pets")
    task.wait(0.3)
    
    loadTab("Shrine.Lua", "Shrine")
    task.wait(0.3)
    
    loadTab("Quest.Lua", "Quest")
    task.wait(0.3)
    
    loadTab("Diceboard.Lua", "Dice Board")
    task.wait(0.3)
    
    loadTab("Trade.Lua", "Trade")
    task.wait(0.3)
    
    loadTab("Teleport.Lua", "Teleport")
    task.wait(0.3)
    
    loadTab("Other.Lua", "Other")
end)

print("[Hub] All tabs loading...")
