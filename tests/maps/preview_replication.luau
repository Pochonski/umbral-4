-- MCP Client with the comparison fixture installed before Play.
local R=game.ReplicatedStorage
local P=game.Players.LocalPlayer
local state={phase="voting",ready=true,deadline=workspace:GetServerTimeNow()+10,
    vote={id=1,options={"puerto","invernadero"},counts={}}}
local function probe(module,folderName)
    local folder=R[folderName]
    local view=require(module).create(P.PlayerGui,function() return true end)
    local gui=view.cards[1].frame:FindFirstAncestorOfClass("ScreenGui")
    local saved=folder.PuertoDeCarga
    local partial
    local report={}
    local ok,err=pcall(function()
        folder.Parent=nil
        view.state(state)
        report.absent=#view.cards[1].world:GetChildren()
        folder.Parent=R
        view.state(state)
        report.afterFolderArrives=#view.cards[1].world:GetChildren()
        -- Change the requested option to clear the first card's previous clone.
        state.vote.options={"invernadero","puerto"};view.state(state)
        saved.Parent=nil
        partial=Instance.new("Model");partial.Name="PuertoDeCarga";partial.Parent=folder
        local counter=saved:FindFirstChild("PreviewPartCount")
        if counter then counter:Clone().Parent=partial end
        state.vote.options={"puerto","invernadero"};view.state(state)
        report.partialCached=view.cards[1].mapId~=nil
        for _,child in saved:GetChildren() do
            if child:IsA("BasePart") then child:Clone().Parent=partial end
        end
        -- No new state event: the production timer must retry the late model.
        task.wait(.3);view.updateTime(state,workspace:GetServerTimeNow())
        local model=view.cards[1].world:FindFirstChildWhichIsA("Model")
        local actual=0
        if model then for _,p in model:GetChildren() do if p:IsA("BasePart") then actual+=1 end end end
        report.eventuallyClonedParts=actual
        local before=model
        for _=1,10 do view.state(state) end
        report.stableClone=before==view.cards[1].world:FindFirstChildWhichIsA("Model")
    end)
    folder.Parent=R
    if partial then partial:Destroy() end
    saved.Parent=folder;gui:Destroy();state.vote.options={"puerto","invernadero"}
    assert(ok,err)
    return report
end
local old=probe(P.PlayerScripts.UmbralClient.UmbralQABaselineVote,"UmbralQABaselinePreviews")
local current=probe(P.PlayerScripts.UmbralClient.MapSelection,"UmbralMapPreviews")
assert(old.afterFolderArrives==0 and old.partialCached and old.eventuallyClonedParts==0,"Baseline did not reproduce")
assert(current.absent==0 and current.afterFolderArrives==1 and not current.partialCached)
assert(current.eventuallyClonedParts>0 and current.stableClone)
return {human=false,ok=true,baseline=old,candidate=current,checks={"late folder retries","partial model isn't cached","timer recovers without another state event","unchanged vote doesn't clone again"}}
