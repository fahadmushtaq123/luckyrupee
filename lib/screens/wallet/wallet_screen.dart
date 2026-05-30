// ============================================================
// lib/screens/wallet/wallet_screen.dart
// Wallet — balance, transactions, deposit, withdraw
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/transaction_model.dart';
import '../../models/draw_model.dart';  // for PaymentMethod
import '../../providers/all_providers.dart';
import '../../services/api_service.dart';
import '../../models/result_models.dart';
import '../../widgets/shared_widgets.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balAsync  = ref.watch(walletBalanceProvider);
    final txnAsync  = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: kGold,
        backgroundColor: kCard,
        onRefresh: () async {
          ref.invalidate(walletBalanceProvider);
          ref.invalidate(transactionsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Balance card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: balAsync.when(
                  data: (bal) => _BalanceCard(
                    balance: bal,
                    onDeposit: () => _showDepositSheet(context, ref),
                    onWithdraw: () => _showWithdrawSheet(context, ref, bal),
                  ).animate().fadeIn(),
                  loading: () => const _BalanceCardSkeleton(),
                  error: (_, __) => _BalanceCard(
                    balance: 0,
                    onDeposit: () => _showDepositSheet(context, ref),
                    onWithdraw: () {},
                  ),
                ),
              ),
            ),

            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(children: [
                  _QuickAction(emoji: '💳', label: 'JazzCash',
                    onTap: () => _showDepositSheet(context, ref, method: PaymentMethod.jazzcash)),
                  const SizedBox(width: 10),
                  _QuickAction(emoji: '📱', label: 'EasyPaisa',
                    onTap: () => _showDepositSheet(context, ref, method: PaymentMethod.easypaisa)),
                  const SizedBox(width: 10),
                  _QuickAction(emoji: '🏧', label: 'Bank',
                    onTap: () => _showDepositSheet(context, ref, method: PaymentMethod.bank)),
                ]),
              ),
            ),

            // Transactions header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SectionHeader(title: 'Transaction History'),
              ),
            ),

            // Transactions list
            txnAsync.when(
              data: (txns) {
                if (txns.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      emoji: '📋',
                      title: 'No transactions yet',
                      subtitle: 'Your deposits, entries, and winnings will appear here.',
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _TxnTile(txn: txns[i])
                        .animate(delay: Duration(milliseconds: i * 40))
                        .fadeIn().slideX(begin: 0.1),
                    childCount: txns.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: kGold)),
              ),
              error: (e, _) => SliverFillRemaining(
                child: EmptyState(emoji: '⚠️', title: 'Error loading', subtitle: e.toString()),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _showDepositSheet(BuildContext ctx, WidgetRef ref, {PaymentMethod? method}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DepositSheet(
        initialMethod: method,
        onSuccess: () => ref.invalidate(walletBalanceProvider),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext ctx, WidgetRef ref, double balance) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _WithdrawSheet(
        balance: balance,
        onSuccess: () => ref.invalidate(walletBalanceProvider),
      ),
    );
  }
}

