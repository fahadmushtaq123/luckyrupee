// ============================================================
// lib/screens/home/home_screen.dart
// Main home screen — draw feed + categories + wallet tile
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/all_providers.dart';
import '../../widgets/shared_widgets.dart';
import '../draw/draw_detail_screen.dart';
import '../wallet/wallet_screen.dart';
import '../referral/referral_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _tab,
        children: const [
          _DrawsFeed(),
          WalletScreen(),
          ReferralScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ── Bottom nav ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🎯', 'Draws'),
      ('💰', 'Wallet'),
      ('👥', 'Refer'),
      ('👤', 'Profile'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: items.asMap().entries.map((e) {
            final i = e.key;
            final label = e.value.$2;
            final icon  = e.value.$1;
            final active = i == current;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(icon, style: TextStyle(fontSize: active ? 22 : 20)),
                    const SizedBox(height: 2),
                    Text(label,
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: active ? kGold : kMuted,
                      )),
                    if (active)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 4, height: 4,
                        decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle),
                      ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Draws feed ─────────────────────────────────────────────
class _DrawsFeed extends ConsumerWidget {
  const _DrawsFeed();

  static const _categories = [
    (null,       'All',     '🎯'),
    ('bike',     'Bikes',   '🏍️'),
    ('phone',    'Phones',  '📱'),
    ('watch',    'Watches', '⌚'),
    ('gadget',   'Gadgets', '💻'),
    ('cash',     'Cash',    '💵'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCat = ref.watch(selectedCategoryProvider);
    final drawsAsync  = ref.watch(drawsProvider(selectedCat));

    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          backgroundColor: kBg,
          floating: true,
          pinned: false,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [kGold, kGoldDim],
            ).createShader(bounds),
            child: const Text('LuckyRupee',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          actions: [
            IconButton(
              icon: const Text('🔔', style: TextStyle(fontSize: 20)),
              onPressed: () {},
            ),
          ],
        ),

        // Wallet tile
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Consumer(builder: (_, ref, __) {
              final balAsync = ref.watch(walletBalanceProvider);
              return balAsync.when(
                data: (bal) => WalletTile(
                  balance: bal,
                  onDeposit: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WalletScreen())),
                ).animate().fadeIn(duration: 400.ms),
                loading: () => const SizedBox(height: 70),
                error: (_, __) => const SizedBox.shrink(),
              );
            }),
          ),
        ),

        // Category chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat    = _categories[i];
                final active = selectedCat == cat.$1;
                return GestureDetector(
                  onTap: () => ref.read(selectedCategoryProvider.notifier).set(cat.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:  active ? kGold.withOpacity(0.15) : kCard,
                      border: Border.all(color: active ? kGold : kBorder),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(cat.$3, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(cat.$2,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: active ? kGold : Colors.white70,
                        )),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Draws list
        drawsAsync.when(
          data: (draws) {
            if (draws.isEmpty) {
              return const SliverFillRemaining(
                child: EmptyState(
                  emoji: '🎁',
                  title: 'No draws right now',
                  subtitle: 'Check back soon — new draws are added daily!',
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => DrawCard(
                    draw: draws[i],
                    onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => DrawDetailScreen(drawId: draws[i].id))),
                  ).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideY(begin: 0.2),
                  childCount: draws.length,
                ),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kGold)),
          ),
          error: (err, _) => SliverFillRemaining(
            child: EmptyState(
              emoji: '⚠️',
              title: 'Could not load draws',
              subtitle: err.toString(),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}
