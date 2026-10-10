# Plan de mejoras UX · v1.2 · 2026-10-10

Worktree: `/home/ulises/Escritorio/Tests/Wallet-ux` · rama `feature/mejoras-ux` · base `7b9ac8e` (master analizado). Línea base: `flutter analyze` sin avisos, 370 pruebas pasan.

Propuestas elegidas: P01, P02, P03, P04, P07, P09, P10, P11, P12, P13, P14, P15, P16, P17.

## Reglas comunes

- Seguir `AGENTS.md`: sin subtítulos ni textos explicativos nuevos; `AppFab`; widgets como clases; sin `Map<String, dynamic>` nuevos; sin APK; sin commits.
- Conservar lógica de negocio, contratos de datos, formato guardado y backup. No cambiar servicios salvo lo indicado.
- Solo editar los archivos asignados. Pruebas nuevas en archivos nuevos dentro del área propia. Si una prueba existente ajena se rompe, informar sin tocarla.
- Errores visibles: siempre `userMessage(error)` o `showError`; nunca `'$error'`.

## Responsables

- **H1** (Haiku): componentes compartidos, Inicio, Cuentas, Presupuestos, Catálogo, Plantillas, Reportes, Configuración, Onboarding.
- **H2** (Haiku): Movimientos, formulario, detalle, devolución/conciliación, Pagos, Bandeja, alta de cuenta, `MoneyText`.

## Tareas

| ID | Prop. | Resp. | Archivos | Depende |
|----|-------|-------|----------|---------|
| T01 | P01 base | H1 | `lib/core/errors/user_message.dart` (nuevo), `lib/shared/widgets/app_snack.dart`, `lib/shared/widgets/async_value_view.dart` | — |
| T02 | P01 | H1 | dashboard, accounts_screen, budgets_screen, catalog_screen, templates_screen, reports_screen, settings_screen, onboarding_screen | T01 |
| T03 | P01 | H2 | transactions_screen, movement_detail, transaction_form_screen, transaction_form_notifier, payments_screen, payment_detail_screen, pending_inbox_screen | T01 |
| T04 | P03 | H1 | `accounts_screen.dart` | — |
| T05 | P04 | H1 | `catalog_screen.dart` | — |
| T06 | P10 | H1 | `budgets_screen.dart`, prueba de servicio nueva | — |
| T07 | P11 | H1 | budgets_screen, templates_screen, catalog_screen | — |
| T08 | P13 | H1 | `trend_chart.dart` | — |
| T09 | P15 | H1 | `reports_screen.dart`, `trend_chart.dart` | — |
| T10 | P16 | H1 | `wallet_settings_screen.dart`, `settings_screen.dart` | — |
| T11 | P17 | H1 | onboarding_screen, wallet_settings_screen | — |
| T12 | P14 | H1 | accounts_screen, templates_screen | T01 |
| T13 | P02 | H2 | `ledger_actions.dart` | T01 |
| T14 | P07 | H2 | transaction_form_state / notifier / fields | — |
| T15 | P09 | H2 | `transactions_screen.dart` | — |
| T16 | P12 | H2 | `money_text.dart` (tras T01), movement_detail, transactions_screen | — |
| T17 | P17 | H2 | pending_inbox_screen, candidate_review_dialog, create_account_dialog | — |
| T18 | P14 | H2 | `payment_detail_screen.dart` | T01 |

Secuencia: T01 (H1) → H1 y H2 en paralelo con sus tareas → autorrevisión → revisión cruzada en lectura → revisión de Opus → correcciones.

## Criterios de aceptación

**P01 · T01–T03**
- C01.1 `userMessage(Object)`: `AppException` → `message`; `StateError`/`FormatException`/`ArgumentError` → su mensaje sin prefijo de tipo; otros → «No se pudo completar la operación.». Con prueba unitaria.
- C01.2 `showError` usa `userMessage`.
- C01.3 `AsyncValueView` en error muestra «No se pudo cargar.» sin detalle técnico y, si recibe `onRetry`, un botón «Reintentar». Las pantallas con proveedor accesible lo pasan (`ref.invalidate`).
- C01.4 No queda en `lib/` (fuera de developer_tools y `technicalDetail`) ningún texto visible con `'$error'`, `'$e'` ni `${...error}`. Se comprueba con grep.
- C01.5 Inicio: «Pendiente del mes» y «Patrimonio total» distinguen carga (indicador) de error (acción «Reintentar»); ya no muestran el mismo «—» para ambos.

