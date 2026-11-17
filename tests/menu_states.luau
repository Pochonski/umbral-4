-- Supplemental presentation checks with synthetic server states, not a network playtest.
local holder = Instance.new("Folder")
local Interface = require(game.Players.LocalPlayer.PlayerScripts.UmbralClient.Interface)
local view = Interface.create(holder)
local terminal = holder.UmbralTerminal
local panel = terminal.ZonaSegura.Terminal
local state = {phase="waiting",status="lobby",participating=false,ready=false,readyCount=1,
    winners={},scores={},goal=10,deadline=110,respawnAt=0,protectedUntil=0,killerName=""}
local checks = {}
local ok, message = pcall(function()
    view.state(state, 1, false)
    assert(not view.play.Active and view.play.Text == "Requiere teclado y ratón")
    table.insert(checks,"unsupported device disables Play with explanation")
    view.state(state, 1, true)
    state.phase = "countdown"
    view.state(state,1,true); view.updateTime(state,100)
    assert(terminal.Enabled and panel.Estado.Cola.Text=="La ronda empieza en 10 s")
    table.insert(checks,"countdown presents server deadline")
    state.phase, state.ready = "playing",true
    view.state(state,1,true); view.updateTime(state,100)
    assert(terminal.Enabled and panel.Estado.Cola.Text=="En cola · Entrarás en la siguiente ronda")
    assert(not view.gui.HUD.Visible)
    table.insert(checks,"late participant remains in the terminal queued for next round")
    state.participating,state.status = true,"alive"
    view.state(state,1,true)
    assert(not terminal.Enabled and view.gui.HUD.Visible)
    state.status,state.respawnAt="dead",106
    view.state(state,1,true); view.updateTime(state,100)
    assert(not terminal.Enabled and not view.gui.HUD.Visible and view.gui["Reaparición"].Visible)
    state.phase="results"
    view.state(state,1,true)
    assert(not terminal.Enabled and view.gui.Resultados.Visible)
    table.insert(checks,"combat, death and results never display the terminal")
    state.phase,state.participating,state.ready="waiting",false,false
    view.options(1,.65,true)
    view.state(state,1,true)
    assert(terminal.Enabled and panel.Position==UDim2.fromScale(.5,.5))
    table.insert(checks,"return with reduced motion has no entrance displacement")
end)
holder:Destroy()
assert(ok,message)
return {syntheticStates=true,checks=checks}
