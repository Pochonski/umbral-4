--!strict
-- Pure rules: the server owns membership, time, rate limiting and randomness.
local MapVote = {}
export type Ballot = {id: number, options: {string}, votes: {[number]: string}}
function MapVote.new(id: number, catalog: {string}, current: string): Ballot
    local options = {}
    for _, mapId in catalog do if mapId ~= current then table.insert(options, mapId) end end
    assert(#options >= 1, "At least two maps are required")
    return {id = id, options = options, votes = {}}
end
function MapVote.cast(ballot: Ballot, userId: number, ballotId: any, mapId: any): boolean
    if ballotId ~= ballot.id or type(mapId) ~= "string" or not table.find(ballot.options, mapId) then return false end
    if ballot.votes[userId] == mapId then return false end
    ballot.votes[userId] = mapId
    return true
end
function MapVote.remove(ballot: Ballot, userId: number)
    ballot.votes[userId] = nil
end
function MapVote.counts(ballot: Ballot): {[string]: number}
    local counts = {}
    for _, mapId in ballot.options do counts[mapId] = 0 end
    for _, mapId in ballot.votes do counts[mapId] += 1 end
    return counts
end
function MapVote.winner(ballot: Ballot, pick: (number, number) -> number): string
    local counts = MapVote.counts(ballot)
    local best, tied = -1, {}
    for _, mapId in ballot.options do
        if counts[mapId] > best then best, tied = counts[mapId], {mapId}
        elseif counts[mapId] == best then table.insert(tied, mapId) end
    end
    return tied[pick(1, #tied)]
end
return table.freeze(MapVote)
