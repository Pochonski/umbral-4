-- MCP Client, idle single-client QA copy. Synthetic ballot for layout only.
-- Network voting is exercised separately by StudioServer and single_client_cycle.
local P=game.Players.LocalPlayer
local d=game:GetService("StudioDeviceSimulatorService")
local view=require(P.PlayerScripts.UmbralClient.MapSelection).create(P.PlayerGui,function() return true end)
local gui=view.cards[1].frame:FindFirstAncestorOfClass("ScreenGui")
gui.Name="UmbralQAVoteLayout"
local hidden={}
for _,g in P.PlayerGui:GetChildren() do
    if g:IsA("ScreenGui") and g~=gui then hidden[g]=g.Enabled;g.Enabled=false end
end
local clicks={0,0,0}
for i,c in view.cards do c.button.Activated:Connect(function() clicks[i]+=1 end) end
view.leave.Activated:Connect(function() clicks[3]+=1 end)
local state={phase="voting",ready=true,deadline=workspace:GetServerTimeNow()+10,
    vote={id=1,options={"puerto","invernadero"},counts={puerto=2,invernadero=1},selected="puerto"}}
view.state(state);view.updateTime(state,workspace:GetServerTimeNow())
local input=assert(game:GetService("UserInputService"):CreateVirtualInput())
local function click(button)
    local pos=button.AbsolutePosition+button.AbsoluteSize/2+game:GetService("GuiService"):GetGuiInset()
    input:SendMousePosition(pos);input:SendMouseButton(pos,Enum.UserInputType.MouseButton1,true,0)
    task.wait(.05);input:SendMouseButton(pos,Enum.UserInputType.MouseButton1,false,0);task.wait(.1)
end
_G.UmbralVoteLayoutResize=function(w,h)
    d:SetDeviceAsync("hd_720");d:SetResolutionAsync(w,h)
    d:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
    task.wait(.5);view.resize(workspace.CurrentCamera.ViewportSize);task.wait(.5)
    assert(workspace.CurrentCamera.ViewportSize==Vector2.new(w,h))
    local checked=0
    for _,item in gui:GetDescendants() do
        if item:IsA("GuiObject") and item.Visible then
            local p,s=item.AbsolutePosition+game:GetService("GuiService"):GetGuiInset(),item.AbsoluteSize
            assert(p.X>=-1 and p.Y>=-1 and p.X+s.X<=w+1 and p.Y+s.Y<=h+1,item:GetFullName().." outside viewport")
            if item:IsA("TextLabel") or item:IsA("TextButton") then
                assert(item.TextBounds.X<=s.X+1 and item.TextBounds.Y<=s.Y+1,item.Text.." clipped")
                checked+=1
            end
        end
    end
    local before=table.clone(clicks)
    click(view.cards[1].button);click(view.cards[2].button);click(view.leave)
    for i=1,3 do assert(clicks[i]==before[i]+1,"Button did not activate") end
    return {width=w,height=h,labelsChecked=checked,buttons=3,human=false,syntheticBallot=true}
end
_G.UmbralVoteLayoutCleanup=function()
    gui:Destroy();for g,value in hidden do g.Enabled=value end
    _G.UmbralVoteLayoutResize=nil;_G.UmbralVoteLayoutCleanup=nil
end
return "Synthetic layout ready; call _G.UmbralVoteLayoutResize(width,height), capture, then cleanup"
