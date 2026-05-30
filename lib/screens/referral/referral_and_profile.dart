// ============================================================
// lib/screens/referral/referral_screen.dart
// Referral program — stats, share link, leaderboard
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/all_providers.dart';
import '../../services/api_service.dart';
import '../../models/result_models.dart';
import '../../widgets/shared_widgets.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_referralStatsProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('Refer & Earn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        elevation: 0,
      ),
      body: statsAsync.when(
        data:    (s) => _buildBody(context, s),
        loading: () => const Center(child: CircularProgressIndicator(color: kGold)),
        error:   (e, _) => EmptyState(emoji: '⚠️', title: 'Error', subtitle: e.toString()),
      ),
    );
  }

  Widget _buildBody(BuildContext ctx, ReferralStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2D4A), Color(0xFF0D1929)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGold.withOpacity(0.2)),
            ),
            child: Column(children: [
              const Text('👥', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('Earn PKR 2 per referral',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('When your friend deposits PKR 10+',
                style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 20),

              // Referral code box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Your code', style: TextStyle(color: kMuted, fontSize: 11)),
                      Text(stats.referralCode,
                        style: const TextStyle(
                          color: kGold, fontSize: 22, fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        )),
                    ]),
                    Row(children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: stats.referralCode));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Code copied!'), backgroundColor: kGreen),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.copy, color: kGold, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Share.share(
                          '🎯 Win amazing prizes on LuckyRupee!\n\nUse my code ${stats.referralCode} at signup and we both get bonus credits!\n\nDownload: https://luckyrupee.pk/app',
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [kGold, kGoldDim]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.share, color: kBg, size: 18),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            _StatCard(label: 'Total Referrals', value: '${stats.totalReferrals}', emoji: '👥'),
            const SizedBox(width: 10),
            _StatCard(label: 'Active Friends', value: '${stats.activeReferrals}', emoji: '✅'),
            const SizedBox(width: 10),
            _StatCard(label: 'Total Earned', value: 'PKR ${stats.totalEarned.toStringAsFixed(0)}', emoji: '💰'),
          ]).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 24),

          // How it works
          const SectionHeader(title: 'How it works'),
          _HowItWorksStep(step: 1, text: 'Share your referral code with friends'),
          _HowItWorksStep(step: 2, text: 'They sign up using your code'),
          _HowItWorksStep(step: 3, text: 'They deposit PKR 10 or more'),
          _HowItWorksStep(step: 4, text: 'You instantly earn PKR 2 in your wallet'),

          const SizedBox(height: 24),

          // Leaderboard
          if (stats.leaderboard.isNotEmpty) ...[
            const SectionHeader(title: '🏆 Top Referrers'),
            ...stats.leaderboard.asMap().entries.map((e) {
              final rank  = e.key + 1;
              final entry = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: rank <= 3 ? kGold.withOpacity(0.05) : kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: rank <= 3 ? kGold.withOpacity(0.2) : kBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(children: [
                  Text(rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                    style: TextStyle(fontSize: rank <= 3 ? 20 : 14, color: kMuted)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry['name'] ?? 'Anonymous',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(entry['city'] ?? '',
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                  ])),
                  Text('${entry['referral_count']} referrals',
                    style: const TextStyle(color: kGold, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ).animate(delay: Duration(milliseconds: (e.key) * 50)).fadeIn().slideX(begin: 0.1);
            }),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, emoji;
  const _StatCard({required this.label, required this.value, required this.emoji});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 0.5)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, fontSize: 10)),
      ]),
    ),
  );
}

class _HowItWorksStep extends StatelessWidget {
  final int step;
  final String text;
  const _HowItWorksStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: kGold.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: kGold.withOpacity(0.4)),
        ),
        child: Center(child: Text('$step',
          style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w800))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
    ]),
  );
}

final _referralStatsProvider = FutureProvider<ReferralStats>((ref) async {
  return ref.read(authServiceProvider).getReferralStats();
});

// ============================================================
// lib/screens/profile/profile_screen.dart
// User profile — info, KYC status, settings, logout
// ============================================================

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2E4A7A), Color(0xFF1A2D4E)]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user?['name'] != null ? (user!['name'] as String)[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?['name'] ?? 'LuckyRupee User',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(user?['phone'] ?? '',
                    style: const TextStyle(color: kMuted, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: user?['isVerified'] == true
                        ? kGreen.withOpacity(0.1) : kGoldDim.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user?['isVerified'] == true ? '✅ Verified' : '⚠️ Unverified',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: user?['isVerified'] == true ? kGreen : kGoldDim,
                      ),
                    ),
                  ),
                ])),
              ]),
            ),

            const SizedBox(height: 20),
            const SectionHeader(title: 'Account'),

            _MenuItem(icon: '🪪', label: 'KYC Verification',
              subtitle: 'Required for withdrawals',
              onTap: () {}),
            _MenuItem(icon: '🔔', label: 'Notifications',
              subtitle: 'Draw reminders, wins, promotions',
              onTap: () {}),
            _MenuItem(icon: '🔒', label: 'Security',
              subtitle: 'Device management',
              onTap: () {}),

            const SizedBox(height: 16),
            const SectionHeader(title: 'Support'),

            _MenuItem(icon: '📋', label: 'Terms & Conditions', onTap: () {}),
            _MenuItem(icon: '🔐', label: 'Privacy Policy', onTap: () {}),
            _MenuItem(icon: '💬', label: 'WhatsApp Support',
              subtitle: '+92-XXX-XXXXXXX',
              onTap: () {}),
            _MenuItem(icon: 'ℹ️', label: 'About LuckyRupee',
              subtitle: 'Version 1.0.0',
              onTap: () {}),

            const SizedBox(height: 24),

            // Logout
            GestureDetector(
              onTap: () async {
                await ref.read(authServiceProvider).logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: kRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kRed.withOpacity(0.3)),
                ),
                child: const Center(
                  child: Text('Log Out',
                    style: TextStyle(color: kRed, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Center(
              child: Text('LuckyRupee (Pvt.) Ltd. · SECP Registered',
                style: TextStyle(color: kMuted, fontSize: 11)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final String? subtitle;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: kMuted, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right, color: kMuted, size: 18),
      ]),
    ),
  );
}
