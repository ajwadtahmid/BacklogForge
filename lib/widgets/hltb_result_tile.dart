import 'package:flutter/material.dart';
import '../models/game_search_result.dart';
import 'artwork_image.dart';

/// A card tile displaying a single HLTB search result.
/// [trailing] is the action widget placed at the end of the row (e.g. add or apply button).
/// [showNoDataLabel] controls whether a "No HLTB data available" subtitle is
/// shown when all three hour fields are null (true for update flow; false for
/// add flow where the subtitle is simply omitted).
class HltbResultTile extends StatelessWidget {
  const HltbResultTile({
    super.key,
    required this.result,
    required this.trailing,
    this.showNoDataLabel = false,
  });

  final GameSearchResult result;
  final Widget trailing;
  final bool showNoDataLabel;

  @override
  Widget build(BuildContext context) {
    final hasTtb = result.essentialHours != null ||
        result.extendedHours != null ||
        result.completionistHours != null;

    Widget? subtitle;
    if (hasTtb) {
      final style = Theme.of(context).textTheme.bodySmall;
      String fmt(double? h) => h != null ? '${h.toStringAsFixed(1)}h' : '—';
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Essential: ${fmt(result.essentialHours)}  ·  Extended: ${fmt(result.extendedHours)}',
            style: style,
          ),
          Text('Completionist: ${fmt(result.completionistHours)}', style: style),
        ],
      );
    } else if (showNoDataLabel) {
      subtitle = const Text('No HLTB data available');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: SizedBox(
          width: 50,
          child: ArtworkImage(url: result.artworkUrl, width: 50),
        ),
        title: Text(result.name),
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}
