# Cabal · Segundo ciclo de evaluación del HTML

Fecha: 2026-10-06. Alcance: completar faltantes razonables de la demostración HTML detectados al contrastar plan, base de producto y servicios Flutter. El primer ciclo y sus puntuaciones se conservan en [REPORT.md](REPORT.md). La aceptación anterior no se extiende automáticamente a estos cambios.

## Rúbrica constante y resultado

Escala de 1 a 10; promedio aritmético simple. La evaluación inicial se hizo antes de modificar archivos. Máximo de tres rondas de cambios; se realizó **una**, con evaluación posterior. Se detuvo al alcanzar promedio ≥8, ningún criterio <7 y sin bloqueos críticos conocidos en los recorridos probados.

| Criterio | Inicial | Después de ronda 1 | Observación inicial y justificación posterior |
| --- | ---: | ---: | --- |
| Jerarquía visual y legibilidad | 8 | 8 | Títulos, importes y acciones principales se distinguen; tipografía y contraste heredados del primer ciclo. Se mantienen legibles en detalle de cuotas, importación y filtros nuevos. No hubo rediseño que justifique subir la nota. |
| Coherencia del diseño y componentes | 8 | 8 | Usa tarjetas, campos y diálogos consistentes. Los controles de programación conjunta, CSV y restauración reutilizan esos componentes; no se detectaron divergencias en las pantallas inspeccionadas. |
| Claridad de navegación y acciones | 8 | 8 | Cinco destinos y retorno al origen claros. Antes, crear primera cuenta interrumpía el gasto; ahora lo reanuda. Se comprobó Reportes→Historial→Detalle→Volver conservando rango. Persisten etiquetas explícitas de simulación. La corrección preserva la nota global, sin elevarla por sí sola. |
| Usabilidad y adaptación móvil | 7 | 8 | Desde/Hasta estaban como elementos independientes en una grilla, separando etiquetas y campos. Ahora cada pareja está agrupada: una columna a 320 px y dos campos completos a 390 px, sin desbordamiento de página; presentación revisada también a 800/1280 px. Formularios largos siguen requiriendo desplazamiento. |
| Accesibilidad básica | 8 | 8 | Se conserva fondo inerte, foco visible y bucle de teclado del diálogo; Tab desde Aplicar vuelve a Cerrar. Nuevos campos tienen etiquetas y resumen CSV anunciado como estado. No se probó lector de pantalla, teclado virtual ni ampliación de texto: no se atribuye cumplimiento WCAG integral. |
| Interacciones y fidelidad al producto aprobado | 6 | 8 | Inicialmente faltaban conflicto de edición, programación conjunta, alias/actualizaciones Wallet, reparto entero fiel y recuperación de copia creada; separador CSV decorativo. Se corrigieron y verificaron como se detalla abajo. Las integraciones Android/archivos siguen simuladas y no se verificaron todas las variantes; por eso no se puntúa 9 o 10. |
| **Promedio** | **7,50** | **8,00** | **Apto para revisión del usuario dentro del alcance HTML.** |

La nota funcional inicial es menor que en el primer ciclo porque este contraste incluyó explícitamente variantes faltantes de la documentación que aquel recorrido no había evaluado; no se alteraron las notas históricas ni se asumió paridad por la aceptación visual.

## Cambios de ronda 1

- Crear la primera cuenta reanuda el borrador y selecciona esa cuenta.
- Ediciones con revisión obsoleta o registro eliminado se rechazan; cambios de otra pestaña avisan sin borrar el formulario abierto.
- Guardar movimiento y plantilla admite gasto mensual/anual, frecuencia y próxima fecha; validación atómica. Si el vencimiento coincide con la compra guardada se consume y avanza, evitando duplicación. Plantillas independientes no crean comercios al validar.
- Programados validan referencias archivadas/ambiguas y se procesan al cargar o recuperar visibilidad del HTML. Se mantiene el botón explícito; no hay ejecución con la página cerrada.
- Wallet ficticio reconoce nombres/alias con cuenta y comercio únicos; omite categoría archivada, deja coincidencias y capturas actualizadas por revisar, e ignora repeticiones idénticas. Incluye escenas de alias y actualización.
- Cuotas conservan importe base y todo el resto en la última; categorías se reparten con pesos restantes. Devoluciones sucesivas se distribuyen sobre categorías aún disponibles. Fechas crediticias ajustan fin de mes y vencen el mes posterior al cierre.
- Desde/Hasta agrupados con sus etiquetas en historial y rango de reportes.
- CSV de ejemplo realmente recalcula la previa por separador, valida filas y omite duplicados existentes; la importación usa esas filas, con lotes reversibles.
- Copia/restauración del libro de sesión en memoria, resumen calculado, contraseña ficticia y estado previo recuperable. No crea archivo ni cifra. Restauración aumenta revisiones para invalidar borradores antiguos. Reiniciar escenario limpia las copias de sesión y actualiza el selector.

