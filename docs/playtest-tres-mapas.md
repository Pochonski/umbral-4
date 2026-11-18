# Playtest de tres mapas — 15 minutos

Estado: **preparado, no ejecutado con personas**. Se necesitan dos jugadores con computadoras, teclado y ratón propios. Una sesión de dos clientes automatizados en un solo equipo no completa esta fase.

## Preparación

1. Abrir la compilación de esta rama en Studio. Confirmar que existen `ServerStorage.UmbralMapTemplates` y `ReplicatedStorage.UmbralMapPreviews`.
2. Para dos computadoras, utilizar una experiencia de prueba con acceso restringido y ambos usuarios autorizados. **Esta entrega no sube ni publica la candidata, ni modifica la visibilidad de la experiencia existente.** El propietario debe autorizar expresamente esa actualización antes de realizarla.
3. Anotar commit de la compilación, nombre de usuario, resolución, calidad gráfica y latencia aproximada. Una persona registra las observaciones de ambas.
4. Abrir el cliente Roblox en ambos equipos y entrar al mismo servidor. Pulsar Jugar en ambos. Empezar en Relevo.

Para un ensayo local previo: Studio → Servidor y clientes → 2 clientes. Esa opción usa un solo equipo y no verifica el transporte por internet ni dos teclados físicos simultáneos.

## Recorrido

| Tiempo | Prueba | Criterio observable |
| --- | --- | --- |
| 0–3 min | Relevo: correr, mirar con el ratón y escribir; probar ceros iniciales, Retroceso y un código erróneo | Movimiento continuo, cuatro dígitos correctos, entrada comprensible y sin pérdida de foco |
| 3–5 min | Ambos votan Puerto; uno cambia el voto, sale de cola y vuelve | Un voto por persona; contador coherente y ningún salto a un mapa distinto del resultado |
| 5–8 min | Puerto: torre, contenedores y galería. Asomarse y esconderse por turnos | Placa visible cuando corresponde; recordar un código no permite atravesar cobertura opaca |
| 8–10 min | Reapariciones en Puerto y votación por Invernadero | Código renovado, protección temporal, movimiento libre y ausencia de placas de la ronda anterior |
| 10–13 min | Invernadero: núcleo, refrigeración y ambas galerías; comparar sol y sombra | Cuatro dígitos legibles al correr; siluetas distinguibles y cámara cómoda en rampas |
| 13–15 min | Intercambiar observaciones y reproducir el peor caso una vez | Registrar ubicación, orientación, código esperado y decisión real, sin asumir que todo rechazo es un error |

La ronda normal dura hasta cuatro minutos y termina antes si se alcanza la meta. Ajustar el cronómetro humano a sus transiciones; **no modificar Config de producción para acelerar el ensayo**.

## Registro compartido mínimo

Copiar esta tabla a un documento compartido o archivo CSV. No hacen falta servicios ni sistemas nuevos dentro del juego.

| ID | Jugador | Mapa / zona | Minuto | Acción y resultado esperado | Resultado observado | ¿Se repite? | Captura / clip | Gravedad |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | A o B | Puerto / contenedor C2 | 06:20 | Escribí 0917 al ver la placa | Rechazo / baja / entrada incompleta | 0/3, 1/3… | Archivo | Bloquea / molesta / visual |

Al terminar, ambos califican de 1 a 5: lectura de placas, escritura mientras se mueven, cámara, comprensión de rechazos y preferencia de mapa. Anotar además si una aparición deja al jugador atrapado o expuesto sin salida, especialmente Spawn 03 de Relevo.

En Spawn 03 y 09, intentar primero una salida natural sin indicaciones. Después comprobar la diagonal hacia el centro y las rutas laterales. En Spawn 09 la baliza bloquea la dirección +X en la prueba automática: registrar si resulta comprensible o si interrumpe injustamente la reaparición. No confundir ese resultado automatizado con una evaluación humana ya completada.

## Pendientes que este ensayo no sustituye

Ocho participantes, hardware modesto, latencia adversa controlada, balance estadístico de apariciones y pruebas largas. Un éxito de 15 minutos permite decidir el siguiente ajuste; no demuestra ausencia total de defectos.
