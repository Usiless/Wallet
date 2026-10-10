import 'package:flutter/foundation.dart';

/// Opt-in de compilación. Release y profile nunca habilitan estas herramientas.
const developerToolsEnabled =
    kDebugMode && bool.fromEnvironment('ENABLE_DEVELOPER_TOOLS');
