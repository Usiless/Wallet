# Cabal · Próximos cambios acordados

Actualizado: 2026-10-07. App de uso personal. Alcance funcional aprobado por el usuario. El encargo vigente «actualiza la documentación relevante y luego mueve el prototipo a flutter» autoriza trasladar a Flutter la experiencia aprobada y sus pruebas. No generar APKs ni ampliar propuestas pendientes. Las decisiones están en [PRODUCT_BASELINE](PRODUCT_BASELINE.md); el inventario de capacidades y evidencia está en [ROADMAP](ROADMAP.md).

## Lo definido

1. Llevar las cinco pestañas del HTML a Flutter: Inicio, Movimientos, Cuentas, Análisis y Más. Presupuestos debe seguir siendo accesible.
2. Consultar presupuestos de otros meses, sin agregar recurrencia.
3. Retirar CSV y JSON. Conservar backup cifrado/restauración y todos los movimientos existentes, incluidos los importados.
4. P05 actualizado por aprobación explícita del 2026-10-07: elegir primera fecha (por defecto compra), cuotas mensuales enlazadas en movimientos y cálculo único en presupuestos/reportes. Crédito completo comprometido al comprar; sin mínimos ni extractos calculados.
5. Wallet opcional. Información clara antes de conceder acceso; automatización sigue siendo una elección separada. Al retirar CSV/JSON, su advertencia de exportación legible deja de ser necesaria.
6. Quitar el build APK automático de CI. Los APK los genera el usuario.

No hace falta definir una versión pública ni preparar publicación. Intereses de ahorro, otras monedas/fuentes, recordatorios y backups periódicos siguen fuera. No se incorpora ninguna dependencia o servicio nuevo por seguir una guía.

## Orden de trabajo

### 1. Comprobar saldos y recuperación

Conservar las reglas existentes: enteros PYG, transferencias/pagos fuera del gasto, compra de crédito aumenta deuda completa, cuotas afectan su período y devoluciones no reescriben cuotas futuras. Ediciones, archivo y restauración conservan identidad, huellas y referencias históricas.

**H01 corregido en el traslado autorizado del 2026-10-07:** `BudgetService.watchProgress` utiliza el reparto exacto de `ReportService`. Compra 101 dividida 51/50, cuotas 33/33/35: categorías 16/16/19 y 17/17/16. Regresión activa sin bandera ni omisión. La reproducción fallida de la fase HTML se conserva abajo como evidencia histórica.

Aceptación mínima:

- Saldos, deuda y patrimonio coinciden con una secuencia calculada independientemente; cuotas suman 101 y categorías del plan 51/50, también en presupuestos/reportes.
- Cancelar no escribe; doble confirmación no duplica; revisión antigua no sobrescribe una nueva. Movimiento/partidas/divisiones/plan y movimiento/plantilla se guardan o revierten juntos.
- Backup válido recupera datos y relaciones sin reiniciar. Contraseña/corrupción/esquema incorrectos no reemplazan el libro. Fallo intermedio revierte la operación; copia previa cifrada antes del reemplazo.
- Restauración no se mezcla con escrituras manuales, Wallet o programados; borradores anteriores deben revisarse antes de guardar sobre datos restaurados.
- Pérdida de clave local no sobrescribe una base ilegible. Recuperación portable depende de backup válido y su contraseña; no se promete recuperar claves perdidas.

Pruebas automatizadas de cálculo, DB/atomicidad y conflictos; Android real para Keystore, archivos, interrupciones y ciclo de vida. HTML solo aporta revisión de mensajes, no prueba de seguridad.

### 2. Simplificar funciones y CI

Retirar entradas y recorridos CSV/JSON, sin borrar compras importadas, lotes históricos ni referencias necesarias para leer/restaurar datos existentes. No eliminar tablas ni cambiar esquema por retirar pantallas. Mantener backup/restauración y compatibilidad de instalación/almacenamiento.

Quitar compilación APK automática de push/PR conservando análisis/pruebas pertinentes. CI-01 aplicado durante este traslado; no se disparó el workflow.

Aceptación: CSV/JSON ya no se ofrecen ni tienen rutas activas de uso normal; movimientos antiguos y backup siguen utilizables. CI no ejecuta build APK automático. No hace falta HTML para CI; revisar la retirada de accesos en el prototipo cuando se prepare el traslado.

### 3. Presupuestos y tarjetas

Agregar consulta anterior/siguiente y selección de mes, con acceso al actual. Conservar mes al volver de otra pantalla. Mes sin presupuestos se distingue de presupuesto existente con consumo cero. La creación existente permanece para mes actual; no agregar alta histórica, edición, eliminación ni recurrencia en este bloque.

Calendario parte de la primera fecha elegida (por defecto compra), repite el día mensual con ajuste a último día sin deriva, separado de cierre/vencimiento. Movimientos, presupuestos y reportes cuentan cada cuota en su fecha; la compra canónica compromete el crédito completo una sola vez. No calcula mínimo bancario ni extractos; no recalcula planes históricos por cambiar cierre de tarjeta. Datos manuales de mínimo existentes no se borran ni se presentan como un cálculo automático.

Aceptación: períodos y categorías concuerdan con reportes, incluidos fin de año, cuotas, devoluciones y meses vacíos; consultar/cancelar no escribe. HTML para control/textos, pruebas de servicio/widgets y Android para fechas locales/persistencia/retorno.

### 4. Trasladar diseño por recorridos

Primero navegación/Inicio/Cuentas; después Movimientos y Análisis/Más. Reutilizar el HTML, revisando los accesos retirados y Presupuestos antes de trasladarlo. No copiar el motor financiero ficticio JavaScript.

Aceptación: las cinco pestañas funcionan; presupuesto sigue accesible; pagar una tarjeta mantiene esa tarjeta; volver de reportes→historial→detalle conserva filtros/período. Formularios conservan borrador o solicitan descarte. Wallet y automatización permanecen opcionales; denegar/revocar acceso no bloquea registro manual. SMS/diagnóstico/inspector/simulador siguen bloqueados sin bandera y en release/profile.

