import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../util/ui_tokens.dart';

/// A shimmer placeholder that matches the shape of the game list.
/// Shown instead of a spinner while the first DB stream emission is pending.
class GameListSkeleton extends StatelessWidget {
  const GameListSkeleton({super.key, this.itemCount = 8});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest,
      highlightColor: isDark ? cs.surfaceContainerHighest : cs.surfaceContainer,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, _) => const _GameCardSkeleton(),
      ),
    );
  }
}

class _GameCardSkeleton extends StatelessWidget {
  const _GameCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Artwork placeholder
          _block(width: kArtworkCardW, height: kArtworkCardH, radius: 6),
          const SizedBox(width: 12),
          // Text + progress bar placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _block(height: 13, width: double.infinity),
                const SizedBox(height: 7),
                _block(height: 10, width: 140),
                const SizedBox(height: 9),
                _block(height: 5, width: double.infinity, radius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _block({
    required double height,
    double? width,
    double radius = 4,
  }) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white, // shimmer gradient paints over this
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ─── Stats skeleton ───────────────────────────────────────────────────────────

/// Shimmer placeholder matching the Stats tab layout (grade card + grid + budget).
class StatsTabSkeleton extends StatelessWidget {
  const StatsTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobileOS = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final isWide = !isMobileOS;

    return Shimmer.fromColors(
      baseColor: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest,
      highlightColor: isDark ? cs.surfaceContainerHighest : cs.surfaceContainer,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grade banner
            _card(height: 80),
            const SizedBox(height: 8),
            // Stat card grid
            GridView.count(
              crossAxisCount: isWide ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: isWide ? 2.5 : 1.4,
              children: List.generate(10, (_) => _card()),
            ),
            const SizedBox(height: 12),
            // Daily budget card
            _card(height: 90),
            const SizedBox(height: 12),
            // Velocity chart card
            _card(height: 160),
          ],
        ),
      ),
    );
  }

  static Widget _card({double? height}) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

// ─── Play Next skeleton ────────────────────────────────────────────────────────

/// Shimmer placeholder for the Play Next tab (3 pick cards).
class PlayNextSkeleton extends StatelessWidget {
  const PlayNextSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest,
      highlightColor: isDark ? cs.surfaceContainerHighest : cs.surfaceContainer,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
