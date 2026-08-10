--[[
    109e63269419cec8.lua
    MAXIMUM RECONSTRUCTION FROM THE USER-PROVIDED DEOBF OUTPUT

    Important:
    - This is a reconstruction, not a claim of byte-for-byte original source.
    - Sections marked UNRECOVERED/INFERRED are places where the supplied
      deobfuscated file exposed constants but not enough VM control-flow to
      prove the exact original instructions.
]]

-- ============================================================
-- RECONSTRUCTION V3 — EVIDENCE FIRST
-- ============================================================
-- This version incorporates additional constants visible in the
-- uploaded deobfuscated file. It is intentionally conservative:
-- where the VM register/control-flow mapping is no longer present,
-- the code is not falsely presented as byte-for-byte original.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Recovered configuration / state
-- ============================================================

local SpeedEnabled = false
local SpeedMultiplier = 1
local WallHopEnabled = false
local DoubleJumpHeight = 1
local DoubleJumpButtonEnabled = false
local LookEnabled = false
local FloatingButtonsEnabled = true
local FloatingScale = 1

local HitboxEnabled = false
local HitboxSize = 8
local TeamCheck = true
local HitboxPart = "Head"

local SpoofEnabled = false
local FakeName = "911"
local FakeDisplay = "V"
local UseAltBadge = false
local Badge = utf8.char(57344)
local BadgeAlt = "V"

local EspSystem = false
local EspBox = false
local EspTracer = false
local EspHealth = false
local EspColor = Color3.fromRGB(255, 255, 255)

local EspBombEnabled = false
local EspBombBox = false
local EspBombChams = false
local EspBombAntenna = false
local EspBombColor = Color3.fromRGB(255, 80, 80)

local BvDistance = 21
local PotatoEnabled = false

local lookingAtPlayer = nil
local targetPlayer = nil

-- Recovered room positions
local Rooms = {
    ["Sala 1"] = Vector3.new(265.9, 16.75, 33.7),
    ["Sala 2"] = Vector3.new(42.5, 19.5, -32.1),
    ["Sala 3"] = Vector3.new(116.1, 16.5, -30.4),
    ["Sala 4"] = Vector3.new(191.6, 18, 36),
    ["Sala 5"] = Vector3.new(189.6, 16, 102),
    ["Sala 6"] = Vector3.new(116.6, 17, 102.5),
    ["Sala 7"] = Vector3.new(42.1, 12.5, 0),
}

-- ============================================================
-- Utility functions
-- ============================================================

local function getCharacter(player)
    return player and player.Character
end

local function getRoot(player)
    local character = getCharacter(player)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
    local character = getCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getNearestEnemy(maxDistance)
    local myRoot = getRoot(LocalPlayer)
    if not myRoot then
        return nil
    end

    local nearest = nil
    local nearestDistance = maxDistance or math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local humanoid = getHumanoid(player)
            local root = getRoot(player)

            if humanoid and humanoid.Health > 0 and root then
                if not TeamCheck or player.Team ~= LocalPlayer.Team then
                    local distance = (root.Position - myRoot.Position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearest = player
                    end
                end
            end
        end
    end

    return nearest, nearestDistance
end

-- ============================================================
-- Speed
-- Recovered constants include Speed ON/OFF, Character,
-- task.delay(0.2), MoveDirection, Magnitude and velocity data.
-- ============================================================

local speedConnection

local function setSpeed(enabled)
    SpeedEnabled = enabled

    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end

    if not enabled then
        return
    end

    speedConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not humanoid or not root then
            return
        end

        local direction = humanoid.MoveDirection
        if direction.Magnitude > 0 then
            -- Reconstructed from the recovered MoveDirection/Magnitude/
            -- AssemblyLinearVelocity constants.
            root.AssemblyLinearVelocity = Vector3.new(
                direction.X * (50 * SpeedMultiplier),
                root.AssemblyLinearVelocity.Y,
                direction.Z * (50 * SpeedMultiplier)
            )
        end
    end)
