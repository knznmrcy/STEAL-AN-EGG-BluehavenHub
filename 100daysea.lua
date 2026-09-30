local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ENEMY_NAMES = {
    ["Buku Boku"]  = true, ["Buku Buku"]  = true, ["Buku Poku"]  = true,
    ["Buku Toku"]  = true, ["Buku1"]      = true, ["BukuBuku"]   = true,
    ["GhostPirate"]        = true, ["GhostPirateCaptain"] = true,
    ["GhostPirateGunner"]  = true, ["GhostBombardier"]    = true,
    ["GhostGalleon"]       = true,
    ["CorruptCrewman"]  = true, ["CorruptOfficer"] = true,
    ["GolemBoss"]   = true, ["MagmaGolem"] = true,
    ["YetiBoss"]    = true, ["KrakenCutscene"] = true,
    ["MeleeAlien"]  = true, ["RaygunAlien"] = true, ["SmallAlien"] = true,
    ["Shark"]   = true, ["Crab"]    = true, ["Boar"] = true,
    ["Seagull"] = true,
}

local FRIENDLY_NAMES = {
    ["Fisherman"] = true, ["Merchant"] = true, ["MerchantBoat"] = true,
    ["Greenbeard"] = true, ["Captain"] = true, ["Survivor"] = true,
    ["Penguin"] = true, ["MukuMuku"] = true, ["Muku"] = true,
    ["Cheer"] = true, ["Chill"] = true, ["Dance"] = true,
    ["Dance1"] = true, ["Dance2"] = true, ["Dance3"] = true,
    ["Laugh"] = true, ["Point"] = true, ["Wave"] = true,
    ["WalkAnim"] = true, ["GameEnding"] = true, ["PiratesShowUp"] = true,
    ["YouPart"] = true, ["StarterCharacter"] = true, ["Characters"] = true,
    ["Player2"] = true, ["Player3"] = true, ["Player4"] = true, ["Player5"] = true,
}

local CHEST_NAMES = {
    "Chest", "SmallChest_Survivor", "LargeChest_Survivor",
    "TreasureChest_01", "TreasureChest_02",
    "Fishermans Chest", "Warrior Chest", "Pirate Chest",
    "MagmaChest", "FrostChest", "AlienChest", "GhostChest",
    "LargeLogChest", "SmallLogChest", "QuestChest",
    "ModernChest_Large", "ModernSmallChest", "TreasureIslandChest",
    "Box",
}
local CHEST_SET = {}
for _, n in ipairs(CHEST_NAMES) do CHEST_SET[n] = true end

-- ✅ WINDUI UPDATED KE VERSI LO
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
))()

local Net, NetReady = nil, false

local function GetNet()
    if Net and NetReady then return Net end
    for _, desc in pairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("ModuleScript") and desc.Name == "Network" then
            local s, m = pcall(require, desc)
            if s then Net = m; NetReady = true; return Net end
        end
    end
    return nil
end

local function SafeFireServer(name, ...)
    local n = GetNet()
    if n and n.FireServer then n:FireServer(name, ...) end
end

local function SafeInvokeServer(name, ...)
    local n = GetNet()
    if n and n.InvokeServer then return n:InvokeServer(name, ...) end
    return nil
end

local function GetCharacter() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function GetHumanoid()
    local c = GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetHRP()
    local c = GetCharacter()
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end
local function Notify(title, content, duration)
    WindUI:Notify({ Title = title or "Exploit", Content = content or "", Duration = duration or 4 })
end

local State = {
    SpeedEnabled = false, SpeedValue = 16,
    FlyEnabled = false, FlySpeed = 80,
    NoclipEnabled = false, InfJumpEnabled = false,
    GodModeEnabled = false, InfAmmoEnabled = false,

    AutoFarmEnabled = false, AutoFarmRunning = false,
    AutoChestEnabled = false, AutoChestRunning = false,
    AutoEatEnabled = false, AutoEatRunning = false,
    AntiAFKEnabled = false,

    PlayerESPEnabled = false, ItemESPEnabled = false,
    FullbrightEnabled = false,

    SelectedClass = "Sailor", SelectedCrate = "Fishermans Chest",
    MassOpenCount = 10,
}

local function IsEnemy(model)
    if not model or not model.Parent then return false end
    local name = model.Name

    if ENEMY_NAMES[name] then return true end

    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            local cg = part.CollisionGroup
            if cg == "Creature" or cg == "Ghost" then return true end
        end
    end

    local parent = model.Parent
    if parent and (parent.Name == "CreatureContainer" or parent.Name == "Creatures") then
        if name == "Seagull_CLIENT" then return false end
        return true
    end

    return false
end

local function IsPlayerCharacter(model)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then return true end
    end
    return false
end

