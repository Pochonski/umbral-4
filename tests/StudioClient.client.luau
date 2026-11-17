local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("UmbralNetwork")
local bridge = ReplicatedStorage:WaitForChild("UmbralQABridge")

network.State.OnClientEvent:Connect(function(state) bridge:FireServer("state", state) end)
network.Plates.OnClientEvent:Connect(function(_, _, updates, reset) bridge:FireServer("plates", updates, reset) end)
network.Feedback.OnClientEvent:Connect(function(kind) bridge:FireServer("feedback", kind) end)
bridge.OnClientEvent:Connect(function(action, round, life, code)
    if action == "ready" then
        network.Request:FireServer("ready", true)
    elseif action == "attack" then
        network.SubmitCode:FireServer(round, life, code)
    elseif action == "repeat" then
        network.SubmitCode:FireServer(round, life, code)
        network.SubmitCode:FireServer(round, life, code)
    end
end)

local gui = player.PlayerGui:WaitForChild("Umbral4", 12)
assert(gui and #gui:GetChildren() == 5, "Client UI failed to initialize")
task.wait(.35)
bridge:FireServer("registered")
