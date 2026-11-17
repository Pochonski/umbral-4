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
local InputBuffer = require(script.Parent.InputBuffer)
local player = Players.LocalPlayer
local view = Interface.create(player:WaitForChild("PlayerGui"))
local network = ReplicatedStorage:WaitForChild("UmbralNetwork")
local map = workspace:WaitForChild("UmbralWorld"):WaitForChild(Config.ArenaModel)
local cover = Geometry.coverParams(map)

local state = {
    phase = "waiting", roundId = 0, lifeId = 0, deadline = 0, goal = 0,
    status = "lobby", participating = false, readyCount = 0,
    respawnAt = 0, protectedUntil = 0, killerName = "", scores = {}, winners = {},
}
local receivedState = false
local plates = {}
local inputBuffer = InputBuffer.new(Config.InputTimeout)
local receiptUntil = 0
local sensitivity, volume, reduced = 1, .65, false
local lastPlayClick = -math.huge
local lastViewport
local vista = CFrame.lookAt(Vector3.new(69, 33, 57), Vector3.new(9, 1.3, -6))
local configuredMinZoom = player.CameraMinZoomDistance
local overlayZoom = 7

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
    InputBuffer.clear(inputBuffer)
    receiptUntil = 0
    view.digits("")
    view.practice("")
end

local function refreshCamera()
    local camera = workspace.CurrentCamera
    local overview = state.phase ~= "playing" or not state.participating
    local aim = state.phase == "playing" and state.participating and state.status == "alive"
        and view.modal == nil and not GuiService.MenuIsOpen
    -- Keep the cursor free while the in-round overlay is open, then restore the configured minimum.
    local minZoom = if not overview and not aim then math.min(
        player.CameraMaxZoomDistance, math.max(configuredMinZoom, overlayZoom)
    ) else configuredMinZoom
    if player.CameraMinZoomDistance ~= minZoom then player.CameraMinZoomDistance = minZoom end
    local mode = if aim then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
    if player.CameraMode ~= mode then
        player.CameraMode = mode
        if not aim then
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

local function onState(nextState)
    receivedState = true
    if state.roundId ~= nextState.roundId or state.lifeId ~= nextState.lifeId
        or state.phase ~= nextState.phase or state.status ~= nextState.status then
        clearInput()
        clearPlates()
        view.notify("", false)
        if view.modal == "how" then view.showModal(nil) end
    end
    state = nextState
    view.state(state, player.UserId, supported())
    refreshCamera()
end

local function onFeedback(kind, rival, roundId, lifeId)
    if state.roundId ~= roundId or state.lifeId ~= lifeId then return end
    if kind == "hit" then
        view.notify("✓  BAJA  ·  " .. rival, true)
        playSound(confirmed, .82)
    elseif kind == "limited" then
        view.notify("ESPERA ANTES DE REINTENTAR", false)
    else
        view.notify("INTENTO FALLIDO", false)
        playSound(miss, .25)
    end
end

network.Update.OnClientEvent:Connect(function(kind, ...)
    if kind == "state" then
        onState(...)
    elseif kind == "plates" then
        local roundId, lifeId, updates, reset = ...
        if state.roundId == roundId and state.lifeId == lifeId and state.phase == "playing" and state.status == "alive" then
            applyPlates(updates, reset)
        end
    elseif kind == "feedback" then
        onFeedback(...)
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
local function keyPressed(input)
    local key = input.KeyCode
    if key == Enum.KeyCode.Escape then
        clearInput()
        return
    end
    if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then return end
    if key == Enum.KeyCode.M and view.modal ~= "how" then
        openModal(if view.modal then nil else "settings")
        return
    end
    local practice = view.modal == "how"
    if not practice and (view.modal or state.phase ~= "playing" or not state.participating
        or state.status ~= "alive" or workspace:GetServerTimeNow() < state.protectedUntil) then return end
    local digit = numberKeys[key]
    if down[key] or (not digit and key ~= Enum.KeyCode.Backspace) then return end
    down[key] = true
    local now = os.clock()
    local display, completed
    if digit then
        display, completed = InputBuffer.push(inputBuffer, digit, now)
    else
        display = InputBuffer.erase(inputBuffer, now)
    end

    receiptUntil = if completed then now + (if practice then Config.InputTimeout else .12) else 0
    view.digits(display)
    if practice then
        local message
        if completed then
            local correct = completed == "0917"
            message = if correct then "✓  Código correcto. Ya puedes jugar." else "Inténtalo otra vez."
            playSound(if correct then confirmed else miss, .53)
        end
        view.practice(display, message)
    elseif completed then
        network.SubmitCode:FireServer(state.roundId, state.lifeId, completed)
    end
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
    if not next(plates) then return end
    debug.profilebegin("Umbral.PlatesClient")
    local origin = camera.CFrame.Position
    local model = player.Character
    local root = model and model:FindFirstChild("HumanoidRootPart")
    local head = model and model:FindFirstChild("Head")
    local rendering = state.phase == "playing" and state.status == "alive" and not view.modal and not GuiService.MenuIsOpen
    local observer = if rendering and root and head then Geometry.pose(root, head) else nil
    for id, plate in plates do
        local visible = false
        if observer then
            local playerTarget = Players:GetPlayerByUserId(id)
            local character = playerTarget and playerTarget.Character
            local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
            local targetHead = character and character:FindFirstChild("Head")
            if targetRoot and targetHead then
                local target = Geometry.withPlate(Geometry.pose(targetRoot, targetHead), targetHead.Size.Z)
                local _, inFrame = camera:WorldToViewportPoint(target.plate.Position)
                visible = inFrame and target.plate.LookVector:Dot(origin - target.plate.Position) > 0
                    and Geometry.eligible(observer, target, cover)
                if visible then plate.part.CFrame = target.plate end
            end
        end
        if plate.gui.Enabled ~= visible then plate.gui.Enabled = visible end
    end
    debug.profileend()
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
        if InputBuffer.expire(inputBuffer, now) or (receiptUntil > 0 and now >= receiptUntil) then clearInput() end
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
