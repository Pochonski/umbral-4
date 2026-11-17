-- Run via MCP in a single Play Client waiting in the lobby. Poll MenuProfileDone.
-- Use the same map, camera, foreground window, quality and Studio process count for both versions.
local RunService = game:GetService("RunService")
local devices = game:GetService("StudioDeviceSimulatorService")
local stats = game:GetService("Stats")
local http = game:GetService("HttpService")
assert(RunService:IsStudio() and RunService:IsClient())
workspace:SetAttribute("MenuProfileDone", false)
workspace:SetAttribute("MenuProfileError", nil)
workspace:SetAttribute("MenuProfileResult", nil)
task.spawn(function()
    local result = {quality="Level10",warmupSeconds=15,sampleSeconds=30,samplesPerResolution=3,
        camera={position={37,13,39},target={-6,5,-11}},resolutions={}}
    local originalQuality = settings().Rendering.QualityLevel
    local ok, message = pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level10
        for _, size in {Vector2.new(1280,720),Vector2.new(1920,1080)} do
            devices:SetDeviceAsync("hd_720")
            devices:SetResolutionAsync(size.X,size.Y)
            devices:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
            local camera = workspace.CurrentCamera
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = CFrame.lookAt(Vector3.new(37,13,39),Vector3.new(-6,5,-11))
            camera.Focus = CFrame.new(-6,5,-11)
            task.wait(15)
            assert(camera.ViewportSize == size, "Wrong resolution")
            local samples = {}
            for sample=1,3 do
                workspace:SetAttribute("MenuProfileProgress", tostring(size).." / "..sample)
                local frames, cpu, gpu = {}, {}, {}
                local started = os.clock()
                repeat
                    table.insert(frames, RunService.PreRender:Wait()*1000)
                    table.insert(cpu, stats.RenderCPUFrameTime*1000)
                    table.insert(gpu, stats.RenderGPUFrameTime*1000)
                until os.clock()-started >= 30
                assert(camera.ViewportSize == size, "Viewport changed during measurement")
                for _, values in {frames,cpu,gpu} do table.sort(values) end
                local function p(values, percentile) return values[math.ceil(#values*percentile)] end
                table.insert(samples,{frames=#frames,seconds=os.clock()-started,p50=p(frames,.5),p95=p(frames,.95),
                    cpuP50=p(cpu,.5),cpuP95=p(cpu,.95),gpuP50=p(gpu,.5),gpuP95=p(gpu,.95)})
            end
            table.insert(result.resolutions,{width=size.X,height=size.Y,samples=samples})
        end
    end)
    settings().Rendering.QualityLevel = originalQuality
    if not ok then workspace:SetAttribute("MenuProfileError",tostring(message)) end
    workspace:SetAttribute("MenuProfileResult",http:JSONEncode(result))
    workspace:SetAttribute("MenuProfileDone",true)
end)
return "Menu profile started; poll workspace attributes"
