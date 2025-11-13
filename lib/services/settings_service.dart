import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';  

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

  // konversi dari API
  static const _kUsdRateKey = 'usd_rate';
  static const _kEurRateKey = 'eur_rate';

  double _usdRate = 0.0;
  double _eurRate = 0.0;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    timezone.value = _parseTz(sp.getString(_kTzKey));
    currency.value = _parseCur(sp.getString(_kCurKey));

    _usdRate = sp.getDouble(_kUsdRateKey) ?? 0.0;
    _eurRate = sp.getDouble(_kEurRateKey) ?? 0.0;
  }

  // SETTERS
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

  // API CALL 
  Future<void> updateExchangeRate() async {
    final url = Uri.parse("https://open.er-api.com/v6/latest/IDR");

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("Tidak dapat mengambil kurs");
    }

    final data = jsonDecode(res.body);
    final rates = data["rates"] as Map<String, dynamic>;

    _usdRate = (rates["USD"] as num).toDouble();
    _eurRate = (rates["EUR"] as num).toDouble();

    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kUsdRateKey, _usdRate);
    await sp.setDouble(_kEurRateKey, _eurRate);
  }

  // CONVERTER
  double get currencyRateFromIdr {
    switch (currency.value) {
      case AppCurrency.usd:
        return _usdRate > 0 ? _usdRate : 0.00006;
      case AppCurrency.eur:
        return _eurRate > 0 ? _eurRate : 0.000053;
      default:
        return 1.0;
    }
  }

  String get currencyPrefix {
    switch (currency.value) {
      case AppCurrency.usd:
        return "\$";
      case AppCurrency.eur:
        return "€";
      default:
        return "Rp";
    }
  }

  // FORMAT
  String formatPriceFromIdr(int idr) {
    final rate = currencyRateFromIdr;
    final prefix = currencyPrefix;

    if (currency.value == AppCurrency.idr) {
      final f = NumberFormat('#,###', 'id_ID');
      return "$prefix ${f.format(idr)}";
    }
    final converted = idr * rate;
    final f = NumberFormat('#,##0.00', 'en_US');
    return "$prefix ${f.format(converted)}";
  }

  // TIMEZONE
  int offsetHours(AppTimezone tz) {
    switch (tz) {
      case AppTimezone.wib:
        return 7;
      case AppTimezone.wita:
        return 8;
      case AppTimezone.wit:
        return 9;
      case AppTimezone.london:
        return 0;
      case AppTimezone.auto:
        return DateTime.now().timeZoneOffset.inHours;
    }
  }

  int get timezoneOffsetHours => offsetHours(timezone.value);

  // ENUM PARSER
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
}
