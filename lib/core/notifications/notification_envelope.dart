import 'dart:convert';

import '../text/normalization.dart';

final class NotificationEnvelope {
  const NotificationEnvelope({
    required this.version,
    required this.packageName,
    required this.notificationKey,
    required this.id,
    required this.postTime,
    this.tag,
    this.title,
    this.text,
    this.bigText,
    this.subText,
    this.summaryText,
    this.textLines = const [],
    this.isUpdate = false,
    this.isTest = false,
    this.captureId,
  });

  factory NotificationEnvelope.fromMap(Map<Object?, Object?> map) {
    String? optionalString(String key) {
      final value = map[key];
      return value?.toString();
    }

    final rawLines = map['textLines'];
    return NotificationEnvelope(
      version: (map['version'] as num?)?.toInt() ?? 1,
      packageName: map['packageName']?.toString() ?? '',
      notificationKey: map['notificationKey']?.toString() ?? '',
      id: (map['id'] as num?)?.toInt() ?? 0,
      tag: optionalString('tag'),
      postTime: DateTime.fromMillisecondsSinceEpoch(
        (map['postTime'] as num?)?.toInt() ?? 0,
        isUtc: true,
      ),
      title: optionalString('title'),
      text: optionalString('text'),
      bigText: optionalString('bigText'),
      subText: optionalString('subText'),
      summaryText: optionalString('summaryText'),
      textLines: rawLines is List
          ? rawLines.map((line) => line.toString()).toList(growable: false)
          : const [],
      isUpdate: map['isUpdate'] == true,
      isTest: map['isTest'] == true,
      captureId: optionalString('captureId'),
    );
  }

  final int version;
  final String packageName;
  final String notificationKey;
  final int id;
  final String? tag;
  final DateTime postTime;
  final String? title;
  final String? text;
  final String? bigText;
  final String? subText;
  final String? summaryText;
  final List<String> textLines;
  final bool isUpdate;
  final bool isTest;
  final String? captureId;

  Iterable<String> get populatedTextFields sync* {
    for (final value in [
      title,
      text,
      bigText,
      subText,
      summaryText,
      ...textLines,
    ]) {
      if (value != null && value.trim().isNotEmpty) yield value.trim();
    }
  }

  String get combinedText => populatedTextFields.join('\n');

  Map<String, Object?> toMap({bool sanitized = false}) {
    String? clean(String? value) =>
        sanitized && value != null ? sanitizeDiagnosticText(value) : value;
    return {
      'version': version,
      'packageName': packageName,
      'notificationKey': sanitized ? '[KEY_OCULTA]' : notificationKey,
      'id': id,
      'tag': sanitized ? clean(tag) : tag,
      'postTime': postTime.toUtc().toIso8601String(),
      'title': clean(title),
      'text': clean(text),
      'bigText': clean(bigText),
      'subText': clean(subText),
      'summaryText': clean(summaryText),
      'textLines': textLines.map((line) => clean(line)).toList(),
      'isUpdate': isUpdate,
      'isTest': isTest,
    };
  }

  String toSanitizedJson() =>
      const JsonEncoder.withIndent('  ').convert(toMap(sanitized: true));
}
