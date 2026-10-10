# Base funcional y decisiones de producto

Decisiones asentadas hasta 2026-10-10. Este documento conserva las decisiones aprobadas y su contexto de autorización. El estado actual y las prioridades están en [ROADMAP.md](ROADMAP.md); los procedimientos, en [DEVELOPMENT.md](DEVELOPMENT.md).

## Diseño revisado y aceptado · 2026-10-07

El usuario dio por terminada la revisión del diseño («creo que ya está») y autorizó expresamente trasladarlo a Flutter/Dart, conservando las integraciones reales. Estas decisiones prevalecen sobre las presentaciones y exclusiones anteriores incompatibles y están implementadas en Flutter.

- **Registro unificado:** Gasto incluye «En cuotas», cantidad y primera fecha; no hay una opción independiente «Compra en cuotas» en el menú de movimientos. «Descripción» admite servicios y gastos generales. Crédito conserva deuda total y calendario mensual; las demás cuentas preparan cuotas pendientes y solo descuentan dinero al confirmar cada pago. El formulario cambia los campos pertinentes según el medio de pago.
- **Pendiente y pago son distintos:** importe previsto, vencimiento y vínculo con el gasto se conservan por separado de importe pagado, fecha efectiva y cuenta elegida. Se propone la cuenta anterior y puede cambiarse. Vencer, recibir o descartar un aviso no confirma pagos. La deuda completa pendiente afecta patrimonio financiero; el disponible refleja las cuentas incluidas y pagos efectivos.
- **Pagos parciales:** registrar lo efectivamente pagado. El resto puede trasladarse a la siguiente cuota existente del mismo plan, con trazabilidad y sin duplicar deuda; si no se traslada, sigue pendiente. No se inventa una siguiente cuota cuando no existe. Editar pendientes futuros conserva los pagos anteriores; no convertir automáticamente un gasto ya registrado en un nuevo plan pendiente.
- **Plantillas programadas:** la experiencia aprobada prepara gastos pendientes de pago en lugar de asumir que se pagaron. Confirmación y recordatorios siguen el mismo criterio que las cuotas. Sustituye la propuesta anterior de registrar automáticamente un gasto como ya pagado por llegar su fecha; no cambia la autorización independiente del registro de compras reconocidas por Wallet.
- **Recordatorios:** tres días antes y el día del vencimiento, a las 09:00 por defecto; editables/desactivables. Aviso para revisar y confirmar pago, no confirmación automática. La notificación del sistema, los permisos, la programación y el comportamiento con la app cerrada son nativos de Android.
- **Categorías:** asignación única y reparto usan el mismo catálogo. Activar «Dividir entre categorías» oculta y deshabilita el selector único; no mostrar simultáneamente ambas formas activas. Las divisiones de cuotas conservan exactamente el total por categoría.
- **Inicio y navegación:** Inicio prioriza disponible, pendiente del mes, patrimonio y próximos pagos; se retiran listas de cuentas y movimientos que duplicaban las pestañas. Cuentas adopta el diseño de tarjetas preferido de Inicio. Sin títulos que repitan el destino en las cinco pestañas raíz; los detalles conservan título y Volver, con acciones accesibles.
- **Altas flotantes:** Inicio y Movimientos comparten un «+» que despliega botones flotantes individuales para Gasto, Ingreso y Transferir. Cuentas y Presupuestos usan el mismo FAB para abrir directamente su alta. Sin panel de opciones ni franja vacía reservada; cierre por Escape/exterior/salida de foco y retorno visible al botón.
- **Presupuestos:** el anillo ajusta su escala cuando el consumo supera el objetivo: a 300%, un tercio dentro del objetivo y dos tercios de exceso. Verde dentro y rojo para exceso; pagado con color pleno y pendiente con tono suave, sin rayado ni leyenda explicativa. A 250% totalmente pendiente, 40% del anillo es verde suave y 60% rojo suave. Porcentaje central real; importes disponibles en detalle y etiquetas accesibles.
- **Orden posterior:** primero cuotas y recordatorios. Reconocimiento flexible a partir de ejemplos de SMS bancarios queda para una fase posterior por definir; notificaciones de otras apps más adelante. No habilitar SMS como función normal ni ampliar las fuentes por esta aceptación.

