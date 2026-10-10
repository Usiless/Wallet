# Prompt maestro: aplicación Android de finanzas personales local-first en Flutter/Dart

## Rol y objetivo

Actuá como arquitecto de software y desarrollador senior especializado en Flutter, Dart, Android nativo, SQLite y aplicaciones financieras personales. Diseñá e implementá una aplicación Android de calidad de producción para administrar finanzas personales. No construyas una demo descartable ni una colección de pantallas sin lógica contable consistente.

La aplicación se inspira funcionalmente en gestores financieros como Wallet de BudgetBakers, pero debe ser un producto original. No copies su nombre, identidad visual, código, textos, recursos, capturas ni disposición exacta. Usá un nombre de trabajo original y fácilmente reemplazable, por ejemplo **Finanzas Locales**.

El objetivo central es ofrecer una aplicación:

- Android-first, desarrollada con Flutter y Dart.
- Completamente utilizable sin suscripciones ni compras dentro de la app.
- Local-first y offline-first.
- Sin servidor, cuenta de usuario, anuncios ni telemetría.
- Sin depender de Firebase, Supabase, servicios de IA, APIs bancarias o servicios pagos.
- Con registro manual muy rápido como mecanismo principal.
- Capaz de detectar compras realizadas con Google Wallet mediante las notificaciones de Android.
- Con importación masiva posterior desde un CSV sencillo.
- Con interpretación de alertas bancarias recibidas como notificaciones de SMS en una fase posterior.
- Preparada para ser utilizada personalmente durante al menos un año sin perder datos al actualizarla.
- Diseñada con suficiente calidad técnica como para evaluar una publicación futura en Google Play, aunque inicialmente se distribuirá como APK de uso personal.

La interfaz debe estar inicialmente en español, utilizar el locale de Paraguay y tratar PYG/guaraníes como moneda predeterminada sin decimales visibles. La arquitectura debe permitir agregar otras monedas en el futuro.

---

## Forma de trabajar obligatoria

No intentes implementar toda la aplicación en un único paso. Antes de programar:

1. Revisá el repositorio y el entorno existente.
2. Confirmá la versión estable actual de Flutter y Dart disponible.
3. Elaborá un plan de implementación por fases basado en este documento.
4. Identificá decisiones realmente bloqueantes; no hagas preguntas por detalles que puedan resolverse con una configuración razonable y documentada.
5. Definí el modelo de datos y las reglas financieras antes de construir reportes o dashboards.
6. Ejecutá compilación, análisis estático y pruebas al terminar cada fase.
7. Mantené la aplicación ejecutable en cada checkpoint.
8. No marques una fase como terminada si contiene flujos principales simulados, botones sin acción o `TODO` que impidan usarla.

En cada fase entregá:

- Resumen breve de lo implementado.
- Archivos principales modificados.
- Decisiones o supuestos realizados.
- Migraciones de base de datos incluidas.
- Pruebas ejecutadas y su resultado real.
- Funciones pendientes de fases posteriores.

No afirmes que una función fue probada en un dispositivo si solo fue compilada. No inventes resultados de pruebas.

---

## Restricciones económicas y de licencias

Todo el funcionamiento central debe ser gratuito. Antes de incorporar una dependencia:

- Confirmá que sea mantenida, compatible con la versión actual de Flutter y adecuada para Android.
- Confirmá que tenga una licencia permisiva compatible con una futura distribución, por ejemplo MIT, BSD o Apache 2.0.
- No uses SDKs con funciones bloqueadas por pago, claves comerciales, límites de uso o licencias “community” condicionadas al tamaño o facturación del usuario.
- No uses Syncfusion ni otra dependencia cuya gratuidad dependa de una licencia comercial o comunitaria.
- No fijes versiones antiguas solamente porque aparezcan en un ejemplo. Elegí las versiones estables compatibles vigentes y registralas en `pubspec.yaml`.
- Generá y mantené un archivo de atribuciones/licencias de terceros.

Stack preferido, sujeto a validación de compatibilidad actual:

- Flutter y Dart estables.
- Material 3.
- Riverpod para estado e inyección de dependencias.
- `go_router` para navegación.
- Drift sobre SQLite para persistencia relacional, consultas reactivas y migraciones.
- `local_auth` para autenticación del dispositivo.
- `flutter_secure_storage` para secretos o claves pequeñas, nunca para movimientos financieros completos.
- `flutter_local_notifications` para recordatorios y acciones sobre movimientos detectados.
- `fl_chart` u otra alternativa realmente libre para gráficos.
- `csv` para importación y exportación.
- Selector de archivos compatible con Storage Access Framework.
- `intl`, `timezone`, `uuid` y utilidades equivalentes cuando sean necesarias.
- WorkManager solamente si se justifica para backups o tareas diferidas; no debe reemplazar `NotificationListenerService`.

La lectura de notificaciones de otras aplicaciones debe implementarse mediante un `NotificationListenerService` Android nativo en Kotlin, comunicado con Flutter de manera clara y testeable. No dependas ciegamente de un plugin abandonado para esta función crítica.

---

## Alcance priorizado

### Prioridad 1: MVP diario

- Onboarding y creación de cuentas.
- Registro manual de ingresos, gastos y transferencias.
- Gestión correcta de una tarjeta de crédito.
- Categorías, subcategorías y comercios.
- Cuenta de efectivo opcional.
- Presupuestos mensuales.
- Compras en cuotas.
- Dashboard y reportes básicos.
- Detección asistida de compras desde Google Wallet.
- Bandeja de movimientos pendientes.
- Backup y restauración local.
- Exportación abierta de todos los datos.
- Seguridad mediante bloqueo del dispositivo/biometría.

