# Настройка PocketBase

Этот проект переводится с Firebase + Supabase на PocketBase.

## Локальный запуск

Рекомендуемый URL локального сервера для эмулятора Android:

- `http://10.0.2.2:8090`

Flutter-приложение читает его из:

- `lib/config/backend_config.dart`

Его можно переопределить во время сборки:

```bash
flutter run --dart-define=POCKETBASE_URL=http://10.0.2.2:8090
```

## Коллекции

### `users`

Коллекция авторизации.

Fields:

- `name` (`text`)
- `bio` (`text`)
- `profileImageUrl` (`text`)
- `profileImage` (`file`, max 1)
- `followers` (`json`)
- `following` (`json`)
- `favoriteGenres` (`json`)
- `movieOnboardingCompleted` (`bool`)

Параметры аутентификации PocketBase:

- collection type: `Auth`
- enable email/password authentication
- require unique email
- allow authenticated users to manage their own record

Рекомендуемые правила API для начальной локальной разработки:

- list rule: `@request.auth.id != ""`
- view rule: `@request.auth.id != ""`
- create rule: empty
- update rule: `@request.auth.id = id`
- delete rule: `@request.auth.id = id`

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

### `media`

Fields:

- `ownerId` (`text`)
- `category` (`text`)
- `file` (`file`, max 1)

Рекомендуемые правила API для локальной разработки:

- `list`: `@request.auth.id != ""`
- `view`: `@request.auth.id != ""`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

### `movies`

Fields:

- `movieId` (`text`)
- `title` (`text`)
- `genres` (`json`)
- `posterUrl` (`text`)
- `overview` (`text`)
- `year` (`number`)
- `popularity` (`number`)

Рекомендуемые правила API для локальной разработки:

- `list`: `@request.auth.id != ""`
- `view`: `@request.auth.id != ""`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

### `ratings`

Fields:

- `uid` (`text`)
- `movieId` (`text`)
- `rating` (`number`)
- `liked` (`bool`)
- `timestamp` (`date`)

Рекомендуемые правила API для локальной разработки:

- `list`: `@request.auth.id != "" && uid = @request.auth.id`
- `view`: `@request.auth.id != "" && uid = @request.auth.id`
- `create`: `@request.auth.id != "" && @request.body.uid = @request.auth.id`
- `update`: `@request.auth.id != "" && uid = @request.auth.id`
- `delete`: `@request.auth.id != "" && uid = @request.auth.id`

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

Рекомендуемые правила API для локальной разработки:

- `list`: `@request.auth.id != "" && uid = @request.auth.id`
- `view`: `@request.auth.id != "" && uid = @request.auth.id`
- `create`: `@request.auth.id != ""`
- `update`: `@request.auth.id != ""`
- `delete`: `@request.auth.id != ""`

## Порядок миграции

1. Отключить чат в интерфейсе.
2. Добавить клиент PocketBase и конфигурацию.
3. Перенести аутентификацию.
4. Перенести профиль и загрузку изображений.
5. Перенести посты.
6. Перенести фильмы, оценки и рекомендации.
7. Удалить пакеты Firebase и Supabase после того, как новый поток работы станет стабильным.
