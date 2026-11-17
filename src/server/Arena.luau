--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Geometry = require(ReplicatedStorage.UmbralShared.Geometry)

local world = workspace:WaitForChild("UmbralWorld")
local map = world:WaitForChild("EstacionDeRelevo") :: Model
local lobby = world:WaitForChild("Vestibulo")
local markers = map:WaitForChild("Spawns")
local lobbyMarker = lobby:WaitForChild("Arrival") :: BasePart
local bounds = map:GetBoundingBox()
local spawns: {BasePart} = {}
for _, marker in markers:GetChildren() do
    assert(marker:IsA("BasePart"), "Spawn marker must be a part")
    table.insert(spawns, marker)
end
assert(#spawns >= 12, "Estación de Relevo needs at least 12 spawn markers")
table.sort(spawns, function(a, b) return a.Name < b.Name end)

local Arena = {
    map = map,
    raycast = Geometry.coverParams(map),
    lobby = lobbyMarker.CFrame,
}

function Arena.inBounds(position: Vector3): boolean
    local origin = bounds.Position
    return math.abs(position.X - origin.X) <= 61
        and math.abs(position.Z - origin.Z) <= 52
        and position.Y >= -20 and position.Y <= 48
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
            if difference < 45 and not Geometry.covered(enemy.Position, marker.Position + Vector3.yAxis, Arena.raycast) then
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