**P02 · T13**
- C02.1 Devolución valida el importe en el diálogo (requerido, > 0); conciliación (requerido, ≥ 0: un saldo real 0 es válido). Error en el campo. *(v1.1: corregido, v1 impedía conciliar a 0)*
- C02.2 La operación se ejecuta dentro del diálogo; si falla, el error se muestra en el diálogo y se conservan los datos; se cierra solo al guardar. Botón deshabilitado mientras guarda.
- C02.3 Pruebas de widget: importe inválido deja el diálogo abierto; error del servicio (devolución mayor que la compra) deja el diálogo abierto con mensaje.

**P03 · T04**
- C03.1 Tarjetas y detalle de Cuentas no muestran `initialBalanceMinor` como saldo mientras los saldos cargan o fallan: muestran un marcador de carga o error.
- C03.2 Prueba de widget con saldos en carga: el saldo inicial no aparece.

**P04 · T05**
- C04.1 «Eliminar alias» pide confirmación («Eliminar» / «Cancelar»); cancelar no modifica nada.

**P07 · T14**
- C07.1 Con «Dividir entre categorías» activo, se muestra «Restante <importe>» = importe − suma de divisiones; si es negativo, «Excedente <importe>» con color de error. Se actualiza al escribir.
- C07.2 El cálculo vive en el estado (no en el widget), con prueba unitaria.

**P09 · T15**
- C09.1 Cada filtro activo (cuenta, comercio, categoría, tipo, período, sin categoría, sin comercio) se muestra como chip con nombre legible; borrar un chip quita solo ese filtro. Reemplaza el texto «Sin categoría. Sin comercio asociado.».
- C09.2 Al cambiar filtros o búsqueda se mantienen las filas anteriores con indicador de carga, sin vaciar la lista.
- C09.3 Prueba de widget: entrada con `account=<id>` muestra el chip con el nombre de la cuenta; borrarlo limpia el filtro.

**P10 · T06**
- C10.1 Crear presupuesto usa el mes visible; el título del diálogo muestra ese mes.
- C10.2 Prueba de servicio en memoria: crear con repetición en un mes pasado y luego `ensureCurrentMonth` crea el mes actual sin rellenar meses intermedios.

**P11 · T07**
- C11.1 Presupuestos, Plantillas y Catálogo tienen padding inferior ≥ 88 en sus listas.

**P12 · T16**
- C12.1 A 360×640 y `textScaler` 2.0, un importe de 1.000.000.000 ₲ se ve completo (escala reducida, sin «…» ni desbordes) en el importe principal del detalle y en la fila de Movimientos.
- C12.2 Prueba de widget que lo comprueba sin excepciones de desborde, montando la fila real de Movimientos (no solo `MoneyText` aislado). *(v1.1)* El comportamiento por defecto de `MoneyText` en otras pantallas no cambia salvo por opción explícita.

**P13 · T08**
- C13.1 El gráfico tiene una etiqueta semántica con el nombre de cada serie y su valor por mes. La leyenda y el tooltip usan los mismos nombres de serie.

**P14 · T12, T18**
- C14.1 Aviso breve al terminar con éxito: confirmar pago, cancelar pendiente, editar pendiente, archivar/reactivar/editar cuenta, pausar/reanudar plantilla, omitir vencimiento. Los textos siguen el estilo existente («Pago registrado.»).

**P15 · T09**
- C15.1 Cifras netas rotuladas «Gastos netos» y brutas «Gasto bruto» en reportes y gráfico.
- C15.2 Plurales correctos («1 compra», «2 compras»).
- C15.3 Porcentajes con formato local (coma decimal).

**P16 · T10**
- C16.1 El interruptor de registro automático está deshabilitado mientras la detección de Wallet está apagada.
- C16.2 La contraseña al restaurar no muestra la ayuda de creación.

