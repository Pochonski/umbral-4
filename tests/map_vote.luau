local Vote = require("../src/shared/MapVote")
local all = {"relevo", "puerto", "invernadero"}
local total=0
local function test(name,fn) fn(); total+=1; print("PASS "..name) end
test("current map cannot be offered or selected",function()
    local b=Vote.new(1,all,"relevo")
    assert(#b.options==2 and not table.find(b.options,"relevo"))
    assert(not Vote.cast(b,1,1,"relevo"))
end)
test("ballot generation and malformed options are rejected",function()
    local b=Vote.new(2,all,"puerto")
    for _,v in {"2",1,0,{},false} do assert(not Vote.cast(b,1,v,"relevo")) end
    for _,v in {"missing",{},12,false} do assert(not Vote.cast(b,1,2,v)) end
end)
test("one vote can change without accumulating votes",function()
    local b=Vote.new(1,all,"relevo")
    assert(Vote.cast(b,1,1,"puerto")); assert(not Vote.cast(b,1,1,"puerto"))
    assert(Vote.cast(b,1,1,"invernadero"))
    local c=Vote.counts(b); assert(c.puerto==0 and c.invernadero==1)
end)
test("departures and unready remove votes",function()
    local b=Vote.new(1,all,"relevo")
    Vote.cast(b,1,1,"puerto"); Vote.cast(b,2,1,"puerto"); Vote.remove(b,1)
    assert(Vote.counts(b).puerto==1)
    Vote.remove(b,2); assert(Vote.counts(b).puerto==0)
end)
test("a strict majority wins independently of the random selector",function()
    local b=Vote.new(1,all,"relevo")
    Vote.cast(b,1,1,"puerto"); Vote.cast(b,2,1,"puerto"); Vote.cast(b,3,1,"invernadero")
    assert(Vote.winner(b,function(lo,hi) assert(lo==1 and hi==1); return hi end)=="puerto")
end)
test("a tie and abstention select only permitted alternatives",function()
    for _,voted in {false,true} do
        local b=Vote.new(1,all,"relevo")
        if voted then Vote.cast(b,1,1,"puerto"); Vote.cast(b,2,1,"invernadero") end
        assert(Vote.winner(b,function(_,hi) return hi end)=="invernadero")
        assert(Vote.winner(b,function(lo) return lo end)=="puerto")
    end
end)
print("PASS "..total.." map vote tests")