local function GetModelRoot(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")
end

local function FindMyRaft()
    local bonfire = Workspace:FindFirstChild("Bonfire", true)
    if bonfire then return bonfire end

    local crafted = Workspace:FindFirstChild("Crafted")
    if crafted then
        local first = crafted:FindFirstChildWhichIsA("Model")
        if first then return first end
    end

    local platforms = Workspace:FindFirstChild("Platforms")
    if platforms then
        local first = platforms:FindFirstChildWhichIsA("BasePart")
        if first then return first.Parent end
    end

    return nil
end

local function GetRaftPosition()
    local raft = FindMyRaft()
    if not raft then return nil end
    if raft:IsA("Model") then
        local root = raft.PrimaryPart or raft:FindFirstChildWhichIsA("BasePart")
        if root then return root.CFrame + Vector3.new(0, 5, 0) end
    elseif raft:IsA("BasePart") then
        return raft.CFrame + Vector3.new(0, 5, 0)
    end
    return nil
end

local FlyBody, FlyGyro

local function SetSpeed(speed)
    local hum = GetHumanoid()
    if hum then hum.WalkSpeed = speed end
end

local function StartFly()
    local hrp = GetHRP()
    if not hrp then return end
    FlyBody = Instance.new("BodyVelocity")
    FlyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    FlyBody.Velocity = Vector3.zero
    FlyBody.Parent = hrp
    FlyGyro = Instance.new("BodyGyro")
    FlyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    FlyGyro.P = 9e4
    FlyGyro.Parent = hrp
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = true end
end

local function StopFly()
    if FlyBody then FlyBody:Destroy(); FlyBody = nil end
    if FlyGyro then FlyGyro:Destroy(); FlyGyro = nil end
    local hum = GetHumanoid()
    if hum then hum.PlatformStand = false end
end

local function UpdateFly()
    if not State.FlyEnabled then return end
    local hrp = GetHRP()
    if not hrp or not FlyBody or not FlyGyro then return end
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.yAxis end
    if dir.Magnitude > 0 then dir = dir.Unit end
    FlyBody.Velocity = dir * State.FlySpeed
    FlyGyro.CFrame = Camera.CFrame
end

local function UpdateNoclip()
    if not State.NoclipEnabled then return end
    local c = GetCharacter()
    if not c then return end
    for _, p in pairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

UserInputService.JumpRequest:Connect(function()
    if State.InfJumpEnabled then
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local function UpdateGodMode()
    if not State.GodModeEnabled then return end
    local c = GetCharacter()
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = hum.MaxHealth end
    if c:GetAttribute("Dead") then c:SetAttribute("Dead", false) end
end

local antiIdleConn
local function StartAntiAFK()
    local vu = game:GetService("VirtualUser")
    antiIdleConn = LocalPlayer.Idled:Connect(function()
        vu:Button2Down(Vector2.zero, Camera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.zero, Camera.CFrame)
    end)
end
local function StopAntiAFK()
    if antiIdleConn then antiIdleConn:Disconnect(); antiIdleConn = nil end
end

local function TeleportTo(cf)
    local hrp = GetHRP()
    if hrp then hrp.CFrame = cf end
end

local function TeleportToPlayer(targetName)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Name == targetName or plr.DisplayName == targetName then
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                TeleportTo(plr.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
                Notify("Teleport", "Teleported to " .. plr.DisplayName)
                return
            end
        end
    end
    Notify("Teleport", "Player not found")
end

local espFolder = Instance.new("Folder", game.CoreGui)
espFolder.Name = "ESP_100Days"

local function ClearESP() espFolder:ClearAllChildren() end

local function CreateHighlight(parent, color, label)
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = Color3.new(1,1,1)
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0.3
    hl.Adornee = parent
    hl.Parent = espFolder
    if label then
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = parent:IsA("Model") and (parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")) or parent
        bb.Parent = espFolder
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.BackgroundTransparency = 1
        tl.TextColor3 = color
        tl.TextStrokeTransparency = 0.4
        tl.Text = label
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 14
        tl.Parent = bb
    end
    return hl
end

local function UpdateESP()
    ClearESP()
    if not State.PlayerESPEnabled and not State.ItemESPEnabled then return end

    if State.PlayerESPEnabled then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                CreateHighlight(plr.Character, Color3.fromRGB(255, 50, 50), plr.DisplayName)
            end
        end
    end

    if State.ItemESPEnabled then
        local chestsFolder = Workspace:FindFirstChild("Chests")
        if chestsFolder then
            for _, obj in pairs(chestsFolder:GetChildren()) do
                if obj:IsA("Model") then
                    CreateHighlight(obj, Color3.fromRGB(255, 215, 0), obj.Name)
                end
            end
        end

        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and IsEnemy(obj) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    CreateHighlight(obj, Color3.fromRGB(255, 0, 0), obj.Name)
                end
            end
        end

        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name == "Survivor" then
                CreateHighlight(obj, Color3.fromRGB(0, 255, 100), "Survivor")
            end
        end
    end
end

local origLighting = {}
local function EnableFullbright()
    origLighting.Ambient = Lighting.Ambient
    origLighting.Brightness = Lighting.Brightness
    origLighting.ClockTime = Lighting.ClockTime
    origLighting.FogEnd = Lighting.FogEnd
    origLighting.GlobalShadows = Lighting.GlobalShadows
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1e6
    Lighting.GlobalShadows = false
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then v.Density = 0 end
    end
end
local function DisableFullbright()
    for k, v in pairs(origLighting) do Lighting[k] = v end
end

local function AutoFarmLoop()
    State.AutoFarmRunning = true
    while State.AutoFarmEnabled do
        local hrp = GetHRP()
        if not hrp then task.wait(1); continue end

        local closest, closestDist = nil, math.huge
        for _, obj in pairs(Workspace:GetDescendants()) do
            if not State.AutoFarmEnabled then break end
            if obj:IsA("Humanoid") and obj.Health > 0 then
                local model = obj.Parent
                if model and not IsPlayerCharacter(model) and IsEnemy(model) then
                    local root = GetModelRoot(model)
                    if root then
                        local d = (root.Position - hrp.Position).Magnitude
                        if d < closestDist then
                            closestDist = d
                            closest = root
                        end
                    end
                end
            end
        end

        if closest and State.AutoFarmEnabled then
            if closestDist > 8 then
                TeleportTo(closest.CFrame + Vector3.new(0, 2, 0))
                task.wait(0.15)
            end
            local char = GetCharacter()
            if char then
                for _, tool in pairs(char:GetChildren()) do
                    if tool:IsA("Tool") then tool:Activate() end
                end
            end
        end
        task.wait(0.35)
    end
    State.AutoFarmRunning = false
end

local function AutoChestLoop()
    State.AutoChestRunning = true
    while State.AutoChestEnabled do
        local hrp = GetHRP()
        if not hrp then task.wait(1); continue end

        local bestChest, bestDist, bestPrompt = nil, math.huge, nil
        local chestsFolder = Workspace:FindFirstChild("Chests")
        local searchIn = chestsFolder and chestsFolder:GetChildren() or {}

        for _, obj in pairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and CHEST_SET[obj.Name] then
                table.insert(searchIn, obj)
            end
        end

        for _, obj in pairs(searchIn) do
            if not State.AutoChestEnabled then break end
            if obj:IsA("Model") and CHEST_SET[obj.Name] then
                local prompt = nil
                for _, d in pairs(obj:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        prompt = d; break
                    end
                end
                if prompt then
                    local root = GetModelRoot(obj) or obj:FindFirstChildWhichIsA("BasePart")
                    if root then
                        local d = (root.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestChest = root
                            bestPrompt = prompt
                        end
                    end
                end
            end
        end

        if bestChest and bestPrompt and State.AutoChestEnabled then
            TeleportTo(bestChest.CFrame + Vector3.new(0, 2, 0))
            task.wait(0.3)
            if State.AutoChestEnabled and bestPrompt and bestPrompt.Parent then
                fireproximityprompt(bestPrompt)
            end
            task.wait(0.6)
        else
            task.wait(1.5)
        end
    end
    State.AutoChestRunning = false
end

local function AutoEatLoop()
    State.AutoEatRunning = true
    local foodKeywords = {
        "chowder","fish","meat","potato","fruit","food",
        "pizza","coconut","banana","apple","steak","egg","berry",
    }
    while State.AutoEatEnabled do
        local hum = GetHumanoid()
        if hum and hum.Health < hum.MaxHealth * 0.7 then
            for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                if not State.AutoEatEnabled then break end
                local tName = tool.Name:lower()
                for _, kw in ipairs(foodKeywords) do
                    if tName:find(kw) then
                        hum:EquipTool(tool)
                        task.wait(0.1)
                        tool:Activate()
                        task.wait(0.3)
                        break
                    end
                end
            end
        end
        task.wait(2)
    end
    State.AutoEatRunning = false
end

RunService.Stepped:Connect(function()
    if State.SpeedEnabled then SetSpeed(State.SpeedValue) end
    if State.FlyEnabled then UpdateFly() end
    if State.NoclipEnabled then UpdateNoclip() end
    if State.GodModeEnabled then UpdateGodMode() end
end)

task.spawn(function()
    while true do
        if State.PlayerESPEnabled or State.ItemESPEnabled then
            UpdateESP()
        end
        task.wait(3)
    end
end)

-- ✅ WINDOW WINDUI — TIDAK ADA YANG DIUBAH
local Window = WindUI:CreateWindow({
    Title = "100 Days At Sea | Star Exploit v2",
    Icon = "anchor",
    Folder = "StarExploit_100Days",
    Size = UDim2.fromOffset(580, 460),
    OpenButton = {
        Title = "Star",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        Color = ColorSequence.new(Color3.fromHex("#00d4ff"), Color3.fromHex("#7b2fff")),
    },
    Topbar = { Height = 42, ButtonsType = "Mac" },
})

Window:Tag({ Title = "v2.0", Icon = "github", Color = Color3.fromHex("#1c1c1c"), Border = true })

local MainSection = Window:Section({ Title = "Main" })
local GameSection = Window:Section({ Title = "Game" })
local VisualsSection = Window:Section({ Title = "Visuals" })
local MiscSection = Window:Section({ Title = "Misc" })

local MovementTab = MainSection:Tab({ Title = "Movement", Icon = "zap", Border = true })

MovementTab:Toggle({
    Title = "Speed Hack",
    Desc = "Override WalkSpeed (no server check)",
    Value = false,
    Callback = function(v)
        State.SpeedEnabled = v
        if not v then SetSpeed(16) end
    end,
})
MovementTab:Space()
MovementTab:Slider({
    Title = "Walk Speed",
    Step = 1, Value = { Min = 16, Max = 500, Default = 100 },
    Callback = function(v) State.SpeedValue = v end,
})
MovementTab:Space()
MovementTab:Toggle({
    Title = "Fly",
    Desc = "BodyVelocity fly — WASD + Space/Ctrl",
    Value = false,
    Callback = function(v)
        State.FlyEnabled = v
        if v then StartFly() else StopFly() end
    end,
})
MovementTab:Space()
MovementTab:Slider({
    Title = "Fly Speed",
    Step = 5, Value = { Min = 10, Max = 500, Default = 80 },
    Callback = function(v) State.FlySpeed = v end,
})
MovementTab:Space()
MovementTab:Toggle({
    Title = "Noclip", Desc = "Walk through walls", Value = false,
    Callback = function(v) State.NoclipEnabled = v end,
})
MovementTab:Space()
MovementTab:Toggle({
    Title = "Infinite Jump", Desc = "Jump mid-air", Value = false,
    Callback = function(v) State.InfJumpEnabled = v end,
})

MovementTab:Space()

local function GetPlayerList()
    local t = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(t, p.Name) end
    end
    return t
end

MovementTab:Dropdown({
    Title = "Teleport to Player",
    Values = GetPlayerList(),
    Callback = function(v) TeleportToPlayer(v) end,
})

MovementTab:Space()

MovementTab:Button({
    Title = "Teleport to My Raft",
    Desc = "Finds your Bonfire and teleports you there",
    Icon = "home",
    Color = Color3.fromHex("#30ff6a"),
    Callback = function()
        local cf = GetRaftPosition()
        if cf then
            TeleportTo(cf)
            Notify("Teleport", "Teleported to your raft!")
        else
            Notify("Teleport", "Raft not found — are you in The Sea?")
        end
    end,
})

MovementTab:Space()

MovementTab:Button({
    Title = "Teleport to Lobby Spawn",
    Icon = "map-pin",
    Callback = function()
        local sp = Workspace:FindFirstChild("SpawnLocation")
        if sp then TeleportTo(sp.CFrame + Vector3.new(0, 5, 0)) end
        Notify("Teleport", "Teleported to spawn")
    end,
})

local CombatTab = MainSection:Tab({ Title = "Combat", Icon = "sword", Border = true })

CombatTab:Toggle({
    Title = "God Mode",
    Desc = "Keep health max + prevent Dead attribute",
    Value = false,
    Callback = function(v) State.GodModeEnabled = v end,
})
CombatTab:Space()
CombatTab:Toggle({
    Title = "Infinite Ammo",
    Desc = "Ammo tracked client-side — patches IntValues",
    Value = false,
    Callback = function(v)
        State.InfAmmoEnabled = v
        if v then
            task.spawn(function()
                while State.InfAmmoEnabled do
                    local c = GetCharacter()
                    if c then
                        for _, tool in pairs(c:GetChildren()) do
                            if tool:IsA("Tool") then
                                for _, d in pairs(tool:GetDescendants()) do
                                    if d:IsA("IntValue") and (d.Name == "Ammo" or d.Name == "CurrentAmmo") then
                                        d.Value = 999
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})
CombatTab:Space()
CombatTab:Button({
    Title = "Kill Aura (5s burst)",
    Desc = "Rapid-activates equipped tool for 5 seconds",
    Icon = "zap",
    Callback = function()
        task.spawn(function()
            for _ = 1, 50 do
                local c = GetCharacter()
                if c then
                    for _, t in pairs(c:GetChildren()) do
                        if t:IsA("Tool") then t:Activate() end
                    end
                end
                task.wait(0.1)
            end
        end)
        Notify("Combat", "Kill Aura active for 5s")
    end,
})

local ClassTab = GameSection:Tab({ Title = "Classes", Icon = "users", Border = true })

local AllClasses = {
    "Sailor","Medic","Survivor","Crewmate","Camper","Builderman","Chef",
    "Merchant","Adventurer","Harpooner","Olympian","Swordsman","Battle Buku",
    "Soldier","Cowboy","Zookeeper","Knight","Sharpshooter","Alien Warrior",
    "Millionaire","Treasure Hunter","Pirate","Hero","Battle Bunny",
    "Fire Mage","Raider","Ice Mage","Alien Overlord","Ancient Squid"
}

ClassTab:Dropdown({
    Title = "Select Class", Values = AllClasses, Value = "Sailor",
    Callback = function(v) State.SelectedClass = v end,
})
ClassTab:Space()
ClassTab:Button({
    Title = "Buy Selected Class", Icon = "shopping-cart", Color = Color3.fromHex("#30ff6a"),
    Callback = function()
        SafeFireServer("BuyClass", State.SelectedClass)
        Notify("Class", "Buy: " .. State.SelectedClass)
    end,
})
ClassTab:Space()
ClassTab:Button({
    Title = "Equip Selected Class", Icon = "shirt",
    Callback = function()
        SafeFireServer("EquipClass", State.SelectedClass)
        Notify("Class", "Equip: " .. State.SelectedClass)
    end,
})
ClassTab:Space()
ClassTab:Button({
    Title = "Skip Class Level", Icon = "arrow-up",
    Callback = function()
        SafeFireServer("SkipClassLevel", State.SelectedClass)
        Notify("Class", "Level skip: " .. State.SelectedClass)
    end,
})
ClassTab:Space()
ClassTab:Button({
    Title = "Buy ALL Classes", Icon = "layers", Color = Color3.fromHex("#ff9500"),
    Callback = function()
        task.spawn(function()
            for _, cls in ipairs(AllClasses) do
                SafeFireServer("BuyClass", cls); task.wait(0.15)
            end
            Notify("Class", "Bought all " .. #AllClasses .. " classes")
        end)
    end,
})
ClassTab:Space()
ClassTab:Button({
    Title = "Refresh Class Stock", Icon = "refresh-cw",
    Callback = function() SafeFireServer("RefreshClassStock"); Notify("Class", "Stock refreshed") end,
})
ClassTab:Space()
ClassTab:Button({
    Title = "Restock Classes", Icon = "package",
    Callback = function() SafeFireServer("RestockClasses"); Notify("Class", "Restocked") end,
})

local PetTab = GameSection:Tab({ Title = "Companions", Icon = "heart", Border = true })

local AllCrates = { "Fishermans Chest","Warrior Chest","Pirate Chest","Magma Chest","Ice Chest" }

PetTab:Dropdown({
    Title = "Select Crate", Values = AllCrates, Value = "Fishermans Chest",
    Callback = function(v) State.SelectedCrate = v end,
})
PetTab:Space()
PetTab:Button({
    Title = "Open Crate", Icon = "gift", Color = Color3.fromHex("#ff30c4"),
    Callback = function()
        local r = SafeInvokeServer("BuyCrate", State.SelectedCrate)
        Notify("Crate", "Result: " .. tostring(r))
    end,
})
PetTab:Space()
PetTab:Button({
    Title = "Open via _G.BuyCrate", Icon = "box",
    Callback = function()
        if _G.BuyCrate then _G.BuyCrate(State.SelectedCrate); Notify("Crate", "Used _G.BuyCrate")
        else Notify("Crate", "_G.BuyCrate not available") end
    end,
})
PetTab:Space()
PetTab:Slider({
    Title = "Mass Open Count", Step = 1, Value = { Min = 1, Max = 100, Default = 10 },
    Callback = function(v) State.MassOpenCount = v end,
})
PetTab:Space()
PetTab:Button({
    Title = "Mass Open Crates", Icon = "layers", Color = Color3.fromHex("#ffd700"),
    Callback = function()
        task.spawn(function()
            for _ = 1, (State.MassOpenCount or 10) do
                SafeInvokeServer("BuyCrate", State.SelectedCrate); task.wait(0.2)
            end
            Notify("Crate", "Opened " .. (State.MassOpenCount or 10) .. "x")
        end)
    end,
})
PetTab:Space()
PetTab:Input({
    Title = "Pet ID", Placeholder = "Enter pet ID...",
    Callback = function(v) State.PetActionID = v end,
})
PetTab:Space()
PetTab:Button({
    Title = "Equip Pet", Icon = "check",
    Callback = function()
        if _G.PetAction then _G.PetAction("Equip", State.PetActionID)
        else SafeInvokeServer("PetAction", "Equip", State.PetActionID) end
        Notify("Pet", "Equip sent")
    end,
})
PetTab:Space()
PetTab:Button({
    Title = "Sell Pet", Icon = "trash",
    Callback = function()
        if _G.PetAction then _G.PetAction("Sell", State.PetActionID, 1)
        else SafeInvokeServer("PetAction", "Sell", State.PetActionID, 1) end
        Notify("Pet", "Sell sent")
    end,
})

local EconomyTab = GameSection:Tab({ Title = "Economy", Icon = "dollar-sign", Border = true })

local ShopItems = {
    "25 Pearls","100 Pearls","250 Pearls","1000 Pearls",
    "Starter Pack","Hero Bundle","Alien Bundle","Ice Mage Bundle",
    "Fire Mage Bundle","Raider Bundle","Battle Bunny Class",
    "Millionaire Bundle","Zookeeper Bundle",
}

EconomyTab:Dropdown({
    Title = "Shop Item", Values = ShopItems, Value = "25 Pearls",
    Callback = function(v) State.SelectedShopItem = v end,
})
EconomyTab:Space()
EconomyTab:Button({
    Title = "Buy Item", Icon = "shopping-bag", Color = Color3.fromHex("#30ff6a"),
    Callback = function()
        local r = SafeInvokeServer("Buy", State.SelectedShopItem or "25 Pearls", false)
        Notify("Shop", "Result: " .. tostring(r))
    end,
})
EconomyTab:Space()
EconomyTab:Input({
    Title = "Gift Target", Placeholder = "Username...",
    Callback = function(v) State.GiftTarget = v end,
})
EconomyTab:Space()
EconomyTab:Button({
    Title = "Gift Item", Icon = "gift", Color = Color3.fromHex("#ff30c4"),
    Callback = function()
        local r = SafeInvokeServer("Buy", State.SelectedShopItem or "25 Pearls", State.GiftTarget or "")
        Notify("Shop", "Gift result: " .. tostring(r))
    end,
})
EconomyTab:Space()
EconomyTab:Input({
    Title = "Redeem Code", Placeholder = "Promo code...",
    Callback = function(v) State.RedeemCode = v end,
})
EconomyTab:Space()
EconomyTab:Button({
    Title = "Redeem", Icon = "check-circle",
    Callback = function()
        local r = SafeInvokeServer("RedeemCode", State.RedeemCode or "")
        Notify("Code", "Result: " .. tostring(r))
    end,
})

local TaskTab = GameSection:Tab({ Title = "Tasks & Quests", Icon = "clipboard-list", Border = true })

TaskTab:Button({
    Title = "Complete Daily Tasks (Client)", Icon = "check", Color = Color3.fromHex("#30ff6a"),
    Callback = function()
        pcall(function()
            LocalPlayer:SetAttribute("DailyTaskProgress1", 1)
            LocalPlayer:SetAttribute("DailyTaskProgress2", 1)
            LocalPlayer:SetAttribute("DailyTaskProgress3", 1)
        end)
        Notify("Tasks", "Progress set to max")
    end,
})
TaskTab:Space()
TaskTab:Button({
    Title = "Claim All Badges", Icon = "award",
    Callback = function()
        task.spawn(function()
            local bMod = ReplicatedStorage:FindFirstChild("Modules")
                and ReplicatedStorage.Modules:FindFirstChild("Data")
                and ReplicatedStorage.Modules.Data:FindFirstChild("Badges")
            if bMod then
                local ok, data = pcall(require, bMod)
                if ok then
                    for _, info in pairs(data) do
                        pcall(function() SafeInvokeServer("ClaimBadge", info.ID) end)
                        task.wait(0.1)
                    end
                    Notify("Badges", "Claimed all badges")
                    return
                end
            end
            Notify("Badges", "Badge data not found")
        end)
    end,
})
TaskTab:Space()
TaskTab:Button({
    Title = "Show Reward", Icon = "star",
    Callback = function() SafeFireServer("ShowMeReward"); Notify("Reward", "Fired") end,
})

local LobbyTab = GameSection:Tab({ Title = "Lobby & Party", Icon = "map", Border = true })

LobbyTab:Section({
    Title = "Seeds: any number works. Default = os.time(). No predefined seed list.",
    TextSize = 13,
})
LobbyTab:Space()
LobbyTab:Slider({
    Title = "Party Size", Step = 1, Value = { Min = 1, Max = 20, Default = 1 },
    Callback = function(v) State.PartySize = v end,
})
LobbyTab:Space()
LobbyTab:Input({
    Title = "World Seed", Placeholder = "Custom seed number...",
    Callback = function(v) State.CustomSeed = tonumber(v) end,
})
LobbyTab:Space()
LobbyTab:Slider({
    Title = "Challenge Tier (0 = vanilla)", Step = 1, Value = { Min = 0, Max = 6, Default = 0 },
    Callback = function(v) State.ChallengeTier = v > 0 and v or nil end,
})
LobbyTab:Space()
LobbyTab:Button({
    Title = "Create Party", Icon = "play", Color = Color3.fromHex("#30ff6a"),
    Callback = function()
        SafeFireServer("CreateParty", State.PartySize or 1, State.CustomSeed or os.time(), State.ChallengeTier)
        Notify("Party", "Created")
    end,
})
LobbyTab:Space()
LobbyTab:Dropdown({
    Title = "Enter Pad", Values = {"1","2","3","4"},
    Callback = function(v)
        local r = SafeInvokeServer("EnterPad", tonumber(v))
        Notify("Pad", "Pad " .. v .. ": " .. tostring(r))
    end,
})
LobbyTab:Space()
LobbyTab:Button({
    Title = "Leave Pad", Icon = "log-out",
    Callback = function()
        if _G.LeavePad then _G.LeavePad() end
        SafeFireServer("LeavePad"); Notify("Pad", "Left")
    end,
})
LobbyTab:Space()
LobbyTab:Button({
    Title = "IMAFK Ping", Icon = "coffee",
    Callback = function() SafeFireServer("IMAFK"); Notify("AFK", "Pinged") end,
})

local RewardsTab = GameSection:Tab({ Title = "Login & Rewards", Icon = "calendar", Border = true })

RewardsTab:Slider({
    Title = "Set Login Streak", Step = 1, Value = { Min = 1, Max = 365, Default = 7 },
    Callback = function(v) pcall(function() LocalPlayer:SetAttribute("LoginStreak", v) end) end,
})
RewardsTab:Space()
RewardsTab:Slider({
    Title = "Set DayGiven", Step = 1, Value = { Min = 0, Max = 9, Default = 0 },
    Callback = function(v) pcall(function() LocalPlayer:SetAttribute("DayGiven", v) end) end,
})
RewardsTab:Space()
RewardsTab:Button({
    Title = "Retrieve Save Data", Icon = "database",
    Callback = function()
        task.spawn(function()
            local data = SafeInvokeServer("RetrieveData")
            if data then
                Notify("Data", "Dumped to console (F9)")
                print("=== SAVE DATA ===")
                for k, v in pairs(data) do print(k, "=", tostring(v)) end
            else
                Notify("Data", "Failed")
            end
        end)
    end,
})

local ESPTab = VisualsSection:Tab({ Title = "ESP", Icon = "eye", Border = true })

ESPTab:Toggle({
    Title = "Player ESP", Desc = "Highlight all players", Value = false,
    Callback = function(v) State.PlayerESPEnabled = v; if not v then ClearESP() end end,
})
ESPTab:Space()
ESPTab:Toggle({
    Title = "Item & Enemy ESP", Desc = "Chests (gold), Enemies (red), Survivors (green)", Value = false,
    Callback = function(v) State.ItemESPEnabled = v; if not v then ClearESP() end end,
})
ESPTab:Space()
ESPTab:Toggle({
    Title = "Fullbright", Value = false,
    Callback = function(v)
        State.FullbrightEnabled = v
        if v then EnableFullbright() else DisableFullbright() end
    end,
})

local AutoTab = MiscSection:Tab({ Title = "Automation", Icon = "bot", Border = true })

AutoTab:Toggle({
    Title = "Auto Kill Enemies",
    Desc = "TP to nearest ENEMY only (Buku, Ghost, Corrupt, Golem, Alien, etc.) — never NPCs",
    Value = false,
    Callback = function(v)
        State.AutoFarmEnabled = v
        if v and not State.AutoFarmRunning then
            task.spawn(AutoFarmLoop)
        end
    end,
})
AutoTab:Space()
AutoTab:Toggle({
    Title = "Auto Collect Chests",
    Desc = "TP to chests and fire ProximityPrompt — stops immediately on toggle off",
    Value = false,
    Callback = function(v)
        State.AutoChestEnabled = v
        if v and not State.AutoChestRunning then
            task.spawn(AutoChestLoop)
        end
    end,
})
AutoTab:Space()
AutoTab:Toggle({
    Title = "Auto Eat (< 70% HP)",
    Desc = "Eats food from backpack automatically",
    Value = false,
    Callback = function(v)
        State.AutoEatEnabled = v
        if v and not State.AutoEatRunning then
            task.spawn(AutoEatLoop)
        end
    end,
})
AutoTab:Space()
AutoTab:Toggle({
    Title = "Anti-AFK",
    Desc = "Prevents AFK kick + fires IMAFK every 60s",
    Value = false,
    Callback = function(v)
        State.AntiAFKEnabled = v
        if v then
            StartAntiAFK()
            task.spawn(function()
                while State.AntiAFKEnabled do SafeFireServer("IMAFK"); task.wait(60) end
            end)
        else StopAntiAFK() end
    end,
})

local NetTab = MiscSection:Tab({ Title = "Network Tools", Icon = "wifi", Border = true })

NetTab:Button({
    Title = "Print Network Key", Icon = "key",
    Callback = function()
        local bootstrap = nil
        for _, v in pairs(game:GetDescendants()) do
            if v.Name == "NetworkBootstrap" and v:IsA("LocalScript") then bootstrap = v; break end
        end
        if bootstrap then
            local m = bootstrap:GetAttribute("Mult") or 1
            local d = bootstrap:GetAttribute("Div") or 1
            local o = bootstrap:GetAttribute("Off") or 1
            local sa = Workspace:FindFirstChild("ServerAge")
            local age = sa and sa.Value or 0
            local key = math.floor(((age + o) * m / d) ^ 0.75425 * 1000)
            Notify("Network", ("Key=%d  Mult=%s Div=%s Off=%s"):format(key, tostring(m), tostring(d), tostring(o)))
        else
            Notify("Network", "Bootstrap not found")
        end
    end,
})
NetTab:Space()
NetTab:Button({
    Title = "Re-fire DialTone", Icon = "phone",
    Callback = function()
        SafeFireServer("DialTone", os.time(), "PC")
        Notify("Network", "DialTone re-fired")
    end,
})
NetTab:Space()
NetTab:Input({
    Title = "Custom Remote Name", Placeholder = "Remote name...",
    Callback = function(v) State.CustomRemoteName = v end,
})
NetTab:Space()
NetTab:Input({
    Title = "Argument", Placeholder = "Optional arg...",
    Callback = function(v) State.CustomRemoteArg = v end,
})
NetTab:Space()
NetTab:Button({
    Title = "Fire Custom Remote", Icon = "send", Color = Color3.fromHex("#ff4830"),
    Callback = function()
        if State.CustomRemoteName and State.CustomRemoteName ~= "" then
            SafeFireServer(State.CustomRemoteName, State.CustomRemoteArg or nil)
            Notify("Network", "Fired: " .. State.CustomRemoteName)
        end
    end,
})

local InfoTab = MiscSection:Tab({ Title = "Player Info", Icon = "user", Border = true })

InfoTab:Button({
    Title = "Dump Player Attributes", Icon = "list",
    Callback = function()
        print("=== PLAYER ATTRIBUTES ===")
        for _, a in ipairs({"Pearls","Days","Speed","Challenge","ChallengeTier",
            "LoginStreak","DayGiven","Pad","Fruits","StarterPack",
            "DailyTask1","DailyTask2","DailyTask3",
            "DailyTaskProgress1","DailyTaskProgress2","DailyTaskProgress3",
            "HighestChallengeTierUnlocked","OnboardStep","Ping"}) do
            local v = LocalPlayer:GetAttribute(a)
            if v ~= nil then print(("  %s = %s"):format(a, tostring(v))) end
        end
        Notify("Info", "Printed to console (F9)")
    end,
})
InfoTab:Space()
InfoTab:Slider({
    Title = "Set Pearls (client visual)", Step = 10, Value = { Min = 0, Max = 99999, Default = 0 },
    Callback = function(v) pcall(function() LocalPlayer:SetAttribute("Pearls", v) end) end,
})
InfoTab:Space()
InfoTab:Slider({
    Title = "Set Days (client visual)", Step = 1, Value = { Min = 0, Max = 100, Default = 0 },
    Callback = function(v) pcall(function() LocalPlayer:SetAttribute("Days", v) end) end,
})

local SettingsTab = MiscSection:Tab({ Title = "Settings", Icon = "settings", Border = true })

SettingsTab:Keybind({
    Title = "Toggle UI Key", Value = "RightShift",
    Callback = function(v) pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end) end,
})
SettingsTab:Space()
SettingsTab:Button({
    Title = "Destroy UI", Icon = "x", Color = Color3.fromHex("#ff4830"),
    Callback = function()
        State.SpeedEnabled = false; State.FlyEnabled = false
        State.NoclipEnabled = false; State.GodModeEnabled = false
        State.AutoFarmEnabled = false; State.AutoChestEnabled = false
        State.AutoEatEnabled = false; State.AntiAFKEnabled = false
        State.PlayerESPEnabled = false; State.ItemESPEnabled = false
        State.InfAmmoEnabled = false
        StopFly(); StopAntiAFK(); ClearESP(); SetSpeed(16)
        if State.FullbrightEnabled then DisableFullbright() end
        espFolder:Destroy(); Window:Destroy()
    end,
})

GetNet()
Notify("Star Exploit v2", "Loaded — enemy whitelist active, raft TP ready")