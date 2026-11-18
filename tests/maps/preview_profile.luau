-- MCP Client: paired comparison, same process/arena/camera, production Config.
local P=game.Players.LocalPlayer
local Run=game:GetService("RunService")
local device=game:GetService("StudioDeviceSimulatorService")
local camera=workspace.CurrentCamera
local hidden={}
for _,gui in P.PlayerGui:GetChildren() do if gui:IsA("ScreenGui") then hidden[gui]=gui.Enabled;gui.Enabled=false end end
local oldQuality=settings().Rendering.QualityLevel
local oldFrame,oldType=camera.CFrame,camera.CameraType
local fixed=CFrame.lookAt(Vector3.new(37,13,39),Vector3.new(-6,5,-11))
local views={}
local output={human=false,baselineCommit="3b4f8f3",mode="paired voting UI rendering",sampleSeconds=10,warmupSeconds=3,cases={},construction={}}
workspace:SetAttribute("RefinePreviewDone",false)
task.spawn(function()
    local ok,err=pcall(function()
        local selected
        for _,id in device:GetDeviceListAsync() do
            local info=device:GetDeviceInfoAsync(id)
            if info.DeviceForm==Enum.DeviceForm.Desktop then selected=id;break end
        end
        assert(selected,"No desktop simulator preset")
        for _,kind in {"baseline","candidate"} do
            local module=if kind=="baseline" then P.PlayerScripts.UmbralClient.UmbralQABaselineVote else P.PlayerScripts.UmbralClient.MapSelection
            local start=os.clock()
            local view=require(module).create(P.PlayerGui,function() return true end)
            local gui=view.cards[1].frame:FindFirstAncestorOfClass("ScreenGui");gui.Name="UmbralQAComparison"..kind
            local createMs=(os.clock()-start)*1000
            start=os.clock()
            view.state({phase="voting",ready=true,deadline=0,vote={id=1,options={"puerto","invernadero"},counts={puerto=2,invernadero=1},selected="puerto"}})
            local cloneMs=(os.clock()-start)*1000
            local parts=0
            for _,card in view.cards do for _,p in card.world:GetDescendants() do if p:IsA("BasePart") then parts+=1 end end end
            output.construction[kind]={createMs=createMs,initialStateMs=cloneMs,previewParts=parts}
            gui.Enabled=false;views[kind]={view=view,gui=gui}
        end
        for _,quality in {Enum.QualityLevel.Level05,Enum.QualityLevel.Level10} do
            settings().Rendering.QualityLevel=quality
            for _,size in {Vector2.new(1280,720),Vector2.new(1920,1080)} do
                device:SetDeviceAsync(selected);device:SetResolutionAsync(size.X,size.Y)
                device:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
                for sample=1,2 do
                    for _,kind in {"baseline","candidate"} do
                        workspace:SetAttribute("RefinePreviewProgress",quality.Name.." / "..tostring(size).." / "..kind.." / "..sample)
                        for key,item in views do item.gui.Enabled=key==kind;item.view.resize(size) end
                        task.wait(3)
                        camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=fixed;camera.FieldOfView=70
                        assert(camera.ViewportSize==size)
                        local frames,cpu,gpu={},{},{}
                        local stats=game:GetService("Stats");local start=os.clock()
                        repeat
                            table.insert(frames,Run.PreRender:Wait()*1000)
                            table.insert(cpu,stats.RenderCPUFrameTime*1000);table.insert(gpu,stats.RenderGPUFrameTime*1000)
                        until os.clock()-start>=10
                        assert(camera.CFrame==fixed and camera.ViewportSize==size)
                        for gui in hidden do assert(not gui.Enabled,"Production GUI changed") end
                        for _,values in {frames,cpu,gpu} do table.sort(values) end
                        local function p(values,f) return values[math.ceil(#values*f)] end
                        table.insert(output.cases,{kind=kind,width=size.X,height=size.Y,quality=quality.Name,sample=sample,frames=#frames,
                            p50Ms=p(frames,.5),p95Ms=p(frames,.95),cpuP95Ms=p(cpu,.95),gpuP95Ms=p(gpu,.95),memoryMb=stats:GetTotalMemoryUsageMb()})
                        workspace:SetAttribute("RefinePreviewPartial",game.HttpService:JSONEncode(output))
                    end
                end
            end
        end
    end)
    for _,item in views do item.gui:Destroy() end
    settings().Rendering.QualityLevel=oldQuality;camera.CFrame=oldFrame;camera.CameraType=oldType
    for gui,value in hidden do gui.Enabled=value end
    output.ok=ok;output.error=if ok then nil else tostring(err)
    workspace:SetAttribute("RefinePreviewResult",game.HttpService:JSONEncode(output))
    workspace:SetAttribute("RefinePreviewDone",true)
end)
return "Paired voting profile started; save RefinePreviewResult before stopping"
