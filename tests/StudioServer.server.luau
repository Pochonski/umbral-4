local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")
if not RunService:IsStudio() then return end

local bridge = Instance.new("RemoteEvent")
bridge.Name = "UmbralQABridge"
local peers = {}
bridge.OnServerEvent:Connect(function(player, action, first, second)
    local peer = peers[player]
    if not peer then
        peer = {player = player, plates = {}, replies = {}}
        peers[player] = peer
    end
    if action == "registered" then
        peer.registered = true
    elseif action == "state" then
        peer.state = first
    elseif action == "plates" then
        if second then table.clear(peer.plates) end
        for _, update in first do
            peer.plates[update.userId] = update.code
        end
    elseif action == "feedback" then
        table.insert(peer.replies, first)
    end
end)
bridge.Parent = ReplicatedStorage

local function await(description, callback, seconds)
    local deadline = os.clock() + (seconds or 8)
    repeat
        local value = callback()
        if value then return value end
        task.wait(.04)
    until os.clock() >= deadline
    error("Timed out: " .. description, 2)
end

local function pass(name)
    print("[UMBRAL QA PASS] " .. name)
end

local function place(peer, position, towards)
    local character = assert(peer.player.Character)
    character.HumanoidRootPart.Anchored = true
    character:PivotTo(CFrame.lookAt(position, towards))
end

local function attack(peer, code, action)
    bridge:FireClient(peer.player, action or "attack", peer.state.roundId, peer.state.lifeId, code)
end

local function kills(peer)
    for _, score in peer.state.scores do
        if score.userId == peer.player.UserId then return score.kills end
    end
    return 0
end

local function run()
    local args
    pcall(function() args = StudioTestService:GetTestArgs() end)
    local expected = if type(args) == "number" then args else 2
    local group = await("clients to initialize", function()
        local ready = {}
        for _, peer in peers do if peer.registered then table.insert(ready, peer) end end
        if #ready >= expected then return ready end
    end, 90)
    table.sort(group, function(a, b) return a.player.UserId < b.player.UserId end)
    local attacker, target = group[1], group[2]
    for _, peer in group do bridge:FireClient(peer.player, "ready") end
    await("all ready players enrolled with live characters", function()
        for _, peer in group do
            if not peer.state or peer.state.phase ~= "playing" or peer.state.status ~= "alive" then return end
        end
        return true
    end, 30)
    assert(#attacker.state.scores == expected)
    assert(attacker.state.goal == (if expected < 4 then 10 elseif expected < 6 then 15 else 25))
    pass("lobby, round, score and goal with " .. expected .. " real Studio client processes")

    local a = Vector3.new(-11, 3.4, -34)
    local b = Vector3.new(-5, 3.4, -34)
    local wall = Instance.new("Part")
    wall.Name = "QA Occluder"
    wall.Anchored = true
    wall.Size = Vector3.new(.55, 12, 5)
    wall.Position = (a + b) * .5 + Vector3.new(0, 2, 0)
    wall.Parent = workspace.UmbralWorld.EstacionDeRelevo
    place(attacker, a, b)
    place(target, b, a)
    local targetId = target.player.UserId
    local targetLife = target.state.lifeId
    local now = workspace:GetServerTimeNow()
    assert(math.max(attacker.state.protectedUntil, target.state.protectedUntil) >= now)
    local protectedEnd = math.max(attacker.state.protectedUntil, target.state.protectedUntil)
    task.wait(math.max(0, protectedEnd - now) + .35)
    assert(attacker.plates[targetId] == nil, "Wall leaked a code")
    pass("wall prevents disclosure and spawn protection has a server deadline")

    local side = Vector3.new(-4.5, 3.4, -41.5)
    local opposite = Vector3.new(5.5, 3.4, -41.5)
    place(attacker, side, opposite)
    place(target, opposite, opposite + Vector3.xAxis)
    task.wait(.45)
    assert(attacker.plates[targetId] == nil, "Facing away leaked a code")
    pass("rear angle suppresses disclosure")

    place(target, opposite, side)
    local code = await("face-to-face disclosure", function() return attacker.plates[targetId] end)
    assert(#code == 4)
    pass("frontal unobstructed code received over the live remote")

    place(attacker, a, b)
    place(target, b, a)
    attack(attacker, code)
    await("formerly disclosed code rejected behind wall", function() return attacker.replies[#attacker.replies] == "miss" end)
    assert(kills(attacker) == 0 and target.state.status == "alive")
    pass("remembered code cannot kill through a wall")

    wall:Destroy()
    place(attacker, side, opposite)
    place(target, opposite, side)
    task.wait(.55)
    await("code is available again", function() return attacker.plates[targetId] == code end)
    attack(attacker, {"malformed"})
    task.wait(.6)
    attack(attacker, code, "repeat")
    await("single kill credited", function() return kills(attacker) == 1 and target.state.status == "dead" end)
    task.wait(.15)
    assert(kills(attacker) == 1)
    pass("malformed remote ignored and duplicate attempts credit exactly one elimination")

    await("new protected life", function()
        return target.state.status == "alive" and target.state.lifeId > targetLife
    end)
    place(target, opposite, side)
    assert(target.state.protectedUntil > workspace:GetServerTimeNow())
    assert(attacker.plates[targetId] == nil)
    task.wait(.55)
    attack(attacker, code)
    assert(kills(attacker) == 1)
    local nextCode = await("different code for the new life", function() return attacker.plates[targetId] end)
    assert(nextCode ~= code and target.state.status == "alive")
    pass("respawn restores a new life and invalidates the old code")

    await("result state", function() return attacker.state.phase == "results" end, 38)
    assert(attacker.state.winners[1] == attacker.player.UserId and attacker.state.endReason == "time")
    await("second round", function() return attacker.state.phase == "playing" and attacker.state.roundId == 2 end)
    assert(kills(attacker) == 0)
    pass("round timeout declares the leader and next round resets scores")
end

local ok, result = pcall(run)
if not ok then warn("[UMBRAL QA FAIL] " .. tostring(result)) end
local summary = if ok then "[UMBRAL QA COMPLETE] PASS" else "[UMBRAL QA COMPLETE] FAIL " .. tostring(result)
print(summary)
pcall(function() StudioTestService:EndTest(summary) end)
