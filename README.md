# BacklogForge

Know what to play. Actually finish it.

## Description / Overview

BacklogForge connects to your Steam account, imports your game library, and helps you decide what to play next. It pulls completion time estimates from HowLongToBeat and compares them against your actual playtime to automatically track which games you have finished, which are in progress, and which are still sitting in your backlog.

Designed for PC gamers who own large Steam libraries and want a structured, low-friction way to manage them — no spreadsheets, no third-party accounts, all data stored locally.

## Demo

<table>
  <tr>
    <td><img src="assets/screenshots/desktop/Screenshot_1.png" alt="Game library with playtime progress bars, search, and sorting filters" width="400"/></td>
    <td><img src="assets/screenshots/desktop/Screenshot_2.png" alt="Completed games list with status filters and completion tracking" width="400"/></td>
  </tr>
  <tr>
    <td><img src="assets/screenshots/desktop/Screenshot_3.png" alt="Play Next recommendations showing suggested games to play next" width="400"/></td>
    <td><img src="assets/screenshots/desktop/Screenshot_4.png" alt="Library statistics dashboard with completion rate and playtime summary" width="400"/></td>
  </tr>
</table>

## Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.41`
- Dart SDK (bundled with Flutter)
- Python 3.10 or later (only if self-hosting the backend)
- A Steam account with a public game library (optional — guest mode available)

### Clone the repository

```bash
git clone https://github.com/ajwadtahmid/backlogforge.git
cd backlogforge
```

### Install Flutter dependencies

```bash
flutter pub get
```

### Generate database code

BacklogForge uses Drift for its local database. The generated files must be built before the first run.

```bash
dart run build_runner build
```

### Backend

The app connects to a hosted backend at `backlogforge.onrender.com` by default — no extra setup needed.

To self-host, deploy `server/app.py` and update the URL in `lib/services/api_config.dart`:

```bash
cd server
pip install -r requirements.txt
flask run
```

```dart
// lib/services/api_config.dart
abstract final class ApiConfig {
  static const backendUrl = 'https://your-backend-url.com';
}
```

The backend requires a Steam API key. Set it as `STEAM_API_KEY` in your environment or in a `.env` file under `server/`. Obtain a key from the [Steam Web API portal](https://steamcommunity.com/dev/apikey).

## Usage

### Run in debug mode

```bash
flutter run
```

### Build for release

```bash
# Android (AAB for Play Store)
flutter build appbundle --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

On first launch, sign in with your Steam account or continue as a guest. When signed in, BacklogForge syncs your library and fetches HowLongToBeat estimates in the background with live progress. Games are organised across four tabs:

| Tab | Contents |
|---|---|
| **Backlog** | Games you haven't finished yet, sortable and searchable |
| **Completed** | Games you've beaten, with completion dates |
| **Play Next** | Shuffle or "Almost Done" recommendations from your backlog |
| **Stats** | Backlog size, hours remaining, completion rate and grade |

Use the refresh button in the toolbar to re-sync with Steam. Games can also be added manually through the search interface for titles not in your Steam library.

## Features

- **Steam library sync** — imports all games from your Steam account automatically
- **Guest / offline mode** — use the app without a Steam account; add games manually
- **HowLongToBeat integration** — fetches Essential, Extended, and Completionist estimates per title
- **Sync progress feedback** — live counter shows HLTB fetch progress during sync
- **Automatic completion detection** — marks a game completed when playtime meets the target
- **Configurable play style** — choose Essential, Extended, or Completionist as your personal target per game
- **Manual status override** — set any game to Playing or Completed regardless of playtime
- **Play Next recommendation** — weighted shuffle or "Almost Done" filter to surface what to play
- **Library statistics** — completion grade (A+ → D), hours to clear backlog, monthly activity
- **Manual game search** — add titles that are not in your Steam library
- **Dark and light theme** — persisted across sessions
- **Offline-first** — all data stored locally in SQLite; no cloud sync required

## Tech Stack / Built With

| Layer | Technology |
|---|---|
| UI framework | Flutter (Dart) |
| State management | Riverpod |
| Navigation | go_router |
| Local database | Drift (SQLite) |
| Secure storage | flutter_secure_storage |
| Completion time data | HowLongToBeat (via self-hosted proxy) |
| Proxy backend | Python, Flask, howlongtobeatpy |
| Image caching | cached_network_image |
| CI / CD | GitHub Actions (analyze, test, Windows / Linux / Android builds) |
| Platforms | Android, Windows, Linux |

## Contributing

Pull requests are welcome. For significant changes, open an issue first to discuss what you'd like to change. Please make sure `flutter analyze` and `flutter test` pass before submitting.

## License

BacklogForge is distributed under the [GNU General Public License v3.0](LICENSE). You are free to use, modify, and distribute this software under the terms of that license.

## Credits / Acknowledgments

- [HowLongToBeat](https://howlongtobeat.com) for game completion time data
- [howlongtobeatpy](https://github.com/ScrappyCocco/HowLongToBeat-PythonAPI) for the Python scraper library
- [Valve / Steam](https://store.steampowered.com) for the Web API
- [Claude Code](https://claude.ai/code) - Parts of this project were built with the assistance of Claude
