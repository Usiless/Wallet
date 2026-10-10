# Registro de ejecución

## Tanda 0 · base antes de correcciones

- Sintaxis: `node --check prototype/cabal/model.js` y `node --check prototype/cabal/app.js`, salida 0.
- Modelo: `node prototype/cabal/model.test.js`, 48/48, 0 fallos. Salida íntegra: `round-0-tests.tap`. Esto no prueba la interfaz.
- A01/A02, navegador: escenario `first`, configuración sin cuentas → Inicio a cero; Gasto → «Crear cuenta y continuar» → cuenta bancaria ficticia con 100.000 ₲ → vuelve al borrador con cuenta seleccionada. Guardar importe vacío da validación; gasto de 25.000 ₲ deja saldo/disponible/patrimonio en 75.000 ₲.
- El selector Playwright por rol no encontró el `summary` de Nuevo movimiento aunque AX lo expone como botón. Se abrió con su selector DOM observado; fallo del selector de prueba, no del control.

## Decisiones de ejecución

- Correcciones dentro de recorridos existentes, sin pedir confirmación entre tandas, tal como solicitó el usuario.
- No existe Git accesible. Comparación contra `/tmp/cabal-validation-baseline/`; no se declara un diff de commits.
- La documentación histórica es evidencia de evaluaciones anteriores, no resultado de esta pasada.

## Limitaciones permanentes de esta validación

No hay Android, captura real Wallet/SMS, notificaciones del sistema, biometría, cifrado, SAF, rollback de base real, proceso cerrado, teclado virtual, TalkBack ni auditoría WCAG integral. Las mediciones de viewport y foco son del navegador.

## Recorridos adicionales en navegador

- A03: gasto25k→editar30k; clonar/cancelar sin guardar; eliminar/deshacer restaura una sola fila y saldo70k de cuenta inicial100k.
- A04/A10: crédito101 dividido51/50 en3 cuotas, primera2027-01-31. Deuda+101, disponible intacto; reporteenero muestra33 y detalle16/17. Volver conservaenero. `round-0-credit.jpg`.
- A07: Bicicleta octubre110k (incluye10k anterior), pagar90k en Efectivo con traslado deja noviembre120k; historial conserva ambos pagos90k.
- A06/A08: repro anterior, electricidad180k editar próximaOct10 duplicabaOct9/Oct10 y total790k→970k. Tras corrección: plantilla Factura dividida100k40/60, merchant Proveedor corregido, fechaOct10 genera exactamenteOct10/Nov10; total710k. Pagar90k parcial registra merchant correcto y traslada10k; disponible727k→637k, pendienteOctober610k. Captura `round-1-payment-320.jpg`.
- A09: aviso Tele500k, cerrar conserva pendiente500k; desactivar recordatorios muestra Desactivado y retira aviso. Recordatorio de Factura saldada ignoró cambio5d/10:30 aunque mostró éxito (R05, corregido en tanda2; requiere repetir UI).
- A12: backup demo→contraseña incorrecta muestra error sin cerrar/reemplazar; correcta cabal-demo+confirmación restaura e informa copia previa; recuperar estado anterior funciona. Son operaciones en memoria, no archivo/cifrado real. Selector de prueba esperaba nombre corto inexistente; reintentado con etiqueta observada, no defecto de producto.
- A11: Wallet pendiente ambiguo185k requiere cuenta, guardar vacío muestra error. Elegir crédito registra y quita propuesta. Segunda95k cancelar conserva, descartar quita con aviso sin modificar saldos. Captura Android no probada.
- A10: cinco vistas Reportes recorridas390px; octubre ingresos4.2m,gasto neto1.973m,neto2.227m; Evolución agosto gasto neto−1.3m/devolución1.3m; Resumen agosto neto5.5m; filtros crédito+hogar dan0 y navegación al historial conserva agosto+ambos filtros. `round-2-report-390.jpg`. Sin overflow horizontal (scrollWidth390).
- A13: detalle de pago320×740 scrollWidth320; navegación inferior dentro del viewport. Formularios recordatorios y backup utilizables320px. Medición de foco inicial modal Cerrar, fondo excluido del árbol AX. No equivale a TalkBack/teclado virtual.

## Hallazgos y correcciones

