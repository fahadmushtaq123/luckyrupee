import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../home/home_screen.dart';
import 'auth_screens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    if (!mounted) return;
    if (token != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5C842), Color(0xFFFF9D00)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: Text('🎯', style: TextStyle(fontSize: 48)),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            const Text('LuckyRupee',
              style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900,
                color: Color(0xFFF5C842), letterSpacing: 1,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 8),
            const Text('Pakistan\'s #1 Skill Prize App',
              style: TextStyle(color: Color(0xFF6B7FA3), fontSize: 14),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Color(0xFFF5C842), strokeWidth: 2,
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