## Entrega y correcciones solicitadas · 2026-10-08/09

El usuario autorizó expresamente continuar, corregir insets superiores/altura de tarjetas en Cuentas, investigar lentitud y compilar/entregar APK. Esto sustituye para esta entrega la restricción anterior de no compilar; no autoriza builds automáticos futuros. Cuentas conserva acciones en detalle y tarjetas compactas. Se prepara profile AOT, con firma debug existente y herramientas de desarrollo desactivadas, al no haber firma release configurada. Los controles Wallet reconocen tanto residual previsto como pagos efectivos enlazados para evitar duplicados; no se amplían fuentes ni la heurística de movimientos manuales arbitrarios. El bloqueo al abrir se verificó en Android el 2026-10-10 y ya no se reproduce.

## Unificación de pendientes · aprobación explícita 2026-10-10

El usuario aprueba los pasos 1–3 de la propuesta de unificación: (1) pago pendiente único con fecha y recordatorio («Pagar después»), independiente de las cuotas; (2) calculador común de reparto entero y fechas mensuales para cuotas de crédito y pendientes; (3) plantilla programada presentada como «Repetir» de un pendiente. Se conservan el modelo de cuotas de crédito, el almacenamiento, el esquema v1, el backup y las plantillas manuales. Verificados por el usuario en Android el 2026-10-10: V01 y V02.

## Cuotas mensuales · aprobación explícita 2026-10-07

El usuario confirmó «exactamente» después de precisar la compra de 1.000.000 ₲ en diez cuotas y la elección de primera fecha. Sustituye la regla anterior de inicio obligatorio en mes de compra y el selector de reportes por compras completas/cuotas.

- Preguntar la fecha de primera cuota, proponiendo la fecha de compra. Repetir mensualmente el mismo día; si no existe, usar el último día de ese mes y conservar el día original para los siguientes.
- La compra compromete todo el crédito inmediatamente. Los movimientos muestran cada cuota enlazada con su compra original; presupuestos y reportes cuentan la cuota en su fecha, sin otro modo de cálculo ni duplicar la compra o el pago de tarjeta.
- Las cuotas futuras se identifican como previstas; no acreditan un cobro bancario ni requieren tareas con la app cerrada. Las devoluciones conservan su fecha y no reescriben cuotas futuras.
- Preservar calendarios históricos. Sin mínimo/extracto calculado, intereses ni nueva integración bancaria. Traslado a Flutter autorizado explícitamente el 2026-10-07 por «mueve el prototipo a flutter»; verificado en Android el 2026-10-10 (V01), sin APK automático.

## Ajustes aprobados · 2026-10-07

A partir de las capturas y solicitudes del usuario: editar nombre/objetivo de presupuestos y permitir repetición mensual; recuperar la apariencia del banner en Inicio; un botón flotante que despliega Gasto, Ingreso y Transferir tanto en Inicio como en Movimientos. Investigar el bloqueo al entrar a Wallet con depuración Wi-Fi, sin compilar APK.

En la consulta explícita sobre edición recurrente eligió **«Ese mes y los siguientes»**. Los meses anteriores se conservan. La repetición es opcional; la copia del mes se prepara al abrir/volver a la app, sin tareas con la app cerrada.

## Decisiones de continuación · 2026-10-06

Aprobadas explícitamente por el usuario después de revisar las seis opciones resumidas. Cabal es para su uso personal; no se requiere plan de publicación ni definir una primera versión pública.

