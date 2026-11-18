-- Presentation only: queue membership and combat remain owned by Main and the server.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Lobby = {}
local steel = Color3.fromRGB(17, 31, 43)
local deep = Color3.fromRGB(9, 17, 25)
local surface = Color3.fromRGB(29, 45, 57)
local white = Color3.fromRGB(235, 242, 243)
local muted = Color3.fromRGB(166, 186, 197)
local amber = Color3.fromRGB(255, 193, 83)
local cyan = Color3.fromRGB(104, 219, 218)

local function make(class, parent, properties)
    local instance = Instance.new(class)
    for name, value in properties do instance[name] = value end
    instance.Parent = parent
    return instance
end

local function frame(parent, name, x, y, width, height, color)
    return make("Frame", parent, {
        Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = color, BorderSizePixel = 0,
    })
end

local function text(parent, name, value, x, y, width, height, size, color, font, alignment)
    return make("TextLabel", parent, {
        Name = name, Text = value, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
        BackgroundTransparency = 1, TextColor3 = color, TextSize = size,
        Font = font or Enum.Font.GothamMedium, TextXAlignment = alignment or Enum.TextXAlignment.Left,
    })
end

local function round(item, radius)
    make("UICorner", item, {CornerRadius = UDim.new(0, radius)})
end

local function border(item, color, transparency)
    return make("UIStroke", item, {Color = color, Transparency = transparency, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

-- Shared by the terminal and its existing dialogs. No perpetual animation loop.
function Lobby.buttonFeedback(item, isReduced, primary)
    item.AutoButtonColor = false
    local edge = border(item, if primary then amber else muted, if primary then .4 else .72)
    local hovering, pressing = false, false
    local tween
    local function refresh()
        if tween then tween:Cancel() end
        local active = item.Active
        local emphasis = active and (hovering or pressing)
        local transparency = if emphasis then (if pressing then .05 else .18) else (if primary then .4 else .72)
        if isReduced() then
            edge.Transparency = transparency
        else
            tween = TweenService:Create(edge, TweenInfo.new(.12, Enum.EasingStyle.Quad), {Transparency = transparency})
            tween:Play()
        end
    end
    item.MouseEnter:Connect(function() hovering = true; refresh() end)
    item.MouseLeave:Connect(function() hovering = false; pressing = false; refresh() end)
    item.SelectionGained:Connect(function() hovering = true; refresh() end)
    item.SelectionLost:Connect(function() hovering = false; pressing = false; refresh() end)
    item.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pressing = true; refresh()
        end
    end)
    item.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pressing = false; refresh()
        end
    end)
    item:GetPropertyChangedSignal("Active"):Connect(refresh)
    return refresh
end

