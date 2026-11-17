-- Run in the Client data model of a foreground Studio Play session.
local runService = game:GetService("RunService")
local stats = game:GetService("Stats")
local gui = game.Players.LocalPlayer.PlayerGui:WaitForChild("Umbral4", 8)
assert(gui and workspace.CurrentCamera, "Start a single-client Studio Play session first")
local camera = workspace.CurrentCamera
local oldType, oldFrame, oldFocus, oldFov = camera.CameraType, camera.CFrame, camera.Focus, camera.FieldOfView
local size = camera.ViewportSize
local views = {
    {"general", Vector3.new(79, 63, 89), Vector3.new(0, 0, -7)},
    {"courtyard", Vector3.new(17, 8.5, 25), Vector3.new(0, 3, -5)},
    {"walkway", Vector3.new(-31, 9.6, 13), Vector3.new(-28, 6, -12)},
}
local result = {
    viewport = tostring(size),
    quality = UserSettings().GameSettings.SavedQualityLevel.Name,
    panels = {},
}
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 70
local ok, errorMessage = pcall(function()
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
camera.CameraType, camera.CFrame, camera.Focus, camera.FieldOfView = oldType, oldFrame, oldFocus, oldFov
assert(ok, errorMessage)
return result
