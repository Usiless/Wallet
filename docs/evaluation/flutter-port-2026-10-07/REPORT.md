# Traslado aprobado a Flutter y correcciones Android

Nota: los informes de tarea, logs y capturas que este informe cita se eliminaron el 2026-10-10; el texto conserva sus conclusiones y los archivos siguen en el historial de control de versiones.

Estado al 2026-10-09: traslado y correcciones terminados, 249 pruebas host aprobadas, análisis limpio y revisión independiente cerrada sin hallazgos relevantes confirmados pendientes. APK definitivo profile compilado y verificado; Android real pendiente.

## Alcance trasladado

- Registro unificado: Gasto incorpora En cuotas para cuentas no crédito, descripción neutral y categorías únicas o divididas excluyentes. Crédito conserva compromiso total y calendario mensual existentes.
- Obligaciones independientes del movimiento real: crear no descuenta; confirmar registra pago real, fecha y cuenta. Parciales y traslado a siguiente cuota existente conservan deuda y categorías exactas. Se propone la cuenta del último pago real y puede cambiarse.
- Edición/cancelación y recordatorios de pendientes, protecciones de revisión y restauración obsoleta; editar futuros conserva cuotas con pagos. Editar/eliminar/deshacer movimientos enlazados actualiza el residual real.
- Plantillas programadas preparan pendientes hasta fin del mes siguiente, sin asumir pagos ni duplicar registros históricos. Los cambios de calendario reconcilian futuros sin enlaces históricos; el avance interno del cursor no cancela fechas.
- Inicio muestra disponible, pendientes, patrimonio y próximos pagos. Cuentas usa tarjetas compactas que abren detalle con sus acciones; el shell móvil respeta insets. Altas flotantes consistentes; sin títulos raíz repetidos ni explicaciones nuevas.
- Presupuestos comparten reparto exacto con reportes y separan real/pendiente. Anillos normalizados verde/rojo y tonos suaves, sin rayado ni leyenda; se conservan edición y repetición mensual nativas.
- Recordatorios reales en Dart/Kotlin: agenda cifrada independiente, alarmas inexactas, permisos, reinicio/hora/zona y apertura del pago. Nunca confirman pagos ni procesan finanzas con app cerrada.
- Google Wallet/autorregistro siguen como funciones normales. SMS, diagnóstico, inspección y simuladores permanecen detrás de debug opt-in; profile/release siempre desactivados. No cambia esquema v1, identidad de instalación ni datos existentes. Prototipo intacto.

## Correcciones verificadas

| Hallazgo | Corrección y evidencia |
| --- | --- |
| P1: reparto de cuatro categorías producía un importe negativo | Restos enteros contra capacidades remanentes, filas/columnas exactas; informe financiero. |
| P1: editar por debajo de deuda trasladada ocultaba residual | Límite incluye traslado y preserva categorías fijas; segunda revisión. |
| P2: edición de calendario retenía obligaciones futuras anteriores | Supersede futuros sin enlaces, conserva historial/deduplicación; mismo informe financiero. |
| P2: backup aceptaba traslado sin destino | Historial, categorías y destinos posteriores obligatorios; normalización de legado válido, rechazo de huérfanos. |
| P2: actualización de agenda borraba avisos válidos | Identidad por entrada y cancelación selectiva; revisión de recordatorios/formulario. |
| P2: preferencia oculta de plantilla bloqueaba gasto en cuotas | Guardado de obligación independiente; misma revisión. |
| P2: importe truncado, palabras partidas y cero ficticio durante carga/error | Importes completos, composición estrecha y estados explícitos; revisión de raíces. |
| P2: Cuentas invadía área superior y crédito agregaba una fila de acciones | SafeArea móvil y tarjetas compactas con acciones en detalle; 12 regresiones y seis capturas. |
| Rendimiento: consultas duplicadas, escrituras idénticas y agenda repetida | Reutilización de lista emitida, escritura condicional y firma de agenda tras éxito; investigación y revisión. |
| Rendimiento: replace/consume de agenda hacían almacenamiento síncrono en hilo Android principal | Worker serial, respuestas por UI y orden preservado; seis pruebas JVM y compilación Kotlin. |

La revisión global confirmó dos variantes de duplicación Wallet: coincidencia exacta con residual y coincidencia con un pago efectivo enlazado fuera de la ventana ordinaria de dos minutos. Se corrigieron ambos caminos (process y confirmación automática), conservando la ventana de tres días para pagos enlazados/programados y la política ordinaria para movimientos manuales sin vínculo. Cinco regresiones de residual y nueve de pagos efectivos incluyen completos, parciales, plantillas, planes, candidatos anteriores y controles sin conflicto. Corrección de residual, corrección de pagos enlazados y revisión final dirigida PASS.

## Verificaciones ejecutadas

