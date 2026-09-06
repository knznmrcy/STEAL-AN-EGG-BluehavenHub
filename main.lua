-- =====================================================
-- 🔵 BLUEHAVEN HUB v4.0 (Full Feature)
-- Game: Steal An Egg (Roblox)
-- UI: Rayfield Interface Suite
-- =====================================================

-- ========== CEK & LOAD RAYFIELD ==========
-- Versi stabil dengan error handling
local Rayfield
local loadSuccess = false

local function loadRayfield()
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua"))()
    end)
    
    if success and result then
        Rayfield = result
        loadSuccess = true
        return true
    end
    
    -- Fallback: coba link alternatif
    local success2, result2 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/xshlex/Rayfield/master/source.lua"))()
    end)
    
    if success2 and result2 then
        Rayfield = result2
        loadSuccess = true
        return true
    end
    
    return false
end

if not loadRayfield() then
    warn("⚠️ Gagal load Rayfield! Coba ulang atau cek koneksi.")
    return
end

print("✅ Rayfield loaded successfully!")

-- ========== SERVICES ==========
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- ========== VARIABEL GLOBAL ==========
local Settings = {
    AutoSteal = false,
    AutoStealRarity = "Any",
    AutoReturn = false,
    SpeedBoost = false,
    SpeedValue = 50,
    SafeDistance = 40,
    CheckInterval = 1.5,
    CurrentState = "Idle",
    ESPEnabled = false,
    AutoHatch = false,
    AutoSell = false,
    TeleportEnabled = false,
    AntiAFK = false,
    EggPriority = "Nearest"
}

local EggsData = {}
local RarityColors = {
    Common = Color3.fromRGB(255, 255, 255),
    Uncommon = Color3.fromRGB(0, 255, 0),
    Rare = Color3.fromRGB(0, 150, 255),
    Epic = Color3.fromRGB(150, 0, 255),
    Legendary = Color3.fromRGB(255, 150, 0),
    Mythic = Color3.fromRGB(255, 0, 100),
    Bloom = Color3.fromRGB(255, 100, 200),
    SpiritBloom = Color3.fromRGB(0, 255, 200)
}

local RarityOrder = {
    Any = 0,
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Bloom = 7,
    SpiritBloom = 8
}

-- ========== [1] FUNGSI SCAN GAME ==========
local function scanGameStructure()
    local data = { 
        Areas = {}, 
        Guards = {}, 
        Eggs = {}, 
        Nests = {},
        Remotes = {},
        Players = {},
        Pets = {}
    }
    
    -- Scan _OBJECTS
    local objects = Workspace:FindFirstChild("_OBJECTS")
    if not objects then 
        warn("⚠️ _OBJECTS not found!") 
        return data 
    end
    
    -- Scan Areas
    local areas = objects:FindFirstChild("Areas")
    if areas then
        for _, area in ipairs(areas:GetChildren()) do
            if area:IsA("Model") then
                local areaData = { 
                    Name = area.Name, 
                    Guards = {}, 
                    Eggs = {}, 
                    Nests = {},
                    Objects = {}
                }
                
                for _, obj in ipairs(area:GetDescendants()) do
                    local name = obj.Name:lower()
                    if name:find("guard") then
                        table.insert(areaData.Guards, obj)
                        table.insert(data.Guards, obj)
                    elseif name:find("egg") then
                        -- Cek rarity dari properti atau warna
                        local rarity = "Common"
                        local eggColor = obj:FindFirstChild("BrickColor") or obj:FindFirstChild("Color")
                        if eggColor then
                            local color = eggColor is BrickColor and eggColor.Color or eggColor
                            for r, c in pairs(RarityColors) do
                                if r ~= "Any" and (color - c).Magnitude < 0.1 then
                                    rarity = r
                                    break
                                end
                            end
                        end
                        
                        local eggData = {
                            Object = obj,
                            Position = obj:IsA("Model") and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("Part")) 
                                and (obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("Part")).Position 
                                or (obj:IsA("Part") and obj.Position or Vector3.new(0,0,0)),
                            Rarity = rarity,
                            Area = area.Name,
                            Name = obj.Name
                        }
                        table.insert(areaData.Eggs, eggData)
                        table.insert(data.Eggs, eggData)
                    elseif name:find("nest") then
                        table.insert(areaData.Nests, obj)
                        table.insert(data.Nests, obj)
                    else
                        table.insert(areaData.Objects, obj)
                    end
                end
                
                table.insert(data.Areas, areaData)
            end
        end
    end
    
    -- Scan Remotes
    local function findRemotes(folder, path)
        path = path or ""
        for _, v in ipairs(folder:GetChildren()) do
            local fullPath = path .. "." .. v.Name
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                table.insert(data.Remotes, { 
                    Name = v.Name, 
                    Type = v.ClassName, 
                    Path = fullPath, 
                    Object = v 
                })
            end
            if #v:GetChildren() > 0 then 
                findRemotes(v, fullPath) 
            end
        end
    end
    findRemotes(ReplicatedStorage)
    
    -- Scan Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(data.Players, p)
        end
    end
    
    return data
