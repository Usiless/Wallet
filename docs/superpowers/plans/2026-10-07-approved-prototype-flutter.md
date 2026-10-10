# Traslado aprobado del prototipo a Flutter

Objetivo: portar las decisiones aceptadas de PRODUCT_BASELINE a Flutter real, conservando libro, integraciones y backups. Ejecución solicitada: subagent-driven-development, por tandas con revisión independiente. Especificación vinculante: PRODUCT_BASELINE, sección Prototipo revisado y aceptado; autorización nativa expresa del encargo actual.

## Restricciones globales
Sin cambios en prototype/cabal, sin APK. PYG entero y calendarios históricos conservados. Wallet y autorregistro normales; SMS/diagnóstico/inspección/simuladores exclusivamente desarrollo, bandera desactivada en release/profile. No textos explicativos ni ayudas sustitutivas. No intereses, SMS por ejemplos, backups automáticos ni fuentes nuevas. Conservar edición/repetición de presupuestos ya aprobada en Flutter aunque no exista en HTML.

## Contraste verificable previo
| Diferencia | Ya existe | Trabajo aprobado restante |
| --- | --- | --- |
| Cuotas de crédito | deuda completa, calendario, redondeo y primera fecha | formulario En cuotas/Descripción; preservar edición |
| Categorías | selector único ya se oculta al dividir | conservar y probar regresión |
| FAB de movimientos | tres botones separados y cierre exterior/back/Escape | retorno/foco; FAB directos consistentes en cuentas/presupuestos |
| Inicio/cuentas | banner patrimonial, tarjetas en Inicio, lista en Cuentas | disponible/resumen/próximos pagos; trasladar tarjetas a Cuentas |
| Raíces | cinco pestañas, appbars con títulos | quitar títulos repetidos, conservar acciones y títulos secundarios |
| Presupuestos | consulta/edición/repetición y arco interior de exceso | anillo proporcional único, pagos plenos/pendientes suaves; detalle accesible |
| Pagos no crédito | no existe obligación independiente del ledger | persistencia, planes, pagos parciales/carry, edición/cancelación y pantallas |
| Plantillas | motor crea ledger automáticamente | preparar pendientes y conservar historial ya registrado/dedupe |
| Recordatorios | permiso notificaciones propias, sin agenda real | puente/agenda persistente y abrir pago, sin confirmar automáticamente |
| Backup | v1, tablas exactas, settings cifrados | almacenamiento versionado en settings y validación semántica sin romper v1 |

Contradicciones resueltas por decisiones posteriores: cuarta acción FAB y menú inferior superados; listas de Inicio retiradas; programado pasa a pendiente para nuevos vencimientos. Registros históricos ya pagados/registrados no se reinterpretan. Restricciones «solo HTML» de informes históricos son superadas por este encargo, no por el código. No hay contradicción bloqueante de comportamiento identificada.

## Arquitectura
Obligaciones versionadas en app_settings cifrado existente, con pagos enlazados a movimientos reales y transacciones Drift, sin nueva tabla/esquema. Repositorio único valida importes/referencias, revisiones y generación de restauración. Agenda nativa independiente de la captura Wallet; notificaciones solo abren revisión. Alarmas inexactas permitidas en suspensión, sin permiso nuevo de alarmas exactas; hora objetivo local y limitación OEM explícita. Ningún trabajo financiero con app cerrada.

