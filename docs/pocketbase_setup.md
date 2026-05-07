# Настройка PocketBase

Этот проект переведен с Firebase и Supabase на PocketBase.

## Локальный запуск

Для Android Emulator рекомендуется использовать адрес:

- `http://10.0.2.2:8090`

Для локального сервиса пересчета рекомендаций:

- `http://10.0.2.2:8091`

Адреса задаются в:

- [backend_config.dart](/C:/Flutter%20Projects/SocialMediaApp/social_media_app/lib/config/backend_config.dart)

При необходимости их можно переопределить:

```powershell
flutter run --dart-define=POCKETBASE_URL=http://10.0.2.2:8090 --dart-define=RECOMMENDATION_SERVICE_URL=http://10.0.2.2:8091
```

## Коллекции PocketBase

### `users`

Тип коллекции:

- `Auth`

Поля:

- `name` — `text`
- `bio` — `text`
- `profileImageUrl` — `text`
- `profileImage` — `file`, максимум 1
- `followers` — `json`
- `following` — `json`
- `favoriteGenres` — `json`
- `movieOnboardingCompleted` — `bool`
- `isAdmin` — `bool`

Рекомендуемые API rules:

- `list`: `@request.auth.id != ""`
- `view`: `@request.auth.id != ""`
- `create`: пусто
- `update`: `@request.auth.id = id`
- `delete`: `@request.auth.id = id`

### `posts`

Поля:

- `userId` — `text`
- `userName` — `text`
- `text` — `text`
- `image` — `file`, максимум 1
- `imageUrl` — `text`
- `likes` — `json`
- `comments` — `json`
- `timestamp` — `date`

Рекомендуемые API rules:

- `list`: `@request.auth.id != ""`
- `view`: `@request.auth.id != ""`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

### `media`

Поля:

- `ownerId` — `text`
- `category` — `text`
- `file` — `file`, максимум 1

Рекомендуемые API rules:

- `list`: `@request.auth.id != ""`
- `view`: `@request.auth.id != ""`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

### `movies`

Поля:

- `movieId` — `text`
- `title` — `text`
- `genres` — `json`
- `posterUrl` — `text`
- `overview` — `text`
- `year` — `number`
- `popularity` — `number`

Рекомендуемые API rules:

- `list`: `@request.auth.id != ""`
- `view`: `@request.auth.id != ""`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

### `ratings`

Поля:

- `uid` — `text`
- `movieId` — `text`
- `rating` — `number`
- `liked` — `bool`
- `timestamp` — `date`

Рекомендуемые API rules:

- `list`: `@request.auth.id != "" && uid = @request.auth.id`
- `view`: `@request.auth.id != "" && uid = @request.auth.id`
- `create`: `@request.auth.id != "" && @request.body.uid = @request.auth.id`
- `update`: `@request.auth.id != "" && uid = @request.auth.id`
- `delete`: `@request.auth.id != "" && uid = @request.auth.id`

### `recommendations`

Поля:

- `uid` — `text`
- `movieId` — `text`
- `score` — `number`
- `reason` — `text`
- `generatedAt` — `date`
- `title` — `text`
- `genres` — `json`
- `posterUrl` — `text`
- `overview` — `text`
- `year` — `number`
- `popularity` — `number`

Рекомендуемые API rules:

- `list`: `@request.auth.id != "" && uid = @request.auth.id`
- `view`: `@request.auth.id != "" && uid = @request.auth.id`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

## Что обязательно для админ-панели рекомендаций

Чтобы служебная панель пересчета была доступна только админу:

1. Добавь в `users` поле `isAdmin`.
2. Для своего пользователя выставь `isAdmin = true`.
3. Для обычных пользователей оставь `false`.

После этого нужно заново войти в приложение, чтобы роль перечиталась из PocketBase.

## Порядок миграции

1. Поднять PocketBase локально.
2. Создать коллекцию `users` типа `Auth`.
3. Создать `posts`, `media`, `movies`, `ratings`, `recommendations`.
4. Импортировать фильмы.
5. Протестировать регистрацию, профиль и посты.
6. Протестировать оценки фильмов и рекомендации.
