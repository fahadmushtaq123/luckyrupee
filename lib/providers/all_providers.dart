import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/mock_data.dart';
import '../models/draw_model.dart';
import '../models/transaction_model.dart';
import '../models/result_models.dart';
import 'wallet_provider.dart';

final authServiceProvider = Provider<ApiService>((ref) => ApiService());

final authStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  if (token == null) return null;
  return {'token': token};
});

class _MapNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => MockData.currentUser;
  void set(Map<String, dynamic>? val) => state = val;
}
final currentUserProvider = NotifierProvider<_MapNotifier, Map<String, dynamic>?>(
  _MapNotifier.new);

class _StringNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? val) => state = val;
}
final selectedCategoryProvider = NotifierProvider<_StringNotifier, String?>(
  _StringNotifier.new);

// Draws — tries API first, falls back to mock data
final drawsProvider = FutureProvider.family<List<DrawModel>, String?>((ref, category) async {
  try {
    return await ref.read(authServiceProvider).getDraws(category: category);
  } catch (_) {
    final all = MockData.draws;
    if (category == null) return all;
    return all.where((d) => d.category == category).toList();
  }
});

final drawDetailProvider = FutureProvider.family<DrawModel, int>((ref, drawId) async {
  try {
    return await ref.read(authServiceProvider).getDrawDetail(drawId);
  } catch (_) {
    return MockData.draws.firstWhere((d) => d.id == drawId,
      orElse: () => MockData.draws.first);
  }
});

// Wallet — real state (re-exported from wallet_provider.dart)
// walletNotifierProvider and transactionsNotifierProvider are in wallet_provider.dart
// Keep these for backward compatibility
final walletBalanceProvider = FutureProvider<double>((ref) async {
  return ref.watch(walletNotifierProvider);
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  return ref.watch(transactionsNotifierProvider);
});

// Referral stats — mock
final referralStatsProvider = FutureProvider<ReferralStats>((ref) async {
  try {
    return await ref.read(authServiceProvider).getReferralStats();
  } catch (_) {
    return MockData.referralStats;
  }
});
