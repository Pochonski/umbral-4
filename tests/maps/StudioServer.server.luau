-- Short-timer, two-client end-to-end regression. Not in production.
local Players=game:GetService("Players")
local R=game:GetService("ReplicatedStorage")
local Test=game:GetService("StudioTestService")
if not game:GetService("RunService"):IsStudio() then return end
R:WaitForChild("UmbralNetwork")
local f=Instance.new("Folder"); f.Name="UmbralQA"; f.Parent=R
local b=Instance.new("RemoteEvent"); b.Name="MapBridge"; b.Parent=f
local peers={}; local checks={}
b.OnServerEvent:Connect(function(p,kind,value,extra)
    peers[p]=peers[p] or {player=p,plates={},feedback={}}
    local q=peers[p]
    if kind=="state" then q.state=value
    elseif kind=="initialized" then q.initialized=true
    elseif kind=="plates" then
        if extra then q.plates={} end
        for _,plate in value do q.plates[plate.userId]=plate.code end
    elseif kind=="feedback" then table.insert(q.feedback,value)
    elseif kind=="error" then q.error=value end
end)
local function waitFor(name,fn,limit)
    local untilTime=os.clock()+(limit or 15)
    repeat
        for _,q in peers do assert(not q.error,q.error) end
        local value=fn(); if value then return value end
        task.wait(.05)
    until os.clock()>untilTime
    error("Timed out: "..name)
