import 'package:flutter/material.dart';
import '../util/ui_tokens.dart';

// ── Rating row ────────────────────────────────────────────────────────────────

/// 10-button circular rating row. Calls [onRatingChanged] with the new value,
/// or null when the user taps the currently selected rating to deselect it.
class RatingRow extends StatelessWidget {
  const RatingRow({
    super.key,
    required this.rating,
    required this.saving,
    required this.onRatingChanged,
  });
  final int? rating;
  final bool saving;
  final void Function(int? newRating) onRatingChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(10, (i) {
        final val = i + 1;
        final isSelected = rating == val;
        // 44px vertical touch target; 26px visual circle centred inside.
        return Semantics(
          button: true,
          label: 'Rating $val${isSelected ? ', selected' : ''}',
          child: GestureDetector(
            onTap: saving ? null : () => onRatingChanged(isSelected ? null : val),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 9, 5, 9),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '$val',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Notes section ─────────────────────────────────────────────────────────────

/// Tappable notes area; shows italic placeholder when empty.
class NotesSection extends StatelessWidget {
  const NotesSection({
    super.key,
    required this.notes,
    required this.saving,
    required this.onEdit,
  });
  final String? notes;
  final bool saving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasNotes = notes?.isNotEmpty == true;
    return GestureDetector(
      onTap: saving ? null : onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          hasNotes ? notes! : 'Tap to add notes…',
          style: TextStyle(
            fontSize: 13,
            color: hasNotes ? cs.onSurface : cs.onSurfaceVariant,
            fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class ToggleOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  const ToggleOption({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

class ToggleRow<T> extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final List<ToggleOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        final isDisabled = onChanged == null;
        final canTap = opt.enabled && !isDisabled;
        final fgColor = isSelected
            ? colors.onPrimary
            : (opt.enabled && !isDisabled)
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.35);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: kAnimNormal,
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : (opt.enabled && !isDisabled)
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

class EditIconButton extends StatelessWidget {
  const EditIconButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Edit',
  });
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
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

class HoursField extends StatelessWidget {
  const HoursField({super.key, required this.controller, required this.label});
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
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

class HltbChip extends StatelessWidget {
  const HltbChip({
    super.key,
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
