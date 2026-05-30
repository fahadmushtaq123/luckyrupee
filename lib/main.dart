import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/auth_screens.dart';
import 'screens/home/home_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'screens/referral/referral_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LuckyRupeeApp()));
}

class DrawsScreen extends StatelessWidget {
  const DrawsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class LuckyRupeeApp extends StatelessWidget {
  const LuckyRupeeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LuckyRupee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFF5C842),
          surface: const Color(0xFF111827),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/phone': (_) => const PhoneEntryScreen(),
        '/otp': (ctx) {
          final phone = ModalRoute.of(ctx)!.settings.arguments as String;
          return OtpVerifyScreen(phone: phone);
        },
        '/home': (_) => const HomeScreen(),
        '/wallet': (_) => const WalletScreen(),
        '/referral': (_) => const ReferralScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
