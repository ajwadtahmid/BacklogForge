/// App-wide constants. Centralised here so a single change propagates everywhere.
abstract final class AppConstants {
  // ── Network timeouts ────────────────────────────────────────────────────────
  /// Timeout for all HLTB proxy requests (search + lookup).
  static const kHltbTimeout = Duration(seconds: 15);

  /// Timeout for Steam library requests; extra headroom for Render cold starts.
  static const kSteamTimeout = Duration(seconds: 45);

  // ── Debounce / pacing ───────────────────────────────────────────────────────
  /// Debounce delay before firing a search query while the user is typing.
  static const kSearchDebounce = Duration(milliseconds: 400);

  /// Minimum gap between sequential HLTB fetch requests during a sync to avoid
  /// rate-limiting the backend scraper.
  static const kHltbRequestGap = Duration(milliseconds: 300);

  // ── Query limits ────────────────────────────────────────────────────────────
  /// Maximum search query length; mirrors the server-side cap in app.py.
  static const kMaxQueryLength = 100;

  // ── Progress thresholds ─────────────────────────────────────────────────────
  /// Progress ratio below which a started game is considered "barely played".
  static const kBarelyPlayedRatio = 0.10;

  /// Progress ratio at or above which a game is considered "halfway done".
  static const kHalfwayRatio = 0.50;

  // ── UI layout ───────────────────────────────────────────────────────────────
  /// Height of the artwork header on the game detail screen.
  static const kDetailHeaderHeight = 280.0;

  /// Inset from the edges for the title overlay on the artwork header.
  static const kArtworkTitlePadding = 20.0;

  // ── Daily budget stepper ────────────────────────────────────────────────────
  static const kMinBudget = 0.5;
  static const kMaxBudget = 12.0;
  static const kBudgetStep = 0.5;

  // ── HLTB retry window ───────────────────────────────────────────────────────
  /// Games whose HLTB lookup was attempted within this window are skipped on
  /// re-sync, avoiding redundant scrapes for titles not found on HLTB.
  static const kHltbRetryWindow = Duration(days: 7);

  // ── Play Next ───────────────────────────────────────────────────────────────
  /// Number of picks shown on the Play Next tab.
  static const kPickCount = 5;

  // ── Progress bar colour bands ───────────────────────────────────────────────
  /// Progress ratio at which the bar transitions from primary → amber.
  static const kProgressColorMidThreshold = 0.33;

  /// Progress ratio at which the bar transitions from amber → green.
  static const kProgressColorHiThreshold = 0.66;

  // ── Game length buckets ─────────────────────────────────────────────────────
  /// Upper bound (exclusive) for the "short" length-filter bucket. UI labels
  /// must match: "Short < 10h", "Medium 10–30h", "Long ≥ 30h".
  static const kShortGameHours = 10.0;

  /// Lower bound for the "long" bucket; upper bound for "medium". UI labels must
  /// stay in sync with [kShortGameHours].
  static const kMediumGameHours = 30.0;

  // ── SQL sort sentinel ───────────────────────────────────────────────────────
  /// Placeholder hours value used in ORDER BY expressions so games without
  /// HLTB data always sort to the end of the list.
  static const kSortNoDataSentinel = 9999.0;

  // ── List scroll clearance ───────────────────────────────────────────────────
  /// Bottom padding when a FAB is visible so the last row is not obscured.
  static const kFabClearance = 80.0;

  /// Bottom padding when the bulk-action bar is visible.
  static const kBulkBarClearance = 72.0;
}
