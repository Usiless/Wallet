# Estado de implementación por fases

**Histórico, no vigente:** checkpoint atribuido al 2026-07-19. Conserva afirmaciones originales, algunas superadas (base sin cifrado, avisos de revisión, plantillas fijas). Consultar [ROADMAP](ROADMAP.md) para estado y [PRODUCT_BASELINE](PRODUCT_BASELINE.md) para decisiones. Los comandos del final son un registro incompleto de ese checkpoint, no resultados nuevos ni instrucciones para compilación automática.

## Fase 0 — fundamentos

Implementado: proyecto Android, Material 3 claro/oscuro, navegación, providers, moneda entera, zona `America/Asuncion`, Drift v1, índices, claves foráneas, WAL, snapshot y CI. Archivos centrales: `lib/app`, `lib/core/database`, `lib/core/money`, `build.yaml`, `drift_schemas`. Supuesto: PYG es la moneda inicial; no existen esquemas publicados anteriores. Migración: creación v1 forward-only. Pendiente posterior: agregar una migración v2 solo cuando cambie el modelo.

## Fase 1 — cuentas y movimientos

Implementado: onboarding, cuentas/alias, categorías/comercios, ingreso/gasto/transferencia/ajuste/reembolso, postings, divisiones, efectivo, historial, clonado, borrado lógico y deshacer. Archivos: `features/onboarding`, `accounts`, `transactions`, `merchants`. Decisión: transferencia y pago de tarjeta son neutrales en analítica. Migración: incluida en v1. Pruebas: dinero, postings y persistencia.

## Fase 2 — tarjeta, cuotas y presupuestos

Implementado: perfil, límite, cierre/vencimiento/mínimo, plantilla de pago, cuotas con residuo final y consumo mensual, presupuestos total/categoría y umbrales. Archivos: `features/credit_cards`, `installments`, `budgets`. Supuesto: el compromiso total reduce el límite y cada cuota afecta su período de presupuesto. Migración: tablas v1. Pruebas: ciclo, redondeo, período y cálculo de presupuesto.

## Fase 3 — Google Wallet

Implementado: `NotificationListenerService` Kotlin, permisos/configuración, cola limitada, DTO, extractor tolerante, diagnóstico, candidatos, notificación local con acciones y deduplicación. Archivos: `android/.../finanzas_locales`, `core/notifications`, `pending_inbox`. Decisión: confirmar/editar siempre abre revisión. Migración: eventos, candidatos y decisiones v1. Pruebas: campos ausentes, alias, montos, claves actualizadas y duplicados. Pendiente externo: calibrar con payload real.

## Fase 4 — CSV

Implementado: plantilla, UTF-8/BOM, detección/cambio de delimitador, preview, filas rechazadas, mapeo, categorías nuevas, huellas, importación parcial transaccional, lote reversible, exportación CSV y JSON. Archivos: `features/imports`, `assets/plantilla_movimientos.csv`. Migración: lotes/filas v1. Pruebas: válidos, formatos erróneos, duplicados, reversión y round-trip básico.

## Fase 5 — backup, seguridad y reportes

Implementado: backup/restore cifrado, checksum, copia previa, bloqueo biométrico/credencial, dashboard, gráfico y métricas, privacidad y exportación abierta. Archivos: `core/backup`, `core/security`, `dashboard`, `reports`, `settings`. Decisión: sin contraseña almacenada; base activa protegida por sandbox, backup cifrado. Pruebas: round-trip, contraseña errónea y corrupción.

## Fase 6 — SMS opcional

Implementado: opt-in de Google Messages, parser Sudameris, alias 9647/647000, pago de tarjeta, salario, transferencias incompletas, débitos, pago mínimo, variaciones de fecha/monto y OTP ignorado. Archivos: `sms_notification_ingestion_service.dart`, `sudameris_parser.dart`, fixtures. Migración: reutiliza candidatos v1 con dirección y contraparte. Pruebas: parser e ingestión; revisión de política aún requerida antes de publicar.

## Verificación del checkpoint

- `flutter analyze`: sin issues.
- `flutter test`: se registra el resultado definitivo tras la última ejecución completa.
- `flutter build apk --debug`: se registra el resultado definitivo tras compilar Android.
- No se declara prueba en dispositivo físico.