### Prioridad 2: importación CSV

- Plantilla simple y documentada.
- Vista previa, validación y deduplicación.
- Importación reversible por lote.
- Exportación compatible con la misma estructura.

### Prioridad 3: notificaciones de SMS

- Interpretación local de alertas de Sudameris recibidas mediante Google Messages.
- Sin solicitar `READ_SMS`.
- Reglas configurables y privacidad estricta.

### Fuera del alcance actual

No implementar ahora:

- Extracción de PDF.
- OCR de extractos.
- Sincronización bancaria/Open Banking.
- Backend, login o sincronización entre dispositivos.
- Cuentas familiares o colaboración.
- Aplicación web, iOS o escritorio.
- Inversiones, acciones o criptomonedas.
- Recomendaciones mediante servicios externos de IA.
- Google Wallet API: esa API no es necesaria para leer compras y no debe confundirse con la escucha local de notificaciones.

Dejá puntos de extensión limpios para estas posibilidades, pero no agregues abstracciones excesivas ni código muerto.

---

## Contexto financiero real y cuentas de referencia

El usuario posee inicialmente:

1. Una cuenta principal de Sudameris asociada a tarjeta de débito.
2. Una tarjeta de crédito Mastercard de Sudameris utilizada para Google Wallet y compras online.
3. Una cuenta secundaria en Banco Familiar.
4. Una cuenta de ahorro en Banco Familiar.
5. Una cuenta de efectivo opcional para gastos pequeños, como compras en una despensa.

Datos enmascarados útiles para configurar alias de ejemplo:

- La cuenta principal Sudameris puede aparecer como `***9647` o `***647000`. Son dos representaciones de **la misma cuenta bancaria**, no dos cuentas distintas.
- La tarjeta de crédito Sudameris aparece como `****5962` o `••5962`.
- En Google Wallet puede aparecer con una etiqueta similar a `SUDAM_GOOGLE ••5962`.

Estos valores deben utilizarse como datos de onboarding o fixtures locales, nunca como constantes dispersas dentro de parsers. La aplicación debe permitir que cualquier cuenta tenga varios alias enmascarados.

Ejemplo conceptual:

```text
Cuenta: Sudameris principal
Tipo: activo / cuenta bancaria
Alias: 9647, 647000

Cuenta: Tarjeta de crédito Sudameris
Tipo: pasivo / tarjeta de crédito
Alias: 5962, SUDAM_GOOGLE
```

No guardes números completos de tarjetas o cuentas. La app no los necesita. Conservá solamente nombres definidos por el usuario y alias enmascarados.

---

## Reglas financieras que no deben romperse

### Tipos de movimiento

Como mínimo:

- Ingreso.
- Gasto.
- Transferencia.
- Ajuste de saldo.
- Reembolso o reversión.

### Compras con tarjeta de crédito

Una compra con tarjeta:

- Es un gasto en la fecha de compra.
- Aumenta el monto adeudado o comprometido de la tarjeta.
- Reduce el crédito disponible.
- No reduce todavía el saldo de la cuenta bancaria.

### Pago de tarjeta

Pagar la tarjeta es una transferencia:

```text
Sudameris principal → Tarjeta de crédito Sudameris
```

Consecuencias:

- Disminuye el saldo de la cuenta principal.
- Disminuye la deuda de la tarjeta.
- No se contabiliza como un gasto nuevo.
- Puede ser parcial, mínimo, total o superior al mínimo.
- Pueden existir varios pagos dentro del mismo período.

### Transferencia a ahorro

Mover dinero desde Sudameris o Familiar hacia la cuenta de ahorro:

- Reduce la cuenta de origen.
- Aumenta la cuenta de ahorro.
- No es un gasto ni un ingreso.
- Puede afectar el indicador de “dinero disponible”, pero no los gastos por categoría.

### Efectivo

Retirar efectivo debe registrarse como transferencia desde la cuenta bancaria hacia la cuenta Efectivo. Las compras posteriores disminuyen Efectivo. No dupliques el gasto al retirar y al comprar.

### Reembolsos

Un reembolso debe vincularse, cuando sea posible, con la compra original y revertir total o parcialmente su efecto. No debe tratarse automáticamente como salario u otro ingreso ordinario.

### Moneda e importes

- Guardá dinero como enteros en unidades mínimas, nunca como `double`.
- Para PYG, la unidad mínima visible es un guaraní y normalmente no hay decimales.
- `PYG 145,500`, `145.500` y `145500` deben poder normalizarse a `145500` cuando el contexto sea inequívoco.
- La base debe guardar `currencyCode`, inicialmente `PYG`.
- No implementes conversiones online de moneda en esta etapa.

### Fechas

- Guardá instantes de auditoría en UTC.
- Conservá la zona horaria local del movimiento o interpretalo en `America/Asuncion`.
- Diferenciá la fecha financiera del movimiento de la fecha de creación o importación.
- La interfaz debe mostrar fechas locales.

---

## Modelo de datos recomendado

Usá identificadores UUID y borrado lógico cuando sea necesario para preservar auditoría. Diseñá un esquema relacional explícito y normalizado, con claves foráneas e índices. Como mínimo evaluá las siguientes entidades:

### `accounts`

- `id`
- `name`
- `type`: bank, savings, cash, creditCard u otros futuros.
- `currencyCode`
- `initialBalanceMinor`
- `color`
- `icon`
- `isArchived`
- `includeInNetWorth`
- `includeInAvailableMoney`
- `createdAt`, `updatedAt`

