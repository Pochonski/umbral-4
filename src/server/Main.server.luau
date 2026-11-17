local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("UmbralShared")
local Config = require(shared.Config)
local Rules = require(shared.Rules)
local Geometry = require(shared.Geometry)
local Arena = require(script.Parent.Arena)

Players.CharacterAutoLoads = false
local network = Instance.new("Folder")
network.Name = "UmbralNetwork"

local function remote(name)
    local event = Instance.new("RemoteEvent")
    event.Name = name
    event.Parent = network
    return event
end

local request = remote("Request")
local submit = remote("SubmitCode")
-- One reliable stream preserves the order of snapshots, plate changes and hit feedback.
local update = remote("Update")
local random = Random.new()
local roster, scores, codeIndex = {}, {}, {}
local codePool = Rules.newCodePool()
local phase, roundId, deadline, goal = "waiting", 0, 0, 0
local winners, endReason = {}, ""
local dirty = true
local metrics = {}

local function time()
    return workspace:GetServerTimeNow()
end

local function count(flag)
    local number = 0
    for _, record in roster do
        if record[flag] then number += 1 end
    end
    return number
end

local function parts(record)
    local character = record.character
    if not character or character ~= record.player.Character or not character.Parent then return nil, nil end
    local root, head = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("Head")
    if not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then return nil, nil end
    return root, head
end

local function active(record, now)
    return record and record.participating and record.status == "alive"
        and now >= record.protectedUntil and record.humanoid and record.humanoid.Health > 0
end

local function snapshot(record, ranking)
    update:FireClient(record.player, "state", {
        phase = phase, roundId = roundId, deadline = deadline, goal = goal,
        ready = record.ready, readyCount = count("ready"), participating = record.participating,
        status = record.status, lifeId = record.lifeId, respawnAt = record.respawnAt,
        protectedUntil = record.protectedUntil, killerName = record.killerName,
        scores = ranking, winners = winners, endReason = endReason,
    })
end

local function revoke(target, resetObserver)
    for _, observer in roster do
        local reveal = observer.reveals[target.player.UserId]
        if reveal then
            if reveal.visible then
                update:FireClient(observer.player, "plates", roundId, observer.lifeId, {
                    { userId = target.player.UserId, lifeId = reveal.lifeId },
                })
            end
            observer.reveals[target.player.UserId] = nil
        end
    end
    if resetObserver then
        table.clear(target.reveals)
        if target.player.Parent == Players then
            update:FireClient(target.player, "plates", roundId, target.lifeId, {}, true)
        end
    end
end

local function cancelLife(record)
    if record.code then
        codeIndex[record.code] = nil
        record.code = nil
    end
    revoke(record, true)
end

local function finish(reason)
    if phase ~= "playing" then return end
    local _, rankedWinners = Rules.ranking(scores)
    winners = if reason == "abandoned" then {} else rankedWinners
    phase, deadline, endReason = "results", time() + Config.ResultsDuration, reason
    for _, record in roster do cancelLife(record) end
    if RunService:IsStudio() then
        print("[Umbral 4] Ronda", roundId, reason,
            "aciertos", metrics.hit or 0, "rechazos", metrics.miss or 0,
            "límite", metrics.limited or 0, "malformados", metrics.invalid or 0)
        print(("[UMBRAL PERF] round=%d ticks=%d pairChecks=%d raycasts=%d meanMs=%.3f maxMs=%.3f"):format(
            roundId, metrics.ticks or 0, metrics.pairs or 0, metrics.rays or 0,
            (metrics.seconds or 0) * 1000 / math.max(1, metrics.ticks or 0), (metrics.peak or 0) * 1000
        ))
    end
    dirty = true
end

