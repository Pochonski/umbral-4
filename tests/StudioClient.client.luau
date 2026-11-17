local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StudioTestService = game:GetService("StudioTestService")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("UmbralNetwork")
local bridge = ReplicatedStorage:WaitForChild("UmbralQABridge")

local hitStarted
local frameSamples = {}
local playing = false
RunService.PreRender:Connect(function(delta)
    if playing and #frameSamples < 600 then table.insert(frameSamples, delta * 1000) end
end)
network.Update.OnClientEvent:Connect(function(kind, ...)
    if kind == "state" then
        local state = ...
        playing = state.phase == "playing" and state.participating
        bridge:FireServer("state", state)
    elseif kind == "plates" then
        local _, _, updates, reset = ...
        bridge:FireServer("plates", updates, reset)
    elseif kind == "feedback" then
        local result = ...
        bridge:FireServer("feedback", result)
        if result == "hit" and hitStarted then
            bridge:FireServer("keyboardLatency", (os.clock() - hitStarted) * 1000)
            hitStarted = nil
        end
    end
end)

local gui = player.PlayerGui:WaitForChild("Umbral4", 12)
assert(gui and #gui:GetChildren() == 5, "Client UI failed to initialize")

local keyNames = {"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"}

local function timedCoveredAttack(code, at, aimAt)
    local input = assert(UserInputService:CreateVirtualInput(), "VirtualInput unavailable")
    local camera = workspace.CurrentCamera
    local oldType, oldFrame = camera.CameraType, camera.CFrame
    local eye = player.Character.Head.Position
    local plates = workspace:WaitForChild("UmbralLocalPlates")
    local function plateVisible()
        for _, part in plates:GetChildren() do
            local surface = part:FindFirstChildOfClass("SurfaceGui")
            local label = surface and surface:FindFirstChildOfClass("TextLabel")
            if label and label.Text == code then return surface.Enabled end
        end
        return false
    end
    local aimBinding = "UmbralQAEdgeCamera"
    RunService:BindToRenderStep(aimBinding, Enum.RenderPriority.Camera.Value, function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(eye, aimAt)
    end)
    local ok, result = pcall(function()
        repeat task.wait() until plateVisible() or workspace:GetServerTimeNow() >= at - .45
        local before = plateVisible()
        local visibleUi = #plates:GetChildren()
        local frameSize = tostring(camera.ViewportSize)
        local function sendDigit(index, pressed)
            local key = Enum.KeyCode["Keypad" .. keyNames[tonumber(code:sub(index, index)) + 1]]
            input:SendKey(pressed, key, false)
        end
        for index = 1, 3 do
            sendDigit(index, true)
            task.wait(.03)
            sendDigit(index, false)
            task.wait(.03)
        end
        while workspace:GetServerTimeNow() < at do task.wait() end
        local atSubmit, when = plateVisible(), workspace:GetServerTimeNow()
        sendDigit(4, true)
        task.wait(.05)
        sendDigit(4, false)
        return {before = before, atSubmit = atSubmit, pressedAt = when, visibleUi = visibleUi, frameSize = frameSize}
    end)
    RunService:UnbindFromRenderStep(aimBinding)
    camera.CameraType = oldType
    camera.CFrame = oldFrame
    if ok then bridge:FireServer("edge", result) else bridge:FireServer("edge", {error = tostring(result)}) end
end

local function virtualKeyboard(code)
    local input = assert(UserInputService:CreateVirtualInput(), "VirtualInput unavailable")
    local function send(pressed, key)
        local ok, reason = pcall(function() input:SendKey(pressed, key, false) end)
        if not ok then error(key.Name .. ": " .. tostring(reason), 0) end
    end
    local function tap(key)
        send(true, key)
        task.wait(.04)
        send(false, key)
        task.wait(.04)
    end
    local function digitKey(index, keypad)
        local name = keyNames[tonumber(code:sub(index, index)) + 1]
        return Enum.KeyCode[if keypad then "Keypad" .. name else name]
    end
    local mainRowUsed, mainRowBlocked = 0, 0
    local function tapDigit(index)
        if index % 2 == 0 then tap(digitKey(index, true)) return end
        local ok, reason = pcall(tap, digitKey(index, false))
        if ok then
            mainRowUsed += 1
        else
            assert(tostring(reason):find("permanently bound", 1, true), tostring(reason))
            mainRowBlocked += 1
            tap(digitKey(index, true))
        end
    end
    local slots = {}
    for _, child in gui.HUD["Entrada"]:GetChildren() do
        if child.Name == "Dígito" then table.insert(slots, child) end
    end
    table.sort(slots, function(a, b) return a.Position.X.Offset < b.Position.X.Offset end)
    assert(#slots == 4, "HUD did not expose four slots")
    local function contents()
        local digits = {}
        for _, slot in slots do
            local value = slot:FindFirstChildOfClass("TextLabel").Text
            if value:match("^%d$") then table.insert(digits, value) end
        end
        return table.concat(digits)
    end

    assert(player.CameraMode == Enum.CameraMode.LockFirstPerson, "combat camera is not first person")
    local minZoom = player.CameraMinZoomDistance
    local observed = "missing"
    local observeM = UserInputService.InputBegan:Connect(function(key, processed)
        if key.KeyCode == Enum.KeyCode.M then observed = tostring(processed) end
    end)
    tap(Enum.KeyCode.M)
    observeM:Disconnect()
    assert(gui.Panel.Visible and player.CameraMode == Enum.CameraMode.Classic, ("settings did not release first person (input processed=%s, panel=%s, camera=%s, menu=%s, focus=%s)"):format(
        observed, tostring(gui.Panel.Visible), player.CameraMode.Name, tostring(GuiService.MenuIsOpen),
        tostring(UserInputService:GetFocusedTextBox())
    ))
    assert(player.CameraMinZoomDistance > minZoom, "settings did not hold a usable zoom")
    tapDigit(1)
    assert(contents() == "", "settings let a digit reach the HUD")
    tap(Enum.KeyCode.M)
    assert(not gui.Panel.Visible and player.CameraMinZoomDistance == minZoom, "settings did not restore the configured zoom")
    assert(player.CameraMode == Enum.CameraMode.LockFirstPerson, "settings did not restore first person")

    tapDigit(1)
    assert(contents() == code:sub(1, 1), "first key did not reach the HUD")
    local focus = Instance.new("TextBox")
    focus.Name = "QAFocus"
    focus.Size = UDim2.fromOffset(100, 40)
    focus.Position = UDim2.fromOffset(24, 112)
    focus.Parent = gui
    focus:CaptureFocus()
    task.wait()
    assert(UserInputService:GetFocusedTextBox() == focus, "the QA text field did not take focus")
    tapDigit(2)
    assert(contents() == "", "text focus did not clear or block combat input")
    focus:ReleaseFocus()
    focus:Destroy()
    task.wait()

    local first = digitKey(1, true)
    send(true, Enum.KeyCode.W)
    send(true, first)
    task.wait(.12)
    send(false, first)
    assert(contents() == code:sub(1, 1), "held digit did not hold its single slot")
    tap(Enum.KeyCode.KeypadOne)
    local correction, blocked = pcall(tap, Enum.KeyCode.Backspace)
    if not correction then
        -- Some Studio versions reserve Backspace for a CoreGui action even with the hotbar hidden.
        assert(tostring(blocked):find("permanently bound", 1, true), tostring(blocked))
        tap(Enum.KeyCode.M)
        tap(Enum.KeyCode.M)
        tap(first)
    end
    assert(contents() == code:sub(1, 1), "backspace did not remove the pending digit")
    tapDigit(2)
    tapDigit(3)
    assert(contents() == code:sub(1, 3), "number keys did not reach the three slots")
    local moving = player.Character:FindFirstChildOfClass("Humanoid").MoveDirection.Magnitude > 0
    hitStarted = os.clock()
    tapDigit(4)
    send(false, Enum.KeyCode.W)
    bridge:FireServer("keyboard", true, {
        movementIntent = moving, backspaceInjected = correction,
        mainRowUsed = mainRowUsed, mainRowBlocked = mainRowBlocked,
    })
end

bridge.OnClientEvent:Connect(function(action, round, life, code, at, aimAt)
    if action == "ready" then
        network.Request:FireServer("sync")
        network.Request:FireServer("ready", true)
    elseif action == "attack" then
        while at and workspace:GetServerTimeNow() < at do task.wait() end
        network.SubmitCode:FireServer(round, life, code)
    elseif action == "repeat" then
        network.SubmitCode:FireServer(round, life, code)
        network.SubmitCode:FireServer(round, life, code)
    elseif action == "spam" then
        for _ = 1, 32 do network.SubmitCode:FireServer(round, life, code) end
    elseif action == "sync" then
        network.Request:FireServer("sync")
    elseif action == "keyboard" then
        local ok, reason = pcall(virtualKeyboard, code)
        if not ok then bridge:FireServer("keyboard", false, tostring(reason)) end
    elseif action == "leave" then
        StudioTestService:LeaveTest()
    elseif action == "frames" then
        table.sort(frameSamples)
        bridge:FireServer("frames", #frameSamples, frameSamples[math.ceil(#frameSamples * .95)])
    elseif action == "ping" then
        bridge:FireServer("pong", round)
    elseif action == "coveredKeyboard" then
        timedCoveredAttack(code, at, aimAt)
    end
end)

task.wait(.35)
bridge:FireServer("registered")
