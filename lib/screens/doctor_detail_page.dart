import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/doctor.dart';
import '../theme.dart';
import '../services/settings_service.dart';
import '../utils/format.dart';
import '../widgets/safe_network_image.dart';
import 'appointment_page.dart';

class DoctorDetailPage extends StatefulWidget {
  final Doctor doctor;
  const DoctorDetailPage({super.key, required this.doctor});

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  bool isFav = false;
  bool hovered = false;

  @override
  void initState() {
    super.initState();
    SettingsService.instance.timezone.addListener(_onSettingsChanged);
    SettingsService.instance.currency.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    SettingsService.instance.timezone.removeListener(_onSettingsChanged);
    SettingsService.instance.currency.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  String _priceText() {
    final priceIdr = parseRupiahToInt(widget.doctor.checkup);
    return formatCurrencyFromIdr(priceIdr);
  }

  List<String> _slotsForCurrentTimezone() {
    final tz = SettingsService.instance.timezone.value;
    int offsetHours = 0;
    if (tz == AppTimezone.wita) offsetHours = 1;
    if (tz == AppTimezone.wit) offsetHours = 2;

    String shift(String s) {
      final parts = s.split(':');
      if (parts.length != 2) return s;
      int h = int.tryParse(parts[0]) ?? 0;
      int m = int.tryParse(parts[1]) ?? 0;
      h = (h + offsetHours) % 24;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    String convert(String raw) {
      if (raw.contains('-')) {
        final seg = raw.split('-');
        if (seg.length >= 2) {
          return '${shift(seg[0].trim())} - ${shift(seg[1].trim())}';
        }
      }
      return shift(raw.trim());
    }

    return widget.doctor.slots.map(convert).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bgGradient = const LinearGradient(
      colors: [Color(0xFFF6EDFF), Color(0xFFEADAFD), Color(0xFFD9C2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final price = _priceText();
    final slots = _slotsForCurrentTimezone();

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.95,
                            height: 260,
                            child: SafeNetworkImage(
                              imageUrl: widget.doctor.image,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 16,
                        child: _circleBtn(
                          Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 16,
                        child: _circleBtn(
                          Icons.favorite_rounded,
                          color: isFav ? Colors.red : Colors.grey.shade400,
                          onTap: () => setState(() => isFav = !isFav),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              DraggableScrollableSheet(
                initialChildSize: 0.68,
                minChildSize: 0.65,
                maxChildSize: 0.95,
                builder: (_, controller) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: ListView(
                      controller: controller,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, color: Color(0xFF9B6EFF)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.doctor.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: kDarkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Symbols.stethoscope, color: Color(0xFF81C784), size: 20),
                            const SizedBox(width: 6),
                            Text(widget.doctor.specialist,
                                style: const TextStyle(color: kLightText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                            Text(widget.doctor.rating.toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 14),
                            const Icon(Icons.location_on_rounded,
                                color: Color(0xFF64B5F6), size: 20),
                            Expanded(
                              child: Text(widget.doctor.location,
                                  style: const TextStyle(color: kLightText)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _statsRow(),
                        const SizedBox(height: 22),
                        const Text('Biography',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: kDarkText)),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.doctor.alumni}\n\nDr. ${widget.doctor.name.split(" ").last} has ${widget.doctor.yearsOfWork} years of experience and has treated ${widget.doctor.numberOfPatients}+ patients.',
                          style: const TextStyle(color: kLightText, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available Schedule',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: kDarkText)),
                            _timezoneBadge(),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final s in slots) _slotChip(s)],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_money_rounded,
                                  color: kPrimary, size: 22),
                              const SizedBox(width: 8),
                              const Text('Consultation Fee',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, color: kDarkText)),
                              const Spacer(),
                              Text(price,
                                  style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  );
                },
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
                  color: Colors.white,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => hovered = true),
                    onExit: (_) => setState(() => hovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      transform:
                          hovered ? (Matrix4.identity()..scale(1.04)) : Matrix4.identity(),
                      curve: Curves.easeOutCubic,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hovered
                              ? [const Color(0xFFD9C2FF), const Color(0xFFB18CFF)]
                              : [const Color(0xFFB18CFF), const Color(0xFFD9C2FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimary.withOpacity(.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AppointmentPage(doctor: widget.doctor)),
                          );
                        },
                        child: const Center(
                          child: Text('Make an Appointment',
                              style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                      ),
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

  Widget _statsRow() {
    return Row(
      children: [
        _statBox(Icons.people_alt_rounded, 'Patients',
            '${widget.doctor.numberOfPatients}+', const Color(0xFFFFE5E5)),
        const SizedBox(width: 10),
        _statBox(Symbols.badge, 'Experience',
            '${widget.doctor.yearsOfWork} Years', const Color(0xFFE8F5E9)),
        const SizedBox(width: 10),
        _statBox(Icons.star_rounded, 'Rate',
            widget.doctor.rating.toStringAsFixed(1), const Color(0xFFE3F2FD)),
      ],
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          color: color.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kPrimary, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: kDarkText)),
            Text(label,
                style: const TextStyle(color: kLightText, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _slotChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary.withOpacity(.15)),
      ),
      child: Text(text,
          style: const TextStyle(
              color: kDarkText, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _timezoneBadge() {
    final tz = SettingsService.instance.timezone.value;
    String label;
    switch (tz) {
      case AppTimezone.wib:
        label = 'WIB (UTC+7)';
        break;
      case AppTimezone.wita:
        label = 'WITA (UTC+8)';
        break;
      case AppTimezone.wit:
        label = 'WIT (UTC+9)';
        break;
      default:
        label = 'AUTO';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(
              color: kPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _circleBtn(IconData icon, {Color color = kPrimary, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
