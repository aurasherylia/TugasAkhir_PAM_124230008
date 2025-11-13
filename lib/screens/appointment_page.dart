import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme.dart';
import '../models/doctor.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../utils/format.dart';
import '../services/notification_simulator.dart';
import 'schedule.dart';

class AppointmentPage extends StatefulWidget {
  final Doctor doctor;
  const AppointmentPage({super.key, required this.doctor});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  String? selectedSlot;
  DateTime selectedDate = DateTime.now();
  final TextEditingController _complaintController = TextEditingController();
  String? selectedPayment;
  bool isLoading = false;

  final _notifier = flutterLocalNotificationsPlugin;
  bool _notifInited = false;

  static const _gopay = Color(0xFF58C173);
  static const _ovo = Color(0xFF6C4DC9);
  static const _shopee = Color(0xFFFF7B45);
  static const _cc = Color(0xFFEE6D8A);

  final List<Map<String, dynamic>> _payments = const [
    {'name': 'Gopay', 'icon': Icons.qr_code_2, 'color': _gopay},
    {'name': 'OVO', 'icon': Icons.account_balance_wallet, 'color': _ovo},
    {'name': 'ShopeePay', 'icon': Icons.payments, 'color': _shopee},
    {'name': 'Credit Card', 'icon': Icons.credit_card, 'color': _cc},
  ];

  late int consultationIdr;
  final int adminFeeIdr = 10000;

  @override
  void initState() {
    super.initState();

    consultationIdr = parseRupiahToInt(widget.doctor.checkup);
    _initNotifications();

    NotificationSimulator.initialize();

    SettingsService.instance.timezone.addListener(_refresh);
    SettingsService.instance.currency.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SettingsService.instance.timezone.removeListener(_refresh);
    SettingsService.instance.currency.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _initNotifications() async {
    if (_notifInited) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String? title, String? body, String? payload) async {
            await _notifier.show(
              id,
              title ?? '💙 Selamat pembayaran anda berhasil!',
              body ?? 'Silakan konsultasi dengan dokter dalam waktu 15 menit.',
              const NotificationDetails(
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentSound: true,
                ),
                android: AndroidNotificationDetails(
                  'success_channel',
                  'Success Notifications',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
            );
          },
    );

    final settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _notifier.initialize(settings);

    final iosPlugin = _notifier
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _notifInited = true;
    debugPrint("✅ Local notifications initialized for iOS device");
  }


