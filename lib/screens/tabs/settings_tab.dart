import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../util/platform.dart';
import '../../providers/theme_provider.dart';
import '../../services/export_import_service.dart';
import '../onboarding_screen.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>(
  (_) => PackageInfo.fromPlatform(),
);

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final syncState = ref.watch(syncStateProvider);
    final isGuest = authAsync.asData?.value.steamId == AuthNotifier.guestSteamId;
    final settingsAsync = ref.watch(settingsStreamProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _sectionHeader(context, 'ACCOUNT'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: authAsync.when(
            loading: () => const ListTile(title: Text('Loading…')),
            error: (e, _) => ListTile(title: Text('Error: $e')),
            data: (auth) {
              final isGuest = auth.steamId == AuthNotifier.guestSteamId;
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(isGuest ? 'Guest Mode' : 'Steam Account'),
                subtitle: Text(
                  isGuest
                      ? 'Sign in to sync your Steam library'
                      : 'ID: ${auth.steamId}',
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isGuest
                    ? FilledButton(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          builder: (_) => const SignInSheet(),
                        ),
                        child: const Text('Sign In'),
                      )
                    : TextButton(
                        onPressed: () =>
                            ref.read(authProvider.notifier).signOut(),
                        style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error),
                        child: const Text('Sign Out'),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(context, 'LIBRARY'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: syncState.status == SyncStatus.syncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        syncState.status == SyncStatus.error
                            ? Icons.error_outline
                            : Icons.sync,
                        color: syncState.status == SyncStatus.error
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                title: const Text('Re-sync Library'),
                subtitle: Text(
                  isGuest ? 'Sign in to sync your Steam library' : _syncSubtitle(syncState),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: isGuest || syncState.status == SyncStatus.syncing
                    ? null
                    : () => ref.read(syncStateProvider.notifier).sync(),
              ),
              const Divider(height: 1),
              // Completion threshold
              settingsAsync.when(
                loading: () => const ListTile(title: Text('Loading…')),
                error: (e, _) => ListTile(title: Text('Error: $e')),
                data: (settings) {
                  final threshold =
                      settings?.completionThreshold ?? 'essential';
                  return _SettingRow(
                    icon: Icons.flag_outlined,
                    title: 'Playstyle',
                    subtitle: 'Determines when a game counts as finished',
                    button: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: const [
                        ButtonSegment(value: 'essential', label: Text('Story')),
                        ButtonSegment(value: 'extended', label: Text('Extended')),
                        ButtonSegment(value: 'completionist', label: Text('100%')),
                      ],
                      selected: {threshold},
                      onSelectionChanged: (s) =>
                          ref.read(setCompletionThresholdProvider)(s.first),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(context, 'APPEARANCE'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              _SettingRow(
                icon: themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.brightness_auto,
                title: 'Theme',
                subtitle: themeMode == ThemeMode.dark
                    ? 'Dark'
                    : themeMode == ThemeMode.light
                        ? 'Light'
                        : 'System default',
                button: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) =>
                      ref.read(themeProvider.notifier).setTheme(s.first),
                ),
              ),
              if (!context.isMobileOS) ...[
                const Divider(height: 1),
                _SettingRow(
                  icon: Icons.navigation_outlined,
                  title: 'Navigation Position',
                  subtitle: 'Choose where navigation appears',
                  button: SegmentedButton<NavigationPosition>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(value: NavigationPosition.top, label: Text('Top')),
                      ButtonSegment(value: NavigationPosition.left, label: Text('Left')),
                      ButtonSegment(value: NavigationPosition.right, label: Text('Right')),
                    ],
                    selected: {ref.watch(navigationPositionProvider)},
                    onSelectionChanged: (s) =>
                        ref.read(navigationPositionProvider.notifier).setPosition(s.first),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(context, 'DATA'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export Library (JSON)'),
                subtitle: const Text('Save your library as a JSON backup'),
                onTap: () => _export(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export Library (CSV)'),
                subtitle: const Text('Export to spreadsheet format'),
                onTap: () => _exportCsv(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Import Library'),
                subtitle: const Text('Restore from a JSON backup'),
                onTap: () => _import(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Clear All Data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Permanently delete all games and settings'),
                onTap: () => _showClearDataConfirmation(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(context, 'ABOUT'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ref.watch(_packageInfoProvider).when(
            loading: () => const ListTile(title: Text('Loading…')),
            error: (_, _) => const ListTile(title: Text('BacklogForge')),
            data: (info) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('BacklogForge'),
              subtitle: Text('Version ${info.version}'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  String _syncSubtitle(SyncState syncState) {
    if (syncState.status == SyncStatus.syncing) {
      if (syncState.hltbTotal != null) {
        return 'Fetching HLTB data (${syncState.hltbCurrent}/${syncState.hltbTotal})…';
      }
      return 'Fetching library from Steam…';
    }
    if (syncState.status == SyncStatus.error) {
      return syncState.errorMessage ?? 'Sync failed';
    }
    return 'Sync your Steam library and HLTB data';
  }

  Widget _sectionHeader(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
        ),
      );

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider).asData?.value;
    final steamId = auth?.steamId;
    if (steamId == null) return;

    try {
      final db = ref.read(databaseProvider);
      final games = await db.gamesDao.getAllGames(steamId);
      final json = ExportImportService.buildExportJson(steamId, games);
      final filename = ExportImportService.buildFilename();

      final location = await getSaveLocation(
        suggestedName: filename,
        confirmButtonText: 'Save',
      );

      if (location == null) return; // user cancelled

      await ExportImportService.writeToPath(location.path, json);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${games.length} games')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider).asData?.value;
    final steamId = auth?.steamId;
    if (steamId == null) return;

    try {
      final db = ref.read(databaseProvider);
      final games = await db.gamesDao.getAllGames(steamId);
      final csv = ExportImportService.buildExportCsv(steamId, games);
      final filename = ExportImportService.buildCsvFilename();

      final location = await getSaveLocation(
        suggestedName: filename,
        confirmButtonText: 'Save',
      );

      if (location == null) return;

      await ExportImportService.writeToPath(location.path, csv);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${games.length} games as CSV')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV export failed: $e')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider).asData?.value;
    final steamId = auth?.steamId;
    if (steamId == null) return;

    try {
      const typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final rawContent = await file.readAsString();

      final backupSteamId = ExportImportService.readBackupSteamId(rawContent);
      final companions = ExportImportService.parseImportJson(rawContent);

      // Dry-run: diff against current library to show added/updated counts.
      final db = ref.read(databaseProvider);
      final existing = await db.gamesDao.getAllGames(steamId);
      final existingAppIds = {for (final g in existing) g.appId};
      int toAdd = 0, toUpdate = 0;
      for (final c in companions) {
        if (existingAppIds.contains(c.appId.value)) {
          toUpdate++;
        } else {
          toAdd++;
        }
      }

      final steamIdMismatch =
          backupSteamId != null && backupSteamId != steamId;

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import library?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (steamIdMismatch) ...[
                _PreviewRow(
                  icon: Icons.warning_amber_outlined,
                  label: 'This backup belongs to a different Steam account.',
                  color: Theme.of(ctx).colorScheme.error,
                ),
                const SizedBox(height: 10),
              ],
              _PreviewRow(icon: Icons.add_circle_outline,
                  label: '$toAdd new game${toAdd == 1 ? '' : 's'} will be added'),
              const SizedBox(height: 6),
              _PreviewRow(icon: Icons.update,
                  label: '$toUpdate existing game${toUpdate == 1 ? '' : 's'} will be updated'),
              const SizedBox(height: 12),
              Text('Total in file: ${companions.length}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final count = await db.gamesDao.importGames(steamId, companions);
      await db.gamesDao.recalculateAllStatuses(steamId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count games')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup file: ${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _showClearDataConfirmation(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authProvider).asData?.value;
    final steamId = auth?.steamId;
    if (steamId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all games, settings, and data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final db = ref.read(databaseProvider);
      final games = await db.gamesDao.getAllGames(steamId);

      // Delete all games for this user
      await db.transaction(() async {
        for (final game in games) {
          await (db.delete(db.games)..where((g) => g.id.equals(game.id))).go();
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear data: $e')),
        );
      }
    }
  }
}

/// A settings row that renders inline (icon + text + button) on desktop,
/// and stacked (icon + text above, full-width button below) on mobile.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.button,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobileOS;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: tt.bodyLarge?.copyWith(color: cs.onSurface)),
        Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: label),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: button),
              ],
            )
          : Row(
              children: [
                Icon(icon, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: label),
                const SizedBox(width: 12),
                button,
              ],
            ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color)),
        ),
      ],
    );
  }
}