- Trasladar a Flutter las cinco pestañas del diseño aprobado: Inicio, Movimientos, Cuentas, Análisis y Más. Conservar acceso a Presupuestos y a las funciones actuales que siguen en alcance.
- Permitir consultar presupuestos de otros meses. La exclusión inicial de recurrencia fue sustituida por la aprobación del 2026-10-07, registrada arriba.
- Retirar importación/exportación CSV y exportación JSON del producto. Se descarta ampliar mapeo/lotes/reversión CSV. Conservar el backup cifrado y la restauración; retirar funciones no autoriza borrar movimientos o referencias de importaciones existentes.
- Regla inicial de cuotas desde mes de compra, sustituida por la aprobación del 2026-10-07; sigue sin cálculo de mínimos ni extractos.
- Mantener Wallet opcional. La propuesta de advertir sobre CSV/JSON legibles queda sin aplicación al retirarlos; conservar información clara sobre Wallet y backups.
- Quitar la compilación automática de APK en CI; el usuario genera los APK.

Estas decisiones sustituyen las propuestas anteriores incompatibles. Este intercambio aprobó alcance; la implementación Flutter fue autorizada posteriormente el 2026-10-07.

## Decisiones ya asentadas

- **Textos de interfaz · 2026-10-07:** eliminar subtítulos, bajadas y textos explicativos en Flutter. No basta con acortarlos ni trasladarlos a ayudas bajo demanda. El usuario indicará explícitamente qué explicaciones necesita; no agregarlas por iniciativa propia. Esta decisión sustituye el criterio anterior de conservar ayudas explicativas desplegables por defecto. Se registra como preferencia aprobada; este cambio documental no acredita su aplicación a todas las pantallas.

- Nombre aprobado: **Cabal**, con ícono geométrico en verde profundo, menta y jade. Se conserva el identificador de instalación y los nombres internos de almacenamiento para mantener compatibles las actualizaciones y los datos existentes.

- Cada usuario ingresa sus propias cuentas, nombres, saldos y datos de tarjeta. No se precargan bancos ni alias personales.
- La configuración puede terminar sin cuentas; se necesita una para registrar movimientos.
- Los datos y cálculos centrales quedan en el dispositivo, sin cuenta de usuario ni servidor.
- La base activa y la cola se cifran con una clave automática protegida por Android Keystore; no se pide otra contraseña al abrir. El backup portable conserva su contraseña independiente.
- La restauración reemplaza todos los datos por los del backup tras validar integridad, esquema y referencias. Guarda un respaldo cifrado previo, usa rollback transaccional ante fallos y no requiere cerrar/reabrir la app.
- PYG es la moneda inicial soportada por la interfaz; los importes se almacenan como enteros. Los campos de propuestas, movimientos nuevos y divisiones muestran separadores de miles mientras se escribe.
- «Descartar» una propuesta conserva su estado ignorado y la oculta de pendientes; no crea ni elimina movimientos y no borra la notificación de Android.
- La bandeja muestra estados de reconocimiento de cuenta y comercio en lugar de porcentajes de confianza por reglas.
- Las propuestas tienen una única acción «Revisar», con importe, comercio, categoría y cuenta en el mismo formulario. «Registrar gasto» confirma los cambios y el movimiento en una transacción; cancelar no modifica la propuesta. El canal sigue en «Más detalles» del registro manual y se determina por la fuente en compras detectadas.
- La carga manual de gastos sugiere comercios activos por nombre y alias normalizados; elegir una sugerencia usa el comercio existente. Se pueden ingresar nombres nuevos.
- Al confirmar una compra o guardar un gasto manual con una sola categoría, se recuerda la categoría elegida para ese comercio. Elegir «Sin categoría» elimina esa preferencia; dividir un gasto no la reemplaza. Se sugiere al seleccionar el comercio y se usa en compras automáticas posteriores; categorías archivadas se omiten y no se modifican compras anteriores.
- Transferencias y pagos de tarjeta no se contabilizan como nuevos gastos.
- El canal manual se simplifica a Efectivo, Tarjeta física, Google Wallet, Pago online, Transferencia y Otro. Los canales antiguos se conservan legibles y al clonar se normalizan a Tarjeta física. En gastos/ingresos, solo cuentas de efectivo admiten Efectivo; esas cuentas excluyen tarjeta, Wallet, pago online y transferencia. Las transferencias entre cuentas admiten Transferencia u Otro, salvo efectivo a efectivo (Efectivo u Otro). Las tarjetas de crédito no admiten Transferencia como canal de compra. Se filtra en el formulario y se valida al crear un movimiento, sin modificar registros históricos.
- Una compra con tarjeta aumenta la deuda; su pago la reduce.
- Ahorro se mantiene como cuenta utilizable de origen o destino y suma al patrimonio. Se excluye del dinero disponible por defecto, con una opción explícita al crearla y en Cuentas para incluirla o excluirla después. Esa opción no modifica su saldo.
- Inicio muestra una tarjeta compacta de «Patrimonio total»: suma los saldos incluidos en patrimonio, incluidos los ahorros, y resta la deuda de crédito. No hay menú de resumen ni selector de ahorros; la antigua preferencia del selector no afecta al total. Tocar una cuenta en Inicio abre sus acciones: «Ver movimientos» y «Administrar» para esa cuenta, y «Pagar tarjeta» como primera acción si es de crédito.

