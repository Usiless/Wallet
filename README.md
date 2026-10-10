# Cabal

Cabal es una aplicación de finanzas personales para Android: cuentas propias, movimientos, crédito y cuotas, pagos pendientes con recordatorios, presupuestos y reportes. Los datos quedan en el dispositivo, sin cuenta de usuario ni servidor. La interfaz trabaja con PYG entero.

La configuración empieza sin cuentas y puede terminar así; para registrar movimientos se necesita una. Google Wallet y el registro automático opcional de compras reconocidas son funciones normales, desactivadas inicialmente. SMS Sudameris, diagnóstico, inspección de notificaciones y simuladores requieren las herramientas de desarrollo, bloqueadas en release/profile.

La base activa, la cola de notificaciones y el backup portable están cifrados; el backup usa una contraseña elegida por el usuario. Restaurar valida los datos, conserva un backup previo cifrado y reemplaza el contenido en una transacción, sin reiniciar la app.

## Documentación

| Necesito… | Documento |
| --- | --- |
| Saber qué está decidido y qué falta acordar | [Base de producto](docs/PRODUCT_BASELINE.md) |
| Ver el estado por capacidad y lo que queda por verificar | [Roadmap](docs/ROADMAP.md) |
| Preparar el entorno, ejecutar pruebas o verificar en el teléfono | [Desarrollo](docs/DEVELOPMENT.md) |
| Entender las capas, la persistencia y la captura | [Arquitectura](docs/ARCHITECTURE.md) y [modelo de datos](docs/DATA_MODEL.md) |
| Recuperar datos | [Formato de backup](docs/BACKUP_FORMAT.md) |
| Revisar seguridad, privacidad y límites | [Privacidad](docs/PRIVACY.md), [limitaciones](docs/KNOWN_LIMITATIONS.md) y [herramientas de desarrollo](docs/DEVELOPER_TOOLS.md) |
| Revisar dependencias | [Dependencias y licencias](docs/THIRD_PARTY_LICENSES.md) |

Las reglas para trabajar en el código (qué no tocar, cómo organizarlo, git y textos de interfaz) están en [AGENTS.md](AGENTS.md).

## Mantenimiento

Una decisión de producto solo se cambia con aprobación explícita del usuario y se registra en la base. Los estados y evidencias se actualizan en el roadmap al observar código, pruebas o una verificación en el teléfono. Cada tema técnico tiene un documento principal; los demás lo enlazan. Las discrepancias de producto no se resuelven a partir del código.

El usuario genera el APK desde VSCodium; el asistente solo ejecuta análisis y pruebas (`flutter analyze`, `flutter test`).