Accesibilidad práctica: etiquetas/errores legibles, foco coherente, información no solo por color, contraste y controles táctiles adecuados; teclado y TalkBack, texto grande sin ocultar Guardar/Cancelar. Revisar HTML móvil y luego probar Flutter/Android, sin confundir simulación con integración real.

## Proceso y compatibilidad

Alcance aprobado → HTML cuando ayude → revisión y aprobación explícita de experiencia → Flutter → verificación Android. Para claves, listener, archivos y ciclo de vida, revisar mensajes/plan directamente; no forzar un HTML del mecanismo.

Cambios pequeños, sin migración financiera prevista. Ante fallo de escritura: rollback, sin datos parciales; antes de cualquier cambio de persistencia, backup verificado. Revertir interfaz no debe borrar datos. No instalar una versión vieja sobre esquema nuevo sin comprobar compatibilidad. El esquema inspeccionado es v1 y restore exige igualdad de esquema: cualquier evolución futura requiere una estrategia explícita para backups antiguos.

## Referencias y límites de evidencia

Fuentes oficiales consultadas el 2026-10-06, aplicadas proporcionalmente:

- [Android Core App Quality](https://developer.android.com/docs/quality-guidelines/core-app-quality): navegación, estado, denegación de permisos, estabilidad y protección de datos. Es guía de calidad; no obliga a añadir funciones multimedia, servicios o backup automático incompatible con claves locales.
- [Flutter testing](https://docs.flutter.dev/testing/overview): unitarias/cálculos, widgets/flujos e integración; no sustituyen permisos/listener/archivos reales.
- [MASVS](https://mas.owasp.org/MASVS/) y [MASTG](https://mas.owasp.org/MASTG/): almacenamiento/fugas, criptografía/claves, entradas externas y privacidad. Sin servidor no corresponde agregar autenticación remota, pinning o atestación por defecto.
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/): referencia HTML para etiquetas, teclado/foco, contraste, reflujo, errores y prevención financiera. No aplica contenido multimedia inexistente; no se declara conformidad integral.
- [Accesibilidad Flutter](https://docs.flutter.dev/ui/accessibility), [pruebas de accesibilidad](https://docs.flutter.dev/ui/accessibility/accessibility-testing) y [Android](https://developer.android.com/guide/topics/ui/accessibility/apps): semántica/TalkBack, texto grande y objetivos Android de 48 dp. No equivaler CSS px a dp.
- [Keystore](https://developer.android.com/privacy-and-security/keystore), [listener](https://developer.android.com/reference/android/service/notification/NotificationListenerService) y [archivos SAF](https://developer.android.com/training/data-storage/shared/documents-files): restricciones de plataforma; no prometer clave portable, captura universal o URI como ruta normal.

En la investigación documental previa no se repitieron pruebas ni sesiones visuales. La ejecución posterior descrita abajo sí incluye host y navegador; las evaluaciones visuales anteriores mantienen su carácter histórico. No se generó APK. Flutter y el paso CI se modificaron en el traslado posterior autorizado; Android nativo permanece intacto. La concurrencia en dispositivo y las claves requieren Android; H01 quedó corregido en host; no se declara certificación, cumplimiento legal o preparación para publicación. La investigación no cubre todos los dispositivos/proveedores ni una auditoría criptográfica.

Este plan breve sustituye la propuesta extensa anterior, especialmente mapeo/reversión CSV, exportación JSON y preparación de una primera versión pública. No quedan decisiones generales bloqueantes. El usuario solicitó trasladar la experiencia actual el 2026-10-07; resultado y límites al final.


## Ejecución autorizada · 2026-10-06

**Registro histórico de la fase HTML.** Sus restricciones y pendientes nativos quedaron superados por el traslado autorizado al final de este documento. Las pruebas anteriores no se presentan como repetidas.

**Trazabilidad de alcance:** las respuestas explícitas del usuario «1. sí … 3. … sacar directamente esa función. también la de json … 6. sí», asentadas en PRODUCT_BASELINE, aprueban P01/P02/P04/P05 y sustituyen P03 por retirada. La solicitud posterior «prototipo, pruebas y documentación» y «No actualices el Flutter/Android» limita esta ejecución. CI-01 tiene decisión aprobada, pero modificar su configuración está fuera. P06 no requiere publicación; P07–P09 no se ejecutan. Aprobación funcional no equivale a aprobación del diseño actualizado.

| Bloque / ID | Cambio y aceptación cubierta | Componentes / evidencia | Estado y límite |
| --- | --- | --- | --- |
| 1 · V01/H01 | Oráculo independiente de saldo/deuda/patrimonio; cuotas/categorías conservan enteros en HTML. Regresión reproduce pérdida de 3 ₲ en presupuesto Flutter. | `model.test.js`, `budgetProgress`; `test/features/budgets/installment_rounding_regression_test.dart`. | Host/JS comprobados; H01 pendiente de corrección autorizada, no cierre integral V01. |
| 1 · V02 | Restaurar/copia previa aumenta generación del libro y revisiones; rechaza borradores anteriores. Conserva identidades, procedencia y lotes históricos. | `model.js:restoreBook`, `app.js:openModal/submit`, acciones `backup-restore/backup-previous-confirm`; tests y recorrido en dos pestañas. | Demostración y mensajes comprobados; no prueba cifrado, atomicidad SQLite ni carreras nativas. |
| 2 · P03/F20 | Retirados pantalla, botones, parser y acciones CSV/JSON; URL histórica `scenario=files` abre Backup. Datos importados existentes se conservan. | `app.js:more/history/action/submit`, `model.js` sin `previewCsv`, `index.html`; regresión de metadatos restaurados. | Completo en HTML. Flutter todavía ofrece CSV/JSON; no se borran servicios/tablas ni historial. |
| 2 · CI-01 | Decisión documentada: quitar build automático, conservar análisis/tests. | `.github/workflows/flutter.yml` inspeccionado, intacto. | Pendiente de encargo que autorice configuración. No disparar workflow actual. |
| 3 · P02/F17 | Anterior/siguiente, selector, mes actual, vacío distinto de consumo cero; consulta conserva período y no crea/copía presupuestos. Alta existente siempre mes actual. | `app.js:budgets`, `budget-month/budget-period/budget-today`; `model.js:budgetProgress/createBudget`. | Completo en HTML; meses independientes de Reportes. Flutter pendiente y condicionado por H01. |
| 3 · P05/F05/F06 | Calendario rotulado distribución presupuestaria desde compra, resto última cuota; no extracto ni prueba de pago. Mínimo antiguo, si existe, rotulado manual. | `app.js:detail/accountDetail`. | HTML inspeccionado y detalle recorrido; sin nuevas reglas, editores ni cálculos bancarios. |
| 4 · P01/P04 | Conservadas cinco pestañas; Presupuestos permanece únicamente en Análisis. Reporte→historial→detalle→volver conserva rango. Información clara de Wallet/backup, detección y automatización separadas; cancelar/revocar deja carga manual. | `app.js:analysis/more/info/wallet/permissionScene`; `index.html`. | Navegador comprobado en recorridos descritos abajo; diseño listo para revisión, sin traslado a Flutter. |
| Transversal · V03 | Preservados procesamiento al abrir/volver, opt-in y barreras de desarrollo existentes. | Tests de programados/Wallet seleccionados y modelo JS; sin cambios nativos. | Host parcial; listener/duplicados reales y barreras profile/release pendientes Android. |

**Datos/compatibilidad:** sin migración de SQLite, nombres de instalación o claves. El HTML conserva `cabal-prototype-v1`; libros antiguos sin `bookRevision` se leen como generación 0. `batches` y referencias importadas se preservan aunque ya no haya acciones CSV. Copia previa y contraseña ficticia viven solo en memoria; recargar pierde esa recuperación. Para recuperar el prototipo puede usarse la copia previa de sesión o reiniciar un escenario ficticio; no son mecanismos de recuperación de producción. Nunca usar datos personales en localStorage. No se incorporaron dependencias. El directorio no expone un repositorio Git utilizable; se compararon huellas antes/después: `lib/`, `android/`, `.github/`, `.vscode/`, `config/` y manifiestos/lockfile intactos, sin archivos previos eliminados.

### Verificación ejecutada

- **Host JS:** `node --check prototype/cabal/app.js`, `node --check prototype/cabal/model.js` y `node prototype/cabal/model.test.js`: sintaxis válida y **32/32** pruebas. Incluyen oráculos financieros, cuota/reembolso por período, consulta sin mutación, alta actual, archivo, deduplicación/actualizaciones Wallet, conflictos, guardado conjunto y restauración de referencias/revisiones. No prueban concurrencia transaccional real.
- **Host Flutter:** `flutter test --no-pub` sobre `budget_service_test.dart`, `report_analysis_test.dart`, `backup_service_test.dart`, `scheduled_template_service_test.dart`, `wallet_automation_test.dart`: **27 pasaron**. Backup emitió advertencia Drift por múltiples instancias de base; no impidió completar la suite y no acredita concurrencia segura. No se modificó producción.
- **H01:** `flutter test --no-pub --dart-define=VERIFY_KNOWN_H01=true test/features/budgets/installment_rounding_regression_test.dart` **falla con 49/49 frente a 51/50**. La prueba queda explícitamente omitida por defecto mientras no se autorice corregir `lib/`; ejecución normal confirma una omisión, no una aprobación. `flutter analyze --no-pub test/features/budgets/installment_rounding_regression_test.dart`: sin incidencias. Ningún comando genera APK.
- **Navegador local:** Más sin CSV/JSON; consulta septiembre vacío, diciembre→enero y mes actual; alta desde mes pasado indica octubre, validación de importe vacío, cancelación y alta válida en octubre conservando la consulta de septiembre; rango de Reportes 1–5 octubre se conserva al alternar presupuestos y al volver desde historial/detalle; calendario desde septiembre; cancelar/conceder/revocar acceso ficticio sin activar automatización; contraseña incorrecta mantiene formulario, restauración válida y recuperación previa; segunda pestaña rechaza guardado abierto antes del restore. Presupuestos sin desborde horizontal a 320/390/1280 px; diálogo a 320 con fondo inert, foco inicial en Cerrar y Tab desde Crear vuelve a Cerrar. Sin errores de consola observados en esa consulta. [Captura móvil](../prototype/cabal/evaluation/approved-scope-budget.png).
- **Inspeccionado:** preservación de mínimo manual, rutas retiradas, referencias, flags y configuración sin cambios. No se repitieron todas las variantes históricas ni se midió contraste/lector de pantalla/texto ampliado en esta sesión. Las guías se aplican parcialmente; no hay declaración de conformidad.
- **Android:** no ejecutado. No compilación, APK, dispositivo, publicación ni workflow. El SDK necesitó acceso a su caché para tests/análisis de host; eso no amplía el alcance sobre archivos de producción.

### Pendientes y comprobación mínima en Android

Esta entrega cierra el HTML/pruebas/documentación que pudo ejecutarse; no declara terminados los bloques nativos. Revisar este HTML antes del traslado. Luego, en un encargo que autorice Flutter y configuración: corregir H01, retirar CSV/JSON conservando historia/backup, aplicar P02/P05 y llevar P01/P04 por recorridos; quitar build automático CI antes de cualquier push que lo dispare.

El usuario genera la app desde VSCodium. En instalación descartable, registrar versión/modo/API y esperado/observado:

1. **V01/H01:** ingreso 1.000.000, gasto 100.000, transferencia 200.000 y compra en segunda tarjeta 90.000, pago 30.000: banco 670.000, efectivo 200.000, deuda 60.000, patrimonio 810.000, gasto 190.000, partiendo de cero. Compra separada 101/51/50 en 3 cuotas: meses 33/33/35, categorías 51/50. Presupuesto y reportes deben coincidir; H01 hoy incumple esto en host.
2. **P01/P02/P03/P05:** tras su implementación nativa, cinco pestañas, retorno con filtros, meses vacíos/fin de año y creación actual; no accesos CSV/JSON; importados antiguos legibles, calendarios y mínimo manual intactos. TalkBack, texto grande y teclado permiten Guardar/Cancelar.
3. **V02/P04:** backup real válido y contraseña incorrecta/copia inválida sin sustituir datos; copia previa recuperable, reapertura y estado tras interrupción. Solo sobre copia de prueba: archivos SAF, bloqueo/Keystore y conflicto de escritura durante restore. HTML no aporta evidencia criptográfica.
4. **V03/P04:** denegar/revocar permiso permite carga manual; detectar no activa registrar; reconocido único una vez, ambiguo/actualizado pendiente, programado sin duplicación al volver. SMS/diagnóstico/inspector/simuladores bloqueados en uso normal y profile/release, también en operaciones/puente. No crear tareas financieras con app cerrada.


### Revisión posterior de textos · Impeccable clarify

A pedido explícito del usuario se instaló [Impeccable](https://github.com/pbakaus/impeccable) y se aplicó su guía `clarify` al HTML: sin bajadas decorativas en encabezados ni descripciones repetidas en Más; ayudas de cálculo bajo demanda, avisos necesarios y contexto financiero conservados. `app.js` e `index.html` cambian solo presentación/textos, sin motor financiero, datos, Flutter/Android ni configuración. Sintaxis y **32/32 pruebas JS** correctas. Navegador: navegación, ayuda desplegable por teclado, avisos Wallet/backup y reflujo 320/390/1280 px. [Captura actual](../prototype/cabal/evaluation/clarify-budget-mobile.png).

La carga `impeccable context --target prototype/cabal/app.js` confirmó que esta corrección acotada puede usar el código existente sin crear PRODUCT.md/DESIGN.md. El detector `detect --json prototype/cabal/app.js prototype/cabal/index.html` emitió advertencias de contraste, tamaño/espaciado y fuente en estilos que no cambian en esta pasada; no equivale a una aprobación completa de accesibilidad/diseño. No se habilitaron hooks automáticos ni se repitieron pruebas Flutter o Android.


### Revisión visual aprobada · P01/P02/F17/F18

El usuario aprobó explícitamente anillos por presupuesto (rojo solo al superar 100%), comparación por barras para revisar, acciones accesibles sin recorrer listas y retirada del acceso duplicado en Más. Implementado solo en HTML: `app.js:budgets/budgetDetail/reportComparison/analysis/history/render/action`, `styles.css`, versión de recursos en `index.html`. Tarjetas muestran nombre y porcentaje; tocar abre importes exactos y movimientos del mes/categoría, en cuotas. Reportes comparan los mismos períodos/filtros de antes: gasto neto e ingresos con presentación uniforme; bruto/devoluciones en desglose, sin delta repetido. El historial del reporte está en el encabezado; Nuevo fuera de la lista desplazable y Plantillas en el encabezado; Crear presupuesto arriba y siempre para mes actual. No cambian motor, esquema, datos históricos ni reglas financieras.

Verificación de esta pasada: sintaxis válida, **32/32 pruebas JS**; comprobación temporal de presentación en host (0/100/101/120%, consumo negativo, comparación negativa y ambos períodos en cero). Navegador: 100% sin rojo y 104% rojo RGB(163,69,57), apertura de presupuesto por Enter, importes/historial filtrado, alta actual, mes vacío, desglose por teclado, Plantillas/Nuevo y acceso superior al historial del reporte; reflujo 320/390/1280 px sin desborde de página. Sin errores de consola observados. [Presupuestos](../prototype/cabal/evaluation/budget-rings-mobile.png) y [reportes](../prototype/cabal/evaluation/report-comparison-mobile.png). Sin migración; recuperación del diseño mediante copia anterior de archivos, sin restaurar el libro. Nueva composición lista para revisión visual; Android, TalkBack y texto ampliado pendientes. Flutter/Android/configuración y modelo financiero intactos; sin APK ni pruebas nativas repetidas.


### Ajustes tras comentarios visuales 1–8 · P01/P02/F17/F18

Esta revisión sustituye la composición de barras anterior. HTML: anillo verde hasta 100%; el excedente ocupa un arco interior rojo (hasta una vuelta adicional), con porcentaje total visible incluso sobre 200%. Reportes: tabla Ingresos/Gastos con flecha y variación contra el período anterior; Neto = ingresos menos gastos netos de devoluciones bajo el criterio seleccionado, sin representar saldo de cuentas. Base anterior cero no produce porcentajes infinitos; base negativa muestra variación absoluta y cambios menores de 1% se indican como tales. Cuenta, categoría y criterio compras/cuotas agrupados en Filtros con Aplicar/Cancelar; cinco vistas conservadas mediante selector. No se elimina ninguna de las dos reglas de cálculo aprobadas.

Más tiene un único acceso a Plantillas; Programadas pasa a filtro interno con pausa/edición/omisión y aviso operativo de Inicio conservados. Información queda con datos de aplicación, licencias y límite de simulación; se retiran tarjetas explicativas y accesos Wallet/backup duplicados. Sus avisos necesarios permanecen en las pantallas y confirmaciones correspondientes. Símbolos: `app.js:budgets/reportChange/reportSummary/reportFilters/reports/templates/more/info/action/submit`; estilos y versión de recursos actualizados. Sin cambios de motor, datos, esquema, Flutter/Android ni configuración.

Sintaxis y **32/32 pruebas JS** correctas. Host temporal: anillos 0/100/120/250% y consumo negativo; indicadores subida/bajada/igualdad/base cero/negativa; neto y devoluciones. Navegador: exceso 123% con base verde y arco rojo; tabla por cuotas (gasto 1.973.000, neto 2.227.000) y compras completas (gasto 1.773.000, neto 2.427.000); selector de categorías, Plantillas→Programadas/Todas e Información. Reflujo 320/390/1280 px sin desborde de página, consola sin errores observados. [Tabla actual](../prototype/cabal/evaluation/report-table-mobile.png), [exceso ficticio](../prototype/cabal/evaluation/budget-excess-mobile.png). Sin migración ni APK. Nueva revisión visual pendiente; Android/TalkBack/texto ampliado sin verificar. Los resultados anteriores son históricos y no se repiten íntegramente.


### Ajustes posteriores 1–6 · P01/F01/F18 · 2026-10-07

HTML: selector directo Por cuotas/Compras completas junto a Vista; Filtros conserva solo cuenta/categoría y Aplicar ya no altera el criterio. Tabla de dos columnas: importe y variación juntos, conservando referencia al período comparado y neto. Plantillas se administra desde Movimientos; retirado el acceso genérico de Más, conservados selector del formulario y aviso operativo de programadas. Inicio elimina la aclaración de patrimonio (cálculo intacto) y sustituye las tres tarjetas de alta por un botón flotante que despliega Gasto/Ingreso/Transferir. Enter abre, Escape o pulsación exterior cierra; cancelar el formulario devuelve foco al botón. Contenido inferior con espacio para alcanzar la última fila sin cubrirla.

Símbolos: `app.js:render/home/homeActions/reportSummary/reportFilters/reports/more/action/submit` y manejadores change/click/keydown; `styles.css`, versión de recursos en `index.html`. Sin cambio de datos, motor o esquema. Sintaxis y **32/32 pruebas JS** correctas, comprobación temporal de indicadores/neto/anillos conservada. Navegador: tres acciones abren su tipo correcto; cancelación, foco y Escape; modo directo conserva resultados y no cambia al aplicar categoría; Plantillas sigue accesible desde Movimientos y no aparece en Más. Dos columnas y página sin desborde a 320/390/1280 px; botón flotante a 320 por encima de navegación. Consola sin errores observados. [Inicio](../prototype/cabal/evaluation/home-floating-mobile.png), [reporte](../prototype/cabal/evaluation/report-inline-mobile.png). Nueva composición pendiente de revisión visual; Android/TalkBack/texto ampliado no verificados. Flutter/Android/configuración intactos y sin APK. Copias anteriores de archivos en `/tmp/cabal-before-inline-*` para revertir presentación, sin restaurar datos.


## P05/F05/F18 · Cuotas mensuales enlazadas · 2026-10-07

**Aprobado:** intercambio de compra 1.000.000 ₲/10 cuotas → usuario autoriza preguntar primera fecha, normalmente compra → confirma «exactamente». Regla vigente en PRODUCT_BASELINE. Sustituye el selector Por cuotas/Compras completas de las revisiones históricas anteriores.

**Implementado solo en HTML:** primera fecha editable; cuotas como filas mensuales enlazadas y detalle de compra/calendario; futuras «Previstas». Presupuestos/reportes usan ese mismo calendario, sin selector de criterio. La compra completa mantiene deuda/crédito; pagos y devolución conservan sus reglas. Editar/eliminar se hace sobre la compra original, sin alterar cuotas aisladas ni generar registros financieros en segundo plano. Cancelar no guarda.

**Componentes:** `model.js:installmentStart/installmentSchedule/movementRows/validate/save/restoreBook/validateTemplate`; `app.js:composer/readDraft/updateComposer/historyRows/transactionRow/detail/installmentDetail/reports`, inicio/cuentas y acciones de edición/clonado/plantilla; estilos y versión de recursos en index. Pruebas en `model.test.js` identificadas P05/F05/F18/V02/H01.

**Datos y recuperación:** campo opcional `firstInstallmentDate` para compras nuevas; ausencia conserva calendario anterior (`firstPeriod` o primer día del mes de compra), sin migración destructiva. Filas mensuales son una proyección de lectura, no copias persistidas; backup ficticio guarda la compra canónica. Clonar/usar plantilla propone fecha actual; restaurar conserva fecha explícita y revisiones, rechaza fecha inválida antes del reemplazo. Copias previas del código en `/tmp/cabal-before-monthly-*`; cualquier reversión debe preservar el libro y el campo nuevo, no restaurar una copia antigua de datos para deshacer presentación.

**Verificado en esta pasada:** `node --check prototype/cabal/model.js`, `node --check prototype/cabal/app.js` y `node prototype/cabal/model.test.js`: **40/40 correctas** (ocho nuevas). Casos: 1.000.000/10, deuda total/pago sin duplicación, primera cuota posterior, lectura sin escritura, febrero común/bisiesto sin deriva, 101 dividido 51/50, devolución/borrado/deshacer, edición obsoleta, rechazo de fila proyectada, atomicidad ante fechas inválidas, calendario histórico y restauración. H01 queda sin corregir en Flutter.

**Navegador, datos ficticios:** alta 1.000.000/10 propone 6 octubre; historial muestra 100.000 y enlaza compra de 1.000.000. Cambiar primera fecha a 6 noviembre mueve todo el calendario; octubre sigue en gasto neto 1.973.000, deuda sube de 905.000 a 1.905.000 y noviembre muestra 300.000 (200.000 anteriores + 100.000 nuevos). Historial del reporte muestra ambas cuotas futuras previstas, sin compra duplicada. Detalle sin desborde de página a 320/390 px; consola sin errores observados. [Historial](../prototype/cabal/evaluation/monthly-installments-history.png) y [detalle](../prototype/cabal/evaluation/monthly-installments-detail.png). Diseño listo para revisión.

**Pendiente nativo:** no se modificó Flutter/Android/configuración ni se generó APK; pruebas nativas históricas no repetidas. Antes del traslado: compatibilidad del campo/calendario persistido y backup; corregir H01; luego Android real con APK del usuario: compra 1.000.000/10, primera fecha diferida, día 31/febrero, cierre/reapertura y restauración conservan deuda, cuotas y referencias; pago no duplica gasto; TalkBack y texto ampliado. HTML no demuestra cifrado, transacciones nativas, ciclo de vida ni cobro real.


## Traslado autorizado a Flutter · 2026-10-07

El usuario solicita trasladar el prototipo actual a Flutter, aprobando su experiencia como base de este bloque: cinco pestañas, anillos de presupuesto, reportes compactos, accesos sin duplicados, alta flotante, retirada CSV/JSON y cuotas mensuales enlazadas. Incluye corregir H01 y preservar calendarios/base/backups existentes. CI-01 ya aprobado: retirar solo build APK automático; no ejecutar workflow, publicar ni compilar APK. Verificación en host y casos Android separados; resultados registrados a continuación.


**Implementado y probado en host; pendiente de aceptación en Android.** Se adaptó la experiencia con Flutter/Material 3 y servicios existentes; el motor JS ficticio no se reutiliza. No hay servidor, dependencias nuevas, cambio de package ID, claves, esquema o formato de backup.

| ID | Cambio / criterio satisfecho | Componentes y evidencia |
| --- | --- | --- |
| V01/H01 | Presupuesto y reportes comparten reparto entero exacto; transacciones/ediciones de compra conservan deuda, partidas y divisiones. La edición conserva IDs de divisiones cuyas categorías siguen presentes para que corregir una nota no cambie el reparto mensual de residuos. | `BudgetService.watchProgress`, `LedgerService.update`; `installment_rounding_regression_test`, `budget_service_test`, `basic_features_test`. |
| P03/F20 | Sin rutas/pantalla/exportadores CSV/JSON; referencias importadas conservadas. | `router.dart`, `providers.dart`, `settings_screen.dart`, datos importados conservados en el backup; `backup_service_test`, `settings_menu_test`. |
| CI-01 | Eliminado únicamente build APK automático; análisis/tests conservados. | `.github/workflows/flutter.yml` inspeccionado; no ejecutado. |
| P05/F05/F07/F18 | Primera fecha elegida, día ancla mensual, resto en última cuota; historial mensual enlazado sin deuda duplicada. Edición actúa sobre compra original, futura prevista, pago no es gasto. | `InstallmentCalculator.schedule`, `InstallmentService.attachPlan`, `LedgerService.update`, `LedgerRepository.watchMovements`/`MovementRow`, formulario/detalle; `monthly_installments_test`, `installment_calculator_test`, `history_pagination_test`, `transaction_form_test`. |
| P02/F17 | Consulta de cualquier mes independiente, creación actual, anillos nombre/% y detalle al tocar; exceso rojo interior sobre base verde. | `BudgetsScreen`, `BudgetRingPainter`; `approved_analysis_test` (320 px lógicos, texto 2x, claro/oscuro, detalle y retorno). |
| P01/F01/F07/F10/F18 | Cinco ramas conservan estado; Inicio con patrimonio/cuentas y FAB; listado de Cuentas por tipo y ficha con saldo, alias, crédito/pago y administración; Plantillas solo en Movimientos, Programadas como filtro; reporte de dos columnas, flecha/% junto al importe, Neto debajo, filtros Aplicar/Cancelar y cinco vistas. | `router.dart`, `DashboardScreen`, `AccountsScreen`, `AnalysisScreen`, `TransactionsScreen`, `TemplatesScreen`, `ReportsScreen`, `AppTheme`; `approved_analysis_test`, `approved_accounts_test` (320/texto 2x y segunda tarjeta), `reports_screen_test`, `history_pagination_test`. |
| P04/F14/F21/F22 | Más simplificado, Wallet/acceso y automatización separados, aviso portable de contraseña/destino, información sin accesos repetidos. | `SettingsScreen`, `WalletSettingsScreen`; `wallet_settings_test`, `backup_picker_test`. |
| V02 | Restaurar conserva calendarios y metadatos; invalida borradores anteriores antes de crear movimiento/plantilla. Salir de un formulario modificado solicita descarte; cancelar conserva el borrador. | `AppDatabase.restoreGeneration`, `BackupService.restore`, formulario; `backup_service_test`, `monthly_installments_test`, `transaction_form_test`. |
| V03/F23 | Barreras de desarrollo, Wallet normal opcional y programados conservados. | Suite de Wallet/programados/desarrollo; sin cambios Kotlin ni puente nativo. Listener/profile/release reales pendientes. |

**Compatibilidad y recuperación:** esquema y `.finbackup` v1 intactos; fechas antiguas se leen sin recalcular y se conservan al editar otros campos. Compras nuevas guardan la fecha completa en columnas existentes. No hay migración destructiva ni cuotas duplicadas persistidas. Edición financiera y plan comparten transacción; error revierte todo. Antes de actualizar una instalación real, conservar backup portable verificado. Revertir presentación no debe restaurar datos antiguos; una versión vieja puede volver a presentar compras completas y no debe editar planes nuevos sin revisar su compatibilidad. 

**Validación y límites:** resultados finales abajo. Inspección de fuentes, host y widgets no acreditan Android real. El navegador y sus capturas citados arriba corresponden a la fase HTML; no se repitieron aquí ni representan Flutter. Guías de calidad Android, testing y accesibilidad Flutter reconsultadas el 2026-10-07; aplicadas a estados, etiquetas, controles Material y texto ampliado. MASVS/MASTG/WCAG siguen como referencias de la investigación previa, sin declaración de conformidad integral. No hay nueva auditoría criptográfica ni prueba de claves/listener/SAF/ciclo de vida.

**Android pendiente, APK del usuario:** cinco pestañas y retorno con mes/filtros; FAB/teclado/TalkBack/texto ampliado/tema oscuro; compra 1.000.000/10 y primera fecha diferida, día 31/febrero, deuda completa y pago sin duplicación; base histórica y backup/restauración conservando calendario y descartando borradores; consentimiento/revocación Wallet y barreras de desarrollo. Procedimiento completo en [DEVELOPMENT](DEVELOPMENT.md#verificación-android-pendiente). V01–V03 no se cierran integralmente hasta obtener esa evidencia. P07–P09 no se implementaron.


**Resultados finales de esta sesión · 2026-10-07:**

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: **159/159** correctas, sin omisiones. Incluye redondeo exacto y estable al editar, cuotas/calendarios, conflictos, rollback, backup/restauración, descarte de borrador, navegación y widgets con texto ampliado.
- `flutter test --no-pub --dart-define-from-file=config/development.json test/features/developer_tools/developer_tools_test.dart`: **8/8** correctas. No acredita barreras de binarios Android profile/release.
- `node --check prototype/cabal/app.js`, `node --check prototype/cabal/model.js` y `node prototype/cabal/model.test.js`: sintaxis correcta, **40/40**. HTML/JS/CSS no cambiaron en este traslado.
- Enlaces locales de los documentos afectados: destinos existentes. Fuentes Kotlin, configuración Android y esquema generado sin cambios propios; no se compilaron APKs, ejecutaron pruebas en dispositivo ni dispararon workflows.

Los tests de backup emiten la advertencia Drift sobre múltiples instancias usada en sus fixtures; terminan correctamente. Los resultados anteriores fallidos de desarrollo no se cuentan como aceptación; la suite final completa es la indicada aquí. Capturas HTML previas son evidencia histórica. Android real continúa pendiente.

## Ajustes tras revisión Android · 2026-10-07

**Autorización:** solicitudes del usuario sobre capturas de Android: edición/repetición de presupuestos, banner como HTML, tres botones flotantes en Inicio y Movimientos e investigación de Wallet. Respuesta trazable a la consulta de edición: «Ese mes y los siguientes (recomendado)». No se incorporan otras propuestas.

- **P02/F17:** `BudgetService.create/edit/ensureCurrentMonth`, `BudgetsScreen`: editar desde el detalle; nombre, objetivo entero, categoría y repetición opcional. Guardar cambia mes seleccionado y miembros posteriores de su serie; anteriores e IDs se conservan. Cancelar no escribe. Copia del mes actual al abrir/volver o entrar en Análisis; ID estable evita duplicados concurrentes, sin rellenar meses no abiertos ni ejecutar tareas con app cerrada. Desactivar repetición detiene nuevas copias y conserva las existentes. Categoría archivada impide nuevas copias hasta corregirla; errores visibles y reintentables. Conflicto de edición/restauración rechaza borrador obsoleto; presupuesto/plantilla se escriben en una transacción.
- **P01/F01/F07:** `MovementFab`, `DashboardScreen`, `TransactionsScreen`: un «+» despliega Gasto, Ingreso, Transferir; selección abre el formulario correspondiente; volver, Escape o tocar fuera cierra sin escribir. Inicio usa verde profundo, cifra blanca y adorno discreto del HTML, sin cambiar cálculo patrimonial. Corrección de desborde del encabezado con texto ampliado. `MoneyText` permite símbolo ₲ en ese banner; el resto mantiene su formato.
- **P04/F14:** `WalletSettingsScreen`: error de carga con Reintentar, controles desactivados mientras faltan preferencias; fallo al abrir ajustes recuperable. Botón de acceso Android adaptable a texto ampliado. Esto no acredita resolución del ANR. Investigación de registros históricos del teléfono y límites en [DEVELOPMENT](DEVELOPMENT.md#bloqueo-de-wallet-con-depurador--2026-10-07).

**Datos/compatibilidad:** sin cambio de esquema, dependencia, claves, identidad de instalación o formato `.finbackup`. Plantillas versionadas en `app_settings` bajo `budget_template:<ID>`; backup cifrado existente las incluye. Meses son registros de presupuesto, sin movimientos/partidas financieras nuevos. Restaurar conserva serie y evita duplicados. Una versión anterior ignora la repetición y puede editar meses sin propagar cambios: preferir recuperación transaccional/backup comprobado frente a editar series con una versión vieja; no restaurar datos antiguos para deshacer presentación. Ningún dato personal de las capturas se convirtió en fixture.

**Verificación:** resultados finales de esta revisión a continuación. Casos nuevos: concurrencia/idempotencia, cambio desde un mes intermedio, pausa, categoría archivada, borrador obsoleto, rollback de plantilla y backup cifrado/restauración; formulario Guardar/Cancelar; tres rutas de FAB en ambas pantallas, volver/Escape/exterior; Wallet con fallo simulado y texto 2x. Capturas aportadas son evidencia del comportamiento anterior, no del código nuevo. Sin ejecución nueva en navegador ni verificación funcional Android de estos cambios. Kotlin/configuración/prototipo no modificados en este bloque; no se compiló, instaló ni generó APK.

**Resultados finales del bloque:** `flutter analyze --no-pub`: sin incidencias; `flutter test --no-pub`: **170/170** correctas (11 regresiones nuevas); suite de desarrollo con `config/development.json`: **8/8** correctas. 107 enlaces locales de PRODUCT_BASELINE, ROADMAP, IMPLEMENTATION_PLAN y DEVELOPMENT con destinos existentes; anclas nuevas contrastadas con sus encabezados. No se repitieron las pruebas JS porque el prototipo no cambió. Evidencia Android obtenida: inspección de ANR históricos; comportamiento del código nuevo en dispositivo todavía pendiente.

## Cierre de revisión HTML posterior · 2026-10-07

El usuario acepta el resultado («creo que ya está») y solicita actualizar documentación. Se asientan las decisiones en [PRODUCT_BASELINE](PRODUCT_BASELINE.md#prototipo-revisado-y-aceptado--2026-10-07), estado actual y diferencias nativas en [PROTOTYPE_STATUS](PROTOTYPE_STATUS.md). Esta sección sucede al traslado Flutter anterior; no declara que las modificaciones HTML posteriores estén trasladadas.

**Cambios finales:** gasto único con En cuotas/Descripción, tres opciones del FAB, selector de categoría única excluyente del reparto, pendientes sin descuento y pagos efectivos separados, divisiones exactas de planes, recordatorios simulados; Inicio sin listas duplicadas, tarjetas en Cuentas, FAB consistentes, raíces sin títulos redundantes; anillos normalizados verde/rojo con pendientes suaves, sin rayado/leyenda.

**Verificación registrada:** ciclo funcional, ciclos visuales indexados en el estado y última tanda. Última regresión: 57 pruebas financieras y 9 de anillos correctas. Navegador: plan dividido100.001 en tres cuotas conserva saldo; crédito120.000/3; rechazo de 121 cuotas; recordatorios/borrador tras alta de categoría; estados/capturas a 320/390/1280. Evaluación independiente final sin defectos relevantes confirmados, sin navegador propio; no acredita segunda ejecución interactiva.

**Pendiente:** contrastar/trasladar las diferencias con Flutter solo bajo un encargo de implementación; verificar Android real, permisos/notificaciones, ciclo de vida, base/backup, TalkBack y teclado. SMS por ejemplos es dirección posterior, no función implementada o fuente normal aprobada. Backups periódicos siguen como propuesta. Esta actualización es documental; sin código Flutter, pruebas nativas repetidas ni APK.

## Traslado de la revisión final aceptada · 2026-10-08

Encargo explícito posterior: verificar documentación/prototipo, portar decisiones aprobadas a Flutter/Dart mediante Superpowers y evaluación independiente, conservando datos e integraciones; no tocar HTML ni generar APK. La comparación previa y los criterios están en el plan detallado.

El código incorpora obligaciones no crédito y pagos reales separados, parciales con traslado, plantillas que preparan pendientes, configuración de recordatorios y agenda Android cifrada. Crédito conserva su deuda/calendario. Inicio, tarjetas de Cuentas, formularios, FAB y anillos reflejan la revisión aceptada; no se trasladan limitaciones ficticias del HTML a edición/repetición nativa existente. Wallet conserva su integración normal y SMS sigue experimental.

La evidencia vigente, las correcciones por revisión y lo que aún requiere Android están en [el informe Flutter](evaluation/flutter-port-2026-10-07/REPORT.md). Ese informe distingue pruebas Dart/widget, renderizado Flutter con datos sintéticos, compilación directa Kotlin y pruebas del sistema Android aún no realizadas. Los resultados anteriores de este documento son históricos y no certifican los cambios posteriores.

### Cierre efectivo del traslado · 2026-10-09

249/249 pruebas Flutter, análisis limpio y revisión independiente global cerrada tras correcciones dirigidas de Wallet/pagos enlazados. Insets móviles y tarjetas compactas verificados en host. APK profile compilado por petición explícita, firma/identificador conservados y herramientas de desarrollo desactivadas; no instalado. [Informe, artefacto y límites](evaluation/flutter-port-2026-10-07/REPORT.md). El bloqueo al abrir y recorridos nativos permanecen pendientes de reproducción Android.

## Unificación de pendientes · pasos 1–3 · 2026-10-10

Aprobados en [PRODUCT_BASELINE](PRODUCT_BASELINE.md#unificación-de-pendientes--aprobación-explícita-2026-10-10); sin APK, esquema, backup ni dependencias nuevas.

1. **Pagar después.** En gasto sin tarjeta de crédito, interruptor «Pagar después» con fecha y recordatorios; «En cuotas» solo aparece dentro de él. Sin cuotas crea un pendiente único (`PendingPaymentService.createPlan`, 1 cuota); no mueve saldo hasta pagar. `transaction_form_screen.dart` (`_pendingOn`, `_installmentsOn`).
2. **Calculador común.** `evenInstallmentAmounts` y `monthlyAnchorDate` en `installment_calculator.dart`, usados por cuotas de crédito y pendientes; comportamiento sin cambios.
3. **Repetir.** Con «Pagar después» sin cuotas, «Repetir» (No repetir / Mensual / Anual) guarda una plantilla programada (`manual_template:`) con la fecha elegida y ejecuta `processDue`, que prepara los pendientes. Las plantillas manuales y las cuotas de crédito no cambian.

Pruebas de host: `flutter analyze` limpio, 254 pruebas sin fallos (nuevas: pendiente único, Repetir, reparto/ancla). Pruebas existentes de cuotas sin crédito ajustadas para pasar por «Pagar después». **Android pendiente:** crear «Internet» pendiente la semana próxima con recordatorio, pagarlo y repetirlo mensual; comprobar que no se duplican vencimientos y que las cuotas de tarjeta siguen igual.

## Corrección: Hero duplicado en botones flotantes · 2026-10-10

Pausa del depurador reportada por el usuario al abrir «Nuevo movimiento»: `FlutterError: There are multiple heroes that share the same tag within a subtree` (tag `<default FloatingActionButton tag>`). Causa: las cinco ramas de navegación conservan sus pantallas y los botones de Presupuestos, Cuentas, Catálogo y Plantillas usaban el tag Hero por defecto junto al de Inicio. Corrección: `heroTag: null` en esos botones. Prueba de regresión `test/shared/fab_hero_tag_test.dart` (ningún `FloatingActionButton` sin `heroTag`); 255 pruebas, análisis limpio. Android pendiente de confirmar.

## Corrección: pantalla de error al tocar un aviso · 2026-10-10

Al tocar un recordatorio en arranque en frío aparecía un instante una pantalla de error. El aviso abre `MainActivity` con el dato `cabal-reminder://open/…`; Flutter lo entrega al router como ubicación inicial y go_router no encuentra esa ruta. Corrección: `flutter_deeplinking_enabled=false` en `AndroidManifest.xml` y redirección de respaldo en `router.dart` (`cabal-reminder` → `/start`); la apertura del detalle sigue yendo por `consumeOpenAction`. Regresión: `test/app/reminder_deeplink_test.dart` (falla sin la redirección); 256 pruebas, análisis limpio. Android pendiente de confirmar.

## Detalle de pago: importe fuera de `build` · 2026-10-10

`PaymentDetailScreen` asignaba el controlador del importe durante `build` al cambiar la revisión. Tras la primera carga se difiere a un callback posterior al cuadro; la primera carga queda igual. Cubierto por la prueba de pago parcial (importe restante `60.000` tras confirmar). Sin cambios de comportamiento observables.

## Selector «Cuándo» · 2026-10-10

Aprobado por el usuario. Sustituye los interruptores «Pagar después» y «En cuotas» por un selector único en «Más detalles»; tarjeta solo Ahora/En cuotas. Pruebas de formulario ajustadas (`chooseWhen`); 256 pruebas, análisis limpio. Verificar en Android: gasto simple, pendiente único con recordatorio, cuotas sin crédito y cuotas con tarjeta.
