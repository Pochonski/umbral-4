-- Execute in Edit on both builds, with no playtest running.
local shared = game.ReplicatedStorage.UmbralShared
local geometry = require(shared.Geometry)
local config = require(shared.Config)
local arena = workspace.UmbralWorld.EstacionDeRelevo
local params = geometry.coverParams(arena)
local random = Random.new(4117)
local origins, destinations = {}, {}
local function eye()
    local x, z = random:NextNumber(-53, 53), random:NextNumber(-43, 43)
    return Vector3.new(x, random:NextNumber(3.7, 10.2), z)
end
while #origins < 1536 do
    local a, b = eye(), eye()
    local distance = (a - b).Magnitude
    if distance > 4 and distance < config.Range then
        table.insert(origins, a)
        table.insert(destinations, b)
    end
end

local function batch()
    local blocked = 0
    local started = os.clock()
    for index, a in origins do
        if geometry.covered(a, destinations[index], params) then
            blocked += 1
        end
    end
    return (os.clock() - started) * 1e6 / #origins, blocked
end

batch()
local times = {}
local blocked
for index = 1, 11 do
    task.wait()
    times[index], blocked = batch()
end
table.sort(times)
return {raysPerBatch = #origins, batches = #times, blocked = blocked, medianUs = times[6], maxUs = times[#times]}
