import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/mock_data.dart';

// ── Wallet balance — actually deducts ─────────────────────
class WalletNotifier extends Notifier<double> {
  @override
  double build() => 72.0; // starting balance

  void deduct(double amount) {
    if (state >= amount) state = state - amount;
  }

  void add(double amount) {
    state = state + amount;
  }
}

final walletNotifierProvider =
    NotifierProvider<WalletNotifier, double>(WalletNotifier.new);

// ── Transactions — adds new ones ──────────────────────────
class TransactionsNotifier extends Notifier<List<Transaction>> {
  @override
  List<Transaction> build() => List.from(MockData.transactions);

  void addTransaction(Transaction txn) {
    state = [txn, ...state];
  }
}

final transactionsNotifierProvider =
    NotifierProvider<TransactionsNotifier, List<Transaction>>(
        TransactionsNotifier.new);
