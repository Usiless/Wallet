# Cabal

Cabal es una aplicación de finanzas personales para Android: cuentas propias, movimientos, crédito y cuotas, presupuestos y reportes. Los datos centrales quedan en el dispositivo, sin cuenta de usuario ni servidor. La interfaz trabaja inicialmente con PYG entero. Flutter es la aplicación real; el HTML es una demostración independiente con datos ficticios.

La configuración empieza sin cuentas y puede terminar así; para registrar movimientos se necesita una. Google Wallet y el registro automático opcional de compras reconocidas son funciones normales, desactivadas inicialmente. SMS Sudameris, diagnóstico, inspección de notificaciones y simuladores requieren herramientas de desarrollo, bloqueadas en release/profile.

## Por dónde empezar

| Necesito… | Documento principal |
| --- | --- |
| Entender qué está decidido y qué falta acordar | [Base de producto y decisiones](docs/PRODUCT_BASELINE.md) |
| Comparar HTML con Android y priorizar el siguiente trabajo | [Roadmap principal](docs/ROADMAP.md) |
| Preparar el entorno, ejecutar pruebas o verificar en teléfono | [Guía de desarrollo y verificación](docs/DEVELOPMENT.md) |
| Explorar las pantallas ficticias | [Abrir el prototipo](prototype/cabal/README.md) y [cobertura HTML](docs/PROTOTYPE_STATUS.md) |
| Entender persistencia, captura y servicios | [Arquitectura](docs/ARCHITECTURE.md) y [modelo de datos](docs/DATA_MODEL.md) |
| Importar/exportar o recuperar datos | [CSV/JSON](docs/CSV_FORMAT.md) y [backup cifrado](docs/BACKUP_FORMAT.md) |
| Revisar seguridad y límites conocidos | [Privacidad](docs/PRIVACY.md), [limitaciones](docs/KNOWN_LIMITATIONS.md) y [herramientas de desarrollo](docs/DEVELOPER_TOOLS.md) |
| Revisar dependencias | [Dependencias y licencias](docs/THIRD_PARTY_LICENSES.md) |
| Revisar esta reorganización y sus pruebas | [Auditoría documental](docs/DOCUMENTATION_AUDIT.md) |

## Estado al 2026-10-06

Los servicios y pantallas principales están implementados según inspección, con pruebas automatizadas. Eso no acredita validación integral en Android. El [roadmap](docs/ROADMAP.md) registra los estados por capacidad y las brechas: navegación HTML distinta, presupuestos sin selector mensual en Flutter, reversión CSV sin acceso visible, JSON solo exportable y validación nativa pendiente.

El prototipo tiene cinco destinos y simula permisos, notificaciones, archivos, backup y bloqueo. Los documentos previos registran aceptación del diseño HTML; esa aceptación no autoriza trasladarlo a Flutter ni implementar propuestas funcionales.

La base activa/WAL y la cola tienen cifrado local; Android Keystore protege la clave automática. El backup portable usa otra contraseña, elegida por el usuario. Restaurar valida los datos, conserva un backup previo cifrado y reemplaza el contenido transaccionalmente sin exigir reinicio. Falta verificar recuperación y actualización en teléfono.

## Historia y mantenimiento

[Changelog](CHANGELOG.md), [revisión técnica de octubre](docs/APP_REVIEW.md), [checkpoint por fases](docs/IMPLEMENTATION_STATUS.md), [plan de diseño](docs/PROTOTYPE_PLAN.md) e [informe visual](prototype/cabal/evaluation/REPORT.md) conservan contexto, no son el roadmap vigente. La [especificación original](docs/archive/Prompt_maestro_finanzas_flutter.md) es histórica.

Al cambiar una decisión, actualizar la base solo con aprobación explícita; al observar código o pruebas, actualizar estados/evidencias en el roadmap. Cada tema técnico tiene un documento principal: los demás lo enlazan. No resolver discrepancias de producto a partir del código.

El usuario genera el APK desde VSCodium. Este segundo ciclo modifica únicamente el prototipo HTML y su documentación; no compila APKs ni modifica Flutter. Resultado: 7,50 → 8,00/10 en una ronda, pendiente de revisión final. Ver [evaluación y pruebas](prototype/cabal/evaluation/ITERATION_2.md).
