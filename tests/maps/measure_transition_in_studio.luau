-- MCP Server, idle QA copy with production Config. No combat participants.
local Arena=require(game.ServerScriptService.UmbralServer.Arena)
local active=workspace.UmbralWorld.ActiveArena
local rows={}
local original=Arena.id
for sample=1,3 do
    for _,id in {"puerto","invernadero","relevo"} do
        local started=os.clock()
        local ok,actual=Arena.activate(id)
        local elapsed=(os.clock()-started)*1000
        assert(ok and actual==id and #active:GetChildren()==1)
        table.insert(rows,{mapId=id,sample=sample,serverActivationMs=elapsed})
        task.wait(.35)
    end
end
assert(Arena.activate(original))
return {human=false,mode="idle server mounting; no network RTT or combat load included",cases=rows}
