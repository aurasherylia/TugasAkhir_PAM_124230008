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

  final String checkup;        
  final String availableHours;    

  final double latitude;
  final double longitude;
  final int price;               
  final List<String> slots;      

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
    final parsedPrice = _parseRupiahToInt(json['checkup']?.toString() ?? '');

    final generatedSlots = _generateSlots(json['available_hours']?.toString() ?? '');

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

  static int _parseRupiahToInt(String rupiah) {
    if (rupiah.isEmpty) return 0;
    final digits = rupiah.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  static List<String> _generateSlots(String range) {
    if (range.isEmpty) {
      return _defaultSlots();
    }

    final normalized = range.replaceAll('–', '-');
    final parts = normalized.split('-');
    if (parts.length != 2) return _defaultSlots();

    final start = _parseTime(parts[0].trim()); 
    final end = _parseTime(parts[1].trim());

    if (start == null || end == null || end <= start) return _defaultSlots();

    final List<String> result = [];
    int cursor = start + 60; 
    while (cursor <= end) {
      result.add(_minuteToLabel(cursor));
      cursor += 60;
    }
    if (result.isEmpty) return _defaultSlots();
    return result;
  }

  static int? _parseTime(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!) ?? 0;
    final min = int.tryParse(m.group(2)!) ?? 0;
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
    }


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
