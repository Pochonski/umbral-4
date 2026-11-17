--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.UmbralShared.Config)
local Geometry = require(ReplicatedStorage.UmbralShared.Geometry)

local world = workspace:WaitForChild("UmbralWorld")
local map = world:WaitForChild(Config.ArenaModel) :: Model
local lobby = world:WaitForChild("Vestibulo")
local markers = map:WaitForChild("Spawns")
local lobbyMarker = lobby:WaitForChild("Arrival") :: BasePart
local bounds = map:FindFirstChild("PlayableBounds")
assert(bounds and bounds:IsA("BasePart"), "The arena needs a PlayableBounds part")
assert(bounds.Anchored and not bounds.CanCollide and not bounds.CanQuery, "PlayableBounds must be anchored and non-queryable")
local boundsTransform, boundsHalfSize = bounds.CFrame, bounds.Size * 0.5
local spawns: {BasePart} = {}
for _, marker in markers:GetChildren() do
    assert(marker:IsA("BasePart"), "Spawn marker must be a part")
    assert(Geometry.inBounds(marker.Position, boundsTransform, boundsHalfSize), marker.Name .. " is outside PlayableBounds")
    table.insert(spawns, marker)
end
assert(#spawns >= Config.MaxPlayers, "The arena needs at least one spawn per player")
table.sort(spawns, function(a, b) return a.Name < b.Name end)

local Arena = {
    map = map,
    raycast = Geometry.coverParams(map),
    lobby = lobbyMarker.CFrame,
}

function Arena.inBounds(position: Vector3): boolean
    return Geometry.inBounds(position, boundsTransform, boundsHalfSize)
end

function Arena.choose(enemies: {BasePart}, previous: BasePart?, random: Random): BasePart
    local best = spawns[1]
    local bestOccupied, bestExposure, bestDistance = math.huge, math.huge, -math.huge
    local start = random:NextInteger(1, #spawns)
    for offset = 0, #spawns - 1 do
        local marker = spawns[((start + offset - 1) % #spawns) + 1]
        if marker == previous then continue end
        local occupied, exposure, distance = 0, 0, math.huge
        for _, enemy in enemies do
            local difference = (enemy.Position - marker.Position).Magnitude
            if difference < 6 then occupied += 1 end
            if difference < Config.Range and not Geometry.covered(enemy.Position, marker.Position + Vector3.yAxis, Arena.raycast) then
                exposure += 1
            end
            distance = math.min(distance, difference)
        end
        if occupied < bestOccupied
            or (occupied == bestOccupied and exposure < bestExposure)
            or (occupied == bestOccupied and exposure == bestExposure and distance > bestDistance) then
            best, bestOccupied, bestExposure, bestDistance = marker, occupied, exposure, distance
        end
    end
    return best
end

return Arena