local function die(record, killer)
    if phase ~= "playing" or not record.participating or record.status ~= "alive" then return end
    record.status = "dead"
    record.respawnAt = time() + Config.RespawnDelay
    record.killerName = if killer then killer.player.DisplayName else ""
    cancelLife(record)
    local targetScore = scores[record.player.UserId]
    targetScore.deaths += 1
    if killer then
        local score = scores[killer.player.UserId]
        score.kills += 1
        metrics.hit = (metrics.hit or 0) + 1
        update:FireClient(killer.player, "feedback", "hit", record.player.DisplayName, roundId, killer.lifeId)
        if score.kills >= goal then finish("goal") end
    end
    if record.humanoid and record.humanoid.Health > 0 then
        record.humanoid.Health = 0
    end
    if killer and record.character then
        local transition = TweenInfo.new(.36, Enum.EasingStyle.Quad)
        for _, part in record.character:GetDescendants() do
            if part:IsA("BasePart") then part.CanCollide = false end
            if (part:IsA("BasePart") or part:IsA("Decal")) and part.Transparency < 1 then
                TweenService:Create(part, transition, {Transparency = 1}):Play()
            end
        end
    end
    dirty = true
end

local function placeCharacter(record, character, humanoid, root, destination)
    record.character, record.humanoid = character, humanoid
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.BreakJointsOnDeath = false
    character:PivotTo(destination)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function queueSpawn(record, inArena)
    cancelLife(record)
    record.spawnTicket += 1
    record.wantsArena = inArena
    record.status = if inArena then "spawning" else "lobby"
    record.respawnAt, record.protectedUntil, record.killerName = 0, 0, ""
    dirty = true
    if record.loading then return end
    record.loading = true

    task.spawn(function()
        while roster[record.player] == record do
            local ticket = record.spawnTicket
            local spawnRound = roundId
            local desiredArena = record.wantsArena
            local ok, errorMessage = pcall(function() record.player:LoadCharacterAsync() end)
            if roster[record.player] ~= record then break end
            local character = if ok then record.player.Character else nil
            local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
            local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
            if ticket ~= record.spawnTicket then continue end
            if not humanoid or not root then
                warn("[Umbral 4] Reintento de aparición", tostring(errorMessage))
                record.retryAt = time() + 2
                break
            end

            if desiredArena and phase == "playing" and roundId == spawnRound and record.participating then
                local opponents = {}
                for _, opponent in roster do
                    if opponent ~= record and opponent.participating and opponent.status == "alive" then
                        local otherRoot = parts(opponent)
                        if otherRoot then table.insert(opponents, otherRoot) end
                    end
                end
                local marker = Arena.choose(opponents, record.lastSpawn, random)
                record.lastSpawn = marker
                placeCharacter(record, character, humanoid, root, marker.CFrame)
                record.lifeId += 1
                record.code = assert(Rules.drawCode(codePool, function(low, high) return random:NextInteger(low, high) end))
                codeIndex[record.code] = record
                record.status = "alive"
                record.protectedUntil = time() + Config.ProtectionTime
                local shield = Instance.new("Highlight")
                shield.Name = "Protección temporal"
                shield.FillColor = Color3.fromRGB(104, 231, 206)
                shield.FillTransparency = .83
                shield.OutlineColor = shield.FillColor
                shield.OutlineTransparency = .12
                shield.DepthMode = Enum.HighlightDepthMode.Occluded
                shield.Parent = character
                task.delay(Config.ProtectionTime, function() shield:Destroy() end)
            else
                placeCharacter(record, character, humanoid, root, Arena.lobby)
                record.status = "lobby"
            end

            humanoid.Died:Connect(function()
                if record.character ~= character or roster[record.player] ~= record then return end
                if record.status == "alive" then
                    die(record, nil)
                elseif record.status == "lobby" and phase ~= "results" then
                    record.retryAt = time() + 2
                end
            end)
            record.retryAt = 0
            dirty = true
            break
        end
        record.loading = false
    end)
end

