-- MCP Client in the SingleServer QA copy only. Not a two-person or two-client test.
local R=game:GetService("ReplicatedStorage")
local H=game:GetService("HttpService")
local P=game.Players.LocalPlayer
local network=R.UmbralNetwork
local inspector=R.UmbralQA.Inspect
local state
local connection=network.Update.OnClientEvent:Connect(function(kind,value) if kind=="state" then state=value end end)
local virtual=assert(game:GetService("UserInputService"):CreateVirtualInput())
local function waitFor(name,fn,seconds)
    local untilTime=os.clock()+(seconds or 30)
    repeat local result=fn(); if result then return result end; task.wait(.05) until os.clock()>untilTime
    error("Timed out: "..name)
end
local function click(button)
    local pos=button.AbsolutePosition+button.AbsoluteSize/2+game:GetService("GuiService"):GetGuiInset()
    virtual:SendMousePosition(pos)
    virtual:SendMouseButton(pos,Enum.UserInputType.MouseButton1,true,0); task.wait(.04)
    virtual:SendMouseButton(pos,Enum.UserInputType.MouseButton1,false,0)
end
workspace:SetAttribute("MapsSingleDone",false)
task.spawn(function()
    local result={human=false,clients=1,qaMinPlayers=1,maps={},votes={}}
    local ok,err=pcall(function()
        local d=game:GetService("StudioDeviceSimulatorService")
        d:SetDeviceAsync("hd_720"); d:SetResolutionAsync(1280,720); d:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
        network.Request:FireServer("sync"); waitFor("sync",function() return state end)
        click(P.PlayerGui.UmbralTerminal.ZonaSegura.Terminal.Jugar)
        for index,id in {"relevo","puerto","invernadero","relevo"} do
            workspace:SetAttribute("MapsSingleStage","waiting "..id)
            waitFor("round "..index,function() return state.phase=="playing" and state.roundId==index and state.status=="alive" end,40)
            assert(state.mapId==id,state.mapId)
            waitFor("first-person camera",function() return P.CameraMode==Enum.CameraMode.LockFirstPerson end,4)
            local report=inspector:InvokeServer("inspect")
            assert(report.activeModels==1 and report.spawns==12 and #report.unsupported==0)
            if id~="relevo" then assert(#report.obstructed==0,H:JSONEncode(report.obstructed)) end
            table.insert(result.maps,report)
            if index==4 then break end
            waitFor("voting",function() return state.phase=="voting" end,35)
            workspace:SetAttribute("MapsSingleStage","voting "..index)
            waitFor("vote panel",function() return P.PlayerGui.UmbralMapVote.Enabled end,3)
            assert(#state.vote.options==2 and not table.find(state.vote.options,id))
            local nextId=if index==1 then "puerto" elseif index==2 then "invernadero" else "puerto"
            if index==3 then assert(inspector:InvokeServer("breakPuerto")) end
            local option=assert(table.find(state.vote.options,nextId))
            click(P.PlayerGui.UmbralMapVote.ZonaSegura.Votacion["Opcion"..option].Votar)
            waitFor("vote selected",function() return state.vote and state.vote.selected==nextId end,3)
            assert(state.vote.counts[nextId]==1)
            table.insert(result.votes,{id=state.vote.id,selected=nextId,count=state.vote.counts[nextId]})
        end
        result.fallback="missing Puerto bounds recovered to Relevo in round four"
    end)
    connection:Disconnect()
    result.ok=ok; result.error=if ok then nil else tostring(err)
    workspace:SetAttribute("MapsSingleResult",H:JSONEncode(result))
    workspace:SetAttribute("MapsSingleDone",true)
    print("[MAP SINGLE]",H:JSONEncode(result))
end)
return "Single-client diagnostic started; poll MapsSingleDone/Result"
