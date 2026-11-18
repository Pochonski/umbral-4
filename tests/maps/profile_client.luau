-- Single Studio client, production Config, isolated map rendering; not combat-load/FPS certification.
local R=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local H=game:GetService("HttpService")
local devices=game:GetService("StudioDeviceSimulatorService")
local inspector=R.UmbralQA.Inspect
assert(require(R.UmbralShared.Config).MinPlayers==2,"Use production Config for rendering measurements")
workspace:SetAttribute("MapsProfileDone",false)
task.spawn(function()
    local output={clients=1,human=false,mode="idle map rendering",warmupSeconds=5,sampleSeconds=15,samplesPerCase=2,
        camera={-8,4.5,-24,0,7,0},cases={},navigation={},occlusion={}}
    local originalQuality=settings().Rendering.QualityLevel
    local camera=workspace.CurrentCamera
    local originalFrame,originalType,originalFov=camera.CFrame,camera.CameraType,camera.FieldOfView
    local fixed=CFrame.lookAt(Vector3.new(-8,4.5,-24),Vector3.new(0,7,0))
    local starter=game:GetService("StarterGui")
    local core={}
    for _,kind in Enum.CoreGuiType:GetEnumItems() do
        if kind~=Enum.CoreGuiType.All then
            local valid,value=pcall(function() return starter:GetCoreGuiEnabled(kind) end)
            if valid then core[kind]=value end
        end
    end
    starter:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
    local enabled={}
    for _,name in {"Umbral4","UmbralTerminal","UmbralMapVote"} do
        local gui=game.Players.LocalPlayer.PlayerGui[name]; enabled[gui]=gui.Enabled; gui.Enabled=false
    end
    local ok,err=pcall(function()
        for _,id in {"relevo","puerto","invernadero"} do
            assert(inspector:InvokeServer("load:"..id))
            task.wait(1)
            output.navigation[id]=inspector:InvokeServer("inspect")
            output.occlusion[id]=inspector:InvokeServer("occlusion")
            assert(output.occlusion[id].mismatches==0,H:JSONEncode(output.occlusion[id]))
            camera.CameraType=Enum.CameraType.Scriptable
            camera.CFrame=CFrame.lookAt(Vector3.new(-8,4.5,-24),Vector3.new(0,7,0));camera.Focus=CFrame.new(0,7,0)
            for _,quality in {Enum.QualityLevel.Level05,Enum.QualityLevel.Level10} do
                settings().Rendering.QualityLevel=quality
                for _,size in {Vector2.new(1280,720),Vector2.new(1920,1080)} do
                    devices:SetDeviceAsync("hd_720"); devices:SetResolutionAsync(size.X,size.Y)
                    devices:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
                    workspace:SetAttribute("MapsProfileProgress",id.." / "..quality.Name.." / "..tostring(size))
                    task.wait(5)
                    camera.CameraType=Enum.CameraType.Scriptable
                    camera.CFrame=fixed; camera.Focus=CFrame.new(0,7,0);camera.FieldOfView=70
                    for gui in enabled do gui.Enabled=false end
                    assert(camera.ViewportSize==size,"Wrong native resolution")
                    for sample=1,2 do
                        local frames,cpu,gpu={},{},{}
                        local stats=game:GetService("Stats")
                        local started=os.clock()
                        repeat
                            table.insert(frames,Run.PreRender:Wait()*1000)
                            table.insert(cpu,stats.RenderCPUFrameTime*1000)
                            table.insert(gpu,stats.RenderGPUFrameTime*1000)
                        until os.clock()-started>=15
                        assert(camera.ViewportSize==size,"Viewport changed")
                        assert(camera.CFrame==fixed and camera.FieldOfView==70,"Camera changed")
                        for gui in enabled do assert(not gui.Enabled,"Game UI changed during sample") end
                        for _,values in {frames,cpu,gpu} do table.sort(values) end
                        local function p(values,n) return values[math.ceil(#values*n)] end
                        table.insert(output.cases,{mapId=id,quality=quality.Name,width=size.X,height=size.Y,sample=sample,
                            mapUiHidden=true,cameraFixed=true,fov=70,frames=#frames,seconds=os.clock()-started,p50Ms=p(frames,.5),p95Ms=p(frames,.95),
                            cpuP50Ms=p(cpu,.5),cpuP95Ms=p(cpu,.95),gpuP50Ms=p(gpu,.5),gpuP95Ms=p(gpu,.95),
                            totalMemoryMb=stats:GetTotalMemoryUsageMb()})
                    end
                end
            end
            local queried,scene=pcall(function() return game:GetService("SceneAnalysisService"):GetTriangleCompositionAsync() end)
            output[id.."Scene"]=if queried then scene else {error=tostring(scene)}
            workspace:SetAttribute("MapsProfilePartial",H:JSONEncode(output))
        end
    end)
    settings().Rendering.QualityLevel=originalQuality
    camera.CFrame,camera.CameraType,camera.FieldOfView=originalFrame,originalType,originalFov
    for kind,value in core do pcall(function() starter:SetCoreGuiEnabled(kind,value) end) end
    for gui,value in enabled do gui.Enabled=value end
    output.ok=ok;output.error=if ok then nil else tostring(err)
    workspace:SetAttribute("MapsProfileResult",H:JSONEncode(output))
    workspace:SetAttribute("MapsProfileDone",true)
end)
return "Map profile started; save MapsProfileResult before stopping Play"
