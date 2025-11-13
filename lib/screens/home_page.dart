// lib/screens/home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// OpenStreetMap (flutter_map)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/doctor.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/safe_network_image.dart';
import 'all_categories_page.dart';
import 'doctors_by_category_page.dart';
import 'doctor_detail_page.dart';
import 'search_page.dart';
import 'chat_history_page.dart';
import 'schedule.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  bool error = false;

  String username = 'User';
  String userCity = 'Loading...';
  int selectedIndex = 0;

  // Posisi efektif: realtime GPS atau manual dari OSM
  Position? userPositionRealtime;
  Position? _manualPosition;
  bool _useRealtimeLocation = true;

  List<Doctor> doctors = [];
  List<Doctor> topDoctors = [];
  List<Doctor> nearbyDoctors = [];
  List<String> categories = [];
  Set<int> favorites = {};

  // cache geocoding alamat -> koordinat
  final Map<String, GeoCacheItem> _geoCache = {};
  // cache jarak doctor.id -> km
  final Map<int, double> _doctorDistanceKm = {};

  late final PageController _pageCtrl;
  int _pageIndex = 0;
  Timer? _autoTimer;

  StreamSubscription<Position>? _posSub;

  // Override timezone lokal halaman ini (opsional)
  AppTimezone? _tzOverride;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.93);
    _startAutoSlide();
    _boot();
    SettingsService.instance.timezone.addListener(_settingsChanged);
    SettingsService.instance.currency.addListener(_settingsChanged);

    ProfileUpdateBus.instance.stream.listen((_) async {
    final sp = await SharedPreferences.getInstance();
    final newName = sp.getString('username') ?? 'User';
    if (mounted) setState(() => username = newName);
  });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    _posSub?.cancel();
    SettingsService.instance.timezone.removeListener(_settingsChanged);
    SettingsService.instance.currency.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  void _startAutoSlide() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageCtrl.hasClients) return;
      final next = (_pageIndex + 1) % 3;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _boot() async {
    try {
      await SettingsService.instance.load();
      final sp = await SharedPreferences.getInstance();
      username = sp.getString('username') ?? 'User';

      // Inisialisasi lokasi realtime awal
      await _initRealtimeLocation();

      // Data dokter
      doctors = await APIService.fetchDoctors();
      categories = doctors.map((d) => d.specialist).toSet().toList();

      // Top dokter by patients
      doctors.sort((a, b) => b.numberOfPatients.compareTo(a.numberOfPatients));
      topDoctors = doctors.take(5).toList();

      // Nearby awal
      await _loadNearbyDoctors();
    } catch (e) {
      error = true;
    }
    if (mounted) setState(() => loading = false);
  }

  // POSISI EFEKTIF + TZ
  Position? get _effectivePosition =>
      _useRealtimeLocation ? userPositionRealtime : _manualPosition;

  AppTimezone get _effectiveTimezone {
    if (_tzOverride != null) return _tzOverride!;
    return SettingsService.instance.timezone.value;
  }

  // REALTIME LOCATION (GPS)
  Future<void> _initRealtimeLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => userCity = 'Location service off');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() => userCity = 'Permission denied');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => userCity = 'Enable location in Settings');
        return;
      }

      // Posisi awal
      userPositionRealtime = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      userCity = await _getCityName(userPositionRealtime!);
      if (mounted) setState(() {});

      // Stream posisi (bergerak >= default distance)
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 50,
        ),
      ).listen((pos) async {
        if (!mounted) return;
        userPositionRealtime = pos;
        if (_useRealtimeLocation) {
          final city = await _getCityName(pos);
          await _loadNearbyDoctors();
          if (mounted) setState(() => userCity = city);
        }
      }, onError: (_) {
        if (mounted) setState(() => userCity = 'Error getting location');
      });
    } catch (_) {
      if (mounted) setState(() => userCity = 'Unknown');
    }
  }

  Future<String> _getCityName(Position pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.first;
      return p.locality ?? p.subAdministrativeArea ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  // Deteksi zona waktu dari longitude (kasar)
  AppTimezone _timezoneFromLongitude(double lon) {
    if (lon >= 128) return AppTimezone.wit;   // UTC+9
    if (lon >= 115) return AppTimezone.wita;  // UTC+8
    if (lon <= 0) return AppTimezone.london;  // UTC+0 untuk Eropa barat
    return AppTimezone.wib;                   // default Indonesia barat UTC+7
  }

  // NEARBY DOCTORS (pakai _effectivePosition)
  Future<void> _loadNearbyDoctors() async {
    final pos = _effectivePosition;
    if (pos == null || doctors.isEmpty) return;

    // geocoding alamat dokter -> koordinat (cache 1 jam)
    final now = DateTime.now();
    for (final d in doctors) {
      final addr = (d.location).trim();
      if (addr.isEmpty) continue;

      GeoCacheItem? cached = _geoCache[addr];
      _LatLng coords;

      if (cached != null && now.difference(cached.ts) < const Duration(hours: 1)) {
        coords = cached.coords;
      } else {
        try {
          final res = await locationFromAddress(addr);
          if (res.isEmpty) continue;
          coords = _LatLng(res.first.latitude, res.first.longitude);
          _geoCache[addr] = GeoCacheItem(coords, now);
        } catch (_) {
          // skip jika gagal geocode
          continue;
        }
      }

      // hitung jarak
      final km = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            coords.lat,
            coords.lon,
          ) /
          1000.0;

      _doctorDistanceKm[d.id] = km;
    }

    // sortir berdasarkan jarak yang sudah ada
    final withDistance = doctors.where((d) => _doctorDistanceKm.containsKey(d.id)).toList();
    withDistance.sort((a, b) => _doctorDistanceKm[a.id]!.compareTo(_doctorDistanceKm[b.id]!));

    nearbyDoctors = withDistance.take(6).toList();

    if (mounted) setState(() {});
  }

  String _convertAvailableHours(String hours) {
    String cleaned = hours
        .replaceAll('–', '-') 
        .replaceAll('—', '-')   
        .replaceAll('.', ':')  
        .trim();

    final parts = cleaned.split(RegExp(r'\s*-\s*'));
    if (parts.isEmpty) return hours;

    String normalize(String hhmm) {
      if (!hhmm.contains(':')) hhmm = '$hhmm:00';
      final bits = hhmm.split(':');
      int h = int.tryParse(bits[0]) ?? 0;
      int m = int.tryParse(bits.length > 1 ? bits[1] : '0') ?? 0;

      int offset = 0;
      final tz = _effectiveTimezone;
      if (tz == AppTimezone.wita) offset = 1;    
      if (tz == AppTimezone.wit) offset = 2;    
      if (tz == AppTimezone.london) offset = -7; 

      h = (h + offset) % 24;
      if (h < 0) h += 24; 
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    if (parts.length == 2) {
      final start = normalize(parts[0]);
      final end = normalize(parts[1]);
      return '$start - $end';
    }

    return normalize(parts.first);
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final bg = const LinearGradient(
      colors: [Color(0xFFF6EDFF), Color(0xFFEADAFD), Color(0xFFD9C2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final pages = [
      _buildHomeContent(),
      const SchedulePage(),
      const ChatHistoryPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(gradient: bg),
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : error
                  ? const Center(child: Text('Failed to load data.'))
                  : pages[selectedIndex],
        ),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildHomeContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _searchLauncher(),
        const SizedBox(height: 18),
        _bannerSlider(),
        const SizedBox(height: 22),
        _buildCategories(),
        const SizedBox(height: 20),

        _sectionTitle('Nearby Doctors'),
        const SizedBox(height: 12),
        _buildNearbyDoctors(),

        const SizedBox(height: 26),
        _sectionTitle('Top Doctor'),
        const SizedBox(height: 12),
        _buildTopDoctors(),
      ],
    );
  }

  // HEADER
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4E9FF), Color(0xFFE8D9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Image.asset('assets/images/logo.png', height: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama pengguna
                RichText(
                  text: TextSpan(
                    text: 'Welcome, ',
                    style: const TextStyle(
                      color: kDarkText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 226, 200, 244).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            username,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(
                        text: ' 👋',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: _openLocationPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: kPrimary, size: 16),
                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          userCity,
                          key: ValueKey(userCity),
                          style: const TextStyle(
                            fontSize: 14,
                            color: kDarkText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: kPrimary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: kPrimary),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  // SEARCH (launch to SearchPage)
  Widget _searchLauncher() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SearchPage(allDoctors: doctors)),
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kPrimary.withOpacity(.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: kPrimary),
            SizedBox(width: 8),
            Text('Search doctor, specialist, or city...',
                style: TextStyle(color: kLightText)),
          ],
        ),
      ),
    );
  }

  // BANNER SLIDER
  Widget _bannerSlider() {
    final slides = [
      _PromoSlide(
        'Healthy or Expensive?',
        'Start caring today before it’s too late.',
        'assets/images/dokter1.png',
        const [Color(0xFFDFE7FD), Color(0xFFC6D0FF)],
      ),
      _PromoSlide(
        'Find Your Specialist',
        'Top-rated doctors ready to help you.',
        'assets/images/dokter2.png',
        const [Color(0xFFE8F6EF), Color(0xFFCDECDC)],
      ),
      _PromoSlide(
        'Consult Online',
        'Anytime, anywhere, in minutes.',
        'assets/images/dokter3.png',
        const [Color(0xFFFFF0F5), Color(0xFFFFDFE8)],
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemCount: slides.length,
            itemBuilder: (_, i) {
              return AnimatedBuilder(
                animation: _pageCtrl,
                builder: (context, child) {
                  double t = 1.0;
                  if (_pageCtrl.hasClients && _pageCtrl.position.haveDimensions) {
                    final page = _pageCtrl.page ?? _pageCtrl.initialPage.toDouble();
                    t = 1 - ((page - i).abs() * 0.3);
                    t = math.max(.9, math.min(1.0, t));
                  }
                  return Transform.scale(scale: t, child: child!);
                },
                child: _BannerCard(slide: slides[i]),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (i) {
            final active = _pageIndex == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: active ? 26 : 8,
              decoration: BoxDecoration(
                color: active ? kPrimary : kPrimary.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  // CATEGORIES
  Widget _buildCategories() {
    final pastel = [
      (bg: const Color(0xFFFFE5E5), icon: const Color(0xFFE57373)), // Umum
      (bg: const Color(0xFFE3F2FD), icon: const Color(0xFF64B5F6)), // Anak
      (bg: const Color(0xFFFCE4EC), icon: const Color(0xFFF06292)), // Jantung
      (bg: const Color(0xFFE8F5E9), icon: const Color(0xFF81C784)), // Kulit
      (bg: const Color(0xFFFFF8E1), icon: const Color(0xFFFFB74D)), // Mata
      (bg: const Color(0xFFEDE7F6), icon: const Color(0xFF9575CD)), // Kandungan
      (bg: const Color(0xFFFFE5E5), icon: const Color(0xFFE57373)), // Saraf
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Categories', onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AllCategoriesPage(categories: categories, doctors: doctors),
            ),
          );
        }),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length.clamp(0, 7),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final pal = pastel[i % pastel.length];
              return _CategoryChip(
                label: cat,
                icon: _getCategoryIcon(cat),
                bg: pal.bg,
                iconColor: pal.icon,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorsByCategoryPage(
                        category: cat,
                        doctors: doctors,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Ikon kategori
  IconData _getCategoryIcon(String cat) {
    final s = cat.toLowerCase();
    if (s.contains('umum')) return Icons.local_hospital;
    if (s.contains('anak')) return Icons.child_care;
    if (s.contains('jantung')) return Icons.favorite;
    if (s.contains('kulit')) return Icons.healing;
    if (s.contains('mata')) return Icons.remove_red_eye;
    if (s.contains('kandungan')) return Icons.pregnant_woman;
    if (s.contains('saraf')) return Icons.medical_services;
    return Icons.medical_information;
  }

  // NEARBY DOCTORS
  Widget _buildNearbyDoctors() {
    if (nearbyDoctors.isEmpty) {
      return const Text('No nearby doctors found.');
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 300,
      ),
      itemCount: nearbyDoctors.length,
      itemBuilder: (_, i) {
        final d = nearbyDoctors[i];
        final priceIdr = parseRupiahToInt(d.checkup);
        final priceStr = formatCurrencyFromIdr(priceIdr);
        final dist = _doctorDistanceKm[d.id];
        final adjustedHours = _convertAvailableHours(d.availableHours);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DoctorDetailPage(doctor: d)),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: SafeNetworkImage(
                      imageUrl: d.image,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kDarkText,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  d.specialist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kLightText, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(' ${d.rating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.location_on, size: 13, color: kPrimary),
                    Text(
                      dist != null ? '${dist.toStringAsFixed(1)} km' : d.location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  priceStr,
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 13, color: kPrimary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          adjustedHours,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // TOP DOCTORS
  Widget _buildTopDoctors() {
    final displayedDoctors = topDoctors.take(6).toList();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 300,
      ),
      itemCount: displayedDoctors.length,
      itemBuilder: (_, i) {
        final d = displayedDoctors[i];
        final isFav = favorites.contains(d.id);
        final priceIdr = parseRupiahToInt(d.checkup);
        final priceStr = formatCurrencyFromIdr(priceIdr);
        final adjustedHours = _convertAvailableHours(d.availableHours);

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DoctorDetailPage(doctor: d)),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: SafeNetworkImage(
                      imageUrl: d.image,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: kDarkText,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        isFav ? favorites.remove(d.id) : favorites.add(d.id);
                      }),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: isFav ? Colors.red : Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  d.specialist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kLightText, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(' ${d.rating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    const Icon(Icons.location_on, size: 13, color: kPrimary),
                    Expanded(
                      child: Text(
                        d.location,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: kPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  priceStr,
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 13, color: kPrimary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          adjustedHours,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NAV BAR
  Widget _buildNavBar() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Schedule'},
      {'icon': Icons.chat_bubble, 'label': 'Chats'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = selectedIndex == i;
          return GestureDetector(
            onTap: () => setState(() => selectedIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? kPrimary.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Icon(items[i]['icon'] as IconData,
                      color: active ? kPrimary : kLightText),
                  if (active)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(items[i]['label'] as String,
                          style: const TextStyle(
                              color: kPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // SETTINGS POPUP
  void _openSettings() {
    final s = SettingsService.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        AppTimezone tz = s.timezone.value;
        AppCurrency cur = s.currency.value;
        return StatefulBuilder(builder: (context, setSt) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Timezone', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('London (UTC+0)'),
                      selected: tz == AppTimezone.london,
                      onSelected: (_) => setSt(() => tz = AppTimezone.london),
                    ),
                    ChoiceChip(
                      label: const Text('WIB (UTC+7)'),
                      selected: tz == AppTimezone.wib,
                      onSelected: (_) => setSt(() => tz = AppTimezone.wib),
                    ),
                    ChoiceChip(
                      label: const Text('WITA (UTC+8)'),
                      selected: tz == AppTimezone.wita,
                      onSelected: (_) => setSt(() => tz = AppTimezone.wita),
                    ),
                    ChoiceChip(
                      label: const Text('WIT (UTC+9)'),
                      selected: tz == AppTimezone.wit,
                      onSelected: (_) => setSt(() => tz = AppTimezone.wit),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Rupiah (IDR)'),
                      selected: cur == AppCurrency.idr,
                      onSelected: (_) => setSt(() => cur = AppCurrency.idr),
                    ),
                    ChoiceChip(
                      label: const Text('Dollar (USD)'),
                      selected: cur == AppCurrency.usd,
                      onSelected: (_) => setSt(() => cur = AppCurrency.usd),
                    ),
                    ChoiceChip(
                      label: const Text('Euro (EUR)'),
                      selected: cur == AppCurrency.eur,
                      onSelected: (_) => setSt(() => cur = AppCurrency.eur),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await s.setTimezone(tz);
                      await s.setCurrency(cur);
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    },
                    child: const Text('Apply', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          );
        });
      },
    );
  }

  // LOKASI 
  void _openLocationPicker() {
    AppTimezone pickedTz = _effectiveTimezone;
    bool useRealtime = _useRealtimeLocation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 18,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Lokasi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: useRealtime,
                      onChanged: (v) => setSt(() => useRealtime = v),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        useRealtime
                            ? 'Gunakan lokasi real-time (GPS)'
                            : 'Gunakan lokasi manual',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!useRealtime) ...[
                  const Text('Klik lokasi pada peta:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(-6.200000, 106.816666), 
                        zoom: 11.0,
                        onTap: (tapPos, latLng) async {
                          final pos = Position(
                            latitude: latLng.latitude,
                            longitude: latLng.longitude,
                            accuracy: 0,
                            altitude: 0,
                            heading: 0,
                            speed: 0,
                            speedAccuracy: 0,
                            timestamp: DateTime.now(),
                            altitudeAccuracy: 0,
                            headingAccuracy: 0,
                          );
                          final city = await _getCityName(pos);
                          setSt(() {
                            _manualPosition = pos;
                            userCity = city;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        if (_manualPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _manualPosition!.latitude,
                                  _manualPosition!.longitude,
                                ),
                                width: 60,
                                height: 60,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Kota: $userCity',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  const Text('Pilih Zona Waktu:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('London'),
                        selected: pickedTz == AppTimezone.london,
                        onSelected: (_) => setSt(() => pickedTz = AppTimezone.london),
                      ),
                      ChoiceChip(
                        label: const Text('WIB'),
                        selected: pickedTz == AppTimezone.wib,
                        onSelected: (_) => setSt(() => pickedTz = AppTimezone.wib),
                      ),
                      ChoiceChip(
                        label: const Text('WITA'),
                        selected: pickedTz == AppTimezone.wita,
                        onSelected: (_) => setSt(() => pickedTz = AppTimezone.wita),
                      ),
                      ChoiceChip(
                        label: const Text('WIT'),
                        selected: pickedTz == AppTimezone.wit,
                        onSelected: (_) => setSt(() => pickedTz = AppTimezone.wit),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('Gunakan GPS Sekarang'),
                        onPressed: () async {
                          try {
                            final pos = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.bestForNavigation,
                            );
                            final city = await _getCityName(pos);
                            if (!mounted) return;
                            setState(() {
                              _useRealtimeLocation = true;
                              _manualPosition = null;
                              userPositionRealtime = pos;
                              userCity = city;
                              _tzOverride = null; // kembali ke setting / tz efektif
                            });
                            await _loadNearbyDoctors();
                            if (mounted) Navigator.pop(ctx);
                          } catch (_) {}
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          if (useRealtime) {
                            if (!mounted) return;
                            setState(() {
                              _useRealtimeLocation = true;
                              _manualPosition = null;
                              _tzOverride = null; // pakai setting global
                            });
                            await _loadNearbyDoctors();
                            if (mounted) Navigator.pop(ctx);
                            return;
                          }

                          if (_manualPosition == null) return;
                          final pos = _manualPosition!;
                          final city = await _getCityName(pos);
                          AppTimezone inferred = _timezoneFromLongitude(pos.longitude);
                          final tzToUse = pickedTz;
                          if (!mounted) return;
                          setState(() {
                            _useRealtimeLocation = false;
                            userCity = city;
                            _tzOverride = tzToUse; // jika null → tetap null (pakai Settings)
                            _tzOverride ??= inferred;
                          });

                          await _loadNearbyDoctors();
                          if (mounted) Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _sectionTitle(String title, {VoidCallback? onSeeAll}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('See All',
                  style: TextStyle(color: kPrimary, fontWeight: FontWeight.w600)),
            ),
        ],
      );
}

// MODELS & EXTRA WIDGETS
class _PromoSlide {
  final String title, sub, image;
  final List<Color> colors;
  _PromoSlide(this.title, this.sub, this.image, this.colors);
}

class _BannerCard extends StatelessWidget {
  final _PromoSlide slide;
  const _BannerCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: slide.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slide.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18, color: kDarkText)),
                  const SizedBox(height: 6),
                  Text(slide.sub,
                      style:
                          const TextStyle(color: kLightText, fontSize: 14, height: 1.3)),
                ],
              ),
            ),
          ),
          Image.asset(slide.image, height: 110),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.bg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 95,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: kDarkText, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatLng {
  final double lat;
  final double lon;
  const _LatLng(this.lat, this.lon);
}

class GeoCacheItem {
  final _LatLng coords;
  final DateTime ts;
  GeoCacheItem(this.coords, this.ts);
}
