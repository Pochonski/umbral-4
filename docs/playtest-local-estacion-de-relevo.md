# Playtest privado de Estación de Relevo

## Abrir la partida

1. Extrae el paquete y abre `Umbral4-Estacion-de-Relevo-Pulido-Final.rbxlx` en Roblox Studio. Es la compilación normal, con la duración y las reglas habituales.
2. En los controles de prueba de Studio, selecciona **Server & Clients**, elige **2** clientes y pulsa **F7**. Abre las dos ventanas de jugador y pulsa **Jugar** en ambas. Para cerrar, usa **End Session**. [Modos de prueba de Studio](https://create.roblox.com/docs/studio/testing-modes)
3. En un solo escritorio, Windows da el teclado y el ratón a una ventana a la vez. Una persona puede controlar el atacante mientras la otra observa y coloca al rival desde el otro cliente cuando le toque. Intercambien roles. El duelo con dos personas controlando a la vez requiere un entorno multijugador compartido ya disponible.

## Sesión de 15 minutos

| Caso | Qué hacer | Qué cuenta como aprobado |
| --- | --- | --- |
| Lectura al correr | Hacer cinco intentos mientras se cruza el patio o se sube a la pasarela. El segundo jugador sitúa al rival frontal, a media distancia, y anota el código. | Pueden leer los cuatro dígitos mientras se desplazan hacia el rival. Los rótulos del mapa se distinguen de la placa. Anotar cualquier confusión y la distancia aproximada. |
| Cámara y escritura | Mantener W o un desplazamiento lateral, girar con el ratón y teclear un código válido. En otro intento, corregir un dígito con Retroceso. | La cámara y el movimiento se mantienen mientras se teclea. La corrección deja visibles los dígitos correctos. |
| Esquinas y galerías | Repetir en Celda 04, la puerta de Potencia, Refrigeración y la galería oeste. Ver la placa en abierto, colocarse en cobertura y probar el código recordado. Volver a salir y repetir. | Una placa estable y frontal permite acertar. Detrás de cobertura la placa desaparece y el servidor rechaza el código. Registrar aparte los intentos hechos justo durante el giro o el cruce. |
| Sombra y sol | Hacer la misma lectura en la unión de la galería y el patio, con el rival en ambos lados de la transición. | Los cuatro dígitos siguen legibles. Si falla, guardar una captura y anotar el sector y la calidad gráfica. |
| Reaparición | Hacer una baja y verificar la cuenta de reaparición, el nuevo código y la protección. Repetir la salida de `Spawn 03` hacia dos lados. | El avatar se mueve al primer intento con W y con un desplazamiento lateral. Registrar si roza la baliza, si la cámara tropieza o si hace falta saltar para salir. |

Para repetir la última prueba en el punto exacto, espera a que el jugador reaparezca. En la ventana de **servidor de prueba**, abre la barra de comandos y pega este bloque. Cambia `Player1` por `Player2` si le toca al otro cliente. La prueba conserva el marcador y la baliza.

```lua
local avatar = game.Players.Player1.Character
local marker = workspace.UmbralWorld.EstacionDeRelevo.Spawns["Spawn 03"]
avatar:PivotTo(marker.CFrame)
avatar.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
```

Registra el caso, el sector, la calidad gráfica, el resultado y un enlace o archivo de captura. Para un rechazo con placa visible, anota si la placa llevaba tiempo estable o acababa de cruzar una esquina. La revisión puede avanzar cuando los dos participantes hayan rotado de rol y cada rechazo observado tenga una explicación reproducible.
