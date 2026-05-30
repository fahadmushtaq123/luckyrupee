import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JazzCashPaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String txnRef;
  final Map<String, dynamic> formData;
  const JazzCashPaymentScreen({
    super.key, required this.amount,
    required this.txnRef, required this.formData,
  });
  @override
  ConsumerState<JazzCashPaymentScreen> createState() => _JazzCashPaymentScreenState();
}

class _JazzCashPaymentScreenState extends ConsumerState<JazzCashPaymentScreen> {
  late WebViewController _webController;
  bool _loading = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          _checkPaymentResult(url);
        },
        onNavigationRequest: (req) {
          if (req.url.contains('luckyrupee.pk/payment/success') ||
              req.url.contains('pp_ResponseCode=000')) {
            _onPaymentSuccess();
            return NavigationDecision.prevent;
          }
          if (req.url.contains('luckyrupee.pk/payment/cancel') ||
              req.url.contains('pp_ResponseCode=124')) {
            _onPaymentCancelled();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

    // Build form-POST HTML to submit JazzCash payment
    final html = _buildPostForm();
    _webController.loadHtmlString(html);
  }

  String _buildPostForm() {
    final fields = widget.formData.entries
      .map((e) => '<input type="hidden" name="${e.key}" value="${e.value}">')
      .join('\n');

    return '''
<!DOCTYPE html>
<html>
<body onload="document.forms[0].submit()" style="background:#0A0E1A;">
  <form method="post" action="${widget.formData['url']}">
    $fields
  </form>
  <p style="color:white;text-align:center;font-family:sans-serif;margin-top:40px">
    Redirecting to JazzCash...
  </p>
</body>
</html>''';
  }

  void _checkPaymentResult(String url) {
    if (url.contains('pp_ResponseCode=000') && !_completed) {
      _onPaymentSuccess();
    }
  }

  void _onPaymentSuccess() {
    if (_completed) return;
    _completed = true;
    HapticFeedback.heavyImpact();
    Navigator.pop(context, {'success': true, 'amount': widget.amount});
  }

  void _onPaymentCancelled() {
    Navigator.pop(context, {'success': false, 'error': 'Payment cancelled'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Row(children: [
          const Text('🏦 ', style: TextStyle(fontSize: 18)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('JazzCash Payment',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('PKR ${widget.amount.toStringAsFixed(0)}',
              style: const TextStyle(color: Color(0xFFF5C842), fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: _onPaymentCancelled,
        ),
        bottom: _loading
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFF1A2235),
                valueColor: AlwaysStoppedAnimation(Color(0xFFF5C842)),
              ))
          : null,
      ),
      body: WebViewWidget(controller: _webController),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// lib/screens/payment/deposit_sheet.dart
// Bottom sheet for selecting deposit method + amount
// ─────────────────────────────────────────────────────────────

class DepositSheet extends ConsumerStatefulWidget {
  const DepositSheet({super.key});
  @override
  ConsumerState<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<DepositSheet> {
  final _amountCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.jazzcash;
  bool _loading = false;

  final _quickAmounts = [50, 100, 200, 500, 1000];

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  Future<void> _initiateDeposit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 10) {
      _showError('Minimum deposit is PKR 10');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).initiateDeposit(
        amount: amount, method: _method,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet

      if (_method == PaymentMethod.jazzcash && result.redirectUrl != null) {
        final payResult = await Navigator.push(context, MaterialPageRoute(
          builder: (_) => JazzCashPaymentScreen(
            amount: amount,
            txnRef: result.txnRef,
            formData: {...result.formData ?? {}, 'url': result.redirectUrl},
          ),
        ));

        if (payResult?['success'] == true) {
          _showSuccessSnack('💰 PKR ${amount.toStringAsFixed(0)} added to wallet!');
          ref.invalidate(walletBalanceProvider);
        }
      }
    } catch (e) {
      _showError('Deposit failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
    ));
  }

  void _showSuccessSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF22C55E),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3650),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 20),
          const Text('💳 Add Money to Wallet',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // Quick amounts
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _quickAmounts.map((amt) => GestureDetector(
              onTap: () => setState(() => _amountCtrl.text = amt.toString()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _amountCtrl.text == amt.toString()
                    ? const Color(0xFFF5C842).withOpacity(0.15)
                    : const Color(0xFF1A2235),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _amountCtrl.text == amt.toString()
                      ? const Color(0xFFF5C842)
                      : const Color(0xFF2A3650),
                  ),
                ),
                child: Text('PKR $amt',
                  style: TextStyle(
                    color: _amountCtrl.text == amt.toString()
                      ? const Color(0xFFF5C842) : Colors.white70,
                    fontSize: 13, fontWeight: FontWeight.w700,
                  )),
              ),
            )).toList(),
          ),

          const SizedBox(height: 16),

          // Custom amount
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'PKR  ',
              prefixStyle: const TextStyle(color: Color(0xFFF5C842), fontWeight: FontWeight.w700),
              hintText: 'Enter custom amount',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 15),
              filled: true, fillColor: const Color(0xFF1A2235),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2A3650)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFF5C842), width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // Payment methods
          const Text('Payment Method',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700,
              letterSpacing: 0.5, height: 1)),
          const SizedBox(height: 10),

          Row(children: [
            _MethodTile(
              label: 'JazzCash', icon: '🟢',
              selected: _method == PaymentMethod.jazzcash,
              onTap: () => setState(() => _method = PaymentMethod.jazzcash),
            ),
            const SizedBox(width: 10),
            _MethodTile(
              label: 'EasyPaisa', icon: '🔵',
              selected: _method == PaymentMethod.easypaisa,
              onTap: () => setState(() => _method = PaymentMethod.easypaisa),
            ),
            const SizedBox(width: 10),
            _MethodTile(
              label: 'Bank', icon: '🏧',
              selected: _method == PaymentMethod.bank,
              onTap: () => setState(() => _method = PaymentMethod.bank),
            ),
          ]),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _initiateDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5C842),
                foregroundColor: const Color(0xFF0A0E1A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF0A0E1A))))
                : Text(
                    'Deposit PKR ${_amountCtrl.text.isEmpty ? '—' : _amountCtrl.text} →',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String label, icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF5C842).withOpacity(0.1) : const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFF5C842) : const Color(0xFF2A3650),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label,
              style: TextStyle(
                color: selected ? const Color(0xFFF5C842) : Colors.white60,
                fontSize: 11, fontWeight: FontWeight.w700,
              )),
          ]),
        ),
      ),
    );
  }
}

