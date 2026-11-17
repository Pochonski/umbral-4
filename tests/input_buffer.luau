local InputBuffer = require("../src/client/InputBuffer")

local function test(name, check)
    check()
    print("PASS " .. name)
end

test("the fourth digit sends once and clears the editable buffer", function()
    local input = InputBuffer.new(2)
    for index, digit in {"0", "9", "1", "7"} do
        local display, submitted = InputBuffer.push(input, digit, index)
        if index < 4 then assert(submitted == nil and #display == index)
        else assert(display == "0917" and submitted == "0917") end
    end
    assert(InputBuffer.erase(input, 4.05) == "", "Backspace must not reopen a submitted prefix")
    local nextDisplay, nextCode = InputBuffer.push(input, "3", 4.06)
    assert(nextDisplay == "3" and nextCode == nil)
end)

test("backspace corrects a pending digit and preserves leading zeroes", function()
    local input = InputBuffer.new(2)
    InputBuffer.push(input, "0", 0)
    InputBuffer.push(input, "3", .1)
    assert(InputBuffer.erase(input, .2) == "0")
    InputBuffer.push(input, "9", .3)
    InputBuffer.push(input, "1", .4)
    local _, result = InputBuffer.push(input, "7", .5)
    assert(result == "0917")
end)

test("a new key cannot complete an expired entry between HUD updates", function()
    local input = InputBuffer.new(2)
    InputBuffer.push(input, "1", .2)
    InputBuffer.push(input, "2", .3)
    InputBuffer.push(input, "3", .4)
    local display, submitted = InputBuffer.push(input, "4", 2.41)
    assert(display == "4" and submitted == nil)
    assert(not InputBuffer.expire(input, 4.40))
    assert(InputBuffer.expire(input, 4.42))
    assert(InputBuffer.push(input, "0", 4.45) == "0")
end)

test("clearing on focus change drops the partial attack", function()
    local input = InputBuffer.new(2)
    InputBuffer.push(input, "1", 0)
    InputBuffer.push(input, "2", .1)
    InputBuffer.clear(input)
    assert(InputBuffer.push(input, "3", .2) == "3")
end)
