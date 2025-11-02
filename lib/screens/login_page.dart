import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../theme.dart';
import '../services/db_service.dart';
import 'home_page.dart';
import 'register_page.dart';
import 'face_verify_live_page.dart'; // ✅ real-time verification

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

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ========================= LOGIN LOGIC =========================
  Future<void> _loginUser(BuildContext ctx) async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Harap isi semua field')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Cek kredensial user dari database
      final user = await DBService.login(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      if (user == null) {
        setState(() => _loading = false);
        _showErrorDialog(ctx, "Email atau password salah!");
        return;
      }

      // 2️⃣ (Opsional) Face ID / Touch ID
      final auth = LocalAuthentication();
      bool canCheck = await auth.canCheckBiometrics;
      bool didAuth = false;
      if (canCheck) {
        didAuth = await auth.authenticate(
          localizedReason: 'Gunakan Face ID atau Touch ID untuk login',
          options: const AuthenticationOptions(biometricOnly: true),
        );
      }

      if (!didAuth && canCheck) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Verifikasi biometrik gagal')),
        );
        return;
      }

      // 3️⃣ Verifikasi wajah secara real-time dari kamera
      final verified = await Navigator.push<bool>(
        ctx,
        MaterialPageRoute(
          builder: (_) => FaceVerifyLivePage(email: user['email']),
        ),
      );

      if (verified != true) {
        setState(() => _loading = false);
        _showErrorDialog(ctx, 'Verifikasi wajah gagal. Coba lagi.');
        return;
      }

      // 4️⃣ Simpan sesi pengguna
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', user['email']);
      await prefs.setString('username', user['username']);
      await prefs.setInt('user_id', user['id']);

      setState(() => _loading = false);
      _showSuccessDialog(ctx);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  // ========================= UI =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDFBFF), Color(0xFFF6EDFF), Color(0xFFEDE1FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 130),
                  const SizedBox(height: 16),
                  const Text(
                    'LOGIN',
                    style: TextStyle(
                      color: kDarkText,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selamat datang kembali! Silakan login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF866BBE),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildForm(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email, color: kPrimary),
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : () => _loginUser(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Login',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Belum punya akun? ',
                style: TextStyle(
                    color: Color(0xFF7E6BAA),
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
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
    );
  }

  // ========================= DIALOG SUKSES =========================
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

  // ========================= DIALOG ERROR =========================
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
