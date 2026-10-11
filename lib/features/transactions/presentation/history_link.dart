import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Abre la pestaña Movimientos con estos filtros, reemplazando los que tuviera.
/// `link` distingue cada apertura: el router lo usa como clave para que repetir
/// el mismo atajo vuelva a aplicar sus filtros.
void openHistory(BuildContext context, Map<String, String> filters) =>
    context.go(
      Uri(
        path: '/transactions',
        queryParameters: {
          ...filters,
          'link': '${DateTime.now().microsecondsSinceEpoch}',
        },
      ).toString(),
    );