function Lobby.create(playerGui)
    local gui = make("ScreenGui", playerGui, {
        Name = "UmbralTerminal", ResetOnSpawn = false, DisplayOrder = 7,
        IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local shade = make("Frame", gui, {Name = "Fondo", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = deep, BackgroundTransparency = .3, BorderSizePixel = 0})
    make("UIGradient", shade, {Rotation = 90, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, .15), NumberSequenceKeypoint.new(.5, .46), NumberSequenceKeypoint.new(1, 0),
    })})
    local safe = make("Frame", gui, {Name = "ZonaSegura", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)})
    local panel = frame(safe, "Terminal", 0, 0, 600, 500, steel)
    panel.AnchorPoint = Vector2.new(.5, .5)
    panel.Position = UDim2.fromScale(.5, .5)
    round(panel, 8)
    border(panel, muted, .65)
    make("UIGradient", panel, {Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(193, 209, 222))})
    local scale = make("UIScale", panel, {})
    local inner = frame(panel, "Marco", 8, 8, 584, 484, steel)
    inner.BackgroundTransparency = 1
    round(inner, 5)
    border(inner, muted, .91)
    frame(panel, "LuzSuperior", 40, 0, 112, 3, amber)
    frame(panel, "LuzSecundaria", 510, 0, 50, 2, cyan)
    for i = 0, 3 do frame(panel, "Marca", 40 + i * 6, 32, 3, 14, if i == 3 then amber else muted) end
    local station = text(panel, "Estacion", "ESTACIÓN DE RELEVO", 76, 29, 350, 20, 12, muted, Enum.Font.GothamBold)
    text(panel, "Identificador", "U4 / ACCESO", 445, 29, 115, 20, 11, muted, Enum.Font.RobotoMono, Enum.TextXAlignment.Right)
    frame(panel, "SeparadorSuperior", 40, 66, 520, 1, surface)
    text(panel, "Titulo", "UMBRAL", 40, 99, 402, 83, 76, white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    local badge = frame(panel, "Cuatro", 447, 105, 85, 74, amber)
    round(badge, 3)
    text(badge, "Numero", "4", 0, -2, 85, 78, 69, deep, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    text(panel, "Premisa", "Lee su número. Escríbelo. Sobrevive.", 40, 188, 520, 27, 18, white,
        Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    local status = frame(panel, "Estado", 40, 242, 520, 58, deep)
    round(status, 4)
    frame(status, "Indicador", 0, 13, 3, 32, cyan)
    local queue = text(status, "Cola", "Conectando con la partida…", 18, 7, 484, 44, 15, cyan,
        Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
    queue.TextWrapped = true
    local function button(name, value, x, y, width, height, primary)
        local item = make("TextButton", panel, {
            Name = name, Text = value, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height),
            BackgroundColor3 = if primary then amber else surface, BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = if primary then 20 else 15,
            TextColor3 = if primary then deep else white,
        })
        round(item, 4)
        return item
    end
    local play = button("Jugar", "Jugar", 40, 320, 520, 60, true)
    local how = button("ComoJugar", "Cómo jugar", 40, 394, 253, 46, false)
    local settings = button("Ajustes", "Ajustes", 307, 394, 253, 46, false)
    text(panel, "Controles", "TECLADO + RATÓN   /   4 DÍGITOS", 40, 462, 520, 18, 11, muted,
        Enum.Font.RobotoMono, Enum.TextXAlignment.Center)

    local view = {play = play, how = how, settings = settings, queue = queue, reduced = false}
    local refreshers = {}
    for _, item in {play, how, settings} do
        table.insert(refreshers, Lobby.buttonFeedback(item, function() return view.reduced end, item == play))
    end
    local entrance
    local shown = false
    function view.show(visible)
        gui.Enabled = visible
        if visible and not shown then
            if entrance then entrance:Cancel() end
            panel.Position = UDim2.fromScale(.5, .5)
            if not view.reduced then
                panel.Position += UDim2.fromOffset(0, 8)
                entrance = TweenService:Create(panel, TweenInfo.new(.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Position = UDim2.fromScale(.5, .5)})
                entrance:Play()
            end
        elseif not visible and entrance then entrance:Cancel() end
        shown = visible
    end
    function view.options(reduced)
        view.reduced = reduced
        if reduced and entrance then
            entrance:Cancel()
            panel.Position = UDim2.fromScale(.5, .5)
        end
        for _, refresh in refreshers do refresh() end
    end
    function view.location(name) station.Text = string.upper(name) end
    function view.resize(viewport)
        local topLeft, bottomRight = GuiService:GetGuiInset()
        safe.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
        safe.Size = UDim2.new(1, -topLeft.X - bottomRight.X, 1, -topLeft.Y - bottomRight.Y)
        scale.Scale = math.min(1.2, viewport.Y / 720, math.max(.1, (viewport.X - topLeft.X - bottomRight.X - 48) / 600),
            math.max(.1, (viewport.Y - topLeft.Y - bottomRight.Y - 48) / 500))
    end
    return view
end

return Lobby
