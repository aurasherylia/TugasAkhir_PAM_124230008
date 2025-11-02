import '../services/settings_service.dart';

int parseRupiahToInt(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.parse(digits);
}

String formatCurrencyFromIdr(int idr) {
  final s = SettingsService.instance;
  final rate = s.currencyRateFromIdr;
  final cur = s.currencyPrefix;
  if (s.currency.value == AppCurrency.idr) {
    final n = idr.toString();
    final buf = StringBuffer();
    for (int i = 0; i < n.length; i++) {
      final idx = n.length - i;
      buf.write(n[i]);
      if (idx > 1 && idx % 3 == 1) buf.write('.');
    }
    return 'Rp$buf';
  } else {
    final v = idr * rate;
    return '$cur${v.toStringAsFixed(2)}';
  }
}

/// Konversi jam dokter berdasarkan setting timezone global
String convertHours(String hours) {
  if (hours.isEmpty) return '-';
  String cleaned = hours
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('.', ':')
      .trim();

  final parts = cleaned.split(RegExp(r'\s*-\s*'));
  final tz = SettingsService.instance.timezone.value;
  final offset = SettingsService.instance.offsetHours(tz);

  String normalize(String hhmm) {
    if (!hhmm.contains(':')) hhmm = '$hhmm:00';
    final bits = hhmm.split(':');
    int h = int.tryParse(bits[0]) ?? 0;
    int m = int.tryParse(bits[1]) ?? 0;
    h = (h + offset) % 24;
    if (h < 0) h += 24;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  // Mode 24 jam normal
  if (tz != AppTimezone.london) {
    if (parts.length == 2) {
      return '${normalize(parts[0])} - ${normalize(parts[1])}';
    }
    return normalize(parts.first);
  }

  // Mode London pakai format 12 jam (AM/PM)
  String format12(String hhmm) {
    final p = hhmm.split(':');
    int h = int.parse(p[0]);
    String m = p[1];
    String suf = h >= 12 ? 'PM' : 'AM';
    h = h % 12 == 0 ? 12 : h % 12;
    return '$h:$m $suf';
  }

  if (parts.length == 2) {
    return '${format12(normalize(parts[0]))} - ${format12(normalize(parts[1]))}';
  }
  return format12(normalize(parts.first));
}