## Tareas y aceptación
### 1. Dominio de pagos pendientes y plantillas
Archivos nuevos lib/features/payments/domain/*; integrar scheduled_template_service, budget_service/calculator, report_service, ingestion y backup. Implementar PendingPaymentService, modelos/versionado y proveedores para pantallas. Pruebas primero: crear no descuenta; reparto100001/3=33333/33333/33335 y categorías60001/40000; pago/carry conserva deuda y saldos; carreras/revisión/restauración obsoleta; última cuota no inventa próxima; edición futura conserva pagos; programación idempotente y calendario31/febrero; Wallet coincidente requiere revisión; backups antiguos y nuevos restaurables. Pago crea gasto real exactamente una vez usando LedgerService.
### 2. Recordatorios reales
Puente Dart/Android separado, receptor/agenda cifrada persistente/reinicio/hora/zona/permiso; configuración3días09:00 y vencimiento, editable/desactivable. Agenda reemplazable e idempotente; pago/edición/cancelación/restauración reconciliados; tocar solo abre ID de obligación. Pruebas de planificación/puente con dobles, sin afirmar entrega Android.
### 3. Interfaz de pagos y formulario unificado
TransactionFormScreen: En cuotas en altas no crédito crea obligación; crédito usa servicio actual; edición nunca convierte registrado en nuevo pendiente. Descripción y recordatorio conservados en borrador/alta inline. Pantallas de listado/detalle/pago, cuenta sugerida editable, importe parcial/carry/fechas, edición futuros y cancelar; rutas integradas. Widget tests de cancelación/error/pago, categoría excluyente y rango2..120,320px/texto2x.
### 4. Pantallas raíz y análisis
Inicio disponible/pendiente/patrimonio/próximos2, tarjetas en Cuentas y acciones conservadas. Sin títulos raíz; secundarios con Volver. FAB unificados y foco; presupuestos normalizados, sin leyenda, tonos0.42, porcentajes reales; reportes incluyen pendiente sin duplicar pagado y separan importes reales. Mantener recurrencia/edición nativa existente. Widgets/ring test250%pendiente40/60,300%pagado1/3-2/3,340%,cero, devolución; claro/oscuro y texto ampliado.
### 5. Integración, revisión y documentación
flutter analyze, suite completa y desarrollo, pruebas dirigidas de backup, flags, Wallet, pagos y widgets. Evaluación independiente por tarea y global; corregir y revalidar. Intentar evidencia visual de Flutter sin APK mediante golden/widget rendering. Documentar exactamente comandos/resultados y límites Android. Verificar hash del prototipo intacto.

## Foco de revisión
Referencias JSON en restore; pagos concurrentes/importe o cuenta obsoletos; borrado/restauración de movimientos pagados; duplicados de Wallet/programados; agenda vieja tras restore/permiso denegado/reinicio. Cada uno debe quedar probado en su tarea propietaria.

## Entorno
No hay repositorio Git disponible en esta carpeta. Se trabaja in situ con snapshot /tmp/cabal-before-flutter-port-2026-10-07.tar.gz y ledger local, sin inventar commits ni crear repositorio. Flutter requiere acceso a su caché SDK externa para ejecutar pruebas; no compilar APK.

## Ampliación autorizada · 2026-10-08

El usuario solicita explícitamente continuar, corregir Cuentas y lentitud/bloqueos reportados, y luego compilar/entregar el APK. Esta autorización sustituye para esta entrega la prohibición anterior de compilación, manteniendo datos, identidad y barreras de desarrollo.

### 6. Regresión móvil en Cuentas
Proteger insets superiores/laterales del shell móvil, sin duplicar AppBar en detalles. Tarjetas compactas que abren detalle, con acciones existentes de movimientos/administración/pago accesibles allí. Probar320/390/486px, oscuro/claro, texto2x, importeslargos y AppBar; capturas Flutter comparables antes/después, diferenciadas de Android real.

### 7. Investigación y corrección de trabajo repetido
Reproducir invalidación/reconciliación redundante con conteos deterministas. Reutilizar datos ya emitidos, evitar escrituras iguales y sacar almacenamiento/agenda nativa del hilo principal con ejecución serial, conservando permisos, orden e identidades. No atribuir congelamientos a estos mecanismos sin traza del teléfono. N+1 y volumen quedan documentados si no se corrigen. Revisar independientemente y repetir pruebas afectadas.

### 8. Entrega solicitada
Análisis, suite completa y regresiones; build APK profile AOT con firma debug existente (no hay firma release configurada), developerToolsEnabled desactivado. Comprobar artefacto/firma/identificador y entregar enlace al APK nuevo; sin instalar ni modificar datos del teléfono. Si una limitación real impide compilar, reportar exactamente el fallo y no entregar un APK previo como nuevo.

Secuencia operativa de entrega: el build candidato puede correr en paralelo a la revisión global después de análisis/suite verdes; no se entrega hasta resolver los hallazgos y verificar que el artefacto corresponde al código final. Una corrección posterior requiere recompilar.
