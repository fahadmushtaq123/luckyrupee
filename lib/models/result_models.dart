enum PaymentMethod { jazzcash, easypaisa, bank }

class AuthResult {
  final String token, refreshToken;
  final bool isNewUser;
  final Map<String, dynamic> user;
  AuthResult({required this.token, required this.refreshToken, required this.isNewUser, required this.user});
  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
    token: j['token'], refreshToken: j['refreshToken'] ?? '',
    isNewUser: j['isNewUser'] ?? false, user: j['user']);
}

class EntryResult {
  final bool success;
  final int entries;
  final double newBalance;
  EntryResult({required this.success, required this.entries, required this.newBalance});
  factory EntryResult.fromJson(Map<String, dynamic> j) => EntryResult(
    success: j['success'], entries: j['entries'],
    newBalance: (j['newBalance'] as num).toDouble());
}

class DepositResult {
  final String method, txnRef;
  final String? redirectUrl;
  final Map<String, dynamic>? formData;
  DepositResult({required this.method, this.redirectUrl, required this.txnRef, this.formData});
  factory DepositResult.fromJson(Map<String, dynamic> j) => DepositResult(
    method: j['method'], redirectUrl: j['redirectUrl'],
    txnRef: j['txnRef'], formData: j['formData']);
}

class ReferralStats {
  final int totalReferrals, activeReferrals;
  final double totalEarned;
  final String referralCode;
  final List<Map<String, dynamic>> leaderboard;
  ReferralStats({required this.totalReferrals, required this.activeReferrals,
    required this.totalEarned, required this.referralCode, required this.leaderboard});
  factory ReferralStats.fromJson(Map<String, dynamic> j) => ReferralStats(
    totalReferrals: int.parse(j['stats']['total_referrals'].toString()),
    activeReferrals: int.parse(j['stats']['active_referrals'].toString()),
    totalEarned: (j['stats']['total_earned'] as num).toDouble(),
    referralCode: j['referralCode'] ?? '',
    leaderboard: List<Map<String, dynamic>>.from(j['leaderboard']));
}
