# Revisión independiente · posterior a tanda 3 · 2026-10-07

## Dictamen

**No aparecen fallos relevantes nuevos confirmados en los casos examinados. R01–R07 están resueltos según regresiones, probes independientes y evidencia de navegador del coordinador.** La revisión no exige otra tanda de correcciones; no equivale a certificación exhaustiva de todos los recorridos ni de Android.

Se revisó código final y comparación `changes.diff` contra la copia inicial, con atención a calendario, divisiones, pagos previos, deduplicación y propagación a plantilla. No se modificaron producto, pruebas compartidas, Flutter ni APK. Se escribieron únicamente evidencias de revisión.

## Ejecución propia final

- `node prototype/cabal/model.test.js`: **55/55**, cero fallos, salida0; `review-3-suite.tap`.
- `node --check prototype/cabal/model.js` y `node --check prototype/cabal/app.js`: salida0.
- `node prototype/cabal/evaluation/validation-2026-10-07/review-3-probes.cjs`: salida0; resultados en `review-3-probes.txt`.
- R07: doce combinaciones de plan anual de doce cuotas, primera fecha enero31 de año común/bisiesto, agosto31, septiembre30, diciembre29 y octubre28, con/sin aplicación a siguientes. Editar solo importe del segundo vencimiento conserva todas las fechas.
- R07 recurrente: octubre31/noviembre30; editar solo importe noviembre conserva ancla octubre31 y cursor diciembre31. Reprocesar genera cero duplicados y plantilla sigue válida.
- Cruce R01/R06/R07: factura dividida40/60, editar siguiente importe120.000 y pagar90.000 desde Efectivo con arrastre. Pago36.000/54.000, siguiente diciembre31 con120.000+30.000=150.000. El cursor avanza a enero31 sin deriva. Conserva categoría y fecha de arrastre.
- Restauración del modelo: snapshot propio de ese libro con pago y arrastre; agregar otro plan y restaurar snapshot. Conserva exactamente obligaciones originales, saldos pendientes derivados y vínculos de pago/arrastre; reprocesamiento agrega cero. **No prueba contraseña, formulario, archivo, cifrado ni rollback real.**
- Wallet modelo: sin detección o permiso simulado rechaza sin movimientos; detección+permiso+auto con comercio/cuenta únicos registra una vez; misma captura no duplica; comercio nuevo queda pendiente. Solo datos ficticios, sin captura Android ni notificaciones reales.
- Separación vencimiento/pago: pendiente septiembre pagado en octubre deja presupuesto septiembre en0 y octubre pagado100.000/pendiente0. No duplica gasto con previsión original.

La revisión previa ya verificó rechazo atómico de fecha duplicada, protección de pagos/arrastre frente a edición directa, recordatorio del seleccionado saldado y distribución sin categoría17/33; la suite fresca mantiene esas regresiones verdes.

## Navegador y evidencia visual

Se intentó obtener el navegador solicitado mediante `cua.getTab('1',{browser:'iab'})`: devolvió `Browser is not available: iab`. El inventario posterior `cua.getState()` devolvió `apps:[]` y `browsers:[]`. **Es una limitación de la herramienta de este subagente, no un fallo del producto.** Se informó al coordinador y este retomó los recorridos UI pendientes. No se alteró viewport ni estado del navegador y no se emitió `markDeliverable` desde esta sesión, al no existir un tab accesible.

Inspección visual propia disponible: `round-2-reminder-paid.jpg`, documentada en review-2, muestra50.000 pagado, porpagar0 y recordatorio5d/10:30 coherentes. No prueba foco, medidas CSS, eventos ni reflujo.

RESULTS del coordinador registra R07 en navegador conservando marzo31; R05/R06 con formulario y pago completo; reportes cinco vistas, retorno con filtros, cuenta ahorro/conciliación/archivo/reactivación y foco/inert/Tab/Escape de plantilla. Son ejecuciones del coordinador, no propias. Las pruebas finales 320/1280, Wallet permiso separado, backup creado en sesión e ingreso/transferencia UI deben atribuirse a su evidencia cuando las complete; esta revisión no las declara verificadas por anticipado.

## Límites del cierre

No se agotaron combinaciones de frecuencia anual, cancelaciones/reanudaciones, todos los montos/divisiones, conservación de datos entre procesos, concurrencia ni todos los escenarios de interfaz. No se verificaron Android, APK, Wallet/SMS reales, tareas cerradas, notificaciones del sistema, cifrado, SAF, biometría, TalkBack, teclado virtual o ampliación de texto. Las brechas funcionales aprobadas pero excluidas del alcance de esta auditoría no se convierten en nuevas funciones ni en aprobación de publicación.

## Addendum · cierre visual y recorridos finales del coordinador

Se inspeccionaron personalmente `final-home-320.jpg`, `final-home-1280.jpg` y `round-3-backup-restored.jpg`. Disponible5.237.000, pendiente790.000 y patrimonio−1.296.500 concuerdan entre capturas móvil/escritorio/restauración. Navegación inferior visible en las tres; ninguna muestra controles cortados horizontalmente ni un defecto nuevo que impida un recorrido. En320 el botón flotante se superpone parcialmente al importe de Bicicleta en esa posición del desplazamiento; el coordinador informa contenido desplazable. Se registra la superposición visible, sin afirmar bloqueo permanente de lectura/acción a partir de una captura. En la restauración el aviso transitorio cubre parte de las filas, sin indicio de corrupción de datos o navegación bloqueada.

El coordinador completó y comunicó: mediciones320/1280 sin desborde horizontal y navegación dentro del viewport; Wallet exige permiso separado y concederlo mantiene detección apagada hasta activación expresa, reconocido se registra conauto y nuevo queda pendiente; ingreso10.000 suma disponible, transferencia5.000 bank→cash conserva disponible/patrimonio y excluye misma cuenta; backup de sesión vuelve de290.000 a790.000 pendiente tras cancelar Tele500.000, conservando plan/arrastre y disponible5.237.000; consola sinwarn/error. Estas son pruebas UI del coordinador, compatibles con los probes propios, no ejecución independiente del navegador desde esta sesión.

No se confirma un nuevo fallo relevante ni se requiere una tanda adicional por esta inspección. Se conservan los límites de teclado virtual y Android, además de los restantes indicados arriba.
