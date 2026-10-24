import 'package:flutter/material.dart';

/// Hora de [at] no formato da localidade; de outro dia, a data curta.
String formatMessageTime(BuildContext context, DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final localizations = MaterialLocalizations.of(context);
  final sameDay =
      at.year == today.year && at.month == today.month && at.day == today.day;
  return sameDay
      ? localizations.formatTimeOfDay(
          TimeOfDay.fromDateTime(at),
          alwaysUse24HourFormat: true,
        )
      : localizations.formatCompactDate(at);
}
