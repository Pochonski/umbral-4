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
    local panel=make("Frame",safe,{Name="Votacion",Size=UDim2.fromOffset(760,526),AnchorPoint=Vector2.new(.5,.5),
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
        local card=make("Frame",panel,{Name="Opcion"..index,Position=UDim2.fromOffset(x,145),Size=UDim2.fromOffset(344,296),
            BackgroundColor3=Color3.fromRGB(29,45,57),BorderSizePixel=0})
        make("UICorner",card,{CornerRadius=UDim.new(0,5)})
        local stroke=make("UIStroke",card,{Color=Color3.fromRGB(104,219,218),Transparency=.85})
        local sky=make("Frame",card,{Name="FondoVista",Size=UDim2.fromOffset(344,146),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0})
        make("UIGradient",sky,{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(37,60,77),Color3.fromRGB(104,138,146))})
        local preview=make("ViewportFrame",card,{Name="Vista",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(344,146),
            BackgroundTransparency=1,BorderSizePixel=0,Ambient=Color3.fromRGB(156,176,187),
            LightColor=Color3.fromRGB(255,236,208),LightDirection=Vector3.new(-.6,-1,-.4)})
        local world=make("WorldModel",preview,{})
        local camera=make("Camera",preview,{FieldOfView=44})
        preview.CurrentCamera=camera
        local loading=text(card,"Preparando vista…",70,62,204,22,12,Color3.fromRGB(218,233,238))
        loading.TextXAlignment=Enum.TextXAlignment.Center
        local accent=make("Frame",card,{Position=UDim2.fromOffset(0,144),Size=UDim2.fromOffset(344,2),BorderSizePixel=0})
        local name=text(card,"",14,157,316,30,19)
        local description=text(card,"",14,190,316,23,12,Color3.fromRGB(166,186,197))
        local info=text(card,"",14,218,316,20,11,Color3.fromRGB(166,186,197))
        local button=make("TextButton",card,{Name="Votar",Text="Votar",Position=UDim2.fromOffset(14,247),Size=UDim2.fromOffset(316,36),
            BackgroundColor3=Color3.fromRGB(255,193,83),TextColor3=Color3.fromRGB(9,17,25),Font=Enum.Font.GothamBold,TextSize=14,BorderSizePixel=0})
        Lobby.buttonFeedback(button,reduced,true)
        cards[index]={frame=card,button=button,name=name,info=info,description=description,world=world,
            camera=camera,accent=accent,stroke=stroke,loading=loading,mapId=nil}
    end
    local leave=make("TextButton",panel,{Name="Salir",Text="Salir de la cola",Position=UDim2.fromOffset(28,466),Size=UDim2.fromOffset(200,30),
        BackgroundColor3=Color3.fromRGB(29,45,57),TextColor3=Color3.fromRGB(235,242,243),Font=Enum.Font.GothamMedium,TextSize=14,BorderSizePixel=0})
    Lobby.buttonFeedback(leave,reduced,false)
    text(panel,"Un voto por persona · Puedes cambiarlo",250,466,482,30,13,Color3.fromRGB(166,186,197))
    local view={cards=cards,leave=leave,voteId=nil}
    local retryAt=0
    local function tryPreview(card)
        local entry=card.entry
        if not entry or card.mapId==entry.id then return end
        local previews=ReplicatedStorage:FindFirstChild("UmbralMapPreviews")
        local model=previews and previews:FindFirstChild(entry.model)
        local count=model and model:FindFirstChild("PreviewPartCount")
        -- A model can replicate before its children. Never cache an incomplete clone.
        if count and count:IsA("IntValue") and count.Value>0 and #model:GetChildren()==count.Value+1 then
            model:Clone().Parent=card.world
            card.mapId=entry.id
            card.loading.Visible=false
        end
    end
    function view.resize(viewport)
        local tl,br=GuiService:GetGuiInset()
        safe.Position=UDim2.fromOffset(tl.X,tl.Y)
        safe.Size=UDim2.new(1,-tl.X-br.X,1,-tl.Y-br.Y)
        scale.Scale=math.min(1.2,viewport.Y/720,(viewport.X-tl.X-br.X-40)/760,(viewport.Y-tl.Y-br.Y-40)/526)
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
            card.entry=entry
            card.name.Text=entry.name
            card.description.Text=entry.description
            local count=vote.counts[id] or 0
            card.info.Text=entry.sector.." · "..tostring(count)..(if count==1 then " voto" else " votos")
            card.button.Text=if vote.selected==id then "✓ Tu voto" else "Votar"
            local rgb=entry.accent
            card.accent.BackgroundColor3=Color3.fromRGB(rgb[1],rgb[2],rgb[3])
            card.stroke.Color=card.accent.BackgroundColor3
            card.stroke.Transparency=if vote.selected==id then .2 else .85
            local c=entry.previewCamera
            card.camera.CFrame=CFrame.lookAt(Vector3.new(c[1],c[2],c[3]),Vector3.new(c[4],c[5],c[6]))
            if card.requestedId~=id then
                card.world:ClearAllChildren()
                card.requestedId=id
                card.mapId=nil
                card.loading.Visible=true
            end
            tryPreview(card)
        end
    end
    function view.updateTime(state,now)
        timer.Text="Cierra en "..math.max(0,math.ceil(state.deadline-now)).." s · El servidor decide los empates"
        -- Voting may have no further state events. Retry late assets locally at most four times/second.
        if gui.Enabled and os.clock()>=retryAt then
            retryAt=os.clock()+.25
            for _,card in cards do tryPreview(card) end
        end
    end
    return view
end
return MapSelection
