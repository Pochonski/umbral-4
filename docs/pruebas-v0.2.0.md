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
local result = test:ExecuteMultiplayerTestAsync(clients, {clients = clients, lateJoin = clients == 2})
print(result)
```

Para comparar latencia, ejecuta primero la prueba con la simulación de red de Studio desactivada. Después configura un perfil personalizado de 75 ms entrantes y 75 ms salientes, 5 ms de variación y 0,2 % de pérdida en cada dirección. Guarda los valores originales y restáuralos al terminar. Comprueba que el eco de QA cambie antes de atribuir resultados al perfil.

### Qué mide la automatización

- `VirtualInput` pasa por el código de entrada real del cliente. Prueba el teclado numérico, el bloqueo por un campo de texto y Ajustes. Intenta también la fila superior y Retroceso, y registra cuando el motor reserva esas teclas. La pulsación sostenida y la intención de movimiento de WASD se observan con las posiciones controladas.
- Los remotos de QA ejercitan ráfagas, payloads malformados, identificadores obsoletos y ataques concurrentes. Estos casos prueban validación a nivel de protocolo.
- La muestra de rendimiento del servidor registra pares examinados, raycasts y tiempo del muestreo de visibilidad. El p95 de cuadro corresponde a un cliente de Studio que comparte equipo con el servidor y los demás clientes.
- El eco de QA mide ida y vuelta del remoto en el mismo reloj. La muestra de teclado a baja mide desde la última tecla virtual hasta el aviso de acierto. El eco y la baja miden recorridos distintos.

## Prueba con personas

Usa el lugar jugable y dos personas, cada una con su teclado y ratón. Anota la versión, número de jugadores, tipo de teclado, resolución y perfil de red. Conserva los resultados separados de la suite automática.

1. Cada persona abre **Cómo jugar** e introduce `0917` sin recibir instrucciones externas. Ambas pulsan **Jugar**.
2. En una ruta despejada, cada una intenta tres bajas mientras alterna WASD y ratón. Anota si tuvo que dejar de moverse, mirar el teclado o corregir un dígito. Repite con teclado superior y numérico.
3. En una esquina, gira al rival durante la entrada del código y repite cruzando cobertura. Anota qué veía el atacante al pulsar el cuarto dígito, si el aviso llegó y si entendió el resultado.
4. Abre Ajustes a mitad de un código. Comprueba cursor, bloqueo de ataques, limpieza de la entrada y retorno a primera persona. Repite con chat, Esc y cambio de ventana.
5. Durante varias reapariciones, observa si la protección es clara, si el punto ofrece una salida y si aparecen bajas injustas al acabar la protección.
6. Repite con un grupo de cuatro y otro de ocho. Comprueba empates, abandono del líder, entradas tardías y si las posiciones elevadas controlan demasiadas rutas.

Registra por separado las bajas legítimas, los rechazos que entendió el jugador, los rechazos que creyó injustos y los intentos que interrumpieron el movimiento. La pregunta de aceptación es si el jugador puede leer, teclear y seguir jugando sin tener que detenerse para operar la interfaz.
