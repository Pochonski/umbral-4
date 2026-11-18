# Mediciones de mapas — 18 de noviembre de 2026

Fuente: [`evidence/mapas-performance.json`](evidence/mapas-performance.json). Un cliente con servidor local de Studio; cámara/FOV fijos, sin UI, cinco segundos de calentamiento y dos muestras de quince segundos por caso. Calidad del renderizador Studio 5 y 10, resolución nativa afirmada por el test. No son pruebas de ocho jugadores ni de hardware modesto.

## Cadencia de cuadros

Cada celda muestra el rango entre las dos repeticiones, en milisegundos.

| Mapa | Calidad | Resolución | p50 de cuadro | p95 de cuadro | p95 CPU render | p95 GPU render |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| relevo | 05 | 1280×720 | 16.69–16.69 | 17.66–17.98 | 5.04–5.09 | 0.71–0.75 |
| relevo | 05 | 1920×1080 | 16.67–16.68 | 17.81–18.01 | 5.14–5.17 | 1.03–1.12 |
| relevo | 10 | 1280×720 | 16.66–16.69 | 17.62–17.92 | 4.89–5.10 | 0.79–0.98 |
| relevo | 10 | 1920×1080 | 16.65–16.65 | 17.79–18.15 | 5.07–5.12 | 0.69–0.81 |
| puerto | 05 | 1280×720 | 16.66–16.66 | 17.87–17.93 | 4.90–4.99 | 0.98–0.98 |
| puerto | 05 | 1920×1080 | 16.67–16.70 | 17.66–17.75 | 4.79–4.82 | 0.58–0.71 |
| puerto | 10 | 1280×720 | 16.63–16.67 | 17.94–18.22 | 5.06–5.06 | 0.81–1.01 |
| puerto | 10 | 1920×1080 | 16.66–16.67 | 17.75–17.78 | 4.77–5.25 | 0.88–1.14 |
| invernadero | 05 | 1280×720 | 16.66–16.68 | 17.71–17.94 | 4.93–4.95 | 0.59–0.71 |
| invernadero | 05 | 1920×1080 | 16.65–16.70 | 18.16–18.19 | 5.01–5.04 | 1.08–1.09 |
| invernadero | 10 | 1280×720 | 16.69–16.70 | 17.60–17.82 | 4.82–4.87 | 0.61–0.67 |
| invernadero | 10 | 1920×1080 | 16.64–16.69 | 17.73–17.97 | 4.97–5.23 | 0.99–1.13 |

Se compara cada mapa con Relevo dentro de la misma candidata, con idéntico cliente y método. No se infiere una mejora porcentual ni un rendimiento universal. La mediana próxima a la cadencia de 60 Hz no demuestra margen de GPU. Las muestras incluyen el motor y servidor local. La primera tanda `mapas-performance-initial.json` no se usa en esta tabla porque su control de cámara/UI era insuficiente.

## Navegación y geometría

| Mapa | Marcadores apoyados | Envolventes obstruidas | Rutas automáticas hacia primer marcador | Puntos de auditoría | Comparaciones | Raycasts | Discrepancias |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| relevo | 12/12 | Spawn 03, Spawn 09 | 12/12 | 80 | 3214 | 11544 | 0 |
| puerto | 12/12 | Ninguna | 12/12 | 80 | 2954 | 9856 | 0 |
| invernadero | 12/12 | Ninguna | 12/12 | 80 | 3220 | 10812 | 0 |

El primer marcador hacia sí mismo es un caso trivial; los otros once usan Pathfinder. Las intersecciones conservadoras de Spawn 03/09 de Relevo requieren verificación física y no se modificaron. Las rutas automáticas no representan navegación humana. La auditoría compara consultas de combate con una copia de toda la geometría opaca consultable, desde posiciones apoyadas en suelo y superficies elevadas dentro del alcance de 45 studs. Cero diferencias en esta muestra no certifica toda cámara o esquina.

Los datos crudos incluyen memoria total del cliente y composición de escena consultada después de cada mapa. No se compara esa memoria como tamaño exclusivo del mapa, porque incluye cachés, engine, avatar y herramientas de Studio.
