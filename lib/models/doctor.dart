class Doctor {
  final int id;
  final String name;
  final String specialist;
  final String hospital;
  final String location;
  final int yearsOfWork;
  final int numberOfPatients;
  final double rating;
  final String alumni;
  final String address;
  final String image;

  // dari API (string)
  final String checkup;           // contoh: "Rp200.000"
  final String availableHours;    // contoh: "08:00–15:30"

  // diturunkan dari API
  final double latitude;
  final double longitude;
  final int price;                // int yang di-parse dari checkup
  final List<String> slots;       // di-generate dari availableHours

  Doctor({
    required this.id,
    required this.name,
    required this.specialist,
    required this.hospital,
    required this.location,
    required this.yearsOfWork,
    required this.numberOfPatients,
    required this.rating,
    required this.alumni,
    required this.address,
    required this.image,
    required this.checkup,
    required this.availableHours,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.slots,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    // 1) parse price dari "Rp200.000" -> 200000
    final parsedPrice = _parseRupiahToInt(json['checkup']?.toString() ?? '');

    // 2) buat slots dari "08:00–15:30" (support '–' dan '-')
    final generatedSlots = _generateSlots(json['available_hours']?.toString() ?? '');

    // 3) ambil koordinat (bisa null)
    final coords = (json['coordinates'] as Map?) ?? {};
    final lat = (coords['latitude'] is num) ? (coords['latitude'] as num).toDouble() : 0.0;
    final lng = (coords['longitude'] is num) ? (coords['longitude'] as num).toDouble() : 0.0;

    return Doctor(
      id: json['id'] as int,
      name: json['name'] as String,
      specialist: json['specialist'] as String,
      hospital: json['hospital'] as String,
      location: json['location'] as String,
      yearsOfWork: json['years_of_work'] as int,
      numberOfPatients: json['number_of_patients'] as int,
      rating: (json['rating'] as num).toDouble(),
      alumni: json['alumni'] as String,
      address: json['address'] as String,
      image: json['image'] as String,
      checkup: json['checkup'] as String,
      availableHours: json['available_hours'] as String,
      latitude: lat,
      longitude: lng,
      price: parsedPrice,
      slots: generatedSlots,
    );
  }

  // ---------- Helpers ----------

  /// "Rp200.000" -> 200000
  static int _parseRupiahToInt(String rupiah) {
    if (rupiah.isEmpty) return 0;
    final digits = rupiah.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  /// "08:00–15:30" (atau "08:00-15:30") -> ["09:00 AM", "10:00 AM", ...]
  /// default: kalau gagal parse, kasih slot bawaan.
  static List<String> _generateSlots(String range) {
    if (range.isEmpty) {
      return _defaultSlots();
    }

    // normalize dash
    final normalized = range.replaceAll('–', '-');
    final parts = normalized.split('-');
    if (parts.length != 2) return _defaultSlots();

    final start = _parseTime(parts[0].trim()); // menit dari 00:00
    final end = _parseTime(parts[1].trim());

    if (start == null || end == null || end <= start) return _defaultSlots();

    // buat slot setiap 60 menit, mulai 1 jam setelah start
    final List<String> result = [];
    int cursor = start + 60; // mulai 1 jam setelah jam buka
    while (cursor <= end) {
      result.add(_minuteToLabel(cursor));
      cursor += 60;
    }
    if (result.isEmpty) return _defaultSlots();
    return result;
  }

  /// "08:00" -> 480 (menit). Return null jika gagal.
  static int? _parseTime(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!) ?? 0;
    final min = int.tryParse(m.group(2)!) ?? 0;
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
    }

  /// 780 -> "01:00 PM"
  static String _minuteToLabel(int minutes) {
    int h24 = minutes ~/ 60;
    int m = minutes % 60;
    final isPM = h24 >= 12;
    int h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final mm = m.toString().padLeft(2, '0');
    final period = isPM ? 'PM' : 'AM';
    return '${h12.toString().padLeft(2, '0')}:$mm $period';
  }

  static List<String> _defaultSlots() => const [
        '09:00 AM', '10:00 AM', '11:00 AM',
        '02:00 PM', '03:00 PM', '04:00 PM', '07:00 PM'
      ];
}
