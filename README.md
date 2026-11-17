# Umbral 4

Prototipo multijugador de Roblox para PC. En Estación de Relevo, gana quien lea y escriba los códigos rivales antes de quedar expuesto.

## Abrir y jugar

1. Abre `Umbral4.rbxlx` en Roblox Studio.
2. En el selector de pruebas, elige **Servidor y clientes** y selecciona **2 clientes**. Inicia la prueba.
3. Pulsa **Jugar** en ambas ventanas cliente. La ronda empieza después de 10 segundos.
4. Usa WASD, ratón y Espacio. Cuando veas una placa, escribe sus cuatro dígitos con la fila superior o el teclado numérico. El cuarto dígito envía el ataque. Retroceso corrige una casilla y Esc limpia el intento al abrir el menú de Roblox. **M** abre Ajustes.

**Cómo jugar** tiene una práctica individual con el código 0917. Una ronda requiere dos jugadores en cola.

## Compilar desde el código fuente

Descomprime el paquete. Desde esa carpeta, con Rojo 7.7.1 disponible:

```powershell
rojo build default.project.json -o Umbral4.rbxlx
```

`default.project.json` incluye el mapa y genera un lugar autónomo. Para trabajar en código sobre una copia del lugar que ya contiene la arena, ejecuta `rojo serve sync.project.json` y conéctate con el plugin oficial de Rojo. Este manifiesto administra únicamente `UmbralShared`, `UmbralServer` y `UmbralClient` en sus servicios correspondientes. Aplica primero la sincronización sobre una copia desechable y revisa el diff del plugin.

- `src/server` controla rondas, aparición, puntuación, visibilidad y ataques.
- `src/shared` define configuración, geometría y reglas puras.
- `src/client` captura pulsaciones y dibuja HUD, menús, efectos y placas temporales.
- `map/EstacionDeRelevo.rbxmx` contiene la arena editable y el vestíbulo. Exporta el modelo `Workspace.UmbralWorld` desde Studio para versionar cambios a la geometría. Los puntos de aparición están en `EstacionDeRelevo.Spawns`.

## Reproducir la verificación

Con Luau CLI 0.747:

```powershell
luau tests/rules.luau
```

La integración de Studio usa remotos de diagnóstico incluidos solo en un lugar de prueba, con tiempos de ronda y reaparición reducidos:

```powershell
python tests/build_studio_qa.py C:\ruta\a\rojo.exe Umbral4-QA.rbxlx
```

Abre el archivo QA, inicia un servidor con dos clientes y busca `[UMBRAL QA COMPLETE] PASS` en la salida del servidor. El juego de entrega se compila desde el manifiesto principal.

## Decisiones registradas

- La versión de referencia es un lugar separado. El original contenía Baseplate, Terrain, Camera y SpawnLocation, sin scripts propios. El mapa nuevo se generó como modelo editable.
- El servidor envía cada código solo a observadores elegibles. Una concesión previa caduca y cada intento vuelve a validar su geometría antes de acreditar la baja. El cliente que ha recibido un código puede conservarlo en memoria, por lo que la elegibilidad del servidor sigue siendo necesaria.
- Las rondas usan 10, 15 o 25 bajas según la cantidad inicial, con límite de 4 min. Los ajustes se guardan durante la sesión y las estadísticas corresponden a la ronda. La persistencia y otros modos quedaron fuera del prototipo.
- Los efectos de confirmación usan un sonido incluido en Roblox, sin modelos, scripts ni licencias de pago.
- Antes de publicar, faltan sesiones con personas reales, mediciones de red y rendimiento con 4 y 8 jugadores y una versión privada evaluada por el propietario.
