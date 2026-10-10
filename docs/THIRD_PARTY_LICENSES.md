# Dependencias y licencias de terceros

Dependencias directas; las versiones están en `pubspec.lock`. Los paquetes no requieren claves comerciales. Esta tabla no certifica las licencias de los componentes nativos ni transitivos del binario; Flutter muestra las atribuciones transitivas en Configuración → Licencias de terceros. Las licencias son las declaradas por cada paquete y no se han vuelto a verificar contra sus fuentes.

| Paquete | Versión | Licencia |
| --- | ---: | --- |
| Flutter / Dart SDK | 3.47.6 / 3.13.5 | BSD-3-Clause |
| archive | 4.3.0 | MIT |
| crypto | 3.0.7 | BSD-3-Clause |
| cryptography | 2.9.0 | Apache-2.0 |
| drift / drift_dev | 2.34.0 | MIT |
| file_picker | 13.1.0 | MIT |
| fl_chart | 1.2.0 | MIT |
| flutter_riverpod | 3.4.3 | MIT |
| go_router | 17.5.0 | BSD-3-Clause |
| intl | 0.20.3 | BSD-3-Clause |
| local_auth | 3.0.2 | BSD-3-Clause |
| path | 1.9.1 | BSD-3-Clause |
| path_provider | 2.1.6 | BSD-3-Clause |
| uuid | 4.6.0 | MIT |
| sqlite3 | 3.7.0 | MIT (la selección nativa `sqlite3mc` requiere revisar sus atribuciones antes de distribuir) |
| build_runner (desarrollo) | 2.15.1 | BSD-3-Clause |
| flutter_lints (desarrollo) | 6.0.0 | BSD-3-Clause |
| flutter_localizations / flutter_test | SDK | Según el SDK |

Los textos completos se distribuyen con cada paquete y se incorporan al registro de licencias de Flutter. Antes de publicar una release hay que regenerar y revisar esta tabla contra `pubspec.lock`, incluidas las dependencias transitivas del artefacto final.
