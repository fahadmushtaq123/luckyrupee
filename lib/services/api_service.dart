import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/draw_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/result_models.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.luckyrupee.pk',
  );

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: 'jwt_token');
        }
        return handler.next(error);
      },
    ));
  }

  // Auth
  Future<void> sendOtp(String phone) async {
    await _dio.post('/api/auth/send-otp', data: {'phone': phone});
  }

  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    String? referralCode,
    required String deviceId,
    required String deviceModel,
  }) async {
    final res = await _dio.post('/api/auth/verify-otp', data: {
      'phone': phone, 'otp': otp,
      'referralCode': referralCode,
      'deviceId': deviceId, 'deviceModel': deviceModel,
    });
    final result = AuthResult.fromJson(res.data);
    await _storage.write(key: 'jwt_token', value: result.token);
    return result;
  }

  Future<void> logout() async => await _storage.deleteAll();

  // Draws
  Future<List<DrawModel>> getDraws({int page = 1, String? category}) async {
    final res = await _dio.get('/api/draws', queryParameters: {
      'page': page,
      if (category != null) 'category': category,
    });
    return (res.data['draws'] as List).map((d) => DrawModel.fromJson(d)).toList();
  }

  Future<DrawModel> getDrawDetail(int drawId) async {
    final res = await _dio.get('/api/draws/$drawId');
    return DrawModel.fromJson(res.data);
  }

  Future<SkillQuestion> getSkillQuestion(int drawId) async {
    final res = await _dio.get('/api/draws/$drawId/question');
    return SkillQuestion.fromJson(res.data);
  }

  Future<EntryResult> enterDraw({
    required int drawId,
    required int entries,
    required String skillAnswer,
    required int questionId,
  }) async {
    final res = await _dio.post('/api/draws/$drawId/enter', data: {
      'entries': entries,
      'skillAnswer': skillAnswer,
      'questionId': questionId,
    });
    return EntryResult.fromJson(res.data);
  }

  // Wallet
  Future<double> getWalletBalance() async {
    final res = await _dio.get('/api/wallet/balance');
    return (res.data['balance'] as num).toDouble();
  }

  Future<List<Transaction>> getTransactions({int limit = 20, int page = 1}) async {
    final res = await _dio.get('/api/wallet/transactions',
      queryParameters: {'limit': limit, 'page': page});
    return (res.data['transactions'] as List)
        .map((t) => Transaction.fromJson(t)).toList();
  }

  Future<DepositResult> initiateDeposit({
    required double amount,
    required PaymentMethod method,
  }) async {
    final res = await _dio.post('/api/wallet/deposit',
      data: {'amount': amount, 'method': method.name});
    return DepositResult.fromJson(res.data);
  }

  Future<bool> requestWithdrawal({
    required double amount,
    required String method,
    required String accountNumber,
  }) async {
    final res = await _dio.post('/api/wallet/withdraw',
      data: {'amount': amount, 'method': method, 'accountNumber': accountNumber});
    return res.data['success'] == true;
  }

  // Referral
  Future<ReferralStats> getReferralStats() async {
    final res = await _dio.get('/api/referral/stats');
    return ReferralStats.fromJson(res.data);
  }
}
