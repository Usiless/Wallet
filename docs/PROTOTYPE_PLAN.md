# Cabal: inventario, navegación y flujos del prototipo

> Plan histórico: para decisiones y presentación vigentes tras la revisión aceptada el 2026-10-07, consultar [PRODUCT_BASELINE](PRODUCT_BASELINE.md#prototipo-revisado-y-aceptado--2026-10-07) y [PROTOTYPE_STATUS](PROTOTYPE_STATUS.md). Las alternativas incompatibles de este plan no amplían el alcance aprobado.

Fecha original: 2026-10-06. Inventario y plan de referencia usados para construir el prototipo navegable.

**Plan de referencia histórico de diseño.** Conserva inventario y alternativas del momento de construcción, no una segunda fuente vigente de estado/prioridad. Los IDs F01–F23 siguen estables. Algunas brechas listadas aquí ya cambiaron en HTML; el contraste actual está en [ROADMAP](ROADMAP.md) y los límites específicos en [PROTOTYPE_STATUS](PROTOTYPE_STATUS.md). No implementar sus propuestas a partir de esta lista.

**Estado registrado al construir:** el HTML está construido en `prototype/cabal/` y el usuario aceptó la versión posterior a la ronda 1 de evaluación. Consultar [PROTOTYPE_STATUS.md](PROTOTYPE_STATUS.md) para cobertura F01–F23, simulaciones, diferencias y pendientes. Este plan conserva requisitos y alternativas de referencia; no certifica que todas sus variantes estén implementadas o verificadas.

Este documento no aprueba cambios de producto ni modifica Flutter. La fuente de decisiones asentadas es [PRODUCT_BASELINE.md](PRODUCT_BASELINE.md). «Existente» significa encontrado en el código; no certifica su funcionamiento integral en un teléfono. El prototipo usa únicamente datos ficticios y simula las operaciones del sistema.

## 1. Inventario contrastado con el código

| Área | Funciones y acciones existentes | Acceso actual y evidencia |
| --- | --- | --- |
| Primera apertura | Tres pasos: privacidad y PYG, cuentas propias opcionales, bloqueo opcional. Agregar/quitar cuentas del borrador y terminar sin cuentas. | `/onboarding`; [onboarding_screen.dart](../lib/features/onboarding/presentation/onboarding_screen.dart). |
| Bloqueo | Biometría o credencial del dispositivo, reintento tras cancelar/fallar. El gate considera un regreso después de más de diez segundos fuera de la app. | Antes del contenido; [app_lock_gate.dart](../lib/shared/widgets/app_lock_gate.dart). |
| Inicio | Patrimonio total, cuentas activas con saldo/deuda, últimos cinco movimientos, gasto/ingreso/transferencia, bandeja con contador, aviso de programados pendientes. Tocar cuenta abre acciones; crédito ofrece pagar primero. | `/dashboard`; [dashboard_screen.dart](../lib/features/dashboard/presentation/dashboard_screen.dart). |
| Cuentas | Bancaria, efectivo, ahorro y crédito; crear, editar nombre/alias y perfil crediticio, archivar/reactivar, ver historial y conciliar. Ahorro permite incluir/excluir del dinero disponible. Tipo, moneda y saldo inicial quedan fijos al editar. | Más y acciones de Inicio → `/accounts`; [accounts_screen.dart](../lib/features/accounts/presentation/accounts_screen.dart), [create_account_dialog.dart](../lib/features/accounts/presentation/create_account_dialog.dart). |
| Tarjetas | Deuda registrada, límite, crédito disponible, próximo cierre, vencimiento estimado y mínimo si existe en el perfil. Pagar conserva la tarjeta de destino desde la que se inició. | Más → `/cards` y pago desde Inicio; [credit_cards_screen.dart](../lib/features/credit_cards/presentation/credit_cards_screen.dart). |
| Registro manual | Gasto, ingreso y transferencia; importe entero PYG, cuentas, categoría opcional o divisiones, comercio/pagador, fecha, canal, nota, cuotas para gasto de crédito. Crear categoría en el formulario; autocompletar comercios y sugerir su categoría aprendida. Guardar y crear otro; guardar también como plantilla. | `/transactions/new`; [transaction_form_screen.dart](../lib/features/transactions/presentation/transaction_form_screen.dart), [payment_channel_policy.dart](../lib/features/transactions/domain/payment_channel_policy.dart). |
| Historial | Búsqueda literal por comercio/nota; filtros combinables por cuenta, comercio, categoría, tipo y período; cargar otros 50; editar, clonar, eliminar/deshacer y devolver un gasto. Historial contextual desde cuenta, comercio y reportes. | `/transactions`; [transactions_screen.dart](../lib/features/transactions/presentation/transactions_screen.dart). No hay una pantalla dedicada de detalle del movimiento. |
| Correcciones | Editar gasto/ingreso/transferencia sin cambiar tipo/moneda ni identidad/fuente. Devolución vinculada a compra con fecha, importe y nota; conciliación con saldo/deuda real, signo y motivo. Ajustes y devoluciones se corrigen eliminando y registrando otro. | Formularios y diálogos; [ledger_actions.dart](../lib/features/transactions/presentation/ledger_actions.dart), [ledger_service.dart](../lib/features/transactions/data/ledger_service.dart). |
| Plantillas | Crear sin registrar movimiento, usar con fecha actual, editar, eliminar/deshacer. Importe manual opcional; guarda cuentas, comercio, categorías/divisiones, canal, nota y cuotas. Selector en Nuevo movimiento prioriza el tipo actual y permite administrar. | Más → `/templates`; [templates_screen.dart](../lib/features/templates/templates_screen.dart), formulario compartido. |
| Programados | Gastos fijos mensuales/anuales, sin cuotas; opt-in, próxima fecha, procesar al abrir/volver, recuperar atrasos, marcar Programado. Pendientes por conflictos/coincidencias, editar, pausar y omitir un vencimiento. Reactivar se hace editando la programación. | Más → `/templates?scheduled=true`, aviso en Inicio; [scheduled_template_service.dart](../lib/features/templates/scheduled_template_service.dart). |
| Presupuestos | Crear general o por categoría para el mes actual; objetivo, consumido, restante, progreso y umbral alcanzado. Cálculo contempla cuotas, devoluciones y cambios del historial. | Pestaña `/budgets`; [budgets_screen.dart](../lib/features/budgets/presentation/budgets_screen.dart), [budget_service.dart](../lib/features/budgets/domain/budget_service.dart). La pantalla no ofrece cambio de mes, edición ni eliminación. |
| Reportes | Resumen, Evolución, Categorías, Comercios y Cuentas. Mes anterior/siguiente o rango personalizado; filtros de cuenta/categoría con archivadas; compras completas o cuotas del período; comparación, gasto bruto, devoluciones y neto; desglose abre historial contextual. | Más → `/reports`; [reports_screen.dart](../lib/features/reports/presentation/reports_screen.dart), [report_service.dart](../lib/features/reports/data/report_service.dart). |
| Compras detectadas | Bandeja, actualizar, estados de cuenta/comercio reconocido, nuevo o por asociar; revisar importe/comercio/categoría/cuenta juntos, crear cuenta, registrar o descartar. Confirmar aprende asociaciones y categoría del comercio. | Inicio → `/inbox`; [pending_inbox_screen.dart](../lib/features/pending_inbox/presentation/pending_inbox_screen.dart), [candidate_review_dialog.dart](../lib/features/pending_inbox/presentation/candidate_review_dialog.dart). |
| Google Wallet | Detección y registro automático separados, apagados inicialmente; acceso a notificaciones de Android. Automatizar solo importe válido, cuenta activa única y comercio reconocido único; casos dudosos quedan pendientes. No vincula la cuenta de Google. | Configuración → `/wallet-settings`; [wallet_settings_screen.dart](../lib/features/settings/presentation/wallet_settings_screen.dart), [notification_ingestion_service.dart](../lib/core/notifications/notification_ingestion_service.dart). |
| Catálogos y asociaciones | Comercios y categorías: crear, renombrar, archivar/reactivar; categoría de gasto/ingreso/ambos. Alias de cuenta/comercio: agregar, reasignar y eliminar; conflictos de cuenta visibles. Comercio abre historial. | Más → `/catalog`; [catalog_screen.dart](../lib/features/catalog/catalog_screen.dart). |
| Archivos | CSV: guardar plantilla, elegir archivo UTF-8, detectar/cambiar separador, vista previa con válidas/inválidas/duplicadas/avisos, importar válidas y crear categorías desconocidas. Exportar CSV y JSON. Reversión de lote existe en servicio, sin acceso en pantalla. | Más o Historial → `/imports`; `csv_import_screen.dart` y `csv_import_service.dart` (retirados el 2026-10-07 y 2026-10-10). No hay importación JSON ni mapeador visual de columnas. |
| Backup y seguridad | Crear backup cifrado con contraseña y selector de destino; elegir backup, revisar resumen, contraseña, validar, copia previa, reemplazo y progreso. Bloqueo configurable. Cifrado local automático de base y cola. | Configuración; [settings_screen.dart](../lib/features/settings/presentation/settings_screen.dart), [backup_service.dart](../lib/core/backup/backup_service.dart), [encrypted_storage.dart](../lib/core/database/encrypted_storage.dart). |
| Información | Mensaje sin servidor/telemetría y licencias de terceros. Política de privacidad documentada; no hay una pantalla completa de privacidad en Configuración. | Configuración y [PRIVACY.md](PRIVACY.md). |
| Desarrollo | Simulador de notificaciones marcado PRUEBA, SMS Sudameris vía notificaciones de Google Messages, diagnóstico consultar/exportar/borrar e inspección de notificaciones activas con creación de propuesta y repetición de prueba tras eliminar movimiento. | `/developer-tools` y sus tres subrutas; [DEVELOPER_TOOLS.md](DEVELOPER_TOOLS.md), [feature_flags.dart](../lib/core/config/feature_flags.dart). Bloqueado por bandera y siempre en release/profile. |

### Diferencias que el diseño debe hacer visibles

- La navegación actual es **Inicio · Movimientos · Presupuestos · Más**. Cuentas, tarjetas y reportes están en Más; el router distingue páginas principales de secundarias. Fuente: [router.dart](../lib/app/router.dart).
- La base pide validar navegación mensual de presupuestos, pero la UI usa `DateTime.now()` sin selector. Añadirlo sería una propuesta de interfaz apoyada por el servicio, no una función visible existente.
- El texto de CSV promete revertir el lote, pero no expone la acción. El prototipo puede proponer el acceso con etiqueta de cambio pendiente; no debe suponer reversión atómica ni deshacer todos los catálogos creados.
- Perfil de tarjeta puede mostrar un mínimo si está almacenado; el formulario visible de cuenta no permite introducirlo. No presentar edición del mínimo como ya disponible.
- `IMPLEMENTATION_STATUS.md` es histórico. `ARCHITECTURE.md` y un párrafo de `DEVELOPER_TOOLS.md` conservan afirmaciones antiguas sobre notificaciones/cifrado. Para este diseño prevalecen la base actual y el código: sin avisos del sistema para pendientes, base/cola cifradas.

## 2. Navegación usada en el prototipo aceptado

Recomendación: cinco destinos inferiores **Inicio · Movimientos · Cuentas · Análisis · Más**.

| Destino | Propósito | Contenido y accesos |
| --- | --- | --- |
| Inicio | Entender mi posición y registrar rápido. | Patrimonio total compacto, cuentas activas, tres acciones actuales, últimos movimientos, bandeja con contador y aviso separado de programados pendientes. Acciones de cuenta se conservan. |
| Movimientos | Consultar y corregir. | Historial, búsqueda, filtros visibles al aplicar, nuevo movimiento y acceso a plantillas. Propuesta: tocar fila abre detalle con edición, clonado, devolución y eliminación. |
| Cuentas | Administrar dinero y deuda. | Todas / Bancarias / Efectivo / Ahorro / Crédito; activas y archivadas. Ficha de cuenta con saldo, historial y administración; ficha de crédito añade límite, disponible, fechas y pago. |
| Análisis | Controlar consumo y comprenderlo. | Dos secciones internas: Presupuestos y Reportes. Reportes conserva sus cinco vistas y selector Compras/Cuotas. Presupuestos conserva objetivo, consumido y restante. |
| Más | Gestionar automatización, datos y seguridad. | Plantillas y programados; Google Wallet; comercios/categorías/asociaciones; archivos; backup/restauración; bloqueo; información y licencias. Desarrollo solo en escenario habilitado. |

Alternativa conservadora: mantener los cuatro destinos actuales, añadir Cuentas como acceso destacado en Inicio y Reportes como acceso destacado en Más. Requiere menos cambio de estructura, pero mantiene más recorridos diarios en el menú secundario.

### Mapa propuesto de pantallas

```text
Apertura
├─ Primera vez: privacidad y moneda → cuentas opcionales → seguridad → Inicio
└─ Configurado: desbloqueo si está activo → último contexto / Inicio

Inicio
├─ Gasto / Ingreso / Transferir → formulario → guardar → origen
├─ Cuenta → acciones: [Pagar si crédito] / Ver movimientos / Administrar
├─ Pendientes (contador) → revisar compra → registrar / cancelar
└─ Programados pendientes → programación con conflicto → resolver / pausar / omitir

Movimientos
├─ Buscar / filtrar → resultados → detalle → editar / clonar / devolver / eliminar
├─ Nuevo → formulario → usar plantilla / guardar también como plantilla
└─ Archivos → importar CSV / exportar CSV o JSON

Cuentas
├─ Nueva cuenta → formulario por tipo → ficha
├─ Cuenta → historial / editar / conciliar / archivar o reactivar
└─ Crédito → deuda y límite / fechas / pagar / historial / administración

Análisis
├─ Presupuestos → crear → progreso
└─ Reportes → período + filtros + Compras/Cuotas
   └─ Resumen / Evolución / Categorías / Comercios / Cuentas → historial → detalle

Más
├─ Plantillas → crear / usar / editar / eliminar y deshacer
├─ Programados → activos / pausados / pendientes → editar / pausar / omitir
├─ Google Wallet → detección / permiso Android / registro automático
├─ Catálogos → comercios / categorías / alias de cuentas / alias de comercios
├─ Archivos → CSV / JSON / [propuesta: lotes y reversión]
├─ Respaldo → crear / restaurar
├─ Seguridad → bloqueo
├─ Información → privacidad [propuesta de pantalla] / licencias
└─ Desarrollo [solo habilitado] → simulador / SMS / diagnóstico / inspección
```

Los nombres son de diseño, no nuevas rutas de Flutter. Una ficha de cuenta, un detalle de movimiento, filtros por tipo de cuenta, conservar el último contexto y las secciones de Análisis son propuestas de presentación.

### Reglas de navegación

- Barra inferior en las pantallas raíz. Formularios, detalles y procesos tienen «Volver» al origen que los abrió.
- Conservar búsqueda, filtros, mes y posición al volver de un detalle. Una consulta abierta desde Reportes conserva también su origen y explica qué incluye.
- Gasto/Ingreso/Transferir son tipos del mismo formulario. Pagar tarjeta se inicia desde la tarjeta; devolución desde la compra; conciliación desde la cuenta.
- Formularios largos en pantalla completa; hojas inferiores para acciones o elegir opciones. Confirmaciones breves para consecuencias importantes; avisos con Deshacer donde la función ya existe.
- Propuesta: advertir al abandonar un formulario con cambios. Cancelar una revisión no guarda cambios de la propuesta; crear explícitamente una cuenta es una operación separada.
- Mantener separados el contador de compras por revisar y el número de programados pendientes. Inicio lleva únicamente un punto en su pestaña cuando hay compras pendientes.
- El prototipo tendrá controles externos de escenario y reinicio; no forman parte del producto Cabal.

## 3. Flujos que debe cubrir el prototipo

| ID | Recorrido principal | Variantes y resultado que debe verse |
| --- | --- | --- |
| F01 | Primera apertura → privacidad/PYG → agregar cuentas o continuar sin ellas → seguridad → Inicio. | Atrás conserva borradores; bloqueo cancelado; inicio vacío con acceso a crear cuenta. Sin login ni cuentas bancarias precargadas. |
| F02 | Inicio o Movimientos → Gasto → importe → cuenta → comercio → categoría opcional → guardar → origen. | Comercio existente/nuevo, categoría aprendida, crear categoría, sin categoría, sin cuentas, importe inválido, guardar y crear otro. Cancelar no registra. |
| F03 | Gasto → dividir categorías → importes → guardar. | Mostrar total, asignado y diferencia como propuesta visual. Bloquear si la suma no coincide. La división no reemplaza la categoría aprendida del comercio. |
| F04 | Ingreso → importe → destino → pagador/categoría opcionales → guardar. Transferir → origen distinto del destino → importe → guardar. | Canal compatible con las cuentas; transferencia cambia saldos, sin aumentar ingresos/gastos analíticos. |
| F05 | Gasto de crédito → Más detalles → cuotas → cantidad → guardar. | Explicar total comprometido y consumo por período. Propuesta: vista del calendario de cuotas. Ocultar cuotas en cuenta no crediticia; el total entero debe conservarse. |
| F06 | Cuenta de crédito → Pagar tarjeta → origen + destino fijado + importe → guardar. | Deuda baja y saldo del origen baja; no consume presupuesto. Mostrar destino correcto entre varias tarjetas y saldo a favor cuando corresponda. |
| F07 | Historial → buscar/filtrar → detalle propuesto → editar → guardar → mismo contexto. | Cuenta/comercio/categoría/tipo/período combinados, sin resultados, cargar más, referencia archivada conservada al editar, conflicto por edición simultánea. Tipo/moneda no editables. |
| F08 | Movimiento → clonar → formulario → guardar. Movimiento → eliminar → aviso → deshacer. | Clonar abre un nuevo registro; no afirmar una fecha sin contrastar su regla al construir. Compra con devoluciones exige eliminarlas primero; un deshacer puede estar bloqueado por conflicto. |
| F09 | Compra → Registrar devolución → importe/fecha/nota → registrar. | Parcial, total, varias devoluciones, límite restante, fecha anterior rechazada. Dinero vuelve o deuda baja; consumo se reduce en fecha de devolución y cuotas futuras no se reescriben. |
| F10 | Cuentas → crear por tipo → guardar → editar / archivar / reactivar / historial. | Ahorro cambia inclusión en disponible sin cambiar saldo; archivo preserva historia y excluye selección activa. Alias compartido muestra conflicto explícito. |
| F11 | Cuenta → Conciliar → saldo/deuda real y motivo → guardar ajuste. | Mostrar diferencia antes de guardar como propuesta visual; crédito admite saldo a favor. Saldo cambió mientras se completaba: pedir reintento. Ajuste fuera del gasto y presupuesto. |
| F12 | Nuevo → Usar plantilla → elegir → completar importe si falta → guardar. Administración → crear/editar/eliminar/deshacer. | Priorizar tipo actual sin ocultar otros. Recordar importe opcional. Guardar también como plantilla conserva ambos o ninguno ante fallo. Crear plantilla independiente no crea movimientos/comercios. |
| F13 | Plantilla de gasto fijo → activar programación → mensual/anual + próxima fecha → guardar → volver a app. | Importe fijo obligatorio, sin cuotas; fin de mes/año bisiesto, atrasos, máximo 120 por pasada, reporte de registrados, pendiente por referencia/canal/conflicto, pausar, reactivar editando u omitir. Programado no prueba un cobro real. |
| F14 | Más → Wallet → activar detección → explicación → permiso Android simulado → regresar y activar → compra detectada → bandeja. | Permiso denegado/revocado y detección apagada. Registro automático separado y apagado inicialmente. No capturar notificaciones reales en el prototipo. |
| F15 | Bandeja → Revisar → importe/comercio/categoría/cuenta → Registrar gasto → historial y contador actualizado. | Cuenta única, sin coincidencia, alias ambiguo, comercio nuevo, crear cuenta, cancelar revisión, descartar sin movimiento. No mostrar porcentajes de confianza ni borrar notificación Android. |
| F16 | Wallet automático activo → compra reconocida → registrado; caso nuevo/dudoso → pendiente. | Coincidencia con programado en ventana de tres días exige revisión. Pendiente no afecta saldos. No seleccionar primera tarjeta; categoría solo por preferencia aprendida. |
| F17 | Análisis → Presupuestos → crear general/categoría → gasto/devolución → progreso actualizado. | Vacío, cerca del objetivo, superado, cuotas y devoluciones. Selector mensual propuesto: señalarlo como UI nueva. No inventar edición/eliminación ni presupuestos recurrentes. |
| F18 | Análisis → Reportes → período + cuenta/categoría + Compras/Cuotas → vista → desglose → historial. | Cinco vistas, meses sin datos, rango parcial, archivados, devolución y neto negativo, comparación anterior. En historial por cuotas se muestra compra completa, no importe de la cuota. |
| F19 | Más → Catálogos → crear/renombrar/archivar/reactivar → alias agregar/reasignar/eliminar. | Gasto/ingreso/ambos para categorías; comercio abre historial. Reasignación expresa; no desplazar alias silenciosamente ni modificar movimientos históricos. |
| F20 | Archivos → CSV de ejemplo → previa → separador → importar válidas → resultado. Exportar → CSV o JSON → destino simulado. | UTF-8 inválido, archivo sin filas válidas, duplicados, avisos, categorías nuevas, cancelar, error. Propuesta separada: lista de lotes y revertir; no prometer restauración completa desde CSV/JSON. |
| F21 | Respaldo → Crear → contraseña → destino simulado → éxito. Restaurar → archivo → resumen/reemplazo → contraseña → validación/progreso → resultado. | Contraseña incorrecta, corrupción, esquema incompatible, cancelación y fallo con conservación de datos. Copia previa cifrada; sin obligación de reiniciar. No crear archivos personales reales. |
| F22 | Seguridad → activar bloqueo → autorización del dispositivo simulada → salir/regresar → desbloquear. Información → licencias y privacidad propuesta. | Sin biometría, credencial alternativa, cancelado/fallido y reintento. Diferenciar bloqueo de cifrado local y contraseña de backup. |
| F23 | Escenario de desarrollo habilitado → simulador/SMS/diagnóstico/inspección. | Emisión PRUEBA, original visible, crear propuesta, repetir tras eliminar; diagnóstico exportar/borrar. En escenario normal no hay rutas ni operaciones experimentales disponibles. |

## 4. Reglas financieras y de producto que quedan fijadas

- Patrimonio = saldos incluidos en patrimonio menos deuda de crédito; incluye ahorros. Mantener la tarjeta compacta actual, sin selector de ahorros ni pulsación larga.
- No presentar saldo de cuenta, dinero disponible, crédito disponible y patrimonio como equivalentes. Si se propone mostrar un total de dinero disponible, acordar su definición y pantalla antes de añadirlo.
- Compra de crédito aumenta deuda; pago la reduce. Transferencias, pagos y ajustes quedan fuera de ingresos/gastos/presupuestos.
- Cuotas: total de compra compromete crédito y cuota afecta período. Reportes puede usar compras completas o consumo del período. Devolución impacta su fecha real.
- Canales: Efectivo, Tarjeta física, Google Wallet, Pago online, Transferencia y Otro, filtrados por tipo/cuentas. Efectivo solo para cuentas de efectivo; crédito no admite transferencia como compra. Históricos siguen legibles.
- Las compras pendientes no cambian saldos. Descartar conserva estado ignorado; confirmar aprende asociaciones independientes de cuenta/comercio.
- Wallet y programados procesan al abrir/volver o mientras la app está visible según su recorrido; no sugerir ejecución financiera con la app cerrada ni avisos del sistema para revisar.
- PYG entero y datos locales, sin servidor/cuenta de usuario. Seguridad no añade contraseña diaria de cifrado; backup sí tiene contraseña independiente.
- SMS, diagnóstico, inspección y simulador requieren habilitación de desarrollo; Wallet normal no depende de ella.

## 5. Cambios de presentación explorados

Los siguientes cambios se plasmaron en el prototipo aceptado. Su traslado a Flutter sigue pendiente; las alternativas se conservan como referencia de diseño:

1. **Navegación principal:** cinco destinos recomendados o los cuatro actuales. Si se acepta Análisis, Presupuestos y Reportes serán sus secciones internas.
2. **Detalle contextual:** ficha de cuenta/crédito y detalle de movimiento, conservando las acciones actuales de cuenta desde Inicio.
3. **Accesos faltantes:** selector mensual de presupuestos, lotes CSV/reversión y pantalla de privacidad. Son propuestas diferenciadas, no decisiones asentadas de Flutter.

Sin nuevas funciones financieras en este bloque: intereses/plazos de ahorro, conversión o múltiples monedas, recordatorios, backups programados, tareas de fondo y sincronización. Permanecen pendientes según la base. «Toda Cabal» cubre las funciones existentes y sus estados; las futuras no se convierten en controles que parezcan operativos.

Orientación visual propuesta: móvil primero, verde profundo/menta/jade de la marca, cifras legibles, jerarquía entre total y contexto, estados con texto además de color y acciones explícitas. Posponer detalles visuales finos hasta cerrar los recorridos.

## 6. Contrato del prototipo con datos ficticios

Construido en `prototype/cabal/`, separado del código Flutter. No conectar base de datos, Android, Wallet, archivos personales ni credenciales reales. Permisos, biometría, selección de archivos, importación, respaldo y notificaciones serán escenas simuladas y claramente identificadas.

Escenarios accesibles desde un panel externo de demostración:

| Escenario | Datos y estados a cubrir |
| --- | --- |
| Primera vez | Sin cuentas ni movimientos; Wallet, automatización, programación y herramientas de desarrollo apagados. |
| Uso diario | Cuenta «Cuenta diaria», «Efectivo», «Reserva» y «Crédito demo»; comercios/categorías ficticios, ingresos, gastos, transferencia y pago de crédito. |
| Crédito y cuotas | Dos tarjetas, compra en cuotas, devolución parcial y pago desde la tarjeta correcta. |
| Pendientes Wallet | Cuenta reconocida, cuenta sin asociación, alias ambiguo, comercio nuevo y posible coincidencia con programado. |
| Programados | Plantilla manual variable, gasto fijo activo, pausado, atrasado y pendiente por conflicto. |
| Análisis | Dos meses y seis meses de evolución, categorías con/sin presupuesto, mes vacío y neto negativo por devolución. |
| Archivos y recuperación | CSV válido/mixto/duplicado, backup válido y fallos simulados. |
| Desarrollo | Activación externa explícita, SMS/diagnóstico/inspección/simulador de prueba; imposible acceder en escenario normal. |

Los escenarios poblados son datos de demostración, no valores que Cabal precargará al usuario. El modelo del prototipo mantiene un libro ficticio compartido: saldos iniciales + movimientos = saldos finales; mismo gasto/cuota/devolución en historial, presupuesto y reporte. Mostrar moneda y fechas con formato paraguayo, sin decimales PYG.

Interacciones mínimas: todas las entradas del mapa llevan a una pantalla o diálogo, guardar actualiza el estado ficticio, cancelar vuelve sin registrar, eliminar/deshacer respeta sus reglas, filtros/períodos cambian resultados y se puede reiniciar cada escenario. Evitar botones decorativos sin resultado; operaciones del sistema abren su simulación.

## 7. Criterio para dar por cerrado el diseño antes de volver a Flutter

- Navegación elegida y cada función del inventario asignada a un acceso visible.
- Recorridos F01–F23 cubiertos por pantalla, formulario, diálogo o escena simulada.
- Separación explícita entre funciones existentes, propuestas de presentación y funciones futuras pendientes.
- Inicio vacío, carga, error, sin resultados, éxito, validación y conflictos cubiertos donde correspondan.
- Retorno al origen y conservación de filtros/período comprobados, especialmente Reportes → Historial → Movimiento.
- Importes y efectos consistentes; pendientes sin impacto, pagos sin gasto duplicado y crédito/cuotas distinguibles.
- Revisión del prototipo antes de trasladar un cambio al código de la app. No generar ni compilar APK como parte de este trabajo.

### Segundo ciclo de contraste y evaluación

La cobertura actual y los límites se mantienen en [PROTOTYPE_STATUS.md](PROTOTYPE_STATUS.md). El [segundo ciclo](../prototype/cabal/evaluation/ITERATION_2.md) registra una ronda de cambios y su verificación; no convierte simulaciones de dispositivo o archivos en integraciones reales.
