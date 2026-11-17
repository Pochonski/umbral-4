--!strict
local Config = {
    ArenaModel = "EstacionDeRelevo",
    MinPlayers = 2,
    MaxPlayers = 8,
    Countdown = 10,
    RoundDuration = 240,
    ResultsDuration = 10,
    RespawnDelay = 6,
    ProtectionTime = 2.5,
    InputTimeout = 2,
    Range = 45,
    AttackerFacing = math.cos(math.rad(65)),
    TargetFacing = math.cos(math.rad(70)),
    SampleInterval = 0.1,
    RevealSamples = 2,
    RevealLifetime = 0.35,
    RequestRate = 2,
    RequestBurst = 2,
    PlateWidth = 2.25,
    PlateHeight = 0.75,
    PlateVerticalOffset = 0.78,
    PlateForwardOffset = 0.76,
}

return table.freeze(Config)