Se corrigió una inferencia de la documentación anterior: Flutter y HTML comienzan cuotas en el mes de compra. La diferencia comprobada estaba en el reparto del resto y las categorías, no en ese mes inicial. Se contrastaron `installment_calculator.dart`, `report_service.dart`, `ledger_service.dart` y `lib/features/credit_cards/domain/credit_card_cycle.dart` sin modificar Flutter.

## Verificación realizada

**Automática:** `node --check prototype/cabal/app.js`, `node --check prototype/cabal/model.js` y `node prototype/cabal/model.test.js`: 28 pruebas aprobadas. Cubren las 16 originales y nuevos casos de conflicto obsoleto/eliminado, atomicidad y vencimiento consumido, comercio archivado programado, reparto exacto 101→33/33/35 y categorías, devoluciones sucesivas, Wallet alias/ambigüedad/duplicación/actualización/permisos, fechas crediticias y previa CSV. Estas pruebas ejecutan el modelo JavaScript; no son pruebas DOM ni Flutter.

**Navegador:**

1. Primera apertura sin cuentas → Gasto → Crear cuenta y continuar → nueva cuenta seleccionada → guardar compra de 100 ₲ → patrimonio/saldo −100 ₲.
2. Compra de 101 ₲ + plantilla mensual, próxima fecha coincidente con compra: un movimiento, plantilla pasa al 6 nov.; procesamiento posterior registra cero adicionales. Se manipularon controles mensual/anual, pero no se acredita prueba completa de todos los años/fechas en DOM.
3. Dos pestañas editan la misma compra: segunda guarda 303 ₲; primera intenta guardar 202 ₲ y recibe error de edición desactualizada. Se cerró la pestaña temporal.
4. Wallet sin permiso abre consentimiento ficticio; tras concederlo se activan detección/registro. Alias MERCADO VERDE PY registra automáticamente; actualizar misma captura de 78.500 a 79.500 ₲ la deja por revisar sin otro registro automático.
5. CSV mixto: 2 válidas, 1 inválida, 1 duplicada; coma incorrecta muestra error y desactiva importar. Punto y coma permite importar 2; repetir muestra 0 válidas, 1 inválida y 3 duplicadas. Revertir lote, copiar antes y restaurar después recupera el lote importado.
6. Backup de sesión: copia del estado actual, modificación posterior mediante reversión de lote, contraseña incorrecta muestra error sin restaurar; contraseña correcta recupera copia con 5 cuentas/29 movimientos y lote activo. La acción separada «Recuperar estado anterior» no se recorrió en navegador; su implementación no equivale a rollback Android. Corrupción/esquema conservan escenas existentes; no se repitieron en este ciclo.
7. Gasto de crédito 101 ₲ dividido Alimentación 51/Hogar 50 en tres cuotas: detalle muestra octubre 33, noviembre 33, diciembre 35; deuda aumenta 101. Reparto por categoría y devoluciones sucesivas comprobados en pruebas del modelo.
8. Reportes con rango 1–6 oct. → historial → detalle → volver dos veces conserva rango y modalidad. Escenario Análisis, agosto: neto −1.300.000 ₲, bruto cero, devolución 1.300.000 ₲; desglose por categoría conserva signo. Abril 2027 muestra estado sin datos; enero 2027 aún muestra cuota futura, correctamente.
9. Vistas 320 y 390 px: detalle de cuotas y diálogos de fechas; sin desbordamiento horizontal del documento. A 390, Desde/Hasta miden 161 px y coinciden con el contenedor de cada campo; a 320 ocupan 264 px cada uno en una columna. A 800 y 1280 px se inspeccionaron reportes. Bucles de foco y fondo inerte comprobados en diálogo de filtros.
10. Apertura directa del escenario Programados procesa dos atrasos y muestra pendientes; apertura directa de Análisis deja el selector consistente. Sin errores de consola capturados en la pestaña al terminar las comprobaciones.

No se generó APK ni se ejecutó la app Flutter. No se probaron teléfono físico, lector de pantalla, texto ampliado, teclado virtual, todos los filtros archivados ni todas las combinaciones F01–F23. La inspección visual y las interacciones enumeradas sí se realizaron; otras variantes permanecen sin certificar.

## Evidencias y límites

- [Rango móvil, 390 px](iteration-2-mobile.jpg).
- [Reportes en escritorio, 1280 px](iteration-2-desktop.jpg).
- [Estado actualizado por recorrido](../../../docs/PROTOTYPE_STATUS.md).

Quedan integraciones Android, permisos reales, biometría, parser de notificaciones, archivos CSV generales, exportación real, cifrado/backup real y pruebas exhaustivas. Son límites explícitos de la demostración, no bloqueos conocidos para los recorridos HTML probados. localStorage no sustituye una base con transacciones concurrentes. La copia de sesión y la contraseña ficticia desaparecen al recargar/cambiar escenario. El diseño aún debe trasladarse a Flutter en otro trabajo. La aceptación final corresponde al usuario.

**Cierre:** una ronda de cambios; no se realizan rondas 2/3 ni una cuarta. Abrir mediante [README](../README.md) o el servidor local en puerto 8765.
