import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _sendOtp() async {
    final phone = _ctrl.text.trim();
    if (!RegExp(r'^03[0-9]{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid number (03XXXXXXXXX)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushNamed(context, '/otp', arguments: phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text('🎯', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Enter your\nphone number',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                  color: Colors.white, height: 1.2)),
              const SizedBox(height: 8),
              const Text("We'll send you a verification code",
                style: TextStyle(color: Color(0xFF6B7FA3), fontSize: 15)),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2235),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A3650)),
                ),
                child: Row(children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('+92', style: TextStyle(color: Color(0xFFF5C842),
                      fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Container(width: 1, height: 24, color: const Color(0xFF2A3650)),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11)],
                      style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: '03XXXXXXXXX',
                        hintStyle: TextStyle(color: Color(0xFF3A4A6A)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      ),
                      onSubmitted: (_) => _sendOtp(),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C842),
                    foregroundColor: const Color(0xFF0A0E1A),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            Color(0xFF0A0E1A))))
                    : const Text('Send OTP',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const Spacer(),
              const Center(
                child: Text(
                  'By continuing you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF3A4A6A), fontSize: 12)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});
  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendSecs = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nodes[0].requestFocus());
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSecs = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSecs > 0) setState(() => _resendSecs--);
      else t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) c.dispose();
    for (final f in _nodes) f.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Future.delayed(const Duration(seconds: 1));
      const storage = FlutterSecureStorage();
      await storage.write(key: 'jwt_token', value: 'demo_${widget.phone}');
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2235),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3650)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white70, size: 16),
                ),
              ),
              const SizedBox(height: 32),
              const Text('🔐', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text('Verify Your Number',
                style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Code sent to +92 ${widget.phone.substring(1)}',
                style: TextStyle(color: Colors.white.withOpacity(0.5),
                  fontSize: 14)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _ctrls[i],
                  focusNode: _nodes[i],
                  hasError: _error != null,
                  onChanged: (val) {
                    if (val.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                    if (_otp.length == 6) _verify();
                  },
                  onBackspace: () {
                    if (_ctrls[i].text.isEmpty && i > 0)
                      _nodes[i - 1].requestFocus();
                  },
                )),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _resendSecs == 0 ? _startTimer : null,
                  child: Text(
                    _resendSecs > 0
                      ? 'Resend in 00:${_resendSecs.toString().padLeft(2, '0')}'
                      : 'Resend Code',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _resendSecs > 0
                        ? Colors.white.withOpacity(0.4)
                        : const Color(0xFFF5C842)),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C842),
                    foregroundColor: const Color(0xFF0A0E1A),
                    disabledBackgroundColor: const Color(0xFF2A3650),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            Color(0xFF0A0E1A))))
                    : const Text('Verify & Continue',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  const _OtpBox({required this.controller, required this.focusNode,
    required this.hasError, required this.onChanged, required this.onBackspace});
  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }
  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    return SizedBox(
      width: 44, height: 56,
      child: Container(
        decoration: BoxDecoration(
          color: widget.hasError
            ? const Color(0xFFEF4444).withOpacity(0.1)
            : filled ? const Color(0xFFF5C842).withOpacity(0.08)
            : const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 1.5,
            color: widget.hasError ? const Color(0xFFEF4444)
              : _focused ? const Color(0xFF3B82F6)
              : filled ? const Color(0xFFF5C842)
              : const Color(0xFF2A3650),
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: widget.hasError ? const Color(0xFFEF4444)
              : filled ? const Color(0xFFF5C842) : Colors.white,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) {
            setState(() {});
            widget.onChanged(val);
          },
        ),
      ),
    );
  }
}
