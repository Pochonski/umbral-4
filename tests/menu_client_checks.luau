-- Run through Studio MCP in Play Client, alone in the waiting lobby.
-- Uses VirtualInput, not human input. Does not belong in a release place.
local players = game:GetService("Players")
local input = game:GetService("UserInputService")
local insetService = game:GetService("GuiService")
local devices = game:GetService("StudioDeviceSimulatorService")
local player = players.LocalPlayer
local gui = player.PlayerGui.Umbral4
local terminal = player.PlayerGui.UmbralTerminal.ZonaSegura.Terminal
local virtual = assert(input:CreateVirtualInput())
local checks = {}
local function pass(name) table.insert(checks, name) end
local function click(button)
    local inset = insetService:GetGuiInset()
    local position = button.AbsolutePosition + button.AbsoluteSize / 2 + inset
    virtual:SendMousePosition(position)
    virtual:SendMouseButton(position, Enum.UserInputType.MouseButton1, true, 0)
    task.wait(.04)
    virtual:SendMouseButton(position, Enum.UserInputType.MouseButton1, false, 0)
    task.wait(.18)
end
local function findText(root, value)
    for _, item in root:GetDescendants() do
        if item:IsA("TextButton") and item.Text == value then return item end
    end
    error("Missing button: " .. value)
end
local function visibleText(root, fragment)
    for _, item in root:GetDescendants() do
        if item:IsA("TextLabel") and item.Text:find(fragment, 1, true) then return true end
    end
    return false
end
local function tap(key)
    virtual:SendKey(true, key, false)
    task.wait(.04)
    virtual:SendKey(false, key, false)
    task.wait(.04)
end
if gui.Panel.Visible then click(findText(gui.Panel, "Volver")) end
if terminal.Jugar.Text == "Salir de la cola" then click(terminal.Jugar); task.wait(.4) end
local layouts = {}
for _, size in {Vector2.new(1280,720), Vector2.new(1920,1080), Vector2.new(1280,800), Vector2.new(1024,768)} do
    devices:SetDeviceAsync("hd_720")
    devices:SetResolutionAsync(size.X, size.Y)
    devices:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
    task.wait(.35)
    assert(workspace.CurrentCamera.ViewportSize == size, "Wrong render resolution")
    local function audit(root)
        local count = 0
        local inset, bottomInset = insetService:GetGuiInset()
        for _, item in root:GetDescendants() do
            if item:IsA("TextLabel") or item:IsA("TextButton") then
                local visible = true
                local ancestor = item
                while ancestor and ancestor ~= root do
                    if ancestor:IsA("GuiObject") and not ancestor.Visible then visible = false end
                    ancestor = ancestor.Parent
                end
                if visible and item.Text ~= "" then
                    local p, s = item.AbsolutePosition + inset, item.AbsoluteSize
                    assert(p.X >= -1 and p.Y >= inset.Y - 1 and p.X+s.X <= size.X+1
                        and p.Y+s.Y <= size.Y-bottomInset.Y+1, "Outside safe viewport: " .. item:GetFullName())
                    assert(item.TextBounds.X <= s.X+2 and item.TextBounds.Y <= s.Y+2, "Text clipped: " .. item.Text)
                    count += 1
                end
            end
        end
        return count
    end
    local count = audit(terminal)
    click(terminal.ComoJugar)
    assert(gui.Panel.Visible and visibleText(gui.Panel, "Cómo jugar"), "How button failed")
    count += audit(gui.Panel)
    click(findText(gui.Panel, "Volver"))
    assert(not gui.Panel.Visible, "Back failed")
    click(terminal.Ajustes)
    assert(gui.Panel.Visible and visibleText(gui.Panel, "Sensibilidad"), "Settings button failed")
    count += audit(gui.Panel)
    click(findText(gui.Panel, "Volver"))
    table.insert(layouts, {width=size.X,height=size.Y,texts=count})
end
pass("four native resolutions: bounds, text, How, Settings, Back")
devices:SetDeviceAsync("hd_720")
devices:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
task.wait(.3)
click(terminal.Jugar)
task.wait(.5)
assert(terminal.Jugar.Text == "Salir de la cola", "Ready failed")
click(terminal.Jugar)
task.wait(.5)
assert(terminal.Jugar.Text == "Jugar", "Unready failed")
pass("ready and leave queue through production buttons")
click(terminal.ComoJugar)
for _, key in {Enum.KeyCode.KeypadOne,Enum.KeyCode.KeypadOne,Enum.KeyCode.KeypadOne,Enum.KeyCode.KeypadOne} do tap(key) end
assert(visibleText(gui.Panel, "Inténtalo otra vez"), "Wrong practice code not reported")
for _, key in {Enum.KeyCode.KeypadZero,Enum.KeyCode.KeypadNine,Enum.KeyCode.KeypadOne,Enum.KeyCode.KeypadSeven} do tap(key) end
assert(visibleText(gui.Panel, "Código correcto"), "Correct practice code not reported")
pass("practice wrong and correct codes through VirtualInput")
local backspaceOK, backspaceReason = pcall(function()
    tap(Enum.KeyCode.KeypadZero)
    tap(Enum.KeyCode.KeypadNine)
    tap(Enum.KeyCode.Backspace)
    assert(visibleText(gui.Panel, "0 · · ·"), "Backspace did not erase")
end)
if not backspaceOK then
    assert(tostring(backspaceReason):find("permanently bound",1,true), tostring(backspaceReason))
else pass("Backspace erases a practice digit") end
click(findText(gui.Panel,"Volver"))
click(terminal.Ajustes)
local settings = gui.Panel.ZonaSegura.Contenido.Ajustes
local plusButtons = {}
for _, child in settings:GetChildren() do
    if child:IsA("TextButton") and child.Text == "+" then table.insert(plusButtons,child) end
end
table.sort(plusButtons,function(a,b) return a.Position.Y.Offset < b.Position.Y.Offset end)
click(plusButtons[1]); click(plusButtons[2])
assert(visibleText(settings,"115 %") and visibleText(settings,"80 %"), "Options did not apply")
click(findText(settings,"Movimiento reducido  ·  Desactivado"))
assert(findText(settings,"Movimiento reducido  ·  Activado"))
click(findText(gui.Panel,"Volver"))
tap(Enum.KeyCode.M)
assert(gui.Panel.Visible and visibleText(settings,"115 %"), "M or session settings failed")
tap(Enum.KeyCode.M)
assert(not gui.Panel.Visible, "M did not close")
assert(player.CameraMode == Enum.CameraMode.Classic and input.MouseBehavior == Enum.MouseBehavior.Default)
pass("options, reduced motion, M, session persistence, unlocked lobby mouse")
return {checks=checks,layouts=layouts,backspaceInjected=backspaceOK,
    backspaceLimitation=if backspaceOK then nil else tostring(backspaceReason),human=false}