end

-- ============================================================
-- WallHop — forensic reconstruction
-- Recovered: RaycastParams, FilterDescendantsInstances, Raycast,
-- Vector3.new(-4.5, 2, ...), Exclude, tick, 0.05, Jumping, Velocity.
-- ============================================================

local wallHopConnection
local wallHopLast = 0

local function setWallHop(enabled)
    WallHopEnabled = enabled

    if wallHopConnection then
        wallHopConnection:Disconnect()
        wallHopConnection = nil
    end

    if not enabled then
        return
    end

    wallHopConnection = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then
            return
        end

        local now = tick()
        if now - wallHopLast < 0.05 then
            return
        end

        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {character}
        params.FilterType = Enum.RaycastFilterType.Exclude

        -- These numeric constants are exposed in the deobf stream.
        local hit = workspace:Raycast(
            root.Position,
            Vector3.new(-4.5, 2, 0),
            params
        )

        if hit and hit.Instance and hit.Instance.CanCollide then
            wallHopLast = now
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            root.Velocity = Vector3.new(50, root.Velocity.Y, 0)
        end
    end)
end

-- ============================================================
-- Double Jump
-- ============================================================

local doubleJumpUsed = false
local doubleJumpConnection

local function setupDoubleJump()
    if doubleJumpConnection then
        doubleJumpConnection:Disconnect()
    end

    doubleJumpConnection = UserInputService.JumpRequest:Connect(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if not humanoid or not root then
            return
        end

        if humanoid:GetState() == Enum.HumanoidStateType.Freefall and not doubleJumpUsed then
            doubleJumpUsed = true
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            root.Velocity = Vector3.new(
                root.Velocity.X,
                50 * DoubleJumpHeight,
                root.Velocity.Z
            )
        end
    end)

    local function reset()
        doubleJumpUsed = false
    end

    LocalPlayer.CharacterAdded:Connect(function(character)
        character:WaitForChild("Humanoid").StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Landed then
                reset()
            end
        end)
    end)
end

setupDoubleJump()

-- ============================================================
-- Look at nearest enemy
-- Recovered constants explicitly identify CFrame.lookAt,
-- targetPlayer, lookingAtPlayer and nearest-player selection.
-- ============================================================

local lookConnection

local function setLook(enabled)
    LookEnabled = enabled

    if lookConnection then
        lookConnection:Disconnect()
        lookConnection = nil
    end

    if not enabled then
        lookingAtPlayer = nil
        return
    end

    lookConnection = RunService.RenderStepped:Connect(function()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        local player = getNearestEnemy(math.huge)
        lookingAtPlayer = player

        if player then
            local enemyRoot = getRoot(player)
            if enemyRoot then
                local p = enemyRoot.Position
                root.CFrame = CFrame.lookAt(
                    root.Position,
                    Vector3.new(p.X, root.Position.Y, p.Z)
                )
            end
        end
    end)
end

-- ============================================================
-- Hitbox
-- Recovered constants: GetPlayers, Humanoid, BasePart, Head,
-- Size, Vector3.new, Transparency, CanCollide=false.
-- ============================================================

local originalHitbox = {}

local function setHitbox(enabled)
    HitboxEnabled = enabled

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, part in ipairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    if not originalHitbox[part] then
                        originalHitbox[part] = {
                            Size = part.Size,
                            Transparency = part.Transparency,
                            CanCollide = part.CanCollide,
                        }
                    end

                    if enabled and part.Name == HitboxPart then
                        part.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        part.Transparency = 0
                        part.CanCollide = false
                    elseif not enabled and originalHitbox[part] then
                        part.Size = originalHitbox[part].Size
                        part.Transparency = originalHitbox[part].Transparency
                        part.CanCollide = originalHitbox[part].CanCollide
                    end
                end
            end
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.4)
        if HitboxEnabled then
            setHitbox(true)
        end
    end)
end)

