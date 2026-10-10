# Auditoría y mejora documental

Fecha local: 2026-10-06. Alcance: documentación mantenida del repositorio, contraste con prototipo HTML y Flutter/Android. Solo se editaron documentos por este trabajo; no se implementó el roadmap, no se compilaron APKs ni se modificaron datos de teléfono. La autoevaluación no equivale a aceptación del usuario.

## Método y límites

Se leyeron primero [AGENTS](../AGENTS.md) y [PRODUCT_BASELINE](PRODUCT_BASELINE.md). Se inventariaron Markdown, configuraciones y fuentes propias excluyendo dependencias, build y cachés generadas. Se contrastaron pantallas/rutas con servicios, persistencia, puentes Kotlin y pruebas; un botón o test aislado no se tomó como integración completa. Se aplicó Diátaxis de forma proporcional: README como entrada, guía práctica, referencias técnicas y decisiones separadas, sin tutoriales o secciones vacías.

El roadmap principal no existía como documento: había un checkpoint histórico por fases, una lista de continuación en la base y un plan del prototipo. No se puntuó contenido de un roadmap inexistente; el 3 inicial refleja prioridades/estados parciales repartidos y falta de aceptación/dependencias por iniciativa.

Durante la auditoría otro trabajo actualizó HTML/JS y documentación del prototipo, añadiendo `evaluation/ITERATION_2.md` y una prueba de modelo. Se releyó esa evidencia y se repitió la comprobación JS: el primer resultado de esta sesión fue 27 y el final 28 pruebas. Esos cambios de código no los realizó esta auditoría. Se conservó el informe nuevo y su revisión final pendiente, sin extenderle la aceptación histórica del primer ciclo. Esta matriz es una fotografía del estado leído, no una garantía contra modificaciones posteriores.

`git status` no pudo usarse: el checkout proporcionado no fue reconocido como repositorio Git (directorio `.git` sin metadatos utilizables). No se hizo commit, push ni se disparó CI. Se comprobaron archivos/enlaces directamente. Las escrituras de este trabajo se limitaron a Markdown; Flutter usa cachés/salidas de pruebas como parte de su ejecución, no un APK.

## Inventario y destino por documento

No se movieron documentos: se conservaron rutas y contexto único, evitando romper referencias desde scripts/configuración. Se consolidó la matriz de implementación en ROADMAP; los documentos históricos explican su alcance y enlazan al estado vigente.