local function begin(now)
    local candidates = {}
    for _, record in roster do
        if record.ready then table.insert(candidates, record) end
    end
    table.sort(candidates, function(a, b) return a.readyAt < b.readyAt end)
    local enrolled = math.min(#candidates, Config.MaxPlayers)
    roundId += 1
    scores, codeIndex, codePool, winners, metrics = {}, {}, Rules.newCodePool(), {}, {}
    phase, deadline, goal, endReason = "playing", now + Config.RoundDuration, Rules.goal(enrolled), ""
    for index = 1, enrolled do
        local record = candidates[index]
        record.participating = true
        record.lastSpawn = nil
        scores[record.player.UserId] = {
            userId = record.player.UserId, name = record.player.DisplayName, kills = 0, deaths = 0, left = false,
        }
        queueSpawn(record, true)
    end
    dirty = true
end

local function reset()
    phase, deadline, goal, endReason = "waiting", 0, 0, ""
    scores, winners = {}, {}
    for _, record in roster do
        if record.participating then
            record.participating = false
            queueSpawn(record, false)
        end
    end
    dirty = true
end

local function combatPose(record)
    local root, head = parts(record)
    if not root or not Arena.inBounds(root.Position) then return nil end
    return Geometry.withPlate(Geometry.pose(root, head), head.Size.Z)
end

local function canSee(attacker, target)
    local origin, opponent = combatPose(attacker), combatPose(target)
    return origin ~= nil and opponent ~= nil and Geometry.eligible(origin, opponent, Arena.raycast)
end

local function hasGrant(reveal, target, now)
    return reveal and reveal.visible and reveal.lifeId == target.lifeId
        and now - reveal.seenAt <= Config.RevealLifetime
end

local poses = {}
local inStudio = RunService:IsStudio()
local function sample(now)
    debug.profilebegin("Umbral.VisibilityServer")
    local started = if inStudio then os.clock() else 0
    local pairChecks, rays = 0, 0
    table.clear(poses)
    for _, record in roster do
        if active(record, now) then poses[record] = combatPose(record) end
    end
    for observer, origin in poses do
        local updates = {}
        for _, target in roster do
            if target == observer then continue end
            local id = target.player.UserId
            local reveal = observer.reveals[id]
            local opponent = poses[target]
            local visible = false
            if opponent then
                local count
                visible, count = Geometry.eligible(origin, opponent, Arena.raycast)
                pairChecks += 1
                rays += count
            end
            if visible then
                if not reveal or reveal.lifeId ~= target.lifeId then
                    reveal = { lifeId = target.lifeId, samples = 0, visible = false }
                    observer.reveals[id] = reveal
                end
                reveal.samples += 1
                reveal.seenAt = now
                if not reveal.visible and reveal.samples >= Config.RevealSamples then
                    reveal.visible = true
                    table.insert(updates, { userId = id, lifeId = target.lifeId, code = target.code })
                end
            elseif reveal then
                if reveal.visible then table.insert(updates, { userId = id, lifeId = reveal.lifeId }) end
                observer.reveals[id] = nil
            end
        end
        if #updates > 0 then
            update:FireClient(observer.player, "plates", roundId, observer.lifeId, updates)
        end
    end
    if inStudio then
        local elapsed = os.clock() - started
        metrics.ticks = (metrics.ticks or 0) + 1
        metrics.pairs = (metrics.pairs or 0) + pairChecks
        metrics.rays = (metrics.rays or 0) + rays
        metrics.seconds = (metrics.seconds or 0) + elapsed
        metrics.peak = math.max(metrics.peak or 0, elapsed)
    end
    debug.profileend()
end

local function addPlayer(player)
    if roster[player] or player.Parent ~= Players then return end
    local now = time()
    local record = {
        player = player, ready = false, participating = false,
        lifeId = 0, status = "lobby", respawnAt = 0, protectedUntil = 0, killerName = "",
        reveals = {}, spawnTicket = 0, retryAt = 0, lastSync = -math.huge, lastReady = -math.huge,
        bucket = {tokens = Config.RequestBurst, updated = now},
    }
    roster[player] = record
    queueSpawn(record, false)
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
    local record = roster[player]
    if not record then return end
    roster[player] = nil
    cancelLife(record)
    local score = scores[player.UserId]
    if score and phase == "playing" then score.left = true end
    if count("participating") < Config.MinPlayers then finish("abandoned") end
    dirty = true
end)