-- ============================================================
-- ESP using Drawing
-- Recovered Drawing.new("Square"/"Line"), RenderStepped,
-- WorldToViewportPoint, Humanoid health/max health, Vector2,
-- Thickness/Filled/Visible/Color.
-- ============================================================

local espObjects = {}

local function removeEsp(player)
    local data = espObjects[player]
    if not data then
        return
    end

    for _, object in pairs(data) do
        pcall(function()
            if object.Remove then
                object:Remove()
            elseif object.Destroy then
                object:Destroy()
            end
        end)
    end

    espObjects[player] = nil
end

local function createEsp(player)
    if player == LocalPlayer or espObjects[player] then
        return
    end

    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 2
    box.Filled = false

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1

    local health = Drawing.new("Square")
    health.Visible = false
    health.Thickness = 2
    health.Filled = true

    espObjects[player] = {
        Box = box,
        Tracer = tracer,
        Health = health,
    }
end

local function updateEsp(player, data)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not root or not humanoid or humanoid.Health <= 0 then
        data.Box.Visible = false
        data.Tracer.Visible = false
        data.Health.Visible = false
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local position, onScreen = camera:WorldToViewportPoint(root.Position)

    if not onScreen then
        data.Box.Visible = false
        data.Tracer.Visible = false
        data.Health.Visible = false
        return
    end

    local distance = math.max((camera.CFrame.Position - root.Position).Magnitude, 1)
    local size = math.clamp(1000 / distance, 15, 120)

    data.Box.Color = EspColor
    data.Box.Size = Vector2.new(size * 0.8, size)
    data.Box.Position = Vector2.new(
        position.X - data.Box.Size.X / 2,
        position.Y - data.Box.Size.Y / 2
    )
    data.Box.Visible = EspSystem and EspBox

    data.Tracer.Color = EspColor
    data.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
    data.Tracer.To = Vector2.new(position.X, position.Y)
    data.Tracer.Visible = EspSystem and EspTracer

    local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
    data.Health.Color = EspColor
    data.Health.Size = Vector2.new(2, size * ratio)
    data.Health.Position = Vector2.new(
        position.X - size * 0.5 - 5,
        position.Y + size / 2 - size * ratio
    )
    data.Health.Visible = EspSystem and EspHealth
end

for _, player in ipairs(Players:GetPlayers()) do
    createEsp(player)
end

Players.PlayerAdded:Connect(createEsp)
Players.PlayerRemoving:Connect(removeEsp)

RunService.RenderStepped:Connect(function()
    for player, data in pairs(espObjects) do
        updateEsp(player, data)
    end
end)

-- ============================================================
-- Rainbow ESP color
-- ============================================================

RunService.RenderStepped:Connect(function()
    if EspColor == "rainbow" then
        EspColor = Color3.fromHSV((tick() / 5) % 1, 1, 1)
    end
end)

-- ============================================================
-- Potato mode
-- Recovered properties include Terrain water settings,
-- Lighting effects, BasePart material/reflectance/cast shadow,
-- Texture/Decal transparency, particle/trail/smoke/fire/sparkles/
-- beam disabling, Rendering.QualityLevel and GlobalShadows.
-- ============================================================

