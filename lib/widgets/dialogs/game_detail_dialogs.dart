import 'package:flutter/material.dart';
import '../game_detail_widgets.dart';

/// Return type for [HltbDialog]. Carries the three nullable hour fields.
class HltbDialogResult {
  final double? essential, extended, completionist;
  const HltbDialogResult(this.essential, this.extended, this.completionist);
}

// ── Playtime dialog ───────────────────────────────────────────────────────────

class PlaytimeDialog extends StatefulWidget {
  const PlaytimeDialog({
    super.key,
    required this.initialHours,
    required this.isSteamGame,
  });
  final double initialHours;
  final bool isSteamGame;

  @override
  State<PlaytimeDialog> createState() => _PlaytimeDialogState();
}

class _PlaytimeDialogState extends State<PlaytimeDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.initialHours.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = double.tryParse(_ctrl.text.trim());
    if (hours == null || hours < 0) {
      setState(() => _error = 'Enter a valid number (e.g. 12.5)');
      return;
    }
    Navigator.pop(context, hours);
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
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Hours played',
              suffixText: 'h',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          if (widget.isSteamGame) ...[
            const SizedBox(height: 8),
            Text(
              'Steam games will have this overwritten on next sync.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── HLTB hours dialog ─────────────────────────────────────────────────────────

class HltbDialog extends StatefulWidget {
  const HltbDialog({
    super.key,
    this.essential,
    this.extended,
    this.completionist,
  });
  final double? essential, extended, completionist;

  @override
  State<HltbDialog> createState() => _HltbDialogState();
}

class _HltbDialogState extends State<HltbDialog> {
  late final TextEditingController _ess, _ext, _cmp;

  @override
  void initState() {
    super.initState();
    _ess = TextEditingController(
        text: widget.essential?.toStringAsFixed(1) ?? '');
    _ext = TextEditingController(
        text: widget.extended?.toStringAsFixed(1) ?? '');
    _cmp = TextEditingController(
        text: widget.completionist?.toStringAsFixed(1) ?? '');
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
          Builder(builder: (context) => Text(
            'Leave a field blank to clear it.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )),
          const SizedBox(height: 12),
          HoursField(controller: _ess, label: 'Essential'),
          const SizedBox(height: 10),
          HoursField(controller: _ext, label: 'Extended'),
          const SizedBox(height: 10),
          HoursField(controller: _cmp, label: 'Completionist'),
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
            HltbDialogResult(
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

// ── Notes dialog ──────────────────────────────────────────────────────────────

/// Shows the notes editing dialog and returns the saved text, or null if cancelled.
Future<String?> showNotesDialog(BuildContext context, String? currentNotes) async {
  final ctrl = TextEditingController(text: currentNotes ?? '');
  final saved = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Notes'),
      content: TextField(
        controller: ctrl,
        maxLines: 5,
        minLines: 3,
        decoration: const InputDecoration(
          hintText: 'Add personal notes…',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return saved;
}
