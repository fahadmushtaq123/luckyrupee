import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────
// lib/providers/auth_provider.dart
// ─────────────────────────────────────────────────────────────

import '../models/user_model.dart';

// Current user state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  const AuthState({this.user, this.isLoading = false, this.error});
  bool get isAuthenticated => user != null;
  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) =>
    AuthState(user: user ?? this.user, isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return const AuthState();
    try {
      final user = await ApiService().getCurrentUser();
      return AuthState(user: user);
    } catch (_) {
      await prefs.remove('jwt_token');
      return const AuthState();
    }
  }

  Future<void> verifyOtp({
    required String phone, required String otp,
    String? referralCode, required String deviceId, required String deviceModel,
  }) async {
    state = const AsyncData(AuthState(isLoading: true));
    try {
      final result = await ApiService().verifyOtp(
        phone: phone, otp: otp,
        referralCode: referralCode,
        deviceId: deviceId, deviceModel: deviceModel,
      );
      state = AsyncData(AuthState(user: UserModel.fromJson(result.user)));
    } catch (e) {
      state = AsyncData(AuthState(error: e.toString()));
      rethrow;
    }
  }

  Future<void> logout() async {
    await ApiService().logout();
    state = const AsyncData(AuthState());
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
final authServiceProvider = Provider((ref) => ApiService());

// ─────────────────────────────────────────────────────────────
// lib/screens/payment/jazzcash_payment_screen.dart
// JazzCash WebView payment flow
// ─────────────────────────────────────────────────────────────