local function setPotato(enabled)
    PotatoEnabled = enabled

    if enabled then
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.GlobalShadows = false
        end)

        pcall(function()
            workspace.Terrain.WaterWaveSize = 0
            workspace.Terrain.WaterWaveSpeed = 0
            workspace.Terrain.WaterReflectance = 0
            workspace.Terrain.WaterTransparency = 1
            workspace.Terrain.GlobalShadows = false
            workspace.Terrain.FogEnd = 8999999488
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
        end)

        for _, object in ipairs(Lighting:GetChildren()) do
            if object:IsA("BlurEffect")
                or object:IsA("ColorCorrectionEffect")
                or object:IsA("BloomEffect")
                or object:IsA("SunRaysEffect")
                or object:IsA("DepthOfFieldEffect")
                or object:IsA("Atmosphere") then
                pcall(function()
                    object.Enabled = false
                end)
            end
        end

        for _, object in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if object:IsA("BasePart") then
                    object.Material = Enum.Material.SmoothPlastic
                    object.Reflectance = 0
                    object.CastShadow = false
                elseif object:IsA("Texture") or object:IsA("Decal") then
                    object.Transparency = 1
                elseif object:IsA("ParticleEmitter")
                    or object:IsA("Trail")
                    or object:IsA("Smoke")
                    or object:IsA("Fire")
                    or object:IsA("Sparkles")
                    or object:IsA("Beam") then
                    object.Enabled = false
                end
            end)
        end
    else
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            settings().Rendering.GlobalShadows = true
        end)
    end
end

-- ============================================================
-- Bate e Volta — forensic reconstruction
-- Recovered: Sala 1..7, CFrame.new, PointToObjectSpace, math.abs,
-- X/Y/Z, GetPlayers, Character, HumanoidRootPart, Magnitude,
-- targetPlayer and distance 21.
-- ============================================================

local function getRoomForPosition(position)
    local bestRoom
    local bestDistance = math.huge

    for roomName, roomPosition in pairs(Rooms) do
        local distance = (position - roomPosition).Magnitude
        if distance < bestDistance then
            bestDistance = distance
            bestRoom = roomName
        end
    end

    return bestRoom
end

local function bateVolta()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local roomName = getRoomForPosition(root.Position)
    if not roomName then
        return
    end

    local roomCFrame = CFrame.new(Rooms[roomName])
    local relative = roomCFrame:PointToObjectSpace(root.Position)

    -- Retain the recovered room-relative calculation.
    if math.abs(relative.Y) > 21 then
        return
    end

    local targetPlayer
    local nearestDistance = 21

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

            if enemyRoot and humanoid and humanoid.Health > 0 then
                local distance = (enemyRoot.Position - root.Position).Magnitude
                if distance <= nearestDistance
                    and ((not TeamCheck) or player.Team ~= LocalPlayer.Team) then
                    targetPlayer = player
                    nearestDistance = distance
                end
            end
        end
    end

    if not targetPlayer then
        return
    end

    local enemyRoot = targetPlayer.Character
        and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not enemyRoot then
        return
    end

    local originalCFrame = root.CFrame
    root.CFrame = CFrame.new(enemyRoot.Position)
    task.wait()
    root.CFrame = originalCFrame
end

-- ============================================================
-- Spoof — forensic reconstruction
-- Recovered: FakeDisplay/FakeName, find/gsub, UseAltBadge,
-- BadgeAlt/Badge, TextLabel/TextButton/TextBox,
-- GetPropertyChangedSignal("Text"), PlayerGui descendants.
-- ============================================================

local spoofConnections = {}

local function spoofText(object)
    if not (
        object:IsA("TextLabel")
        or object:IsA("TextButton")
        or object:IsA("TextBox")
    ) then
        return
    end

    local text = object.Text
    if type(text) ~= "string" or text == "" then
        return
    end

    if LocalPlayer.DisplayName ~= ""
        and text:find(LocalPlayer.DisplayName, 1, true) then
        text = text:gsub(LocalPlayer.DisplayName, FakeDisplay)
    end

    if LocalPlayer.Name ~= ""
        and text:find(LocalPlayer.Name, 1, true) then
        text = text:gsub(LocalPlayer.Name, FakeName)
    end

    if UseAltBadge
        and Badge ~= ""
        and text:find(Badge, 1, true) then
        text = text:gsub(Badge, BadgeAlt)
    end

    object.Text = text
end

