-- MCP Client in an idle QA copy. Humanoid movement, not physical keyboard input.
local P=game.Players.LocalPlayer
local character=P.Character or P.CharacterAdded:Wait()
local humanoid=character:WaitForChild("Humanoid")
local root=character:WaitForChild("HumanoidRootPart")
local active=workspace.UmbralWorld.ActiveArena
assert(active:GetAttribute("MapId")=="relevo","Load Relevo before running spawn QA")
local arena=assert(active:FindFirstChildWhichIsA("Model"))
local controls=require(P.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local previous=character:GetPivot()
local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances={arena};overlap.RespectCanCollide=true
local output={human=false,input="Humanoid:MoveTo; no keyboard",spawns={}}
controls:Disable()
local ok,err=pcall(function()
    for _,name in {"Spawn 03","Spawn 09"} do
        local marker=arena.Spawns[name]
        local colliders={}
        for _,part in workspace:GetPartBoundsInBox(marker.CFrame,Vector3.new(2.5,5,2.5),overlap) do
            table.insert(colliders,{path=part:GetFullName(),position=tostring(part.Position),size=tostring(part.Size)})
        end
        local sx=if marker.Position.X>0 then -1 else 1
        local sz=if marker.Position.Z>0 then -1 else 1
        local inward=Vector3.new(-marker.Position.X,0,-marker.Position.Z).Unit
        local cases={{name="inward X",direction=Vector3.xAxis*sx},{name="inward Z",direction=Vector3.zAxis*sz},
            {name="toward centre",direction=inward},{name="toward beacon",direction=if name=="Spawn 03" then Vector3.new(-1,0,-1).Unit else Vector3.xAxis}}
        local row={position=tostring(marker.Position),conservativeEnvelope=colliders,routes={}}
        for _,case in cases do
            character:PivotTo(marker.CFrame);root.AssemblyLinearVelocity=Vector3.zero
            task.wait(.4)
            local from=root.Position;local goal=from+case.direction*5
            humanoid:MoveTo(goal);task.wait(1.2);humanoid:MoveTo(root.Position)
            local delta=root.Position-from
            table.insert(row.routes,{name=case.name,travelled=Vector3.new(delta.X,0,delta.Z).Magnitude,
                remaining=(root.Position-goal).Magnitude,from=tostring(from),to=tostring(root.Position)})
        end
        row.centreExitClear=row.routes[3].travelled>4
        assert(row.centreExitClear,name.." cannot leave toward arena centre")
        output.spawns[name]=row
    end
end)
character:PivotTo(previous);root.AssemblyLinearVelocity=Vector3.zero
controls:Enable()
output.ok=ok;output.error=if ok then nil else tostring(err)
return output
