# Arquitectura

Referencia de implementación inspeccionada al 2026-10-07. Las decisiones de producto están en [PRODUCT_BASELINE](PRODUCT_BASELINE.md), los estados y brechas en [ROADMAP](ROADMAP.md).

## Componentes y recorridos

Flutter/Material 3 organiza código por función. Riverpod proporciona dependencias/streams; GoRouter rutas; Drift/SQLite persistencia con claves foráneas, WAL e índices. La navegación Flutter tiene cinco destinos en `StatefulShellRoute.indexedStack`: Inicio, Movimientos, Cuentas, Análisis y Más. Análisis conserva Presupuestos y Reportes; las ramas preservan su estado.

```text
UI Flutter → servicios / repositorios → LedgerService / PostingCalculator → Drift
Listener Kotlin → cola cifrada → MethodChannel → extractor / deduplicación
  → propuesta pendiente → revisión → LedgerService
  → registro automático opcional solo si cumple reglas → LedgerService
Ciclo de vida Flutter / captura visible → procesar cola → procesar programados
```

`PostingCalculator` calcula efectos; `LedgerService` guarda movimiento, partidas, divisiones y auditoría transaccionalmente. Plantillas, revisiones y planes coordinan sus escrituras con la transacción financiera. Importes persistidos enteros; `Money.format` puede usar división para presentación, por lo que «no usa double en ninguna parte» sería demasiado amplio. PYG es la interfaz actual, no soporte multimoneda completo.

`LedgerRepository.watchMovements` proyecta cuotas como filas mensuales enlazadas sin crear transacciones duplicadas. `ReportService` es la fuente de cálculo compartida por reportes y presupuestos, incluido el reparto entero de categorías (H01). La deuda utiliza la compra completa y los pagos siguen fuera del gasto.

## Directorios y evidencia

- [App/router/providers](../lib/app): tema, navegación y ciclo de vida (`app.dart`).
- [Core](../lib/core): base, dinero, seguridad, backup y notificaciones.
- [Features](../lib/features): pantallas/servicios financieros, plantillas y herramientas de desarrollo separadas.
- [Android Kotlin](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales): listener, cola, puente y `DeviceCrypto`.
- [Pruebas](../test): evidencias limitadas al entorno ejecutado.
- [Prototipo](../prototype/cabal): libro ficticio JS/localStorage; no conecta con Flutter ni prueba Android.

## Persistencia y recuperación

El esquema sigue en v1 (`AppDatabase.schemaVersion`, [snapshot](../drift_schemas/schema_v1.json)); no se borra la base ante un error de migración. La conversión de archivos claros a cifrados es una migración de almacenamiento distinta de una nueva versión de esquema. `encrypted_storage.dart` conserva el original hasta comprobar la copia.

SQLite3MultipleCiphers se selecciona en `pubspec.yaml` (`sqlite3.source: sqlite3mc`). Android Keystore protege la clave automática de base/cola mediante `DeviceCrypto.kt`; cola AES-GCM, base/WAL cifrados. Bloqueo de pantalla y cifrado son barreras distintas. La portabilidad usa contraseña independiente: [BACKUP_FORMAT](BACKUP_FORMAT.md). Restaurar valida snapshot, crea respaldo previo cifrado y reemplaza datos en una transacción sin cerrar la conexión.

## Captura y automatización

El listener admite paquetes consentidos. Wallet es normal y opcional. SMS/diagnóstico/inspección/simulador exigen la [bandera](DEVELOPER_TOOLS.md), comprobada en Dart, rutas, operaciones y Android; ocultar el menú no basta.

La cola limita capturas a las últimas 100 y filtra antigüedad de 24 horas al operar. No garantiza borrado por reloj mientras la app está cerrada. Flutter acusa eventos procesados y aplica reconocimiento/deduplicación. Una compra automática exige importe válido, cuenta activa única y comercio único; desconocidos, actualizaciones y posibles duplicados requieren revisión. No hay avisos del sistema para revisar ni tarea financiera persistente con la app cerrada. Capturar en segundo plano no equivale a registrar en segundo plano.

`ScheduledTemplateService.processDue` procesa gastos fijos al abrir/volver; máximo 120 vencimientos por plantilla/pasada, identificación plantilla/fecha y conflictos con movimientos/notificaciones en ventana de tres días. Son reglas preventivas, no confirmación de cobro bancario.

## Límites de la referencia

La inspección y pruebas de host no demuestran entrega del listener, seguridad de claves en cada dispositivo, compatibilidad de actualización ni publicación en Play. No se revisaron políticas externas vigentes en esta auditoría; el texto de privacidad sigue preliminar. Ver [limitaciones](KNOWN_LIMITATIONS.md) y [verificación Android](DEVELOPMENT.md#verificación-android-pendiente).
