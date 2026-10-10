import 'package:drift/drift.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_envelope.dart';
import '../../../core/notifications/notification_ingestion_service.dart';

final class NotificationRetestService {
  NotificationRetestService(this.database, this.ingestion);
  final AppDatabase database;
  final NotificationIngestionService ingestion;

  Future<void> reopen(NotificationEnvelope envelope) async {
    if (!developerToolsEnabled) {
      throw StateError('Herramientas de desarrollo desactivadas.');
    }
    final preview = await ingestion.preview(envelope);
    if (preview == null) {
      throw StateError('No se reconoció una compra compatible.');
    }
    await database.transaction(() async {
      final matches = await (database.select(
        database.paymentCandidates,
      )..where((table) => table.fingerprint.equals(preview.fingerprint))).get();
      if (matches.length != 1) {
        throw StateError('Primero creá una propuesta para esta notificación.');
      }
      final candidate = matches.single;
      if (candidate.status == 'pending') {
        throw StateError('La propuesta ya está pendiente.');
      }
      final movements =
          await (database.select(database.ledgerTransactions)..where(
                (table) =>
                    table.externalFingerprint.equals(preview.fingerprint),
              ))
              .get();
      if (movements.isEmpty ||
          movements.any((row) => row.status != 'deleted')) {
        throw StateError(
          'Solo podés repetir la prueba después de eliminar el movimiento anterior.',
        );
      }
      await (database.update(
        database.paymentCandidates,
      )..where((table) => table.id.equals(candidate.id))).write(
        PaymentCandidatesCompanion(
          status: const Value('pending'),
          transactionId: const Value(null),
          suggestedAccountId: Value(preview.suggestedAccountId),
          suggestedFromAccountId: Value(preview.suggestedAccountId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }
}
