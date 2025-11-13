import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/safe_network_image.dart';
import 'doctor_detail_page.dart';

class DoctorsByCategoryPage extends StatefulWidget {
  final String category;
  final List<Doctor> doctors;

  const DoctorsByCategoryPage({
    super.key,
    required this.category,
    required this.doctors,
  });

  @override
  State<DoctorsByCategoryPage> createState() => _DoctorsByCategoryPageState();
}

class _DoctorsByCategoryPageState extends State<DoctorsByCategoryPage> {
  late List<Doctor> _list;
  String _query = '';
  String _sort = 'rating';

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  void _applyFilter() {
    final cat = widget.category.toLowerCase();
    _list = widget.doctors
        .where((d) => d.specialist.toLowerCase() == cat)
        .where((d) =>
            d.name.toLowerCase().contains(_query) ||
            d.location.toLowerCase().contains(_query))
        .toList();
    _sortList();
    setState(() {});
  }

  void _sortList() {
    if (_sort == 'rating') {
      _list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sort == 'name') {
      _list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == 'price') {
      int p(Doctor d) {
        final s = d.checkup.replaceAll(RegExp(r'[^0-9]'), '');
        if (s.isEmpty) return 0;
        return int.tryParse(s) ?? 0;
      }
      _list.sort((a, b) => p(a).compareTo(p(b)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: kPrimary, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.category,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kDarkText,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort_rounded, color: kPrimary),
                      onSelected: (v) {
                        _sort = v;
                        _sortList();
                        setState(() {});
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rating', child: Text('Sort by Rating')),
                        PopupMenuItem(value: 'price', child: Text('Sort by Price')),
                        PopupMenuItem(value: 'name', child: Text('Sort by Name')),
                      ],
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildSearch(),
              ),

              // Doctor List
              Expanded(
                child: _list.isEmpty
                    ? const Center(
                        child: Text(
                          'No doctors found',
                          style: TextStyle(color: kLightText),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _doctorCard(_list[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary.withOpacity(.5), width: 1.2),
      ),
      child: TextField(
        cursorColor: kPrimary,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: kPrimary),
          hintText: 'Search doctor or city',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) {
          _query = v.toLowerCase();
          _applyFilter();
        },
      ),
    );
  }

  Widget _doctorCard(Doctor d) {
    final priceIdr = parseRupiahToInt(d.checkup);
    final priceStr = formatCurrencyFromIdr(priceIdr);
    final specialistColor = _getSpecialistColor(d.specialist);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            pageBuilder: (_, __, ___) => DoctorDetailPage(doctor: d),
            transitionsBuilder: (_, anim, __, child) {
              final offsetAnim = Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: offsetAnim, child: child),
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimary.withOpacity(0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: d.image,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SafeNetworkImage(imageUrl: d.image, height: 70, width: 70),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama & Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          d.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: kDarkText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            d.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: kDarkText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Spesialis & Lokasi
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  // Jam & Harga
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled,
                          size: 14, color: kPrimary),
                      const SizedBox(width: 4),
                      Text(
                        d.availableHours,
                        style: const TextStyle(
                            fontSize: 12, color: kDarkText, height: 1.3),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.payments_rounded,
                          size: 14, color: kPrimary),
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

  Color _getSpecialistColor(String specialist) {
  final s = specialist.toLowerCase();
  if (s.contains('umum')) return const Color(0xFFE57373); 
  if (s.contains('anak')) return const Color(0xFF64B5F6); 
  if (s.contains('jantung')) return const Color(0xFFF06292); 
  if (s.contains('kulit')) return const Color(0xFF81C784); 
  if (s.contains('mata')) return const Color(0xFFFFB74D); 
  if (s.contains('kandungan')) return const Color(0xFF9575CD);
  if (s.contains('saraf')) return const Color(0xFFE57373); 
  return kPrimary; // default
}
}
