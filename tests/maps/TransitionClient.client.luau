-- QA only: observe production state/rendering, never override combat decisions.
local P=game.Players.LocalPlayer
local R=game.ReplicatedStorage
local Run=game:GetService("RunService")
local network=R:WaitForChild("UmbralNetwork")
local bridge=R:WaitForChild("UmbralQA"):WaitForChild("MapBridge")
local state
local aliveAt=math.huge
local report={human=false,rounds={},errors={},echoMs={},frames=0,enabledPlateFrames=0,transitionFrameMs={}}
local tagged=setmetatable({},{__mode="k"})
local lastCharacter
local echoes={}
local function fault(value)
    if #report.errors<12 and not table.find(report.errors,value) then table.insert(report.errors,value) end
end
network.Update.OnClientEvent:Connect(function(kind,...)
    if kind=="state" then
        local nextState=...
        if nextState.status=="alive" and (not state or state.status~="alive" or state.lifeId~=nextState.lifeId) then
            aliveAt=workspace:GetServerTimeNow()
        end
        state=nextState
        if state.phase=="playing" and state.status=="alive" and not report.rounds[tostring(state.roundId)] then
            report.rounds[tostring(state.roundId)]={mapId=state.mapId,revision=state.mapRevision,stateAt=workspace:GetServerTimeNow(),
                previousCharacter=lastCharacter}
        end
        bridge:FireServer("state",state)
    elseif kind=="plates" then
        local _,_,updates,reset=...;bridge:FireServer("plates",updates,reset)
    elseif kind=="feedback" then bridge:FireServer("feedback",...) end
end)
Run.PreRender:Connect(function(dt)
    if not state then return end
    report.frames+=1
    local active=workspace.UmbralWorld:FindFirstChild("ActiveArena")
    local consistent=active and active:GetAttribute("Revision")==state.mapRevision and #active:GetChildren()==1
    local now=workspace:GetServerTimeNow()
    local row=report.rounds[tostring(state.roundId)]
    if (state.phase=="voting" or state.phase=="countdown" or (row and now-row.stateAt<2)) and #report.transitionFrameMs<6000 then
        table.insert(report.transitionFrameMs,dt*1000)
    end
    local plates=workspace:FindFirstChild("UmbralLocalPlates")
    local enabled=0
    if plates then
        for _,part in plates:GetChildren() do
            tagged[part]=tagged[part] or {round=state.roundId,revision=state.mapRevision}
            local gui=part:FindFirstChildOfClass("SurfaceGui")
            local label=gui and gui:FindFirstChildOfClass("TextLabel")
            if label and label.Text=="QA-OLD" then fault("old round packet created a plate") end
            if gui and gui.Enabled then
                enabled+=1
                if state.phase~="playing" or state.status~="alive" or not consistent then fault("plate enabled outside consistent live state") end
                if tagged[part].round~=state.roundId or tagged[part].revision~=state.mapRevision then fault("previous generation plate enabled") end
            end
        end
    end
    if enabled>0 then report.enabledPlateFrames+=1 end
    if row and state.phase=="playing" and state.status=="alive" and consistent then
        local model=active:FindFirstChildWhichIsA("Model")
        local bounds=model and model:FindFirstChild("PlayableBounds")
        local spawns=model and model:FindFirstChild("Spawns")
        local character=P.Character;local root=character and character:FindFirstChild("HumanoidRootPart")
        local inside=false
        if bounds and root then
            local pos=bounds.CFrame:PointToObjectSpace(root.Position);local half=bounds.Size*.5
            inside=math.abs(pos.X)<=half.X and math.abs(pos.Y)<=half.Y and math.abs(pos.Z)<=half.Z
        end
        if bounds and spawns and #spawns:GetChildren()==12 and inside and character~=row.previousCharacter
            and (not row.previousCharacter or row.previousCharacter.Parent==nil) then
            if not row.convergedAfterMs then
                row.convergedAfterMs=(now-row.stateAt)*1000
                row.activeModels=#active:GetChildren();row.spawnCount=#spawns:GetChildren()
                row.viewport=tostring(workspace.CurrentCamera.ViewportSize)
                row.previousCharacterRemoved=not row.previousCharacter or row.previousCharacter.Parent==nil
                lastCharacter=character
            end
        elseif now-aliveAt>2 then
            fault("round "..state.roundId.." not converged after two seconds")
        end
        if row.convergedAfterMs and row.previousCharacter and row.previousCharacter.Parent and now-row.stateAt>2 then
            fault("old avatar still exists in round "..state.roundId)
        end
    end
end)
bridge.OnClientEvent:Connect(function(action,value)
    if action=="ready" then network.Request:FireServer("ready",true)
    elseif action=="vote" then network.Request:FireServer("vote",state.vote.id,value)
    elseif action=="attack" then network.SubmitCode:FireServer(state.roundId,state.lifeId,value)
    elseif action=="echo" then
        if echoes[value] then table.insert(report.echoMs,(os.clock()-echoes[value])*1000);echoes[value]=nil end
    elseif action=="measureEcho" then
        task.spawn(function()
            for i=1,8 do
                local seq=tostring(os.clock())..":"..i;echoes[seq]=os.clock();bridge:FireServer("echo",seq);task.wait(.3)
            end
        end)
    elseif action=="report" then
        local result={human=false,errors=report.errors,frames=report.frames,enabledPlateFrames=report.enabledPlateFrames,echoMs=report.echoMs,rounds={}}
        for key,row in report.rounds do
            local clean=table.clone(row);clean.previousCharacter=nil;result.rounds[key]=clean
        end
        table.sort(report.transitionFrameMs)
        result.transitionFrames=#report.transitionFrameMs
        result.transitionFrameP95Ms=report.transitionFrameMs[math.ceil(#report.transitionFrameMs*.95)]
        bridge:FireServer("report",result)
    end
end)
network.Request:FireServer("sync");bridge:FireServer("initialized")
