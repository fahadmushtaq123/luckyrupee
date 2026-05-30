import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/draw_model.dart';
import '../models/transaction_model.dart';
import '../models/result_models.dart';

final authServiceProvider = Provider<ApiService>((ref) => ApiService());

final authStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  if (token == null) return null;
  return {'token': token};
});

// Use NotifierProvider instead of StateProvider for riverpod 3.x compatibility
class _NullableMapNotifier extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void set(Map<String, dynamic>? val) => state = val;
}
final currentUserProvider = NotifierProvider<_NullableMapNotifier, Map<String, dynamic>?>(
  _NullableMapNotifier.new);

class _NullableStringNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? val) => state = val;
}
final selectedCategoryProvider = NotifierProvider<_NullableStringNotifier, String?>(
  _NullableStringNotifier.new);

final drawsProvider = FutureProvider.family<List<DrawModel>, String?>((ref, category) async {
  return ref.read(authServiceProvider).getDraws(category: category);
});

final drawDetailProvider = FutureProvider.family<DrawModel, int>((ref, drawId) async {
  return ref.read(authServiceProvider).getDrawDetail(drawId);
});

final walletBalanceProvider = FutureProvider<double>((ref) async {
  return ref.read(authServiceProvider).getWalletBalance();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  return ref.read(authServiceProvider).getTransactions();
});