- Plantillas personalizables: crear desde el formulario o la lista, usar, editar y eliminar/deshacer. Guardan tipo, cuentas, comercio, categoría/divisiones, canal, nota y opciones de cuotas; el importe manual es opcional. Usarlas manualmente abre un formulario con fecha actual. Se guardan dentro de la base cifrada y forman parte del backup. Desde Nuevo movimiento, «Usar plantilla» permite elegirla y acceder a su administración. Se muestran primero las del tipo de movimiento actual, manteniendo accesibles los demás tipos, y se indica frecuencia, próxima fecha o estado pendiente/pausado. «Recordar importe» permite dejar el importe vacío para usos manuales futuros; las automáticas requieren importe fijo. «Guardar también como plantilla» guarda el movimiento y la plantilla juntos, con reversión completa si falla. La creación/edición independiente en administración no crea comercios, asociaciones ni movimientos. Inicio conserva solo el aviso de registros programados pendientes.
- Registro programado opcional, desactivado por defecto: gastos de importe fijo, sin plan de cuotas, frecuencia mensual o anual y próxima fecha. Se procesa al abrir/volver a la app y recupera vencimientos atrasados, con un máximo de 120 por plantilla en cada pasada. Se conserva el día original al ajustar fin de mes o años no bisiestos. Al guardar una nueva plantilla junto con un movimiento, la próxima fecha propuesta es la siguiente repetición; si se elige la misma fecha, ese movimiento consume el vencimiento. Movimiento y avance de fecha se guardan juntos; cada plantilla/fecha se registra una vez incluso si se elimina después el movimiento.
- Los registros programados se identifican como «Programado» y no acreditan un cobro real. Conflictos de cuenta, categoría, comercio o canal quedan pendientes en Plantillas, donde se puede editar, pausar u omitir un vencimiento. Inicio muestra el número pendiente y se informa qué se registró al procesar.
- Coincidencias de cuenta, comercio e importe con movimientos o notificaciones en una ventana de tres días se revisan antes de duplicar una suscripción. Wallet posterior a un registro programado queda pendiente aunque la automatización de Wallet esté activa. La coincidencia es una precaución por reglas; no prueba que sea la misma compra. Importes variables siguen siendo plantillas manuales; no se registran solos.
- Se eliminan las plantillas fijas del menú de Nuevo movimiento. «Pagar tarjeta» permanece en la pantalla de la tarjeta correspondiente y en sus acciones desde Inicio.
- En cuotas, la compra completa compromete el crédito y cada cuota afecta movimientos, presupuesto y reportes de su período. La elección anterior de compras completas/cuotas fue sustituida por la aprobación del 2026-10-07.
- Google Wallet y la opción de registro automático están en Configuración normal, ambos desactivados inicialmente.
- Con automatización activada, solo compras con importe válido, cuenta activa única y comercio único reconocido pueden registrarse sin confirmar. Los casos nuevos, ambiguos, actualizados o posiblemente duplicados quedan pendientes.
- Las asociaciones de cuenta y comercio se aprenden al confirmar y son independientes: no se necesita aprender cada combinación.
- Los comercios se reconocen por nombres o alias exactos normalizados; nombres diferentes solo se asocian tras elección del usuario. La categoría es opcional; solo se asigna automáticamente una preferencia aprendida de ese comercio.
- El acceso a la bandeja muestra el número de propuestas pendientes y la pestaña Inicio solo un punto; al confirmar o ignorar se actualiza y se oculta si no queda ninguna.
- No se emiten avisos del sistema para revisar compras. La cola se procesa al abrir/volver a la app, al llegar capturas con la app visible o al actualizar la bandeja interna; no se registra en una tarea de fondo con la app cerrada.
- El simulador de desarrollo emite notificaciones locales de esta app marcadas PRUEBA, con comercios editables y montos variables, y usa el recorrido de captura real. Sus movimientos y asociaciones afectan esta instalación y están identificados como pruebas.
- Sin coincidencia única se exige seleccionar una cuenta; si no hay cuentas, se permite crear una. Wallet solo sugiere cuentas activas con un alias único; no elige la primera tarjeta.
- Las compras de Wallet confirmadas guardan el identificador detectado como alias local de la cuenta elegida, sin duplicar un alias equivalente ya existente en ella. No se vincula ni accede a la cuenta de Google. Las coincidencias ambiguas siguen exigiendo selección.
- Herramientas de desarrollo: carpeta y menú propios, bandera de compilación y bloqueo en release/profile.
- El usuario genera los APK desde VSCodium; el asistente ejecuta análisis y pruebas pertinentes.

