# Revisión general · 2026-10-04

**Informe histórico con seguimientos.** Los pendientes iniciales 1–3 fueron sustituidos por los apartados de seguimiento de este mismo informe. Los conteos corresponden a ejecuciones anteriores, no a esta auditoría. Estado consolidado: [ROADMAP](ROADMAP.md); nuevas verificaciones: [DOCUMENTATION_AUDIT](DOCUMENTATION_AUDIT.md).

Alcance: lectura del código de formularios, navegación, cuentas, movimientos y saldos, cuotas, presupuestos, reportes, backup/restauración, bloqueo y captura de notificaciones; análisis estático y pruebas automatizadas. No se construyó ni instaló un APK. No es una certificación completa en teléfono.

## Evidencia del fallo

Se consultó logcat del dispositivo conectado sin borrarlo. Los registros Flutter disponibles conservaban arranques de la app, pero no la aserción de la captura. Las advertencias generales del sistema no prueban errores de esta app.

La prueba de interfaz reproduce exactamente la aserción `DropdownButton` con valor `sys-food` al conservar una división de gasto y cambiar a ingreso: esa categoría ya no figura entre las opciones. Con las correcciones la misma prueba pasa. Se agregaron comprobaciones de transferencias, pago de una tarjeta específica y fallo al guardar cuotas.

## Corregido

- **Categorías y cuentas:** selección válida frente a cambios de tipo, listas o exclusión de contraparte; el estado del campo se recrea cuando cambian selección/opciones. Cambiar de tipo descarta divisiones incompatibles. Las categorías recién creadas esperan su actualización del stream. Se evitan actualizaciones de pantalla tras cerrar un selector o salir del formulario.
- **Cuotas:** comercio, compra, partidas, categorías y plan se guardan en una sola transacción de base de datos. Un fallo de creación del plan revierte la compra y su efecto en saldos. Cambiar de tarjeta a una cuenta sin crédito desactiva cuotas.
- **Deshacer:** comprobación del movimiento y restauración de saldos en una misma transacción. Dos intentos concurrentes restauran una sola vez. Los errores de eliminar/deshacer se muestran como mensajes; el aviso no depende de un WidgetRef de una pantalla que pudo haberse cerrado.
- **Pago de tarjeta:** el botón envía la tarjeta elegida al formulario en vez de seleccionar siempre la primera tarjeta de la lista.
- **Reporte mensual:** consulta todos los movimientos confirmados del mes, independiente del límite de 100 del historial. No incluye pendientes.
- **Presupuesto mensual:** las compras ordinarias se seleccionan entre medianoches locales, sin excluir la madrugada del primer día ni incluir la del mes siguiente. Los marcadores de períodos de cuotas conservan su formato existente.
- **Diagnóstico vencido:** se borra el contenido crudo, conservando los identificadores necesarios para propuestas y deduplicación. El borrado anterior violaba claves foráneas al intentar eliminar eventos referenciados.

## Validación

- Suite completa: 91 pruebas pasaron tras las correcciones; incluye regresiones de saldos, más de 100 compras, límites de mes y limpieza de datos referenciados.
- Formularios: 4 pruebas pasaron, incluida la comprobación añadida posteriormente de pago de la tarjeta indicada.
- Análisis estático: sin incidencias.
- Herramientas de desarrollo: 8 pruebas pasaron con `config/development.json`; los bloqueos por bandera se mantienen.
- Logs de esta sesión en `/tmp/wallet-review-*.log`. No se incluyen logs del teléfono en el proyecto.

## Pendientes de esta revisión

1. **Restauración de backup:** el codec comprueba autenticidad, hash y cabecera SQLite, pero falta comprobar integridad y esquema completo antes de reemplazar el archivo activo. La restauración cierra la conexión y exige reiniciar; deben probarse recuperación y reinicio de servicios ante fallos de escritura. No se hicieron pruebas destructivas con la base real del usuario.
2. **Historial:** sigue limitado a los últimos 100 movimientos. Hace falta paginación para que “Ver todos” permita recorrer todo el historial. El reporte ya no depende de esa lista.
3. **Cifrado activo:** la base y cola no tienen cifrado propio a nivel de archivo. Es una decisión pendiente en PRODUCT_BASELINE, no una propiedad que se deba asumir por el bloqueo biométrico.
4. **Validación en teléfono:** volver a probar cambios de tipo con categorías y divisiones, transferencia al cambiar origen, compra en cuotas, eliminación/deshacer y pago desde la segunda tarjeta. La restauración completa necesita una instalación de prueba con datos descartables.

