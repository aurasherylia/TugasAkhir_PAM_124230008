import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/db_service.dart';
import 'login_page.dart';

/// ======== Event Bus agar HomePage ikut ter-update realtime ========
class ProfileUpdateBus {
  ProfileUpdateBus._();
  static final ProfileUpdateBus instance = ProfileUpdateBus._();
  final _ctrl = StreamController<void>.broadcast();
  Stream<void> get stream => _ctrl.stream;
  void notify() => _ctrl.add(null);
}

/// =================================================================
///                            PROFILE PAGE
/// =================================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int? _userId;
  String _username = 'User';
  String _nim = '124230008';
  String? _photoPath;
  bool _loading = true;

  final _picker = ImagePicker();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    _userId = sp.getInt('user_id') ?? 1;
    _photoPath = sp.getString('photoPath');
    _username = sp.getString('username') ?? 'User';
    _nim = sp.getString('nim') ?? '124230008';
  if (!sp.containsKey('nim')) {
    await sp.setString('nim', _nim);
  }
    setState(() => _loading = false);
  }

  /// ==================== Edit Username ====================
  Future<void> _editUsername() async {
    final nameCtrl = TextEditingController(text: _username);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final width = MediaQuery.of(ctx).size.width * 0.85;
        return AlertDialog(
          backgroundColor: const Color(0xFFF8F4FF),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          content: SizedBox(
            width: width,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.person_outline, color: kPrimary),
                      SizedBox(width: 8),
                      Text(
                        "Edit Profile",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kDarkText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Username tidak boleh kosong'
                        : null,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: const Icon(Icons.person, color: kPrimary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: kPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "NIM: $_nim (tidak dapat diubah)",
                            style: const TextStyle(
                                color: kLightText,
                                fontWeight: FontWeight.w500,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Batal",
                          style: TextStyle(
                              color: kPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          final name = nameCtrl.text.trim();

                          try {
                            final db = await DBService.database;
                            await db.update('users', {'username': name},
                                where: 'id = ?', whereArgs: [_userId]);
                            final sp = await SharedPreferences.getInstance();
                            await sp.setString('username', name);

                            if (!mounted) return;
                            setState(() => _username = name);
                            ProfileUpdateBus.instance.notify();
                            Navigator.pop(ctx);
                            _snack("Profil berhasil diperbarui!", Colors.green);
                          } catch (e) {
                            _snack("Gagal menyimpan perubahan", Colors.red);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text("Simpan",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _changePassword() async {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool ob1 = true, ob2 = true, ob3 = true;

  // Simpan context utama agar tidak hilang
  final rootContext = context;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final screenWidth = MediaQuery.of(ctx).size.width;
      return AlertDialog(
        backgroundColor: const Color(0xFFF8F4FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: StatefulBuilder(
          builder: (context, setSt) {
            return SizedBox(
              width: screenWidth * 0.9,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.lock_outline, color: kPrimary, size: 26),
                          SizedBox(width: 10),
                          Text(
                            "Ganti Password",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kDarkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Password lama
                      TextFormField(
                        controller: oldCtrl,
                        obscureText: ob1,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Isi password lama' : null,
                        decoration: InputDecoration(
                          labelText: "Password Lama",
                          prefixIcon:
                              const Icon(Icons.lock_outline, color: kPrimary),
                          suffixIcon: IconButton(
                            icon: Icon(
                                ob1 ? Icons.visibility_off : Icons.visibility,
                                color: kPrimary),
                            onPressed: () => setSt(() => ob1 = !ob1),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password baru
                      TextFormField(
                        controller: newCtrl,
                        obscureText: ob2,
                        validator: (v) =>
                            (v != null && v.length >= 6) ? null : 'Minimal 6 karakter',
                        decoration: InputDecoration(
                          labelText: "Password Baru",
                          prefixIcon: const Icon(Icons.lock, color: kPrimary),
                          suffixIcon: IconButton(
                            icon: Icon(
                                ob2 ? Icons.visibility_off : Icons.visibility,
                                color: kPrimary),
                            onPressed: () => setSt(() => ob2 = !ob2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Konfirmasi password
                      TextFormField(
                        controller: confCtrl,
                        obscureText: ob3,
                        validator: (v) =>
                            v == newCtrl.text ? null : 'Konfirmasi tidak cocok',
                        decoration: InputDecoration(
                          labelText: "Konfirmasi Password Baru",
                          prefixIcon:
                              const Icon(Icons.lock_reset, color: kPrimary),
                          suffixIcon: IconButton(
                            icon: Icon(
                                ob3 ? Icons.visibility_off : Icons.visibility,
                                color: kPrimary),
                            onPressed: () => setSt(() => ob3 = !ob3),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              "Batal",
                              style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ?? false)) return;

                              final db = await DBService.database;
                              final rows = await db.query('users',
                                  where: 'id = ?', whereArgs: [_userId], limit: 1);
                              if (rows.isEmpty ||
                                  rows.first['password'] !=
                                      DBService.encrypt(oldCtrl.text)) {
                                _snack('Password lama salah', Colors.red);
                                return;
                              }

                              await db.update(
                                  'users',
                                  {'password': DBService.encrypt(newCtrl.text)},
                                  where: 'id = ?', whereArgs: [_userId]);

                              if (!mounted) return;
                              Navigator.pop(ctx);

                              // Popup sukses
                              showDialog(
                                context: rootContext, // ✅ gunakan context utama
                                barrierDismissible: false,
                                builder: (_) {
                                  final width = MediaQuery.of(rootContext).size.width;
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFFF8F4FF),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24)),
                                    insetPadding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 120),
                                    contentPadding: const EdgeInsets.all(24),
                                    content: SizedBox(
                                      width: width * 0.85,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.green, size: 60),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "Password Berhasil Diubah!",
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: kDarkText,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            "Harap login kembali untuk keamanan akun Anda.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: kDarkText, height: 1.5),
                                          ),
                                          const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(14)),
                                              ),
                                              icon: const Icon(Icons.logout,
                                                  color: Colors.white),
                                              label: const Text(
                                                "Logout Sekarang",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              onPressed: () async {
                                                final sp = await SharedPreferences.getInstance();
                                                await sp.clear();

                                                // Tutup dialog dulu
                                                Navigator.of(rootContext, rootNavigator: true).pop();
                                                // Jalankan logout pakai rootContext
                                                Future.delayed(const Duration(milliseconds: 100), () {
                                                  if (mounted) {
                                                    Navigator.pushAndRemoveUntil(
                                                      rootContext,
                                                      MaterialPageRoute(builder: (_) => const LoginPage()),
                                                      (_) => false,
                                                    );
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            child: const Text(
                              "Simpan",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
      );
    },
  );
}


  // ==================== Foto Profil ====================
  Future<void> _pickPhoto() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('photoPath', picked.path);
    setState(() => _photoPath = picked.path);
    ProfileUpdateBus.instance.notify();
    _snack("Foto berhasil diganti!", Colors.green);
  }

  Future<void> _removePhoto() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('photoPath');
    setState(() => _photoPath = null);
    ProfileUpdateBus.instance.notify();
    _snack("Foto berhasil dihapus!", Colors.red);
  }

  // ==================== Logout ====================
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:
            const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Yakin ingin keluar dari akun ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      final sp = await SharedPreferences.getInstance();
      await sp.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    const bgGradient = LinearGradient(
      colors: [Color(0xFFF6EDFF), Color(0xFFEADAFD), Color(0xFFD9C2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      _buildBody(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            const SizedBox(height: 20),
            const Text("My Profile",
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: kDarkText)),
            const SizedBox(height: 14),
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      _photoPath != null ? FileImage(File(_photoPath!)) : null,
                  child: _photoPath == null
                      ? const Icon(Icons.person, size: 60, color: kPrimary)
                      : null,
                ),
                Positioned(
                  bottom: -8,
                  child: Row(
                    children: [
                      _circleBtn(Icons.edit, _pickPhoto),
                      const SizedBox(width: 8),
                      if (_photoPath != null)
                        _circleBtn(Icons.delete, _removePhoto,
                            color: Colors.redAccent),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
        Positioned(
          bottom: -20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined, color: kPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_username,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: kDarkText)),
                      Text("NIM: $_nim",
                          style: const TextStyle(
                              fontSize: 13, color: kLightText)),
                    ],
                  ),
                ),
                IconButton(
                    onPressed: _editUsername,
                    icon: const Icon(Icons.edit_outlined, color: kPrimary))
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF5EEFF),
            Color(0xFFE8DBFF),
            Color(0xFFDCC6FF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 18, offset: Offset(0, -2))
        ],
      ),
      child: Column(
        children: [
          _socialMediaSection(),
          const Divider(height: 40),
          _gallerySection(),
          const Divider(height: 40),
          _menuSection(),
          const SizedBox(height: 30),
          _logoutButton(),
        ],
      ),
    );
  }

  // ==================== SOSIAL MEDIA ====================
  Widget _socialMediaSection() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      "Sosial Media",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: kDarkText,
      ),
    ),
    const SizedBox(height: 16),

    Row(
      children: [
        Expanded(
          child: _socialIcon(
            'assets/images/instagram.png',
            'Instagram',
            'https://instagram.com/aurasherylia',
            showRightBorder: true, // garis di kanan
          ),
        ),
        Expanded(
          child: _socialIcon(
            'assets/images/whatsapp.png',
            'WhatsApp',
            'https://wa.me/6288216526097',
            showRightBorder: true,
          ),
        ),
        Expanded(
          child: _socialIcon(
            'assets/images/tiktok.png',
            'TikTok',
            'https://tiktok.com/@aurasherylia',
            showRightBorder: false, 
          ),
        ),
      ],
    ),
  ],
);

  Widget _socialIcon(String asset, String label, String url, {bool showRightBorder = false}) {
  return InkWell(
    onTap: () async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Gagal membuka tautan.', Colors.red);
      }
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      decoration: BoxDecoration(
        border: Border(
          right: showRightBorder
              ? const BorderSide(
                  color: Color(0xFFBFA9E9), 
                  width: 1.0,
                )
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Image.asset(asset, height: 40),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: kDarkText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

  // ==================== GALLERY ====================
  Widget _gallerySection() {
    final imgs = [
      'assets/images/aura1.jpg',
      'assets/images/aura2.jpg',
      'assets/images/aura3.jpg'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Gallery",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: imgs.length,
              itemBuilder: (_, i) => Image.asset(imgs[i], fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            imgs.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 8,
              width: _currentPage == i ? 22 : 8,
              decoration: BoxDecoration(
                color: _currentPage == i
                    ? kPrimary
                    : kPrimary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== MENU ====================
  Widget _menuSection() => Column(
        children: [
          _menuTile("Change Password", Icons.lock, _changePassword),
          const SizedBox(height: 16),
          const _IntegratedFeedbackCard(
              kesan: "MasyaAllah, tugasnya sangat menantang dan banyak, bikin ga tidur seminggu.",
              pesan:
                  "Semoga dalam penyampaian materi lebih jelas dan mohon berikan saya nilai A ya, pak!"),
          const SizedBox(height: 16),
          const _IntegratedFaqSection(),
        ],
      );

  Widget _menuTile(String title, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon, color: kPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Icon(Icons.chevron_right, color: kPrimary)
            ],
          ),
        ),
      );

  // ==================== LOGOUT BUTTON ====================
  Widget _logoutButton() => GestureDetector(
        onTap: _logout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          width: double.infinity,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [ Color.fromARGB(255, 65, 44, 110),  Color.fromARGB(255, 65, 44, 110)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: const Color.fromARGB(255, 43, 12, 81).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ]),
          child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Logout',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))
              ]),
        ),
      );

  // ==================== UTILITIES ====================
  void _snack(String msg, Color color) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  Widget _circleBtn(IconData i, VoidCallback f, {Color color = kPrimary}) =>
      InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3))
              ]),
          child: Icon(i, color: Colors.white, size: 18),
        ),
      );
}

/// ==================== KESAN & PESAN ====================
class _IntegratedFeedbackCard extends StatelessWidget {
  final String kesan;
  final String pesan;
  const _IntegratedFeedbackCard({required this.kesan, required this.pesan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 245, 232, 241),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color.fromARGB(255, 235, 206, 231)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.school_outlined, color: Color.fromARGB(255, 102, 17, 71)),
            SizedBox(width: 8),
            Text('Kesan & Pesan Mata Kuliah PAM',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 95, 14, 72))),
          ]),
          const SizedBox(height: 16),
          _highlightText("Kesan", kesan),
          const SizedBox(height: 12),
          _highlightText("Pesan", pesan),
        ],
      ),
    );
  }

  static Widget _highlightText(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color.fromARGB(255, 121, 21, 56))),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color.fromARGB(255, 237, 212, 223),
              borderRadius: BorderRadius.circular(10)),
          child: Text(content,
              style: const TextStyle(color: Colors.black87, height: 1.45)),
        ),
      ],
    );
  }
}

