--!strict
local Rules = {}

export type Score = {
    userId: number,
    name: string,
    kills: number,
    deaths: number,
    left: boolean,
}

export type Bucket = { tokens: number, updated: number }
export type CodePool = { used: {[string]: boolean}, nextFree: number }

function Rules.validCode(value: unknown): boolean
    return type(value) == "string" and #value == 4 and value:match("^[0-9]+$") ~= nil
end

function Rules.newCodePool(): CodePool
    return { used = {}, nextFree = 0 }
end

function Rules.drawCode(pool: CodePool, pick: (number, number) -> number): string?
    for _ = 1, 12 do
        local code = string.format("%04d", pick(0, 9999))
        if not pool.used[code] then
            pool.used[code] = true
            return code
        end
    end
    while pool.nextFree < 10000 do
        local code = string.format("%04d", pool.nextFree)
        pool.nextFree += 1
        if not pool.used[code] then
            pool.used[code] = true
            return code
        end
    end
    return nil
end

function Rules.consume(bucket: Bucket, now: number, rate: number, capacity: number): boolean
    bucket.tokens = math.min(capacity, bucket.tokens + math.max(0, now - bucket.updated) * rate)
    bucket.updated = now
    if bucket.tokens < 1 then
        return false
    end
    bucket.tokens -= 1
    return true
end

function Rules.goal(playerCount: number): number
    if playerCount <= 3 then
        return 10
    elseif playerCount <= 5 then
        return 15
    end
    return 25
end

function Rules.ranking(scores: {[number]: Score}): ({Score}, {number})
    local ranking: {Score} = {}
    for _, score in scores do
        table.insert(ranking, score)
    end
    table.sort(ranking, function(a: Score, b: Score)
        if a.left ~= b.left then return not a.left end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.userId < b.userId
    end)
    local winners: {number} = {}
    local leader = ranking[1]
    if leader and not leader.left then
        for _, score in ranking do
            if score.left or score.kills ~= leader.kills then break end
            table.insert(winners, score.userId)
        end
    end
    return ranking, winners
end

return Rules