### `account_aliases`

- `id`
- `accountId`
- `alias`
- `normalizedAlias`
- `source`: manual, googleWallet, sms, csv.
- Restricción de unicidad razonable.

### `credit_card_profiles`

- `accountId`
- `creditLimitMinor`
- `closingDay` o regla de cierre.
- `dueDay` o fecha calculada.
- `minimumPaymentMinor` opcional.
- `minimumPaymentDueDate` opcional.
- `lastStatementAmountMinor` opcional.
- Configuración de ciclo.

### `transactions`

- `id`
- `type`
- `status`: pending, confirmed, ignored, reversed, deleted.
- `source`: manual, googleWalletNotification, csv, smsNotification, recurring, adjustment.
- `occurredAt`
- `createdAt`, `updatedAt`
- `currencyCode`
- `amountMinor`
- `fromAccountId` opcional.
- `toAccountId` opcional.
- `merchantId` opcional.
- `description`
- `note`
- `paymentChannel`: cash, debitCard, physicalCreditCard, googleWalletContactless, onlineCard, bankTransfer, other.
- `externalFingerprint` opcional.
- `sourceReference` opcional.
- `importBatchId` opcional.
- `parentTransactionId` para reversión o clonación relacionada.
- Metadatos mínimos y explícitos; no conviertas toda la entidad en un JSON opaco.

### Efectos por cuenta

Para evitar lógica inconsistente, centralizá en un servicio de dominio cómo cada transacción afecta los saldos. Podés utilizar una tabla `account_postings` con deltas en el saldo natural de cada cuenta:

- En activos, delta positivo aumenta dinero disponible y negativo lo reduce.
- En tarjetas/pasivos, delta positivo aumenta deuda y negativo la reduce.

Ejemplos:

- Gasto desde banco: delta negativo en cuenta bancaria.
- Gasto con tarjeta: delta positivo en deuda de tarjeta.
- Pago de tarjeta: delta negativo en banco y delta negativo en deuda de tarjeta.
- Transferencia banco → ahorro: delta negativo en origen y positivo en destino.

La interfaz no debe permitir crear postings arbitrarios. Todos deben generarse mediante casos de uso probados.

### `transaction_splits`

- `id`
- `transactionId`
- `categoryId`
- `amountMinor`
- `note` opcional.
- La suma debe coincidir exactamente con el importe categorizable de la transacción.

### `categories`

- `id`
- `name`
- `parentId` opcional.
- `kind`: expense, income o ambos cuando tenga sentido.
- `icon`, `color`
- `isSystem`, `isArchived`
- Orden personalizable.

### `merchants` y `merchant_aliases`

Separá el nombre canónico de las variantes detectadas.

Ejemplo:

```text
Comercio: Spotify
Alias:
- Spotify P3F488004C S
- Spotify P404A5A010 S
- Spotify P44819C280 S
```

### `categorization_rules`

- Prioridad.
- Fuente.
- Cuenta o tarjeta opcional.
- Comercio/alias/palabras clave.
- Tipo de movimiento.
- Categoría resultante.
- Nivel de confianza.
- Si puede sugerir o confirmar automáticamente.
- Activa/inactiva.

El comportamiento predeterminado es sugerir, no confirmar automáticamente.

### Presupuestos

Entidades para:

- Presupuesto mensual total.
- Presupuesto por categoría.
- Período.
- Importe objetivo.
- Umbrales de aviso.
- Rollover opcional, desactivado por defecto.
- Estado archivado.

### Cuotas

Entidades para:

- Compra original.
- Total comprometido.
- Cantidad de cuotas.
- Importe de cada cuota, permitiendo ajustar la última por redondeo.
- Primera fecha o ciclo de cobro.
- Cuotas vencidas, actuales y futuras.
- Estado cancelado/completado.

La compra debe almacenarse una sola vez. No generes gastos duplicados por cada cuota. El límite de crédito debe reflejar el total comprometido, mientras que el presupuesto y la planificación mensual utilizan la cuota correspondiente al período. Los reportes deben distinguir claramente “valor total de compra” de “impacto mensual de cuotas”.

### Planificación y recordatorios

- Pagos recurrentes.
- Suscripciones.
- Vencimientos.
- Pago mínimo de tarjeta.
- Plantillas de movimientos.

### Orígenes automáticos

Entidades separadas para:

- Eventos de notificación recibidos.
- Candidatos de movimiento extraídos.
- Lotes de importación CSV.
- Filas importadas y errores.
- Auditoría de cambios.

No conserves indefinidamente el contenido crudo de notificaciones.

---

## Onboarding

Construí un onboarding breve que permita:

1. Elegir moneda predeterminada, inicialmente PYG.
2. Crear o aceptar cuentas sugeridas.
3. Configurar tarjeta de crédito, límite, cierre y vencimiento.
4. Agregar alias enmascarados.
5. Crear cuenta Efectivo opcional.
6. Habilitar bloqueo biométrico o del dispositivo.
7. Explicar que los datos permanecen locales.
8. Explicar el acceso a notificaciones antes de abrir los ajustes del sistema.
9. Permitir omitir Google Wallet y activarlo posteriormente.

No obligues al usuario a configurar todas las funciones para empezar a registrar movimientos.

---

## Registro manual: experiencia principal

La pantalla de alta manual debe ser más rápida que completar una planilla. Flujo recomendado:

