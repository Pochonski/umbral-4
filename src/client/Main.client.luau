local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local shared = ReplicatedStorage:WaitForChild("UmbralShared")
local Config = require(shared.Config)
local Geometry = require(shared.Geometry)
local Interface = require(script.Parent.Interface)
local player = Players.LocalPlayer
local view = Interface.create(player:WaitForChild("PlayerGui"))
local network = ReplicatedStorage:WaitForChild("UmbralNetwork")
local map = workspace:WaitForChild("UmbralWorld"):WaitForChild("EstacionDeRelevo")
local cover = Geometry.coverParams(map)

local state = {
    phase = "waiting", roundId = 0, lifeId = 0, deadline = 0, goal = 0,
    status = "lobby", participating = false, readyCount = 0,
    respawnAt = 0, protectedUntil = 0, killerName = "", scores = {}, winners = {},
}
local receivedState = false
local plates, upcoming = {}, {}
local digits, lastDigit, practiceMessage = "", 0, nil
local sensitivity, volume, reduced = 1, .65, false
local lastPlayClick = -math.huge
local lastViewport
local vista = CFrame.lookAt(Vector3.new(69, 33, 57), Vector3.new(9, 1.3, -6))

local plateFolder = Instance.new("Folder")
plateFolder.Name = "UmbralLocalPlates"
plateFolder.Parent = workspace

local function tone(name, speed)
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = "rbxasset://sounds/volume_slider.ogg"
    sound.PlaybackSpeed = speed
    sound.Volume = 0
    sound.Parent = SoundService
    return sound
end

local confirmed = tone("Confirmación", 1.34)
local miss = tone("Intento", .73)

local function playSound(sound, level)
    if volume == 0 then return end
    sound.Volume = volume * level
    sound.TimePosition = 0
    sound:Play()
end

local function supported()
    return UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
end

local function clearInput()
    digits, lastDigit, practiceMessage = "", 0, nil
    view.digits("")
    view.practice("")
end

local function refreshCamera()
    local camera = workspace.CurrentCamera
    local overview = state.phase ~= "playing" or not state.participating
    local aim = state.phase == "playing" and state.participating and state.status == "alive"
        and view.modal == nil and not GuiService.MenuIsOpen
    local mode = if aim then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
    if player.CameraMode ~= mode then
        player.CameraMode = mode
        if not aim then
            player.CameraMinZoomDistance = 7
            player.CameraMinZoomDistance = .5
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
    if camera and overview and camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = vista
        camera.Focus = CFrame.new(9, 1.3, -6)
    elseif camera and not overview and camera.CameraType == Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Custom
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
    end
end

local function openModal(name)
    clearInput()
    view.showModal(name)
    refreshCamera()
end

local function clearPlates()
    for _, plate in plates do plate.part:Destroy() end
    table.clear(plates)
end

local function addPlate(code)
    local plate = Instance.new("Part")
    plate.Name = "Placa"
    plate.Size = Vector3.new(Config.PlateWidth, Config.PlateHeight, .03)
    plate.Anchored = true
    plate.CanCollide, plate.CanQuery, plate.CanTouch = false, false, false
    plate.Transparency = 1
    plate.CastShadow = false
    plate.Parent = plateFolder

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.AlwaysOnTop = false
    gui.Enabled = false
    gui.LightInfluence = 0
    gui.Brightness = 1
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(252, 84)
    gui.Parent = plate

    local label = Instance.new("TextLabel")
    label.Text = code
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(255, 236, 183)
    label.TextColor3 = Color3.fromRGB(22, 35, 43)
    label.TextSize = 69
    label.Font = Enum.Font.RobotoMono
    label.BorderSizePixel = 0
    label.Parent = gui
    local edges = Instance.new("UICorner")
    edges.CornerRadius = UDim.new(0, 10)
    edges.Parent = label

    return plate, gui
end

local function applyPlates(updates, reset)
    if reset then clearPlates() end
    for _, update in updates do
        local existing = plates[update.userId]
        if update.code then
            if existing then existing.part:Destroy() end
            local part, gui = addPlate(update.code)
            plates[update.userId] = {part = part, gui = gui, lifeId = update.lifeId}
        elseif existing and existing.lifeId == update.lifeId then
            existing.part:Destroy()
            plates[update.userId] = nil
        end
    end
end

network.State.OnClientEvent:Connect(function(nextState)
    receivedState = true
    if state.roundId ~= nextState.roundId or state.lifeId ~= nextState.lifeId
        or state.phase ~= nextState.phase or state.status ~= nextState.status then
        clearInput()
        clearPlates()
        view.notify("", false)
        if view.modal == "how" then view.showModal(nil) end
    end
    state = nextState
    if state.status == "alive" and state.phase == "playing" then
        for _, entry in upcoming do
            if entry.roundId == state.roundId and entry.lifeId == state.lifeId then
                applyPlates(entry.updates, entry.reset)
            end
        end
    end
    table.clear(upcoming)
    view.state(state, player.UserId, supported())
    refreshCamera()
end)

network.Plates.OnClientEvent:Connect(function(roundId, lifeId, updates, reset)
    if state.roundId == roundId and state.lifeId == lifeId then
        if state.phase == "playing" and state.status == "alive" then applyPlates(updates, reset) end
    elseif roundId > state.roundId or (roundId == state.roundId and lifeId > state.lifeId) then
        table.insert(upcoming, {roundId = roundId, lifeId = lifeId, updates = updates, reset = reset})
    end
end)

