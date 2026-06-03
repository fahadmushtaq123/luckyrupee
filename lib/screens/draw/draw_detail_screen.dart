import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/draw_model.dart';
import '../../models/result_models.dart';
import '../../providers/all_providers.dart';
import '../../services/mock_data.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/shared_widgets.dart';
import 'dart:async';
import 'dart:math';

class DrawDetailScreen extends ConsumerStatefulWidget {
  final int drawId;
  const DrawDetailScreen({super.key, required this.drawId});
  @override
  ConsumerState<DrawDetailScreen> createState() => _DrawDetailScreenState();
}

class _DrawDetailScreenState extends ConsumerState<DrawDetailScreen> {
  int _entryCount   = 1;
  SkillQuestion?    _question;
  String?           _selectedAnswer;
  bool _loading     = false;
  bool _loadingQ    = false;
  String?           _errorMsg;
  bool _entered     = false;
  int   _userEntries = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestion();
  }

  void _fetchQuestion() {
    setState(() { _loadingQ = true; _selectedAnswer = null; });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final questions = MockData.skillQuestions;
      final q = questions[Random().nextInt(questions.length)];
      setState(() { _question = q; _loadingQ = false; });
    });
  }

  Future<void> _enterDraw(DrawModel draw) async {
    if (_question == null) { _fetchQuestion(); return; }
    if (_selectedAnswer == null) {
      setState(() => _errorMsg = 'Please answer the skill question first');
      return;
    }

    // Validate answer
    final correct = MockData.correctAnswers[_question!.id];
    if (_selectedAnswer != correct) {
      setState(() => _errorMsg = '❌ Wrong answer! Try again.');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() { _errorMsg = null; _selectedAnswer = null; });
        _fetchQuestion();
      });
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final cost = draw.entryPrice * _entryCount;
    final currentBalance = ref.read(walletNotifierProvider);

    if (currentBalance < cost) {
      setState(() {
        _loading  = false;
        _errorMsg = 'Insufficient balance! Add money to wallet first.';
      });
      return;
    }

    // Deduct from wallet
    ref.read(walletNotifierProvider.notifier).deduct(cost);

    // Add transaction
    ref.read(transactionsNotifierProvider.notifier).addTransaction(
      Transaction(
        id: DateTime.now().millisecondsSinceEpoch,
        type: TransactionType.entryFee,
        amount: -cost,
        description: '${_entryCount} ${_entryCount == 1 ? 'entry' : 'entries'} in ${draw.prizeName}',
        status: 'completed',
        createdAt: DateTime.now(),
      ),
    );

    setState(() {
      _loading     = false;
      _entered     = true;
      _userEntries += _entryCount;
    });

    _showSuccessSheet(draw, cost);
  }

  void _showSuccessSheet(DrawModel draw, double cost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎉', style: TextStyle(fontSize: 64))
              .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 12),
          const Text("You're in!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
              color: Colors.white)),
          const SizedBox(height: 8),
          Text('$_entryCount ${_entryCount == 1 ? 'entry' : 'entries'} confirmed',
            style: const TextStyle(color: kMuted, fontSize: 16)),
          const SizedBox(height: 4),
          Text('PKR ${cost.toStringAsFixed(0)} deducted',
            style: const TextStyle(color: kGold, fontSize: 14,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          GoldButton(label: 'Awesome! 🚀', onTap: () {
            Navigator.pop(context);
            _fetchQuestion();
          }),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawAsync = ref.watch(drawDetailProvider(widget.drawId));
    return Scaffold(
      backgroundColor: kBg,
      body: drawAsync.when(
        data:    (draw) => _buildBody(draw),
        loading: () => const Center(child: CircularProgressIndicator(color: kGold)),
        error:   (e, _) => EmptyState(emoji: '⚠️', title: 'Draw not found',
          subtitle: e.toString()),
      ),
    );
  }

  Widget _buildBody(DrawModel draw) {
    final pct      = draw.fillPercent.clamp(0.0, 1.0);
    final totalCost = draw.entryPrice * _entryCount;

    return CustomScrollView(slivers: [
      // Hero image
      SliverAppBar(
        backgroundColor: Colors.transparent,
        expandedHeight: 260,
        pinned: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kBg.withOpacity(0.85), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          ),
        ),
        flexibleSpace: FlexibleSpaceBar(
          background: CachedNetworkImage(
            imageUrl: draw.prizeImageUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: kSurface,
              child: const Center(child: Text('🎁',
                style: TextStyle(fontSize: 72)))),
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Prize info
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(draw.prizeName,
                    style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Worth PKR ${draw.prizeValue.toStringAsFixed(0)}',
                    style: const TextStyle(color: kGold, fontSize: 15,
                      fontWeight: FontWeight.w600)),
                ],
              )),
              _CountdownWidget(endTime: draw.endTime),
            ]),

            const SizedBox(height: 16),

            // Progress
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${draw.entriesSold} entries sold',
                style: const TextStyle(color: kMuted, fontSize: 13)),
              Text('${draw.spotsLeft} spots left',
                style: TextStyle(
                  color: draw.isAlmostFull ? kRed : kGreen,
                  fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 8,
                backgroundColor: kBorder,
                valueColor: AlwaysStoppedAnimation(
                  draw.isAlmostFull ? kRed : kGreen),
              ),
            ),

            if (draw.prizeDescription.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('About the Prize',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              const SizedBox(height: 8),
              Text(draw.prizeDescription,
                style: const TextStyle(color: kMuted, fontSize: 14,
                  height: 1.6)),
            ],

            const SizedBox(height: 24),

            // Skill question
            const Text('Answer to Enter',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Answer correctly to qualify your entry',
              style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 12),

            if (_loadingQ)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: kGold, strokeWidth: 2)))
            else if (_question != null)
              _SkillQuestionWidget(
                question: _question!,
                selected: _selectedAnswer,
                onSelect: (a) => setState(() {
                  _selectedAnswer = a;
                  _errorMsg = null;
                }),
              ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            // Entry count
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder)),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Number of entries',
                      style: TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600)),
                    Row(children: [
                      _CountBtn(icon: '-',
                        onTap: _entryCount > 1
                          ? () => setState(() => _entryCount--)
                          : null),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$_entryCount',
                          style: const TextStyle(color: kGold, fontSize: 20,
                            fontWeight: FontWeight.w800)),
                      ),
                      _CountBtn(icon: '+',
                        onTap: _entryCount < draw.maxPerUser
                          ? () => setState(() => _entryCount++)
                          : null),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total cost',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                    Text('PKR ${totalCost.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (_userEntries > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your entries',
                        style: TextStyle(color: kMuted, fontSize: 13)),
                      Text('$_userEntries',
                        style: const TextStyle(color: kGreen, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ]),
            ),

            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kRed.withOpacity(0.3))),
                  child: Text(_errorMsg!,
                    style: const TextStyle(color: kRed, fontSize: 13)),
                ),
              ),

            const SizedBox(height: 20),
            GoldButton(
              label: '${_entered ? 'Enter Again' : 'Enter Draw'} — PKR ${totalCost.toStringAsFixed(0)}',
              loading: _loading,
              onTap: () => _enterDraw(draw),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                '🔒 Cryptographically fair draw • Results published publicly',
                style: TextStyle(color: kMuted, fontSize: 11)),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    ]);
  }
}

