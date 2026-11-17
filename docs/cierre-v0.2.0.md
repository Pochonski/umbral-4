# Umbral 4 · Cierre técnico de v0.2.0 para ChatGPT

**17 de noviembre de 2026 · Mantener en revisión.** La corrección de inscripción está comprobada y pasaron los casos de combate local y bajo latencia que se detallan abajo. Quedan la prueba con ocho clientes, el rendimiento con clientes en equipos separados y la validación con personas. El [PR #1](https://github.com/Pochonski/umbral-4/pull/1) sigue abierto en borrador.

## Defecto reproducido y corrección

En la candidata anterior, `sync` y `ready` compartían una ventana de 0,24 segundos. En Studio se enviaron ambos, en ese orden, por el mismo remoto. El resultado fue `readyAfterAdjacent=false`. Un reintento posterior solo con `ready` dio `true`. La primera corrida con cuatro clientes tampoco logró inscribirlos a todos. Ese síntoma motivó la investigación, aunque el log de esa corrida no identifica qué solicitud perdió cada cliente.

Se aplicaron límites separados a sincronización e inscripción. Ambos siguen limitados. La prueba de regresión manda deliberadamente `sync` e inmediatamente `ready` en cada cliente. Con la corrección se inscribieron cuatro clientes en la misma ronda. Fue el único cambio de comportamiento del juego en este cierre.

## Rendimiento

**Entorno.** Roblox Studio 0.747 en Windows, Ryzen 5 5600G, GeForce RTX 5060 y 15,87 GiB de RAM. La sesión aislada usó Prueba (F5) con los modelos de datos de cliente y servidor dentro de un solo proceso. El encuadre del vestíbulo fue fijo a 1685 × 1113. La prueba multicliente ejecutó el servidor y sus clientes en procesos de Studio en el mismo equipo.

| Condición | Muestra | Resultado |
| --- | --- | --- |
| Vista del vestíbulo con interfaz y actualización activas | 150 cuadros por repetición, dos repeticiones | **17,63 ms** y **17,57 ms p95** |
| Mismo encuadre y misma sesión, con interfaz oculta y actualización de Umbral desactivada solo en la prueba | 150 cuadros | **17,58 ms p95** |
| Combate con cuatro clientes locales | 183 cuadros del cliente instrumentado | **68,70 ms p95** |
| Tres corridas con dos clientes bajo el mismo perfil simulado | 240, 600 y 600 cuadros | **68,16 ms**, **18,16 ms** y **18,15 ms p95** |
| Visibilidad en la primera ronda con cuatro clientes | 319 ciclos, 3042 pares, 188 raycasts efectuados | **0,031 ms** de media por ciclo, **0,138 ms** de máximo |

La comparación de vestíbulo controla el encuadre y apunta a un coste pequeño del HUD en esa situación. Los **68,47 ms p95** de la candidata anterior y los **68,70 ms p95** de la prueba actual se tomaron con distinta cantidad de clientes. Las tres corridas con dos clientes y el mismo perfil también variaron ampliamente. Son observaciones de carga compartida, sin base para atribuir una mejora o un deterioro al código. La ocupación de los procesos y la memoria disponible cambian entre corridas.

**MicroProfiler.** Se extrajeron trazas de un cliente y del servidor durante las pruebas de combate, además de la sesión aislada. Las ventanas fueron cortas. En el cliente del caso con latencia, `Present` dominó los ámbitos filtrados. `Script_CameraModule` y `Umbral.PlatesClient` aparecieron en nueve muestras cada uno y quedaron por debajo de `Present`. En la captura del servidor con cuatro clientes, `Umbral.VisibilityServer` quedó por debajo de la presentación y los ámbitos de escena. `Present` puede incluir espera. La traza no separa saturación de GPU, cadencia del editor y contención de procesos. Los datos no identifican un cuello de botella del HUD, cámara, placas o raycasts que justifique cambiar el juego. [MicroProfiler de Roblox](https://create.roblox.com/docs/performance-optimization/microprofiler)

**Riesgo pendiente.** El objetivo anterior era **22 ms p95**. La sesión de cuatro clientes en Studio lo superó y falta medir un cliente instrumentado mientras el servidor y los demás clientes ejecutan la carga en otros equipos. También falta una escena con muchos jugadores mirando a varios rivales a la vez. La ronda observada no representa el peor caso de raycasts.

## QA multijugador y combate

| Caso | Resultado |
| --- | --- |
| Cuatro clientes sin latencia añadida | **Aprobado.** Inscripción tras sincronizar, revelado y revocación, teclado virtual, dos ataques programados al mismo tiempo contra una sola vida, un único punto, reaparición, ganador al vencer el tiempo, desconexión, empate entre quienes quedaron y tercera ronda con marcador limpio. |
| Ocho clientes | **Sin ejecutar.** Durante la corrida de cuatro se observaron **0,66 GiB libres**. Añadir cuatro procesos más en este equipo habría empeorado esa presión. La [guía de QA](pruebas-v0.2.0.md) permite repetir la misma suite con ocho clientes en un equipo con memoria disponible. |
| Ataques malformados, duplicados y ráfaga | Se rechazaron payloads inválidos y códigos de ronda obsoleta. Una ráfaga de 32 solicitudes quedó limitada. Los ataques duplicados y concurrentes solo produjeron un punto por vida. |
| Entrada tardía | Un tercer cliente recibió el estado de la ronda y quedó en cola, sin código ni plaza en la ronda activa. |
| Desconexión con latencia y pérdida | **Pendiente.** La primera corrida agotó ocho segundos esperando el marcador. En dos repeticiones, con y sin incorporación tardía, la sonda del servidor agotó 20 segundos esperando `Players.PlayerRemoving`. La lógica de abandono se comprobó en la corrida sin simulación. |
| Prueba con personas | **Sin ejecutar.** Las pruebas de teclado que siguen son simulación y las posiciones de combate se controlaron en Studio. |

### Latencia y discrepancia visual al cuarto dígito

Se aplicaron **75 ms de demora, 5 ms de variación y 0,2 % de pérdida por dirección**, con restauración del perfil original de cero tras la sesión. El eco de QA midió **200,5 ms**, **199,3 ms** y **200,1 ms p95**, con 20 muestras por corrida. El eco local de dos clientes del informe previo fue de **34,2 ms p95**. Con visibilidad despejada, las bajas completas tardaron **251,8 ms**, **199,7 ms** y **199,0 ms** desde el cuarto dígito virtual hasta la confirmación en el cliente. La corrida previa de dos clientes locales registró **116,3 ms** para una baja. Son muestras aisladas de baja y no permiten estimar un p95 de combate.

| Transición programada | Lo que vio el cliente al enviar | Decisión del servidor |
| --- | --- | --- |
| El objetivo cruzó detrás de una pared | La placa seguía habilitada, con pulsación aproximadamente 24 ms después del cambio en servidor | Rechazo y baja sin acreditar |
| El objetivo se giró | La placa seguía habilitada, con pulsación aproximadamente 24 ms después del giro en servidor | Rechazo y baja sin acreditar |

La réplica más antigua explica por qué se seguía mostrando la placa mientras el servidor ya tenía otra pose. Cuando llegaron las actualizaciones, el cliente quitó la placa. El servidor siguió validando contra la cobertura y orientación vigentes con sus propios datos. Las pruebas de cobertura y giro se repitieron con el mismo resultado. La suite completa con latencia queda pendiente por la desconexión sin evento del motor dentro del plazo. Hace falta repetir esa parte fuera del arnés de Studio antes de atribuirla al juego.

**Seguridad residual.** Un cliente modificado puede automatizar la escritura de códigos que ya recibió. La validación conserva el límite de frecuencia y rechaza un código recordado con el objetivo oculto. Quedan por probar el movimiento manipulado y el abuso sostenido de varios clientes. La experiencia humana con rechazos visualmente ambiguos sigue abierta.

## Automatización y compatibilidad

- GitHub Actions usa un runner estándar de Linux para compilar Luau, analizar los módulos puros y ejecutar **11 pruebas**. Rojo y Luau están fijados por versión y los ZIP por SHA-256. Los runners estándar de GitHub son gratuitos para este repositorio público. [Facturación de GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- Dos compilaciones locales del lugar final coincidieron byte por byte. El verificador confirmó **8 scripts de juego**, **12 puntos de aparición** y ausencia de objetos QA. El control negativo con el archivo de integración sí fue rechazado.
- Los scripts de la compilación completa coinciden en nombre, clase y ubicación con el mapa de fuentes de Rojo para sincronización. Coinciden también las propiedades del marcador `PlayableBounds`. Para actualizar un mapa de v0.1.0 hay que incluir ese marcador o reconstruir el lugar con el manifiesto completo. El chequeo verifica el artefacto y el manifiesto. Sigue pendiente probar la sincronización del plugin de Rojo sobre un mapa de usuario editado.
- SHA-256 del lugar candidato de cierre: `cfefe182cd0f8ad35c9ece257434de55bb52a812a3c962fa1dbc5de4dbebadc3`.

### Extracto verificable de Studio

```text
[UMBRAL QA PASS] ready immediately after sync is accepted for all participants
[UMBRAL QA PASS] two clients submit against one life at the same scheduled time and only one scores
[UMBRAL PERF CLIENT] clients=4 frames=183 p95Ms=68.70 rttN=20 rttP50Ms=32.8 rttP95Ms=33.5
[UMBRAL QA PASS] disconnect excludes the departed player and equal remaining scores result in a tie
[UMBRAL QA PASS] third consecutive round starts clean and enrolls any queued newcomer
[UMBRAL QA COMPLETE] PASS

[UMBRAL EDGE] cover visibleBefore=true visibleAtFourth=true clientPressAfterChangeMs=23.7 server=miss
[UMBRAL EDGE] turn visibleBefore=true visibleAtFourth=true clientPressAfterChangeMs=24.1 server=miss
[UMBRAL INPUT] movementIntent=true backspaceInjected=true mainRowUsed=3 mainRowBlocked=0 keyboardHitMs=251.8
[UMBRAL QA COMPLETE] FAIL ServerScriptService.UmbralQA:291: Timed out: Studio server observed PlayerRemoving
```

El bloque superior es de la corrida de cuatro clientes. Las tres líneas de combate con latencia y el vencimiento de `PlayerRemoving` proceden de corridas distintas del mismo perfil.

## Guía mínima para dos personas

Prueben con teclado y ratón físicos y registren el resultado por persona. Primero practiquen con `0917`, luego jueguen una recta y una esquina. La [guía de QA](pruebas-v0.2.0.md) tiene el protocolo completo.

1. **Lectura.** 9 de 10 códigos correctos a distancias cortas y medias.
2. **Movimiento.** 8 de 10 intentos válidos mientras conservan el movimiento. Anoten cuándo sueltan el ratón o las teclas. Prueben ambas filas y dos correcciones con Retroceso.
3. **Cobertura.** Cinco giros o cruces de esquina por persona. Cero bajas con cobertura confirmada por el servidor y al menos cuatro rechazos entendidos por quien atacó.
4. **Foco y reaparición.** Cero envíos y cero dígitos heredados al usar chat, Ajustes o cambiar de ventana. Comprueben que el jugador protegido tampoco pueda atacar y que pueda salir del punto de aparición.

**Siguiente decisión.** Mantener la candidata en revisión. Completar el playtest humano y la carga de ocho clientes, medir el p95 con cliente y servidor distribuidos y comprobar la desconexión en red degradada fuera del arnés de Studio. Si aparece un fallo de jugabilidad, reproducirlo con la pose visible y el estado del servidor antes de cambiar las reglas.
