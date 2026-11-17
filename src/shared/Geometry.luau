--!strict
local Config = require(script.Parent.Config)
local Geometry = {}

export type Pose = { eye: Vector3, facing: Vector3 }
export type TargetPose = { eye: Vector3, facing: Vector3, plate: CFrame }

local function horizontal(vector: Vector3): Vector3
    local flat = Vector3.new(vector.X, 0, vector.Z)
    if flat.Magnitude < 0.001 then return Vector3.zero end
    return flat.Unit
end

function Geometry.pose(root: BasePart, head: BasePart): Pose
    return { eye = head.Position, facing = horizontal(root.CFrame.LookVector) }
end

function Geometry.withPlate(pose: Pose, headDepth: number): TargetPose
    local facing = pose.facing
    local center = pose.eye
        + Vector3.new(0, Config.PlateVerticalOffset, 0)
        + facing * (headDepth * 0.5 + Config.PlateForwardOffset)
    local plate = if facing == Vector3.zero then CFrame.new(center) else CFrame.lookAlong(center, facing)
    return { eye = pose.eye, facing = facing, plate = plate }
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

function Geometry.inBounds(position: Vector3, transform: CFrame, halfSize: Vector3): boolean
    local point = transform:PointToObjectSpace(position)
    return math.abs(point.X) <= halfSize.X and math.abs(point.Y) <= halfSize.Y and math.abs(point.Z) <= halfSize.Z
end

function Geometry.eligible(attacker: Pose, target: TargetPose, geometry: RaycastParams): (boolean, number)
    local difference = target.eye - attacker.eye
    if difference.Magnitude > Config.Range then return false, 0 end
    local direction = horizontal(difference)
    if direction == Vector3.zero then return false, 0 end
    if attacker.facing:Dot(direction) < Config.AttackerFacing then return false, 0 end
    if target.facing:Dot(-direction) < Config.TargetFacing then return false, 0 end
    if Geometry.covered(attacker.eye, target.eye, geometry) then return false, 1 end
    return not Geometry.covered(attacker.eye, target.plate.Position, geometry), 2
end

return Geometry
