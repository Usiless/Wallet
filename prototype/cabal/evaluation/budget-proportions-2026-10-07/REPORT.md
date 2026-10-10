# Presupuesto proporcional y estado de pago · 2026-10-07

Aprobación explícita: escalar anillo al total al exceder; verde dentro objetivo, rojo exceso; sólido pagado y rayado pendiente en ambas zonas. Hasta100% conserva progreso con tramo vacío. Porcentaje central sigue relación total/objetivo. Solo prototipo HTML, sinFlutter/APK ni cambios modelo.

## Implementación

budgetRingSegments calcula partes exactas con denominador max(objetivo,total). Pagos consumen primero la capacidad del objetivo; saldo pendiente ocupa su capacidad restante y luego exceso. Un solo radio, cuatro combinaciones posibles, sin vueltas ni aro interior extra. Cada parte pendiente usa patrón SVG con fondo verde/rojo y rayado claro, IDs únicos por presupuesto/zona. Leyenda muestra color y textura; aria-label conserva porcentaje y agrega importes pagados/pendientes. Los cálculos financieros y detalle mantienen importes originales.

Devoluciones netas: se conserva total del modelo; gráfico no inventa longitud pagada negativa ni excede total. El texto/detalle conserva valores netos reales.

## Pruebas

Red antes: helper inexistente, ReferenceError registrado en red.tap. Green9/9 en green.tap:250todo pendiente40verde60rojo,340pendiente,300pagado1/3verde2/3rojo,mixtos,sub100,vacío,devoluciones y barrido de finitud/longitud. VM de helper real, no navegador. Modelo55/55, sintaxis app.js salida0.

Navegador: base130% y34% conservan importes y estados. Para comprobar250 se creó categoría Prueba anillo, plan250.000 con1cuota del mes y presupuesto100.000 mediante formularios. DOM confirma dos segmentos pendientes:40verde60rojo; detalle0pagado/250.000pendiente/objetivo100.000/exceso150.000. Capturas pending-250-320/390. Documento320=scroll320. Luego pago parcial100.000 vía formulario: mismo250%, segmento verde40sólido, rojo60rayado. mixed-250-390/1280. Documento1280=scroll1280. La recarga final elimina cambios ficticios y devuelve base130%.

Revisión independiente en REVIEW.md: fuentes, capturas, pruebas, barrido propio de160combinaciones. Sin acceso a navegador propio; no confundir simulaciones y recorridos interactivos del principal. Detector una vez: JSON íntegro, avisos heredados fuente/sombra/marcadores; no determinan aprobación estética.

No se prueban Android real, TalkBack ni notificaciones. No se amplían funciones. El porcentaje, monto y detalle siguen accesibles sin depender únicamente de colores.
