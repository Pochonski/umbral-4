-- QA-only four-round transition test with actual local client processes.
if not game:GetService("RunService"):IsStudio() then return end
local R=game.ReplicatedStorage
R:WaitForChild("UmbralNetwork")
local Test=game:GetService("StudioTestService")
local folder=Instance.new("Folder");folder.Name="UmbralQA";folder.Parent=R
local bridge=Instance.new("RemoteEvent");bridge.Name="MapBridge";bridge.Parent=folder
local peers={};local checks={};local transitions={}
bridge.OnServerEvent:Connect(function(p,kind,value,extra)
    peers[p]=peers[p] or {player=p,plates={},feedback={}}
    local q=peers[p]
    if kind=="initialized" then q.initialized=true
    elseif kind=="state" then
        if q.state and q.state.roundId~=value.roundId then q.plates={} end
        q.state=value
    elseif kind=="plates" then
        if extra then q.plates={} end
        for _,v in value do q.plates[v.userId]=v.code end
    elseif kind=="feedback" then table.insert(q.feedback,value)
    elseif kind=="echo" then bridge:FireClient(p,"echo",value)
    elseif kind=="report" then q.report=value end
end)
local function waitFor(label,fn,seconds)
    local deadline=os.clock()+(seconds or 15)
    repeat local value=fn();if value then return value end;task.wait(.05) until os.clock()>deadline
    error("Timed out: "..label)
end
local function pass(label) table.insert(checks,label);print("[REFINE TRANSITION PASS] "..label) end
local function run()
    local args
    pcall(function()args=Test:GetTestArgs() end)
    local expected=if (type(args)=="table" and args.clients==1) or workspace:GetAttribute("UmbralTransitionClients")==1 then 1 else 2
    local group=waitFor("two clients",function()
        local rows={};for _,q in peers do if q.initialized and q.state then table.insert(rows,q) end end
        if #rows==expected then return rows end
    end,75)
    table.sort(group,function(a,b)return a.player.UserId<b.player.UserId end)
    local a,t=group[1],group[2]
    for _,q in group do bridge:FireClient(q.player,"ready");bridge:FireClient(q.player,"measureEcho") end
    local active=workspace.UmbralWorld:WaitForChild("ActiveArena")
    local Arena=require(game.ServerScriptService.UmbralServer.Arena)
    local sequence={"relevo","puerto","invernadero","relevo"}
    local previousMap,oldCharacters,oldRound,oldLife
    for round,id in sequence do
        waitFor("alive round "..round,function()
            for _,q in group do
                if q.state.roundId~=round or q.state.phase~="playing" or q.state.status~="alive" then return false end
            end
            return true
        end,50)
        assert(Arena.id==id)
        for _,q in group do assert(q.state.mapId==id) end
        assert(#active:GetChildren()==1)
        local model=active:FindFirstChildWhichIsA("Model")
        if previousMap then assert(previousMap.Parent==nil,"Old map survived replacement") end
        for _,q in group do
            assert(Arena.inBounds(q.player.Character.HumanoidRootPart.Position))
            if oldCharacters then assert(oldCharacters[q.player]~=q.player.Character and oldCharacters[q.player].Parent==nil,"Old avatar survived") end
            if oldRound then R.UmbralNetwork.Update:FireClient(q.player,"plates",oldRound,oldLife,{{userId=(t or a).player.UserId,lifeId=1,code="QA-OLD"}},false) end
        end
        pass(id..": one complete arena, new avatars in bounds, old map/avatar removed")
        if t then
        local left,right=Vector3.new(-11,3.4,-34),Vector3.new(-5,3.4,-34)
        if id~="relevo" then left,right=Vector3.new(-6,3,-24),Vector3.new(6,3,-24) end
        for index,q in group do
            local pos=if index==1 then left else right;local toward=if index==1 then right else left
            local c=q.player.Character;c.HumanoidRootPart.Anchored=true;c.Humanoid.AutoRotate=false;c.Humanoid.WalkSpeed=0
            c:PivotTo(CFrame.lookAt(pos,toward));c.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
        end
        local code=waitFor("visible code",function()return a.plates[t.player.UserId] end)
        local before=t.state.lifeId;a.feedback={};bridge:FireClient(a.player,"attack",code)
        waitFor("confirmed hit",function()return table.find(a.feedback,"hit") end)
        waitFor("respawn new life",function()return t.state.status=="alive" and t.state.lifeId>before end)
        pass(id..": code disclosure, server-confirmed elimination and respawn under test profile")
        else
            pass(id..": single-client transport mode; opponent combat deliberately not tested")
        end
        oldRound,oldLife=a.state.roundId,a.state.lifeId
        if round==4 then break end
        waitFor("vote",function()
            for _,q in group do if q.state.phase~="voting" then return false end end
            return true
        end,40)
        waitFor("avatars moved to lobby",function()
            for _,q in group do
                local c=q.player.Character;local root=c and c:FindFirstChild("HumanoidRootPart")
                if not root or (root.Position-Arena.lobby.Position).Magnitude>4 then return false end
            end
            return true
        end)
        oldCharacters={};for _,q in group do oldCharacters[q.player]=q.player.Character end
        previousMap=model
        local nextId=sequence[round+1]
        for _,q in group do bridge:FireClient(q.player,"vote",nextId) end
        waitFor("votes",function()return a.state.vote and a.state.vote.counts[nextId]==expected end)
        table.insert(transitions,{from=id,to=nextId,voteId=a.state.vote.id,serverVoteDeadline=a.state.deadline})
        pass(id.." → "..nextId..": lobby avatars and "..expected.." vote(s) before replacement")
    end
    task.wait(2)
    for _,q in group do bridge:FireClient(q.player,"report") end
    waitFor("client render audits",function()
        for _,q in group do if not q.report then return false end end
        return true
    end)
    local clients={}
    for _,q in group do
        assert(#q.report.errors==0,game.HttpService:JSONEncode(q.report.errors))
        if expected>1 then assert(q.report.enabledPlateFrames>0,"No plate rendered during QA") end
        assert(#q.report.echoMs>=4,"Insufficient echo samples")
        for round=1,4 do
            local row=q.report.rounds[tostring(round)]
            assert(row and row.convergedAfterMs and row.previousCharacterRemoved,"Client transition incomplete")
            print("[REFINE CLIENT ROUND]",q.player.Name,round,game.HttpService:JSONEncode(row))
        end
        q.report.userId=q.player.UserId;table.insert(clients,q.report)
    end
    pass(expected.." client(s): no obsolete plates, no stale packet plate, no old avatars; all four rounds converged")
    return {human=false,ok=true,clientCount=expected,opponentCombat=expected>1,clients=clients,checks=checks,transitions=transitions}
end
local ok,result=pcall(run)
local output=if ok then result else {ok=false,error=tostring(result),checks=checks}
print("[REFINE TRANSITION COMPLETE]",ok)
pcall(function() Test:EndTest(game.HttpService:JSONEncode(output)) end)
