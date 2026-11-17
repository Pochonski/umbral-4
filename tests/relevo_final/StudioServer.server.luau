local players = game:GetService("Players")
local runService = game:GetService("RunService")
local storage = game:GetService("ReplicatedStorage")
local tests = game:GetService("StudioTestService")
local json = game:GetService("HttpService")
if not runService:IsStudio() then return end

local geometry = require(storage.UmbralShared.Geometry)
local arena = workspace.UmbralWorld.EstacionDeRelevo
local full = geometry.coverParams(arena)
local bridge = Instance.new("RemoteEvent")
bridge.Name = "RelevoFinalQA"
local peers, originalParts, relief = {}, {}, {}
for _, object in arena:GetDescendants() do
    if object:IsA("BasePart") and object.CanQuery then
        table.insert(if object.CanCollide then originalParts else relief, object)
    end
end
local original = geometry.coverParams(arena)
original.FilterDescendantsInstances = originalParts

bridge.OnServerEvent:Connect(function(player, action, a, b, c, d)
    local peer = peers[player]
    if not peer then
        peer = {player = player, plates = {}, feedback = {}}
        peers[player] = peer
    end
    if action == "registered" then
        peer.registered = true
    elseif action == "state" then
        peer.state = a
    elseif action == "plates" then
        if d then table.clear(peer.plates) end
        for _, item in c do peer.plates[item.userId] = item.code end
    elseif action == "feedback" then
        table.insert(peer.feedback, a)
    elseif action == "observed" then
        peer.observed = a
    elseif action == "keyboard" then
        peer.keyboard = {ok = a, reason = b}
    end
end)
bridge.Parent = storage

local function await(label, predicate, timeout)
    local deadline = os.clock() + (timeout or 8)
    repeat
        local value = predicate()
        if value then return value end
        task.wait(.04)
    until os.clock() >= deadline
    error("Timed out: " .. label, 2)
end

local function send(peer, ...)
    bridge:FireClient(peer.player, ...)
end

local function alive(peer, round)
    return peer.state and peer.state.phase == "playing" and peer.state.roundId == round
        and peer.state.status == "alive" and peer.state.protectedUntil <= workspace:GetServerTimeNow()
end

local function place(peer, eye, other)
    local avatar = assert(peer.player.Character)
    local head = avatar:FindFirstChild("Head")
    local root = avatar:FindFirstChild("HumanoidRootPart")
    root.Anchored = true
    local pivot = eye - Vector3.yAxis * (head.Position.Y - avatar:GetPivot().Position.Y)
    local facing = Vector3.new(other.X - eye.X, 0, other.Z - eye.Z)
    avatar:PivotTo(CFrame.lookAlong(pivot, facing.Unit))
    return geometry.withPlate(geometry.pose(root, head), head.Size.Z)
end

local function positioned(a, b, from, to)
    local eyeA, eyeB = place(a, from, to), place(b, to, from)
    return eyeA, eyeB
end

local function aim(observer, target)
    local head = target.player.Character.Head
    send(observer, "aim", head.Position + Vector3.yAxis * .22)
end

local function getCode(a, b)
    return a.plates[b.player.UserId]
end

local function observe(a, code)
    a.observed = nil
    send(a, "observe", code)
    await("client SurfaceGui observation", function() return a.observed ~= nil end)
    return a.observed
end

local function fire(a, code, how)
    local count = #a.feedback
    a.keyboard = nil
    send(a, how or "attack", code)
    if how == "keyboard" then
        local keyboard = await("physical input simulation", function() return a.keyboard end)
        assert(keyboard.ok, keyboard.reason)
    end
    return await("attack feedback", function() return a.feedback[count + 1] end)
end

local cases = {
    {name = "cell corner", axis = "X", edge = 3, side = 1, first = -5.5, last = 5,
        heights = {4.10, 3.86, 3.32, 3.10}, relief = true},
    {name = "power doors", axis = "X", edge = -22.5, side = 1, first = 3.2, last = 22.7,
        heights = {4.16, 3.82, 3.24, 2.74}, relief = true},
    {name = "cooling fans", axis = "Z", edge = 42.5, side = -1, first = -10.4, last = 8.5,
        heights = {4.15, 3.89, 3.28, 2.68}, relief = true},
    {name = "gallery column", axis = "X", edge = -8.8, side = 1, first = -38, last = -23.0,
        heights = {3.74, 3.45}, relief = false},
}

local function points(case, height, distance)
    local cross = case.edge + case.side * distance
    if case.axis == "X" then
        return Vector3.new(case.first, height, cross), Vector3.new(case.last, height, cross)
    end
    return Vector3.new(cross, height, case.first), Vector3.new(cross, height, case.last)
