local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Maps = require(ReplicatedStorage.UmbralShared.Maps)
local Lobby = require(script.Parent.Lobby)
local MapSelection = {}
function MapSelection.create(playerGui, reduced)
    local function make(kind, parent, props)
        local item = Instance.new(kind)
        for key, value in props do item[key] = value end
        item.Parent = parent
        return item
    end
    local function text(parent, value, x, y, w, h, size, color)
        return make("TextLabel", parent, {Text = value, Position = UDim2.fromOffset(x,y), Size = UDim2.fromOffset(w,h),
            BackgroundTransparency = 1, TextColor3 = color or Color3.fromRGB(235,242,243), TextSize = size,
            Font = Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left})
    end
    local gui = make("ScreenGui", playerGui, {Name="UmbralMapVote",DisplayOrder=7,ResetOnSpawn=false,IgnoreGuiInset=true,Enabled=false})
    make("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(9,17,25),BackgroundTransparency=.18,BorderSizePixel=0,Active=true})
    local safe=make("Frame",gui,{Name="ZonaSegura",Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
    local panel=make("Frame",safe,{Name="Votacion",Size=UDim2.fromOffset(760,440),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),BackgroundColor3=Color3.fromRGB(17,31,43),BorderSizePixel=0})
    make("UICorner",panel,{CornerRadius=UDim.new(0,8)})
    make("UIStroke",panel,{Color=Color3.fromRGB(104,219,218),Transparency=.6})
    local scale=make("UIScale",panel,{})
    text(panel,"UMBRAL 4 / SIGUIENTE DESTINO",28,20,550,20,12,Color3.fromRGB(104,219,218))
    text(panel,"Elige la próxima arena",28,52,640,38,30)
    local timer=text(panel,"",28,98,704,30,15,Color3.fromRGB(166,186,197))
    local cards={}
    for index=1,2 do
        local x=28+(index-1)*360
        local card=make("Frame",panel,{Name="Opcion"..index,Position=UDim2.fromOffset(x,145),Size=UDim2.fromOffset(344,228),
            BackgroundColor3=Color3.fromRGB(29,45,57),BorderSizePixel=0})
        make("UICorner",card,{CornerRadius=UDim.new(0,5)})
        local preview=make("ViewportFrame",card,{Name="Vista",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(344,108),
            BackgroundColor3=Color3.fromRGB(36,56,67),BorderSizePixel=0,Ambient=Color3.fromRGB(190,195,198),LightColor=Color3.fromRGB(255,236,208)})
        local world=make("WorldModel",preview,{})
        local camera=make("Camera",preview,{FieldOfView=38,CFrame=CFrame.lookAt(Vector3.new(66,42,78),Vector3.new(0,3,0))})
        preview.CurrentCamera=camera
        local name=text(card,"",14,116,316,34,19)
        local info=text(card,"",14,152,316,22,12,Color3.fromRGB(166,186,197))
        local button=make("TextButton",card,{Name="Votar",Text="Votar",Position=UDim2.fromOffset(14,181),Size=UDim2.fromOffset(316,34),
            BackgroundColor3=Color3.fromRGB(255,193,83),TextColor3=Color3.fromRGB(9,17,25),Font=Enum.Font.GothamBold,TextSize=14,BorderSizePixel=0})
        Lobby.buttonFeedback(button,reduced,true)
        cards[index]={frame=card,button=button,name=name,info=info,world=world,mapId=nil}
    end
    local leave=make("TextButton",panel,{Name="Salir",Text="Salir de la cola",Position=UDim2.fromOffset(28,385),Size=UDim2.fromOffset(200,30),
        BackgroundColor3=Color3.fromRGB(29,45,57),TextColor3=Color3.fromRGB(235,242,243),Font=Enum.Font.GothamMedium,TextSize=14,BorderSizePixel=0})
    Lobby.buttonFeedback(leave,reduced,false)
    text(panel,"Un voto por persona · Puedes cambiarlo",250,385,482,30,13,Color3.fromRGB(166,186,197))
    local view={cards=cards,leave=leave,voteId=nil}
    function view.resize(viewport)
        local tl,br=GuiService:GetGuiInset()
        safe.Position=UDim2.fromOffset(tl.X,tl.Y)
        safe.Size=UDim2.new(1,-tl.X-br.X,1,-tl.Y-br.Y)
        scale.Scale=math.min(1.2,viewport.Y/720,(viewport.X-tl.X-br.X-40)/760,(viewport.Y-tl.Y-br.Y-40)/440)
    end
    function view.state(state)
        local vote=state.vote
        gui.Enabled=state.phase=="voting" and state.ready and vote~=nil
        view.voteId=if vote then vote.id else nil
        if not gui.Enabled then return end
        for index,card in cards do
            local id=vote.options[index]
            card.frame.Visible=id~=nil
            card.button.Active=id~=nil
            if not id then continue end
            local entry
            for _, candidate in Maps do if candidate.id==id then entry=candidate; break end end
            if not entry then continue end
            card.name.Text=entry.name
            card.info.Text=entry.sector.." · "..tostring(vote.counts[id] or 0).." votos"
            card.button.Text=if vote.selected==id then "✓ Tu voto" else "Votar"
            if card.mapId~=id then
                card.world:ClearAllChildren()
                local previews=ReplicatedStorage:FindFirstChild("UmbralMapPreviews")
                local model=previews and previews:FindFirstChild(entry.model)
                if model then model:Clone().Parent=card.world end
                card.mapId=id
            end
        end
    end
    function view.updateTime(state,now)
        timer.Text="Cierra en "..math.max(0,math.ceil(state.deadline-now)).." s · El servidor decide los empates"
    end
    return view
end
return MapSelection