local function clearSpoofConnections()
    for _, connection in ipairs(spoofConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(spoofConnections)
end

local function hookSpoofObject(object)
    if not (
        object:IsA("TextLabel")
        or object:IsA("TextButton")
        or object:IsA("TextBox")
    ) then
        return
    end

    spoofText(object)

    table.insert(
        spoofConnections,
        object:GetPropertyChangedSignal("Text"):Connect(function()
            if SpoofEnabled then
                spoofText(object)
            end
        end)
    )
end

local function setSpoof(enabled)
    SpoofEnabled = enabled
    clearSpoofConnections()

    if not enabled then
        return
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return
    end

    for _, object in ipairs(playerGui:GetDescendants()) do
        hookSpoofObject(object)
    end

    table.insert(
        spoofConnections,
        playerGui.DescendantAdded:Connect(function(object)
            if SpoofEnabled then
                hookSpoofObject(object)
            end
        end)
    )
end

-- ============================================================
-- Floating button state
-- ============================================================

local floatingGui
local floatingButtons = {}

local function makeButton(parent, name, text, position)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 100, 0, 40)
    button.Position = position
    button.Text = text
    button.BackgroundColor3 = Color3.fromRGB(60, 20, 110)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.Parent = parent
    return button
end

local function createFloatingGui()
    if floatingGui then
        return
    end

    floatingGui = Instance.new("ScreenGui")
    floatingGui.Name = "EzScriptButtons"
    floatingGui.ResetOnSpawn = false
    floatingGui.IgnoreGuiInset = true
    floatingGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local container = Instance.new("Frame")
    container.Name = "ButtonsContainer"
    container.BackgroundTransparency = 1
    container.Visible = FloatingButtonsEnabled
    container.Size = UDim2.new(0, 200, 0, 220)
    container.Position = UDim2.new(0, 10, 0.5, -110)
    container.Parent = floatingGui

    floatingButtons.Speed = makeButton(container, "Speed", "Speed\nOFF",
        UDim2.new(0, 0, 0, 0))

    floatingButtons.WallHop = makeButton(container, "WallHop", "WallHop\nOFF",
        UDim2.new(0, 0, 0, 45))

    floatingButtons.Jump = makeButton(container, "Jump", "Jump",
        UDim2.new(0, 0, 0, 90))

    floatingButtons.Look = makeButton(container, "Look", "Look\nOFF",
        UDim2.new(0, 0, 0, 135))

    floatingButtons.BV = makeButton(container, "BV", "B&V\nClick",
        UDim2.new(0, 0, 0, 180))

    floatingButtons.Potato = makeButton(container, "Potato", "Potato\nOFF",
        UDim2.new(0, 105, 0, 0))

    floatingButtons.Speed.MouseButton1Click:Connect(function()
        setSpeed(not SpeedEnabled)
        floatingButtons.Speed.Text = SpeedEnabled and "Speed\nON" or "Speed\nOFF"
    end)

    floatingButtons.WallHop.MouseButton1Click:Connect(function()
        setWallHop(not WallHopEnabled)
        floatingButtons.WallHop.Text = WallHopEnabled and "WallHop\nON" or "WallHop\nOFF"
    end)

    floatingButtons.Jump.MouseButton1Click:Connect(function()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if humanoid and root then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            root.Velocity = Vector3.new(root.Velocity.X, 50, root.Velocity.Z)
        end
    end)

    floatingButtons.Look.MouseButton1Click:Connect(function()
        setLook(not LookEnabled)
        floatingButtons.Look.Text = LookEnabled and "Look\nON" or "Look\nOFF"
    end)

    floatingButtons.BV.MouseButton1Click:Connect(bateVolta)

    floatingButtons.Potato.MouseButton1Click:Connect(function()
        setPotato(not PotatoEnabled)
        floatingButtons.Potato.Text = PotatoEnabled and "Potato\nON" or "Potato\nOFF"
    end)
end

createFloatingGui()

-- ============================================================
-- Loader / Security GUI
-- Recovered exactly enough to reproduce the visible structure.
-- The original key-validation endpoint/control-flow is not fully
-- recoverable from the supplied constant stream.
-- ============================================================

