import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/database/app_database.dart';
import 'core/backup/backup_service.dart';
import 'core/settings/settings_repository.dart';
import 'features/accounts/data/accounts_service.dart';
import 'features/onboarding/data/onboarding_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final settings = SettingsRepository(database);
  final onboarding = OnboardingService(
    database,
    AccountsService(database),
    settings,
  );
  await onboarding.ensureSystemData();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(cleanupBackupWorkingFiles().catchError((Object _) {})),
  );
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const FinanzasApp(),
    ),
  );
}
