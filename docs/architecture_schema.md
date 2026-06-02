# Схема архитектуры приложения и базы данных

Документ описывает текущую архитектуру проекта: мобильное приложение Flutter, PocketBase как основной backend, локальный сервис пересчета рекомендаций и Python-пайплайн на основе MovieLens.

## Общая архитектура

```mermaid
flowchart LR
    User["Пользователь"] --> Flutter["Flutter mobile app"]

    Flutter --> AuthCubit["AuthCubit"]
    Flutter --> ProfileCubit["ProfileCubit"]
    Flutter --> PostCubit["PostCubit"]
    Flutter --> SearchCubit["SearchCubit"]
    Flutter --> MovieCubit["MovieCubit"]

    AuthCubit --> AuthRepo["PocketBaseAuthRepo"]
    ProfileCubit --> ProfileRepo["PocketBaseProfileRepo"]
    PostCubit --> PostRepo["PocketBasePostRepo"]
    SearchCubit --> SearchRepo["PocketBaseSearchRepo"]
    MovieCubit --> MovieRepo["PocketBaseMovieRepo"]
    MovieCubit --> RebuildClient["RecommendationServiceClient"]

    AuthRepo --> PB["PocketBase API"]
    ProfileRepo --> PB
    PostRepo --> PB
    SearchRepo --> PB
    MovieRepo --> PB

    RebuildClient --> LocalService["Local recommendation service :8091"]
    LocalService --> Scripts["Python / PowerShell pipeline"]
    Scripts --> PB
    Scripts --> MovieLens["MovieLens dataset"]
    Scripts --> TMDB["TMDB metadata"]

    PB --> SQLite["PocketBase SQLite DB + file storage"]
```

Главная идея: приложение работает с социальными функциями и фильмами через PocketBase. Рекомендации пересчитываются отдельным локальным сервисом, который запускает Python-скрипты, берет оценки пользователя из PocketBase, объединяет их с MovieLens и записывает результат обратно в коллекцию `recommendations`.

## Архитектура Flutter-приложения

```mermaid
flowchart TB
    App["MyApp"]

    App --> Auth["Auth feature"]
    App --> Profile["Profile feature"]
    App --> Posts["Posts feature"]
    App --> Search["Search feature"]
    App --> Movies["Movies feature"]
    App --> Storage["Storage feature"]

    Auth --> AuthRepo["PocketBaseAuthRepo"]
    Profile --> ProfileRepo["PocketBaseProfileRepo"]
    Posts --> PostRepo["PocketBasePostRepo"]
    Search --> SearchRepo["PocketBaseSearchRepo"]
    Movies --> MovieRepo["PocketBaseMovieRepo"]
    Storage --> StorageRepo["PocketBaseStorageRepo"]

    Movies --> MoviesPage["MoviesPage: оценка фильмов"]
    Movies --> RecommendationsPage["RecommendationsPage: рекомендации"]
    Movies --> AdminPage["RecommendationAdminPage: статус и пересчет"]

    AuthRepo --> Client["PocketBaseClient"]
    ProfileRepo --> Client
    PostRepo --> Client
    SearchRepo --> Client
    MovieRepo --> Client
    StorageRepo --> Client

    Client --> Config["BackendConfig"]
    Client --> PB["PocketBase"]
```

В приложении используется слой репозиториев. UI-экраны не работают с PocketBase напрямую: они обращаются к Cubit, Cubit вызывает репозиторий, а репозиторий уже общается с PocketBase.

## Пайплайн рекомендаций

```mermaid
sequenceDiagram
    participant User as Пользователь
    participant App as Flutter app
    participant PB as PocketBase
    participant Service as Local service :8091
    participant Pipeline as Python pipeline
    participant ML as MovieLens dataset

    User->>App: Ставит оценку фильму
    App->>PB: Создает/обновляет запись ratings
    App->>Service: POST /rebuild с userId
    Service->>Pipeline: rebuild_recommendations.ps1
    Pipeline->>PB: Экспорт оценок пользователя
    Pipeline->>ML: Чтение ratings.csv и movies.csv
    Pipeline->>Pipeline: Item-based collaborative filtering
    Pipeline->>PB: Импорт recommendations
    Pipeline->>PB: Синхронизация metadata фильмов
    App->>Service: GET /status
    App->>PB: Загружает новые рекомендации
```

Алгоритм использует item-based collaborative filtering: строится матрица пользователь-фильм, затем считается похожесть фильмов по паттернам оценок. Оценки текущего пользователя добавляются как новый синтетический пользователь MovieLens.

## Схема базы данных PocketBase