| ID | Gravedad | Hallazgo confirmado | Corrección / evidencia |
|---|---|---|---|
| R01 | P1 | Plantilla dividida pierde categorías en previsión/pago/carry | Copiar división y repartir pagos/restos; RED→GREEN, prueba propia y revisión0 |
| R02 | P1 | Sin categoría de cuota recalcula con pesos incompletos (49vs33 total) | Filtrar categorías tras distribución completa; RED→GREEN |
| R03 | P1 | Editar próxima fecha duplica proyecciones; formulario enseña cursor interno | Reconciliar calendario y mostrar primer editable; navegador790→970 antes,710 correcto después |
| R04 | P2 | Comercio editado no llega al pendiente/pago | Actualizar proyección editable con comercio; navegador Proveedor corregido |
| R05 | P2 | Editar recordatorio resuelto ignora el seleccionado | saveReminder aplica al seleccionado y futuros pendientes; RED→GREEN tanda2, recheck UI pendiente |
| R06 | P1 | Editar importe dividido conserva pesos viejos: deuda200k/previsión100k o fantasma50k pagado | editObligation transaccional escala pesos y plantilla, conserva historial, evita fechas duplicadas; RED→GREEN tanda2, recheck UI pendiente |

### Tandas

- Base0:48/48; revisión independiente `/root/review_round0`: tresP1/unoP2, probes propios y capturas. No navegó personalmente.
- Corrección1:R01–R04;52/52; rechecks UI de calendario/comercio/partial y móvil. Nueva revisión `/root/review_round1` confirma R05/R06,52/52 y probes de handler reales. Captura móvil inspeccionada, sin control propio navegador.
- Corrección2:R05/R06;54/54; `round-2-red.tap` y `round-2-tests.tap`. UI y nueva revisión en curso.

## Rechecks posteriores y tanda 3

- R05/R06 navegador390px: plantilla100k dividida40/60 → Editar pendiente50k/Oct10/aplicar siguientes → pago50k → detallePagado/porpagar0; recordatorio del saldado5d10:30 ahora visible, `round-2-reminder-paid.jpg`. Inicio/reporte pendiente610k (solo tele500k+bici110k), sin50k fantasma.
- R07 P2 independiente: cambiar solo importe desdeFeb28 de plan Jan31/Feb28/Mar31 recalculabaMar28; mismo problema cursor plantillaDec31→Dec30 desdeNov30. Corrección3 conserva fechas y ancla si no se cambió fecha. RED→GREEN55/55. Navegador tras recargar: plan300k Jan31/Feb28/Mar31; editarFeb a120k/aplicar siguientes mantieneMar31, total340k. `round-3-month-end.jpg` + AX observado. La captura muestra parte desplazable; no se infiere de ella que todas las filas estén simultáneamente visibles.
- A05 navegador: Reserva4.55m incluida en disponible suma727k→5.277m; patrimonio permanece−1.178m después de crear plan adicional340k (antes y después del toggle). Conciliar a4.5m previsualiza−50k, guarda ajuste en historial; archivar conserva saldo/historial y retira conciliación, reactivar con confirmación recupera acceso. Sin operaciones bancarias reales.
- A06/A13: Usar Mi café proponeEfectivo/Café del Patio/Alimentación e importe vacío; Shift+Tab desdeCerrar va aGuardar, Tab desdeGuardar vuelveCerrar, fondo studio/device inert; Escape cierra y devuelve focoUsar sin registrar. Pausar Electricidad cambia estadoPausada, muestraReactivar.
- Los selectores por rol fallaron también para `summary` Plan completo. SelectorDOM de summary abre calendario correctamente; incidencia del mecanismo de prueba, no bloqueo de uso.
- Revisión2 `review-2.md`: confirma R01–R06; descubreR07. Suite propia55/55 fue ejecutada tras corrección3 y el informe distingue esa secuencia. Revisión3 posterior solicitada, con control independiente del navegador autorizado al agente.

## Comprobaciones de cierre en navegador

- A02: ingreso ficticio10k aCuenta diaria cambia430k y disponible5.237m (+10k). Transferencia5kbank→cash deja425k/312k, disponible5.237m y patrimonio−1.218m intactos. Al elegir origenbank, destino excluyebank: no se forzó una opción inexistente; rechazo de iguales también cubierto por modelo.
- A11: Detectar compras sin permiso abre escena de autorización y conserva toggleapagado. Conceder acceso ficticio deja detecciónapagada; activarla y activarauto permite «Compra reconocida registrada automáticamente (ficticia)». Comercio nuevo queda pendiente. No hubo permiso Android real. `.check()` informó que el toggle no quedó marcado al abrir autorización: comportamiento esperado de permiso separado, no defecto.
- A12: crear backup de sesión con contraseña ficticia y guardar destino simulado; cancelar Tele500k baja pendientes790k→290k sin pago. Restaurar copia de sesión recupera790k, disponible5.237m y calendario completo. `round-3-backup-restored.jpg`. La recuperación del estado previo de restauración ya fue recorrida con backupdemo. Persistencia de pago/carry y revisión obsoleta se comprobaron en modelo, no en concurrencia real de pestañas.
- A13 final:320×740, scrollWidth320, navtop663/bottom740/left0/right320, controles sin desborde horizontal.1280×900, scrollWidth1280, navtop773/bottom854 dentro del dispositivo. Capturas `final-home-320.jpg` / `final-home-1280.jpg`, inspeccionadas visualmente. Viewport390×844 usado para reportes, formularios y R07. Override restablecido al terminar; tab marcada como entregable.
- Navegador: registro capturado de consola warn/error devuelve[] en cierre (no certifica ausencia de errores previos no capturados).

