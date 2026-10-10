import 'package:flutter/material.dart';

/// Los llamadores comprueban `context.mounted` antes de usarlo tras un await.
void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

void showError(BuildContext context, Object error) =>
    showMessage(context, '$error');
