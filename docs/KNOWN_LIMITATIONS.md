# Limitaciones conocidas

Google Wallet y el registro automático de compras reconocidas están en Más → Google Wallet. El simulador, SMS, la inspección de notificaciones existentes y el diagnóstico requieren la bandera de desarrollo y modo debug; están bloqueados en release/profile. Ver [herramientas de desarrollo](DEVELOPER_TOOLS.md).

- La base activa y WAL usan SQLite3MultipleCiphers; la cola usa AES-GCM y la clave se protege con Android Keystore. Falta validación de Keystore y migración de la instalación real en teléfono. El diagnóstico se limpia al abrir/procesar; no hay eliminación programada mientras la app está cerrada.

- El extractor de Google Wallet tiene fixtures sanitizados y una prueba manual con una compra real. Android y Google pueden cambiar textos/campos; faltan pruebas con más formatos, idiomas y dispositivos.
- No se emiten avisos del sistema para revisar propuestas. La captura puede ocurrir en segundo plano, pero el procesamiento y registro se ejecutan al abrir/volver a la app o mientras está visible.
- SMS funciona solo cuando Google Messages muestra una alerta Sudameris reconocible. No lee SMS directamente y no soporta otros bancos todavía.
- La asociación de transferencias SMS sin contraparte queda pendiente para que el usuario elija la cuenta faltante.
- No hay backup programado ni integración con API de Drive. El backup manual puede guardarse en Drive mediante el selector del sistema.
- CSV/JSON retirados, con historia importada conservada. Backup/restauración utilizan copias SQLite temporales descifradas dentro del caché privado; se borran al finalizar y se limpian al próximo inicio si hubo interrupción. Los backups y respaldos previos persistentes están cifrados y autenticados.
- Los gastos programados de importe fijo se procesan al abrir/volver a la app, con frecuencia mensual/anual y recuperación de atrasos. La preparación financiera no se ejecuta con la app cerrada. La agenda independiente de recordatorios sí persiste alarmas Android inexactas; su entrega aún no fue verificada en dispositivo. Cada pasada procesa hasta 120 vencimientos por plantilla. Conflictos quedan en Plantillas; se puede editar, pausar u omitir un vencimiento. La detección de posibles duplicados con Wallet usa cuenta, comercio, importe y una ventana de tres días, no un identificador bancario de pago.
- Se han realizado pruebas manuales parciales en un teléfono. No equivalen a una validación integral de todos los recorridos ni a una revisión de publicación en Google Play.
- El historial carga bloques de 50 movimientos mediante “Cargar 50 movimientos más”. Los reportes consultan todos los movimientos confirmados del período, con cuotas mensuales enlazadas como criterio único. Devoluciones impactan en su fecha; no se reprograman cuotas futuras de la compra devuelta.
- La restauración valida integridad SQLite, tablas/columnas y referencias antes de aplicar los datos. Conserva un respaldo cifrado previo y revierte la transacción si falla una escritura; el recorrido completo debe volver a validarse en teléfono.

Ver [APP_REVIEW](APP_REVIEW.md) para el informe histórico y [ROADMAP](ROADMAP.md) para brechas y prioridades actuales.

- Administración, edición de movimientos, filtros, conciliación y devoluciones fueron implementados en el bloque básico del 2026-10-04. Su recorrido completo todavía requiere validación en teléfono. Los cambios de tipo/moneda/saldo inicial de cuentas existentes están bloqueados; se usa conciliación para corregir saldos.

- El traslado Flutter incluye cinco pestañas, consulta mensual de presupuestos y cuotas enlazadas. Falta verificar esta versión en Android: navegación/teclado/TalkBack, actualización sobre base anterior, SAF, claves y ciclo de vida. Pruebas de host y widgets no sustituyen esos recorridos. Ver [plan](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07).
- CI-01 aplicado: se retiró el paso APK automático, conservando análisis y pruebas. No se ejecutó el workflow.

- Traslado posterior del prototipo: obligaciones no crédito, parciales, plantillas pendientes, recordatorios reales en código y pantallas actualizadas. [Informe de host y evaluación](evaluation/flutter-port-2026-10-07/REPORT.md). Las capturas Flutter con datos sintéticos no prueban Android, SAF, Keystore, entrega de alarmas, TalkBack ni actualización sobre una instalación anterior.
- Se compiló APK profile por petición explícita del usuario, con JDK21 configurado de Android Studio; el fallo previo con JRE sin compilador ya no bloquea el build. Compilación/recursos/D8/empaquetado no acreditan ejecución Android. El artefacto definitivo y su verificación constan en el informe del traslado.

- Lentitud/bloqueo al abrir reportados el2026-10-08: corregidos mecanismos verificables de consultas/agenda repetidas y trabajo de recordatorios en UI; sin teléfono conectado no se reprodujo el incidente ni se demuestra resuelto. N+1 de hidratación, arranque previo a runApp, cola Wallet y espera del receptor siguen pendientes de medir. No confundir con la pausa histórica del depurador.
