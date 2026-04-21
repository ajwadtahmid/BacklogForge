enum PlayStyle { essential, extended, completionist }

extension PlayStyleLabel on PlayStyle {
  String get label => switch (this) {
        PlayStyle.essential => 'Essential',
        PlayStyle.extended => 'Extended',
        PlayStyle.completionist => 'Completionist',
      };
}

extension PlayStyleFromNullableString on String? {
  PlayStyle get toPlayStyle => switch (this) {
        'extended' => PlayStyle.extended,
        'completionist' => PlayStyle.completionist,
        _ => PlayStyle.essential,
      };
}
