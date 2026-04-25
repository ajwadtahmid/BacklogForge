import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game.dart';
import '../models/game_status.dart';
import '../models/play_style.dart';
import '../providers/game_actions_provider.dart';
import '../services/database/app_database.dart';

/// Full-screen detail view for a single game.
/// Watches [gameDetailProvider] so all edits (playtime, HLTB hours, status,
/// play style) are reflected immediately without manual invalidation.
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

  @override
  void initState() {
    super.initState();
    _status = widget.game.status.toGameStatus;
    _playStyle = widget.game.playStyle.toPlayStyle;
  }

  double? _targetHours(Game game) => switch (_playStyle) {
        PlayStyle.extended => game.extendedHours ?? game.essentialHours,
        PlayStyle.completionist =>
          game.completionistHours ?? game.extendedHours ?? game.essentialHours,
        PlayStyle.essential => game.essentialHours,
      };

  Future<void> _setStatus(Game game, GameStatus next) async {
    if (next == _status || _saving) return;
    setState(() {
      _status = next;
      _saving = true;
    });
    try {
      await ref.read(gameActionsProvider).setStatus(
            game,
            next,
            preserveCompletedAt:
                next == GameStatus.playing && game.completedAt != null,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setPlayStyle(PlayStyle style) async {
    if (style == _playStyle || _saving) return;
    setState(() {
      _playStyle = style;
      _saving = true;
    });
    try {
      await ref
          .read(gameActionsProvider)
          .setPlayStyle(widget.game, style);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showPlaytimeDialog(BuildContext context, Game game) async {
    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => _PlaytimeDialog(
        initialHours: game.playtimeMinutes / 60.0,
        isSteamGame: game.appId > 0,
      ),
    );
    if (hours != null && mounted) {
      setState(() => _saving = true);
      try {
        await ref.read(gameActionsProvider).setPlaytime(game, hours);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _showHltbDialog(BuildContext context, Game game) async {
    final result = await showDialog<_HltbResult>(
      context: context,
      builder: (ctx) => _HltbDialog(
        essential: game.essentialHours,
        extended: game.extendedHours,
        completionist: game.completionistHours,
      ),
    );
    if (result != null && mounted) {
      setState(() => _saving = true);
      try {
        await ref.read(gameActionsProvider).setHltbHours(
              game,
              essential: result.essential,
              extended: result.extended,
              completionist: result.completionist,
            );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the live stream from the DB; fall back to the passed game while loading.
    final gameAsync = ref.watch(gameDetailProvider(widget.game.id));
    final game = gameAsync.asData?.value ?? widget.game;

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
              icon:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Artwork header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'artwork_${game.id}',
                    child: CachedNetworkImage(
                      imageUrl: game.artworkUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child:
                            const Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.45, 1.0],
                        colors: [Colors.transparent, scaffoldBg],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Text(
                      game.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 8, color: Colors.black54)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Detail content ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Playtime ───────────────────────────────────────
                  Row(
                    children: [
                      _SectionLabel('Playtime'),
                      const Spacer(),
                      _EditIconButton(
                        onPressed: _saving
                            ? null
                            : () => _showPlaytimeDialog(context, game),
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
                  if (game.appId > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Synced from Steam — overwritten on next sync',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),

                  // ── Time to Beat ───────────────────────────────────
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _SectionLabel('Time to Beat'),
                      const Spacer(),
                      _EditIconButton(
                        onPressed: _saving
                            ? null
                            : () => _showHltbDialog(context, game),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasHltb)
                    Row(
                      children: [
                        if (game.essentialHours != null)
                          Expanded(
                            child: _HltbChip(
                              label: 'Essential',
                              hours: game.essentialHours!,
                              color: colors.primary,
                            ),
                          ),
                        if (game.extendedHours != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HltbChip(
                              label: 'Extended',
                              hours: game.extendedHours!,
                              color: colors.secondary,
                            ),
                          ),
                        ],
                        if (game.completionistHours != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HltbChip(
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
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),

                  // ── Status ─────────────────────────────────────────
                  const SizedBox(height: 28),
                  _SectionLabel('Status'),
                  const SizedBox(height: 12),
                  _ToggleRow<GameStatus>(
                    options: [
                      _ToggleOption(
                          value: GameStatus.backlog,
                          label: 'Backlog',
                          icon: Icons.inbox_outlined),
                      _ToggleOption(
                          value: GameStatus.playing,
                          label: 'Playing',
                          icon: Icons.play_circle_outline),
                      _ToggleOption(
                          value: GameStatus.completed,
                          label: 'Completed',
                          icon: Icons.check_circle_outline),
                    ],
                    selected: _status,
                    onChanged: _saving ? null : (s) => _setStatus(game, s),
                  ),

                  // ── Play Style ─────────────────────────────────────
                  if (hasHltb) ...[
                    const SizedBox(height: 28),
                    _SectionLabel('Play Style'),
                    const SizedBox(height: 12),
                    _ToggleRow<PlayStyle>(
                      options: [
                        _ToggleOption(
                          value: PlayStyle.essential,
                          label: 'Essential',
                          enabled: game.essentialHours != null,
                        ),
                        _ToggleOption(
                          value: PlayStyle.extended,
                          label: 'Extended',
                          enabled: game.extendedHours != null,
                        ),
                        _ToggleOption(
                          value: PlayStyle.completionist,
                          label: 'Completionist',
                          enabled: game.completionistHours != null,
                        ),
                      ],
                      selected: _playStyle,
                      onChanged: _saving ? null : _setPlayStyle,
                    ),

                    // ── Progress ────────────────────────────────────
                    const SizedBox(height: 28),
                    _SectionLabel('Progress'),
                    const SizedBox(height: 12),
                    if (progress != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor:
                              colors.primary.withValues(alpha: 0.15),
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
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500]),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%  ·  ${target!.toStringAsFixed(1)}h goal',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'No estimate for the selected play style.',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _HltbResult {
  final double? essential, extended, completionist;
  const _HltbResult(this.essential, this.extended, this.completionist);
}

class _PlaytimeDialog extends StatefulWidget {
  const _PlaytimeDialog({required this.initialHours, required this.isSteamGame});
  final double initialHours;
  final bool isSteamGame;

  @override
  State<_PlaytimeDialog> createState() => _PlaytimeDialogState();
}

class _PlaytimeDialogState extends State<_PlaytimeDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialHours.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Playtime'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Hours played',
              suffixText: 'h',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.isSteamGame) ...[
            const SizedBox(height: 8),
            Text(
              'Steam games will have this overwritten on next sync.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final hours = double.tryParse(_ctrl.text.trim());
            if (hours != null && hours >= 0) Navigator.pop(context, hours);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HltbDialog extends StatefulWidget {
  const _HltbDialog({this.essential, this.extended, this.completionist});
  final double? essential, extended, completionist;

  @override
  State<_HltbDialog> createState() => _HltbDialogState();
}

class _HltbDialogState extends State<_HltbDialog> {
  late final TextEditingController _ess, _ext, _cmp;

  @override
  void initState() {
    super.initState();
    _ess = TextEditingController(text: widget.essential?.toStringAsFixed(1) ?? '');
    _ext = TextEditingController(text: widget.extended?.toStringAsFixed(1) ?? '');
    _cmp = TextEditingController(text: widget.completionist?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    _ess.dispose();
    _ext.dispose();
    _cmp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Time to Beat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Leave a field blank to clear it.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _HoursField(controller: _ess, label: 'Essential'),
          const SizedBox(height: 10),
          _HoursField(controller: _ext, label: 'Extended'),
          const SizedBox(height: 10),
          _HoursField(controller: _cmp, label: 'Completionist'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _HltbResult(
              double.tryParse(_ess.text.trim()),
              double.tryParse(_ext.text.trim()),
              double.tryParse(_cmp.text.trim()),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  const _ToggleOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

class _ToggleRow<T> extends StatelessWidget {
  const _ToggleRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final List<_ToggleOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        final canTap = opt.enabled && onChanged != null;
        final fgColor = isSelected
            ? colors.onPrimary
            : opt.enabled
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.35);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : opt.enabled
                          ? colors.outline.withValues(alpha: 0.45)
                          : colors.outline.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: canTap ? () => onChanged!(opt.value) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opt.icon != null) ...[
                          Icon(opt.icon, size: 20, color: fgColor),
                          const SizedBox(height: 5),
                        ],
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: fgColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _EditIconButton extends StatelessWidget {
  const _EditIconButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.edit_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _HoursField extends StatelessWidget {
  const _HoursField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'h',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _HltbChip extends StatelessWidget {
  const _HltbChip({
    required this.label,
    required this.hours,
    required this.color,
  });
  final String label;
  final double hours;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 2),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
