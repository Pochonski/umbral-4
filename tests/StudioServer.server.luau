local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")
if not RunService:IsStudio() then return end

local bridge = Instance.new("RemoteEvent")
bridge.Name = "UmbralQABridge"
local peers = {}
local pingSent, pingSamples = {}, {}
local departureTimes = {}
Players.PlayerRemoving:Connect(function(player) departureTimes[player] = os.clock() end)
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
    elseif action == "keyboard" then
        peer.keyboard = {ok = first, detail = second}
    elseif action == "keyboardLatency" then
        peer.keyboardLatency = first
    elseif action == "frames" then
        peer.frames = {count = first, p95 = second}
    elseif action == "edge" then
        peer.edge = first
    elseif action == "pong" and pingSent[first] then
        table.insert(pingSamples, (os.clock() - pingSent[first]) * 1000)
        pingSent[first] = nil
    elseif action == "menuProbe" then
        peer.menuProbe = {ok=first,detail=second}
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

local function attack(peer, code, action, at)
    bridge:FireClient(peer.player, action or "attack", peer.state.roundId, peer.state.lifeId, code, at)
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
    local engineTest = args ~= nil
    if args == nil and workspace:GetAttribute("UmbralMenuQA") then args = {clients=2,menuControls=true} end
    local expected = if type(args) == "table" then args.clients else (if type(args) == "number" then args else 2)
    local group = await("clients to initialize", function()
        local ready = {}
        for _, peer in peers do if peer.registered then table.insert(ready, peer) end end
        if #ready >= expected then return ready end
    end, 90)
    table.sort(group, function(a, b) return a.player.UserId < b.player.UserId end)
    local attacker, target = group[1], group[2]
    if type(args) == "table" and args.menuControls then
        for _, peer in group do
            bridge:FireClient(peer.player,"menuProbe")
            local probe = await("menu button probe", function() return peer.menuProbe end)
            assert(probe.ok, probe.detail)
        end
        pass("both clients ready/unready by button, rapid clicks are debounced, practice opens")
    end
    for _, peer in group do
        bridge:FireClient(peer.player, if type(args)=="table" and args.menuControls then "readyButton" else "ready")
    end
    await("all ready players enrolled with live characters", function()
        for _, peer in group do
            if not peer.state or peer.state.phase ~= "playing" or peer.state.status ~= "alive" then return end
        end
        return true
    end, 30)
    assert(#attacker.state.scores == expected)
    assert(attacker.state.goal == (if expected < 4 then 10 elseif expected < 6 then 15 else 25))
    pass(if type(args)=="table" and args.menuControls then "production Play buttons enroll both participants"
        else "ready immediately after sync is accepted for all participants")
    pass("lobby, round, score and goal with " .. expected .. " real Studio client processes")

    task.spawn(function()
        for nonce = 1, 20 do
            pingSent[nonce] = os.clock()
            bridge:FireClient(attacker.player, "ping", nonce)
            task.wait(.10)
        end
    end)

    local Geometry = require(ReplicatedStorage.UmbralShared.Geometry)
    local bounds = CFrame.new(18, 8, 12) * CFrame.Angles(0, math.rad(75), 0)
    local half = Vector3.new(5, 3, 2)
    assert(Geometry.inBounds(bounds:PointToWorldSpace(Vector3.new(4, -2, 1)), bounds, half))
    assert(not Geometry.inBounds(bounds:PointToWorldSpace(Vector3.new(5.1, 0, 0)), bounds, half))
    assert(not Geometry.inBounds(bounds:PointToWorldSpace(Vector3.new(0, -3.1, 0)), bounds, half))
    pass("translated and rotated bounds include local volume and reject its edges")

    local a = Vector3.new(-11, 3.4, -34)
    local b = Vector3.new(-5, 3.4, -34)
    local wall = Instance.new("Part")
    wall.Name = "QA Occluder"
    wall.Anchored = true
    wall.Size = Vector3.new(.55, 12, 5)
    wall.Position = (a + b) * .5 + Vector3.new(0, 2, 0)
    wall.Parent = workspace.UmbralWorld.ActiveArena
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
    attack(attacker, code, "spam")
    await("rate limit under burst", function() return table.find(attacker.replies, "limited") end)
    local misses, notices = 0, 0
    for _, reply in attacker.replies do
        if reply == "miss" then misses += 1 elseif reply == "limited" then notices += 1 end
    end
    assert(misses >= 1 and misses <= 2 and notices == 1)
    assert(kills(attacker) == 0 and target.state.status == "alive")
    bridge:FireClient(attacker.player, "sync")
    await("hidden code has been revoked", function() return attacker.plates[targetId] == nil end)
    pass("remembered code is rejected behind cover, sync is clean and a 32-message burst is limited")

    wall:Destroy()
    place(attacker, side, opposite)
    place(target, opposite, side)
    task.wait(.55)
    await("code is available again", function() return attacker.plates[targetId] == code end)

    if type(args) == "table" and args.latencyEdges then
        local cover = Instance.new("Part")
        cover.Name = "QA Latency Cover"
        cover.Anchored = true
        cover.Size = Vector3.new(.6, 10, 2.4)
        cover.Position = Vector3.new(0, 6, -38)
        cover.Parent = workspace.UmbralWorld.ActiveArena
        for _, scenario in {"cover", "turn"} do
            attacker.edge = nil
            local feedbackBefore = #attacker.replies
            local changeAt = workspace:GetServerTimeNow() + 1.25
            bridge:FireClient(attacker.player, "coveredKeyboard",
                attacker.state.roundId, attacker.state.lifeId, code, changeAt + .025, opposite + Vector3.yAxis * 1.5)
            while workspace:GetServerTimeNow() < changeAt do task.wait() end
            if scenario == "cover" then
                place(target, Vector3.new(6, 3.4, -32.5), side)
            else
                place(target, opposite, opposite + Vector3.xAxis)
            end
            local changed = workspace:GetServerTimeNow()
            local result = await("client visibility at final keystroke", function() return attacker.edge end)
            assert(not result.error, result.error)
            assert(result.before, ("the client was not showing the plate before the transition (local plate parts=%d, viewport=%s)"):format(
                result.visibleUi, result.frameSize
            ))
            await("server rejection after geometry changed", function()
                return #attacker.replies > feedbackBefore and attacker.replies[#attacker.replies] == "miss"
            end)
            assert(kills(attacker) == 0 and target.state.status == "alive")
            await("revocation arrives at client", function() return attacker.plates[targetId] == nil end)
            print(("[UMBRAL EDGE] %s visibleBefore=%s visibleAtFourth=%s clientPressAfterChangeMs=%.1f server=miss"):format(
                scenario, tostring(result.before), tostring(result.atSubmit), (result.pressedAt - changed) * 1000
            ))
            place(target, opposite, side)
            await("reveal after returning to open view", function() return attacker.plates[targetId] == code end)
        end
        cover:Destroy()
        pass("a valid code typed during cover or rear-angle transition is rejected by fresh server geometry")
    end

    attack(attacker, {"malformed"})
    task.wait(.6)
    bridge:FireClient(attacker.player, "attack", attacker.state.roundId - 1, attacker.state.lifeId, code)
    task.wait(.55)
    assert(kills(attacker) == 0 and target.state.status == "alive", "valid code accepted from an obsolete round")
    attack(attacker, code, "keyboard")
    local keyboard = await("VirtualInput result", function() return attacker.keyboard end, 12)
    assert(keyboard.ok, tostring(keyboard.detail))
    await("single keyboard kill credited", function() return kills(attacker) == 1 and target.state.status == "dead" end)
    attack(attacker, code, "repeat")
    task.wait(.45)
    assert(kills(attacker) == 1)
    pass("VirtualInput submitted a code and honored modal/text focus and camera transitions")
    print(("[UMBRAL INPUT] movementIntent=%s backspaceInjected=%s mainRowUsed=%d mainRowBlocked=%d keyboardHitMs=%.1f"):format(
        tostring(keyboard.detail.movementIntent), tostring(keyboard.detail.backspaceInjected),
        keyboard.detail.mainRowUsed, keyboard.detail.mainRowBlocked, attacker.keyboardLatency or -1
    ))
    pass("malformed, obsolete-round and duplicate requests did not add eliminations")

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

    if expected >= 4 then
        local rival = group[3]
        local flank = side + Vector3.new(0, 0, 2)
        place(rival, flank, opposite)
        await("second attacker's grant", function() return rival.plates[targetId] == nextCode end)
        local at = workspace:GetServerTimeNow() + .5
        attack(attacker, nextCode, "attack", at)
        attack(rival, nextCode, "attack", at)
        await("contested target defeated", function() return target.state.status == "dead" end)
        task.wait(.4)
        assert(kills(attacker) + kills(rival) == 2, "contested target awarded multiple kills")
        pass("two clients submit against one life at the same scheduled time and only one scores")
    end

    bridge:FireClient(attacker.player, "frames")
    local frame = await("client frame metrics", function() return attacker.frames end)
    assert(frame.count > 0 and type(frame.p95) == "number")
    table.sort(pingSamples)
    print(("[UMBRAL PERF CLIENT] clients=%d frames=%d p95Ms=%.2f rttN=%d rttP50Ms=%.1f rttP95Ms=%.1f"):format(
        expected, frame.count, frame.p95, #pingSamples,
        pingSamples[math.ceil(#pingSamples * .50)] or -1, pingSamples[math.ceil(#pingSamples * .95)] or -1
    ))

    await("result state", function() return attacker.state.phase == "results" end, 50)
    assert(table.find(attacker.state.winners, attacker.player.UserId) and attacker.state.endReason == "time")
    await("second round", function() return attacker.state.phase == "playing" and attacker.state.roundId == 2 end)
    assert(kills(attacker) == 0)
    pass("round timeout declares the leader and next round resets scores")
    if type(args)=="table" and args.menuControls then
        for _,peer in group do assert(peer.menuProbe.ok, peer.menuProbe.detail) end
        pass("terminal, HUD and results visibility follow server state through two rounds")
    end

    local newcomer
    if type(args) == "table" and args.lateJoin then
        StudioTestService:AddPlayers(1)
        newcomer = await("late client registration", function()
            for _, peer in peers do
                if peer.registered and not table.find(group, peer) then return peer end
            end
        end, 27)
        await("late client receives current round", function()
            return newcomer.state and newcomer.state.phase == "playing" and newcomer.state.roundId == 2
        end)
        bridge:FireClient(newcomer.player, "ready")
        await("late client queues", function() return newcomer.state.ready end)
        assert(not newcomer.state.participating and next(newcomer.plates) == nil)
        pass("late connection receives the round and queues without taking a seat or receiving codes")
    end

    local leaveRequested = os.clock()
    if not engineTest then
        attacker.player:Kick("Umbral QA controlled disconnect")
    else
        bridge:FireClient(attacker.player, "leave")
    end
    local departedAt = await("Studio server observed PlayerRemoving", function()
        return departureTimes[attacker.player]
    end, 20)
    print(("[UMBRAL DISCONNECT] engineObservedMs=%.0f"):format((departedAt - leaveRequested) * 1000))
    await("client disconnect recorded", function()
        for _, score in target.state.scores do
            if score.userId == attacker.player.UserId and score.left then return true end
        end
    end)
    if expected == 2 then
        assert(target.state.phase == "results" and target.state.endReason == "abandoned" and #target.state.winners == 0)
        pass("disconnect below minimum ends without a winner")
    else
        await("remaining clients tie", function() return target.state.phase == "results" end, 48)
        assert(#target.state.winners == expected - 1 and not table.find(target.state.winners, attacker.player.UserId))
        pass("disconnect excludes the departed player and equal remaining scores result in a tie")
    end

    if newcomer or expected >= 4 then
        await("third round starts after departure", function()
            return target.state.phase == "playing" and target.state.roundId == 3
        end, 20)
        assert(kills(target) == 0)
        if newcomer then
            await("queued newcomer joins the third round", function()
                return newcomer.state.roundId == 3 and newcomer.state.participating
            end)
        end
        pass("third consecutive round starts clean and enrolls any queued newcomer")
    end
end

local ok, result = pcall(run)
if not ok then warn("[UMBRAL QA FAIL] " .. tostring(result)) end
local summary = if ok then "[UMBRAL QA COMPLETE] PASS" else "[UMBRAL QA COMPLETE] FAIL " .. tostring(result)
print(summary)
pcall(function() StudioTestService:EndTest(summary) end)
