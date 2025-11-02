import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme.dart';
import 'doctors_by_category_page.dart';

class AllCategoriesPage extends StatelessWidget {
  final List<String> categories;
  final List<Doctor> doctors;

  const AllCategoriesPage({
    super.key,
    required this.categories,
    required this.doctors,
  });

  @override
  Widget build(BuildContext context) {
    // palet pastel sama seperti Home Page
    final pastel = [
      (bg: const Color(0xFFFFE5E5), icon: const Color(0xFFE57373)), // Dokter Umum
      (bg: const Color(0xFFE3F2FD), icon: const Color(0xFF64B5F6)), // Anak
      (bg: const Color(0xFFFCE4EC), icon: const Color(0xFFF06292)), // Jantung
      (bg: const Color(0xFFE8F5E9), icon: const Color(0xFF81C784)), // Kulit
      (bg: const Color(0xFFFFF8E1), icon: const Color(0xFFFFB74D)), // Mata
      (bg: const Color(0xFFEDE7F6), icon: const Color(0xFF9575CD)), // Kandungan
    ];

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
              // ================= HEADER =================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: kPrimary, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "All Specialists",
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

              // ================= GRID SPECIALISTS =================
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: GridView.builder(
                    itemCount: categories.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final pal = pastel[index % pastel.length]; // loop warna pastel
                      final icon = _getCategoryIcon(cat);

                      return _CategoryTile(
                        title: cat,
                        colorBg: pal.bg,
                        colorIcon: pal.icon,
                        icon: icon,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration:
                                  const Duration(milliseconds: 450),
                              pageBuilder: (_, __, ___) => DoctorsByCategoryPage(
                                category: cat,
                                doctors: doctors,
                              ),
                              transitionsBuilder: (_, anim, __, child) {
                                final offsetAnim = Tween<Offset>(
                                  begin: const Offset(0, 0.05),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: anim, curve: Curves.easeOutCubic));
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                      position: offsetAnim, child: child),
                                );
                              },
                            ),
                          );
                        },
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

  /// Ikon per spesialis (sama seperti Home Page)
  IconData _getCategoryIcon(String cat) {
    final s = cat.toLowerCase();
    if (s.contains('umum')) return Icons.local_hospital;
    if (s.contains('anak')) return Icons.child_care;
    if (s.contains('jantung')) return Icons.favorite;
    if (s.contains('kulit')) return Icons.healing;
    if (s.contains('mata')) return Icons.remove_red_eye;
    if (s.contains('kandungan')) return Icons.pregnant_woman;
    return Icons.medical_services;
  }
}

/// ================= TILE SPESIALIS =================
class _CategoryTile extends StatefulWidget {
  final String title;
  final Color colorBg;
  final Color colorIcon;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.title,
    required this.colorBg,
    required this.colorIcon,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: widget.colorIcon.withOpacity(0.2),
        highlightColor: Colors.transparent,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.colorBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 30, color: widget.colorIcon),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kDarkText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
