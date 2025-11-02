import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/doctor.dart';

class APIService {
  // 🔗 URL Dokter (GitHub Gist)
  static const _doctorUrl =
      'https://gist.githubusercontent.com/aurasherylia/1e565ea389763e8852a7cfd718445932/raw/dadaa620293a06c49c085e8b7e464f5efb7388f8/doctor.json';

  /// ============================================================
  /// 👩‍⚕️ Fetch Doctor List
  /// ============================================================
  static Future<List<Doctor>> fetchDoctors() async {
    try {
      final res = await http
          .get(Uri.parse(_doctorUrl))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('Failed to load doctor data (${res.statusCode})');
      }

      final data = json.decode(res.body);
      if (data is Map && data.containsKey('doctors')) {
        return (data['doctors'] as List)
            .map((e) => Doctor.fromJson(e))
            .toList();
      } else {
        throw Exception('Invalid doctor JSON structure');
      }
    } catch (e) {
      throw Exception('Error loading doctor data: $e');
    }
  }
}
