import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../models/game.dart';
import '../util/date_format.dart';
import '../models/game_status.dart';
import '../models/play_style.dart';
import '../providers/game_actions_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/daily_budget_provider.dart';
import '../services/database/app_database.dart';
import '../services/steam_service.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../util/ui_tokens.dart';
import '../widgets/artwork_image.dart';
import '../widgets/dialogs/game_detail_dialogs.dart';
import '../widgets/game_detail_widgets.dart';

/// Full-screen detail view for a single game.
/// Watches [gameDetailProvider] so all edits are reflected immediately.
class GameDetailScreen extends ConsumerStatefulWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  late GameStatus _status;
  late PlayStyle _playStyle;
  bool _saving = false;

  Future<void> _withSaving(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _status = widget.game.status.toGameStatus;
    _playStyle = widget.game.playStyle.toPlayStyle;
  }

  double? _targetHours(Game game) => resolveTargetHours(game, _playStyle);

  Future<void> _setStatus(Game game, GameStatus next) async {
    if (next == _status) return;
    setState(() => _status = next);
    await _withSaving(() => ref.read(gameActionsProvider).setStatus(
          game,
          next,
          preserveCompletedAt:
              next == GameStatus.playing && game.completedAt != null,
        ));
  }

  Future<void> _setPlayStyle(PlayStyle style) async {
    if (style == _playStyle) return;
    setState(() => _playStyle = style);
    await _withSaving(
        () => ref.read(gameActionsProvider).setPlayStyle(widget.game, style));
  }

  Future<void> _showPlaytimeDialog(BuildContext context, Game game) async {
    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => PlaytimeDialog(
        initialHours: game.playtimeMinutes / 60.0,
        isSteamGame: game.appId > 0,
      ),
    );
    if (hours != null && mounted) {
      await _withSaving(
          () => ref.read(gameActionsProvider).setPlaytime(game, hours));
    }
  }

  Future<void> _showHltbDialog(BuildContext context, Game game) async {
    final result = await showDialog<HltbDialogResult>(
      context: context,
      builder: (ctx) => HltbDialog(
        essential: game.essentialHours,
        extended: game.extendedHours,
        completionist: game.completionistHours,
      ),
    );
    if (result != null && mounted) {
      await _withSaving(() => ref.read(gameActionsProvider).setHltbHours(
            game,
            essential: result.essential,
            extended: result.extended,
            completionist: result.completionist,
          ));
    }
  }

  static String _finishByLabel(double target, double hoursPlayed, double budgetPerDay) {
    final remaining = target - hoursPlayed;
    if (remaining <= 0) return '';
    final days = (remaining / budgetPerDay).ceil();
    final now = DateTime.now();
    final finish = now.add(Duration(days: days));
    final label = finish.year == now.year
        ? '${monthAbbr(finish.month)} ${finish.day}'
        : '${monthAbbr(finish.month)} ${finish.day}, ${finish.year}';
    return 'At your pace (~${budgetPerDay.toStringAsFixed(1)}h/day), done around $label';
  }

  Future<void> _showNotesDialog(BuildContext context, Game game) async {
    final saved = await showNotesDialog(context, game.notes);
    if (saved != null && mounted) {
      await _withSaving(
          () => ref.read(gameActionsProvider).setNotes(game, saved));
    }
  }

  Future<void> _syncPlaytimeFromSteam(Game game) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = await ref.read(authProvider.future);
      final steamId = auth.steamId;
      if (steamId == null || game.appId <= 0) return;

      final playtimeMinutes =
          await SteamService().getGamePlaytime(steamId, game.appId);

      if (playtimeMinutes != null && mounted) {
        await ref
            .read(gameActionsProvider)
            .setPlaytime(game, playtimeMinutes / 60.0);
        messenger.showSnackBar(
          const SnackBar(content: Text('Playtime synced from Steam')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Failed to sync playtime from Steam')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the live stream from the DB; fall back to the passed game while loading.
    final gameAsync = ref.watch(gameDetailProvider(widget.game.id));
    final game = gameAsync.asData?.value ?? widget.game;
    final dailyBudget = ref.watch(dailyBudgetProvider).asData?.value ?? 0.0;

    final hoursPlayed = game.playtimeMinutes / 60.0;
    final target = _targetHours(game);
    final progress =
        target != null ? (hoursPlayed / target).clamp(0.0, 1.0) : null;
    final hasHltb = game.essentialHours != null ||
        game.extendedHours != null ||
        game.completionistHours != null;
    final colors = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: _buildSlivers(
          context,
          game: game,
          hoursPlayed: hoursPlayed,
          target: target,
          progress: progress,
          hasHltb: hasHltb,
          colors: colors,
          scaffoldBg: scaffoldBg,
          dailyBudget: dailyBudget,
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context, {
    required Game game,
    required double hoursPlayed,
    required double? target,
    required double? progress,
    required bool hasHltb,
    required ColorScheme colors,
    required Color scaffoldBg,
    required double dailyBudget,
  }) {
    return [
      _buildArtworkHeader(game, scaffoldBg),
      _buildDetailContent(
        context,
        game: game,
        hoursPlayed: hoursPlayed,
        target: target,
        progress: progress,
        hasHltb: hasHltb,
        colors: colors,
        dailyBudget: dailyBudget,
      ),
    ];
  }

  Widget _buildArtworkHeader(Game game, Color scaffoldBg) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: AppConstants.kDetailHeaderHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'artwork_${game.id}',
              child: ArtworkImage(
                url: game.artworkUrl,
                alignment: Alignment.topCenter,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.25, 1.0],
                  colors: [Colors.transparent, scaffoldBg],
                ),
              ),
            ),
            Positioned(
              bottom: AppConstants.kArtworkTitlePadding,
              left: AppConstants.kArtworkTitlePadding,
              right: AppConstants.kArtworkTitlePadding,
              child: Text(
                game.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: kDetailTitleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black87),
                    Shadow(blurRadius: 16, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context, {
    required Game game,
    required double hoursPlayed,
    required double? target,
    required double? progress,
    required bool hasHltb,
    required ColorScheme colors,
    required double dailyBudget,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlaytimeSection(context, game, hoursPlayed, colors),
            _divider(colors),
            _buildTimeToBeatSection(context, game, hasHltb, colors),
            _divider(colors),
            _buildStatusSection(game, colors),
            if (hasHltb) ...[
              _divider(colors),
              _buildPlayStyleSection(game, colors),
              _divider(colors),
              _buildProgressSection(context, game, hoursPlayed, target, progress, colors, dailyBudget),
            ],
            _divider(colors),
            _buildRatingSection(context, game, colors),
            _divider(colors),
            _buildNotesSection(context, game),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaytimeSection(
      BuildContext context, Game game, double hoursPlayed, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel('Playtime'),
            const Spacer(),
            if (game.appId > 0)
              IconButton(
                icon: Icon(Icons.sync, size: 18, color: colors.primary),
                tooltip: 'Sync from Steam',
                onPressed: _saving ? null : () => _syncPlaytimeFromSteam(game),
              ),
            EditIconButton(
              tooltip: 'Edit Playtime',
              onPressed: _saving ? null : () => _showPlaytimeDialog(context, game),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hoursPlayed < 1
              ? '${game.playtimeMinutes} minutes played'
              : '${hoursPlayed.toStringAsFixed(1)} hours played',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            game.appId > 0 ? 'Synced from Steam' : 'Manually added',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeToBeatSection(
      BuildContext context, Game game, bool hasHltb, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'TIME TO BEAT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: colors.primary,
                      ),
                    ),
                    if (game.hltbName != null)
                      TextSpan(
                        text: ' (${game.hltbName} on HLTB)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (game.appId > 0)
              IconButton(
                icon: Icon(Icons.search, size: 18, color: colors.primary),
                tooltip: 'Update Time to Beat',
                onPressed: _saving
                    ? null
                    : () => context.push('/library/game/${game.id}/hltb', extra: game),
              ),
            EditIconButton(
              tooltip: 'Edit Time to Beat',
              onPressed: _saving ? null : () => _showHltbDialog(context, game),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hasHltb)
          Row(
            children: [
              if (game.essentialHours != null)
                Expanded(
                  child: HltbChip(
                    label: 'Essential',
                    hours: game.essentialHours!,
                    color: colors.primary,
                  ),
                ),
              if (game.extendedHours != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: HltbChip(
                    label: 'Extended',
                    hours: game.extendedHours!,
                    color: colors.secondary,
                  ),
                ),
              ],
              if (game.completionistHours != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: HltbChip(
                    label: 'Completionist',
                    hours: game.completionistHours!,
                    color: colors.tertiary,
                  ),
                ),
              ],
            ],
          )
        else
          Text(
            'No data — tap edit to add.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildStatusSection(Game game, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Status'),
        const SizedBox(height: 12),
        ToggleRow<GameStatus>(
          options: [
            ToggleOption(
                value: GameStatus.backlog,
                label: 'Backlog',
                icon: Icons.inbox_outlined),
            ToggleOption(
                value: GameStatus.playing,
                label: 'Playing',
                icon: Icons.play_circle_outline),
            ToggleOption(
                value: GameStatus.completed,
                label: 'Completed',
                icon: Icons.check_circle_outline),
          ],
          selected: _status,
          onChanged: _saving ? null : (s) => _setStatus(game, s),
        ),
      ],
    );
  }

  Widget _buildPlayStyleSection(Game game, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Play Style'),
        const SizedBox(height: 12),
        ToggleRow<PlayStyle>(
          options: [
            ToggleOption(
              value: PlayStyle.essential,
              label: 'Essential',
              enabled: game.essentialHours != null,
            ),
            ToggleOption(
              value: PlayStyle.extended,
              label: 'Extended',
              enabled: game.extendedHours != null,
            ),
            ToggleOption(
              value: PlayStyle.completionist,
              label: 'Completionist',
              enabled: game.completionistHours != null,
            ),
          ],
          selected: _playStyle,
          onChanged: _saving ? null : _setPlayStyle,
        ),
      ],
    );
  }

  Widget _buildProgressSection(
    BuildContext context,
    Game game,
    double hoursPlayed,
    double? target,
    double? progress,
    ColorScheme colors,
    double dailyBudget,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Progress'),
        const SizedBox(height: 12),
        if (progress != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colors.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(progressColor(progress, colors)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hoursPlayed < 1
                    ? '${game.playtimeMinutes}m played'
                    : '${hoursPlayed.toStringAsFixed(1)}h played',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%  ·  ${target!.toStringAsFixed(1)}h goal',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
          ),
          if (dailyBudget > 0 && progress < 1.0) ...[
            const SizedBox(height: 6),
            Builder(builder: (context) {
              final label = _finishByLabel(target, hoursPlayed, dailyBudget);
              if (label.isEmpty) return const SizedBox.shrink();
              return Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.primary,
                    fontStyle: FontStyle.italic),
              );
            }),
          ],
        ] else
          Text(
            'No estimate for the selected play style.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildRatingSection(
      BuildContext context, Game game, ColorScheme colors) {
    final tt = Theme.of(context).textTheme;
    final isMobile = context.isMobileOS;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_outline, size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text('Rating', style: tt.titleSmall)),
                Text(
                  game.rating != null ? '${game.rating}/10' : 'Not set',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: game.rating != null ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: (game.rating?.toDouble() ?? 0),
                min: 0,
                max: 10,
                divisions: 10,
                onChanged: _saving
                    ? null
                    : (val) => _withSaving(
                          () => ref.read(gameActionsProvider).setRating(
                                game,
                                val == 0 ? null : val.toInt(),
                              ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, Game game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel('Notes'),
            const Spacer(),
            EditIconButton(
              tooltip: 'Edit notes',
              onPressed: _saving ? null : () => _showNotesDialog(context, game),
            ),
          ],
        ),
        const SizedBox(height: 8),
        NotesSection(
          notes: game.notes,
          saving: _saving,
          onEdit: () => _showNotesDialog(context, game),
        ),
      ],
    );
  }

  static Widget _divider(ColorScheme colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(
          height: 1,
          thickness: 0.4,
          color: colors.outlineVariant.withValues(alpha: 0.7),
        ),
      );
}
