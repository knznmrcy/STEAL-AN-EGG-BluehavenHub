-- =====================================================
-- 🥚 SMART STEAL HUB v3.0 (Rayfield UI)
-- Based on: Steal An Egg + Rayfield Interface Suite
-- =====================================================

-- ========== LOAD RAYFIELD ==========
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()

-- ========== SERVICES ==========
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ========== VARIABEL ==========
local Settings = {
    AutoSteal = false,
    SpeedBoost = false,
    SpeedValue = 50,
    SafeDistance = 40,
    CheckInterval = 1.5,
    CurrentState = "Idle"
}

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

-- ========== [1] FUNGSI SCAN ==========
local function scanGameStructure()
    local data = { Areas = {}, Guards = {}, Eggs = {}, Remotes = {}, Nests = {} }
    local objects = workspace:FindFirstChild("_OBJECTS")
    if not objects then return data end
    
    local areas = objects:FindFirstChild("Areas")
    if areas then
        for _, area in ipairs(areas:GetChildren()) do
            if area:IsA("Model") then
                local areaData = { Name = area.Name, Guards = {}, Eggs = {}, Nests = {} }
                for _, obj in ipairs(area:GetDescendants()) do
                    local name = obj.Name:lower()
                    if name:find("guard") then
                        table.insert(areaData.Guards, obj)
                        table.insert(data.Guards, obj)
                    elseif name:find("egg") then
                        table.insert(areaData.Eggs, obj)
                        table.insert(data.Eggs, obj)
                    elseif name:find("nest") then
                        table.insert(areaData.Nests, obj)
                        table.insert(data.Nests, obj)
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
                table.insert(data.Remotes, { Name = v.Name, Type = v.ClassName, Path = fullPath, Object = v })
            end
            if #v:GetChildren() > 0 then findRemotes(v, fullPath) end
        end
    end
    findRemotes(ReplicatedStorage)
    
    return data
end

-- ========== [2] FUNGSI UTILITY ==========
local function findNearestGuard(position)
    local gameData = scanGameStructure()
    local nearest, shortest = nil, math.huge
    for _, guard in ipairs(gameData.Guards) do
        local guardPos = guard:FindFirstChild("HumanoidRootPart")
        if guardPos then
            local dist = (position - guardPos.Position).Magnitude
            if dist < shortest then
                shortest = dist
                nearest = { Object = guard, Position = guardPos.Position, Distance = dist }
            end
        end
    end
    return nearest
end

local function findNearestEgg(position, avoidGuards)
    local gameData = scanGameStructure()
    local candidates = {}
    for _, egg in ipairs(gameData.Eggs) do
        local eggPos = egg:IsA("Model") and egg:FindFirstChild("HumanoidRootPart")
        if eggPos then eggPos = eggPos.Position
        elseif egg:IsA("Part") then eggPos = egg.Position
        else continue end
        
        local isSafe = true
        if avoidGuards then
            local nearestGuard = findNearestGuard(eggPos)
            if nearestGuard and nearestGuard.Distance < Settings.SafeDistance then isSafe = false end
        end
        if isSafe then
            table.insert(candidates, { Object = egg, Position = eggPos, Distance = (position - eggPos).Magnitude })
        end
    end
    table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
    return candidates[1]
end

local function moveTo(position, speed)
    speed = speed or 20
    local tween = TweenService:Create(hrp, TweenInfo.new((hrp.Position - position).Magnitude / speed, Enum.EasingStyle.Linear), { CFrame = CFrame.new(position) })
    tween:Play()
    return tween
end

-- ========== [3] AUTO STEAL ==========
local function stealEgg(eggData)
    if not eggData then return false end
    Settings.CurrentState = "Stealing"
    local tween = moveTo(eggData.Position, 25)
    tween.Completed:Wait()
    
    local gameData = scanGameStructure()
    for _, remote in ipairs(gameData.Remotes) do
        local name = remote.Name:lower()
        if name:find("steal") or name:find("collect") or name:find("grab") or name:find("take") then
            local ok = pcall(function()
                if remote.Type == "RemoteEvent" then remote.Object:FireServer(eggData.Object)
                elseif remote.Type == "RemoteFunction" then remote.Object:InvokeServer(eggData.Object) end
            end)
            if ok then return true end
        end
    end
    return false
end

local function autoStealLoop()
    while Settings.AutoSteal do
        Settings.CurrentState = "Scanning"
        local targetEgg = findNearestEgg(hrp.Position, true)
        if targetEgg then
            local guard = findNearestGuard(targetEgg.Position)
            if not guard or guard.Distance >= Settings.SafeDistance then
                if stealEgg(targetEgg) then
                    Settings.CurrentState = "Success"
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