1. Importe, con teclado numérico y calculadora sencilla.
2. Tipo: gasto, ingreso o transferencia.
3. Cuenta o cuentas involucradas.
4. Categoría.
5. Comercio o beneficiario.
6. Guardar.

La fecha predeterminada es ahora. Campos como notas, etiquetas, canal, cuotas y detalles adicionales deben estar disponibles sin recargar la vista principal.

Calidad de vida obligatoria:

- Recordar última cuenta por tipo de operación.
- Mostrar categorías y comercios recientes.
- Autocompletar comercios.
- Sugerir categoría según historial local.
- Crear categoría o comercio sin abandonar el formulario.
- Plantillas: Despensa, Pagar tarjeta, Transferir a ahorro y otras configurables.
- Clonar movimiento.
- Dividir un gasto entre categorías.
- Guardar y crear otro.
- Deshacer inmediatamente una eliminación o cambio sensible.
- Confirmación explícita para eliminar definitivamente.
- Atajo desde el icono de Android y, si es viable, widget de gasto rápido.
- Haptics discretos y accesibilidad.
- Formularios utilizables con tema claro y oscuro.

### Plantilla “Pagar tarjeta”

- Origen predeterminado: Sudameris principal.
- Destino: tarjeta Sudameris.
- Importe editable.
- Mostrar mínimo, vencimiento y deuda actual.
- Registrar transferencia, nunca gasto.

### Plantilla “Transferir a ahorro”

- Origen seleccionable.
- Destino predeterminado: Familiar ahorro.
- No afectar presupuestos de gasto.

---

## Google Wallet mediante notificaciones

### Principio

No uses scraping, accesibilidad, Google Wallet API ni credenciales. Implementá un `NotificationListenerService` nativo y solicitá al usuario habilitar el acceso especial desde Ajustes de Android.

La captura histórica disponible sugiere:

```text
Tarjeta: SUDAM_GOOGLE ••5962
Comercio: ECOP OBLIGADO
Importe: PYG145,500
Fecha: Jul 18
```

También aparecen comercios como:

- MAKOS HELADERIA.
- SHELL LASO-HOHENAU.
- COPETROL-PASEO BVS.

Sin embargo, una pantalla de historial no garantiza que la notificación exponga exactamente los mismos campos. No hardcodees un parser basándote únicamente en esa captura.

### Fuente probable

Las notificaciones pueden provenir de Google Play Services y no necesariamente del paquete visible de Google Wallet. Permití configurar una lista blanca de paquetes. Empezá contemplando Google Play Services y Google Wallet, pero verificá el paquete real en dispositivo.

### Sobre de notificación

El módulo Kotlin debe capturar de manera segura al menos:

- Package name.
- Notification key.
- ID y tag.
- Post time.
- Title.
- Text.
- Big text.
- Subtext.
- Summary text.
- Text lines cuando existan.
- Si es actualización de una notificación anterior.

Transmití a Dart un DTO versionado, no un mapa informal sin contrato.

### Modo diagnóstico

Incluí una herramienta de diagnóstico local, desactivada por defecto, para:

- Ver los campos recibidos únicamente de paquetes seleccionados.
- Copiar o exportar una versión sanitizada.
- Ocultar números largos y datos potencialmente sensibles.
- Retener eventos crudos por un plazo corto, por ejemplo 24 horas, o hasta que el usuario los elimine.
- No incluir esta información en logs de release.

Este modo se utilizará para observar una notificación real antes de finalizar el parser de Google Wallet.

### Pipeline

Separá claramente:

```text
NotificationEnvelope
→ filtro de fuente
→ extractor específico
→ PaymentCandidate
→ deduplicador
→ bandeja pendiente
→ confirmación/edición/ignorar
→ Transaction confirmada
```

`PaymentCandidate` debe contener:

- Importe y moneda.
- Comercio crudo y normalizado.
- Cuenta/tarjeta sugerida.
- Alias detectado.
- Fecha/hora del evento.
- Fuente.
- Confianza por campo y confianza global.
- Motivo de la sugerencia.
- Huella de deduplicación.

### Comportamiento

Una compra detectada genera por defecto un movimiento pendiente, no confirmado. Mostrá una notificación propia con acciones:

- Confirmar.
- Editar.
- Ignorar.

Al confirmar:

- Registrar gasto en la tarjeta `5962`.
- Canal: Google Wallet/contactless.
- Fecha: la del evento.
- Comercio: valor normalizado.
- Categoría: sugerida por reglas locales.

La aplicación puede ofrecer una regla de autoconfirmación por comercio después de varias confirmaciones consistentes, pero debe estar desactivada por defecto y habilitarse explícitamente por comercio.

### Deduplicación

No uses solamente fecha, comercio e importe. Dos compras legítimas pueden ocurrir el mismo día en el mismo comercio, incluso por importes iguales.

Reglas:

- Una actualización con la misma notification key debe actualizar el candidato existente.
- Un evento idéntico con la misma fuente, clave y contenido no crea otro movimiento.
- Eventos independientes con claves distintas se conservan salvo evidencia fuerte de duplicación.
- La huella debe ser reproducible y versionada.
- Guardá la relación entre evento, candidato y transacción.
- No descartes silenciosamente: registrá la decisión de deduplicación para diagnóstico.

### Autorizaciones y monto final

Google Wallet puede mostrar una autorización cuyo detalle final dependa del banco. Permití editar importe, comercio o estado. Prepará soporte para reversión, pero no intentes consultar el banco.

---

## Importación CSV

### Objetivo

Permitir preparar movimientos en una hoja de cálculo e importarlos todos juntos sin PDF ni formatos bancarios complejos.

