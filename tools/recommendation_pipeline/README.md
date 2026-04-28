# Пайплайн рекомендаций

В этой папке находится минимальный офлайн-пайплайн для демонстрации диплома:

1. Считывает набор данных MovieLens.
2. Экспортирует стартовый каталог фильмов для Flutter-приложения.
3. Объединяет его с оценками, собранными из Flutter-приложения.
4. Вычисляет топ-N рекомендаций фильмов.
5. Экспортирует JSON, который можно загрузить в Firestore.

## Рекомендуемая структура Firestore

- `movies/{movieId}`
  - `id`
  - `title`
  - `genres`
  - `posterUrl`
  - `overview`
  - `year`
  - `popularity`
- `ratings/{uid_movieId}`
  - `id`
  - `uid`
  - `movieId`
  - `rating`
  - `liked`
  - `timestamp`
- `recommendations/{uid}/items/{movieId}`
  - `movieId`
  - `score`
  - `reason`
  - `generatedAt`
  - optional denormalized fields: `title`, `genres`, `posterUrl`, `overview`, `year`

## Набор данных

Рекомендуемый источник: MovieLens latest-small или 32M от GroupLens.

Ожидаемые файлы внутри `dataset_dir`:

- `movies.csv`
- `ratings.csv`
- `links.csv`

## Формат локальных оценок

Create a JSON file like this:

```json
[
  { "movieId": 1, "rating": 5.0 },
  { "movieId": 32, "rating": 4.0 },
  { "movieId": 296, "rating": 5.0 }
]
```

## Запуск

Экспорт стартового каталога фильмов:

```bash
python movielens_movies_export.py ^
  --dataset-dir path/to/ml-latest-small ^
  --output-file movies_seed.json ^
  --limit 200
```

Затем загрузите `movies_seed.json` в коллекцию `movies`.

Чтобы обогатить MovieLens постерами и описаниями из TMDB:

```bash
python enrich_movies_with_tmdb.py ^
  --dataset-dir path/to/ml-latest-small ^
  --tmdb-token YOUR_TMDB_BEARER_TOKEN ^
  --output-file movies_enriched.json ^
  --limit 200
```

Затем импортируйте `movies_enriched.json` вместо `movies_seed.json`.

Также можно обогатить уже существующий экспорт на месте:

```bash
python enrich_movies_with_tmdb.py ^
  --dataset-dir path/to/ml-latest-small ^
  --input-file movies_seed.json ^
  --tmdb-token YOUR_TMDB_BEARER_TOKEN ^
  --output-file movies_enriched.json ^
  --language ru-RU
```

Примечания:

- скрипт использует `links.csv`, чтобы сопоставить каждый `movieId` из MovieLens с `tmdbId` из TMDB
- `--tmdb-token` можно не указывать, если `TMDB_BEARER_TOKEN` задан в окружении
- результат сохраняет идентификаторы MovieLens, но при наличии данных заполняет `posterUrl`, `overview`, `genres`, `year` и `popularity` из TMDB
- если в TMDB нет совпадения, скрипт откатывается к исходным данным MovieLens вместо того, чтобы прерывать весь экспорт

Чтобы обогатить данные и импортировать их в PocketBase за один шаг:

```powershell
$env:TMDB_BEARER_TOKEN="YOUR_TMDB_BEARER_TOKEN"
.\tools\recommendation_pipeline\sync_movies_with_tmdb.ps1 `
  -SuperuserEmail "admin@example.com" `
  -SuperuserPassword "your_password"
```

Этот помощник также может зеркалировать постеры в вашу локальную коллекцию PocketBase `media`, чтобы эмулятор Flutter загружал изображения из PocketBase, а не напрямую из TMDB.

Сгенерировать рекомендации:

```bash
python movielens_recommender.py ^
  --dataset-dir path/to/ml-latest-small ^
  --user-id demo_user ^
  --user-ratings-file path/to/user_ratings.json ^
  --output-file recommendations.json
```

Скрипт записывает JSON-массив, который можно загрузить в:

- `recommendations/{userId}/items`

Загрузка фильмов:

```bash
python firestore_import_json.py ^
  --service-account path/to/serviceAccount.json ^
  --collection movies ^
  --json-file movies_seed.json ^
  --doc-id-field id
```

Загрузка рекомендаций:

```bash
python firestore_import_json.py ^
  --service-account path/to/serviceAccount.json ^
  --collection recommendations ^
  --subcollection-user-id YOUR_UID ^
  --subcollection items ^
  --json-file recommendations.json ^
  --doc-id-field movieId
```

## Поток PocketBase

Импорт фильмов в PocketBase:

```bash
python pocketbase_import_json.py ^
  --base-url http://127.0.0.1:8090 ^
  --superuser-email admin@example.com ^
  --superuser-password your_password ^
  --collection movies ^
  --json-file movies_enriched.json ^
  --lookup-template "movieId={movieId}"
```

Экспорт оценок одного пользователя из PocketBase:

```bash
python pocketbase_export_ratings.py ^
  --base-url http://127.0.0.1:8090 ^
  --superuser-email admin@example.com ^
  --superuser-password your_password ^
  --user-id YOUR_UID ^
  --output-file user_ratings.json
```

Примечание:

- если старые значения `ratings.movieId` содержат внутренние идентификаторы записей PocketBase вместо идентификаторов MovieLens, экспортёр попытается автоматически разрешить их через коллекцию `movies`

Сгенерировать рекомендации:

```bash
python movielens_recommender.py ^
  --dataset-dir path/to/ml-latest-small ^
  --user-id YOUR_UID ^
  --user-ratings-file user_ratings.json ^
  --output-file recommendations.json
```

Импорт рекомендаций в PocketBase:

```bash
python pocketbase_import_json.py ^
  --base-url http://127.0.0.1:8090 ^
  --superuser-email admin@example.com ^
  --superuser-password your_password ^
  --collection recommendations ^
  --json-file recommendations.json ^
  --lookup-template "uid={uid} && movieId={movieId}"
```

Пересобрать рекомендации одного пользователя end-to-end одной командой:

```powershell
.\tools\recommendation_pipeline\rebuild_recommendations.ps1 `
  -SuperuserEmail "admin@example.com" `
  -SuperuserPassword "your_password" `
  -UserId "YOUR_UID"
```

Этот помощник:

- экспортирует оценки текущего пользователя из PocketBase
- вычисляет топ-N рекомендаций на основе MovieLens
- импортирует их в коллекцию `recommendations`
- синхронизирует названия, постеры, жанры и описания из `movies`
- если существует предыдущий локальный файл рекомендаций, формирует небольшой сравнительный отчёт с пересечением и изменившимися идентификаторами фильмов

Сравнительный отчёт сохраняется в:

- `assets/db/generated/recommendation_report_<uid>.json`

## Необязательная загрузка в Firestore

Если у вас есть JSON сервисного аккаунта Firebase, вы можете загружать результаты напрямую:

```bash
python movielens_recommender.py ^
  --dataset-dir path/to/ml-latest-small ^
  --user-id demo_user ^
  --user-ratings-file path/to/user_ratings.json ^
  --output-file recommendations.json ^
  --service-account path/to/serviceAccount.json ^
  --firebase-project your-project-id
```

## Примечания

- Этот пайплайн намеренно простой и подходит для диплома.
- Он использует item-based collaborative filtering на основе матрицы пользователь-элемент.
- Для production, вероятно, стоит перенести генерацию рекомендаций в backend-job.
- При использовании данных TMDB нужно соблюдать их требования к атрибуции и API: [документация TMDB](https://developer.themoviedb.org/), [справочник API TMDB](https://developer.themoviedb.org/reference/movie-details), [эндпоинт конфигурации TMDB](https://developer.themoviedb.org/reference/configuration-details)

## Примечания для защиты

Для краткого объяснения в дипломе см.:

- `docs/diploma_recommendation_system.md`
