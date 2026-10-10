# Revisión independiente · FAB y detalle

2026-10-07. Alcance acotado al feedback: unificar alta desde Inicio/Movimientos, quitar franja reservada y proponer una organización alternativa de los metadatos del detalle. Se revisaron app/styles/index frente a `before/`, capturas y helpers reales; sin modificar producto, Flutter ni APK. El nuevo detalle es una propuesta para juzgar visualmente, no aprobación estética del usuario.

## Resultado

Sin defecto funcional relevante nuevo confirmado en los cambios examinados. Inicio y Movimientos utilizan exactamente `homeActions()` y el mismo `movement-actions`, por lo que comparten FAB y hoja con las cuatro opciones. La franja se elimina del flujo: FAB absoluto sobre contenido, con espacio final de scroll para recuperar acceso a la última fila. El detalle conserva datos y acciones; cambia presentación a definición semántica `dl/dt/dd` en dos columnas, con nota a ancho completo y devolución dentro del mismo grid.

## Evidencia propia

- Capturas inspeccionadas: before/history390 y detail390; after/history390, history-end390 y detail390. La última fila del historial queda por encima del FAB al final del scroll. En posición intermedia, el FAB se superpone al importe de Transferencia; el final del scroll demuestra que la oclusión no es permanente. Es el comportamiento del flotante solicitado y no acredita bloqueo de acceso.
- 25 movimientos seed comparados con helpers reales antes/después en VM: etiquetas, importes y acciones preservados. `review-probes.cjs` y `review-probes.json`. Incluye origen/destino, categoría, canal, nota y disponible para devolución cuando corresponde. No prueba layout/interacción.
- Suite fresca `node prototype/cabal/model.test.js`: 55/55, cero fallos; `review-model-tests.tap`.
- Fuente: render añade el mismo FAB solo en home/history; no introduce botones en detalle ni cambia handlers de guardado, edición, clonado, devoluciones o eliminación. CSS usa minmax(0,1fr), min-width0 y overflow-wrap para valores del detalle. No se alteran model.js ni cálculos.

## Cobertura del principal y límites

El principal comunica hojas idénticas de cuatro opciones, Ingreso abre tipo correcto y medición history390: contenido termina donde empieza navegación, última fila669.5 < FAB692. Su evidencia complementa esta revisión; no son recorridos propios. El navegador independiente continúa sin superficies disponibles. No se afirma verificación táctil, TalkBack, teclado Android ni app Flutter.

Las capturas320/1280 estaban pendientes al redactar este bloque; no se infiere una prueba de esos tamaños solo por CSS. La propuesta del detalle no se puntúa por gusto personal. Recordatorios HTML siguen siendo previsualización; esta revisión no acredita entrega nativa de avisos ni implementa scheduler/AlarmManager en Flutter.

## Adenda · capturas finales320/1280

Inspeccionadas after/history320, empty320, history1280, detail390 recapturado y detail-long320/detail-long1280. El nombre largo y nota larga se distribuyen dentro del ancho visible; el detalle390 sitúa Disponible para devolver junto a Canal. La nota ocupa el ancho completo y conserva lectura multilineal. En320 el resto del detalle continúa bajo el borde del scroll; no prueba pérdida de información. La lista vacía conserva FAB y navegación. No aparece franja reservada en las capturas.

El principal midió320 ancho=scroll320 y dispositivo en1280 ancho=scroll458, y comunica Escape desde hoja de alta vacía con foco devuelto al FAB y cero diálogos. Son mediciones/recorridos del principal, complementados por inspección visual independiente. No hay nuevo defecto funcional relevante confirmado ni motivo para otra tanda; el detalle sigue siendo propuesta visual para el usuario. Permanecen las limitaciones de navegador propio y Android real.