Formato canónico recomendado, UTF-8 y separado por `;`:

```csv
fecha;tipo;importe;moneda;cuenta_origen;cuenta_destino;categoria;subcategoria;comercio;canal;nota;referencia
2026-07-06;ingreso;3688653;PYG;;Sudameris principal;Ingresos;Salario;;;Salario julio;salario-2026-07
2026-07-06;transferencia;219000;PYG;Sudameris principal;Tarjeta Sudameris;;;;;Pago de tarjeta;pago-tc-2026-07-06
2026-07-07;gasto;75000;PYG;Tarjeta Sudameris;;Alimentación;Supermercado;Supermercado X;google_wallet;;compra-001
```

### Reglas

- `fecha`, `tipo`, `importe` y las cuentas necesarias según el tipo son obligatorios.
- Para gasto se requiere cuenta de origen.
- Para ingreso se requiere cuenta de destino.
- Para transferencia se requieren origen y destino.
- `importe` debe ser positivo; la dirección la define el tipo.
- Recomendá importes sin separador de miles.
- Admití fechas ISO `YYYY-MM-DD`; opcionalmente aceptá `DD/MM/YYYY` con locale explícito.
- No adivines fechas ambiguas silenciosamente.
- Aceptá encabezados con o sin BOM.
- Permití seleccionar delimitador si el archivo no usa `;`.
- Normalizá espacios y mayúsculas para buscar cuentas/categorías, sin perder el texto original.

### Flujo de importación

1. Descargar o compartir una plantilla.
2. Elegir archivo.
3. Detectar encabezado y delimitador.
4. Mostrar vista previa.
5. Validar cada fila.
6. Mapear nombres desconocidos a cuentas, categorías y comercios existentes, o crearlos con confirmación.
7. Detectar duplicados mediante referencia y huella secundaria.
8. Mostrar resumen: válidas, advertencias, inválidas y duplicadas.
9. No escribir nada antes de la confirmación.
10. Permitir importar solo filas válidas o cancelar todo.
11. Registrar un `importBatch`.
12. Permitir revertir el lote completo sin afectar movimientos ajenos.

La exportación CSV debe utilizar el mismo formato para permitir ida y vuelta sin pérdida de información esencial.

---

## SMS mediante notificaciones: fase posterior

### Restricción

No solicites permisos `READ_SMS`, `RECEIVE_SMS` ni conviertas la aplicación en gestor de SMS. El módulo observará la notificación generada por Google Messages a través del mismo `NotificationListenerService`, con consentimiento explícito y lista blanca.

Esta función debe estar desactivada por defecto y separada del parser de Google Wallet. Antes de una futura publicación en Google Play se debe revisar nuevamente la política vigente y documentar el tratamiento de datos.

### Privacidad

- Filtrar por paquete de la aplicación de mensajes.
- Filtrar por remitentes o patrones configurados por el usuario.
- Ignorar OTP, códigos de seguridad y mensajes no financieros.
- Extraer únicamente datos financieros.
- No guardar toda la bandeja ni mensajes históricos.
- Eliminar el contenido crudo después de procesar, confirmar o vencer su retención.
- No transmitir datos.

### Ejemplos reales y resultados esperados

#### Pago de tarjeta

```text
SUDAMERIS Informa: Movimiento de Débito , Pago Tarj. de Crédito e-bank , Caja de Ahorros N0*****9647 ,PYG 75,000.00, 24/11/2025 19:30:25
```

Resultado:

- Transferencia.
- Origen: Sudameris principal, resolviendo alias `9647`.
- Destino: tarjeta `5962`.
- Importe: 75000 PYG.
- No es gasto.

También reconocer:

```text
Pago de T.C.- Debito
```

#### Salario

```text
SUDAMERIS Informa: Movimiento de Crédito , Salario s/instrucion , Caja de Ahorros N0 ***9647 , PYG 3,688,653.00 , 06/07/26 11:16:34
```

Resultado:

- Ingreso.
- Cuenta: Sudameris principal.
- Categoría: Salario.
- Importe: 3688653 PYG.

Reconocer también aguinaldo y tolerar abreviaciones/errores ortográficos.

#### Transferencias sin contraparte

Variantes:

```text
Transferencia SPI Entrante
Transferencia SPI Saliente
Transf.e-Bank
```

Crear transferencia pendiente de completar. No convertir automáticamente en gasto o ingreso porque el mensaje no informa la contraparte.

#### Débitos y suscripciones

Ejemplos:

```text
GOOGLE*YOUTUBE MOUNT
Spotify P44819C280 S
Pago de Servicios e-bank
Compra POS Extranj.
Compra Negocio Tigo
```

Normalizar sufijos variables. Por ejemplo, todas las variantes `Spotify P... S` deben poder asociarse al comercio canónico Spotify.

#### Aviso de pago mínimo

```text
SUDAMERIS le informa: el Pago Minimo de su MASTERCARD CLASICA ****5962 es de PYG 1,603,000.00 con vto. de pago el: 03/02/26
```

No crear movimiento. Actualizar:

- Tarjeta `5962`.
- Pago mínimo.
- Fecha de vencimiento.
- Recordatorio.

Sumar pagos parciales del período y mostrar si el mínimo fue cubierto, sin afirmar que el resumen total quedó pagado.

### Variaciones del formato

El parser debe tolerar:

- `***9647`, `*****9647` y `***647000` como alias de la misma cuenta.
- Espacios opcionales.
- Año con dos o cuatro dígitos.
- `PYG 190,000` y `PYG 190,000.00`.
- Comas dentro del importe y como separadores del mensaje.
- Tildes, mayúsculas y errores menores.
- Mensajes repetidos exactamente varias veces.

