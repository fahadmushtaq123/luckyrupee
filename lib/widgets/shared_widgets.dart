// ============================================================
// lib/widgets/shared_widgets.dart
// Reusable UI components for LuckyRupee
// ============================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/draw_model.dart';

// ── App colours ───────────────────────────────────────────
const kBg      = Color(0xFF0A0E1A);
const kSurface = Color(0xFF111827);
const kCard    = Color(0xFF1A2235);
const kBorder  = Color(0xFF2A3650);
const kGold    = Color(0xFFF5C842);
const kGoldDim = Color(0xFFFF9D00);
const kGreen   = Color(0xFF10B981);
const kRed     = Color(0xFFEF4444);
const kMuted   = Color(0xFF6B7FA3);

// ── Draw card ─────────────────────────────────────────────
class DrawCard extends StatelessWidget {
  final DrawModel draw;
  final VoidCallback onTap;
  const DrawCard({super.key, required this.draw, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = draw.fillPercent.clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: draw.isFeatured ? kGold.withOpacity(0.4) : kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prize image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: draw.prizeImageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 160,
                      color: kSurface,
                      child: const Center(child: CircularProgressIndicator(color: kGold, strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 160,
                      color: kSurface,
                      child: const Center(child: Text('🎁', style: TextStyle(fontSize: 48))),
                    ),
                  ),
                  if (draw.isFeatured)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kGold, kGoldDim]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('⭐ FEATURED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kBg)),
                      ),
                    ),
                  Positioned(
                    top: 10, right: 10,
                    child: _CountdownBadge(endTime: draw.endTime),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draw.prizeName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('PKR ${draw.prizeValue.toStringAsFixed(0)}',
                      style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('· ${draw.category.toUpperCase()}',
                      style: const TextStyle(color: kMuted, fontSize: 11)),
                  ]),
                  const SizedBox(height: 12),
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${draw.entriesSold} / ${draw.maxEntries} entries',
                            style: const TextStyle(color: kMuted, fontSize: 12)),
                          Text('${(pct * 100).toStringAsFixed(0)}% full',
                            style: TextStyle(
                              color: pct > 0.85 ? kRed : kMuted,
                              fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: kBorder,
                          valueColor: AlwaysStoppedAnimation(pct > 0.85 ? kRed : kGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bottom row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kGold.withOpacity(0.3)),
                        ),
                        child: Text('PKR ${draw.entryPrice.toStringAsFixed(0)} / entry',
                          style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      if (draw.userEntries > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('✓ ${draw.userEntries} entries',
                            style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Countdown badge ───────────────────────────────────────
class _CountdownBadge extends StatefulWidget {
  final DateTime endTime;
  const _CountdownBadge({required this.endTime});
  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _update();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(_update);
      return _remaining.inSeconds > 0;
    });
  }

  void _update() => _remaining = widget.endTime.difference(DateTime.now());

  String get _label {
    if (_remaining.inSeconds <= 0) return 'ENDED';
    if (_remaining.inHours >= 24) return '${_remaining.inDays}d left';
    if (_remaining.inHours >= 1)  return '${_remaining.inHours}h left';
    return '${_remaining.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _remaining.inHours < 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (urgent ? kRed : kBg).withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_label,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: urgent ? Colors.white : kMuted,
        )),
    );
  }
}

// ── Wallet balance tile ───────────────────────────────────
class WalletTile extends StatelessWidget {
  final double balance;
  final VoidCallback onDeposit;
  const WalletTile({super.key, required this.balance, required this.onDeposit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2D4A), Color(0xFF0F1A2E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Wallet Balance', style: TextStyle(color: kMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Text('PKR ${balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
        ),
        GestureDetector(
          onTap: onDeposit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kGold, kGoldDim]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('+ Add Money',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBg)),
          ),
        ),
      ]),
    );
  }
}

// ── Section header ─────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String emoji, title, subtitle;
  const EmptyState({super.key, required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kMuted, height: 1.4)),
        ]),
      ),
    );
  }
}

// ── Gold button ───────────────────────────────────────────
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const GoldButton({super.key, required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          disabledBackgroundColor: kGold.withOpacity(0.4),
          foregroundColor: kBg,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(kBg)))
          : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
