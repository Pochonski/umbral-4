# Validación de Umbral 4 v0.2.0

## Pruebas reproducibles

Con Luau CLI, Rojo y Python disponibles en el entorno de desarrollo:

```powershell
luau tests/rules.luau
luau tests/input_buffer.luau
python tests/build_studio_qa.py (Get-Command rojo).Source Umbral4-QA.rbxlx
```

El lugar QA está separado del archivo jugable. Acorta los tiempos y añade scripts de prueba de Studio. Para el caso de dos clientes, abre el lugar QA y selecciona **Servidor y clientes**. Lee la salida del servidor y busca los mensajes `[UMBRAL QA PASS]` y el resultado final `[UMBRAL QA COMPLETE]`.

Para elegir el número de clientes y probar una incorporación durante la ronda desde un plugin de Studio o el contexto de edición del MCP, abre la copia QA y ejecuta:

```luau
local test = game:GetService("StudioTestService")
local clients = 2 -- también 4 u 8 cuando el equipo pueda sostenerlos
local result = test:ExecuteMultiplayerTestAsync(clients, {
    clients = clients,
    lateJoin = clients == 2,
    latencyEdges = false,
})
print(result)
```

Para la matriz, ejecuta primero 2 clientes y luego 4 y 8 como sesiones independientes. Usa un equipo de pruebas con memoria libre, observa la presión al iniciar los clientes y conserva la salida de cada sesión. La prueba de 2 clientes incorpora un tercero mientras transcurre una ronda. Las pruebas con 4 y 8 programan dos ataques contra la misma vida, simulan la salida de un participante y comprueban el empate y el arranque de la tercera ronda.

Para comparar latencia, ejecuta primero la prueba con la simulación de red de Studio desactivada. Después configura un perfil personalizado de 75 ms entrantes y 75 ms salientes, 5 ms de variación y 0,2 % de pérdida en cada dirección. En la segunda prueba usa `latencyEdges = true` para observar la placa en el cuarto dígito durante un giro y un cruce de cobertura. Guarda los valores originales y restáuralos al terminar. Comprueba que el eco de QA cambie antes de atribuir resultados al perfil. Si una desconexión simulada falla, comprueba si el registro indica que faltó `PlayerRemoving` en Studio o si se recibió el evento y faltó la actualización del juego.

## Compilación y sincronización

GitHub Actions ejecuta las pruebas Luau, analiza los módulos que no dependen del motor y verifica dos compilaciones idénticas. El verificador comprueba que los scripts del lugar coincidan con el manifiesto de sincronización, que el lugar distribuido no incluya el arnés QA y que el marcador de límites tenga las propiedades esperadas.

```powershell
rojo build default.project.json -o Umbral4.rbxlx
rojo build default.project.json -o Umbral4-rebuild.rbxlx
rojo sourcemap sync.project.json -o sourcemap.json
python tests/verify_place.py Umbral4.rbxlx Umbral4-rebuild.rbxlx sourcemap.json
```

Cuando actualices un mapa anterior a v0.2.0, añade `PlayableBounds` antes de sincronizar los scripts o compila el lugar completo. El manifiesto de sincronización deja `Workspace` fuera de su alcance.

### Qué mide la automatización

- `VirtualInput` pasa por el código de entrada real del cliente. Prueba el teclado numérico, el bloqueo por un campo de texto y Ajustes. Intenta también la fila superior y Retroceso, y registra cuando el motor reserva esas teclas. La pulsación sostenida y la intención de movimiento de WASD se observan con las posiciones controladas.
- Los remotos de QA ejercitan ráfagas, payloads malformados, identificadores obsoletos y ataques concurrentes. Estos casos prueban validación a nivel de protocolo.
- La muestra de rendimiento del servidor registra pares examinados, raycasts y tiempo del muestreo de visibilidad. El p95 de cuadro corresponde a un cliente de Studio que comparte equipo con el servidor y los demás clientes.
- El eco de QA mide ida y vuelta del remoto en el mismo reloj. La muestra de teclado a baja mide desde la última tecla virtual hasta el aviso de acierto. El eco y la baja miden recorridos distintos.

## Prueba con personas

Usa el lugar jugable y dos personas, cada una con su teclado y ratón. Anota la versión, número de jugadores, tipo de teclado, resolución y perfil de red. Conserva los resultados separados de la suite automática.

1. **Lectura.** Cada persona abre **Cómo jugar** e introduce `0917` sin instrucciones externas. En la ronda, anota los códigos leídos de frente a distancias cortas y medias. Criterio inicial por persona, 9 de 10 lecturas correctas. Repite una parte de la prueba a 720p y a 1080p cuando sea posible.
2. **Movimiento y digitación.** En una ruta despejada, cada persona hace diez intentos mientras usa WASD y el ratón. Reparte los intentos entre ambas filas si el teclado tiene numérico. Criterio inicial, 8 de 10 intentos sin detener el movimiento para teclear. Registra errores y prueba dos correcciones con Retroceso. Un código válido de cuatro dígitos debe enviarse una sola vez.
3. **Cobertura y comprensión.** Haz cinco intentos por persona mientras el rival gira o cruza una esquina. Registra lo que veía el atacante al cuarto dígito y qué decidió el servidor. Criterio, ninguna baja cuando el servidor confirma cobertura y al menos 4 de 5 rechazos comprendidos. Anota por separado los rechazos que el atacante creyó injustos.
4. **Foco.** Abre Ajustes a mitad de un código. Comprueba cursor, bloqueo de ataques, limpieza de la entrada y retorno a primera persona. Repite con chat, Esc y cambio de ventana. Criterio, cero envíos involuntarios y ningún dígito heredado en el siguiente intento.
5. **Reaparición.** Observa si la protección es clara y si el nuevo punto ofrece una salida. Comprueba que el jugador protegido no pueda atacar y registra las bajas inmediatamente después de vencer la protección.

Estos criterios son objetivos para la prueba con personas. Las pulsaciones de `VirtualInput` y las posiciones controladas de la suite se registran como evidencia automatizada.