No uses `split(',')`. Extraé primero la fecha y el importe mediante patrones anclados y luego interpretá el resto. Versioná los parsers y conservá fixtures de pruebas.

### Deduplicación de SMS

Una huella canónica debe considerar:

- Banco/remitente.
- Dirección débito/crédito.
- Descripción normalizada.
- Cuenta resuelta.
- Importe.
- Fecha y hora contenidas dentro del mensaje.

Mensajes idénticos repetidos deben generar un solo candidato. Movimientos distintos con la misma hora, como salario y pago automático de tarjeta, deben mantenerse separados.

---

## Comercios y aprendizaje local

El aprendizaje no necesita IA externa. Implementá reglas deterministas, explicables y editables.

Flujo:

1. Normalizar espacios, mayúsculas y símbolos.
2. Eliminar códigos variables solo mediante patrones específicos.
3. Buscar alias exacto.
4. Buscar regla explícita priorizada.
5. Considerar cuenta, fuente y canal.
6. Sugerir comercio y categoría con una explicación.
7. Aprender después de una corrección confirmada.

Ejemplo visible:

> Categoría sugerida: Combustible. Este comercio fue clasificado así 4 veces.

No permitas que una corrección cree reglas demasiado amplias. El usuario debe poder ver, editar, desactivar y eliminar reglas.

---

## Tarjeta de crédito y cuotas

La vista de tarjeta debe mostrar:

- Límite.
- Deuda/consumo registrado.
- Crédito disponible.
- Próximo cierre.
- Vencimiento.
- Pago mínimo conocido.
- Pagos realizados en el período.
- Cuotas del mes y futuras.
- Compras recientes.

### Compra en cuotas

Formulario:

- Total.
- Cantidad de cuotas.
- Primera cuota/ciclo.
- Importe calculado por cuota.
- Posibilidad de corregir redondeo.

Reglas acordadas:

- El total comprometido afecta el límite desde el inicio.
- El presupuesto mensual considera solamente la cuota del mes.
- El pago posterior de tarjeta no vuelve a crear el gasto.
- La compra se almacena una sola vez.
- Mostrar claramente total de compra, cuotas restantes y compromiso futuro.

---

## Presupuestos

Incluir en el MVP:

- Presupuesto mensual total.
- Presupuesto por categoría.
- Progreso consumido/restante.
- Alertas configurables al 50 %, 80 % y 100 %.
- Opción de excluir cuentas o categorías.
- Transferencias, pagos de tarjeta y ajustes excluidos por defecto.
- Cuotas contabilizadas según impacto mensual.
- Archivo histórico de presupuestos.
- Rollover opcional y desactivado por defecto.

Al editar o eliminar movimientos, el presupuesto debe recalcularse reactivamente.

---

## Dashboard y análisis

El inicio debe priorizar información accionable, no llenar la pantalla de gráficos.

Tarjetas sugeridas:

- Dinero disponible.
- Saldo por cuenta.
- Deuda de tarjeta.
- Ingresos del mes.
- Gastos del mes.
- Balance mensual.
- Presupuesto consumido.
- Movimientos pendientes de confirmar.
- Próximo vencimiento de tarjeta.

Reportes:

- Gastos por categoría y subcategoría.
- Gastos por comercio.
- Gastos por cuenta y canal.
- Evolución diaria/mensual.
- Flujo de caja.
- Comparación con el mes anterior.
- Comparación contra promedio de los últimos tres meses.
- Suscripciones y gastos recurrentes.
- Cuotas futuras.
- Ahorro acumulado.

Separá conceptualmente:

- **Consumo:** fecha y naturaleza del gasto.
- **Flujo de caja:** cuándo entra o sale dinero de cuentas activas.

Los filtros deben permitir rango, cuentas, categorías, comercios, fuentes, estados y monedas.

---

## Backup, restauración y portabilidad

### Principios

- Los datos pertenecen al usuario.
- Toda información debe poder exportarse sin pagar.
- No depender de un proveedor cloud.
- Una actualización nunca debe borrar la base.

### Backup completo

Definí un formato versionado, por ejemplo `.finbackup`, que contenga:

- Manifest con versión del formato y esquema.
- Base de datos consistente.
- Configuración.
- Reglas.
- Adjuntos si existieran.
- Checksums.

Ofrecé cifrado con contraseña utilizando primitivas criptográficas mantenidas y auditadas. No diseñes criptografía casera. Usá cifrado autenticado, salt aleatorio y derivación de clave apropiada. Documentá el formato suficientemente para poder recuperarlo en versiones futuras.

Flujo:

- Crear backup manual.
- Elegir ubicación mediante Storage Access Framework o compartirlo con otra app.
- Restaurar con vista previa de versión, fecha, cuentas y cantidad de movimientos.
- Crear automáticamente un backup de seguridad antes de reemplazar datos.
- Validar integridad y contraseña antes de modificar la base activa.
- No sobrescribir silenciosamente un backup existente.

El guardado manual en Google Drive mediante el selector/hoja de compartir es válido; no integrar la API de Drive.

### Backup programado

Puede implementarse después del backup manual. Si se agrega:

- Carpeta elegida por el usuario con permiso persistente.
- WorkManager.
- Política de retención configurable.
- Notificación clara de éxito o fallo.
- Sin red obligatoria.

### Exportaciones abiertas

- CSV canónico.
- JSON documentado.
- Resumen legible opcional.

---

