local Rules = require("../src/shared/Rules")
local total = 0

local function test(name, check)
    check()
    total += 1
    print("PASS " .. name)
end

test("codes preserve leading zeroes and reject malformed remote values", function()
    for _, value in {"0000", "0917", "9999"} do assert(Rules.validCode(value)) end
    for _, value in {917, "917", "09170", "-917", "0 17", "091\n", "０９１７", {"0917"}, false} do
        assert(not Rules.validCode(value), tostring(value))
    end
    assert(not Rules.validCode(nil))
end)

test("a collision never reuses a code in the same round", function()
    local pool = Rules.newCodePool()
    local pick = function() return 917 end
    assert(Rules.drawCode(pool, pick) == "0917")
    assert(Rules.drawCode(pool, pick) == "0000")
    assert(Rules.drawCode(pool, pick) == "0001")
    assert(Rules.drawCode(Rules.newCodePool(), pick) == "0917")
end)

test("a depleted code pool fails without giving out a duplicate", function()
    local pool = Rules.newCodePool()
    local already = {}
    for _ = 1, 10000 do
        local value = assert(Rules.drawCode(pool, function() return 0 end))
        assert(not already[value], value)
        already[value] = true
    end
    assert(Rules.drawCode(pool, function() return 0 end) == nil)
end)

test("burst has two attempts and refills at two per second", function()
    local bucket = {tokens = 2, updated = 0}
    assert(Rules.consume(bucket, 0, 2, 2))
    assert(Rules.consume(bucket, 0, 2, 2))
    assert(not Rules.consume(bucket, 0, 2, 2))
    assert(not Rules.consume(bucket, .25, 2, 2))
    assert(Rules.consume(bucket, .5, 2, 2))
    assert(not Rules.consume(bucket, .5, 2, 2))
end)

test("round goals cover the intended population bands", function()
    for index, value in {10, 10, 15, 15, 25, 25, 25} do assert(Rules.goal(index + 1) == value) end
end)

test("a score tie shares first place and ignores departures", function()
    local scores = {
        [3] = {userId=3, name="C", kills=25, deaths=0, left=true},
        [5] = {userId=5, name="E", kills=7, deaths=0, left=false},
        [2] = {userId=2, name="B", kills=7, deaths=4, left=false},
        [1] = {userId=1, name="A", kills=4, deaths=1, left=false},
    }
    local ranking, winners = Rules.ranking(scores)
    assert(#winners == 2 and winners[1] == 2 and winners[2] == 5)
    assert(ranking[4].userId == 3)
end)

test("a round without eligible participants has no winner", function()
    local _, winners = Rules.ranking({[1]={userId=1, name="A", kills=5, deaths=0, left=true}})
    assert(#winners == 0)
    _, winners = Rules.ranking({})
    assert(#winners == 0)
end)

print(("PASS %d rule tests"):format(total))