## Funciones básicas completadas · 2026-10-04

Alcance autorizado: las seis funciones básicas del roadmap; las secundarias y futuras no forman parte de este bloque.

- **Edición de movimientos:** gastos, ingresos y transferencias conservan identidad, fuente y datos de deduplicación. Se pueden corregir importe, fecha, cuentas, comercio, nota, canal, categorías/divisiones y cuotas. Se recalculan partidas y plan en una transacción; una revisión antigua no sobrescribe una edición posterior. No se cambia tipo ni moneda. Referencias históricas archivadas pueden conservarse. Devoluciones y ajustes se corrigen eliminando y creando otro registro.
- **Administración de cuentas:** edición de nombre, alias y datos de crédito; archivo/reactivación sin borrar historial. Tipo, moneda y saldo inicial se conservan; el saldo actual se corrige con conciliación. Archivar excluye la cuenta de selección y resumen de cuentas activas.
- **Comercios, categorías y asociaciones:** renombrar, crear, archivar/reactivar y administrar alias desde Configuración → Comercios, categorías y asociaciones. Archivar no altera movimientos anteriores. Los alias pueden eliminarse o reasignarse explícitamente; agregar un alias no desplaza silenciosamente el de otro elemento. Los alias de cuenta ambiguos se muestran como conflictos.
- **Historial:** búsqueda literal por comercio/nota y filtros combinables por cuenta, comercio, categoría, tipo y período, manteniendo paginación. Cuentas y comercios permiten abrir su historial filtrado.
- **Conciliación:** se registra la diferencia entre saldo real y registrado como un ajuste separado. Crédito usa su saldo natural de deuda y admite saldo a favor. Si el saldo cambió mientras se completaba el formulario, se pide volver a intentarlo. Ajustes quedan fuera de ingresos, gastos y presupuestos.
- **Devoluciones:** movimiento vinculado a una compra confirmada, a su cuenta y moneda; devuelve fondos o reduce deuda. No puede ser anterior a la compra ni superar lo comprado entre todas las devoluciones activas. Conserva categorías proporcionales con reparto entero exacto. Reduce consumo en el período de devolución; no reescribe la compra ni el calendario de cuotas. Para eliminar una compra con devoluciones se eliminan primero sus devoluciones. El deshacer revalida el límite.
- **Reportes:** cinco vistas (Resumen, Evolución, Categorías, Comercios y Cuentas), navegación por mes o período personalizado, filtros compartidos por cuenta y categoría (incluidas archivadas), consumo por cuotas mensuales del período (criterio único aprobado el 2026-10-07). Resumen compara con el mes anterior real o con el período anterior de igual cantidad de días. Evolución muestra seis meses para un mes seleccionado y los meses del rango para períodos personalizados, incluyendo ceros y extremos parciales. Rankings usan gasto bruto para sus porcentajes; las devoluciones y el neto se muestran por separado. Los desgloses abren el historial filtrado; el historial muestra el importe de cada cuota del período enlazada a la compra completa. El reparto entero de cuotas conserva exactamente los totales por categoría del plan completo. Devoluciones se muestran separadas y se restan sin ocultar un neto negativo. Transferencias, pagos de tarjeta y ajustes quedan excluidos. Presupuestos se actualizan con ediciones, devoluciones y eliminación/deshacer.