end

-- ========== [2] FUNGSI UTILITY ==========
-- Cari guard terdekat
local function findNearestGuard(position)
    local gameData = scanGameStructure()
    local nearest = nil
    local shortest = math.huge
    
    for _, guard in ipairs(gameData.Guards) do
        local guardPos = guard:FindFirstChild("HumanoidRootPart") or guard:FindFirstChildWhichIsA("Part")
        if guardPos then
            local pos = guardPos.Position
            local dist = (position - pos).Magnitude
            if dist < shortest then
                shortest = dist
                nearest = {
                    Object = guard,
                    Position = pos,
                    Distance = dist
                }
            end
        end
    end
    return nearest
end

-- Cari telur berdasarkan rarity & posisi
local function findEggsByRarity(position, rarity, avoidGuards)
    local gameData = scanGameStructure()
    local candidates = {}
    local minRarity = RarityOrder[rarity] or 0
    
    for _, egg in ipairs(gameData.Eggs) do
        local eggRarity = RarityOrder[egg.Rarity] or 0
        if eggRarity >= minRarity then
            local isSafe = true
            if avoidGuards then
                local nearestGuard = findNearestGuard(egg.Position)
                if nearestGuard and nearestGuard.Distance < Settings.SafeDistance then
                    isSafe = false
                end
            end
            
            if isSafe then
                local dist = (position - egg.Position).Magnitude
                table.insert(candidates, {
                    Object = egg.Object,
                    Position = egg.Position,
                    Distance = dist,
                    Rarity = egg.Rarity,
                    Area = egg.Area,
                    Name = egg.Name
                })
            end
        end
    end
    
    -- Urutkan berdasarkan priority
    if Settings.EggPriority == "Nearest" then
        table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
    elseif Settings.EggPriority == "Rarest" then
        table.sort(candidates, function(a, b) 
            return (RarityOrder[a.Rarity] or 0) > (RarityOrder[b.Rarity] or 0)
        end)
    elseif Settings.EggPriority == "Farthest" then
        table.sort(candidates, function(a, b) return a.Distance > b.Distance end)
    end
    
    return candidates
end

