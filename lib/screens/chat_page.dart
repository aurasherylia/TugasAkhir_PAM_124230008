import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/db_service.dart';
import '../widgets/safe_network_image.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> appointment;
  const ChatPage({super.key, required this.appointment});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _canChat = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadMessages();
    _checkChatWindow();

    if (_messages.isEmpty) {
      await _createInitialMessage();
      await _loadMessages();
    }
  }

  void _checkChatWindow() {
    final createdAtStr = widget.appointment['created_at'];
    if (createdAtStr == null) return;
    final createdAt = DateTime.tryParse(createdAtStr);
    if (createdAt == null) return;

    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes >= 15) {
      setState(() => _canChat = false);
    } else {
      final remaining = Duration(minutes: 15) - diff;
      Timer(remaining, () => setState(() => _canChat = false));
    }
  }

  Future<void> _createInitialMessage() async {
    final a = widget.appointment;
    final desc = a['complaint'] ?? 'Tidak ada keluhan.';
    final payment = a['payment_method'] ?? '-';
    final price = a['total_price'] ?? '-';

    final msg =
        '''
Halo! 👋
Saya ${a['doctor_name']}, ${a['doctor_specialist']}.

Berikut ringkasan janji temu Anda:
🕓 Tanggal: ${a['date']}
🩺 Keluhan: $desc
💳 Metode Pembayaran: $payment
💰 Total Pembayaran: $price

Silakan jelaskan kondisi Anda lebih detail agar saya bisa membantu 😊
''';

    await DBService.insertChat(a['id'], 'doctor', msg.trim());
  }

  Future<void> _loadMessages() async {
    final data = await DBService.getChatsByAppointment(
      widget.appointment['id'],
    );
    setState(() => _messages = data);
  }

  Future<void> _sendMessage(String text) async {
    if (!_canChat || text.trim().isEmpty) return;
    await DBService.insertChat(widget.appointment['id'], 'user', text.trim());
    _controller.clear();
    await _loadMessages();

    Future.delayed(const Duration(seconds: 1), () async {
      final reply = _generateAutoReply(text);
      await DBService.insertChat(widget.appointment['id'], 'doctor', reply);
      await _loadMessages();
    });
  }

  String _generateAutoReply(String text) {
    text = text.toLowerCase();
    if (text.contains('nyeri') || text.contains('sakit')) {
      return 'Terima kasih atas penjelasannya, bisa dijelaskan sejak kapan keluhan ini dirasakan? 😊';
    } else if (text.contains('obat')) {
      return 'Saya akan bantu rekomendasikan obat yang sesuai setelah menilai gejala Anda ya 💊';
    } else if (text.contains('terima kasih')) {
      return 'Sama-sama, semoga lekas membaik 💜';
    }
    return 'Baik, saya catat ya. Bisa diceritakan lebih detail gejalanya? 🩺';
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
    final a = widget.appointment;
    final specialistColor = _getSpecialistColor(a['doctor_specialist'] ?? '');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6EDFF), Color(0xFFEADAFD), Color(0xFFD9C2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildHeader(a, specialistColor),
        body: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        "Belum ada percakapan.",
                        style: TextStyle(color: kLightText),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isUser = msg['sender'] == 'user';

                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFFE6D5FF) // bubble user
                                  : Colors.white,
                              border: Border.all(
                                color: isUser
                                    ? const Color(0xFFB388FF)
                                    : const Color.fromARGB(255, 243, 216, 255),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: isUser
                                    ? const Radius.circular(18)
                                    : const Radius.circular(4),
                                bottomRight: isUser
                                    ? const Radius.circular(4)
                                    : const Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg['message'],
                              style: TextStyle(
                                color: isUser ? kDarkText : kDarkText,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            if (!_canChat)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(
                  bottom: 0,
                ), // 🔹 Naik lebih ke atas
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  "⚠️ Waktu konsultasi telah berakhir. \n\n",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontSize: 13,
                  ),
                ),
              ),

            if (_canChat) _buildInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(
    Map<String, dynamic> a,
    Color specialistColor,
  ) {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFD9C2FF), Color(0xFFB18CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: a['doctor_image'] ?? '',
                    height: 46,
                    width: 46,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a['doctor_name'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                  fontSize: 16,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: specialistColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  a['doctor_specialist'] ?? '',
                  style: TextStyle(
                    color: specialistColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: "Ketik pesan...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: kPrimary),
              onPressed: () => _sendMessage(_controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
