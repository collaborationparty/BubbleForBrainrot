-- ================================================
-- ACTIVITY INFO TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local ActivityTab = Window:Tab({ Title = "Activity Info", Icon = "activity" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local request = http_request or request or (syn and syn.request)

if not request then
    ActivityTab:Section({ Title = "Error" })
    ActivityTab:Paragraph({
        Title = "Webhook Not Supported",
        Desc = "Your executor doesn't support webhooks!",
    })
    return
end

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.activity then settings.activity = {} end
local activitySettings = settings.activity

-- ======================================
-- SETTINGS
-- ======================================
local activityWebhookURL = activitySettings.webhookURL or ""
local activityEnabled = activitySettings.enabled or false
local lastSent = ""

-- Initialize global activity tracker
if not getgenv().ActivityStatus then
    getgenv().ActivityStatus = {
        current = "Idle",
        trigger = false,
    }
end

-- ======================================
-- FUNCTIONS
-- ======================================
local function sendActivity(msg)
    if not activityEnabled then return end
    if activityWebhookURL == "" then return end
    if msg == lastSent then return end
    
    lastSent = msg
    
    pcall(function()
        request({
            Url = activityWebhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = "Activity Update",
                    description = "**" .. player.Name .. "**\n" .. msg,
                    color = 5814783,
                    footer = {text = "Renoa Hub * " .. os.date("%Y-%m-%d %H:%M:%S")}
                }}
            })
        })
    end)
end

-- Monitor global activity trigger
task.spawn(function()
    while true do
        task.wait(3)
        local status = getgenv().ActivityStatus
        if status.trigger and status.current ~= lastSent then
            sendActivity(status.current)
            status.trigger = false
        end
    end
end)

-- ======================================
-- UI
-- ======================================
ActivityTab:Section({ Title = "Activity Webhook" })

ActivityTab:Paragraph({
    Title = "How It Works",
    Desc = "Sends webhook when your character is actively doing something. Only sends when action is actually being performed, not on toggle.",
})

ActivityTab:Input({
    Title = "Activity Webhook URL",
    Value = activityWebhookURL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(v)
        activityWebhookURL = v
        activitySettings.webhookURL = v
        getgenv().HubSettings.activity = activitySettings
        saveHubSettings()
    end,
})

ActivityTab:Toggle({
    Title = "Turn On/Turn Off",
    Desc = "Enables/disables activity webhook notifications",
    Value = activityEnabled,
    Callback = function(v)
        activityEnabled = v
        lastSent = ""
        activitySettings.enabled = v
        getgenv().HubSettings.activity = activitySettings
        saveHubSettings()
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1)
    
    if activityEnabled then
        activityEnabled = true
        lastSent = ""
    end
end)

print("[Activity Info] Loaded!")
