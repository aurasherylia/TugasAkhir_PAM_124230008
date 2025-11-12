import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import 'chat_page.dart';
import 'home_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    SettingsService.instance.timezone.addListener(_loadData);
  }

  @override
  void dispose() {
    SettingsService.instance.timezone.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null || userId == 0) {
        debugPrint('user_id not found in SharedPreferences!');
        setState(() {
          _appointments = [];
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login again — user not found.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final data = await DBService.getAppointmentsByUser(userId);
      setState(() {
        _appointments = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading appointments: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteAppointment(int id) async {
    await DBService.deleteAppointment(id);
    await _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment deleted successfully'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6EDFF), Color(0xFFEADAFD), Color(0xFFD9C2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: kDarkText,
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                          (route) => false,
                        );
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'My Appointments',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kDarkText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: kPrimary),
                      )
                    : _appointments.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data appointment.',
                          style: TextStyle(
                            color: kLightText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                          itemCount: _appointments.length,
                          itemBuilder: (_, i) {
                            final a = _appointments[i];
                            final createdAt =
                                DateTime.tryParse(a['created_at'] ?? '') ??
                                DateTime.now();
                            final isCompleted =
                                DateTime.now()
                                    .difference(createdAt)
                                    .inMinutes >=
                                15;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _AppointmentCard(
                                appointment: a,
                                isCompleted: isCompleted,
                                onStartChat: () {
                                  if (isCompleted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'This appointment is already completed.',
                                        ),
                                        backgroundColor: Colors.grey,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(appointment: a),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                onDelete: () => _deleteAppointment(a['id']),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isCompleted;
  final VoidCallback onStartChat;
  final VoidCallback onDelete;

  const _AppointmentCard({
    required this.appointment,
    required this.isCompleted,
    required this.onStartChat,
    required this.onDelete,
  });


  Color _getSpecialistColor(String specialist) {
    final s = specialist.toLowerCase();
    if (s.contains('umum')) return const Color(0xFFE57373);
    if (s.contains('anak')) return const Color(0xFF64B5F6);
    if (s.contains('jantung')) return const Color(0xFFF06292);
    if (s.contains('kulit')) return const Color(0xFF81C784);
    if (s.contains('mata')) return const Color(0xFFFFB74D);
    if (s.contains('kandungan')) return const Color(0xFF9575CD);
    if (s.contains('saraf')) return const Color(0xFFE57373);
    return kPrimary;
  }


  String _formatTimeWithTimezone(String slot) {
    if (slot.isEmpty) return '-';
    return slot;
  }

  @override
  Widget build(BuildContext context) {
    final doctor = appointment['doctor_name'] ?? '-';
    final specialist = appointment['doctor_specialist'] ?? '-';
    final date = DateTime.tryParse(appointment['date'] ?? '') ?? DateTime.now();
    final slot = appointment['slot'] ?? '';
    final invoice = appointment['invoice_number'] ?? '-';
    final imageUrl =
        appointment['doctor_image'] ??
        'https://cdn-icons-png.flaticon.com/512/387/387561.png';

    final cardColor = isCompleted ? const Color(0xFFE9F8EE) : Colors.white;
    final borderColor = isCompleted
        ? const Color(0xFF4CAF50)
        : kPrimary.withOpacity(0.1);
    final textColor = isCompleted ? const Color(0xFF388E3C) : kDarkText;
    final specColor = _getSpecialistColor(specialist);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          if (!isCompleted)
            BoxShadow(
              color: kPrimary.withOpacity(.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: NetworkImage(imageUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invoice: $invoice',
                      style: TextStyle(color: textColor.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 6),
                    _chip(specialist, specColor),
                  ],
                ),
              ),
              Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.schedule_rounded,
                color: isCompleted ? const Color(0xFF4CAF50) : kPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date', style: TextStyle(color: kLightText)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy', 'id_ID').format(date),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time', style: TextStyle(color: kLightText)),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeWithTimezone(slot),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // cek status completed
          if (isCompleted)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                    size: 30,
                  ),
                  tooltip: 'Delete appointment',
                  onPressed: () {
                    final doctorName =
                        appointment['doctor_name'] ?? 'dokter ini';
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: const Color(
                          0xFFF9F5FF,
                        ), // warna lembut seperti contoh
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hapus Appointment',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Color(0xFF2D2A3D),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Apakah kamu yakin ingin menghapus riwayat dengan $doctorName?',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF4A4458),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Batal',
                                      style: TextStyle(
                                        color: Color(0xFF6B46C1), // ungu lembut
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onDelete(); // hapus data
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6B46C1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Text(
                                      'Hapus',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble, color: Colors.white),
                label: const Text(
                  'Start Chat',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onStartChat,
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
