import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/safe_network_image.dart';
import 'doctor_detail_page.dart';

class SearchPage extends StatefulWidget {
  final List<Doctor> allDoctors;
  const SearchPage({super.key, required this.allDoctors});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allDoctors.where((d) {
      if (q.isEmpty) return false;
      final s = q.toLowerCase();
      return d.name.toLowerCase().contains(s) ||
          d.specialist.toLowerCase().contains(s) ||
          d.location.toLowerCase().contains(s) ||
          d.hospital.toLowerCase().contains(s);
    }).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6EDFF), Color(0xFFEADAFD), Color(0xFFD9C2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: kPrimary,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Search",
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

              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: _searchBar(),
              ),

              // HASIL PENCARIAN
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Search doctor, specialist, or city...',
                          style: TextStyle(color: kLightText, fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _doctorCard(filtered[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //SEARCH BAR 
  Widget _searchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary.withOpacity(.5), width: 1.3),
      ),
      child: TextField(
        autofocus: true,
        cursorColor: kPrimary,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 14, color: kDarkText),
        decoration: const InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.search_rounded, color: kPrimary, size: 20),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 36),
          hintText: 'Search doctor, specialist, or city...',
          hintStyle: TextStyle(color: kLightText, fontSize: 14.5),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() => q = v),
      ),
    );
  }

  // DOCTOR CARD 
  Widget _doctorCard(Doctor d) {
    final priceIdr = parseRupiahToInt(d.checkup);
    final priceStr = formatCurrencyFromIdr(priceIdr);
    final hours = convertHours(d.availableHours);
    final specialistColor = _getSpecialistColor(d.specialist);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withOpacity(0.65), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DoctorDetailPage(doctor: d)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: d.image,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SafeNetworkImage(
                  imageUrl: d.image,
                  height: 70,
                  width: 70,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kDarkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: specialistColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          d.specialist,
                          style: TextStyle(
                            color: specialistColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '• ${d.location}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kLightText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_filled,
                        size: 14,
                        color: kPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hours,
                        style: const TextStyle(fontSize: 12, color: kDarkText),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.payments_rounded,
                        size: 14,
                        color: kPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        priceStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kPrimary,
                          fontSize: 12,
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
    );
  }

  /// COLOR PER SPECIALIST
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
}
