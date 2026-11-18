--!strict
-- IDs are stable network values. Cameras describe presentation, never combat poses.
local Maps = {
    {id = "relevo", model = "EstacionDeRelevo", name = "Estación de Relevo", sector = "TRANSFERENCIA / 01",
        description = "Celda 04 · potencia y refrigeración", camera = {37, 13, 39, -6, 5, -11},
        previewCamera = {2,6.5,11,0,2.4,0}, accent = {255,193,83}},
    {id = "puerto", model = "PuertoDeCarga", name = "Puerto de Carga", sector = "LOGÍSTICA / 02",
        description = "Torre T0 · contenedores y muelle", camera = {49, 18, 47, -5, 4, -8},
        previewCamera = {37,17,34,-4,6,-7}, accent = {255,193,83}},
    {id = "invernadero", model = "InvernaderoDeProtocolo", name = "Invernadero de Protocolo", sector = "BIOSISTEMAS / 03",
        description = "Cultivo N0 · galerías de protocolo", camera = {43, 15, 43, -5, 4, -9},
        previewCamera = {31,15,-34,0,6,0}, accent = {104,219,218}},
}
for _, entry in Maps do
    table.freeze(entry.camera); table.freeze(entry.previewCamera); table.freeze(entry.accent); table.freeze(entry)
end
return table.freeze(Maps)
