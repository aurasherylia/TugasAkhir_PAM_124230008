import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'services/notification_simulator.dart';

const kPrimary = Color.fromARGB(255, 65, 44, 110);
const kBg = Color(0xFFF4EFFF);
const kDarkText = Color(0xFF3A2C63);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await NotificationSimulator.initialize();
  await NotificationSimulator.startRepeatingNotification();


  final oldDbPath = p.join(await getDatabasesPath(), 'aormed.db');
  if (await File(oldDbPath).exists()) {
    await deleteDatabase(oldDbPath);
    debugPrint('Deleted old read-only DB (migration fix)');
  }


  runApp(const AorMedApp());
}

// APP WRAPPER
class AorMedApp extends StatelessWidget {
  const AorMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'AorMed+',
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// SPLASH SCREEN 
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (_, __, ___) => const OnboardingScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDFBFF),
              Color(0xFFF6EDFF),
              Color(0xFFEDE1FF),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 130),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ONBOARDING SCREEN
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/dokter1.png",
      "title": "Konsultasi dengan dokter terpercaya",
      "desc": "Temui dokter profesional secara online tanpa perlu antre.",
    },
    {
      "image": "assets/images/dokter2.png",
      "title": "Temukan banyak dokter spesialis",
      "desc": "Semua dokter spesialis tersedia hanya dalam satu aplikasi.",
    },
    {
      "image": "assets/images/dokter3.png",
      "title": "Terhubung cepat dan aman",
      "desc": "Gunakan fitur konsultasi real-time untuk kesehatanmu.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDFBFF),
              Color(0xFFF6EDFF),
              Color(0xFFEDE1FF),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (value) {
                setState(() => _index = value);
              },
              itemCount: onboardingData.length,
              itemBuilder: (context, i) {
                final item = onboardingData[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 600),
                        scale: _index == i ? 1 : 0.9,
                        child: Image.asset(
                          item["image"]!,
                          height: 340,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 40),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: _index == i ? 1 : 0,
                        child: Column(
                          children: [
                            Text(
                              item["title"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kDarkText,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item["desc"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF7E6BAA),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            /// tombol skip
            Positioned(
              top: 60,
              right: 32,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const StartScreen()),
                  );
                },
                child: const Text(
                  "Skip",
                  style: TextStyle(
                    color: Color(0xFF7E6BAA),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(onboardingData.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _index == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _index == index
                          ? kPrimary
                          : kPrimary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              bottom: 50,
              right: 32,
              child: FloatingActionButton(
                backgroundColor: kPrimary,
                onPressed: () {
                  if (_index < onboardingData.length - 1) {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const StartScreen()),
                    );
                  }
                },
                child: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// START SCREEN
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFDFBFF),
              Color(0xFFF6EDFF),
              Color(0xFFEDE1FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 120),
                const SizedBox(height: 24),
                const Text(
                  "Let's Get Started!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kDarkText,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Silakan untuk menikmati fitur AorMed+ dan tetap sehat bersama kami!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7E6BAA),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPrimary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Register',
                    style: TextStyle(
                        color: kPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
