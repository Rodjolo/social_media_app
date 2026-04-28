# Recommendation Pipeline

This folder contains a minimal offline pipeline for the diploma demo:

1. Read a MovieLens dataset.
2. Export an initial movie catalog for the Flutter app.
3. Merge it with ratings collected from the Flutter app.
4. Compute top-N movie recommendations.
5. Export JSON that can be uploaded to Firestore.

## Suggested Firestore structure

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

## Dataset

Recommended source: MovieLens latest-small or 32M from GroupLens.

Expected files inside `dataset_dir`:

- `movies.csv`
- `ratings.csv`
- `links.csv`

## Local ratings format

Create a JSON file like this:

```json
[
  { "movieId": 1, "rating": 5.0 },
  { "movieId": 32, "rating": 4.0 },
  { "movieId": 296, "rating": 5.0 }
]
```

## Run

Export a starter movie catalog:

```bash
python movielens_movies_export.py ^
  --dataset-dir path/to/ml-latest-small ^
  --output-file movies_seed.json ^
  --limit 200
```

Then upload `movies_seed.json` into the `movies` collection.

To enrich MovieLens with posters and descriptions from TMDB:

```bash
python enrich_movies_with_tmdb.py ^
  --dataset-dir path/to/ml-latest-small ^
  --tmdb-token YOUR_TMDB_BEARER_TOKEN ^
  --output-file movies_enriched.json ^
  --limit 200
```

Then import `movies_enriched.json` instead of `movies_seed.json`.

You can also enrich an existing export in place:

```bash
python enrich_movies_with_tmdb.py ^
  --dataset-dir path/to/ml-latest-small ^
  --input-file movies_seed.json ^
  --tmdb-token YOUR_TMDB_BEARER_TOKEN ^
  --output-file movies_enriched.json ^
  --language ru-RU
```

Notes:

- the script uses `links.csv` to map each MovieLens `movieId` to a TMDB `tmdbId`
- `--tmdb-token` can be omitted if `TMDB_BEARER_TOKEN` is set in the environment
- the output keeps MovieLens ids, but fills `posterUrl`, `overview`, `genres`, `year`, and `popularity` from TMDB when available
- if TMDB has no match, the script falls back to the original MovieLens data instead of failing the whole export

To enrich and import into PocketBase in one step:

```powershell
$env:TMDB_BEARER_TOKEN="YOUR_TMDB_BEARER_TOKEN"
.\tools\recommendation_pipeline\sync_movies_with_tmdb.ps1 `
  -SuperuserEmail "admin@example.com" `
  -SuperuserPassword "your_password"
```

This helper can also mirror posters into your local PocketBase `media`
collection, so the Flutter emulator loads images from PocketBase instead of
directly from TMDB.

Generate recommendations:

```bash
python movielens_recommender.py ^
  --dataset-dir path/to/ml-latest-small ^
  --user-id demo_user ^
  --user-ratings-file path/to/user_ratings.json ^
  --output-file recommendations.json
```

The script writes a JSON array that can be uploaded into:

- `recommendations/{userId}/items`

Upload movies:

```bash
python firestore_import_json.py ^
  --service-account path/to/serviceAccount.json ^
  --collection movies ^
  --json-file movies_seed.json ^
  --doc-id-field id
```

Upload recommendations:

```bash
python firestore_import_json.py ^
  --service-account path/to/serviceAccount.json ^
  --collection recommendations ^
  --subcollection-user-id YOUR_UID ^
  --subcollection items ^
  --json-file recommendations.json ^
  --doc-id-field movieId
```

## PocketBase flow

Import movies into PocketBase:

```bash
python pocketbase_import_json.py ^
  --base-url http://127.0.0.1:8090 ^
  --superuser-email admin@example.com ^
  --superuser-password your_password ^
  --collection movies ^
  --json-file movies_enriched.json ^
  --lookup-template "movieId={movieId}"
```

Export one user's ratings from PocketBase:

```bash
python pocketbase_export_ratings.py ^
  --base-url http://127.0.0.1:8090 ^
  --superuser-email admin@example.com ^
  --superuser-password your_password ^
  --user-id YOUR_UID ^
  --output-file user_ratings.json
```

Note:

- if older `ratings.movieId` values contain PocketBase internal record ids instead
  of MovieLens ids, the exporter will try to resolve them through the `movies`
  collection automatically.

Generate recommendations:

```bash
python movielens_recommender.py ^
  --dataset-dir path/to/ml-latest-small ^
  --user-id YOUR_UID ^
  --user-ratings-file user_ratings.json ^
  --output-file recommendations.json
```

Import recommendations into PocketBase:

```bash
python pocketbase_import_json.py ^
  --base-url http://127.0.0.1:8090 ^
  --superuser-email admin@example.com ^
  --superuser-password your_password ^
  --collection recommendations ^
  --json-file recommendations.json ^
  --lookup-template "uid={uid} && movieId={movieId}"
```

Rebuild one user's recommendations end-to-end in one command:

```powershell
.\tools\recommendation_pipeline\rebuild_recommendations.ps1 `
  -SuperuserEmail "admin@example.com" `
  -SuperuserPassword "your_password" `
  -UserId "YOUR_UID"
```

This helper:

- exports the current user's ratings from PocketBase
- computes top-N recommendations from MovieLens
- imports them into the `recommendations` collection
- synchronizes titles, posters, genres, and overviews from `movies`
- if a previous local recommendation file exists, builds a small comparison report
  with overlap and changed movie ids

The comparison report is saved into:

- `assets/db/generated/recommendation_report_<uid>.json`

## Optional Firestore upload

If you have a Firebase service account JSON, you can upload results directly:

```bash
python movielens_recommender.py ^
  --dataset-dir path/to/ml-latest-small ^
  --user-id demo_user ^
  --user-ratings-file path/to/user_ratings.json ^
  --output-file recommendations.json ^
  --service-account path/to/serviceAccount.json ^
  --firebase-project your-project-id
```

## Notes

- This pipeline is intentionally simple and diploma-friendly.
- It uses item-based collaborative filtering from a user-item matrix.
- For production, you would likely move recommendation generation to a backend job.
- TMDB data usage should follow their attribution and API terms: [TMDB docs](https://developer.themoviedb.org/), [TMDB API reference](https://developer.themoviedb.org/reference/movie-details), [TMDB configuration endpoint](https://developer.themoviedb.org/reference/configuration-details)

## Defense notes

For a short diploma explanation, see:

- `docs/diploma_recommendation_system.md`
