-- Run in the Edit data model of a Rojo build, using Studio MCP or the command bar.
local pathfinder = game:GetService("PathfindingService")
local geometry = require(game.ReplicatedStorage.UmbralShared.Geometry)
local arena = workspace.UmbralWorld.EstacionDeRelevo
local bounds = arena.PlayableBounds
local rays = geometry.coverParams(arena)
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = {arena}
local result = {spawns = 0, closeToBeacon = 0, paths = {}, sight = {}}

for _, marker in arena.Spawns:GetChildren() do
    assert(geometry.inBounds(marker.Position, bounds.CFrame, bounds.Size * 0.5), marker.Name)
    local ground = workspace:Raycast(marker.Position, Vector3.new(0, -4, 0), rays)
    assert(ground and ground.Instance.Name == "Losa", marker.Name .. " has no arena floor")
    local clearance = workspace:GetPartBoundsInBox(marker.CFrame, Vector3.new(2, 5.4, 2), overlap)
    if #clearance > 0 then
        assert(marker.Name == "Spawn 03" and #clearance <= 2, marker.Name .. " has a blocker at avatar height")
        for _, part in clearance do
            assert(part.Name == "Base de baliza" or part.Name == "Baliza de ruta", part.Name)
            result.closeToBeacon += 1
        end
    end
    result.spawns += 1
end
assert(result.spawns == 12)

local routes = {
    {"west gallery", Vector3.new(-38, 1, 0), Vector3.new(-23.5, 1, 0)},
    {"east gallery", Vector3.new(23.5, 1, 0), Vector3.new(38, 1, 0)},
    {"south corridor", Vector3.new(-23, 1, 41), Vector3.new(23, 1, 41)},
    {"north corridor", Vector3.new(23, 1, -41), Vector3.new(-23, 1, -41)},
}
for _, x in {-31, 31} do
    for _, z in {-31, 31} do
        table.insert(routes, {string.format("ramp %d/%d", x, z), Vector3.new(x, 1, z), Vector3.new(x, 6.7, 0)})
    end
end
for _, route in routes do
    local path = pathfinder:CreatePath({AgentRadius = 1.5, AgentHeight = 4.0, AgentCanJump = false})
    path:ComputeAsync(route[2], route[3])
    assert(path.Status == Enum.PathStatus.Success, route[1] .. " path: " .. path.Status.Name)
    result.paths[route[1]] = #path:GetWaypoints()
end

local clear = {eye = Vector3.new(2.5, 5.1, 40), facing = -Vector3.zAxis}
local target = geometry.withPlate({eye = Vector3.new(2.5, 5.1, 26), facing = Vector3.zAxis}, 1)
result.sight.frontal = geometry.eligible(clear, target, rays)
assert(result.sight.frontal, "The shared combat rule cannot see the frontal target")
local rear = geometry.withPlate({eye = target.eye, facing = -Vector3.zAxis}, 1)
result.sight.rear = geometry.eligible(clear, rear, rays)
assert(not result.sight.rear)
local covered = {eye = Vector3.new(0, 3.5, 5), facing = -Vector3.zAxis}
local opposite = geometry.withPlate({eye = Vector3.new(0, 3.5, -5), facing = Vector3.zAxis}, 1)
result.sight.behindCover = geometry.eligible(covered, opposite, rays)
assert(not result.sight.behindCover)
return result