**P17 · T11, T17**
- C17.1 Se eliminan los textos explicativos: onboarding (párrafos, subtítulo del interruptor, «Para registrar movimientos…»), párrafo y subtítulos de Wallet, oración del vacío de la bandeja (queda una frase corta), «Recordaremos el comercio…» y la ayuda de alias del alta de cuenta. Se conservan títulos, etiquetas y datos.

**Globales**
- G1 `flutter analyze` sin avisos; `flutter test` completo pasa.
- G2 Ningún archivo de pantalla supera 600 líneas sin aviso.

## Comportamientos que se conservan

Cálculos financieros, validaciones de servicio, deshacer existentes, navegación y rutas, formato de importes por defecto, guarda «¿Descartar cambios?» del formulario de movimientos, estados de reconocimiento de la bandeja.

## Limitaciones

Sin APK ni ejecución en dispositivo (AGENTS.md). Pendiente de prueba manual: texto ampliado real, TalkBack, teclado y botón Atrás de Android, barra inferior al entrar a Movimientos desde Cuentas.

## Decisiones durante la implementación

- v1.1: C02.1 conciliación ≥ 0; C12.2 prueba sobre la fila real; se autoriza actualizar `transaction_form_test.dart` y `catalog_screen_test.dart` porque el cambio de texto/flujo es el diseño elegido (P01, P04).

## Estado

- Exploradores: A, B, C (Haiku 5.5) terminados.
- T01: hecho (H1). `userMessage`, `showError` y `AsyncValueView(onRetry:)`; prueba en `test/core/errors/`.
- T02: hecho (H1). Errores visibles con `userMessage` en Inicio, Cuentas, Presupuestos, Catálogo, Plantillas, Reportes, Configuración; Reintentar en Inicio, Cuentas, Catálogo, Plantillas.
- T04: hecho (H1). Saldo inicial no se muestra mientras carga o falla; prueba en `test/features/accounts/account_balance_state_test.dart`.
- T05: hecho (H1). Confirmación al eliminar alias; prueba existente de Catálogo adaptada al diálogo.
- T06: hecho (H1). Crear usa el mes visible; prueba en `test/features/budgets/budget_repeat_current_month_test.dart`.
- T07: hecho (H1). Padding inferior 88 en Presupuestos, Plantillas y Catálogo.
- T08: hecho (H1). Etiqueta semántica del gráfico; leyenda y tooltip con los mismos nombres.
- T09: hecho (H1). «Gastos netos», plurales y porcentajes con coma.
- T10: hecho (H1). Registro automático deshabilitado con detección apagada; ayuda de contraseña solo al crear backup.
- T11: hecho (H1). Textos explicativos retirados de Onboarding y Wallet.
- T12: hecho (H1). Avisos al editar/archivar/reactivar cuenta, pausar plantilla y omitir vencimiento. Reanudar plantilla no está en estas pantallas.
- T03: hecho (H2). Errores con `userMessage` en Movimientos, detalle, formulario, pagos, detalle de pago y Bandeja; Reintentar en Movimientos y Bandeja.
- T13: hecho (H2). Devolución y conciliación son diálogos propios: validan importe, guardan dentro y muestran el error sin cerrar; prueba en `test/features/transactions/ledger_dialog_errors_test.dart`.
- T14: hecho (H2). «Restante» / «Excedente» calculado en `TransactionFormState.splitRemainingMinor`; prueba en `test/features/transactions/split_remaining_test.dart`.
- T15: hecho (H2). Chips de filtros activos con nombre, quitables de a uno; la lista anterior se mantiene durante la carga; prueba en `test/features/transactions/transactions_filter_chips_test.dart`.
- T16: hecho (H2). `MoneyText(fitWidth: true)` opt-in en el detalle y en Movimientos; prueba en `test/shared/widgets/money_text_fit_test.dart`.
- T17: hecho (H2). Textos explicativos retirados de la Bandeja, la revisión de candidatos y el alta de cuenta.
- T18: hecho (H2). Avisos «Pago registrado.», «Pendiente cancelado.», «Pendiente actualizado.».
- H2 ronda 1 Opus: R1 conciliación admite saldo 0 (prueba en `ledger_dialog_errors_test.dart`); R2 `transaction_form_test.dart` espera el mensaje genérico; R3 importe de la fila acotado al 40 % del ancho (prueba en `test/features/transactions/movement_row_amount_test.dart`). Detalle de movimiento sin prueba de pantalla completa (ver informe).
- H2 ronda 2 Opus: W1 Reintentar en Pagos, detalle de pago y formulario (`retryLoad` en el notifier); W2 `PopScope(canPop: !_saving)` en devolución y conciliación (verificado por código, sin prueba discriminante); W3 `FittedBox` alineado al inicio (prueba en `money_text_fit_test.dart`).
- H1 ronda 2 Opus: cuentas sin fila de saldo (archivadas) muestran «—» en vez del saldo inicial; pruebas de detalle y archivada; prueba del interruptor de Wallet.
- H2 ronda adicional: el formulario muestra el `loadError` legible con «Reintentar».