| Documento | Situación inicial / problema | Resultado y lector |
| --- | --- | --- |
| [README](../README.md) | Entrada extensa mezclada con firma, diagnóstico y estado antiguo; prometía JSON importable, acceso experimental a Wallet y avisos. | Entrada vigente breve y mapa por necesidad; desarrollo trasladado a DEVELOPMENT y privacidad enlazada. Usuario/desarrollador. |
| [PRODUCT_BASELINE](PRODUCT_BASELINE.md) | Fuente de decisiones con estado duplicado y pendientes que mezclaban validación/decisión. | Conserva todas las reglas únicas aprobadas y propuestas; tabla de estado consolidada en ROADMAP, pendientes aclarados. Usuario que decide alcance. |
| [ROADMAP](ROADMAP.md) | No existía principal. | Nuevo: F01–F23, V01–V03 y P01–P09, estado doble, evidencia, aceptación, dependencias, prioridad y proceso. Usuario/desarrollador. |
| [DEVELOPMENT](DEVELOPMENT.md) | No existía guía única; comandos/instrucciones dispersos en README y desarrollo. | Nueva guía de entorno, análisis/tests, APK manual/firma y procedimiento Android pendiente. Desarrollador/verificador. |
| [IMPLEMENTATION_STATUS](IMPLEMENTATION_STATUS.md) | Histórico por fases que parecía estado actual; seguridad/notificaciones superadas y resultados incompletos. | Histórico explícito sin borrar contexto ni atribuir resultados nuevos. Mantenedor que investiga evolución. |
| [APP_REVIEW](APP_REVIEW.md) | Informe con pendientes iniciales resueltos más abajo; varios conteos sucesivos. | Marcado histórico con seguimientos; conteos no presentados como suite actual. Mantenedor. |
| [PROTOTYPE_PLAN](PROTOTYPE_PLAN.md) | Diseño/inventario con alternativas y brechas antiguas; susceptible de confundirse con roadmap aprobado. | Plan de referencia histórico con IDs estables y enlace al estado actual; no aprueba implementación. Diseñador/usuario. |
| [PROTOTYPE_STATUS](PROTOTYPE_STATUS.md) | Matriz HTML duplicada; inicialmente desactualizada y luego actualizada concurrentemente. | Límites/diferencias únicos conservados, estado doble consolidado en ROADMAP y vínculo a ambos informes visuales. Revisor de diseño. |
| [README HTML](../prototype/cabal/README.md) | Guía útil; estados/cantidad de tests cambiaron concurrentemente. | Se conserva uso, escenarios y segunda evaluación; enlace al roadmap/auditoría y límites de comprobación. Usuario del prototipo. |
| [REPORT visual](../prototype/cabal/evaluation/REPORT.md) | Evidencia de primer ciclo aceptado; no describe todo el código posterior. | Histórico identificado y enlazado al segundo ciclo. No se alteran notas originales. |
| [ITERATION_2](../prototype/cabal/evaluation/ITERATION_2.md) | Apareció durante el trabajo; nuevo informe de otra tarea. | Conservado, revisado y enlazado; resultados atribuidos a ese informe y aceptación final pendiente. |
| [ARCHITECTURE](ARCHITECTURE.md) | Flujo solo manual, avisos antiguos, cifrado/restauración incompletos. | Referencia vigente: automatización opcional, ciclo de vida, cifrado, recuperación, responsabilidad por módulo y límites. Desarrollador. |
| [DATA_MODEL](DATA_MODEL.md) | Postings descritos como inmutables pese a reconstrucción al editar. | Corregido; programación JSON/huella explicada sin inventar tablas, reglas contables conservadas. Desarrollador. |
| [CSV_FORMAT](CSV_FORMAT.md) | Prometía mapeo, previa completa y reversión accesible; canal físico ausente. | Contrato y límites reales de UI/servicio, reversión no atómica, JSON solo exportación y vínculos no garantizados por parser. Usuario técnico/desarrollador. |
| [BACKUP_FORMAT](BACKUP_FORMAT.md) | Copia previa clara, reemplazo de archivo/reinicio y compatibilidad anterior no respaldados. | Sobre criptográfico conservado; igual esquema, snapshot validado, copia cifrada, rollback transaccional, temporales y derivación nativa/Dart actualizados. Desarrollador/verificador. |
| [PRIVACY](PRIVACY.md) | Afirmaba cola sin cifrado. | Corregido y marcado límite de inspección; divulgación final sigue preliminar/no aprobada. Usuario/revisor de distribución. |
| [DEVELOPER_TOOLS](DEVELOPER_TOOLS.md) | Buena guía de bandera, con párrafo antiguo sin cifrado y contador ambiguo. | Corregidos esos puntos; preservados pasos y límites de diagnóstico, simulador y repetición. Desarrollador. |
| [KNOWN_LIMITATIONS](KNOWN_LIMITATIONS.md) | Útil, pero brechas UI/CI incompletas y rutas en texto. | Enlaces corregidos, F17/F20/CI-01 añadidos, validación real pendiente conservada. Verificador. |
| [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES.md) | Tabla incompleta (`sqlite3`/desarrollo), afirmación universal sin nueva revisión de licencias nativas. | Versiones/entradas añadidas y licencias no comprobadas marcadas; atribuciones nativas siguen pendientes antes de distribuir. Mantenedor de publicación. |
| [CHANGELOG](../CHANGELOG.md) | Registro histórico sin resultados recientes completos. | Conservado, identificado como historia, enlaza estado vigente. No se inventa historial de versiones. |
| [Prompt original](archive/Prompt_maestro_finanzas_flutter.md) | Especificación extensa archivada; no es autorización vigente. | Conservada íntegra como contexto, separada de decisiones actuales. |
| [AGENTS](../AGENTS.md) | Reglas vigentes y explícitas. | Sin cambios; CI-01 señalado sin cambiar reglas o workflow. |

## Hallazgos y decisiones no resueltas

1. Base/WAL y cola cifradas según fuentes; bloqueo no sustituye cifrado. Restauración no exige reinicio y la copia previa persistente es `.finbackup`, no SQLite claro. Referencias vigentes corregidas; checkpoints se conservan como historia.
2. Captura Wallet es función normal; SMS/diagnóstico/inspección/simulador son desarrollo. No se emiten avisos del sistema para revisar; el procesamiento financiero no se promete con la app cerrada.
3. HTML tiene navegación de cinco destinos y accesos que Flutter no incorpora: mes de presupuestos, lotes/reversión y privacidad completa. No se declaran implementados en Android ni aprobados para traslado.
4. JSON no tiene importador encontrado; CSV no recupera todo el modelo ni divisiones como una transacción. Servicio de reversión no equivale a acción accesible ni atomicidad de lote.
5. Se corrigió inferencia sobre cuotas basadas en cierre: el formulario Flutter pasa fecha de compra. No se decide una nueva regla bancaria; P05 requiere aclaración.
6. Primera versión, privacidad/consentimiento, exportaciones legibles, ampliaciones de ahorro/moneda/fuentes y recordatorios/backups periódicos requieren revisión. Se mantienen fuera del trabajo aprobado.
7. CI-01 enfrenta compilación APK automática del workflow con regla del proyecto. Queda señalada, sin modificar configuración ni inferir excepción aprobada.
8. No se verificaron licencias nativas/transitivas completas, políticas de Play ni todos los formatos Wallet/dispositivos. Se marcan esos límites sin presentar cumplimiento o paridad exhaustiva.

## Rúbrica constante y evaluación

