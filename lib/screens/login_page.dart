import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/db_service.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _showSelectUser = true;
  bool _manualLoginMode = false;

  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DBService.getRecentUsers(limit: 3);
    setState(() => _users = users);
  }

  Future<void> _selectUser(Map<String, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _email.text = user['email'];
      _password.clear();
      _manualLoginMode = false;
      _showSelectUser = false;
    });
  }

  Future<void> _loginUser(BuildContext ctx) async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('Harap isi semua field')));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await DBService.login(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      if (user == null) {
        setState(() => _loading = false);
        _showErrorDialog(ctx, "Email atau password salah!");
        return;
      }

      if (_manualLoginMode) {
        final auth = LocalAuthentication();
        final canCheck = await auth.canCheckBiometrics;
        if (!canCheck) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Perangkat tidak mendukung Face ID')),
          );
          return;
        }
        final didAuth = await auth.authenticate(
          localizedReason: 'Gunakan Face ID untuk login',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!didAuth) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Verifikasi Face ID dibatalkan/gagal'),
            ),
          );
          return;
        }
      }

      // Simpan sesi
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', user['email']);
      await prefs.setString('username', user['username']);
      await prefs.setInt('user_id', user['id']);

      setState(() => _loading = false);
      _showSuccessDialog(ctx);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    }
  }

  // LOGIN DENGAN FACE ID
  Future<void> _loginWithFaceID(BuildContext ctx) async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Pilih pengguna terlebih dahulu')),
      );
      return;
    }

    final auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;

    if (!canCheck) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Perangkat tidak mendukung Face ID')),
      );
      return;
    }

    final didAuth = await auth.authenticate(
      localizedReason: 'Gunakan Face ID untuk login',
      options: const AuthenticationOptions(biometricOnly: true),
    );

    if (didAuth) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', _selectedUser!['email']);
      await prefs.setString('username', _selectedUser!['username']);
      await prefs.setInt('user_id', _selectedUser!['id']);

      _showSuccessDialog(ctx);
    } else {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('Autentikasi gagal')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDFBFF), Color(0xFFF6EDFF), Color(0xFFEDE1FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _showSelectUser
              ? _buildSelectUser(context)
              : _buildLoginForm(context),
        ),
      ),
    );
  }

  Widget _buildSelectUser(BuildContext ctx) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', height: 120),
          const SizedBox(height: 46),
          const Text(
            'Masuk Sebagai',
            style: TextStyle(color: kPrimary, fontSize: 16),
          ),
          const SizedBox(height: 14),

          for (final u in _users) _UserTile(u, onTap: () => _selectUser(u)),

          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedUser = null;
                _email.clear();
                _password.clear();
                _manualLoginMode = true;
                _showSelectUser = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Log into another account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 130),
          OutlinedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: const BorderSide(color: kPrimary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Create new account',
              style: TextStyle(
                color: kPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext ctx) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo + Brand
            Image.asset('assets/images/logo.png', height: 120),
            const SizedBox(height: 8),
            const Text(
              'LOGIN',
              style: TextStyle(
                color: kDarkText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Selamat datang kembali! Silakan login.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF866BBE), fontSize: 15),
            ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    readOnly: _selectedUser != null && !_manualLoginMode,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email, color: kPrimary),
                      labelText: 'Email',

                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kPrimary.withOpacity(
                            0.8,
                          ),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kPrimary.withOpacity(
                            0.8,
                          ), 
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: kPrimary),
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: kPrimary,
                        ),
                      ),

                      filled: true,
                      fillColor: Colors.white.withOpacity(
                        0.15,
                      ), 

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kPrimary.withOpacity(
                            0.8,
                          ),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kPrimary.withOpacity(0.8),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  //Face ID
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _loginUser(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _loginWithFaceID(ctx),
                        child: 
                        Image.asset(
                          'assets/images/faceid.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Belum punya akun? ',
                  style: TextStyle(
                    backgroundColor: Color.fromARGB(255, 255, 255, 255),
                    color: Color(0xFF7E6BAA),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      ctx,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: const Text(
                    'Daftar Sekarang',
                    style: TextStyle(
                      color: Color(0xFF6A35CC),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext ctx) {
    _controller.forward(from: 0);
    showGeneralDialog(
      context: ctx,
      barrierLabel: "Login Success",
      barrierDismissible: false,
      barrierColor: Colors.black54.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return ScaleTransition(
          scale: _scaleAnim,
          child: Center(
            child: Container(
              width: MediaQuery.of(dialogCtx).size.width * 0.82,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8F4FF), Color(0xFFEFE5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/success.json', height: 180),
                  const SizedBox(height: 12),
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kDarkText,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login berhasil, selamat datang kembali!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF7E6BAA),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      Navigator.pushReplacement(
                        ctx,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(180, 50),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext ctx, String msg) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Login Gagal'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK', style: TextStyle(color: kPrimary)),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _UserTile(this.user, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: DBService.getUserPhoto(user['id']),
      builder: (ctx, snap) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: const Color(0xFF6A35CC), width: 1.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: (snap.hasData && snap.data != null)
                      ? MemoryImage(snap.data!)
                      : null,
                  backgroundColor: const Color(0xFFEDE1FF),
                  child: (snap.data == null)
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFF6A35CC),
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    user['username'] ?? '',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: kDarkText,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF6A35CC),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
