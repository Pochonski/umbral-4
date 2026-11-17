-- Execute in the Edit model of a Rojo build. The scratch folder is removed after the audit.
local physicalArena = workspace.UmbralWorld.EstacionDeRelevo
local geometry = require(game.ReplicatedStorage.UmbralShared.Geometry)
local physicalRays = geometry.coverParams(physicalArena)
local cameraReplica = Instance.new("Folder")
cameraReplica.Name = "QA Area Visibility"
local sourceNames = {}
local result = {rays = 0, visualOnly = 0, queryOnly = 0, blockers = {}, examples = {},
    relief = 0, maxReliefOverhang = 0}

local function isOpaque(part)
    return part:IsA("BasePart") and part.Transparency < .35
end

local function audit()
    local solid = {}
    for _, part in physicalArena:GetDescendants() do
        if part:IsA("Part") and part.CanCollide and part.Shape == Enum.PartType.Block then
            table.insert(solid, part)
        end
    end
    for _, part in physicalArena:GetDescendants() do
        if isOpaque(part) then
            if part.CanQuery and not part.CanCollide then
                local corners = {}
                for _, x in {-1, 1} do
                    for _, y in {-1, 1} do
                        for _, z in {-1, 1} do
                            table.insert(corners, part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * .5))
                        end
                    end
                end
                local best = math.huge
                for _, support in solid do
                    local half = support.Size * .5
                    local maxGap = 0
                    for _, corner in corners do
                        local p = support.CFrame:PointToObjectSpace(corner)
                        maxGap = math.max(maxGap, math.abs(p.X) - half.X, math.abs(p.Y) - half.Y, math.abs(p.Z) - half.Z)
                    end
                    best = math.min(best, maxGap)
                end
                assert(not part.CanTouch and part.Anchored and best <= .30,
                    string.format("%s extends %.3f studs beyond its backing", part:GetFullName(), best))
                result.relief += 1
                result.maxReliefOverhang = math.max(result.maxReliefOverhang, best)
            end
            local copy = part:Clone()
            copy:ClearAllChildren()
            copy.Anchored = true
            copy.CanCollide, copy.CanTouch, copy.CanQuery = false, false, true
            copy.Transparency = 1
            copy.Parent = cameraReplica
            sourceNames[copy] = part.Name
        end
    end
    cameraReplica.Parent = workspace
    local visualRays = geometry.coverParams(cameraReplica)
    local function compare(a, b, label)
        result.rays += 1
        local direction = b - a
        local server = workspace:Raycast(a, direction, physicalRays)
        local rendered = workspace:Raycast(a, direction, visualRays)
        if rendered and not server then
            result.visualOnly += 1
            local name = sourceNames[rendered.Instance]
            result.blockers[name] = (result.blockers[name] or 0) + 1
            if result.blockers[name] == 1 then
                table.insert(result.examples, {part = name, label = label, from = tostring(a), to = tostring(b)})
            end
        elseif server and not rendered then
            result.queryOnly += 1
        end
    end

    -- Deliberate cross-gallery and grazing rays at standing and jumping eye/plate heights.
    for _, x in {-31, 31} do
        for _, z in {-11.5, -10, -9.5, -6, -3.7, -1, 0, 1, 5.4, 7, 9.5, 10, 11.5} do
            for _, height in {3.8, 4.25, 4.45, 4.55, 4.62, 4.68, 4.79, 5.9, 7.4, 8.4, 8.6, 8.8, 9.6} do
                compare(Vector3.new(x - 8, height, z), Vector3.new(x + 8, height + .015, z), "gallery")
            end
        end
    end
    local housings = {
        {0, 0, 6, 6}, {-12, -12, 13, 9}, {12, 12, 13, 9}, {-13, 26, 15, 7},
        {13, -26, 15, 7}, {-46, 1, 7, 13}, {46, -1, 7, 13},
    }
    for _, box in housings do
        local x, z, width, depth = table.unpack(box)
        for _, sign in {-1, 1} do
            for _, height in {1.65, 2.55, 3.4, 3.8, 4.25, 4.65, 5.05, 5.6, 6.2, 6.55} do
                for _, margin in {.015, .05, .12, .20, .32, .52, .9, 1.2} do
                    local sideZ = z + sign * (depth / 2 + margin)
                    compare(Vector3.new(x - width / 2 - 2, height, sideZ),
                        Vector3.new(x + width / 2 + 2, height + .04, sideZ), "façade tangent")
                    local sideX = x + sign * (width / 2 + margin)
                    compare(Vector3.new(sideX, height, z - depth / 2 - 2),
                        Vector3.new(sideX, height + .04, z + depth / 2 + 2), "façade tangent")
                end
            end
        end
    end

    -- Seeded lanes between standing and airborne eye points on playable floor and decks.
    local random = Random.new(2704)
    local sample = {}
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances = {physicalArena}
    for _ = 1, 580 do
        local x, z = random:NextNumber(-53, 53), random:NextNumber(-43, 43)
        local down = workspace:Raycast(Vector3.new(x, 17, z), Vector3.new(0, -19, 0), physicalRays)
        if down then
            local p = down.Position + Vector3.new(0, random:NextNumber(3.8, 6.2), 0)
            if #workspace:GetPartBoundsInBox(CFrame.new(p), Vector3.new(.85, 1.1, .85), overlap) == 0 then
                table.insert(sample, p)
            end
        end
    end
    for _ = 1, 12500 do
        local a, b = sample[random:NextInteger(1, #sample)], sample[random:NextInteger(1, #sample)]
        local distance = (a - b).Magnitude
        if distance > 4 and distance < 50 then compare(a, b, "seeded lane") end
    end
end

local ok, failure = pcall(audit)
cameraReplica:Destroy()
assert(ok, failure)
return result