- **Accesos de administración:** Configuración incluye Plantillas y Movimientos programados. El segundo acceso filtra las plantillas con programación activa, pausada o pendiente; conserva las acciones de edición, pausa y omisión de vencimientos.

## Estado y brechas

La matriz principal es [ROADMAP.md](ROADMAP.md): F01–F25 lista las capacidades con su verificación en Android, V03 es la verificación pendiente y P07–P09 son las propuestas sin aprobar. No se mantiene otra tabla de implementación aquí.

## Propuestas pendientes y comprobaciones abiertas

Los puntos 2–6 mezclaban decisiones ya tomadas con validaciones pendientes: se conservan para contexto, sin reabrir las reglas aprobadas anteriores. Las comprobaciones no autorizan ampliar alcance.

1. **Primera versión:** propuesta de alcance: registro manual, cuentas, tarjetas, presupuestos, reporte simple y backup. Wallet ya está autorizado en uso normal; SMS sigue experimental.
2. **Gestión del enlace con Wallet:** edición/eliminación y reasignación de alias implementadas. Falta validar la gestión de conflictos con identificadores reales adicionales.
3. **Tarjetas virtuales y fuentes distintas:** validar identificadores reales de Wallet y extender el criterio de coincidencia única a las demás fuentes experimentales.
4. **Configuración de cuentas:** edición y archivo implementados. Tipo, moneda y saldo inicial quedan fijos; los alias compartidos requieren resolución explícita.
5. **Movimiento detectado:** edición posterior implementada conservando fuente e identidad. La categoría opcional y la preferencia por comercio ya están aprobadas e implementadas.
6. **Cuotas y reportes:** elección histórica sustituida el 2026-10-07 por calendario mensual único. Devoluciones impactan su fecha real y no modifican cuotas futuras.
7. **Ahorro a futuro:** el usuario propone plazo corto/largo e interés como una función posterior. Falta definir tasa, período, capitalización, vencimiento y tratamiento de intereses reales frente a proyecciones antes de implementarla. La inclusión opcional de ahorros en dinero disponible ya está aprobada e implementada.
8. **Seguridad:** el cifrado local con clave automática está aprobado e implementado. Falta validar recuperación ante pérdida de claves y acordar exportaciones legibles y limpieza del diagnóstico antes de publicar. El bloqueo de pantalla y el cifrado siguen siendo funciones distintas.
9. **Privacidad:** acordar divulgación y consentimiento antes de leer notificaciones, fuentes permitidas y cómo revocar el acceso.
10. **Monedas:** mantener PYG para la primera versión o definir soporte real de múltiples monedas y conversiones.

## Continuación

Ver el [roadmap](ROADMAP.md). Las ampliaciones siguen requiriendo aprobación explícita del usuario.
