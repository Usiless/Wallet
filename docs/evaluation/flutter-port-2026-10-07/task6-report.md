# Task6 · Insets móviles y tarjetas compactas

## Alcance y criterio
Brief aprobado en task6-brief.md; AGENTS y PRODUCT_BASELINE conservados. Impeccable context/adapt.native/android/craft-floor aplicados como refinamiento del Flutter existente. Context informó ausencia de PRODUCT/DESIGN; no se creó nueva identidad ni documentación de diseño fuera de alcance. Sin subagentes, cambios de dominio/prototipo ni APK por este agente.

## Cambios mínimos
- `lib/app/router.dart`: shell móvil protege contenido con SafeArea(bottom:false). Conserva barra inferior fuera del wrapper y la variante tablet existente. SafeArea retira el inset superior heredado antes del AppBar del detalle, evitando duplicarlo.
- `lib/features/accounts/presentation/accounts_screen.dart`: tarjetas siguen siendo clicables y conservan icono, nombre, saldo y estado archivado. Se retiran los botones redundantes de la lista; pagar tarjeta, movimientos, editar, conciliar y archivar siguen en el detalle. Espaciado icono/nombre reducido de16 a8. FittedBox scaleDown conserva todos los dígitos del importe en vez de elipsis.
- Se conserva el cambio a una columna en anchos estrechos o texto ampliado ya existente.

## TDD y pruebas
- RED: `flutter test --no-pub test/features/management/accounts_compact_regression_test.dart` — exit1, 0passed/5failed, `docs/evaluation/flutter-port-2026-10-07/accounts-red.log`; casos320/390/486 y texto2x reproducen inset insuficiente/acciones en lista antes de los cambios.
- La primera pasada GREEN encontró un error del fixture (espacioIntl NBSP y espacio final en importes buscados) y una ruta de prueba inexistente solicitada por el coordinador. La sonda del coordinador confirmó el texto real `1.234.567.890\u00a0PYG `; se ajustó solo la coincidencia de espacios, conservando los importes literales independientes y comprobaciones de límites de los glifos. El test de pago desde ficha ya pasó en esa pasada. Evidencia en accounts-green.log.
- GREEN final: `flutter test --no-pub test/features/management/accounts_compact_regression_test.dart test/features/management/approved_accounts_test.dart test/features/dashboard/root_accessibility_regression_test.dart` — exit0,12/12passed, log accounts-green.log. Incluye cinco variantes de cuentas, el pago de la tarjeta correcta desde detalle y seis regresiones de Inicio. Verifica importe positivo/negativo completo con límites de glifos, AppBar de detalle con inset único y acciones preservadas. Análisis estático completo queda como gate final del coordinador.

## Capturas Flutter host
Comandos del coordinador: `flutter test --no-pub tool/qa/flutter_accounts_capture_test.dart --update-goldens --dart-define=CAPTURE_PHASE=before` y mismo comando con `CAPTURE_PHASE=after`. Ambos:3/3passed, logs accounts-before.log/accounts-after.log.

Archivos reales de Flutter, datos sintéticos y Roboto/MaterialIcons/NotoSans cargados; no son HTML ni capturas Android:
- flutter-accounts-before-390-1x.png / flutter-accounts-after-390-1x.png
- flutter-accounts-before-320-2x.png / flutter-accounts-after-320-2x.png (oscuro)
- flutter-accounts-before-486-1x.png / flutter-accounts-after-486-1x.png

Inspección en una tanda: antes390 la tarjetaVisa agrega una fila de acción y el saldo1.234.567.890PYG se corta; después se lee completo, las tarjetas pierden botones redundantes y los filtros respetan los24px superiores/8px laterales sintéticos.320/2x usa una columna. Gestos y barras físicas Android permanecen fuera de esta evidencia.

## Entrega
`task6.diff`: unified diff basado en copias ui-regression-before para los dos archivos productivos, más pruebas/QA nuevas. No se utilizó Git.
