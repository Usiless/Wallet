import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/shared/widgets/pending_count_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('contador aparece con propuestas y desaparece al resolverlas', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PendingCountBadge(child: Icon(Icons.inbox))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    final service = container.read(notificationIngestionProvider);
    final candidate = await service.ingest(
      NotificationEnvelope(
        version: 1,
        packageName: 'com.google.android.apps.walletnfcrel',
        notificationKey: 'badge-1',
        id: 1,
        postTime: DateTime.now(),
        title: 'ECOP',
        text: 'PYG 15000 · ••1234',
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(find.text('1'), findsOneWidget);
    await service.ignore(candidate!.id);
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
