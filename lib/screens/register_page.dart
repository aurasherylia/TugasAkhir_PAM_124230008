import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme.dart';
import '../services/db_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // REGISTER FLOW
  Future<void> _registerUser(BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final email = _email.text.trim();
    final username = _username.text.trim();
    final password = _password.text.trim();

    try {
      final existing = await DBService.login(email: email, password: password);
      if (existing != null) {
        setState(() => _loading = false);
        _showErrorDialog(ctx, 'Email sudah terdaftar! Gunakan email lain.');
        return;
      }

      // langsung register tanpa face capture
      final msg = await DBService.register(
        username: username,
        email: email,
        password: password,
      );
      setState(() => _loading = false);

      if (msg != null) {
        _showErrorDialog(ctx, msg);
      } else {
        _showSuccessDialog(ctx);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErrorDialog(ctx, 'Terjadi kesalahan: $e');
    }
  }

  // UI
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', height: 130),
                    const SizedBox(height: 16),
                    const Text(
                      'REGISTER',
                      style: TextStyle(
                        color: kDarkText,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Buat akun baru Anda!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF866BBE), fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    _buildForm(context),
                  ],
                ),
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
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _username,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person, color: kPrimary),
              labelText: 'Username',

              filled: true,
              fillColor: Colors.transparent,

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kPrimary.withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kPrimary.withOpacity(0.8),
                  width: 2,
                ),
              ),
            ),

            validator: (v) =>
                (v == null || v.isEmpty) ? 'Masukkan username' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email, color: kPrimary),
              labelText: 'Email',

              filled: true,
              fillColor: Colors.transparent,

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kPrimary.withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kPrimary.withOpacity(0.8),
                  width: 2,
                ),
              ),
            ),

            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
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
              fillColor: Colors.transparent,

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: kPrimary.withOpacity(0.8),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kPrimary, width: 2),
              ),
            ),

            validator: (v) =>
                (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : () => _registerUser(ctx),
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
                    'Register',
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
                'Sudah punya akun? ',
                style: TextStyle(
                  color: Color(0xFF7E6BAA),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    ctx,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text(
                  'Login Sekarang',
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

  // DIALOG SUKSES
  void _showSuccessDialog(BuildContext ctx) {
    if (!mounted) return;
    _controller.reset();
    _controller.forward();

    showGeneralDialog(
      context: ctx,
      barrierLabel: "Register Success",
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C6BFF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset('assets/success.json', height: 180),
                  const SizedBox(height: 12),
                  const Text(
                    'Pendaftaran Berhasil!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kDarkText,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Akun Anda telah dibuat dan wajah berhasil disimpan.',
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
                        MaterialPageRoute(builder: (_) => const LoginPage()),
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
                      'Lanjut ke Login',
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

  // DIALOG ERROR
  void _showErrorDialog(BuildContext ctx, String msg) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Registrasi Gagal'),
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