network.Feedback.OnClientEvent:Connect(function(kind, rival, roundId, lifeId)
    if state.roundId ~= roundId or state.lifeId ~= lifeId then return end
    if kind == "hit" then
        view.notify("✓  BAJA  ·  " .. rival, true)
        playSound(confirmed, .82)
    else
        view.notify("INTENTO FALLIDO", false)
        playSound(miss, .25)
    end
end)

view.play.Activated:Connect(function()
    local now = os.clock()
    if not receivedState or not supported() or view.modal or now - lastPlayClick < .3 then return end
    lastPlayClick = now
    network.Request:FireServer("ready", not state.ready)
end)
view.how.Activated:Connect(function() openModal("how") end)
view.settings.Activated:Connect(function() openModal("settings") end)
view.close.Activated:Connect(function() openModal(nil) end)

local function applyOptions()
    UserInputService.MouseDeltaSensitivity = sensitivity
    view.options(sensitivity, volume, reduced)
end

view.controls.sensitivityDown.Activated:Connect(function()
    sensitivity = math.max(.25, sensitivity - .15)
    applyOptions()
end)
view.controls.sensitivityUp.Activated:Connect(function()
    sensitivity = math.min(2, sensitivity + .15)
    applyOptions()
end)
view.controls.volumeDown.Activated:Connect(function()
    volume = math.max(0, volume - .15)
    applyOptions()
    playSound(confirmed, .48)
end)
view.controls.volumeUp.Activated:Connect(function()
    volume = math.min(1, volume + .15)
    applyOptions()
    playSound(confirmed, .48)
end)
view.controls.motion.Activated:Connect(function()
    reduced = not reduced
    applyOptions()
end)

local numberKeys = {}
for i, name in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" } do
    numberKeys[Enum.KeyCode[name]] = tostring(i - 1)
    numberKeys[Enum.KeyCode["Keypad" .. name]] = tostring(i - 1)
end

local down = {}
local function keyPressed(input, processed)
    local key = input.KeyCode
    if key == Enum.KeyCode.Escape then
        clearInput()
        return
    end
    if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
    if processed and not numberKeys[key] and key ~= Enum.KeyCode.Backspace then return end
    if key == Enum.KeyCode.M and view.modal ~= "how" then
        openModal(if view.modal then nil else "settings")
        return
    end
    local practice = view.modal == "how"
    if not practice and (view.modal or state.phase ~= "playing" or not state.participating
        or state.status ~= "alive" or workspace:GetServerTimeNow() < state.protectedUntil) then return end
    if key == Enum.KeyCode.Backspace then
        digits = digits:sub(1, -2)
        lastDigit = os.clock()
    elseif numberKeys[key] and not down[key] then
        down[key] = true
        if #digits == 4 then digits = "" end
        digits ..= numberKeys[key]
        lastDigit, practiceMessage = os.clock(), nil
        if #digits == 4 then
            if practice then
                practiceMessage = if digits == "0917" then "✓  Código correcto. Ya puedes jugar." else "Inténtalo otra vez."
                playSound(if digits == "0917" then confirmed else miss, .53)
            else
                network.SubmitCode:FireServer(state.roundId, state.lifeId, digits)
                local completedAt = lastDigit
                task.delay(.12, function()
                    if lastDigit == completedAt then clearInput() end
                end)
            end
        end
    end
    view.digits(digits)
    if practice then view.practice(digits, practiceMessage) end
end

UserInputService.InputBegan:Connect(keyPressed)
UserInputService.InputEnded:Connect(function(input) down[input.KeyCode] = nil end)
UserInputService.WindowFocusReleased:Connect(function()
    table.clear(down)
    clearInput()
end)
UserInputService.TextBoxFocused:Connect(clearInput)
GuiService.MenuOpened:Connect(function()
    clearInput()
    refreshCamera()
end)
GuiService.MenuClosed:Connect(refreshCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refreshCamera)

local function renderPlates(camera)
    local origin = camera.CFrame.Position
    local rendering = state.phase == "playing" and state.status == "alive" and not view.modal
    for id, plate in plates do
        local target = Players:GetPlayerByUserId(id)
        local model = target and target.Character
        local root = model and model:FindFirstChild("HumanoidRootPart")
        local head = model and model:FindFirstChild("Head")
        local visible = false
        if rendering and root and head then
            local cframe = Geometry.plateCFrame(root, head)
            local _, inFrame = camera:WorldToViewportPoint(cframe.Position)
            visible = inFrame and cframe.LookVector:Dot(origin - cframe.Position) > 0
                and not Geometry.covered(origin, head.Position, cover)
                and not Geometry.covered(origin, cframe.Position, cover)
            if visible then plate.part.CFrame = cframe end
        end
        if plate.gui.Enabled ~= visible then plate.gui.Enabled = visible end
    end
end

local nextUpdate = 0
RunService:BindToRenderStep("UmbralHUD", Enum.RenderPriority.Camera.Value + 1, function()
    local camera = workspace.CurrentCamera
    if not camera then return end
    if camera.ViewportSize ~= lastViewport then
        lastViewport = camera.ViewportSize
        view.resize(lastViewport)
    end
    renderPlates(camera)
    local now = os.clock()
    if now >= nextUpdate then
        nextUpdate = now + .1
        if #digits > 0 and now - lastDigit > Config.InputTimeout then clearInput() end
        view.updateTime(state, workspace:GetServerTimeNow())
    end
end)

view.state(state, player.UserId, supported())
view.digits("")
applyOptions()
refreshCamera()
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
network.Request:FireServer("sync")
task.spawn(function()
    for _ = 1, 5 do
        task.wait(1)
        if receivedState then break end
        network.Request:FireServer("sync")
    end
end)
