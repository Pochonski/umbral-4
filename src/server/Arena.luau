--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage.UmbralShared.Config)
local Geometry = require(ReplicatedStorage.UmbralShared.Geometry)
local Maps = require(ReplicatedStorage.UmbralShared.Maps)
local world = workspace:WaitForChild("UmbralWorld")
local templates = ServerStorage:FindFirstChild("UmbralMapTemplates")
assert(templates, "Missing map templates: rebuild the place with default.project.json before syncing scripts")
local original = world:FindFirstChild("EstacionDeRelevo")
-- Preserve the approved source model; only its runtime copy is replaced.
if original then
    if not templates:FindFirstChild("EstacionDeRelevo") then
        local recovery=original:Clone()
        local exterior=world:FindFirstChild("Complejo exterior")
        if exterior then exterior:Clone().Parent=recovery end
        recovery.Parent=templates
    end
    local exterior=world:FindFirstChild("Complejo exterior")
    if exterior then exterior:Destroy() end
    original:Destroy()
end
local container = world:FindFirstChild("ActiveArena")
if not container then
    container = Instance.new("Folder")
    container.Name = "ActiveArena"
    container.Parent = world
end
local lobbyMarker = world:WaitForChild("Vestibulo"):WaitForChild("Arrival") :: BasePart
local Arena = {
    map = container, raycast = Geometry.coverParams(container), lobby = lobbyMarker.CFrame,
    id = container:GetAttribute("MapId") or "", revision = container:GetAttribute("Revision") or 0, spawns = {} :: {BasePart},
    boundsTransform = CFrame.identity, boundsHalfSize = Vector3.zero,
}
local function prepare(id: string)
    local entry
    for _, candidate in Maps do if candidate.id == id then entry = candidate; break end end
    assert(entry, "Unknown map ID")
    local template = templates:FindFirstChild(entry.model)
    assert(template and template:IsA("Model"), "Missing map template")
    local bounds = template:FindFirstChild("PlayableBounds")
    assert(bounds and bounds:IsA("BasePart"), "Missing PlayableBounds")
    assert(bounds.Anchored and not bounds.CanCollide and not bounds.CanQuery and not bounds.CanTouch,
        "PlayableBounds must be anchored and non-interactive")
    local markers = template:FindFirstChild("Spawns")
    assert(markers and markers:IsA("Folder"), "Missing Spawns")
    local halfSize = bounds.Size * .5
    assert(halfSize.X > 0 and halfSize.Y > 0 and halfSize.Z > 0, "Empty bounds")
    for _, item in template:GetDescendants() do
        assert(not item:IsA("LuaSourceContainer"), "Map templates cannot contain scripts")
        if item:IsA("BasePart") then assert(item.Anchored, "Unanchored map geometry") end
    end
    assert(#markers:GetChildren() >= Config.MaxPlayers, "Insufficient spawns")
    for _, marker in markers:GetChildren() do
        assert(marker:IsA("BasePart") and not marker.CanCollide and not marker.CanQuery,
            "Invalid spawn marker")
        assert(Geometry.inBounds(marker.Position, bounds.CFrame, halfSize), "Spawn outside bounds")
    end
    return template:Clone(), bounds.CFrame, halfSize
end
function Arena.activate(id: string): (boolean, string)
    local ok, model, transform, halfSize = pcall(prepare, id)
    if not ok then
        warn("[Umbral Maps] Invalid map", id, model)
        if id == "relevo" then return false, tostring(model) end
        return Arena.activate("relevo")
    end
    -- No yielding between removal and parenting. Characters must be in the lobby first.
    container:ClearAllChildren()
    model.Parent = container
    Arena.spawns = {}
    for _, marker in model.Spawns:GetChildren() do table.insert(Arena.spawns, marker) end
    table.sort(Arena.spawns, function(a, b) return a.Name < b.Name end)
    Arena.boundsTransform, Arena.boundsHalfSize = transform, halfSize
    Arena.id, Arena.revision = id, Arena.revision + 1
    container:SetAttribute("MapId", id)
    container:SetAttribute("Revision", Arena.revision)
    return true, id
end
local existing = container:FindFirstChildWhichIsA("Model")
if existing and existing:FindFirstChild("PlayableBounds") and existing:FindFirstChild("Spawns") then
    Arena.boundsTransform = existing.PlayableBounds.CFrame
    Arena.boundsHalfSize = existing.PlayableBounds.Size * .5
    for _, marker in existing.Spawns:GetChildren() do table.insert(Arena.spawns, marker) end
    table.sort(Arena.spawns, function(a,b) return a.Name < b.Name end)
else
    assert(Arena.activate(Config.StartMap))
end

function Arena.inBounds(position: Vector3): boolean
    return Geometry.inBounds(position, Arena.boundsTransform, Arena.boundsHalfSize)
end

function Arena.choose(enemies: {BasePart}, previous: BasePart?, random: Random): BasePart
    local best = Arena.spawns[1]
    local bestOccupied, bestExposure, bestDistance = math.huge, math.huge, -math.huge
    local start = random:NextInteger(1, #Arena.spawns)
    for offset = 0, #Arena.spawns - 1 do
        local marker = Arena.spawns[((start + offset - 1) % #Arena.spawns) + 1]
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