-- ========== [4] RAYFIELD UI ==========
local Window = Rayfield:CreateWindow({
    Name = "🥚 Smart Steal Hub v3",
    LoadingTitle = "Smart Steal Hub",
    LoadingSubtitle = "by Kamu",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SmartStealHub",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- ===== TAB: MAIN =====
local MainTab = Window:CreateTab("🏠 Main", 4483362458)

MainTab:CreateSection("Auto Steal")
local AutoStealToggle = MainTab:CreateToggle({
    Name = "🥚 Auto Steal",
    CurrentValue = false,
    Flag = "AutoSteal",
    Callback = function(Value)
        Settings.AutoSteal = Value
        if Value then
            Rayfield:Notify({
                Title = "Auto Steal",
                Content = "Started searching for eggs!",
                Duration = 3
            })
            coroutine.wrap(autoStealLoop)()
        else
            Rayfield:Notify({
                Title = "Auto Steal",
                Content = "Stopped!",
                Duration = 2
            })
            Settings.CurrentState = "Idle"
        end
    end
})

MainTab:CreateSection("Speed")
local SpeedToggle = MainTab:CreateToggle({
    Name = "💨 Speed Boost",
    CurrentValue = false,
    Flag = "SpeedBoost",
    Callback = function(Value)
        Settings.SpeedBoost = Value
        if Value then
            humanoid.WalkSpeed = Settings.SpeedValue
            Rayfield:Notify({
                Title = "Speed Boost",
                Content = "Speed set to " .. Settings.SpeedValue,
                Duration = 2
            })
        else
            humanoid.WalkSpeed = 16
        end
    end
})

local SpeedSlider = MainTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 100},
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

MainTab:CreateSection("Settings")
local SafeSlider = MainTab:CreateSlider({
    Name = "Safe Distance from Guard",
    Range = {10, 80},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = 40,
    Flag = "SafeDistance",
    Callback = function(Value)
        Settings.SafeDistance = Value
    end
})

-- ===== TAB: INFO =====
local InfoTab = Window:CreateTab("📊 Info", 4483362458)

InfoTab:CreateSection("Game Structure")
local ScanButton = InfoTab:CreateButton({
    Name = "🔍 Scan Game Structure",
    Callback = function()
        local data = scanGameStructure()
        Rayfield:Notify({
            Title = "Scan Complete",
            Content = string.format("Areas: %d | Eggs: %d | Guards: %d | Remotes: %d",
                #data.Areas, #data.Eggs, #data.Guards, #data.Remotes),
            Duration = 5
        })
        print("📊 Game Structure:")
        for _, area in ipairs(data.Areas) do
            print(string.format("  📁 %s: %d eggs, %d guards", area.Name, #area.Eggs, #area.Guards))
        end
        print("📡 Remotes:")
        for _, remote in ipairs(data.Remotes) do
            print(string.format("  🔴 %s: %s", remote.Type, remote.Path))
        end
    end
})

InfoTab:CreateSection("Status")
local StatusLabel = InfoTab:CreateLabel("Status: Idle")

-- ===== TAB: TELEPORT =====
local TeleportTab = Window:CreateTab("🚀 Teleport", 4483362458)

TeleportTab:CreateSection("Teleport to Areas")
local function teleportTo(areaName)
    local objects = workspace:FindFirstChild("_OBJECTS")
    if objects then
        local areas = objects:FindFirstChild("Areas")
        if areas then
            for _, area in ipairs(areas:GetChildren()) do
                if area.Name:lower():find(areaName:lower()) then
                    local hrp = area:FindFirstChild("HumanoidRootPart") or area:FindFirstChildWhichIsA("Part")
                    if hrp then
                        moveTo(hrp.Position, 50)
                        Rayfield:Notify({
                            Title = "Teleport",
                            Content = "Teleported to " .. area.Name,
                            Duration = 2
                        })
                        return
                    end
                end
            end
        end
    end
    Rayfield:Notify({
        Title = "Teleport",
        Content = "Area not found!",
        Duration = 2
    })
end

TeleportTab:CreateButton({
    Name = "🌲 Forest",
    Callback = function() teleportTo("Forest") end
})

TeleportTab:CreateButton({
    Name = "❄️ Winter",
    Callback = function() teleportTo("Winter") end
})

TeleportTab:CreateButton({
    Name = "🌵 Desert",
    Callback = function() teleportTo("Desert") end
})

TeleportTab:CreateButton({
    Name = "🌋 Volcano",
    Callback = function() teleportTo("Volcano") end
})

-- ========== [5] STATUS UPDATE ==========
coroutine.wrap(function()
    while true do
        if StatusLabel then
            local icons = {
                Idle = "⏹", Scanning = "🔍", Stealing = "🥚",
                Returning = "🏃", Waiting = "⏳", Searching = "🔎",
                Success = "✅", Failed = "❌"
            }
            StatusLabel:Set("Status: " .. (icons[Settings.CurrentState] or "🔄") .. " " .. Settings.CurrentState)
        end
        task.wait(1)
    end
end)()

-- ========== [6] NOTIF START ==========
Rayfield:Notify({
    Title = "🥚 Smart Steal Hub",
    Content = "Loaded successfully! Press K to toggle UI",
    Duration = 5
})

print("✅ Smart Steal Hub with Rayfield UI loaded!")
print("📌 Press K to toggle UI")