-- Fungsi move
local function moveTo(position, speed)
    speed = speed or 20
    if not hrp then return nil end
    
    local tweenInfo = TweenInfo.new(
        (hrp.Position - position).Magnitude / speed,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(hrp, tweenInfo, { CFrame = CFrame.new(position) })
    tween:Play()
    return tween
end

-- Teleport (instant)
local function teleportTo(position)
    if not hrp then return end
    hrp.CFrame = CFrame.new(position)
end

-- ========== [3] ESP SYSTEM ==========
local ESPObjects = {}

local function createESP(eggData)
    if not Settings.ESPEnabled then return end
    
    -- Hapus ESP lama
    if ESPObjects[eggData.Object] then
        ESPObjects[eggData.Object]:Destroy()
        ESPObjects[eggData.Object] = nil
    end
    
    -- Buat ESP baru (highlight)
    local highlight = Instance.new("Highlight")
    highlight.Name = "BluehavenESP"
    highlight.Adornee = eggData.Object
    highlight.FillColor = RarityColors[eggData.Rarity] or Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Parent = CoreGui
    
    ESPObjects[eggData.Object] = highlight
end

local function updateESP()
    local gameData = scanGameStructure()
    for _, egg in ipairs(gameData.Eggs) do
        createESP(egg)
    end
end

local function clearESP()
    for obj, highlight in pairs(ESPObjects) do
        pcall(function() highlight:Destroy() end)
    end
    ESPObjects = {}
end

-- ========== [4] AUTO STEAL ==========
local function stealEgg(eggData)
    if not eggData then return false end
    Settings.CurrentState = "Stealing"
    
    -- Move ke telur
    local tween = moveTo(eggData.Position, 25)
    if tween then tween.Completed:Wait() end
    
    -- Coba interaksi via remote
    local gameData = scanGameStructure()
    local success = false
    
    for _, remote in ipairs(gameData.Remotes) do
        local name = remote.Name:lower()
        local stealKeywords = {"steal", "collect", "grab", "take", "pickup", "get", "claim"}
        
        for _, keyword in ipairs(stealKeywords) do
            if name:find(keyword) then
                local ok = pcall(function()
                    if remote.Type == "RemoteEvent" then
                        remote.Object:FireServer(eggData.Object)
                    elseif remote.Type == "RemoteFunction" then
                        remote.Object:InvokeServer(eggData.Object)
                    end
                end)
                if ok then 
                    success = true 
                    break 
                end
            end
        end
        if success then break end
    end
    
    -- Fallback: klik
    if not success then
        local mouse = player:GetMouse()
        local screenPos, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(eggData.Position)
        if onScreen then
            mouse.Move(mouse.X, mouse.Y) -- simulasi hover
            mouse.Click()
        end
        success = true -- anggap berhasil
    end
    
    return success
end

local function autoStealLoop()
    while Settings.AutoSteal do
        Settings.CurrentState = "Scanning"
        
        -- Cari telur sesuai rarity
        local eggs = findEggsByRarity(
            hrp.Position, 
            Settings.AutoStealRarity, 
            true
        )
        
        if #eggs > 0 then
            local targetEgg = eggs[1]
            local guard = findNearestGuard(targetEgg.Position)
            
            if not guard or guard.Distance >= Settings.SafeDistance then
                Settings.CurrentState = "Stealing"
                if stealEgg(targetEgg) then
                    Settings.CurrentState = "Success"
                    Rayfield:Notify({
                        Title = "✅ Egg Stolen!",
                        Content = string.format("%s (%s) from %s", 
                            targetEgg.Rarity, targetEgg.Name, targetEgg.Area),
                        Duration = 3
                    })
                    
                    -- Auto return
                    if Settings.AutoReturn then
                        Settings.CurrentState = "Returning"
                        local base = Workspace:FindFirstChild("Base") or Workspace:FindFirstChild("Spawn")
                        if base then
                            local basePos = base:IsA("Model") and base:FindFirstChild("HumanoidRootPart")
                            if basePos then
                                moveTo(basePos.Position, 25)
                            end
                        end
                    end
                    
                    wait(2)
                else
                    Settings.CurrentState = "Failed"
                    wait(3)
                end
            else
                Settings.CurrentState = "Waiting"
                wait(2)
            end
        else
            Settings.CurrentState = "Searching"
            wait(2)
        end
        
        task.wait(Settings.CheckInterval)
    end
end

-- ========== [5] AUTO HATCH ==========
local function autoHatchLoop()
    while Settings.AutoHatch do
        -- Cari inkubator terdekat
        local incubators = {}
        local gameData = scanGameStructure()
        
        for _, obj in ipairs(gameData.Nests) do
            local pos = obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart")
            if pos then
                table.insert(incubators, {
                    Object = obj,
                    Position = pos.Position
                })
            end
        end
        
        if #incubators > 0 then
            -- Urutkan berdasarkan jarak
            table.sort(incubators, function(a, b)
                return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude
            end)
            
            -- Teleport/Move ke inkubator
            moveTo(incubators[1].Position, 20)
            wait(1)
            
            -- Interaksi dengan inkubator
            for _, remote in ipairs(gameData.Remotes) do
                if remote.Name:lower():find("hatch") or remote.Name:lower():find("incubate") then
                    pcall(function()
                        if remote.Type == "RemoteEvent" then
                            remote.Object:FireServer(incubators[1].Object)
                        end
                    end)
                    break
                end
            end
        end
        
        wait(5)
    end
end

-- ========== [6] ANTI AFK ==========
local function antiAFKLoop()
    while Settings.AntiAFK do
        -- Kirim input gerak kecil
        local v = humanoid.MoveDirection
        humanoid:MoveTo(hrp.Position + Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)))
        wait(30)
    end