Se actualizaron las limitaciones antiguas que todavía describían Wallet como exclusivamente experimental y avisos del sistema que ya no se emiten. Las decisiones pendientes de producto no se convirtieron en funciones nuevas durante esta revisión.

## Seguimiento solicitado · restauración, cifrado e historial

Los pendientes 1–3 se implementaron tras la autorización del usuario. La restauración ahora valida integridad, esquema y referencias, conserva un `.finbackup` previo y reemplaza los datos en una transacción manteniendo abierta la conexión. La interfaz muestra la etapa en curso. PBKDF2 usa el proveedor Android en un hilo separado, con una implementación Dart en isolate para plataformas sin ese proveedor; mantiene los parámetros de backups existentes.

La base y WAL se cifran con SQLite3MultipleCiphers, siguiendo la [configuración de Drift](https://drift.simonbinder.eu/platforms/encryption/). Android Keystore protege una clave local automática; también cifra las capturas de la cola con AES-GCM. Las bases y antiguas copias de seguridad en texto se migran conservando el original hasta verificar la copia cifrada. No se ejecutó esa actualización en el teléfono.

El historial permite cargar de 50 en 50 sin el tope de 100; la división de categorías evita el desborde en una pantalla angosta con el tema real. Se añadieron pruebas de restauración completa y rollback, contraseña incorrecta, migración interrumpida, WAL, backup portable de base cifrada y navegación hasta el movimiento 125. Sigue pendiente la prueba manual en la instalación del usuario; las pruebas destructivas se realizaron únicamente con datos descartables.

## Seguimiento · seis funciones básicas del roadmap

Alcance confirmado por el usuario: solo funciones básicas. Se implementaron edición de movimientos, administración de cuentas, comercios/categorías/alias, filtros de historial, conciliación/devoluciones y reportes por período con ambas vistas de cuotas.

Validación automatizada: suite completa de 138 pruebas aprobadas. Las nuevas regresiones verifican conservación de identidad y fuente, revisión concurrente, reconstrucción de cuotas y rollback, devolución concurrente sin exceder la compra, deshacer con revalidación, reparto exacto entre categorías tras múltiples devoluciones parciales, ajuste de deuda y saldo a favor, exclusión de ajustes del reporte, filtros literales combinados y presupuestos reactivos. La interfaz se probó con referencias archivadas y a 360 px de ancho, corrigiendo el desborde del selector de categorías.

No se generó ni instaló APK. La validación en teléfono queda pendiente; las pruebas automatizadas utilizan bases descartables. Las funciones secundarias y expansiones futuras no se implementaron en este bloque.

## Seguimiento · ampliación de reportes

Inspiración: vistas de análisis de `../GastosBanc` (evolución mensual, rankings, comparación con el período anterior y compras sin clasificar). Se adaptaron al modelo local de movimientos, cuotas y devoluciones de esta app: Resumen, Evolución, Categorías, Comercios y Cuentas, con filtros compartidos y acceso al historial de cada desglose.

La comparación usa el mes calendario anterior o un rango anterior con la misma cantidad de días. Evolución incluye meses sin actividad y respeta los extremos parciales de períodos personalizados. Los porcentajes usan gasto bruto; devoluciones y gastos netos se muestran aparte. El reparto de cuotas conserva todas las unidades de los importes originales por categoría. Los detalles de cuotas recuperan también compras anteriores al período y aclaran que el historial muestra su importe completo.

Validación: `flutter analyze` sin incidencias y suite completa de **146 pruebas aprobadas**. Las ocho pruebas nuevas verifican desgloses/totales con referencias archivadas, filtros, meses vacíos, rangos parciales y comparación, cuotas con redondeo, devoluciones con neto negativo, más de 100 compras, exclusión de movimientos no confirmados y navegación al historial. Las cinco vistas con datos se probaron con el tema real a 360 px y texto ampliado al 120 %. No se generó APK ni se modificaron datos del teléfono; queda la comprobación visual en el dispositivo.
