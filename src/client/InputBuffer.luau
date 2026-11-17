--!strict
local InputBuffer = {}
export type Buffer = { value: string, lastInput: number, timeout: number }

function InputBuffer.new(timeout: number): Buffer
    return { value = "", lastInput = 0, timeout = timeout }
end

function InputBuffer.clear(self: Buffer)
    self.value = ""
end

function InputBuffer.expire(self: Buffer, now: number): boolean
    if self.value == "" or now - self.lastInput < self.timeout then return false end
    InputBuffer.clear(self)
    return true
end

function InputBuffer.push(self: Buffer, digit: string, now: number): (string, string?)
    InputBuffer.expire(self, now)
    local value = self.value .. digit
    self.lastInput = now
    if #value == 4 then
        InputBuffer.clear(self)
        return value, value
    end
    self.value = value
    return value, nil
end

function InputBuffer.erase(self: Buffer, now: number): string
    InputBuffer.expire(self, now)
    self.value = self.value:sub(1, -2)
    self.lastInput = now
    return self.value
end

return InputBuffer