// ── Balance card ──────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onDeposit, onWithdraw;
  const _BalanceCard({required this.balance, required this.onDeposit, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2D4A), Color(0xFF0D1929)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      child: Column(children: [
        const Text('Available Balance', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Text('PKR ${balance.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: onDeposit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGold, kGoldDim]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('+ Deposit',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kBg))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onWithdraw,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: const Center(
                  child: Text('Withdraw',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20)),
  );
}

// ── Quick action ──────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _QuickAction({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: kCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

// ── Transaction tile ──────────────────────────────────────
class _TxnTile extends StatelessWidget {
  final Transaction txn;
  const _TxnTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(txn.icon, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(txn.description,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(_formatDate(txn.createdAt),
              style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(txn.formattedAmount,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: txn.isCredit ? kGreen : Colors.white,
            )),
          if (txn.status == 'pending')
            const Text('Pending', style: TextStyle(color: kGoldDim, fontSize: 11)),
        ]),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Deposit bottom sheet ──────────────────────────────────
class _DepositSheet extends ConsumerStatefulWidget {
  final PaymentMethod? initialMethod;
  final VoidCallback onSuccess;
  const _DepositSheet({this.initialMethod, required this.onSuccess});
  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _amountCtrl = TextEditingController();
  late PaymentMethod _method;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod ?? PaymentMethod.jazzcash;
  }

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  Future<void> _deposit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount < 10) {
      setState(() => _error = 'Minimum deposit is PKR 10');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // In production: call API and open payment URL in WebView
      await Future.delayed(const Duration(seconds: 1)); // simulate
      if (!mounted) return;
      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Redirecting to ${_method.name}...'),
          backgroundColor: kGreen,
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add Money', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 20),

        const Text('Amount (PKR)', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '500',
            hintStyle: const TextStyle(color: kMuted),
            prefixText: 'PKR  ',
            prefixStyle: const TextStyle(color: kMuted, fontSize: 16),
            filled: true, fillColor: kSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGold),
            ),
          ),
        ),

        const SizedBox(height: 16),
        // Quick amounts
        Row(children: [100, 200, 500, 1000].map((amt) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _amountCtrl.text = amt.toString(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kSurface, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Text('$amt', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ),
        )).toList()),

        const SizedBox(height: 20),
        const Text('Payment Method', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: PaymentMethod.values.map((m) {
          final labels = {
            PaymentMethod.jazzcash:  ('💳', 'JazzCash'),
            PaymentMethod.easypaisa: ('📱', 'EasyPaisa'),
            PaymentMethod.bank:      ('🏧', 'Bank'),
          };
          final l = labels[m]!;
          final active = _method == m;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _method = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? kGold.withOpacity(0.1) : kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? kGold : kBorder, width: active ? 1.5 : 0.5),
                  ),
                  child: Column(children: [
                    Text(l.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(l.$2, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: active ? kGold : Colors.white60,
                    )),
                  ]),
                ),
              ),
            ),
          );
        }).toList()),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
          ),

        const SizedBox(height: 20),
        GoldButton(label: 'Proceed to Payment', loading: _loading, onTap: _deposit),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Withdraw bottom sheet ─────────────────────────────────
class _WithdrawSheet extends ConsumerStatefulWidget {
  final double balance;
  final VoidCallback onSuccess;
  const _WithdrawSheet({required this.balance, required this.onSuccess});
  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _amountCtrl  = TextEditingController();
  final _accountCtrl = TextEditingController();
  String _method = 'jazzcash';
  bool _loading  = false;
  String? _error;

  @override
  void dispose() { _amountCtrl.dispose(); _accountCtrl.dispose(); super.dispose(); }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount < 100)  { setState(() => _error = 'Minimum withdrawal is PKR 100'); return; }
    if (amount > widget.balance)          { setState(() => _error = 'Insufficient balance'); return; }
    if (_accountCtrl.text.trim().isEmpty) { setState(() => _error = 'Account number required'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      // TODO: pass apiService via constructor — see README
      await ref.read(authServiceProvider).requestWithdrawal(
        amount:        amount,
        method:        _method,
        accountNumber: _accountCtrl.text.trim(),
      );
      if (!mounted) return;
      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal submitted. Processing within 24 hours.'), backgroundColor: kGreen),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Withdraw', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 6),
        Text('Available: PKR ${widget.balance.toStringAsFixed(2)}',
          style: const TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 20),

        const Text('Amount (PKR)', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          decoration: _inputDeco('Enter amount', prefix: 'PKR  '),
        ),
        const SizedBox(height: 16),

        const Text('Account Number', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _accountCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: _inputDeco('03XXXXXXXXX'),
        ),
        const SizedBox(height: 16),

        const Text('Withdraw via', style: TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          for (final m in ['jazzcash', 'easypaisa', 'bank'])
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _method = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _method == m ? kGold.withOpacity(0.1) : kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _method == m ? kGold : kBorder, width: _method == m ? 1.5 : 0.5),
                  ),
                  child: Center(child: Text(m.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _method == m ? kGold : Colors.white60,
                    ))),
                ),
              ),
            )),
        ]),

        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13))),

        const SizedBox(height: 20),
        GoldButton(label: 'Submit Withdrawal', loading: _loading, onTap: _withdraw),
        const SizedBox(height: 8),
        const Center(
          child: Text('KYC verification required for withdrawals',
            style: TextStyle(color: kMuted, fontSize: 11)),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, {String? prefix}) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: kMuted),
    prefixText: prefix, prefixStyle: const TextStyle(color: kMuted, fontSize: 16),
    filled: true, fillColor: kSurface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGold)),
  );
}
