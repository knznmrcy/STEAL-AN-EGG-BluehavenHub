-- =====================================================
-- 🔵 BLUEHAVEN HUB v4.1 (Anti-Error Version)
-- Fix: "attempt to call a nil value" di Line 1
-- =====================================================

-- ========== CEK ENVIRONMENT ==========
local function checkEnvironment()
    -- Cek apakah game running
    if not game or not game:GetService then
        return false, "Game service not found"
    end
    
    -- Cek apakah player ada
    local Players = game:GetService("Players")
    if not Players then
        return false, "Players service not found"
    end
    
    local player = Players.LocalPlayer
    if not player then
        return false, "LocalPlayer not found"
    end
    
    return true, "OK"
end

local envOk, envMsg = checkEnvironment()
if not envOk then
    warn("⚠️ Environment error: " .. envMsg)
    return
end

-- ========== LOAD RAYFIELD (SAFE) ==========
local Rayfield = nil
local loadSuccess = false

-- Coba berbagai link
local rayfieldUrls = {
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua",
    "https://raw.githubusercontent.com/xshlex/Rayfield/master/source.lua",
    "https://pastebin.com/raw/rayfield_safe.lua", -- fallback
}

for _, url in ipairs(rayfieldUrls) do
    local success, result = pcall(function()
        local content = game:HttpGet(url)
        if content and #content > 100 then
            return loadstring(content)()
        end
        return nil
    end)
    
    if success and result then
        Rayfield = result
        loadSuccess = true
        break
    end
end

if not loadSuccess then
    -- Buat UI manual kalo Rayfield gak bisa load
    warn("⚠️ Rayfield failed to load, using fallback UI")
    -- Gua bakal pake UI custom kalo Rayfield gagal
    createFallbackUI()
    return
end

print("✅ Rayfield loaded!")

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

-- Wait for character
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- ========== VARIABEL ==========
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

local EggsData = {}
local ESPObjects = {}
local isRunning = false