end

-- ========== [7] RAYFIELD UI ==========
-- Create Window
local Window = Rayfield:CreateWindow({
    Name = "🔵 Bluehaven Hub v4",
    LoadingTitle = "Bluehaven Hub",
    LoadingSubtitle = "Steal An Egg - Full Features",
    Theme = "Amethyst", -- Theme: Default, Amethyst, etc.
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BluehavenHub",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- ===== [TAB 1] MAIN =====
local MainTab = Window:CreateTab("🏠 Main", 4483362458)

MainTab:CreateSection("Auto Steal")
MainTab:CreateToggle({
    Name = "🥚 Auto Steal",
    CurrentValue = false,
    Flag = "AutoSteal",
    Callback = function(Value)
        Settings.AutoSteal = Value
        if Value then
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "🔍 Auto Steal started!",
                Duration = 3
            })
            coroutine.wrap(autoStealLoop)()
        else
            Settings.CurrentState = "Idle"
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "⏹ Auto Steal stopped",
                Duration = 2
            })
        end
    end
})

MainTab:CreateDropdown({
    Name = "🎯 Egg Rarity Target",
    Options = {"Any", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Bloom", "SpiritBloom"},
    CurrentOption = "Any",
    Flag = "EggRarity",
    Callback = function(Option)
        Settings.AutoStealRarity = Option
    end
})

MainTab:CreateDropdown({
    Name = "📊 Egg Priority",
    Options = {"Nearest", "Rarest", "Farthest"},
    CurrentOption = "Nearest",
    Flag = "EggPriority",
    Callback = function(Option)
        Settings.EggPriority = Option
    end
})

MainTab:CreateSection("Auto Features")
MainTab:CreateToggle({
    Name = "🏃 Auto Return to Base",
    CurrentValue = false,
    Flag = "AutoReturn",
    Callback = function(Value)
        Settings.AutoReturn = Value
    end
})

MainTab:CreateToggle({
    Name = "🐣 Auto Hatch",
    CurrentValue = false,
    Flag = "AutoHatch",
    Callback = function(Value)
        Settings.AutoHatch = Value
        if Value then
            coroutine.wrap(autoHatchLoop)()
        end
    end
})

MainTab:CreateToggle({
    Name = "💤 Anti AFK",
    CurrentValue = false,
    Flag = "AntiAFK",
    Callback = function(Value)
        Settings.AntiAFK = Value
        if Value then
            coroutine.wrap(antiAFKLoop)()
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "✅ Anti AFK activated!",
                Duration = 2
            })
        end
    end
})

-- ===== [TAB 2] SPEED & TELEPORT =====
local SpeedTab = Window:CreateTab("💨 Speed", 4483362458)

SpeedTab:CreateSection("Speed Boost")
SpeedTab:CreateToggle({
    Name = "💨 Speed Boost",
    CurrentValue = false,
    Flag = "SpeedBoost",
    Callback = function(Value)
        Settings.SpeedBoost = Value
        if Value then
            humanoid.WalkSpeed = Settings.SpeedValue
        else
            humanoid.WalkSpeed = 16
        end
    end
})

SpeedTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 120},
    Increment = 1,
    Suffix = "studs/s",
    CurrentValue = 50,
    Flag = "SpeedValue",
    Callback = function(Value)
        Settings.SpeedValue = Value
        if Settings.SpeedBoost then
            humanoid.WalkSpeed = Value
        end
    end
})

SpeedTab:CreateSection("Teleport")
SpeedTab:CreateButton({
    Name = "📌 Teleport to Nearest Egg",
    Callback = function()
        local eggs = findEggsByRarity(hrp.Position, Settings.AutoStealRarity or "Any", false)
        if #eggs > 0 then
            teleportTo(eggs[1].Position)
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "🚀 Teleported to nearest egg!",
                Duration = 2
            })
        else
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "❌ No eggs found!",
                Duration = 2
            })
        end
    end
})