// ── Skill question ────────────────────────────────────────
class _SkillQuestionWidget extends StatelessWidget {
  final SkillQuestion question;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _SkillQuestionWidget({required this.question, this.selected,
    required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final opts = [
      ('a', question.optionA), ('b', question.optionB),
      ('c', question.optionC), ('d', question.optionD),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6)),
          child: const Text('Skill Question',
            style: TextStyle(color: kGold, fontSize: 11,
              fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Text(question.question,
          style: const TextStyle(color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.w600, height: 1.4)),
        const SizedBox(height: 12),
        ...opts.map((opt) {
          final isSel = selected == opt.$1;
          return GestureDetector(
            onTap: () => onSelect(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSel ? kGold.withOpacity(0.15) : kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? kGold : kBorder,
                  width: isSel ? 1.5 : 0.5)),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSel ? kGold : kBorder.withOpacity(0.5)),
                  child: Center(child: Text(opt.$1.toUpperCase(),
                    style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSel ? kBg : kMuted))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(opt.$2,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSel ? Colors.white : Colors.white70,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.normal))),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Countdown ─────────────────────────────────────────────
class _CountdownWidget extends StatefulWidget {
  final DateTime endTime;
  const _CountdownWidget({required this.endTime});
  @override
  State<_CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<_CountdownWidget> {
  late Duration _r;
  Timer? _t;
  @override
  void initState() { super.initState(); _update(); _tick(); }
  void _update() => _r = widget.endTime.difference(DateTime.now());
  void _tick() => _t = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(_update);
  });
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_r.inSeconds <= 0) return const SizedBox.shrink();
    final h = _r.inHours;
    final m = _r.inMinutes % 60;
    final s = _r.inSeconds % 60;
    final urgent = _r.inHours < 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (urgent ? kRed : kSurface).withOpacity(urgent ? 0.15 : 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgent ? kRed.withOpacity(0.4) : kBorder)),
      child: Column(children: [
        Text('⏱ Ends in',
          style: TextStyle(color: kMuted, fontSize: 10)),
        Text(h > 0 ? '${h}h ${m}m'
          : '${m}m ${s.toString().padLeft(2, '0')}s',
          style: TextStyle(
            color: urgent ? kRed : kGold,
            fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── +/- Button ────────────────────────────────────────────
class _CountBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  const _CountBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: onTap != null ? kCard : kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onTap != null ? kGold.withOpacity(0.4) : kBorder)),
      child: Center(child: Text(icon,
        style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: onTap != null ? kGold : kMuted))),
    ),
  );
}
