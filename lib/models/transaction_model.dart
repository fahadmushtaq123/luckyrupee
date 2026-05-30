enum TransactionType { deposit, withdrawal, entryFee, prizeWon, referralBonus, welcomeBonus }

class Transaction {
  final int id;
  final TransactionType type;
  final double amount;
  final String description, status;
  final DateTime createdAt;

  bool get isCredit => amount > 0;
  String get formattedAmount => '${isCredit ? '+' : ''}PKR ${amount.abs().toStringAsFixed(0)}';
  String get icon {
    switch (type) {
      case TransactionType.deposit: return '💰';
      case TransactionType.withdrawal: return '💸';
      case TransactionType.entryFee: return '🎯';
      case TransactionType.prizeWon: return '🏆';
      case TransactionType.referralBonus: return '👥';
      case TransactionType.welcomeBonus: return '🎁';
    }
  }

  const Transaction({required this.id, required this.type, required this.amount,
    required this.description, required this.status, required this.createdAt});

  factory Transaction.fromJson(Map<String, dynamic> j) {
    final typeMap = {
      'deposit': TransactionType.deposit, 'withdrawal': TransactionType.withdrawal,
      'entry_fee': TransactionType.entryFee, 'prize_won': TransactionType.prizeWon,
      'referral_bonus': TransactionType.referralBonus, 'welcome_bonus': TransactionType.welcomeBonus,
    };
    return Transaction(id: j['id'], type: typeMap[j['type']] ?? TransactionType.entryFee,
      amount: (j['amount'] as num).toDouble(), description: j['description'] ?? '',
      status: j['status'] ?? 'completed', createdAt: DateTime.parse(j['created_at']));
  }
}