local loader = Instance.new("ScreenGui")
loader.Name = "EzScriptLoader"
loader.ResetOnSpawn = false
loader.IgnoreGuiInset = true
loader.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 380, 0, 220)
frame.Position = UDim2.new(0.5, -190, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(14, 6, 22)
frame.BorderSizePixel = 0
frame.Parent = loader

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(140, 50, 220)
stroke.Thickness = 2
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 15)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Ez Script - Security"
title.TextColor3 = Color3.fromRGB(240, 235, 255)
title.TextSize = 18
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 20)
subtitle.Position = UDim2.new(0, 0, 0, 45)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Digite sua Key para continuar"
subtitle.TextColor3 = Color3.fromRGB(180, 150, 220)
subtitle.TextSize = 12
subtitle.Parent = frame

local keyBox = Instance.new("TextBox")
keyBox.Size = UDim2.new(0, 300, 0, 45)
keyBox.Position = UDim2.new(0.5, -150, 0, 85)
keyBox.BackgroundColor3 = Color3.fromRGB(12, 20, 40)
keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBox.Font = Enum.Font.Gotham
keyBox.PlaceholderText = "Digite sua Key aqui..."
keyBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
keyBox.Text = ""
keyBox.TextSize = 15
keyBox.Parent = frame

local verify = Instance.new("TextButton")
verify.Size = UDim2.new(0, 300, 0, 45)
verify.Position = UDim2.new(0.5, -150, 0, 145)
verify.BackgroundColor3 = Color3.fromRGB(60, 20, 110)
verify.Font = Enum.Font.GothamBold
verify.Text = "Verificar Key"
verify.TextColor3 = Color3.fromRGB(255, 255, 255)
verify.TextSize = 18
verify.Parent = frame

verify.MouseButton1Click:Connect(function()
    -- UNRECOVERED:
    -- The supplied file exposes "time-ez", "Key invalida! Tente novamente.",
    -- HttpService, loadstring, and the WindUI URL, but not enough verified
    -- control-flow to reproduce the exact original validation routine.
    --
    -- Therefore this reconstruction does NOT invent a key-validation API.
    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(1, 0, 0, 20)
    message.Position = UDim2.new(0, 0, 1, -25)
    message.BackgroundTransparency = 1
    message.Font = Enum.Font.Gotham
    message.Text = "Key validation logic: UNRECOVERED"
    message.TextColor3 = Color3.fromRGB(255, 80, 80)
    message.TextSize = 12
    message.Parent = frame
end)

-- ============================================================
-- WindUI metadata recovered from constants
-- ============================================================

local WindUI_URL =
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"

-- The original source loads WindUI after successful key validation.
-- Exact original configuration/control-flow is not fully present
-- in the supplied deobf output, so it is intentionally not fabricated.

-- Recovered theme:
local DarkPurpleTheme = {
    Name = "DarkPurple",
    Background = Color3.fromRGB(14, 6, 22),
    Accent = Color3.fromRGB(90, 25, 160),
    Dialog = Color3.fromRGB(10, 35, 35),
    Outline = Color3.fromRGB(140, 50, 220),
    Text = Color3.fromRGB(240, 235, 255),
    Placeholder = Color3.fromRGB(150, 120, 180),
    Button = Color3.fromRGB(100, 30, 180),
}

-- Recovered UI title/sections:
local WindowInfo = {
    Title = "Ez Script | minsu & ez",
    Size = UDim2.fromOffset(780, 560),
    SideBarWidth = 180,
    HideSearchBar = true,
    Sections = {
        {"home", "Ez Script", "home"},
        {"info", "Info", "info"},
        {"move", "Movement", "move"},
        {"target", "Combat", "target"},
        {"eye", "Visuals", "eye"},
        {"box", "Misc", "box"},
        {"repeat", "BateVolta", "repeat"},
        {"leaf", "Potato", "leaf"},
        {"palette", "Themes", "palette"},
    },
}

-- ============================================================
-- Recovered feature labels / metadata
-- ============================================================

