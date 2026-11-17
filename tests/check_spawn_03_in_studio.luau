-- Execute on the Client of a single-player Studio Play session.
local localPlayer = game.Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local arena = workspace.UmbralWorld.EstacionDeRelevo
local marker = arena.Spawns["Spawn 03"]
local controls = require(localPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local previous = character:GetPivot()
local routes = {
    {"+X", Vector3.xAxis},
    {"+Z", Vector3.zAxis},
    {"toward beacon", Vector3.new(-1, 0, -1).Unit},
}
local result = {}
controls:Disable()
local ok, failure = pcall(function()
    for _, route in routes do
        character:PivotTo(marker.CFrame)
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(.38)
        local from = root.Position
        local goal = from + route[2] * 5
        humanoid:MoveTo(goal)
        task.wait(1.20)
        humanoid:MoveTo(root.Position)
        local delta = root.Position - from
        result[route[1]] = {
            travelled = math.floor(Vector3.new(delta.X, 0, delta.Z).Magnitude * 100 + .5) / 100,
            remaining = math.floor((root.Position - goal).Magnitude * 100 + .5) / 100,
        }
    end
    assert(result["+X"].travelled > 4 and result["+Z"].travelled > 4, "Spawn 03 has a blocked departure route")
end)
character:PivotTo(previous)
root.AssemblyLinearVelocity = Vector3.zero
controls:Enable()
assert(ok, failure)
return result