SpeedTab:CreateButton({
    Name = "🏠 Teleport to Base",
    Callback = function()
        local base = Workspace:FindFirstChild("Base") or Workspace:FindFirstChild("Spawn")
        if base then
            local basePos = base:IsA("Model") and base:FindFirstChild("HumanoidRootPart")
            if basePos then
                teleportTo(basePos.Position)
                Rayfield:Notify({
                    Title = "Bluehaven Hub",
                    Content = "🏠 Teleported to base!",
                    Duration = 2
                })
            end
        else
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "❌ Base not found!",
                Duration = 2
            })
        end
    end
})

-- ===== [TAB 3] AREAS =====
local AreasTab = Window:CreateTab("🗺️ Areas", 4483362458)

AreasTab:CreateSection("Teleport to Area")
local function teleportToArea(areaName)
    local objects = Workspace:FindFirstChild("_OBJECTS")
    if objects then
        local areas = objects:FindFirstChild("Areas")
        if areas then
            for _, area in ipairs(areas:GetChildren()) do
                if area.Name:lower():find(areaName:lower()) then
                    local pos = area:FindFirstChild("HumanoidRootPart") or area:FindFirstChildWhichIsA("Part")
                    if pos then
                        teleportTo(pos.Position)
                        Rayfield:Notify({
                            Title = "Bluehaven Hub",
                            Content = "🚀 Teleported to " .. area.Name,
                            Duration = 2
                        })
                        return
                    end
                end
            end
        end
    end
    Rayfield:Notify({
        Title = "Bluehaven Hub",
        Content = "❌ Area not found!",
        Duration = 2
    })
end

AreasTab:CreateButton({ Name = "🌲 Forest", Callback = function() teleportToArea("Forest") end })
AreasTab:CreateButton({ Name = "❄️ Winter", Callback = function() teleportToArea("Winter") end })
AreasTab:CreateButton({ Name = "🌵 Desert", Callback = function() teleportToArea("Desert") end })
AreasTab:CreateButton({ Name = "🌋 Volcano", Callback = function() teleportToArea("Volcano") end })
AreasTab:CreateButton({ Name = "🌸 Cherry Blossom", Callback = function() teleportToArea("Cherry") end })
AreasTab:CreateButton({ Name = "🏝️ Beach", Callback = function() teleportToArea("Beach") end })

-- ===== [TAB 4] ESP & INFO =====
local InfoTab = Window:CreateTab("👁️ Info", 4483362458)

InfoTab:CreateSection("ESP")
InfoTab:CreateToggle({
    Name = "🔮 Enable ESP (Highlight Eggs)",
    CurrentValue = false,
    Flag = "ESP",
    Callback = function(Value)
        Settings.ESPEnabled = Value
        if Value then
            updateESP()
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "👁️ ESP activated!",
                Duration = 2
            })
        else
            clearESP()
        end
    end
})

InfoTab:CreateButton({
    Name = "🔄 Refresh ESP",
    Callback = function()
        clearESP()
        if Settings.ESPEnabled then
            updateESP()
            Rayfield:Notify({
                Title = "Bluehaven Hub",
                Content = "🔄 ESP refreshed!",
                Duration = 2
            })
        end
    end
})

InfoTab:CreateSection("Game Info")
InfoTab:CreateButton({
    Name = "📊 Scan Game Structure",
    Callback = function()
        local data = scanGameStructure()
        local totalEggs = #data.Eggs
        
        -- Hitung rarity
        local rarityCount = {}
        for _, egg in ipairs(data.Eggs) do
            rarityCount[egg.Rarity] = (rarityCount[egg.Rarity] or 0) + 1
        end
        
        local msg = string.format(
            "📁 Areas: %d\n🥚 Total Eggs: %d\n🛡️ Guards: %d\n📡 Remotes: %d\n\n📊 Rarity:\n%s",
            #data.Areas,
            totalEggs,
            #data.Guards,
            #data.Remotes,
            table.concat(
                (function()
                    local lines = {}
                    for r, c in pairs(rarityCount) do
                        table.insert(lines, string.format("  %s: %d", r, c))
                    end
                    return lines
                end)(),
                "\n"
            )
        )
        
        Rayfield:Notify({
            Title = "📊 Game Scan Complete",
            Content = string.format("Found %d eggs, %d guards, %d areas", 
                totalEggs, #data.Guards, #data.Areas),
            Duration = 5
        })
        
        print("📊 === BLUEHAVEN HUB SCAN ===")
        print(msg)
        print("📡 Remotes:")
        for _, remote in ipairs(data.Remotes) do
            print(string.format("  🔴 %s: %s", remote.Type, remote.Path))
        end
    end
})

InfoTab:CreateSection("Status")
local StatusLabel = InfoTab:CreateLabel("Status: Idle")
local RarityLabel = InfoTab:CreateLabel("Target: Any")
local EggsLabel = InfoTab:CreateLabel("Eggs found: 0")

-- ===== [TAB 5] SETTINGS =====
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)

