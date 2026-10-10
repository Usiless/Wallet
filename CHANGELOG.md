# Changelog

Registro histórico de cambios, no evidencia actual de ejecución ni aprobación de ampliaciones. Estado vigente y límites: [ROADMAP](docs/ROADMAP.md). Se conservan las entradas originales.

## 0.1.0 - 2026-07-19

- Proyecto Flutter Android local-first con Material 3, Riverpod, GoRouter y Drift/SQLite.
- Onboarding, cuentas/alias, categorías/comercios, historial y registro rápido.
- Motor central de postings para ingresos, gastos, transferencias, pagos de tarjeta, efectivo y reembolsos.
- Tarjeta, ciclos, cuotas enteras y presupuestos mensuales.
- Listener Android Kotlin para Google Wallet y Google Messages, diagnóstico temporal, deduplicación y bandeja pendiente.
- Importación CSV con preview, validación, lote reversible y exportación CSV/JSON.
- Backup manual AES-256-GCM con PBKDF2, checksum, restore validado y copia previa.
- Bloqueo local, dashboard, reportes, temas claro/oscuro y configuración de privacidad.
- Esquema de base v1 y snapshot contractual inicial. No hay migraciones previas porque esta es la primera versión interna.


## 2026-10-04

- Contador de movimientos pendientes en la bandeja de Inicio y punto indicador en su pestaña; capturas nuevas se procesan también mientras la app está visible mediante aviso del lector nativo.

- Wallet y registro automático opcional en Configuración normal; aprendizaje confirmado de cuentas y comercios, asociación de comercios existentes y revisión de conflictos o posibles duplicados.
- Procesamiento de la cola al abrir/volver a la app y actualización de bandeja, con acuse de recibo después de procesar; sin avisos del sistema para casos pendientes.
- Simulador de notificaciones Android en desarrollo, con comercios editables tomados de la captura aportada, importes variables y transacciones marcadas como prueba.

- Avisos inferiores flotantes con márgenes y esquinas redondeadas; «Deshacer» desaparece a los 8 segundos en lugar de quedar persistente.

- Inicio sin bancos, cuentas ni alias personales precargados; cada usuario agrega sus propias cuentas o lo hace más adelante.
- Formulario compartido de cuentas con validación y datos de tarjeta ingresados por el usuario.
- Pago de tarjeta sin preferencia por un banco específico.
- Herramientas experimentales agrupadas en carpeta y menú propios, con bandera por archivo y bloqueo de captura y diagnóstico en release/profile.
- Perfiles de VSCodium para uso normal y pruebas, y lista de funciones básicas y decisiones pendientes en `docs/`.
- Limpieza de salidas de compilación, cachés locales, carpetas vacías, configuración antigua de IntelliJ y reloj auxiliar sin uso.
- Documentación reunida en `docs/`, especificación histórica archivada y fixtures usados desde las pruebas sin incluirlos en la app.
- Eliminadas dependencias directas sin imports: collection, cupertino_icons y mocktail.
- Actualizado file_picker a 13.1.0 y adaptadas selección, lectura y guardado de CSV, backups y diagnósticos a su API nueva para corregir el aviso de compatibilidad Kotlin.
- Migración a Flutter 3.47.6 estable y Dart 3.13.5, con Kotlin integrado en AGP 9 y versión actualizada en CI.
- Corregida la espera asíncrona del cifrado antes de limpiar el backup temporal y de la autenticación para capturar sus errores sin desbloquear la app.
- Consulta de notificaciones activas de Wallet en herramientas de desarrollo, con inspección previa sin escrituras y creación explícita de propuestas sin descartar la notificación.
- Selección obligatoria de cuenta sin coincidencia única, creación desde la confirmación, exclusión de cuentas archivadas y corrección de deduplicación de notificaciones actualizadas.
- Confirmación de compras Wallet guarda su identificador como alias de la cuenta seleccionada sin duplicar alias existentes; guardado y confirmación atómicos.
- Opción de desarrollo para reabrir propuestas después de eliminar el gasto, con bloqueo de confirmaciones repetidas y de restauraciones que dupliquen una compra activa.
