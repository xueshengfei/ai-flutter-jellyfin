# jellyfin_models

Shared business models for Jellyfin media apps. Pure Dart models for media items, libraries, users, and playback contracts.

## Features

- `MediaItem` - Movies, series, episodes, albums, artists, audio
- `MediaLibrary` - Media library with type info
- `Season` / `Episode` - Series season and episode models
- `AppUser` / `AppSession` - User and session models
- `ServerInfo` - Server discovery models
- Type aliases for data fetching contracts (`MediaItemDetailFetcher`, etc.)

All models extend `Equatable` for value equality and are pure Dart (no Flutter dependency).

## Usage

```dart
import 'package:jellyfin_models/jellyfin_models.dart';

final item = MediaItem(
  id: '123',
  name: 'Inception',
  type: 'Movie',
  serverUrl: 'https://jellyfin.example.com',
  productionYear: 2010,
  communityRating: 8.8,
);

print(item.typeDisplayName); // '电影'
print(item.durationText);    // '148分钟'
```
