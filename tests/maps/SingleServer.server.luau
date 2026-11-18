-- Single-client diagnostic copy only; MinPlayers=1 and short rounds are QA overrides.
if not game:GetService("RunService"):IsStudio() then return end
local R=game:GetService("ReplicatedStorage")
R:WaitForChild("UmbralNetwork")
local f=Instance.new("Folder"); f.Name="UmbralQA"; f.Parent=R
local remote=Instance.new("RemoteFunction"); remote.Name="Inspect"; remote.Parent=f
remote.OnServerInvoke=function(_,action)
    if type(action)=="string" and action:sub(1,5)=="load:" then
        local Arena=require(game.ServerScriptService.UmbralServer.Arena)
        return Arena.activate(action:sub(6))
    end
    if action=="breakPuerto" then
        game.ServerStorage.UmbralMapTemplates.PuertoDeCarga.PlayableBounds:Destroy()
        return true
    end
    local active=workspace.UmbralWorld.ActiveArena
    local map=assert(active:FindFirstChildWhichIsA("Model"))
    local ray=RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Include; ray.FilterDescendantsInstances={map}; ray.RespectCanCollide=true
    local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Include; overlap.FilterDescendantsInstances={map}; overlap.RespectCanCollide=true
    local bad={}; local unsupported={}; local paths={}
    local markers=map.Spawns:GetChildren()
    table.sort(markers,function(a,b) return a.Name<b.Name end)
    if action=="occlusion" then
        local Geometry=require(R.UmbralShared.Geometry)
        local points={}
        for _,marker in markers do table.insert(points,marker.Position) end
        local bounds=map.PlayableBounds
        for _,height in {3,11} do
            local limit=if height==3 then 60 else 80
            for x=-48,48,8 do
                for z=-40,40,8 do
                    local probe=Vector3.new(x,height,z)
                    local hit=workspace:Raycast(probe,Vector3.new(0,-8,0),ray)
                    if not hit or (height==11 and hit.Position.Y<4) then continue end
                    local pos=hit.Position+Vector3.yAxis*3
                    if #points<limit and Geometry.inBounds(pos,bounds.CFrame,bounds.Size*.5)
                        and #workspace:GetPartBoundsInBox(CFrame.new(pos),Vector3.new(2.5,5,2.5),overlap)==0 then table.insert(points,pos) end
                end
            end
        end
        local visual=Instance.new("Model"); visual.Name="UmbralQAVisualQuery"
        for _,part in map:GetDescendants() do
            if part:IsA("BasePart") and part.Transparency<.35 then
                local clone=part:Clone(); clone:ClearAllChildren()
                clone.CanCollide=false; clone.CanTouch=false; clone.CanQuery=true; clone.Parent=visual
            end
        end
        visual.Parent=workspace
        local ok,result=pcall(function()
            local physicalParams=Geometry.coverParams(map)
            local visualParams=Geometry.coverParams(visual)
            local checks,rays,mismatches=0,0,0
            for i,a in points do
                for j,b in points do
                    local delta=b-a
                    if i~=j and delta.Magnitude>1 and delta.Magnitude<=45 then
                        local flat=Vector3.new(delta.X,0,delta.Z).Unit
                        local attacker={eye=a+Vector3.yAxis*1.5,facing=flat}
                        local target=Geometry.withPlate({eye=b+Vector3.yAxis*1.5,facing=-flat},1)
                        local first,n1=Geometry.eligible(attacker,target,physicalParams)
                        local second,n2=Geometry.eligible(attacker,target,visualParams)
                        checks+=1; rays+=n1+n2
                        if first~=second then mismatches+=1 end
                    end
                end
                if i%10==0 then task.wait() end
            end
            return {mapId=active:GetAttribute("MapId"),points=#points,checks=checks,raycasts=rays,mismatches=mismatches,
                scope="opaque geometry, supported ground and raised surfaces, frontal codes within 45 studs"}
        end)
        visual:Destroy()
        assert(ok,result)
        return result
    end
    for _,marker in markers do
        if not workspace:Raycast(marker.Position,Vector3.new(0,-8,0),ray) then table.insert(unsupported,marker.Name) end
        if #workspace:GetPartBoundsInBox(CFrame.new(marker.Position),Vector3.new(2.5,5,2.5),overlap)>0 then table.insert(bad,marker.Name) end
        if marker==markers[1] then paths[marker.Name]=true; continue end
        local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=1.5,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
        local ok=pcall(function() path:ComputeAsync(marker.Position,markers[1].Position) end)
        paths[marker.Name]=ok and path.Status==Enum.PathStatus.Success
        path:Destroy()
    end
    return {mapId=active:GetAttribute("MapId"),activeModels=#active:GetChildren(),spawns=#markers,
        obstructed=bad,unsupported=unsupported,pathsToSpawn01=paths}
end