## Seguridad y privacidad

- Sin tráfico de red para funciones centrales.
- Sin analytics ni crash reporting remoto por defecto.
- Bloqueo al abrir o volver desde segundo plano, configurable.
- Usar `local_auth` con credenciales del dispositivo.
- Guardar secretos pequeños en almacenamiento seguro.
- No guardar PIN en texto plano.
- No registrar movimientos, SMS o notificaciones completas en logs de release.
- Sanitizar exportaciones diagnósticas.
- Permitir borrar inmediatamente eventos crudos.
- Mostrar claramente qué paquetes de Android se observan.
- Permitir pausar el listener.
- Nunca leer notificaciones antes de consentimiento.
- No solicitar permisos no utilizados.
- Documentar prácticas de privacidad en `PRIVACY.md`.
- Preparar texto de divulgación para una eventual ficha de Google Play, sin afirmar cumplimiento futuro sin revisión.

La base vive en el sandbox privado de Android. Si se implementa cifrado completo de base, elegir una solución mantenida y compatible con Drift/sqlite3 actual; no adoptar bibliotecas obsoletas. El cifrado de backups sí es obligatorio.

---

## Arquitectura del proyecto

Usá una arquitectura feature-first pragmática, por ejemplo:

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    database/
    money/
    time/
    security/
    notifications/
    backup/
    errors/
  features/
    onboarding/
    accounts/
    transactions/
    credit_cards/
    installments/
    budgets/
    merchants/
    rules/
    dashboard/
    reports/
    imports/
    pending_inbox/
    settings/
  shared/
