class Appointment {
  final int id;
  final int doctorId;
  final String doctorName;
  final String doctorImage;
  final String specialist;
  final String time;
  final int price;

  Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorImage,
    required this.specialist,
    required this.time,
    required this.price,
  });

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        id: m['id'],
        doctorId: m['doctor_id'],
        doctorName: m['doctor_name'],
        doctorImage: m['doctor_image'],
        specialist: m['specialist'],
        time: m['time'],
        price: m['price'],
      );
}
