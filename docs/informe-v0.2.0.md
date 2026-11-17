# Umbral 4 · Informe técnico para revisión con ChatGPT

**Estado** · Candidata local v0.2.0, 17 de noviembre de 2026. La candidata se construyó y abrió en Roblox Studio. Falta la prueba con personas y la validación de carga antes de considerar la versión lista para publicar.

## Decisiones y comparación con v0.1.0

| Área | v0.1.0 | Candidata v0.2.0 |
| --- | --- | --- |
| Entrada | El cuarto dígito se enviaba y el código seguía editable brevemente. La expiración del intento dependía del ciclo del HUD. | Un búfer independiente se vacía al enviar y comprueba la caducidad antes de aceptar la siguiente pulsación. El HUD conserva brevemente la confirmación visual. |
| Cámara | Al salir de primera persona se escribía un mínimo de zoom de 7 y se sustituía inmediatamente por 0,5. | Ajustes aplica la distancia durante la transición y devuelve el mínimo configurado al recuperar el control de combate. Se respetan el menú de Roblox y el foco de texto. |
| Placas | La autorización usaba el personaje y el cliente comprobaba oclusión desde la cámara. | Cliente y servidor usan la misma geometría de combate. El cliente añade el encuadre y la cara visible para dibujar. El servidor vuelve a comprobar la pose y la cobertura antes de acreditar una baja. |
| Sincronización | El estado, las placas y el resultado viajaban en tres eventos. La resincronización podía reenviar una concesión anterior sin comprobar visibilidad en ese momento. | Un evento fiable ordena estado, placas y avisos. La resincronización confirma que el objetivo y la concesión siguen vigentes y vuelve a comprobar la geometría. |
| Arena | Los límites estaban definidos por números en el módulo. | El modelo incluye un volumen invisible y no consultable, `PlayableBounds`. Su posición, tamaño y orientación definen la arena. Se validan los puntos de aparición al cargar. |
| Rendimiento | La toma de poses se repetía por pareja. | El servidor calcula una pose por jugador activo y muestra métricas de pares, raycasts y tiempo en Studio. Se añadieron ámbitos para analizar cliente y servidor en MicroProfiler. |

Se conservaron las reglas de alcance, temporización, puntuación y estética. El aviso de límite indica cuándo esperar antes de reintentar. La primera persona mantiene un origen de ataque cercano al personaje. Ampliar la tolerancia con posiciones declaradas por el cliente, o aceptar ataques por un código previamente visto, permitiría bajas a través de cobertura. La candidata rechaza esos casos.

## Hallazgos reproducidos y alcance de la corrección

- **Discrepancia geométrica reproducida.** En Studio, con los módulos de v0.1.0, un objetivo frontal y dentro del encuadre cumplió el filtro de dibujo de una placa concedida, mientras el servidor rechazó el intento por la orientación del atacante. La rama usa el mismo origen y los mismos ángulos para el dibujo y la validación. Las posiciones replicadas todavía pueden diferir temporalmente entre máquinas.
- **Búfer y caducidad.** La inspección confirmó que Retroceso podía operar sobre el código enviado mientras duraba la animación. La nueva prueba asegura que el prefijo se borre al enviar y que una pulsación posterior al plazo no complete un intento que el HUD todavía muestra.
- **Zoom.** Se confirmó la doble asignación en el código anterior. No se aisló un fallo visual reproducible de v0.1.0 causado exclusivamente por esas dos escrituras. En la candidata, la prueba virtual sí comprobó apertura y cierre de Ajustes, cámara clásica durante el panel y retorno a primera persona con el mínimo original.
- **Límites.** La prueba de Studio verificó un volumen trasladado y rotado y rechazó posiciones fuera de sus bordes. El archivo jugable incluye un marcador. Las copias antiguas que se actualicen únicamente con Rojo necesitan incorporar el marcador o recompilar el lugar completo.

## Resultados comprobados

| Prueba | Resultado |
| --- | --- |
| Compilación | Luau compiló los scripts y Rojo construyó el lugar autónomo. El archivo de revisión se abrió en Studio y no contiene scripts QA. |
| Reglas puras | **11 pruebas aprobadas.** Siete casos de reglas y cuatro del búfer. |
| Integración local | **Aprobada** con dos clientes y una incorporación posterior. Se probaron revelado frontal, giro, pared, resincronización, protección, reaparición con código nuevo, marcador, cierre por tiempo, nueva ronda, entrada tardía sin códigos y término sin ganador tras desconectarse un participante. |
| Teclado simulado | **Baja confirmada desde el cliente** con `VirtualInput`. Se logró con ambas filas numéricas, Retroceso, tecla sostenida e intención de WASD activa. Se verificó el bloqueo en Ajustes y en un campo de texto. Los personajes estaban en posiciones controladas. |
| Cargas adversas | Una ráfaga de 32 solicitudes quedó limitada. El código recordado detrás de la pared, el payload malformado, el identificador de ronda obsoleto y los duplicados no dieron puntos indebidos. |
| Red con un cliente de Studio | **Perfil aplicado y medido.** Se comparó el eco del transporte en sesión local y con 75 ms en cada dirección, 5 ms de variación y 0,2 % de pérdida por dirección. Se verificó la restauración a los seis valores iniciales de cero y se retiró la sonda. |
| Cuatro y ocho clientes | **Pendientes de ejecución.** Hay casos preparados para dos atacantes contra la misma vida y empate tras una desconexión. La comprobación de recursos encontró aproximadamente 2,5 GiB disponibles en un equipo de 15,9 GiB. Una corrida anterior de dos clientes con una copia de edición adicional llegó a 0,3 GiB libres. |
| Playtest con personas | **Pendiente.** No se realizaron pruebas con jugadores humanos. Faltan el desplazamiento libre mientras se escribe, ergonomía, lectura, posiciones de cámara dinámicas y sensación del feedback. |

