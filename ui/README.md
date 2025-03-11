# Davinci3 Wiki UI

A cross-platform desktop application for browsing offline Wikipedia content.

## Features

- Browse articles with infinite scrolling
- Search for articles with full-text and semantic search
- Read article details with related articles
- Offline support with caching
- Dark mode support
- Responsive layout

## Architecture

The application follows a simple and clean architecture:

### Models
- `Article`: Represents a Wikipedia article.
- `SearchResult`: Represents a search result.
- `Settings`: Application settings.

### Services
- `WikiService`: Communicates with the backend API and provides offline fallback.
- `CacheService`: Handles local caching of articles and search results.
- `SearchHistoryService`: Manages search history.
- `SettingsService`: Manages application settings.

### UI
- `ArticlesPage`: Displays a list of articles with infinite scrolling.
- `SearchPage`: Provides text and semantic search with history.
- `ArticleDetailsPage`: Displays article content and related articles.
- `SettingsPage`: Manages application settings.

## Development

### Dependencies

- Flutter SDK (3.0+)
- Visual Studio Build Tools (Windows)
- XCode (macOS)
- Linux development packages (Linux)

### Setup

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Enable desktop support: https://docs.flutter.dev/desktop
3. Clone this repository
4. Run `flutter pub get` to install dependencies
5. Run `flutter run -d windows/macos/linux` to run the app

### Building

To build the application for distribution:

```bash
flutter build windows
flutter build macos
flutter build linux
```

The built application will be located in the `build` directory.

## Testing

To run the tests:

```bash
flutter test
```

## License

MIT License
