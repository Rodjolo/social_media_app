# Пайплайн рекомендаций

В этой папке находится offline-пайплайн для демонстрации диплома.

Он решает четыре задачи:

1. Подготавливает каталог фильмов из MovieLens.
2. Обогащает фильмы метаданными из TMDB.
3. Вычисляет персональные рекомендации на основе оценок пользователя.
4. Загружает результат обратно в PocketBase.

## Какие файлы нужны

В папке датасета MovieLens должны быть:

- `movies.csv`
- `ratings.csv`
- `links.csv`

Рекомендуемый источник:

- `MovieLens latest-small`

## Формат локальных оценок пользователя

Пример файла:

```json
[
  { "movieId": 1, "rating": 5.0 },
  { "movieId": 32, "rating": 4.0 },
  { "movieId": 296, "rating": 5.0 }
]
```

## Экспорт стартового каталога фильмов

```powershell
python .\tools\recommendation_pipeline\movielens_movies_export.py `
  --dataset-dir .\assets\db\ml-latest-small `
  --output-file .\assets\db\movies_seed.json `
  --limit 200
```

## Обогащение фильмов через TMDB

```powershell
$env:TMDB_BEARER_TOKEN="YOUR_TMDB_BEARER_TOKEN"
python .\tools\recommendation_pipeline\enrich_movies_with_tmdb.py `
  --dataset-dir .\assets\db\ml-latest-small `
  --input-file .\assets\db\movies_seed.json `
  --output-file .\assets\db\movies_enriched.json `
  --language ru-RU
```

Что заполняется:

- русское название;
- описание;
- жанры;
- постер;
- год;
- популярность.

## Импорт фильмов в PocketBase

```powershell
python .\tools\recommendation_pipeline\pocketbase_import_json.py `
  --base-url http://127.0.0.1:8090 `
  --superuser-email "admin@example.com" `
  --superuser-password "your_password" `
  --collection movies `
  --json-file .\assets\db\movies_enriched.json `
  --lookup-template "movieId={movieId}"
```

## Экспорт оценок пользователя

```powershell
python .\tools\recommendation_pipeline\pocketbase_export_ratings.py `
  --base-url http://127.0.0.1:8090 `
  --superuser-email "admin@example.com" `
  --superuser-password "your_password" `
  --user-id "YOUR_UID" `
  --output-file .\assets\db\user_ratings.json
```

## Генерация рекомендаций

```powershell
python .\tools\recommendation_pipeline\movielens_recommender.py `
  --dataset-dir .\assets\db\ml-latest-small `
  --user-id "YOUR_UID" `
  --user-ratings-file .\assets\db\user_ratings.json `
  --output-file .\assets\db\recommendations.json
```

## Импорт рекомендаций в PocketBase

```powershell
python .\tools\recommendation_pipeline\pocketbase_import_json.py `
  --base-url http://127.0.0.1:8090 `
  --superuser-email "admin@example.com" `
  --superuser-password "your_password" `
  --collection recommendations `
  --json-file .\assets\db\recommendations.json `
  --lookup-template "uid={uid} && movieId={movieId}"
```

## Пересчет одной командой

```powershell
.\tools\recommendation_pipeline\rebuild_recommendations.ps1 `
  -SuperuserEmail "admin@example.com" `
  -SuperuserPassword "your_password" `
  -UserId "YOUR_UID"
```

Этот скрипт:

- экспортирует оценки пользователя;
- строит новые рекомендации;
- импортирует их в PocketBase;
- синхронизирует метаданные из `movies`;
- при наличии предыдущего файла строит сравнительный отчет.

Сравнительный отчет сохраняется сюда:

- `assets/db/generated/recommendation_report_<uid>.json`

## Локальный HTTP-сервис для запуска из приложения

Чтобы админ мог запускать пересчет прямо из Flutter-приложения, можно поднять маленький локальный сервис:

```powershell
python .\tools\recommendation_pipeline\recommendation_service.py `
  --superuser-email "admin@example.com" `
  --superuser-password "your_password"
```

Важно:

- если логин или пароль superuser неверные, сервис теперь не стартует сразу и покажет понятную ошибку;
- после обновления этого файла сервис нужно перезапустить вручную.

По умолчанию сервис работает на:

- `http://127.0.0.1:8091` на хост-компьютере
- `http://10.0.2.2:8091` для Android Emulator

Доступные endpoint:

- `GET /health`
- `GET /status?userId=...`
- `POST /rebuild`

Пример тела запроса:

```json
{
  "userId": "YOUR_UID",
  "topN": 10
}
```

## Что важно для диплома

Этот пайплайн intentionally простой и хорошо подходит именно для дипломного проекта:

- алгоритм легко объясняется;
- используется публичный датасет MovieLens;
- результат можно воспроизводимо показать на защите;
- пользовательские оценки реально влияют на итоговую подборку.

Подробное описание научной части:

- [описание системы рекомендаций для диплома](../../docs/diploma_recommendation_system.md)
