# Refinamiento — mediciones verificables

## Votación: comparación A/B

Datos: [`refine-preview-performance.json`](evidence/refine-preview-performance.json). Mismo cliente activo, servidor en proceso separado, misma escena/cámara/FOV, UI anterior y candidata alternadas. Dos muestras de diez segundos por variante/caso, tres segundos de calentamiento. Resolución nativa comprobada; par Puerto/Invernadero. Ryzen 5600G, RTX 5060, 16 GB de RAM; no hardware modesto.

| Calidad | Resolución | Variante | p50 cuadro, ms | p95 cuadro, ms | p95 CPU render, ms | p95 GPU render, ms |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| 05 | 1280×720 | baseline | 16.65–16.66 | 17.74–17.85 | 5.22–5.35 | 0.93–1.10 |
| 05 | 1280×720 | candidate | 16.61–16.68 | 17.66–17.89 | 5.31–5.69 | 0.90–1.25 |
| 05 | 1920×1080 | baseline | 16.63–16.66 | 17.88–17.91 | 5.07–5.45 | 1.16–1.49 |
| 05 | 1920×1080 | candidate | 16.66–16.69 | 17.61–17.93 | 5.16–5.26 | 1.04–1.44 |
| 10 | 1280×720 | baseline | 16.64–16.67 | 17.77–18.10 | 5.06–5.68 | 1.10–1.27 |
| 10 | 1280×720 | candidate | 16.65–16.66 | 17.52–18.04 | 5.30–5.39 | 1.17–1.24 |
| 10 | 1920×1080 | baseline | 16.63–16.68 | 17.79–17.85 | 5.18–5.31 | 1.06–1.12 |
| 10 | 1920×1080 | candidate | 16.65–16.68 | 17.66–18.07 | 5.18–5.56 | 1.02–1.33 |

Los rangos abarcan las dos repeticiones, sin porcentajes de mejora. La cadencia próxima a 60 Hz limita la comparación del tiempo de cuadro; no demuestra rendimiento de ocho jugadores ni ausencia de picos. Los valores CPU/GPU observados se incluyen sin atribuir toda diferencia al cambio.

### Creación inicial e instancias

Una observación por variante; no es un percentil ni una media de arranques. Ambas variantes estaban cargadas, por lo que la memoria global no se interpreta como memoria exclusiva de la miniatura.

| Variante | Piezas en las dos vistas | Crear interfaz, ms | Aplicar estado inicial y clonar, ms |
| --- | ---: | ---: | ---: |
| baseline | 37 | 2.25 | 1.45 |
| candidate | 478 | 2.97 | 7.80 |

La tanda anterior `refine-preview-performance-background.json` quedó en torno a 68 ms p95 con Studio en segundo plano. No se mezcla con esta comparación. La diferencia entre tandas no se presenta como una optimización del juego. Los encuadres de Relevo se inspeccionan visualmente, pero no forman parte del par de esta tabla.

## Transiciones y red

Datos: `refine-network-zero.json`, `refine-network-custom75.json`, `refine-network-3g.json` y `refine-ping-*.json`. Un cliente y servidor separados; QA MinPlayers=1. Cada perfil completa cuatro rondas y tres cambios de mapa, con doce comprobaciones. **Sin oponente ni combate en este modo.**

| Perfil | NetworkPing medido, ms (5 muestras) | Eco de aplicación, ms (8 muestras) | Convergencia máxima tras estado vivo, ms | Cierre del voto → avatar coherente, s | Errores del monitor |
| --- | ---: | ---: | ---: | ---: | ---: |
| zero | 3.8–9.1 | 26.2–586.6 | 31.2 | 3.44–3.52 | 0 |
| custom75 | 156.3–157.6 | 182.4–274.4 | 49.1 | 3.54–3.60 | 0 |
| 3g | 387.8–405.8 | 416.5–517.8 | 30.4 | 3.64–4.02 | 0 |

La última columna temporal incluye la cuenta regresiva QA de **tres segundos**, aparición y replicación. No es el tiempo aislado de cargar un modelo; producción mantiene su cuenta de diez segundos. La convergencia se cuenta desde que el cliente recibe el estado vivo; no sustituye la latencia de ida y vuelta. La muestra NetworkPing de cero procede de una sesión separada con la misma configuración sin demora. Las diferencias menores a un cuadro no se consideran significativas.

Las ocho muestras de eco comienzan al inscribirse, sin calentamiento: el perfil cero incluye un valor de 586,6 ms al arranque. Se conserva esa observación, sin atribuirla a la red ni convertir ocho muestras en un p95 estable. NetworkPing y eco de aplicación miden recorridos distintos.

Los monitores no encontraron avatares antiguos persistentes ni creación de placas por los mensajes de ronda obsoleta inyectados. No había placas enemigas naturales (`enabledPlateFrames=0`): la prueba de una placa rival visible durante una transición con latencia queda pendiente. Las muestras de cuadro del arnés de transición corresponden a su ventana de 689×635 y segundo plano; **no son evidencia de FPS a 720p/1080p**.

## Montaje del servidor

Datos: [`refine-server-activation.json`](evidence/refine-server-activation.json). Nueve activaciones en servidor inactivo, tres por mapa, con espera entre ellas. Implementación de Arena y fuentes de los escenarios idénticas a la base. No incluye red, aparición, contador ni combate.

| Mapa | Mínimo / mediana / máximo, ms |
| --- | ---: |
| relevo | 20.40 / 22.50 / 26.32 |
| puerto | 15.47 / 16.47 / 17.37 |
| invernadero | 7.92 / 8.71 / 12.51 |

Son tres observaciones por mapa, insuficientes para un p95 de montaje. Un montaje puede superar un presupuesto de cuadro; sucede fuera de combate y no se modificó su implementación. No se identifica aquí una regresión causada por las miniaturas ni se atribuye una mejora al juego.

## Límites conservados

Dos clientes bajo latencia: intento cancelado por memoria. Ocho clientes, hardware modesto, personas con teclados físicos y una réplica de internet real: pendientes. No se sustituye esa validación por las simulaciones ni por esta tabla.