Escala 1–10, igual peso para siete criterios; promedio = suma / 7. La evaluación inicial se fijó antes de editar. Se realizó **una ronda documental**, que incluye reorganización, contraste, correcciones y revisión de enlaces/conservación. No se cuentan como rondas propias los ciclos visuales de otro trabajo ni la evaluación inicial.

| Criterio | Inicial | Ronda 1 | Observación inicial → cambio observable que justifica la nota |
| --- | ---: | ---: | --- |
| Organización y localización | 5 | 9 | Estado en base/checkpoints/plan y README mixto → entrada por necesidad, roadmap y guía principales; referencias e historia separadas sin secciones vacías. |
| Claridad y redacción | 7 | 8 | Muchos detalles útiles, términos de estado ambiguos → glosario, lector/propósito por documento y separación captura/procesamiento/simulación. Planes largos permanecen como historia identificada. |
| Coherencia y duplicación | 4 | 8 | Cifrado, reinicio y avisos contradictorios, matrices duplicadas → referencias corregidas y estado consolidado; CI-01/alcances pendientes explícitos. No se reescribe la historia para aparentar unanimidad. |
| Exactitud y trazabilidad | 5 | 8 | Versiones/conteos históricos sin asociación uniforme, UI inferida por servicios → archivos/símbolos/tests por capacidad y límites de ejecución; licencias/políticas/nativo no verificados señalados. Falta evidencia integral de teléfono. |
| Utilidad y cobertura | 7 | 8 | Cobertura financiera amplia pero faltaba procedimiento Android único → guía con secuencia de saldos, recuperación, permisos/banderas y límites de archivos; información histórica única preservada. No es manual exhaustivo para cada dispositivo. |
| Calidad del roadmap | 3 | 8 | No existía roadmap principal; orden suelto sin criterios/dependencias → necesidad/beneficio, alcance/exclusiones, aceptación, prioridades razonadas y esfuerzo relativo en V/P. Estimaciones y prioridad siguen propuestas, no compromisos. |
| HTML/Flutter/verificación/aprobación | 5 | 9 | Buenas advertencias HTML, pero estados/aceptación mezclados → columnas independientes, definiciones, ningún Android verificado por lectura, segundo ciclo pendiente y proceso con aprobación explícita. |
| **Promedio (suma / 7)** | **36 / 7 = 5,14** | **58 / 7 = 8,29** | Se detiene tras ronda 1: promedio ≥8, mínimo 8 y contradicciones críticas conocidas señaladas. No representa aceptación del usuario. |

## Verificaciones de la ronda 1

- `flutter analyze --no-pub`: **sin incidencias**.
- `flutter test --no-pub`: **147 pruebas aprobadas**. El log contiene advertencias de múltiples instancias de base de pruebas; resultado final satisfactorio. No demuestra integración nativa.
- `flutter test --no-pub --dart-define-from-file=config/development.json test/features/developer_tools/developer_tools_test.dart`: **8 aprobadas**. No demuestra bloqueo del binario real release/profile.
- `node --check prototype/cabal/app.js` y `node --check prototype/cabal/model.js`: sintaxis correcta.
- `node prototype/cabal/model.test.js`: **28 aprobadas** sobre el estado final leído; resultado inicial de sesión 27 antes del cambio concurrente. No es prueba DOM/Android.
- Se comprobaron 236 enlaces Markdown locales y sus anclas en 23 documentos mantenidos (sin rutas/anclas rotas), incluida la referencia de ambos informes visuales; se corrigió una referencia de símbolo inexistente en el nuevo informe concurrente. No se verificó disponibilidad de enlaces externos: fuentes externas históricas quedan como referencias, no evidencia de políticas actuales.
- Se revisó conservación de decisiones/pendientes, reglas contables, pasos de diagnóstico, instrucciones de firma, limitaciones y contexto histórico. No se movieron rutas; las referencias desde código/configuración siguen apuntando al mismo lugar. ROADMAP centraliza estados/prioridades y enlaza las fuentes pertinentes.

Los intentos iniciales de Flutter fallaron antes del análisis por caché del SDK de solo lectura; se repitieron con permiso para escribir esa caché y completaron. Logs de esta sesión: `/tmp/cabal-doc-analyze.log`, `/tmp/cabal-doc-test.log`, `/tmp/cabal-doc-dev-test.log`, `/tmp/cabal-doc-html-test.log`; son temporales, los resultados durables quedan aquí. No se ejecutó `build_runner`, build APK, workflow CI ni smoke Android. No se inspeccionaron logs personales del teléfono. Los recorridos visuales del segundo informe se atribuyen a ese trabajo, no a esta ejecución.

## Pendiente de revisión del usuario

Revisar [ROADMAP](ROADMAP.md), especialmente P01–P06 y CI-01; decidir alcance posterior con solicitud explícita. Las funciones ya existentes conservan su estado real; las propuestas no se promovieron a decisiones. No queda una contradicción crítica conocida presentada como resuelta. Pueden aparecer nuevas brechas al ejecutar V01–V03 en Android.
