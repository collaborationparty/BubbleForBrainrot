-- ================================================
-- INFO TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer

local request = http_request or request or (syn and syn.request)

-- ======================================
-- WELCOME + SESSION TIMER
-- ======================================
local startTime = os.clock()

local welcomeParagraph = InfoTab:Paragraph({
    Title = "Hello " .. player.Name .. "! Welcome back",
    Desc = "Session: 00:00",
})

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local elapsed = os.clock() - startTime
            local minutes = math.floor(elapsed / 60)
            local seconds = math.floor(elapsed % 60)
            welcomeParagraph:SetDesc(string.format("Session: %02d:%02d", minutes, seconds))
        end)
    end
end)

-- ======================================
-- DISCORD
-- ======================================
InfoTab:Section({ Title = "Discord" })

InfoTab:Paragraph({
    Title = "Join our Discord community!",
    Desc = "discord.gg/GfjXmXkG4E",
})

InfoTab:Button({
    Title = "Copy Discord Invite",
    Desc = "Copies invite link to clipboard",
    Callback = function()
        pcall(function()
            setclipboard("https://discord.gg/GfjXmXkG4E")
        end)
        print("[Info] Discord invite copied!")
    end,
})

-- ======================================
-- DONATION
-- ======================================
InfoTab:Section({ Title = "Donation" })

InfoTab:Paragraph({
    Title = "Support Renoa Hub development!",
    Desc = "Donation links coming soon!",
})

InfoTab:Button({
    Title = "Copy Donation Link",
    Desc = "Coming soon",
    Callback = function()
        print("[Info] Donation link coming soon!")
    end,
})

-- ======================================
-- SUGGESTION
-- ======================================
InfoTab:Section({ Title = "Suggestion" })

InfoTab:Paragraph({
    Title = "Send your suggestion directly to us!",
    Desc = "We read every single message.",
})

InfoTab:Input({
    Title = "Your Suggestion",
    Value = "",
    Placeholder = "Type your suggestion here...",
    Callback = function(v)
        getgenv()._suggestionText = v
    end,
})

InfoTab:Button({
    Title = "Send Suggestion",
    Desc = "Sends your suggestion to the team",
    Callback = function()
        local message = getgenv()._suggestionText
        
        if not message or message == "" then
            print("[Info] Please type a suggestion first!")
            return
        end
        
        local webhookURL = "https://discord.com/api/webhooks/1369693785214423102/o8SwG_v7B0TB0HtmjbgJ-b3Pc50TzsuwqpucoChXhFA5hcGeM9EXYKKy4WkYE5Q5Qb7u"
        
        if not request then
            print("[Info] Cannot send right now!")
            return
        end
        
        pcall(function()
            request({
                Url = webhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({
                    embeds = {{
                        title = "💡 New Suggestion!",
                        description = message,
                        color = 0x8B00FF,
                        fields = {{
                            name = "From",
                            value = player.Name,
                            inline = true
                        }, {
                            name = "Game",
                            value = MarketplaceService:GetProductInfo(game.PlaceId).Name,
                            inline = true
                        }},
                        footer = {text = "Renoa Hub Suggestion * " .. os.date("%Y-%m-%d %H:%M:%S")}
                    }}
                })
            })
            print("[Info] ✅ Suggestion sent! Thank you!")
            getgenv()._suggestionText = ""
        end)
    end,
})

print("[Info] Loaded!")