## Revisión de Opus · aprobada

- Integración: `flutter analyze` sin avisos; `flutter test` 391 pasan (370 previas + 21 nuevas).
- T01–T18 aprobadas. Verificado solo por código: C02.2 bloqueo de cierre durante el guardado, C14 avisos de éxito, C15.3, C09.2, C12.1 en el detalle.
- Pendiente de prueba manual en Android: texto ampliado real, TalkBack (gráfico, «Saldo no disponible»), botón Atrás en devolución/conciliación, barra inferior al ir de Cuentas a Movimientos.
- Fuera de alcance, anotado: `scheduled_template_service.dart:291` guarda `'$error'` como motivo pendiente (servicio, no se tocó). Tarjeta archivada ya no muestra fechas de ciclo.

## v1.2 · Pendientes elegidos: P20, P21, P22 (responsable H2)

| ID | Prop. | Archivos | Criterios |
|----|-------|----------|-----------|
| T19 | P20 | `lib/features/templates/scheduled_template_service.dart`, prueba de servicio nueva | C20.1 el catch de `processDue` guarda `userMessage(error)`; StateError/FormatException/AppException conservan su texto actual. C20.2 prueba en memoria: un error inesperado deja `pendingReason` = «No se pudo completar la operación.». C20.3 `templates_screen_test.dart` sigue pasando sin cambios. |
| T20 | P21 | `transactions_screen.dart`, nuevos `movement_tile.dart` y `active_filter_chips.dart` | C21.1 `MovementTile` y `ActiveFilterChips` (con `FilterKind` y etiquetas de tipo) en archivos propios; sin cambios de comportamiento ni de textos. C21.2 la pantalla ≤ 420 líneas. C21.3 pasan las pruebas de transactions sin modificarlas (salvo imports si fuese imprescindible, justificado). |
| T21 | P22 | `transaction_form_screen.dart`, nuevos `transaction_type_selector.dart` y `amount_field.dart` | C22.1 `_typeSelector` y `_amountField` pasan a clases de widget con parámetros explícitos (estado/tipo, controller, callbacks, validador, autofocus); mismo árbol visible, claves y comportamiento (selector bloqueado al editar). C22.2 la pantalla ≤ 500 líneas. C22.3 pasan las pruebas del formulario sin modificarlas. |

Globales: G1 (`flutter analyze` sin avisos, suite completa pasa). Sin cambios de lógica ni de textos en T20–T21.
- T19 (v1.2, H2): hecho. `processDue` guarda `userMessage(error)` en `pendingReason`; prueba `test/features/templates/scheduled_unexpected_error_test.dart` (error inesperado por dato malformado → «No se pudo completar la operación.»).
- T20 (v1.2, H2): hecho. `MovementTile` en `movement_tile.dart` y `ActiveFilterChips`/`FilterKind`/`filterTypeLabels` en `active_filter_chips.dart`; `transactions_screen.dart` 385 líneas.
- T21 (v1.2, H2): hecho. `TransactionTypeSelector` en `transaction_type_selector.dart` y `AmountField` en `amount_field.dart`; `transaction_form_screen.dart` 489 líneas.

## Revisión de Opus v1.2 · aprobada

- T19–T21 aprobadas: diff del servicio limitado al catch; extracciones mecánicas sin cambios en pruebas existentes. Pantallas: transactions_screen 385, transaction_form_screen 489.
- `flutter analyze` sin avisos; `flutter test` 392 pasan.
