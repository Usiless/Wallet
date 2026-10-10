# Instrucciones del proyecto

- El usuario genera el APK por su cuenta desde VSCodium. No regenerar ni compilar APKs automáticamente después de realizar cambios; hacerlo únicamente si el usuario lo pide explícitamente.
- Se pueden ejecutar análisis y pruebas pertinentes para validar los cambios sin generar un APK.
- Las funciones de pruebas y experimentales se agrupan en `lib/features/developer_tools/` y en su menú de configuración. Respetar `developerToolsEnabled`: desactivado por defecto y siempre desactivado en release/profile. No habilitarlas solo ocultando el menú.
- Google Wallet y el registro automático de compras reconocidas son funciones de uso normal autorizadas por el usuario. SMS, diagnóstico, inspección de notificaciones existentes y simuladores siguen sujetos a la bandera de desarrollo.
- Consultar `docs/PRODUCT_BASELINE.md` para las decisiones de producto asentadas y las propuestas pendientes. No tratar propuestas pendientes como decisiones aprobadas.
- Botones flotantes: usar siempre `AppFab` (`lib/shared/widgets/app_fab.dart`) en lugar de `FloatingActionButton`, para que ninguno comparta el Hero por defecto.
- Textos de interfaz: menos es más. Eliminar subtítulos, bajadas y textos explicativos; no sustituirlos por ayudas desplegables ni agregar explicaciones por iniciativa propia. Incluirlos solo cuando el usuario los solicite explícitamente. Esta preferencia aplica a Flutter y al prototipo HTML.
- Git: no hacer commits ni crear ramas sin que el usuario lo pida. Cuando un cambio funcione, `flutter analyze` y las pruebas pasen y se vaya a proponer trabajo nuevo, recomendar explícitamente hacer commit antes de continuar, con un mensaje sugerido (en español, primera línea breve). Para cambios grandes o riesgosos, recomendar además una rama aparte (p. ej. `feature/...` o `fix/...`) en lugar de trabajar sobre `master`.
