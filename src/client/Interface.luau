local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Lobby = require(script.Parent.Lobby)

local ink = Color3.fromRGB(235, 242, 243)
local muted = Color3.fromRGB(153, 176, 188)
local panel = Color3.fromRGB(17, 31, 43)
local wash = Color3.fromRGB(30, 48, 62)
local dark = Color3.fromRGB(12, 21, 29)
local gold = Color3.fromRGB(255, 193, 83)
local mint = Color3.fromRGB(104, 231, 206)
local coral = Color3.fromRGB(255, 147, 113)

local Interface = {}
Interface.Colors = { ink = ink, muted = muted, gold = gold, mint = mint, coral = coral }

local function make(kind, parent, properties)
    local item = Instance.new(kind)
    for name, value in properties do item[name] = value end
    item.Parent = parent
    return item
end

local function canvas(parent, name, size, position, anchor, color, transparency)
    return make("Frame", parent, {
        Name = name, Size = size, Position = position, AnchorPoint = anchor,
        BackgroundColor3 = color, BackgroundTransparency = transparency or 0, BorderSizePixel = 0,
    })
end

local function label(parent, value, size, align, color, position, dimensions, font)
    return make("TextLabel", parent, {
        Text = value, Font = font or Enum.Font.GothamMedium, TextSize = size,
        TextXAlignment = align or Enum.TextXAlignment.Left, TextColor3 = color or ink,
        Position = position, Size = dimensions, BackgroundTransparency = 1,
    })
end

local function corner(element, radius)
    make("UICorner", element, { CornerRadius = UDim.new(0, radius) })
end

local function button(parent, value, x, y, width, color, textColor)
    local item = make("TextButton", parent, {
        Text = value, Size = UDim2.fromOffset(width, 42), Position = UDim2.fromOffset(x, y),
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = textColor,
        BackgroundColor3 = color, BorderSizePixel = 0,
    })
    corner(item, 5)
    return item
end

