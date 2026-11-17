-- Execute in the Client of foreground Studio Play, beginning with Device Simulator off.
local devices = game:GetService("StudioDeviceSimulatorService")
local runService = game:GetService("RunService")
local stats = game:GetService("Stats")
local render = settings().Rendering
local previousQuality = render.QualityLevel
local camera = workspace.CurrentCamera
local oldType, oldFrame, oldFocus, oldFov = camera.CameraType, camera.CFrame, camera.Focus, camera.FieldOfView
local requestedDevice = "hd_720"
local expectedSize = if requestedDevice == "hd_720" then Vector2.new(1280, 720) else Vector2.new(1920, 1080)
local views = {
    {"patio", Vector3.new(4.1, 4.45, 8.1), Vector3.new(0, 2.95, 0)},
    {"gallery", Vector3.new(-40, 4.05, -1.8), Vector3.new(-26, 3.85, 2.2)},
    {"walkway", Vector3.new(31, 9.85, 13), Vector3.new(31, 7.9, -11)},
}
local result = {panels = {}}
local initialScaling
local ok, message = pcall(function()
    devices:SetDeviceAsync(requestedDevice)
    initialScaling = devices:GetScalingModeAsync()
    devices:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
    render.QualityLevel = Enum.QualityLevel.Level10
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = 70
    task.wait(1)
    result.viewport = tostring(camera.ViewportSize)
    result.device = tostring(devices:GetResolutionAsync())
    result.quality = render.QualityLevel.Name
    assert(camera.ViewportSize == expectedSize and devices:GetResolutionAsync() == expectedSize,
        "Expected " .. tostring(expectedSize) .. ", got " .. result.viewport .. " (device " .. result.device .. ")")
    for _, view in views do
        camera.CFrame = CFrame.lookAt(view[2], view[3])
        camera.Focus = CFrame.new(view[3])
        task.wait(.8)
        local frames, cpu, gpu = {}, {}, {}
        for index = 1, 150 do
            frames[index] = runService.PreRender:Wait() * 1000
            cpu[index] = stats.RenderCPUFrameTime * 1000
            gpu[index] = stats.RenderGPUFrameTime * 1000
        end
        for _, samples in {frames, cpu, gpu} do table.sort(samples) end
        result.panels[view[1]] = {
            p50 = frames[75], p95 = frames[143], cpuP95 = cpu[143], gpuP95 = gpu[143], samples = #frames,
        }
    end
    assert(camera.ViewportSize == expectedSize, "Viewport changed during the sample")
end)
pcall(function()
    if initialScaling then devices:SetScalingModeAsync(initialScaling) end
    devices:StopSimulationAsync()
end)
render.QualityLevel = previousQuality
camera.CameraType, camera.CFrame, camera.Focus, camera.FieldOfView = oldType, oldFrame, oldFocus, oldFov
assert(ok, message)
return result