```

Separá:

- UI/presentación.
- Casos de uso y reglas de dominio.
- Repositorios.
- Persistencia.
- Integraciones Android.

No coloques reglas de saldo o deduplicación directamente en widgets. Evitá también una “clean architecture” ceremoniosa con decenas de capas sin valor. Priorizá código testeable y fácil de mantener por una persona.

La integración Android debe vivir en clases Kotlin propias, documentadas, y exponer contratos estables a Flutter mediante platform channels o un plugin interno del proyecto.

---

## Migraciones y longevidad de los datos

Este requisito es crítico porque la aplicación se utilizará al menos un año:

- Versioná el esquema desde el primer commit.
- Escribí migraciones explícitas y testeadas.
- Nunca uses “delete database on migration failure”.
- Conservá snapshots de esquemas para pruebas.
- Probá actualización desde cada versión publicada internamente.
- Hacé backup previo a migraciones de riesgo.
- Si una migración falla, no abras una base parcialmente migrada.
- Documentá cambios en `CHANGELOG.md`.
- Backups antiguos deben restaurarse mediante rutas de migración conocidas.

---

## Manejo de errores

- Errores comprensibles para el usuario.
- Detalle técnico disponible localmente para diagnóstico.
- Nunca ocultar filas rechazadas en una importación.
- Nunca descartar silenciosamente una notificación candidata.
- Operaciones financieras y lotes deben ser transaccionales.
- Evitar estados intermedios si la app se cierra.
- Soportar reinicio durante importación o restauración.
- Ofrecer reintento seguro cuando corresponda.

---

## Pruebas obligatorias

### Unitarias de dominio

- Gasto desde cuenta bancaria.
- Gasto con tarjeta.
- Pago parcial y total de tarjeta.
- Transferencia a ahorro.
- Retiro y gasto de efectivo sin duplicación.
- Reembolso parcial/total.
- División de categorías.
- Sumas exactas en PYG.
- Presupuestos y umbrales.
- Cuotas, redondeo y cambio de período.
- Cierre y vencimiento de tarjeta.

### Parsers y deduplicación

- Campos de notificación ausentes.
- Actualización con misma notification key.
- Dos compras legítimas en mismo comercio/día.
- Importe `PYG145,500` sin espacio.
- Alias `5962` asociado a tarjeta.
- SMS con años de dos/cuatro dígitos.
- SMS con/sin `.00`.
- Alias `9647` y `647000` resolviendo la misma cuenta.
- Spotify con sufijos variables.
- Duplicados exactos repetidos varias veces.
- Salario y pago de tarjeta con misma hora permanecen separados.
- Aviso de pago mínimo no crea transacción.
- OTP ignorado.

### CSV

- Archivo válido completo.
- BOM UTF-8.
- Delimitador incorrecto.
- Cuenta desconocida.
- Categoría nueva.
- Fecha ambigua.
- Importe con formato inválido.
- Referencia duplicada.
- Importación parcial.
- Reversión del lote.
- Exportación y reimportación equivalentes.

### Base y backup

- Migraciones desde esquemas anteriores.
- Fallo simulado de migración sin pérdida.
- Backup cifrado y restauración.
- Contraseña incorrecta.
- Archivo corrupto.
- Backup de versión anterior.
- Restauración cancelada.

### Widget e integración

- Onboarding.
- Alta manual rápida.
- Confirmar, editar e ignorar candidato.
- Pago de tarjeta.
- Compra en cuotas.
- Crear presupuesto.
- Importar CSV.
- Bloqueo biométrico y fallback.
- Deep link desde acción de notificación.

Usá fixtures sanitizados derivados de los ejemplos proporcionados. No dependas de servicios externos durante las pruebas.

---

## Accesibilidad y diseño

- Material 3 con identidad original.
- Tema claro y oscuro.
- Contraste suficiente.
- Soporte de escalado de fuente.
- Etiquetas semánticas.
- Áreas táctiles adecuadas.
- No comunicar estados únicamente por color.
- Formato paraguayo de números y fechas.
- PYG sin decimales visibles.
- Confirmaciones y errores breves, no modales innecesarios.
- Dashboard adaptable a diferentes tamaños Android.

No imites visualmente Wallet. Creá una interfaz sobria, rápida y centrada en datos.

---

## Fases de implementación sugeridas

### Fase 0: fundamentos

- Crear proyecto.
- Configurar análisis, formatos, tests y CI local.
- Definir arquitectura, tema y navegación.
- Implementar Drift, esquema v1 y migraciones.
- Crear tipos monetarios y de fecha.
- Documentar decisiones.

### Fase 1: cuentas y movimientos manuales

- Onboarding.
- Cuentas y alias.
- Categorías/comercios.
- Ingreso, gasto, transferencia y ajuste.
- Saldos correctos.
- Efectivo opcional.
- Historial, filtros básicos y edición.

### Fase 2: tarjeta, cuotas y presupuestos

- Perfil de tarjeta.
- Pago de tarjeta.
- Ciclo, mínimo y vencimiento.
- Compras en cuotas.
- Presupuesto total y por categoría.
- Recordatorios básicos.

### Fase 3: Google Wallet

- Servicio Kotlin.
- Permisos y onboarding.
- DTO de notificación.
- Modo diagnóstico.
- Parser configurable.
- Bandeja pendiente.
- Notificación propia con acciones.
- Deduplicación y reglas aprendidas.

No cierres el parser definitivo sin observar al menos una notificación real o conservar un mecanismo seguro para ajustar el extractor.

### Fase 4: CSV

- Plantilla.
- Preview y validación.
- Mapeo.
- Duplicados.
- Lote reversible.
- Exportación compatible.

### Fase 5: backup, seguridad y reportes

- Backup cifrado.
- Restauración.
- Exportación JSON.
- Bloqueo local.
- Dashboard completo y análisis.
- Revisión de privacidad y rendimiento.

### Fase 6: SMS opcional

- Google Messages en lista blanca.
- Parser Sudameris con fixtures.
- Transferencias pendientes.
- Pago mínimo.
- Deduplicación.
- Revisión de política antes de distribución.

---

## Criterios de aceptación del MVP

El MVP se considera utilizable cuando:

1. Puede instalarse y abrirse sin internet.
2. El onboarding permite configurar cuentas y tarjeta.
3. Registrar manualmente un gasto normal requiere pocos pasos.
4. Ingresos, gastos y transferencias producen saldos correctos.
5. Pagar la tarjeta no duplica gastos.
6. Transferir a ahorro no aparece como gasto.
7. El efectivo puede habilitarse u omitirse.
8. Una compra en cuotas afecta límite y presupuesto según las reglas acordadas.
9. Los presupuestos se recalculan correctamente.
10. El usuario puede habilitar y revocar acceso a notificaciones.
11. Una notificación compatible genera un candidato, nunca una transacción oculta.
12. El candidato puede confirmarse, editarse o ignorarse.
13. Los duplicados no crean movimientos repetidos.
14. Todos los datos pueden respaldarse y exportarse sin pagar.
15. Una actualización/migración no elimina datos.
16. `flutter analyze` no presenta errores.
17. Las pruebas financieras críticas pasan.
18. Existe README suficiente para compilar un APK desde cero.

---

## Entregables finales

- Repositorio Flutter completo.
- APK debug y procedimiento para release firmado, sin incluir claves privadas.
- `README.md` con configuración, ejecución, pruebas y build.
- `ARCHITECTURE.md`.
- `DATA_MODEL.md` con diagrama o descripción de tablas.
- `PRIVACY.md`.
- `CSV_FORMAT.md` y plantilla CSV.
- `BACKUP_FORMAT.md`.
- `CHANGELOG.md`.
- Licencias de terceros.
- Fixtures sanitizados.
- Tests unitarios, widget e integración razonables.
- Instrucciones para capturar de manera segura el payload real de Google Wallet.
- Lista de limitaciones conocidas, sin esconderlas.

---

## Fuentes técnicas de referencia

Usá documentación oficial y revisá su estado al implementar:

- Android `NotificationListenerService`: https://developer.android.com/reference/android/service/notification/NotificationListenerService
- Ajustes de acceso al listener: https://developer.android.com/reference/android/provider/Settings#ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS
- Campos estándar de `Notification`: https://developer.android.com/reference/android/app/Notification
- Permiso para notificaciones propias en Android 13+: https://developer.android.com/develop/ui/views/notifications/notification-permission
- Cambios de privacidad/OTP en Android 15: https://developer.android.com/about/versions/15/behavior-changes-all
- Historial y notificaciones de compras de Google Wallet: https://support.google.com/wallet/answer/12059878
- Política de permisos SMS de Google Play: https://support.google.com/googleplay/android-developer/answer/10208820
- Drift: https://pub.dev/packages/drift
- `local_auth`: https://pub.dev/packages/local_auth
- `flutter_local_notifications`: https://pub.dev/packages/flutter_local_notifications
- `flutter_secure_storage`: https://pub.dev/packages/flutter_secure_storage

---

## Instrucción final

Comenzá respondiendo con:

1. Un resumen de cómo entendés el producto.
2. Las decisiones arquitectónicas propuestas.
3. El esquema inicial de datos.
4. Un plan por fases con criterios verificables.
5. Las pocas preguntas que sean realmente bloqueantes.

Después implementá la **Fase 0** y continuá de forma incremental. Priorizá exactitud financiera, preservación de datos y rapidez del registro manual por encima de agregar funciones llamativas.
