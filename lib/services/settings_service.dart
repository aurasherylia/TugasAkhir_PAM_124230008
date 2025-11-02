import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zona waktu yang digunakan di aplikasi.
enum AppTimezone { auto, wib, wita, wit, london }

/// Pilihan mata uang di aplikasi.
enum AppCurrency { idr, usd, eur }

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final ValueNotifier<AppTimezone> timezone = ValueNotifier(AppTimezone.auto);
  final ValueNotifier<AppCurrency> currency = ValueNotifier(AppCurrency.idr);

  static const _kTzKey = 'app_timezone';
  static const _kCurKey = 'app_currency';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    timezone.value = _parseTz(sp.getString(_kTzKey));
    currency.value = _parseCur(sp.getString(_kCurKey));
  }

  Future<void> setTimezone(AppTimezone tz) async {
    final sp = await SharedPreferences.getInstance();
    timezone.value = tz;
    await sp.setString(_kTzKey, _tzToStr(tz));
  }

  Future<void> setCurrency(AppCurrency cur) async {
    final sp = await SharedPreferences.getInstance();
    currency.value = cur;
    await sp.setString(_kCurKey, _curToStr(cur));
  }

  String _tzToStr(AppTimezone tz) {
    switch (tz) {
      case AppTimezone.auto:
        return 'auto';
      case AppTimezone.wib:
        return 'wib';
      case AppTimezone.wita:
        return 'wita';
      case AppTimezone.wit:
        return 'wit';
      case AppTimezone.london:
        return 'london';
    }
  }

  AppTimezone _parseTz(String? s) {
    switch (s) {
      case 'wib':
        return AppTimezone.wib;
      case 'wita':
        return AppTimezone.wita;
      case 'wit':
        return AppTimezone.wit;
      case 'london':
        return AppTimezone.london;
      case 'auto':
      default:
        return AppTimezone.auto;
    }
  }

  String _curToStr(AppCurrency c) {
    switch (c) {
      case AppCurrency.idr:
        return 'idr';
      case AppCurrency.usd:
        return 'usd';
      case AppCurrency.eur:
        return 'eur';
    }
  }

  AppCurrency _parseCur(String? s) {
    switch (s) {
      case 'usd':
        return AppCurrency.usd;
      case 'eur':
        return AppCurrency.eur;
      case 'idr':
      default:
        return AppCurrency.idr;
    }
  }


  int offsetHours(AppTimezone tz) {
  switch (tz) {
    case AppTimezone.wib:
      return 7; // WIB = UTC+7
    case AppTimezone.wita:
      return 8; // WITA = UTC+8
    case AppTimezone.wit:
      return 9; // WIT = UTC+9
    case AppTimezone.london:
      return 0; // London = UTC+0
    case AppTimezone.auto:
      // Ikuti timezone sistem (biasanya UTC di emulator)
      return DateTime.now().timeZoneOffset.inHours;
  }
}

  /// Kurs konversi (dummy)
  double get currencyRateFromIdr {
    switch (currency.value) {
      case AppCurrency.usd:
        return 0.000065;
      case AppCurrency.eur:
        return 0.000059;
      default:
        return 1.0;
    }
  }

  String get currencyPrefix {
    switch (currency.value) {
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.eur:
        return '€';
      default:
        return 'Rp';
    }
  }

  int get timezoneOffsetHours => offsetHours(timezone.value);
}