Durante el ajuste de QA, las primeras corridas detectaron problemas del propio entorno de prueba, entre ellos una carga de texto con codificación incorrecta en una copia temporal, una bandera de repetición que el motor no admitía para dígitos y el bloqueo de la tecla superior `One` por `CoreGui` en una corrida. La suite registra cuándo se permite la fila superior y cuándo recurre al teclado numérico. La corrida final usó ambas filas y Retroceso. Sigue pendiente una comprobación exhaustiva de teclas físicas. [Documentación de VirtualInput](https://create.roblox.com/docs/reference/engine/classes/VirtualInput)

## Rendimiento, latencia y seguridad

| Métrica de Studio | Resultado observado |
| --- | --- |
| Visibilidad de servidor, ronda con dos clientes | 319 ciclos, 510 pares evaluados y 992 raycasts. Media de **0,038 ms** por ciclo y máximo de **0,232 ms**. |
| Cuadros del cliente en esa sesión | **68,47 ms p95** en 169 cuadros. El equipo ejecutaba servidor y varios procesos de Studio. La muestra supera el objetivo anterior de 22 ms. No identifica por sí sola un cuello de botella de renderizado o una cifra de producción. |
| Cuarto dígito virtual a baja confirmada | **116,3 ms** en una muestra con dos clientes locales. El eco de QA en esa sesión marcó **34,2 ms p95** en 20 muestras. |
| Eco en sesión de un cliente sin perfil | **49,7 ms p50**, **51,0 ms p95**, 20 muestras. |
| Eco en sesión de un cliente con perfil | **182,9 ms p50**, **184,0 ms p95**, 20 muestras. El contador de ping de Studio indicó **157,4 ms**. La medición corresponde al eco, con una prueba de combate bajo latencia aún pendiente. |

Los datos no permiten declarar una mejora porcentual respecto a v0.1.0, porque falta una medición equivalente de aquella versión. Los recuentos y los tiempos muestran qué cuesta el muestreo en el escenario probado y permiten repetir la comparación con 4 y 8 clientes. La sesión con perfil comprueba que Studio aplicó la simulación, pero una sola baja local no permite calcular un p95 fiable de respuesta de combate. [Pruebas y simulación de red en Studio](https://create.roblox.com/docs/studio/testing-modes)

**Seguridad residual.** El cliente puede automatizar la entrada de un código que ya recibió. El servidor conserva la decisión y limita la frecuencia. La prueba cubrió ataques detrás de cobertura y mensajes inválidos u obsoletos. Sigue pendiente medir abuso sostenido desde varios clientes, teletransporte o movimiento manipulado y ataques cruzados bajo latencia. Las pruebas de clasificación y empate a nivel de reglas pasaron. El empate tras una desconexión sigue pendiente en una sesión de cuatro u ocho.

## Evidencia de Studio

```text
[UMBRAL INPUT] movementIntent=true backspaceInjected=true mainRowUsed=3 mainRowBlocked=0 keyboardHitMs=116.3
[UMBRAL PERF CLIENT] clients=2 frames=169 p95Ms=68.47 rttN=20 rttP50Ms=32.7 rttP95Ms=34.2
[UMBRAL PERF] round=1 ticks=319 pairChecks=510 raycasts=992 meanMs=0.038 maxMs=0.232
[UMBRAL QA PASS] late connection receives the round and queues without taking a seat or receiving codes
[UMBRAL QA PASS] disconnect below minimum ends without a winner
[UMBRAL QA COMPLETE] PASS
```

La entrega incluye una captura de Estación de Relevo desde el archivo candidato. La [guía de validación](pruebas-v0.2.0.md) contiene los pasos para reproducir las pruebas automáticas y de juego. [v0.1.0 como punto de recuperación](https://github.com/Pochonski/umbral-4/releases/tag/v0.1.0)

## Recomendación para la siguiente etapa

1. **Probar con dos personas y teclado físico.** Jugar primero en una recta y luego en una esquina. Registrar si hace falta dejar el ratón o WASD, qué ve el atacante al pulsar el cuarto dígito y si entiende el aviso recibido. Repetir con chat, Ajustes y cambios de foco.
2. **Completar la carga con cuatro y ocho clientes en un equipo con memoria disponible.** Medir cuadro y servidor por separado, verificar el empate, los ataques simultáneos y varias rondas consecutivas. Añadir latencia y cronometrar suficientes bajas para evaluar el objetivo de confirmación.
3. **Ajustar solo los problemas observados.** Si se repiten rechazos al cruzar una esquina, registrar el estado del cliente y del servidor en ese instante antes de cambiar los ángulos o la tolerancia. Luego revisar reapariciones y balance con personas, y decidir si la candidata puede pasar a alfa privada.
