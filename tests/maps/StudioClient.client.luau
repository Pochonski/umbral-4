-- Instrumented Studio copy only. VirtualInput is automation, never a human playtest.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Gui=game:GetService("GuiService")
if not game:GetService("RunService"):IsStudio() then return end
local p=Players.LocalPlayer
local n=ReplicatedStorage:WaitForChild("UmbralNetwork")
local b=ReplicatedStorage:WaitForChild("UmbralQA"):WaitForChild("MapBridge")
local state
n.Update.OnClientEvent:Connect(function(kind,...)
    if kind=="state" then state=...; b:FireServer("state",state)
    elseif kind=="plates" then
        local round,life,updates,reset=...
        b:FireServer("plates",updates,reset)
    elseif kind=="feedback" then b:FireServer("feedback",...) end
end)
local virtual=assert(Input:CreateVirtualInput())
local function click(button)
    local pos=button.AbsolutePosition+button.AbsoluteSize/2+Gui:GetGuiInset()
    virtual:SendMousePosition(pos)
    virtual:SendMouseButton(pos,Enum.UserInputType.MouseButton1,true,0)
    task.wait(.04)
    virtual:SendMouseButton(pos,Enum.UserInputType.MouseButton1,false,0)
end
b.OnClientEvent:Connect(function(action,value)
    local ok,err=pcall(function()
        if action=="ready" then n.Request:FireServer("ready",true)
        elseif action=="readyValue" then n.Request:FireServer("ready",value)
        elseif action=="staleAttack" then n.SubmitCode:FireServer(value.round,value.life,value.code)
        elseif action=="readyButton" then click(p.PlayerGui.UmbralTerminal.ZonaSegura.Terminal.Jugar)
        elseif action=="vote" then
            n.Request:FireServer("vote",state.vote.id,value)
        elseif action=="attack" then n.SubmitCode:FireServer(state.roundId,state.lifeId,value)
        elseif action=="invalidVote" then
            n.Request:FireServer("vote",state.vote.id-1,value)
            n.Request:FireServer("vote",state.vote.id,"not-a-map")
        end
    end)
    if not ok then b:FireServer("error",tostring(err)) end
end)
p.PlayerGui:WaitForChild("UmbralMapVote",15)
n.Request:FireServer("sync")
b:FireServer("initialized")
