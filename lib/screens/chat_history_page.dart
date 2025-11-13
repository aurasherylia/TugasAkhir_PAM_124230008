import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_service.dart';
import '../theme.dart';
import 'chat_page.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      _loadAppointments();
    });
  }

  Future<void> _loadAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        setState(() {
          _appointments = [];
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final dataRaw = await DBService.getAppointmentsByUser(userId);
      final data = List<Map<String, dynamic>>.from(dataRaw);

      data.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _appointments = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      if (mounted) {
        setState(() {
          _appointments = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteAppointment(int id, String doctor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Riwayat Chat"),
        content: Text("Apakah kamu yakin ingin menghapus chat dengan $doctor?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DBService.deleteAppointment(id);
    if (!mounted) return;
    setState(() {
      _appointments.removeWhere((a) => a['id'] == id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Riwayat chat dengan $doctor telah dihapus."),
        backgroundColor: Colors.redAccent.shade200,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isChatActive(String? createdAt) {
    final date = DateTime.tryParse(createdAt ?? '');
    if (date == null) return false;
    return DateTime.now().difference(date).inMinutes < 15;
  }

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: const Color(0xFFF6EDFF),
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6EDFF).withOpacity(0),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  "Chat History",
                  style: TextStyle(
                    color: kDarkText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // List Chat
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadAppointments,
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: kPrimary),
                        )
                      : _appointments.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada riwayat chat.',
                            style: TextStyle(
                              color: kLightText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _appointments.length,
                            separatorBuilder: (_, __) => Divider(
                              color: Colors.grey.withOpacity(0.2),
                              thickness: 0.7,
                            ),
                            itemBuilder: (context, index) {
                              final a = _appointments[index];
                              final doctor = a['doctor_name'] ?? '-';
                              final specialist = a['doctor_specialist'] ?? '-';
                              final createdAt = a['created_at'] ?? '';
                              final dateStr = DateFormat('dd MMM', 'id_ID')
                                  .format(
                                    DateTime.tryParse(createdAt) ??
                                        DateTime.now(),
                                  );
                              final isActive = _isChatActive(createdAt);
                              final color = _getSpecialistColor(specialist);

                              String rawImage =
                                  a['doctor_image']?.toString() ?? '';
                              if (rawImage.isNotEmpty &&
                                  !rawImage.startsWith('http')) {
                                rawImage = 'https://api.aormed.com$rawImage';
                              }

                              return Dismissible(
                                key: ValueKey(a['id']),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  await _deleteAppointment(a['id'], doctor);
                                  return false;
                                },
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChatPage(appointment: a),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 62,
                                              height: 62,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFD9C2FF),
                                                    Color(0xFFB18CFF),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                              child: ClipOval(
                                                child: Image.network(
                                                  rawImage,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.person,
                                                        color: kPrimary,
                                                        size: 30,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    doctor,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: kDarkText,
                                                    ),
                                                  ),
                                                  Text(
                                                    dateStr,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: kLightText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: color.withOpacity(
                                                        0.1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      specialist,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    Icons.circle,
                                                    size: 8,
                                                    color: isActive
                                                        ? const Color.fromARGB(
                                                            255,
                                                            52,
                                                            189,
                                                            62,
                                                          )
                                                        : Colors.grey.shade500,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    isActive
                                                        ? 'Konsultasi aktif'
                                                        : 'Konsultasi berakhir',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: isActive
                                                          ? const Color.fromARGB(
                                                              255,
                                                              52,
                                                              189,
                                                              62,
                                                            )
                                                          : Colors
                                                                .grey
                                                                .shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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