-- ========== [1] SCAN FUNCTIONS ==========
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
    
    local objects = Workspace:FindFirstChild("_OBJECTS")
    if not objects then return data end
    
    local areas = objects:FindFirstChild("Areas")
    if areas then
        for _, area in ipairs(areas:GetChildren()) do
            if area:IsA("Model") then
                local areaData = { 
                    Name = area.Name, 
                    Guards = {}, 
                    Eggs = {}, 
                    Nests = {}
                }
                
                for _, obj in ipairs(area:GetDescendants()) do
                    local name = obj.Name:lower()
                    if name:find("guard") then
                        table.insert(areaData.Guards, obj)
                        table.insert(data.Guards, obj)
                    elseif name:find("egg") then
                        local rarity = "Common"
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
                    end
                end
                table.insert(data.Areas, areaData)
            end
        end
    end
    
    local function findRemotes(folder)
        if not folder then return end
        for _, v in ipairs(folder:GetChildren()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                table.insert(data.Remotes, { 
                    Name = v.Name, 
                    Type = v.ClassName, 
                    Object = v 
                })
            end
            if #v:GetChildren() > 0 then 
                findRemotes(v) 
            end
        end
    end
    findRemotes(ReplicatedStorage)
    
    return data
end

-- ========== [2] UTILITY FUNCTIONS ==========
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
                nearest = { Object = guard, Position = pos, Distance = dist }
            end
        end
    end
    return nearest
end

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
    
    if Settings.EggPriority == "Nearest" then
        table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
    elseif Settings.EggPriority == "Rarest" then
        table.sort(candidates, function(a, b) 
            return (RarityOrder[a.Rarity] or 0) > (RarityOrder[b.Rarity] or 0)
        end)
    end
    
    return candidates
end

local function moveTo(position, speed)
    speed = speed or 20
    if not hrp then return nil end
    local tween = TweenService:Create(hrp, TweenInfo.new(
        (hrp.Position - position).Magnitude / speed,
        Enum.EasingStyle.Linear
    ), { CFrame = CFrame.new(position) })
    tween:Play()
    return tween
end

local function teleportTo(position)
    if not hrp then return end
    hrp.CFrame = CFrame.new(position)
end

-- ========== [3] ESP SYSTEM ==========
local function clearESP()
    for _, highlight in pairs(ESPObjects) do
        pcall(function() highlight:Destroy() end)
    end
    ESPObjects = {}
end

local function updateESP()
    if not Settings.ESPEnabled then return end
    clearESP()
    
    local gameData = scanGameStructure()
    for _, egg in ipairs(gameData.Eggs) do
        pcall(function()
            local highlight = Instance.new("Highlight")
            highlight.Name = "BluehavenESP"
            highlight.Adornee = egg.Object
            highlight.FillColor = RarityColors[egg.Rarity] or Color3.fromRGB(255,255,255)
            highlight.FillTransparency = 0.5
            highlight.OutlineColor = Color3.fromRGB(255,255,255)
            highlight.OutlineTransparency = 0.2
            highlight.Parent = CoreGui
            table.insert(ESPObjects, highlight)
        end)
    end
end

-- ========== [4] AUTO STEAL ==========
local function stealEgg(eggData)
    if not eggData then return false end
    Settings.CurrentState = "Stealing"
    
    local tween = moveTo(eggData.Position, 25)
    if tween then tween.Completed:Wait() end
    
    local gameData = scanGameStructure()
    for _, remote in ipairs(gameData.Remotes) do
        local name = remote.Name:lower()
        if name:find("steal") or name:find("collect") or name:find("grab") or name:find("take") then
            local ok = pcall(function()
                if remote.Type == "RemoteEvent" then
                    remote.Object:FireServer(eggData.Object)
                elseif remote.Type == "RemoteFunction" then
                    remote.Object:InvokeServer(eggData.Object)
                end
            end)
            if ok then return true end
        end
    end
    return false
end

local function autoStealLoop()
    while Settings.AutoSteal do
        Settings.CurrentState = "Scanning"
        local eggs = findEggsByRarity(hrp.Position, Settings.AutoStealRarity, true)
        
        if #eggs > 0 then
            local targetEgg = eggs[1]
            local guard = findNearestGuard(targetEgg.Position)
            
            if not guard or guard.Distance >= Settings.SafeDistance then
                if stealEgg(targetEgg) then
                    Settings.CurrentState = "Success"
                    if Settings.AutoReturn then
                        Settings.CurrentState = "Returning"
                        local base = Workspace:FindFirstChild("Base") or Workspace:FindFirstChild("Spawn")
                        if base then
                            local basePos = base:FindFirstChild("HumanoidRootPart") or base:FindFirstChildWhichIsA("Part")
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
        local gameData = scanGameStructure()
        if #gameData.Nests > 0 then
            local nest = gameData.Nests[1]
            local pos = nest:IsA("Model") and nest:FindFirstChild("HumanoidRootPart")
            if pos then
                moveTo(pos.Position, 20)
                wait(1)
                for _, remote in ipairs(gameData.Remotes) do
                    if remote.Name:lower():find("hatch") or remote.Name:lower():find("incubate") then
                        pcall(function() remote.Object:FireServer(nest) end)
                        break
                    end
                end
            end
        end
        wait(5)
    end
end

-- ========== [6] ANTI AFK ==========
local function antiAFKLoop()
    while Settings.AntiAFK do
        if humanoid and hrp then
            humanoid:MoveTo(hrp.Position + Vector3.new(math.random(-1,1), 0, math.random(-1,1)))
        end
        wait(30)
    end
end

-- ========== [7] FALLBACK UI (Kalo Rayfield Gagal) ==========
function createFallbackUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BluehavenHub_Fallback"
    screenGui.Parent = CoreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 400)
    frame.Position = UDim2.new(0.5, -150, 0.5, -200)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    frame.BackgroundTransparency = 0.9
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Text = "🔵 Bluehaven Hub v4.1"
    title.TextColor3 = Color3.fromRGB(100, 200, 255)
    title.BackgroundTransparency = 1
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 30)
    status.Position = UDim2.new(0, 10, 0, 60)
    status.Text = "⚡ Rayfield not available"
    status.TextColor3 = Color3.fromRGB(255, 200, 100)
    status.BackgroundTransparency = 1
    status.TextScaled = true
    status.Parent = frame
    
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 80)
    info.Position = UDim2.new(0, 10, 0, 100)
    info.Text = "Using fallback UI\n\nPlease check:\n1. Internet connection\n2. Try re-execute"
    info.TextColor3 = Color3.fromRGB(200, 200, 200)
    info.BackgroundTransparency = 1
    info.TextSize = 14
    info.TextXAlignment = Enum.TextXAlignment.Center
    info.Parent = frame
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 200, 0, 40)
    btn.Position = UDim2.new(0.5, -100, 0, 300)
    btn.Text = "🔄 Reload"
    btn.BackgroundColor3 = Color3.fromRGB(60, 150, 200)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Parent = frame
    
    btn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        print("🔄 Reloading script...")
        -- Execute ulang
        loadstring(game:HttpGet("https://raw.githubusercontent.com/yourscript/bluehaven.lua"))()
    end)
end

