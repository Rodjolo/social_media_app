# PocketBase Setup

This project is being migrated from Firebase + Supabase to PocketBase.

## Local launch

Recommended local server URL for Android emulator:

- `http://10.0.2.2:8090`

The Flutter app reads it from:

- `lib/config/backend_config.dart`

You can override it at build time:

```bash
flutter run --dart-define=POCKETBASE_URL=http://10.0.2.2:8090
```

## Collections

### `users`

Auth collection.

Fields:

- `name` (`text`)
- `bio` (`text`)
- `profileImage` (`file`, max 1)
- `followers` (`json`)
- `following` (`json`)
- `favoriteGenres` (`json`)
- `movieOnboardingCompleted` (`bool`)

### `posts`

Fields:

- `userId` (`text`)
- `userName` (`text`)
- `text` (`text`)
- `image` (`file`, max 1)
- `imageUrl` (`text`)
- `likes` (`json`)
- `comments` (`json`)
- `timestamp` (`date`)

### `movies`

Fields:

- `title` (`text`)
- `genres` (`json`)
- `posterUrl` (`text`)
- `overview` (`text`)
- `year` (`number`)
- `popularity` (`number`)

### `ratings`

Fields:

- `uid` (`text`)
- `movieId` (`text`)
- `rating` (`number`)
- `liked` (`bool`)
- `timestamp` (`date`)

### `recommendations`

Fields:

- `uid` (`text`)
- `movieId` (`text`)
- `score` (`number`)
- `reason` (`text`)
- `generatedAt` (`date`)
- `title` (`text`)
- `genres` (`json`)
- `posterUrl` (`text`)
- `overview` (`text`)
- `year` (`number`)
- `popularity` (`number`)

## Migration order

1. Disable chat in UI.
2. Add PocketBase client and config.
3. Migrate auth.
4. Migrate profile and image upload.
5. Migrate posts.
6. Migrate movies, ratings, and recommendations.
7. Remove Firebase and Supabase packages after the new flow is stable.