## Cobertura y límites por criterio

| Criterio | Evidencia actual | Límite / pendiente específico |
|---|---|---|
| A01 | Primera vez, cuenta desde borrador, validación y guardado UI | No todas las variantes del onboarding |
| A02 | Gasto/ingreso/transferencia/división UI; canales y validaciones modelo | No cada canal ni montos máximos en UI |
| A03 | Editar/clonar cancelado/eliminar/deshacer/retorno filtrado UI | No todas las combinaciones de filtros |
| A04 | Crédito101/3 y fecha futura UI; resto/finmes/pago/devolución modelo | Pago y devolución de tarjeta no repetidos mediante formulario en esta pasada |
| A05 | Cuenta nueva, ahorrodisponible, conciliación/archivo/reactivación UI | Edición de alias/cierre de tarjeta no recorrida UI |
| A06 | Manual cancelar, edición programación, pausa, proyección sin duplicados UI/modelo | Crear plantilla desde gasto y omitir/reanudar conflictos no repetidos UI |
| A07 | Nuevo plan, otro medio, pago parcial/traslado UI | Última cuota parcial comprobada en modelo |
| A08 | Editar importe dividido/pagar/saldar UI; factura variable/histórico modelo | Importe final diferente y todas las frecuencias no agotadas UI |
| A09 | Editar/desactivar/aviso/cerrar y recordatorio saldado UI | Entrega del sistema y appcerrada requierenAndroid |
| A10 | Cinco vistas, negativos, filtros, período futuro, presupuestos UI/modelo | Sin auditoría exhaustiva de todas las series/rangos |
| A11 | Permiso separado, auto reconocido, nuevo, ambiguo, cancelar/descartar UI; duplicados modelo | Captura real/lifecycle requiereAndroid |
| A12 | Contraseñaerror, restaurardemo/sesión, copia previa y pendientes UI; snapshot/carry/revisión modelo | No archivos/cifrado/SAF ni concurrencia real |
| A13 |320/390/1280, focoTab/Escape/inert y capturas UI | No teclado virtual/TalkBack/zoom/todos los dispositivos |

## Dictamen de cierre

Tres tandas de corrección, cuatro evaluaciones independientes (base0 y posteriores1–3). Se resuelven siete hallazgos confirmados: cuatroP1 (R01/R02/R03/R06), tresP2 (R04/R05/R07). Sin P0 ni defectos relevantes nuevos confirmados en los casos examinados después de corrección3. La revisión independiente final no exige tanda4. Esto habilita seguir probando el prototipo dentro de la cobertura descrita; **no declara validación exhaustiva de A01–A13 ni aprobación de llevar cambios aFlutter**.

Prueba final fresca: `node prototype/cabal/model.test.js`, **55/55**, cero fallos; `final-tests.tap`. Sintaxis `node --check` de `model.js` y `app.js`, salida0. Código final comparado contra copia inicial en `changes.diff`; cambios de producto solo `app.js`, `model.js` y `model.test.js`. Sin cambios Flutter, APK ni estilos/HTML/README en esta auditoría.

Quedan las brechas HTML ya documentadas: edición/recurrencia avanzada de presupuestos y menú flotante equivalente enMovimientos (actualmente botónNuevo); no se agregaron durante esta auditoría. SMS por ejemplos y otras notificaciones continúan diferidos. Android, cifrado, permisos reales y entrega de recordatorios requieren otra fase con dispositivo. Las limitaciones de cobertura de la tabla se mantienen explícitas; no son fallos financieros reproducidos pendientes de corrección.

### Observación visual menor

La revisión final de capturas observa que el FAB se superpone parcialmente al importe de una fila en una posición de scroll a320px. La fila es desplazable; no se confirmó bloqueo permanente ni pérdida de acceso. Se conserva como observación de usabilidad para prueba táctil, sin clasificarla como fallo funcional relevante resuelto. Revisión independiente: addendum de `review-3.md`.
