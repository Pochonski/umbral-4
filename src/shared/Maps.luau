--!strict
-- IDs are stable network values. Cameras describe presentation, never combat poses.
local Maps = {
    {id = "relevo", model = "EstacionDeRelevo", name = "Estación de Relevo", sector = "TRANSFERENCIA / 01",
        description = "Patio industrial · pasarelas y galerías", camera = {37, 13, 39, -6, 5, -11}},
    {id = "puerto", model = "PuertoDeCarga", name = "Puerto de Carga", sector = "LOGÍSTICA / 02",
        description = "Muelle de transferencia · acero y ámbar", camera = {49, 18, 47, -5, 4, -8}},
    {id = "invernadero", model = "InvernaderoDeProtocolo", name = "Invernadero de Protocolo", sector = "BIOSISTEMAS / 03",
        description = "Núcleo de cultivo · galerías técnicas", camera = {43, 15, 43, -5, 4, -9}},
}
for _, entry in Maps do table.freeze(entry.camera); table.freeze(entry) end
return table.freeze(Maps)