local function stroke(element, color, transparency)
    return make("UIStroke", element, {
        Color = color, Transparency = transparency or 0, Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local zero = Vector2.zero
local centered = Vector2.new(0.5, 0.5)
local center = Enum.TextXAlignment.Center
local bold = Enum.Font.GothamBold
local function formatTime(seconds)
    local remaining = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
end

function Interface.create(playerGui)
    local gui = make("ScreenGui", playerGui, {
        Name = "Umbral4", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true, DisplayOrder = 8,
    })
    local hud = canvas(gui, "HUD", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, dark, 1)
    local upper = canvas(hud, "Puntuación", UDim2.fromOffset(428, 73),
        UDim2.new(0.5, 0, 0, 27), Vector2.new(0.5, 0), panel, 0.05)
    corner(upper, 8)
    stroke(upper, muted, 0.72)
    canvas(upper, "Acento", UDim2.fromOffset(146, 2), UDim2.fromOffset(141, 0), zero, gold)
    local topScales = { make("UIScale", upper, {}) }
    local scoreLabels = {}
    for i, name in { "TUS BAJAS", "TIEMPO", "LÍDER" } do
        local x = (i - 1) * 142
        label(upper, name, 11, center, muted, UDim2.fromOffset(x, 11), UDim2.fromOffset(142, 14), bold)
        scoreLabels[i] = label(upper, "–", 26, center, if i == 2 then ink else gold,
            UDim2.fromOffset(x, 26), UDim2.fromOffset(142, 32), bold)
    end
    local goalLine = canvas(upper, "Progreso", UDim2.fromOffset(400, 3), UDim2.fromOffset(14, 65), zero, wash)
    local fill = canvas(goalLine, "Meta", UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), zero, mint)
    local bottom = canvas(hud, "Entrada", UDim2.fromOffset(266, 96),
        UDim2.new(0.5, 0, 1, -47), Vector2.new(0.5, 1), panel, 0.06)
    corner(bottom, 7)
    stroke(bottom, muted, 0.72)
    table.insert(topScales, make("UIScale", bottom, {}))
    local slots = {}
    local slotBorders = {}
    for i = 1, 4 do
        local cell = canvas(bottom, "Dígito", UDim2.fromOffset(49, 50),
            UDim2.fromOffset(25 + (i - 1) * 56, 12), zero, wash)
        corner(cell, 4)
        slotBorders[i] = stroke(cell, muted, 0.7)
        slots[i] = label(cell, "·", 29, center, muted, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Enum.Font.RobotoMono)
    end
    local status = label(bottom, "ESCRIBE LOS 4 DÍGITOS", 11, center, muted,
        UDim2.fromOffset(8, 68), UDim2.fromOffset(250, 16), bold)
    local crosshair = canvas(hud, "Mira", UDim2.fromOffset(4, 4), UDim2.fromScale(.5, .5), centered, ink, .25)
    corner(crosshair, 3)
    local feedback = label(hud, "", 19, center, mint, UDim2.new(.5, -230, .5, 41), UDim2.fromOffset(460, 32), bold)
    feedback.TextStrokeColor3 = dark
    feedback.TextStrokeTransparency = .26
    local settingsHint = label(hud, "M  AJUSTES", 12, Enum.TextXAlignment.Right, ink,
        UDim2.new(1, -156, 1, -42), UDim2.fromOffset(120, 19), bold)
    settingsHint.TextStrokeTransparency = 0.4

    local lobby = Lobby.create(playerGui)
    local playButton, howButton, settingsButton = lobby.play, lobby.how, lobby.settings
    local queueStatus = lobby.queue

    local blackout = canvas(gui, "Reaparición", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, dark, .08)
    blackout.Visible = false
    local deathCard = canvas(blackout, "Estado", UDim2.fromOffset(450, 212), UDim2.fromScale(.5, .5), centered, panel)
    corner(deathCard, 8)
    local deathScale = make("UIScale", deathCard, {})
    local deathHeading = label(deathCard, "ELIMINACIÓN", 15, center, coral,
        UDim2.fromOffset(18, 20), UDim2.fromOffset(414, 29), bold)
    local deathBy = label(deathCard, "", 17, center, ink,
        UDim2.fromOffset(20, 146), UDim2.fromOffset(410, 38))
    local countLabel = label(deathCard, "6", 66, center, ink,
        UDim2.fromOffset(20, 63), UDim2.fromOffset(410, 74), bold)

    local resultsShade = canvas(gui, "Resultados", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, dark, .12)
    resultsShade.Visible = false
    local results = canvas(resultsShade, "Tabla", UDim2.fromOffset(550, 489), UDim2.fromScale(.5, .5), centered, panel)
    corner(results, 9)
    stroke(results, muted, .6)
    local resultScale = make("UIScale", results, {})
    label(results, "ESTACIÓN DE RELEVO", 12, nil, gold,
        UDim2.fromOffset(25, 19), UDim2.fromOffset(500, 22), bold)
    local winnerLabel = label(results, "", 30, nil, ink, UDim2.fromOffset(25, 48), UDim2.fromOffset(500, 47), bold)
    winnerLabel.TextTruncate = Enum.TextTruncate.AtEnd
    label(results, "JUGADOR", 12, nil, muted, UDim2.fromOffset(38, 108), UDim2.fromOffset(280, 20), bold)
    label(results, "BAJAS", 12, center, muted, UDim2.fromOffset(341, 108), UDim2.fromOffset(69, 20), bold)
    label(results, "MUERTES", 12, center, muted, UDim2.fromOffset(423, 108), UDim2.fromOffset(84, 20), bold)
    local rows = {}
    for i = 1, 8 do
        local row = canvas(results, "Jugador", UDim2.fromOffset(500, 34), UDim2.fromOffset(25, 135 + (i - 1)*38), zero, wash)
        corner(row, 4)
        local name = label(row, "", 15, nil, ink, UDim2.fromOffset(13, 0), UDim2.fromOffset(298, 34))
        name.TextTruncate = Enum.TextTruncate.AtEnd
        local kills = label(row, "", 15, center, gold, UDim2.fromOffset(316, 0), UDim2.fromOffset(69, 34), bold)
        local deaths = label(row, "", 15, center, muted, UDim2.fromOffset(398, 0), UDim2.fromOffset(84, 34), bold)
        rows[i] = { frame = row, name = name, kills = kills, deaths = deaths }
    end
    local nextRound = label(results, "", 13, nil, mint, UDim2.fromOffset(25, 447), UDim2.fromOffset(500, 25), bold)

    local modalShade = canvas(gui, "Panel", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, dark, .22)
    modalShade.Visible = false
    -- The backdrop fills the viewport; only the interactive content uses safe insets.
    modalShade.Active = true
    local modalSafe = canvas(modalShade, "ZonaSegura", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, panel, 1)
    local modal = canvas(modalSafe, "Contenido", UDim2.fromOffset(540, 440), UDim2.fromScale(.5, .5), centered, panel)
    corner(modal, 8)
    stroke(modal, muted, .6)
    local modalScale = make("UIScale", modal, {})
    canvas(modal, "Acento", UDim2.fromOffset(96, 3), UDim2.fromOffset(32, 0), zero, gold)
    label(modal, "UMBRAL 4  /  TERMINAL", 11, nil, muted,
        UDim2.fromOffset(32, 22), UDim2.fromOffset(476, 20), Enum.Font.RobotoMono)
    local modalTitle = label(modal, "", 30, nil, ink,
        UDim2.fromOffset(32, 48), UDim2.fromOffset(476, 41), bold)
    canvas(modal, "Separador", UDim2.fromOffset(476, 1), UDim2.fromOffset(32, 101), zero, wash)
    local how = canvas(modal, "Práctica", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, panel, 1)
    local instructions = label(how, "Muévete con WASD, salta con Espacio y mira con el ratón. Cuando veas la placa de un rival, escribe los cuatro dígitos.",
        16, nil, ink, UDim2.fromOffset(32, 117), UDim2.fromOffset(476, 65))
    instructions.TextWrapped = true
    local samplePlate = label(how, "0917", 41, center, dark,
        UDim2.fromOffset(189, 200), UDim2.fromOffset(162, 55), Enum.Font.RobotoMono)
    samplePlate.BackgroundTransparency = 0
    samplePlate.BackgroundColor3 = Color3.fromRGB(255, 239, 194)
    corner(samplePlate, 5)
    local demoDigits = label(how, "· · · ·", 23, center, gold,
        UDim2.fromOffset(32, 266), UDim2.fromOffset(476, 34), Enum.Font.RobotoMono)
    local demoNote = label(how, "Escribe el código para probar el ataque", 14, center, ink,
        UDim2.fromOffset(32, 310), UDim2.fromOffset(476, 23))
    label(how, "RETROCESO  /  BORRAR DÍGITO", 11, center, muted,
        UDim2.fromOffset(32, 340), UDim2.fromOffset(476, 18), Enum.Font.RobotoMono)
    local settings = canvas(modal, "Ajustes", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), zero, panel, 1)
    local sensitivity = label(settings, "", 16, nil, ink, UDim2.fromOffset(32, 133), UDim2.fromOffset(340, 42))
    local volume = label(settings, "", 16, nil, ink, UDim2.fromOffset(32, 197), UDim2.fromOffset(340, 42))
    local settingsButtons = {
        sensitivityDown = button(settings, "−", 398, 133, 46, wash, ink),
        sensitivityUp = button(settings, "+", 462, 133, 46, wash, ink),
        volumeDown = button(settings, "−", 398, 197, 46, wash, ink),
        volumeUp = button(settings, "+", 462, 197, 46, wash, ink),
        motion = button(settings, "", 32, 270, 476, wash, ink),
    }
    label(settings, "Los ajustes se conservan durante esta sesión.", 13, center, muted,
        UDim2.fromOffset(32, 330), UDim2.fromOffset(476, 23))
    local closeButton = button(modal, "Volver", 32, 376, 476, gold, dark)

    local view = {
        gui = gui, play = playButton, how = howButton, settings = settingsButton,
        close = closeButton, controls = settingsButtons, modal = nil, reduced = false,
    }
    local optionFeedback = {}
    for _, item in settingsButtons do
        table.insert(optionFeedback, Lobby.buttonFeedback(item, function() return view.reduced end, false))
    end
    table.insert(optionFeedback, Lobby.buttonFeedback(closeButton, function() return view.reduced end, true))

    function view.resize(viewport)
        local scale = math.clamp(math.min(viewport.X / 680, viewport.Y / 620), .46, 1.15)
        lobby.resize(viewport)
        deathScale.Scale, resultScale.Scale = scale, scale
        local topLeft, bottomRight = GuiService:GetGuiInset()
        modalSafe.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
        modalSafe.Size = UDim2.new(1, -topLeft.X - bottomRight.X, 1, -topLeft.Y - bottomRight.Y)
        modalScale.Scale = math.min(1.2, viewport.Y / 720, math.max(.1, (viewport.X - topLeft.X - bottomRight.X - 48) / 540),
            math.max(.1, (viewport.Y - topLeft.Y - bottomRight.Y - 48) / 440))
        for _, scaleObject in topScales do scaleObject.Scale = scale end
    end

    function view.showModal(name)
        view.modal = name
        modalShade.Visible = name ~= nil
        modalTitle.Text = if name == "how" then "Cómo jugar" else "Ajustes"
        how.Visible, settings.Visible = name == "how", name == "settings"
    end

    function view.options(sensitivityValue, volumeValue, reduce)
        view.reduced = reduce
        lobby.options(reduce)
        for _, refresh in optionFeedback do refresh() end
        sensitivity.Text = string.format("Sensibilidad  ·  %d %%", math.round(sensitivityValue * 100))
        volume.Text = string.format("Efectos  ·  %d %%", math.round(volumeValue * 100))
        settingsButtons.motion.Text = if reduce then "Movimiento reducido  ·  Activado" else "Movimiento reducido  ·  Desactivado"
    end

    function view.practice(digits, message)
        local cells = {}
        for i = 1, 4 do cells[i] = if i <= #digits then digits:sub(i, i) else "·" end
        demoDigits.Text = table.concat(cells, " ")
        demoNote.Text = message or "Escribe el código para probar el ataque"
    end

    function view.digits(value)
        for i, cell in slots do
            local digit = value:sub(i, i)
            cell.Text = if digit ~= "" then digit else "·"
            cell.TextColor3 = if digit == "" then muted else gold
            slotBorders[i].Color = if i == #value + 1 then gold else muted
            slotBorders[i].Transparency = if i == #value + 1 then .18 else .72
        end
    end

    function view.notify(message, hit)
        feedback.Text = message
        feedback.TextColor3 = if hit then mint else coral
        feedback.TextTransparency = 0
        if view.fade then view.fade:Cancel() end
        view.fade = TweenService:Create(feedback,
            TweenInfo.new(if view.reduced then .01 else .3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 1.02),
            {TextTransparency = 1})
        view.fade:Play()
    end

    function view.state(state, userId, supported)
        local playing = state.phase == "playing" and state.participating
        local alive = playing and state.status == "alive"
        hud.Visible = alive
        crosshair.Visible = alive
        lobby.show(not playing and state.phase ~= "results")
        blackout.Visible = playing and not alive
        resultsShade.Visible = state.phase == "results"
        playButton.Active = supported
        playButton.AutoButtonColor = false
        playButton.BackgroundColor3 = if supported then gold else wash
        playButton.TextColor3 = if supported then dark else ink
        playButton.Text = if not supported then "Requiere teclado y ratón"
            elseif state.ready then "Salir de la cola" else "Jugar"
        local ownKills = 0
        local leaderKills = 0
        local winnerNames = {}
        local winningIds = {}
        for _, id in state.winners do winningIds[id] = true end
        for i, row in rows do
            local score = state.scores[i]
            row.frame.Visible = score ~= nil
            if score then
                if score.userId == userId then ownKills = score.kills end
                if not score.left then leaderKills = math.max(leaderKills, score.kills) end
                if winningIds[score.userId] then table.insert(winnerNames, score.name) end
                row.name.Text = if score.left then score.name .. " · Abandono" else score.name
                row.name.TextColor3 = if winningIds[score.userId] then mint else ink
                row.kills.Text, row.deaths.Text = tostring(score.kills), tostring(score.deaths)
            end
        end
        scoreLabels[1].Text = string.format("%d / %d", ownKills, state.goal)
        scoreLabels[3].Text = tostring(leaderKills)
        fill.Size = UDim2.fromScale(if state.goal > 0 then math.clamp(ownKills / state.goal, 0, 1) else 0, 1)
        winnerLabel.Text = if state.endReason == "abandoned" then "Ronda sin ganador"
            elseif #winnerNames == 1 then "Victoria de " .. winnerNames[1]
            elseif #winnerNames > 1 then "Empate · " .. table.concat(winnerNames, ", ") else "Fin de la ronda"
    end

    function view.updateTime(state, now)
        if state.phase == "countdown" then
            queueStatus.Text = "La ronda empieza en " .. tostring(math.max(0, math.ceil(state.deadline - now))) .. " s"
        elseif state.phase == "playing" and not state.participating then
            queueStatus.Text = if state.ready then "En cola · Entrarás en la siguiente ronda" else "Ronda en curso"
        else
            queueStatus.Text = string.format("%d jugadores en cola · Se necesitan 2 para empezar", state.readyCount)
        end
        scoreLabels[2].Text = formatTime(state.deadline - now)
        local remaining = state.respawnAt - now
        deathHeading.Text = if state.status == "spawning" then "PREPARANDO APARICIÓN" else "REAPARECES EN"
        countLabel.Text = if state.status == "spawning" then "…" else tostring(math.max(0, math.ceil(remaining)))
        deathBy.Text = if state.killerName == "" then "" else "Te eliminó " .. state.killerName
        nextRound.Text = "Regreso al vestíbulo en " .. tostring(math.max(0, math.ceil(state.deadline - now))) .. " s"
        local protected = now < state.protectedUntil
        status.Text = if protected then string.format("PROTECCIÓN  %.1f s", math.max(0, state.protectedUntil - now))
            else "ESCRIBE LOS 4 DÍGITOS"
        status.TextColor3 = if protected then mint else muted
    end

    return view
end

return Interface