  String get _consultationText {
  final s = SettingsService.instance;
  final rate = s.currencyRateFromIdr;
  final prefix = s.currencyPrefix;
  final isIDR = s.currency.value == AppCurrency.idr;

  final formatted = NumberFormat(
    isIDR ? '#,###' : '#,##0.00',
    isIDR ? 'id_ID' : 'en_US',
  ).format(consultationIdr * rate);

  return '$prefix$formatted';
}

String get _adminFeeText {
  final s = SettingsService.instance;
  final rate = s.currencyRateFromIdr;
  final prefix = s.currencyPrefix;
  final isIDR = s.currency.value == AppCurrency.idr;

  final formatted = NumberFormat(
    isIDR ? '#,###' : '#,##0.00',
    isIDR ? 'id_ID' : 'en_US',
  ).format(adminFeeIdr * rate);

  return '$prefix$formatted';
}

String get _totalText {
  final s = SettingsService.instance;
  final rate = s.currencyRateFromIdr;
  final prefix = s.currencyPrefix;
  final isIDR = s.currency.value == AppCurrency.idr;

  final total = (consultationIdr + adminFeeIdr) * rate;
  final formatted = NumberFormat(
    isIDR ? '#,###' : '#,##0.00',
    isIDR ? 'id_ID' : 'en_US',
  ).format(total);

  return '$prefix$formatted';
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      body: Stack(
        children: [
          Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF2E9FF), Color(0xFFF7F3FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  child: Row(
                    children: [
                      _circleBtn(
                        Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'Book Appointment',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Color(0xFF2D2A3D),
                        ),
                      ),
                      const Spacer(),
                      _circleBtn(Icons.settings, onTap: _openQuickSettings),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                    children: [
                      _DoctorCardPremium(doctor: widget.doctor),
                      const SizedBox(height: 16),
                      _sectionTitle('Select Date'),
                      const SizedBox(height: 8),
                      _DateSelector(
                        initial: selectedDate,
                        onSelect: (d) => setState(() => selectedDate = d),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle(
                        'Appointment Time',
                        trailing: _timezoneBadge(),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kPrimary.withOpacity(0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedSlot ??
                                    'Tap to view real-time appointment time',
                                style: TextStyle(
                                  color: selectedSlot == null
                                      ? Colors.grey
                                      : kDarkText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Icon(
                                Icons.access_time_rounded,
                                color: kPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Describe Your Complaint'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _complaintController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type your symptoms or health issue...',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: kPrimary.withOpacity(.18),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sectionTitle('Payment Method'),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _payments.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 3.8,
                            ),
                        itemBuilder: (_, i) {
                          final m = _payments[i];
                          final sel = selectedPayment == m['name'];
                          return _PaymentTile(
                            name: m['name'] as String,
                            icon: m['icon'] as IconData,
                            baseColor: m['color'] as Color,
                            selected: sel,
                            onTap: () =>
                                setState(() => selectedPayment = m['name']),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle('Payment Detail'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withOpacity(.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _row('Consultation', _consultationText),
                            _row('Admin Fee', _adminFeeText),
                            const Divider(),
                            _row('Total', _totalText, bold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
              color: const Color(0xFFF7F3FF),
              child: InkWell(
                onTap:
                    (selectedSlot == null ||
                        selectedPayment == null ||
                        _complaintController.text.isEmpty)
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Please complete all fields before confirming ✨',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: kPrimary.withOpacity(0.9),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    : _confirmAndPay,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB18CFF), Color(0xFFD9C2FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Confirm Appointment',
                      style: TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final settings = SettingsService.instance;
    final tz = settings.timezone.value;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSt) {
            DateTime now = _getCurrentTimeByTimezone(tz);
            Timer? timer;

            // update jam setiap detik
            timer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (!mounted) return;
              now = _getCurrentTimeByTimezone(tz);
              if (Navigator.of(context).mounted) setSt(() {});
            });

            return SizedBox(
              height: 260,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Appointment Time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getTimezoneLabel(tz),
                          style: const TextStyle(
                            fontSize: 13,
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat('HH:mm:ss').format(now),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(160, 44),
                      ),
                      onPressed: () {
                        timer?.cancel();
                        Navigator.pop(context, now);
                      },
                      child: const Text(
                        'Use This Time',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((value) {
      if (value != null && value is DateTime) {
        // Simpan waktu + zona (tanpa UTC)
        final formatted =
            '${DateFormat('HH:mm').format(value)} ${_getTimezoneLabel(tz).split(' ').first}';
        setState(() => selectedSlot = formatted);
      }
    });
  }

  DateTime _getCurrentTimeByTimezone(AppTimezone tz) {
    final utcNow = DateTime.now().toUtc();

    final offset = SettingsService.instance.offsetHours(tz);

    return utcNow.add(Duration(hours: offset));
  }

  Future<void> _confirmAndPay() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login again — user not found.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final doctor = widget.doctor;
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

      await DBService.addAppointment(
        userId: userId,
        doctorName: doctor.name,
        doctorSpecialist: doctor.specialist,
        doctorImage: doctor.image,
        date: dateStr,
        slot: selectedSlot ?? '',
        complaint: _complaintController.text,
        paymentMethod: selectedPayment ?? '-',
        totalPrice: _totalText,
      );

      await _showPaymentSheet();
    } catch (e) {
      debugPrint('❌ Error saving appointment: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }



  Future<void> _showPaymentSheet() async {
    final totalStr = _totalText;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final qrPayload = {
          'doctor': widget.doctor.name,
          'amount': totalStr,
          'slot': selectedSlot ?? '',
          'date': DateFormat('yyyy-MM-dd').format(selectedDate),
          'method': selectedPayment ?? '-',
        }.toString();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 44,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Text(
                'Payment',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total: $totalStr',
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kPrimary.withOpacity(.15)),
                ),
                child: QrImageView(
                  data: qrPayload,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scan QR to pay via ${selectedPayment ?? '-'}',
                style: const TextStyle(color: kLightText),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble, color: Colors.white),
                  label: const Text(
                    'Consult Now',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 300));
                    await NotificationSimulator.initialize(); 
                    await NotificationSimulator.showPaymentSuccess(); 
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SchedulePage()),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimezoneLabel(AppTimezone tz) {
    switch (tz) {
      case AppTimezone.wib:
        return 'WIB';
      case AppTimezone.wita:
        return 'WITA';
      case AppTimezone.wit:
        return 'WIT';
      case AppTimezone.london:
        return 'London';
      default:
        return 'Auto';
    }
  }

  void _openQuickSettings() {
    final settings = SettingsService.instance;
    AppTimezone tempTz = settings.timezone.value;
    AppCurrency tempCur = settings.currency.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDarkText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Timezone',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppTimezone.values
                        .where((e) => e != AppTimezone.auto)
                        .map((tz) {
                          final selected = tempTz == tz;
                          return ChoiceChip(
                            label: Text(_getTimezoneLabel(tz)),
                            selected: selected,
                            selectedColor: kPrimary.withOpacity(.14),
                            onSelected: (_) async {
                              setSt(() => tempTz = tz);
                              await settings.setTimezone(tz);
                              if (mounted) setState(() {});
                            },
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Currency',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppCurrency.values.map((cur) {
                      final selected = tempCur == cur;
                      return ChoiceChip(
                        label: Text(_getCurrencyLabel(cur)),
                        selected: selected,
                        selectedColor: kPrimary.withOpacity(.14),
                        onSelected: (_) async {
                          setSt(() => tempCur = cur);
                          await settings.setCurrency(cur);
                          if (mounted) setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getCurrencyLabel(AppCurrency c) {
    switch (c) {
      case AppCurrency.idr:
        return 'Rupiah (IDR)';
      case AppCurrency.usd:
        return 'Dollar (USD)';
      case AppCurrency.eur:
        return 'Euro (EUR)';
    }
  }

  Widget _circleBtn(IconData icon, {VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: kPrimary),
    ),
  );

  Widget _sectionTitle(String text, {Widget? trailing}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: kDarkText,
        ),
      ),
      if (trailing != null) trailing,
    ],
  );

  Widget _timezoneBadge() {
    final tz = SettingsService.instance.timezone.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getTimezoneLabel(tz),
        style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: kDarkText,
          ),
        ),
      ],
    ),
  );
}

class _DoctorCardPremium extends StatelessWidget {
  const _DoctorCardPremium({required this.doctor});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.network(
              doctor.image,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: kPrimary.withOpacity(.08),
                child: const Icon(Icons.person, color: kPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kDarkText,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.local_hospital,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      doctor.specialist,
                      style: const TextStyle(color: kLightText, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: kPrimary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doctor.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kLightText, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              Text(
                doctor.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.name,
    required this.icon,
    required this.baseColor,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final Color baseColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? baseColor.withOpacity(.10) : Colors.white;
    final border = selected ? baseColor : baseColor.withOpacity(.25);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: baseColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kDarkText,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: baseColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.initial, required this.onSelect});
  final DateTime initial;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final tz = settings.timezone.value;
    final now = DateTime.now().toUtc().add(
      Duration(hours: settings.offsetHours(tz)),
    );
    final today = DateTime(now.year, now.month, now.day);

    return GestureDetector(
      onTap: () => onSelect(today),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 70,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: kPrimary.withOpacity(.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kPrimary.withOpacity(.3)),
        ),
        child: Center(
          child: Text(
            DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(today),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kPrimary,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