end
local function pass(name) table.insert(checks,name); print("[MAP QA PASS] "..name) end
local function run()
    local group=waitFor("two clients",function()
        local list={}; for _,q in peers do if q.initialized and q.state then table.insert(list,q) end end
        if #list==2 then return list end
    end,60)
    local a,t=group[1],group[2]
    for _,q in group do b:FireClient(q.player,"ready") end
    local active=workspace.UmbralWorld:WaitForChild("ActiveArena")
    local sequence={"relevo","puerto","invernadero"}
    local previousAttack
    for round,mapId in sequence do
        waitFor("playing "..mapId,function() return a.state.phase=="playing" and a.state.roundId==round and a.state.status=="alive" and t.state.status=="alive" end,45)
        assert(a.state.mapId==mapId and t.state.mapId==mapId)
        assert(#active:GetChildren()==1 and active:GetAttribute("MapId")==mapId)
        local map=active:FindFirstChildWhichIsA("Model")
        assert(#map.Spawns:GetChildren()==12)
        local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={map}; params.RespectCanCollide=true
        local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Include; overlap.FilterDescendantsInstances={map}; overlap.RespectCanCollide=true
        for _,marker in map.Spawns:GetChildren() do
            assert(workspace:Raycast(marker.Position,Vector3.new(0,-8,0),params),marker.Name.." has no floor")
            if mapId~="relevo" then assert(#workspace:GetPartBoundsInBox(CFrame.new(marker.Position),Vector3.new(2.5,5,2.5),overlap)==0,marker.Name.." lacks clearance") end
        end
        pass(mapId..": one active model, bounds and twelve supported spawns; new maps have clear avatar envelopes")
        local left,right=Vector3.new(-11,3.4,-34),Vector3.new(-5,3.4,-34)
        if mapId~="relevo" then left,right=Vector3.new(-6,3,-24),Vector3.new(6,3,-24) end
        local function place(q,pos,target)
            local c=q.player.Character; c.HumanoidRootPart.Anchored=true; c:PivotTo(CFrame.lookAt(pos,target)); c.Humanoid.WalkSpeed=0; c.Humanoid.AutoRotate=false
            c.HumanoidRootPart.AssemblyLinearVelocity=Vector3.zero
        end
        place(a,left,right); place(t,right,left)
        if previousAttack then
            b:FireClient(a.player,"staleAttack",previousAttack)
            task.wait(.4)
            for _,row in a.state.scores do assert(row.kills==0,"Previous map attack changed new scores") end
            task.wait(.7)
            pass("old round attack cannot score after changing map")
        end
        local code=waitFor("frontal disclosure",function() return a.plates[t.player.UserId] end)
        local wall=Instance.new("Part"); wall.Name="UmbralQA Cover"; wall.Anchored=true; wall.Size=Vector3.new(.5,9,5); wall.Position=(left+right)/2+Vector3.yAxis; wall.Parent=map
        task.wait(.5); assert(a.plates[t.player.UserId]==nil)
        a.feedback={}; b:FireClient(a.player,"attack",code)
        waitFor("server cover rejection",function() return table.find(a.feedback,"miss") end)
        assert(t.state.status=="alive")
        wall:Destroy()
        if mapId~="relevo" then
            local outsideLeft,outsideRight,hiddenLeft,hiddenRight
            if mapId=="puerto" then
                outsideLeft,outsideRight=Vector3.new(-43,3,-25),Vector3.new(-12,3,-25)
                hiddenLeft,hiddenRight=Vector3.new(-43,3,-16),Vector3.new(-12,3,-16)
            else
                outsideLeft,outsideRight=Vector3.new(-15,3,-12),Vector3.new(15,3,-12)
                hiddenLeft,hiddenRight=Vector3.new(-15,3,0),Vector3.new(15,3,0)
            end
            place(a,outsideLeft,outsideRight); place(t,outsideRight,outsideLeft)
            code=waitFor("native corner open",function() return a.plates[t.player.UserId] end)
            place(a,hiddenLeft,hiddenRight); place(t,hiddenRight,hiddenLeft)
            task.wait(.5); assert(a.plates[t.player.UserId]==nil,"Native opaque cover leaked code")
            a.feedback={}; b:FireClient(a.player,"attack",code)
            waitFor("native cover rejects",function() return table.find(a.feedback,"miss") end)
            assert(t.state.status=="alive")
            pass(mapId..": native opaque cover rejects remembered code; outside corner exposes target")
            place(a,left,right); place(t,right,left)
            task.wait(.6)
        end
        code=waitFor("redisclosure",function() return a.plates[t.player.UserId] end)
        local oldLife=t.state.lifeId
        previousAttack={round=a.state.roundId,life=a.state.lifeId,code=code}
        a.feedback={}; b:FireClient(a.player,"attack",code)
        waitFor("elimination",function() return table.find(a.feedback,"hit") end)
        waitFor("respawn with a new life",function() return t.state.status=="alive" and t.state.lifeId>oldLife end)
        waitFor("one confirmed score",function()
            for _,row in a.state.scores do if row.userId==a.player.UserId then return row.kills==1 end end
        end)
        pass(mapId..": live targets, cover rejects, frontal hit and respawn")
        waitFor("results",function() return a.state.phase=="results" end,35)
        waitFor("vote",function() return a.state.phase=="voting" end)
        assert(#a.state.vote.options==2 and not table.find(a.state.vote.options,mapId))
        if round<3 then
            local nextId=sequence[round+1]
            b:FireClient(a.player,"invalidVote",nextId); task.wait(.3)
            assert(a.state.vote.counts[nextId]==0)
            task.wait(1.1)
            for _,q in group do b:FireClient(q.player,"vote",nextId) end
            waitFor("two network votes",function() return a.state.vote and a.state.vote.counts[nextId]==2 end)
            b:FireClient(t.player,"readyValue",false)
            waitFor("unready removes vote",function() return a.state.vote and a.state.vote.counts[nextId]==1 end)
            task.wait(.3)
            b:FireClient(t.player,"readyValue",true)
            waitFor("rejoin during vote",function() return t.state.ready end)
            b:FireClient(t.player,"vote",nextId)
            waitFor("rejoined vote counted",function() return a.state.vote and a.state.vote.counts[nextId]==2 end)
            pass("two network votes select "..nextId.."; stale/forged options rejected; leaving/rejoining queue updates votes")
        end
    end
    -- A real disconnection while voting must remove the departed player's vote.
    b:FireClient(t.player,"vote","puerto")
    waitFor("departure vote",function() return a.state.vote.counts.puerto==1 end)
    t.player:Kick("Controlled map QA disconnect")
    waitFor("vote removed on disconnect",function() return a.state.vote and a.state.vote.counts.puerto==0 end)
    pass("actual disconnected client loses its vote")
    return {human=false,clients=2,checks=checks}
end
local ok,result=pcall(run)
print("[MAP QA COMPLETE]",ok,if ok then game:GetService("HttpService"):JSONEncode(result) else tostring(result))
pcall(function() Test:EndTest(if ok then "MAP QA PASS" else tostring(result)) end)
