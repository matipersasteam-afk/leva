import 'package:intl/intl.dart';

import '../../domain/models/event.dart';

/// Formatos de fecha del torneo en es-MX.
abstract final class EventFormat {
  static final _day = DateFormat('d', 'es_MX');
  static final _dayMonth = DateFormat("d 'de' MMMM", 'es_MX');
  static final _month = DateFormat('MMM', 'es_MX');
  static final _weekday = DateFormat('EEE', 'es_MX');
  static final _deadline = DateFormat("d 'de' MMM, HH:mm", 'es_MX');

  /// "14–16 nov" o "30 nov – 2 dic".
  static String range(PadelEvent e) {
    final s = e.startDate, f = e.endDate;
    if (s.year == f.year && s.month == f.month) {
      return s.day == f.day
          ? '${_day.format(s)} ${_short(s)}'
          : '${s.day}–${f.day} ${_short(s)}';
    }
    return '${s.day} ${_short(s)} – ${f.day} ${_short(f)}';
  }

  static String _short(DateTime d) =>
      _month.format(d).replaceAll('.', '').toLowerCase();

  static String month(DateTime d) => _short(d);
  static String longDay(DateTime d) => _dayMonth.format(d);
  static String weekday(DateTime d) {
    final w = _weekday.format(d).replaceAll('.', '');
    return w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
  }

  static String deadline(DateTime d) => _deadline.format(d);
}
