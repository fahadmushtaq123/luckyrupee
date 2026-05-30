class UserModel {
  final int id;
  final String phone;
  final String? name, city;
  final double walletBalance;
  final String referralCode;
  final bool isVerified;

  const UserModel({required this.id, required this.phone, this.name, this.city,
    required this.walletBalance, required this.referralCode, required this.isVerified});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'], phone: j['phone'], name: j['name'], city: j['city'],
    walletBalance: (j['walletBalance'] as num).toDouble(),
    referralCode: j['referralCode'] ?? '', isVerified: j['isVerified'] ?? false);
}
