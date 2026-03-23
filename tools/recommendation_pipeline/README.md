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
  --json-file movies_seed.json ^
  --lookup-template "movieId=\"{movieId}\""
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
  --lookup-template "uid=\"{uid}\" && movieId=\"{movieId}\""
```

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
