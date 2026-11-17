local players = game:GetService("Players")
local runService = game:GetService("RunService")
local storage = game:GetService("ReplicatedStorage")
local inputService = game:GetService("UserInputService")
if not runService:IsStudio() then return end

local player = players.LocalPlayer
local network = storage:WaitForChild("UmbralNetwork")
local bridge = storage:WaitForChild("RelevoFinalQA")
local state
local aim
local digits = {"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
network.Update.OnClientEvent:Connect(function(kind, ...)
    if kind == "state" then
        state = ...
        bridge:FireServer("state", state)
    elseif kind == "plates" or kind == "feedback" then
        bridge:FireServer(kind, ...)
    end
end)

runService:BindToRenderStep("RelevoFinalQA", Enum.RenderPriority.Camera.Value, function()
    local head = player.Character and player.Character:FindFirstChild("Head")
    if aim and head then
        local camera = workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(head.Position, aim)
        camera.Focus = CFrame.new(aim)
        for _, object in player.Character:GetDescendants() do
            if object:IsA("BasePart") then object.LocalTransparencyModifier = 1 end
        end
    end
end)

bridge.OnClientEvent:Connect(function(command, value)
    if command == "ready" then
        network.Request:FireServer("sync")
        network.Request:FireServer("ready", true)
    elseif command == "aim" then
        aim = value
    elseif command == "observe" then
        local enabled = false
        for _, part in workspace.UmbralLocalPlates:GetChildren() do
            local gui = part:FindFirstChildOfClass("SurfaceGui")
            local text = gui and gui:FindFirstChildOfClass("TextLabel")
            if gui and gui.Enabled and text and text.Text == value then enabled = true end
        end
        bridge:FireServer("observed", enabled)
    elseif command == "attack" then
        network.SubmitCode:FireServer(state.roundId, state.lifeId, value)
    elseif command == "keyboard" then
        local ok, failure = pcall(function()
            local input = assert(inputService:CreateVirtualInput(), "VirtualInput unavailable")
            for index = 1, #value do
                local key = Enum.KeyCode["Keypad" .. digits[tonumber(value:sub(index, index)) + 1]]
                input:SendKey(true, key, false)
                task.wait(.045)
                input:SendKey(false, key, false)
                task.wait(.045)
            end
        end)
        bridge:FireServer("keyboard", ok, tostring(failure))
    end
end)

assert(player.PlayerGui:WaitForChild("Umbral4", 15))
bridge:FireServer("registered")