request.OnServerEvent:Connect(function(player, kind, value)
    local record = roster[player]
    local now = time()
    if not record then return end
    if kind == "sync" then
        if now - record.lastSync < 0.24 then return end
        record.lastSync = now
        snapshot(record, Rules.ranking(scores))
        local plates = {}
        if phase == "playing" and active(record, now) then
            for targetId, reveal in record.reveals do
                local targetPlayer = Players:GetPlayerByUserId(targetId)
                local target = targetPlayer and roster[targetPlayer]
                if active(target, now) and hasGrant(reveal, target, now) and canSee(record, target) then
                    table.insert(plates, {userId = targetId, lifeId = target.lifeId, code = target.code})
                elseif reveal.visible then
                    record.reveals[targetId] = nil
                end
            end
        end
        update:FireClient(player, "plates", roundId, record.lifeId, plates, true)
    elseif kind == "ready" and type(value) == "boolean" and not record.participating then
        if now - record.lastReady < 0.24 then return end
        record.lastReady = now
        if value and not record.ready then record.readyAt = now end
        record.ready = value
        dirty = true
    end
end)

submit.OnServerEvent:Connect(function(player, requestRound, requestLife, code)
    local attacker = roster[player]
    local now = time()
    if not attacker or phase ~= "playing" or now >= deadline then return end
    if not Rules.consume(attacker.bucket, now, Config.RequestRate, Config.RequestBurst) then
        metrics.limited = (metrics.limited or 0) + 1
        if requestRound == roundId and requestLife == attacker.lifeId and active(attacker, now) and Rules.validCode(code)
            and now >= (attacker.nextLimitNotice or 0) then
            attacker.nextLimitNotice = now + 1 / Config.RequestRate
            update:FireClient(player, "feedback", "limited", "", roundId, attacker.lifeId)
        end
        return
    end
    if requestRound ~= roundId or requestLife ~= attacker.lifeId or not active(attacker, now) then return end
    if not Rules.validCode(code) then
        metrics.invalid = (metrics.invalid or 0) + 1
        return
    end
    local target = codeIndex[code]
    local reveal = target and attacker.reveals[target.player.UserId]
    if target and target ~= attacker and active(target, now)
        and hasGrant(reveal, target, now) and canSee(attacker, target) then
        die(target, attacker)
    else
        metrics.miss = (metrics.miss or 0) + 1
        update:FireClient(player, "feedback", "miss", "", roundId, attacker.lifeId)
    end
end)

local nextSample = 0
RunService.Heartbeat:Connect(function()
    local now = time()
    if phase == "waiting" and count("ready") >= Config.MinPlayers then
        phase, deadline, dirty = "countdown", now + Config.Countdown, true
    elseif phase == "countdown" then
        if count("ready") < Config.MinPlayers then
            phase, deadline, dirty = "waiting", 0, true
        elseif now >= deadline then
            begin(now)
        end
    elseif phase == "playing" and now >= deadline then
        finish("time")
    elseif phase == "results" and now >= deadline then
        reset()
    end

    local shouldSample = now >= nextSample
    if shouldSample then
        nextSample = now + Config.SampleInterval
        for _, record in roster do
            if record.retryAt > 0 and now >= record.retryAt then
                record.retryAt = 0
                queueSpawn(record, phase == "playing" and record.participating)
            elseif phase == "playing" and record.participating then
                if record.status == "dead" and now >= record.respawnAt then
                    queueSpawn(record, true)
                elseif record.status == "alive" then
                    local root = parts(record)
                    if not root or not Arena.inBounds(root.Position) then die(record, nil) end
                end
            end
        end
    end
    if shouldSample and phase == "playing" then sample(now) end
    if dirty then
        dirty = false
        local ranking = Rules.ranking(scores)
        for _, record in roster do snapshot(record, ranking) end
    end
end)

network.Parent = ReplicatedStorage
for _, player in Players:GetPlayers() do addPlayer(player) end