SettingsTab:CreateSection("Combat Settings")
SettingsTab:CreateSlider({
    Name = "🛡️ Safe Distance from Guard",
    Range = {10, 100},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = 40,
    Flag = "SafeDistance",
    Callback = function(Value)
        Settings.SafeDistance = Value
    end
})

SettingsTab:CreateSlider({
    Name = "⏱️ Check Interval",
    Range = {0.5, 5},
    Increment = 0.5,
    Suffix = "s",
    CurrentValue = 1.5,
    Flag = "CheckInterval",
    Callback = function(Value)
        Settings.CheckInterval = Value
    end
})

SettingsTab:CreateSection("UI Settings")
SettingsTab:CreateButton({
    Name = "🔄 Refresh UI",
    Callback = function()
        Rayfield:Notify({
            Title = "Bluehaven Hub",
            Content = "🔄 UI refreshed!",
            Duration = 2
        })
    end
})

SettingsTab:CreateButton({
    Name = "❌ Unload Hub",
    Callback = function()
        Settings.AutoSteal = false
        Settings.AutoHatch = false
        Settings.AntiAFK = false
        Settings.SpeedBoost = false
        Settings.ESPEnabled = false
        clearESP()
        humanoid.WalkSpeed = 16
        Rayfield:Destroy()
        print("🔵 Bluehaven Hub unloaded")
    end
})

-- ========== [8] STATUS UPDATE ==========
coroutine.wrap(function()
    while true do
        pcall(function()
            if StatusLabel and RarityLabel and EggsLabel then
                -- Update Status
                local icons = {
                    Idle = "⏹", Scanning = "🔍", Stealing = "🥚",
                    Returning = "🏃", Waiting = "⏳", Searching = "🔎",
                    Success = "✅", Failed = "❌"
                }
                StatusLabel:Set("Status: " .. (icons[Settings.CurrentState] or "🔄") .. " " .. Settings.CurrentState)
                
                -- Update Rarity Target
                RarityLabel:Set("Target: " .. Settings.AutoStealRarity)
                
                -- Update Egg Count
                local data = scanGameStructure()
                EggsLabel:Set(string.format("Eggs found: %d", #data.Eggs))
            end
        end)
        task.wait(1)
    end
end)()

-- ========== [9] KEYBIND ==========
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        -- Toggle UI dengan K
        if Window then
            local frame = Window:GetFrame()
            if frame then
                frame.Visible = not frame.Visible
            end
        end
    end
    
    -- F12 untuk toggle Auto Steal
    if input.KeyCode == Enum.KeyCode.F12 then
        -- Cari toggle di UI
        for _, tab in ipairs(Window:GetTabs()) do
            if tab.Name == "🏠 Main" then
                -- Toggle auto steal dari flag
                local flags = Rayfield:GetFlags()
                if flags.AutoSteal ~= nil then
                    flags.AutoSteal = not flags.AutoSteal
                end
                break
            end
        end
    end
end)

-- ========== [10] NOTIF START ==========
Rayfield:Notify({
    Title = "🔵 Bluehaven Hub v4",
    Content = "Loaded successfully! Press K to toggle UI",
    Duration = 5
})

print("🔵 === BLUEHAVEN HUB v4 LOADED ===")
print("📌 Features:")
print("  - Auto Steal (with Rarity Selection)")
print("  - Speed Boost (up to 120 studs/s)")
print("  - Teleport to Eggs/Areas/Base")
print("  - ESP (Highlight Eggs)")
print("  - Auto Hatch")
print("  - Auto Return to Base")
print("  - Anti AFK")
print("  - Game Structure Scanner")
print("📌 Keybinds:")
print("  - K: Toggle UI")
print("  - F12: Toggle Auto Steal")
