--!strict
local Config = require(script.Parent.Config)
local Geometry = {}

local function horizontal(vector: Vector3): Vector3
    local flat = Vector3.new(vector.X, 0, vector.Z)
    if flat.Magnitude < 0.001 then return Vector3.zero end
    return flat.Unit
end

function Geometry.plateCFrame(root: BasePart, head: BasePart): CFrame
    local facing = horizontal(root.CFrame.LookVector)
    local center = head.Position
        + Vector3.new(0, Config.PlateVerticalOffset, 0)
        + facing * (head.Size.Z * 0.5 + Config.PlateForwardOffset)
    if facing == Vector3.zero then return CFrame.new(center) end
    return CFrame.lookAlong(center, facing)
end

function Geometry.covered(origin: Vector3, destination: Vector3, geometry: RaycastParams): boolean
    return workspace:Raycast(origin, destination - origin, geometry) ~= nil
end

function Geometry.coverParams(map: Instance): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { map }
    params.IgnoreWater = true
    return params
end

function Geometry.eligible(
    attackerRoot: BasePart, attackerHead: BasePart, targetRoot: BasePart, targetHead: BasePart,
    geometry: RaycastParams
): boolean
    local difference = targetHead.Position - attackerHead.Position
    if difference.Magnitude > Config.Range then return false end
    local direction = horizontal(difference)
    if direction == Vector3.zero then return false end
    if horizontal(attackerRoot.CFrame.LookVector):Dot(direction) < Config.AttackerFacing then return false end
    if horizontal(targetRoot.CFrame.LookVector):Dot(-direction) < Config.TargetFacing then return false end
    return not Geometry.covered(attackerHead.Position, targetHead.Position, geometry)
        and not Geometry.covered(attackerHead.Position, Geometry.plateCFrame(targetRoot, targetHead).Position, geometry)
end

return Geometry