```mermaid
erDiagram
    users ||--o{ posts : creates
    users ||--o{ ratings : rates
    users ||--o{ recommendations : receives
    users ||--o{ media : uploads
    movies ||--o{ ratings : rated_as
    movies ||--o{ recommendations : recommended_as

    users {
        string id PK
        string email
        string name
        string bio
        string profileImageUrl
        file profileImage
        json followers
        json following
        json favoriteGenres
        bool movieOnboardingCompleted
        bool isAdmin
        bool verified
    }

    posts {
        string id PK
        string userId FK
        string userName
        string text
        string imageUrl
        datetime timestamp
        json likes
        json comments
    }

    movies {
        string id PK
        string movieId
        string title
        json genres
        string posterUrl
        file posterFile
        string overview
        number year
        number popularity
    }

    ratings {
        string id PK
        string uid FK
        string movieId FK
        number rating
        bool liked
        datetime timestamp
    }

    recommendations {
        string id PK
        string uid FK
        string movieId FK
        number score
        string reason
        datetime generatedAt
        string title
        json genres
        string posterUrl
        string overview
        number year
        number popularity
    }

    media {
        string id PK
        string ownerId FK
        string category
        file file
    }
```

## Коллекции PocketBase

| Коллекция | Назначение | Основные поля |
|---|---|---|
| `users` | Аккаунты пользователей, профиль и роль администратора | `email`, `name`, `bio`, `profileImageUrl`, `profileImage`, `followers`, `following`, `isAdmin` |
| `posts` | Посты социальной сети | `userId`, `userName`, `text`, `imageUrl`, `timestamp`, `likes`, `comments` |
| `media` | Загруженные файлы профиля и постов | `ownerId`, `category`, `file` |
| `movies` | Каталог фильмов из MovieLens, обогащенный TMDB | `movieId`, `title`, `genres`, `posterUrl`, `posterFile`, `overview`, `year`, `popularity` |
| `ratings` | Оценки и лайки фильмов конкретного пользователя | `uid`, `movieId`, `rating`, `liked`, `timestamp` |
| `recommendations` | Персональные рекомендации пользователя | `uid`, `movieId`, `score`, `reason`, `generatedAt`, metadata фильма |

## Основные сценарии данных

### Регистрация и профиль

```mermaid
flowchart LR
    Register["Регистрация"] --> Users["users"]
    Login["Вход"] --> AuthStore["PocketBase authStore"]
    ProfileEdit["Редактирование профиля"] --> Users
    ImageUpload["Загрузка аватара"] --> Media["media"]
    Media --> Users
```

### Посты

```mermaid
flowchart LR
    CreatePost["Создание поста"] --> Posts["posts"]
    UploadImage["Загрузка изображения"] --> Media["media"]
    Media --> Posts
    Like["Лайк поста"] --> Posts
    Comment["Комментарий"] --> Posts
```

### Фильмы и рекомендации

```mermaid
flowchart LR
    MoviesScreen["Экран Фильмы"] --> Movies["movies"]
    MoviesScreen --> Ratings["ratings"]
    Ratings --> Service["Local recommendation service"]
    Service --> Pipeline["MovieLens recommender"]
    Pipeline --> Recommendations["recommendations"]
    Recommendations --> RecScreen["Экран Рекомендации"]
    Pipeline --> Validation["validation report"]
    Validation --> AdminPanel["Панель рекомендаций"]
```

## Локальные сервисы и конфигурация

| Компонент | По умолчанию | Назначение |
|---|---:|---|
| PocketBase | `http://10.0.2.2:8090` в Android emulator, `http://127.0.0.1:8090` на компьютере | Основная база данных и файловое хранилище |
| Recommendation service | `http://10.0.2.2:8091` в Android emulator, `http://127.0.0.1:8091` на компьютере | HTTP-обертка над локальным пересчетом рекомендаций |
| MovieLens dataset | `assets/db/ml-latest-small` | Источник исторических оценок и каталога фильмов |
| TMDB | внешний API | Постеры, описания, жанры и популярность фильмов |

Ключевые настройки находятся в `lib/config/backend_config.dart`. Для локального запуска на Android emulator приложение использует `10.0.2.2`, потому что `127.0.0.1` внутри emulator указывает на сам emulator, а не на компьютер.

## Где находится код

| Часть | Путь |
|---|---|
| PocketBase config | `lib/config/backend_config.dart`, `lib/config/pocketbase_client.dart` |
| Auth/Profile/Post/Search/Storage repos | `lib/features/*/data/pocketbase_*_repo.dart` |
| Movies feature | `lib/features/movies/` |
| Recommendation UI | `lib/features/movies/presentation/pages/recommendations_page.dart` |
| Admin panel | `lib/features/movies/presentation/pages/recommendation_admin_page.dart` |
| Python pipeline | `tools/recommendation_pipeline/` |
| Setup docs | `docs/pocketbase_setup.md`, `tools/recommendation_pipeline/README.md` |