end

local function edgeRun(a, b)
    await("two active avatars", function() return alive(a, 1) and alive(b, 1) end, 25)
    for index, case in cases do
        local hidden, open
        local margins = if case.relief then {.20, .16, .12, .085, .045} else {-.75, -.50}
        for _, height in case.heights do
            local from, to = points(case, height, 1.1)
            local eyeA, eyeB = positioned(a, b, from, to)
            if not geometry.eligible(eyeA, eyeB, full) then continue end
            for _, margin in margins do
                local behindFrom, behindTo = points(case, height, margin)
                local behindA, behindB = positioned(a, b, behindFrom, behindTo)
                local originalAllows = geometry.eligible(behindA, behindB, original)
                if originalAllows == case.relief and not geometry.eligible(behindA, behindB, full) then
                    local hit = workspace:Raycast(behindA.eye, behindB.eye - behindA.eye, full)
                        or workspace:Raycast(behindA.eye, behindB.plate.Position - behindA.eye, full)
                    hidden, open = {behindFrom, behindTo, hit.Instance.Name, margin}, {from, to}
                    break
                end
            end
            if hidden then break end
        end
        assert(hidden, "No geometrically valid test position for " .. case.name)
        positioned(a, b, table.unpack(open))
        aim(a, b)
        local code = await("open code in " .. case.name, function() return getCode(a, b) end)
        task.wait(.30)
        assert(observe(a, code), case.name .. " showed no plate with stable open sight")
        positioned(a, b, hidden[1], hidden[2])
        aim(a, b)
        await("code revoked in " .. case.name, function() return not getCode(a, b) end)
        assert(not observe(a, code), case.name .. " kept rendering a blocked plate")
        assert(fire(a, code) == "miss" and b.state.status == "alive", case.name .. " accepted a hidden rival")
        positioned(a, b, table.unpack(open))
        aim(a, b)
        await("open again in " .. case.name, function() return getCode(a, b) == code end)
        task.wait(.30)
        assert(observe(a, code), case.name .. " failed to show the reopened plate")
        assert(fire(a, code, if index == #cases then "keyboard" else "attack") == "hit",
            case.name .. " unexpectedly rejected the visible plate")
        await("respawn after " .. case.name, function() return alive(b, 1) end)
        print("[RELEVO EDGE] " .. json:JSONEncode({
            sector = case.name, blocker = hidden[3], margin = hidden[4],
            originalAllows = case.relief, hidden = "miss", visible = "hit",
            from = tostring(hidden[1]), to = tostring(hidden[2]),
        }))
    end
end

local function profileRun(a, b)
    local from, to = Vector3.new(4.55, 4.35, 9.6), Vector3.new(4.55, 4.35, -4.4)
    for round, enabled in {false, true, true, false} do
        for _, part in relief do part.CanQuery = enabled end
        await("active profiling round " .. round, function() return alive(a, round) and alive(b, round) end, 50)
        local started = workspace:GetServerTimeNow()
        local kills = 0
        for step = 1, 19 do
            if not alive(a, round) or not alive(b, round) then break end
            local target = to + Vector3.xAxis * (.6 * math.sin(step * .8))
            positioned(a, b, from, target)
            aim(a, b)
            if step == 7 or step == 14 then
                local code = await("profile attack has a live grant", function() return getCode(a, b) end, 3)
                assert(fire(a, code) == "hit", "profile attack missed")
                kills += 1
                await("profile respawn", function() return alive(b, round) end)
            end
            task.wait(.54)
        end
        assert(kills == 2)
        await("end of profiling round " .. round, function()
            return a.state.roundId == round and a.state.phase == "results"
        end, 40)
        print("[RELEVO PROFILE] " .. json:JSONEncode({
            round = round, reliefQueries = enabled, relief = #relief, kills = kills,
            seconds = workspace:GetServerTimeNow() - started,
        }))
    end
end

local args = tests:GetTestArgs()
local ok, failure = pcall(function()
    assert(#relief == 389, "Unexpected relief inventory")
    local group = await("two Studio clients", function()
        local found = {}
        for _, peer in peers do if peer.registered then table.insert(found, peer) end end
        if #found == 2 then return found end
    end, 50)
    table.sort(group, function(a, b) return a.player.UserId < b.player.UserId end)
    for _, peer in group do send(peer, "ready") end
    if args and args.profile then profileRun(group[1], group[2]) else edgeRun(group[1], group[2]) end
end)
for _, part in relief do part.CanQuery = true end
local summary = if ok then "PASS" else "FAIL " .. tostring(failure)
print("[RELEVO FINAL QA] " .. summary)
tests:EndTest(summary)