- `flutter analyze --no-pub`: exit0, sin incidencias, log.
- `flutter test --no-pub --reporter expanded`: exit0, **249 pruebas**, log. Ejecución final tras ambas correcciones Wallet: 249/249 en43s; análisis sin incidencias en1.2s.
- Desarrollo opt-in: `flutter test --no-pub --dart-define-from-file=config/development.json test/features/developer_tools/developer_tools_test.dart`: ocho pruebas, log.
- Regresiones financieras: 59 dirigidas, luego 15 del último guard de edición; informes enlazados. Recordatorios/rendimiento: 20 dirigidas y seis JVM, logs, nativo.
- Capturas Flutter host: Inicio/shell390/320texto2x/960; Cuentas antes/después390/320texto2x/486. Generadas por pruebas de captura retiradas el 2026-10-10. Son fixtures sintéticos; no screenshots Android. Algunos fixtures de Inicio no resuelven el glifo ₲ del host, pendiente verificar Android real.
- Integridad del HTML: manifiesto204archivos sin cambios, registro.
- Compilación definitiva solicitada: `flutter build apk --profile --no-pub --dart-define=ENABLE_DEVELOPER_TOOLS=false`, log. Las compilaciones candidatas anteriores se conservaron como logs históricos; no contienen todos los arreglos y no se entregan como versión final. Build definitivo exit0 en43.4s, APK124.622.725bytes. Metadatos y hash, firma, identificador.

La suite inicial completa encontró una expectativa obsoleta que ocultaba Plantillas en Más; se corrigió al alcance aprobado conservando ausencia CSV/JSON. Se corrigieron15 avisos de estilo sin alterar condiciones. Los avisos Drift de múltiples conexiones en pruebas de backup permanecen como advertencias de host, sin fallos.

## Evidencia, revisión y límites

La comparación previa está en el plan. Las revisiones independientes de tareas están enlazadas arriba. La primera revisión global se interrumpió por límite de uso sin emitir veredicto completo. Se reanudó una evaluación independiente finita: informe global, seguido de una única corrección de sus hallazgos restantes y revisión dirigida PASS. No hubo nueva auditoría broad ni se presentó la revisión interrumpida como aprobación. El registro operativo (informes de tarea, logs, capturas y `.superpowers/`) se eliminó el 2026-10-10; permanece en el historial de control de versiones.

No hubo Android conectado (`adb devices -l` vacío). El usuario reportó bloqueo al abrir que requirió cerrar; no se reprodujo ni se demuestra corregido. El antecedente de pausa del depurador documentado en DEVELOPMENT no acredita causa de este incidente. Se corrigieron mecanismos de trabajo repetido y almacenamiento en UI observables; falta medir en teléfono. La hidratación N+1, cola Wallet, obtención inicial de clave y espera del monitor desde BroadcastReceiver siguen como riesgos de volumen/arranque sin medición Android.

Falta validar entrega real de recordatorios, permisos/canal denegados, suspensión, app cerrada, reinicio, reloj/zona, restricciones OEM y taps fríos/calientes; Wallet real; actualización sobre base anterior; SAF, Keystore, biometría, TalkBack, teclado y temas/insets físicos. Compilación, JVM y MethodChannels simulados no prueban esos recorridos. El procedimiento está en [DEVELOPMENT](../../DEVELOPMENT.md).

## Entrega

El usuario autorizó expresamente compilar y entregar APK el2026-10-08. Se eligió profile AOT para evitar JIT de debug, manteniendo la firma debug existente al no estar configurada firma release privada. No se instala ni reemplaza información del teléfono automáticamente. APK final: `build/app/outputs/flutter-apk/cabal-2026-10-09.apk` (copia exacta de app-profile.apk). Firma SHA-256 coincide con el APK debug anterior, identificador py.finanzaslocales.finanzas_locales; BuildConfig profile tiene DEVELOPER_TOOLS_ENABLED=false y Dart se compiló con ENABLE_DEVELOPER_TOOLS=false. SHA-256 del archivo: `10cb0b1f6f4108be2da884b6cddde49145090f0cf8838cb369c4ecc2ef4eb6a6`. No se afirma compatibilidad de actualización comprobada físicamente; la firma se compara con el APK debug anterior disponible en este workspace.

## Decisiones operativas y coste

- Sin Git disponible se trabajó en el checkout existente y se conservaron informes/diffs/snapshots locales. Coste: no hay un historial Git ni un diff histórico pre-port completo recuperable.
- Obligaciones versionadas en app_settings preservan esquema y backups v1; coste: validar referencias/JSON/carries estrictamente en restauración.
- Continuación y correcciones sin confirmación intermedia siguen la autorización expresa; propuestas de SMS u otras fuentes permanecen pendientes.
- Límite del harness obligó a reutilizar algunos implementadores con briefs separados; revisores independientes cerraron los cambios. Coste: menor aislamiento de contexto del implementador, compensado por snapshot/diff y revisión.
- Profile AOT usa la firma debug existente, sin fabricar una firma release. Coste: es una compilación profile con instrumentación, no un release de distribución ni una medición real de rendimiento.
- Builds candidatos se ejecutaron mientras cerraba la revisión, con entrega bloqueada hasta resolver hallazgos. Coste: dos recompilaciones al aparecer correcciones posteriores. Solo se entrega el artefacto definitivo.