/// ==================== FAQ  ====================
class _IntegratedFaqSection extends StatefulWidget {
  final List<(String, String)> items = const [
    ('Apa itu AorMed+?',
        'Aplikasi konsultasi dokter untuk booking dan chat dengan cepat.'),
    ('Bagaimana cara booking dokter?',
        'Pilih dokter → pilih jadwal → konfirmasi. Riwayat disimpan otomatis.'),
    ('Apakah data saya aman?',
        'Ya, data Anda hanya disimpan di perangkat lokal secara terenkripsi.'),
  ];
  const _IntegratedFaqSection();

  @override
  State<_IntegratedFaqSection> createState() => _IntegratedFaqSectionState();
}

class _IntegratedFaqSectionState extends State<_IntegratedFaqSection> {
  int? _openIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(
            'FAQs',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: kDarkText),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrimary.withOpacity(0.1)),
          ),
          child: Column(
            children: List.generate(widget.items.length, (i) {
              final item = widget.items[i];
              final opened = _openIndex == i;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: opened ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: opened
                      ? [
                          BoxShadow(
                              color: kPrimary.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]
                      : null,
                ),
                child: Theme(
                  data:
                      Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: Row(
                      children: [
                        const Icon(Icons.help_outline, color: kPrimary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.$1,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, color: kDarkText),
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(opened ? Icons.remove : Icons.add,
                        color: kPrimary),
                    onExpansionChanged: (v) =>
                        setState(() => _openIndex = v ? i : null),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.$2,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: kDarkText.withOpacity(0.85), height: 1.4),
                        ),
                      )
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

         