-- ========== [8] CREATE RAYFIELD UI ==========
if Rayfield and loadSuccess then
    local Window = Rayfield:CreateWindow({
        Name = "🔵 Bluehaven Hub v4.1",
        LoadingTitle = "Bluehaven Hub",
        LoadingSubtitle = "Steal An Egg",
        Theme = "Amethyst",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "BluehavenHub",
            FileName = "Settings"
        },
        Discord = { Enabled = false },
        KeySystem = false
    })
    
    -- === MAIN TAB ===
    local MainTab = Window:CreateTab("🏠 Main", 4483362458)
    
    MainTab:CreateSection("Auto Steal")
    MainTab:CreateToggle({
        Name = "🥚 Auto Steal",
        CurrentValue = false,
        Flag = "AutoSteal",
        Callback = function(Value)
            Settings.AutoSteal = Value
            if Value then
                coroutine.wrap(autoStealLoop)()
                Rayfield:Notify({ Title = "Bluehaven Hub", Content = "🔍 Auto Steal started!", Duration = 3 })
            else
                Settings.CurrentState = "Idle"
                Rayfield:Notify({ Title = "Bluehaven Hub", Content = "⏹ Auto Steal stopped", Duration = 2 })
            end
        end
    })
    
    MainTab:CreateDropdown({
        Name = "🎯 Egg Rarity",
        Options = {"Any", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Bloom", "SpiritBloom"},
        CurrentOption = "Any",
        Flag = "EggRarity",
        Callback = function(Option)
            Settings.AutoStealRarity = Option
        end
    })
    
    MainTab:CreateDropdown({
        Name = "📊 Egg Priority",
        Options = {"Nearest", "Rarest"},
        CurrentOption = "Nearest",
        Flag = "EggPriority",
        Callback = function(Option)
            Settings.EggPriority = Option
        end
    })
    
    MainTab:CreateSection("Auto Features")
    MainTab:CreateToggle({
        Name = "🏃 Auto Return",
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
            end
        end
    })
    
    -- === SPEED TAB ===
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
            end
        end
    })
    
    SpeedTab:CreateButton({
        Name = "🏠 Teleport to Base",
        Callback = function()
            local base = Workspace:FindFirstChild("Base") or Workspace:FindFirstChild("Spawn")
            if base then
                local basePos = base:FindFirstChild("HumanoidRootPart") or base:FindFirstChildWhichIsA("Part")
                if basePos then
                    teleportTo(basePos.Position)
                end
            end
        end
    })
    
    -- === AREAS TAB ===
    local AreasTab = Window:CreateTab("🗺️ Areas", 4483362458)
    
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
                            return
                        end
                    end
                end
            end
        end
    end
    
    AreasTab:CreateSection("Teleport to Area")
    local areaNames = {"Forest", "Winter", "Desert", "Volcano", "Cherry Blossom", "Beach"}
    for _, name in ipairs(areaNames) do
        AreasTab:CreateButton({
            Name = "🗺️ " .. name,
            Callback = function() teleportToArea(name) end
        })
    end
    
    -- === INFO TAB ===
    local InfoTab = Window:CreateTab("👁️ Info", 4483362458)
    
    InfoTab:CreateSection("ESP")
    InfoTab:CreateToggle({
        Name = "🔮 ESP (Highlight Eggs)",
        CurrentValue = false,
        Flag = "ESP",
        Callback = function(Value)
            Settings.ESPEnabled = Value
            if Value then
                updateESP()
            else
                clearESP()
            end
        end
    })
    
    InfoTab:CreateSection("Game Info")
    InfoTab:CreateButton({
        Name = "📊 Scan Game",
        Callback = function()
            local data = scanGameStructure()
            Rayfield:Notify({
                Title = "Scan Complete",
                Content = string.format("Eggs: %d | Guards: %d | Areas: %d",
                    #data.Eggs, #data.Guards, #data.Areas),
                Duration = 4
            })
            print("📊 Game Data:", #data.Eggs, "eggs,", #data.Guards, "guards")
            for _, area in ipairs(data.Areas) do
                print("  - " .. area.Name .. ": " .. #area.Eggs .. " eggs")
            end
        end
    })
    
    InfoTab:CreateSection("Status")
    local StatusLabel = InfoTab:CreateLabel("Status: Idle")
    
    -- === SETTINGS TAB ===
    local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)
    
    SettingsTab:CreateSection("Combat Settings")
    SettingsTab:CreateSlider({
        Name = "🛡️ Safe Distance",
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
    
    SettingsTab:CreateSection("Hub Control")
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
    
    -- === STATUS UPDATE ===
    coroutine.wrap(function()
        while true do
            pcall(function()
                if StatusLabel then
                    local icons = {
                        Idle = "⏹", Scanning = "🔍", Stealing = "🥚",
                        Returning = "🏃", Waiting = "⏳", Searching = "🔎",
                        Success = "✅", Failed = "❌"
                    }
                    StatusLabel:Set("Status: " .. (icons[Settings.CurrentState] or "🔄") .. " " .. Settings.CurrentState)
                end
            end)
            task.wait(1)
        end
    end)()
    
    -- === KEYBIND ===
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.K then
            local frame = Window:GetFrame()
            if frame then
                frame.Visible = not frame.Visible
            end
        end
        if input.KeyCode == Enum.KeyCode.F12 then
            local flags = Rayfield:GetFlags()
            if flags.AutoSteal ~= nil then
                flags.AutoSteal = not flags.AutoSteal
            end
        end
    end)
    
    Rayfield:Notify({
        Title = "🔵 Bluehaven Hub v4.1",
        Content = "Loaded! Press K to toggle UI",
        Duration = 5
    })
    
    print("🔵 Bluehaven Hub v4.1 loaded successfully!")
end
