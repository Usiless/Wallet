# Dependencias y licencias de terceros

Dependencias directas; versiones registradas en `pubspec.lock`. Los paquetes no requieren claves comerciales para los recorridos locales inspeccionados. Esta tabla no certifica las licencias de todos los componentes nativos/transitivos del binario. Flutter también muestra las atribuciones transitivas en Configuración > Licencias de terceros.

| Paquete | Versión | Licencia |
| --- | ---: | --- |
| Flutter / Dart SDK | 3.47.6 / 3.13.5 | BSD-3-Clause |
| archive | 4.0.9 | MIT |
| crypto | 3.0.7 | BSD-3-Clause |
| cryptography | 2.9.0 | Apache-2.0 |
| csv | 8.0.0 | MIT |
| drift / drift_dev | 2.34.0 | MIT |
| file_picker | 13.1.0 | MIT |
| fl_chart | 1.2.0 | MIT |
| flutter_riverpod | 3.3.2 | MIT |
| go_router | 17.3.0 | BSD-3-Clause |
| intl | 0.20.2 | BSD-3-Clause |
| local_auth | 3.0.2 | BSD-3-Clause |
| path | 1.9.1 | BSD-3-Clause |
| path_provider | 2.1.6 | BSD-3-Clause |
| timezone | 0.11.1 | BSD-3-Clause |
| uuid | 4.6.0 | MIT |
| sqlite3 | 3.7.0 | MIT (declaración pendiente de revisión de componentes nativos sqlite3mc) |
| build_runner (desarrollo) | 2.15.1 | BSD-3-Clause (no verificada en esta auditoría) |
| flutter_lints (desarrollo) | 6.0.0 | BSD-3-Clause (no verificada en esta auditoría) |
| flutter_localizations / flutter_test / integration_test | SDK | Según SDK; textos no revisados en esta auditoría |

Los textos completos se distribuyen en cada paquete del SDK/cache y se incorporan al registro de licencias de Flutter. Antes de publicar una release debe regenerarse/revisarse esta tabla contra `pubspec.lock`, incluyendo dependencias transitivas del artefacto final.


Auditoría documental: versiones de paquetes contrastadas con `pubspec.yaml`/`pubspec.lock`; licencias de la tabla original conservadas como declaraciones no verificadas nuevamente. La selección nativa `sqlite3mc` requiere revisar sus atribuciones además del wrapper Dart antes de distribuir. No se consultaron políticas ni registros externos actuales.