local FeatureLabels = {
    SpeedTitle = "Deixa voce mais rapido",
    SpeedToggle = "LIGAR / DESLIGAR SPEED",
    SpeedSlider = "Multiplicador de Velocidade",
    WallHopTitle = "Wallhop Automatico",
    WallHopToggle = "LIGAR / DESLIGAR WALLHOP",
    DoubleJumpTitle = "Pulo Duplo (Fake Jump)",
    DoubleJumpSlider = "Altura do Double Jump",
    DoubleJumpBtnToggle = "EXIBIR / OCULTAR BOTAO DOUBLE JUMP",
    LookTitle = "Olhar para os inimigos",
    LookToggle = "EXIBIR / OCULTAR GUI DE OLHAR",
    FloatingTitle = "Botoes Flutuantes",
    FloatingToggle = "Exibir / Ocultar Botoes Flutuantes",
    FloatingScale = "Tamanho dos Botoes (Escala)",
    HitboxTitle = "Aumenta a Hitbox",
    HitboxToggle = "LIGAR / DESLIGAR HITBOX",
    HitboxSlider = "Tamanho da Hitbox",
    TeamCheck = "Verificacao de Equipe (Team Check)",
    HitboxPart = "Parte Alvo da Hitbox",
    SpoofTitle = "Modificador de Nome",
    SpoofDesc = "Fingir seu nome",
    SpoofToggle = "LIGAR / DESLIGAR SPOOF",
    FakeNameInput = "Nome Falso (FakeName)",
    FakeDisplayInput = "Display Falso (FakeDisplay)",
    EspTitle = "ESP de Jogadores",
    EspSystem = "Sistema ESP Geral",
    EspBox = "ESP Box (Caixa)",
    EspTracer = "Tracer (Linhas)",
    EspHealth = "Barra de Vida",
    EspColor = "Cor do ESP Geral (Box, Tracer)",
    EspBombTitle = "ESP da Bomba",
    EspBombToggle = "Ligar ESP Bomb",
    EspBombBox = "Ligar Box na Bomb",
    EspBombChams = "Ligar Chams na Bomb",
    EspBombAntenna = "Ligar Antena em Cima da Bomb",
    EspBombColor = "Cor do ESP Bomb",
    BvTitle = "Bate e Volta",
    BvDesc = "Teleportar para o inimigo mais proximo e voltar",
    BvDistance = "Distancia Maxima da Sala",
    PotatoTitle = "Potato",
    PotatoDesc = "Aumento de FPS para PCs fracos",
    PotatoToggle = "LIGAR / DESLIGAR MODO BATATA",
    ThemeTitle = "Tema da Interface",
    ThemeDesc = "Mudar a aparencia da UI",
    ThemeSelect = "Tema",
    ThemeNote = "Apenas DarkPurple por enquanto",
    CreditsTitle = "Creditos",
    CreditsDesc = "feito por minsu e ez",
}

-- ============================================================
-- Executor detection constants recovered from the file.
-- ============================================================

local function getExecutorName()
    local name = "Unknown"

    pcall(function()
        if syn then
            name = "Synapse X"
        elseif KRNL_LOADED then
            name = "Krnl"
        elseif scriptware then
            name = "ScriptWare"
        elseif getexecutorname then
            name = getexecutorname()
        elseif RunService:IsStudio() then
            name = "Roblox Studio"
        end
    end)

    return name
end

-- ============================================================
-- End of maximum reconstruction.
-- ============================================================

return {
    Rooms = Rooms,
    Theme = DarkPurpleTheme,
    Window = WindowInfo,
    Features = FeatureLabels,
    GetExecutorName = getExecutorName,
    SetSpeed = setSpeed,
    SetWallHop = setWallHop,
    SetLook = setLook,
    SetHitbox = setHitbox,
    SetSpoof = setSpoof,
    SetPotato = setPotato,
    BateVolta = bateVolta,
}
