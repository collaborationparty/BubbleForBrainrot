-- ================================================
-- PETS TAB (WINDUI VERSION)
-- ================================================
repeat task.wait() until getgenv().Window
local Window = getgenv().Window
local WindUI = getgenv().WindUI

local PetTab = Window:Tab({ Title = "Pets", Icon = "paw-print" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local RE = ReplicatedStorage.Shared.Framework.Network.Remote.RemoteEvent

local NetworkRemote = ReplicatedStorage:WaitForChild("Shared")
    :WaitForChild("Framework")
    :WaitForChild("Network")
    :WaitForChild("Remote")
    :WaitForChild("RemoteFunction")

-- ======================================
-- LOAD SAVED SETTINGS
-- ======================================
local settings = getgenv().HubSettings or {}
if not settings.pets then settings.pets = {} end
local petSettings = settings.pets

-- ======================================
-- DELETE FUNCTION (BULK)
-- ======================================
local function deletePet(petId, amount)
    pcall(function()
        RE:FireServer("DeletePet", petId, amount, false)
    end)
end

-- ======================================
-- TRUE SECRET DETECTION
-- ======================================
local function isTrueSecret(info)
    if not info then return false end
    if info.Rarity ~= "Secret" then return false end
    if info.Celestial then return false end
    if info.Infinity then return false end
    if info.Void then return false end
    return true
end

-- ======================================
-- AUTO DELETE T3 LEGENDARY
-- ======================================
local autoDeleteT3Enabled = petSettings.autoDeleteT3 or false
local autoDeleteT3Thread = nil

local TARGET_EGGS = {
    "Void Egg", "Neon Egg", "Lava Egg",
    "Vine Egg", "Atlantis Egg", "Classic Egg",
}

local function isT3Legendary(pet, info)
    if not info or not info.Egg then return false end
    if not table.find(TARGET_EGGS, info.Egg) then return false end
    if pet.Super then return false end
    if pet.Locked then return false end
    if not info.Rarity then return false end
    if not info.Rarity:find("Legendary") then return false end
    if info.Rarity:find("Super") then return false end
    return true
end

-- ======================================
-- AUTO DELETE BY RARITY
-- ======================================
local autoDeleteRarityEnabled = petSettings.autoDeleteRarity or false
local autoDeleteRarityThread = nil

local DELETE_RARITIES = {"Common", "Unique", "Rare", "Epic", "Legendary"}

local function shouldDeleteByRarity(pet, info)
    if not info or not info.Rarity then return false end
    if pet.Super then return false end
    if pet.Locked then return false end
    
    for _, rarity in ipairs(DELETE_RARITIES) do
        if info.Rarity == rarity then
            return true
        end
    end
    
    return false
end

-- ======================================
-- REBIRTH MACHINE
-- ======================================
local fuserActive = false
local loopThread = nil
local targetPetNamesString = ""
local selectedVariant = "Normal"

local fuseAllActive = false
local fuseAllThread = nil

local function isCorrectVariant(pet)
    if selectedVariant == "Shiny Mythic" then
        return (pet.Shiny and pet.Mythic)
    elseif selectedVariant == "Shiny" then
        return pet.Shiny and not pet.Mythic
    elseif selectedVariant == "Mythic" then
        return pet.Mythic and not pet.Shiny
    else
        return not pet.Shiny and not pet.Mythic
    end
end

local function getVariantPriority(pet)
    if pet.Shiny and pet.Mythic then return 4
    elseif pet.Mythic and not pet.Shiny then return 3
    elseif pet.Shiny and not pet.Mythic then return 2
    else return 1 end
end

local function fusionLoop()
    while fuserActive do
        task.wait(2.5)
        
        if targetPetNamesString == "" then continue end
        
        local targetNames = {}
        for chunk in string.gmatch(targetPetNamesString, "[^,]+") do
            local clean = string.lower(string.gsub(chunk, "^%s*(.-)%s*$", "%1"))
            if clean ~= "" then table.insert(targetNames, clean) end
        end
        
        local data = LocalData:Get()
        if not data or not data.Pets then continue end
        
        local matching = {}
        for _, pet in pairs(data.Pets) do
            if not pet.Locked then
                if isCorrectVariant(pet) then
                    local name = string.lower(pet.Name)
                    for _, t in ipairs(targetNames) do
                        if name:find(t) then
                            table.insert(matching, pet)
                            break
                        end
                    end
                end
            end
        end
        
        if #matching >= 5 then
            table.sort(matching, function(a, b)
                return getVariantPriority(a) < getVariantPriority(b)
            end)
            
            local payload = {}
            for i = 1, 5 do
                table.insert(payload, tostring(matching[i].Id))
            end
            
            pcall(function()
                NetworkRemote:InvokeServer("UseRebirthMachine", "RebirthMachine", payload)
            end)
            task.wait(1.5)
        end
    end
end

-- ======================================
-- UI - AUTO DELETE PET
-- ======================================
PetTab:Section({ Title = "Auto Delete Pet" })

PetTab:Paragraph({
    Title = "⚠️ Note",
    Desc = "First toggle only deletes T3 Legendary from perm egg THAT CAN be Super Legendary (Safe Tested many times 🔥)",
})

PetTab:Toggle({
    Title = "Auto Delete T3 Legendary",
    Desc = "Deletes all T3 Legendary pets in bulk",
    Value = autoDeleteT3Enabled,
    Callback = function(v)
        autoDeleteT3Enabled = v
        petSettings.autoDeleteT3 = v
        getgenv().HubSettings.pets = petSettings
        saveHubSettings()
        
        if v then
            autoDeleteT3Thread = task.spawn(function()
                while autoDeleteT3Enabled do
                    local data = LocalData:Get()
                    
                    if data and data.Pets then
                        for _, pet in pairs(data.Pets) do
                            if not autoDeleteT3Enabled then break end
                            
                            local info = Pets[pet.Name]
                            if isT3Legendary(pet, info) then
                                local amount = pet.Amount or 1
                                deletePet(pet.Id, amount)
                                task.wait(0.5)
                            end
                        end
                    end
                    
                    task.wait(10)
                end
            end)
        else
            if autoDeleteT3Thread then task.cancel(autoDeleteT3Thread) end
        end
    end,
})

PetTab:Toggle({
    Title = "Auto Delete Rarity",
    Desc = "Deletes Common, Unique, Rare, Epic, Legendary pets",
    Value = autoDeleteRarityEnabled,
    Callback = function(v)
        autoDeleteRarityEnabled = v
        petSettings.autoDeleteRarity = v
        getgenv().HubSettings.pets = petSettings
        saveHubSettings()
        
        if v then
            autoDeleteRarityThread = task.spawn(function()
                while autoDeleteRarityEnabled do
                    local data = LocalData:Get()
                    
                    if data and data.Pets then
                        for _, pet in pairs(data.Pets) do
                            if not autoDeleteRarityEnabled then break end
                            
                            local info = Pets[pet.Name]
                            if shouldDeleteByRarity(pet, info) then
                                local amount = pet.Amount or 1
                                deletePet(pet.Id, amount)
                                task.wait(0.5)
                            end
                        end
                    end
                    
                    task.wait(10)
                end
            end)
        else
            if autoDeleteRarityThread then task.cancel(autoDeleteRarityThread) end
        end
    end,
})

-- ======================================
-- UI - REBIRTH MACHINE
-- ======================================
PetTab:Section({ Title = "Rebirth Machine" })

PetTab:Input({
    Title = "Pet Names (comma separated)",
    Value = "",
    Placeholder = "doggy, cat, ufo",
    Callback = function(v)
        targetPetNamesString = v
    end,
})

PetTab:Dropdown({
    Title = "Variant",
    Values = {"Normal", "Shiny", "Mythic", "Shiny Mythic"},
    Value = "Normal",
    Callback = function(v)
        selectedVariant = v
    end,
})

PetTab:Toggle({
    Title = "Auto Rebirth Machine",
    Desc = "Uses the Rebirth Machine with specified pet names",
    Value = false,
    Callback = function(v)
        fuserActive = v
        if v then
            loopThread = task.spawn(fusionLoop)
        else
            fuserActive = false
            if loopThread then
                task.cancel(loopThread)
                loopThread = nil
            end
        end
    end,
})

-- ======================================
-- UI - REBIRTH MACHINE (ALL UNLOCKED)
-- ======================================
PetTab:Section({ Title = "Rebirth Machine (All Unlocked)" })

PetTab:Paragraph({
    Title = "⚠️ Warning",
    Desc = "Make sure to Lock all Valuable Pets before using this. Only uses TRUE Secret pets (NOT Celestial, Infinity, Void). XL pets are EXCLUDED.",
})

local trackerParagraph = PetTab:Paragraph({
    Title = "Last Used: None",
    Desc = "Waiting for first use...",
})

PetTab:Toggle({
    Title = "Auto Rebirth Machine (All Unlocked Pets)",
    Desc = "Uses all unlocked True Secret pets (grouped by variant)",
    Value = false,
    Callback = function(v)
        fuseAllActive = v
        if v then
            pcall(function() 
                trackerParagraph:SetTitle("Last Used: None")
                trackerParagraph:SetDesc("Waiting for first use...")
            end)
            
            fuseAllThread = task.spawn(function()
                local lastPrint = ""
                local wasActive = false
                while fuseAllActive do
                    task.wait(5)
                    
                    local data = LocalData:Get()
                    if not data or not data.Pets then
                        wasActive = false
                        continue
                    end
                    
                    local groups = {Normal = {}, Shiny = {}, Mythic = {}, ShinyMythic = {}}
                    for _, pet in pairs(data.Pets) do
                        if not pet.Locked and not pet.XL then
                            local info = Pets[pet.Name]
                            if isTrueSecret(info) then
                                if pet.Shiny and pet.Mythic then
                                    table.insert(groups.ShinyMythic, pet)
                                elseif pet.Shiny then
                                    table.insert(groups.Shiny, pet)
                                elseif pet.Mythic then
                                    table.insert(groups.Mythic, pet)
                                else
                                    table.insert(groups.Normal, pet)
                                end
                            end
                        end
                    end
                    
                    local selectedGroup = nil
                    if #groups.Normal >= 5 then selectedGroup = groups.Normal
                    elseif #groups.Shiny >= 5 then selectedGroup = groups.Shiny
                    elseif #groups.Mythic >= 5 then selectedGroup = groups.Mythic
                    elseif #groups.ShinyMythic >= 5 then selectedGroup = groups.ShinyMythic
                    end
                    
                    if selectedGroup then
                        local beforeCount = 0
                        for _, _ in pairs(data.Pets) do beforeCount = beforeCount + 1 end
                        
                        local payload = {}
                        local usedWithVariant = {}
                        for i = 1, 5 do
                            local pet = selectedGroup[i]
                            table.insert(payload, tostring(pet.Id))
                            local variant = "Normal"
                            if pet.Shiny and pet.Mythic then variant = "Shiny Mythic"
                            elseif pet.Shiny then variant = "Shiny"
                            elseif pet.Mythic then variant = "Mythic" end
                            table.insert(usedWithVariant, variant .. " " .. pet.Name)
                        end
                        
                        local text = table.concat(usedWithVariant, ", ")
                        
                        pcall(function() 
                            trackerParagraph:SetTitle("Last Used: " .. text)
                            trackerParagraph:SetDesc("Used 5 pets")
                        end)
                        
                        pcall(function()
                            NetworkRemote:InvokeServer("UseRebirthMachine", "RebirthMachine", payload)
                        end)
                        
                        task.wait(1.5)
                        
                        local data2 = LocalData:Get()
                        local afterCount = 0
                        if data2 and data2.Pets then
                            for _, _ in pairs(data2.Pets) do afterCount = afterCount + 1 end
                        end
                        
                        if afterCount < beforeCount then
                            if text ~= lastPrint or not wasActive then
                                getgenv().ActivityStatus.current = "Rebirth Machine used: " .. text
                                getgenv().ActivityStatus.trigger = true
                                wasActive = true
                                lastPrint = text
                            end
                        else
                            wasActive = false
                        end
                        
                        task.wait(10)
                    else
                        wasActive = false
                    end
                end
            end)
        else
            fuseAllActive = false
            if fuseAllThread then
                task.cancel(fuseAllThread)
                fuseAllThread = nil
            end
        end
    end,
})

-- ======================================
-- AUTO-START SAVED TOGGLES
-- ======================================
task.spawn(function()
    task.wait(1.5)
    
    -- ⚠️ DELIBERATELY NOT AUTO-STARTING DELETE TOGGLES
    -- Auto Delete T3 and Auto Delete Rarity are DESTRUCTIVE.
    -- If they auto-start on rejoin, you could lose pets before you realize they're on.
    -- User must manually toggle them each session.
    --
    -- If you WANT them to auto-start, uncomment the blocks below:
    --
    -- if petSettings.autoDeleteT3 then
    --     autoDeleteT3Enabled = true
    --     autoDeleteT3Thread = task.spawn(function()
    --         while autoDeleteT3Enabled do
    --             local data = LocalData:Get()
    --             if data and data.Pets then
    --                 for _, pet in pairs(data.Pets) do
    --                     if not autoDeleteT3Enabled then break end
    --                     local info = Pets[pet.Name]
    --                     if isT3Legendary(pet, info) then
    --                         local amount = pet.Amount or 1
    --                         deletePet(pet.Id, amount)
    --                         task.wait(0.5)
    --                     end
    --                 end
    --             end
    --             task.wait(10)
    --         end
    --     end)
    -- end
    --
    -- if petSettings.autoDeleteRarity then
    --     autoDeleteRarityEnabled = true
    --     autoDeleteRarityThread = task.spawn(function()
    --         while autoDeleteRarityEnabled do
    --             local data = LocalData:Get()
    --             if data and data.Pets then
    --                 for _, pet in pairs(data.Pets) do
    --                     if not autoDeleteRarityEnabled then break end
    --                     local info = Pets[pet.Name]
    --                     if shouldDeleteByRarity(pet, info) then
    --                         local amount = pet.Amount or 1
    --                         deletePet(pet.Id, amount)
    --                         task.wait(0.5)
    --                     end
    --                 end
    --             end
    --             task.wait(10)
    --         end
    --     end)
    -- end
    
    -- NOTE: Auto Rebirth Machine (both manual and All Unlocked) is NOT persisted.
    -- Their toggles use `Value = false` with no settings save, so they never auto-start.
    
    print("[Pets] Auto-started saved toggles!")
end)

print("[Pets] Loaded!")
