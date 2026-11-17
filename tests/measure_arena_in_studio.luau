-- Run in the Client data model of a foreground Studio Play session.
local runService = game:GetService("RunService")
local stats = game:GetService("Stats")
local gui = game.Players.LocalPlayer.PlayerGui:WaitForChild("Umbral4", 8)
assert(gui and workspace.CurrentCamera, "Start a single-client Studio Play session first")
local camera = workspace.CurrentCamera
local render = settings().Rendering
local previousQuality = render.QualityLevel
local oldType, oldFrame, oldFocus, oldFov = camera.CameraType, camera.CFrame, camera.Focus, camera.FieldOfView
local size = camera.ViewportSize
local views = {
    {"courtyard", Vector3.new(4.1, 4.45, 8.1), Vector3.new(0, 2.95, 0)},
    {"cooling", Vector3.new(38, 4.45, -14), Vector3.new(46, 3.4, -4)},
    {"gallery", Vector3.new(-40, 4.05, -1.8), Vector3.new(-26, 3.85, 2.2)},
    {"walkway", Vector3.new(31, 9.85, 13), Vector3.new(31, 7.9, -11)},
}
local requestedQuality = Enum.QualityLevel.Automatic
local result = {
    viewport = tostring(size),
    panels = {},
}
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 70
local ok, errorMessage = pcall(function()
    render.QualityLevel = requestedQuality
    result.quality = render.QualityLevel.Name
    for _, view in views do
        camera.CFrame = CFrame.lookAt(view[2], view[3])
        camera.Focus = CFrame.new(view[3])
        task.wait(.85)
        local frame, cpu, gpu = {}, {}, {}
        local drawCalls, triangles = 0, 0
        for index = 1, 150 do
            frame[index] = runService.PreRender:Wait() * 1000
            cpu[index] = stats.RenderCPUFrameTime * 1000
            gpu[index] = stats.RenderGPUFrameTime * 1000
            drawCalls += stats.SceneDrawcallCount
            triangles += stats.SceneTriangleCount
        end
        for _, samples in {frame, cpu, gpu} do table.sort(samples) end
        result.panels[view[1]] = {
            samples = #frame, frameP50 = frame[75], frameP95 = frame[143],
            cpuP95 = cpu[143], gpuP95 = gpu[143],
            meanDrawCalls = drawCalls / #frame, meanTriangles = triangles / #frame,
        }
    end
    assert(camera.ViewportSize == size, "Viewport resized during the benchmark")
end)
render.QualityLevel = previousQuality
camera.CameraType, camera.CFrame, camera.Focus, camera.FieldOfView = oldType, oldFrame, oldFocus, oldFov
assert(ok, errorMessage)
return result
