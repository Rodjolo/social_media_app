import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:  # pragma: no cover
    firebase_admin = None
    credentials = None
    firestore = None


def parse_args():
    parser = argparse.ArgumentParser(description="Generate movie recommendations from MovieLens.")
    parser.add_argument("--dataset-dir", required=True, help="Path to MovieLens dataset folder.")
    parser.add_argument("--user-id", required=True, help="Application user id.")
    parser.add_argument(
        "--user-ratings-file",
        required=True,
        help="JSON file with current app user ratings.",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Path to resulting recommendation JSON.",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=10,
        help="How many recommendations to export.",
    )
    parser.add_argument(
        "--service-account",
        help="Optional Firebase service account JSON for direct upload.",
    )
    parser.add_argument(
        "--firebase-project",
        help="Optional Firebase project id. Used only for upload logs.",
    )
    return parser.parse_args()


def load_movielens(dataset_dir: Path):
    movies = pd.read_csv(dataset_dir / "movies.csv")
    ratings = pd.read_csv(dataset_dir / "ratings.csv")
    return movies, ratings


def load_user_ratings(user_ratings_file: Path, synthetic_user_id: int):
    raw = json.loads(user_ratings_file.read_text(encoding="utf-8"))
    rows = []
    for entry in raw:
        rows.append(
            {
                "userId": synthetic_user_id,
                "movieId": int(entry["movieId"]),
                "rating": float(entry["rating"]),
                "timestamp": int(datetime.now(tz=timezone.utc).timestamp()),
            }
        )
    return pd.DataFrame(rows)


def build_recommendations(movies_df, ratings_df, target_user_id: int, top_n: int):
    matrix = ratings_df.pivot_table(
        index="userId",
        columns="movieId",
        values="rating",
        fill_value=0,
    )

    similarity = cosine_similarity(matrix.T)
    similarity_df = pd.DataFrame(
        similarity,
        index=matrix.columns,
        columns=matrix.columns,
    )

    target_ratings = matrix.loc[target_user_id]
    rated_movies = target_ratings[target_ratings > 0]

    scores = {}
    for movie_id, rating in rated_movies.items():
        similar_items = similarity_df[movie_id].sort_values(ascending=False)
        for candidate_id, similarity_score in similar_items.items():
            if candidate_id in rated_movies.index:
                continue
            scores.setdefault(candidate_id, 0.0)
            scores[candidate_id] += similarity_score * rating

    ranked = sorted(scores.items(), key=lambda item: item[1], reverse=True)[:top_n]

    recommendations = []
    for movie_id, score in ranked:
        movie_row = movies_df[movies_df["movieId"] == movie_id]
        if movie_row.empty:
            continue
        movie = movie_row.iloc[0]
        title = str(movie["title"])
        year = extract_year(title)
        recommendations.append(
            {
                "movieId": str(movie_id),
                "score": round(float(score), 4),
                "reason": "Recommended from similar rating patterns in MovieLens.",
                "generatedAt": datetime.now(tz=timezone.utc).isoformat(),
                "title": clean_title(title),
                "genres": split_genres(movie.get("genres", "")),
                "posterUrl": "",
                "overview": "",
                "year": year,
                "popularity": float(score),
            }
        )

    return recommendations


def clean_title(title: str) -> str:
    if title.endswith(")") and "(" in title:
        return title.rsplit("(", maxsplit=1)[0].strip()
    return title.strip()


def extract_year(title: str) -> int:
    if not title.endswith(")") or "(" not in title:
        return 0
    year_text = title.rsplit("(", maxsplit=1)[-1].replace(")", "").strip()
    return int(year_text) if year_text.isdigit() else 0


def split_genres(raw_value):
    if not raw_value or raw_value == "(no genres listed)":
        return []
    return [part for part in str(raw_value).split("|") if part]


def export_json(recommendations, output_file: Path):
    output_file.write_text(
        json.dumps(recommendations, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def upload_to_firestore(service_account_path: Path, user_id: str, recommendations):
    if firebase_admin is None:
        raise RuntimeError(
            "firebase-admin is not installed. Run pip install -r requirements.txt first."
        )

    app = firebase_admin.get_app() if firebase_admin._apps else firebase_admin.initialize_app(  # pylint: disable=protected-access
        credentials.Certificate(str(service_account_path))
    )
    db = firestore.client(app=app)

    collection = (
        db.collection("recommendations")
        .document(user_id)
        .collection("items")
    )

    batch = db.batch()
    for item in recommendations:
        doc_ref = collection.document(str(item["movieId"]))
        payload = dict(item)
        payload["generatedAt"] = datetime.now(tz=timezone.utc)
        batch.set(doc_ref, payload)
    batch.commit()


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset_dir)
    user_ratings_file = Path(args.user_ratings_file)
    output_file = Path(args.output_file)

    movies_df, ratings_df = load_movielens(dataset_dir)

    synthetic_user_id = int(ratings_df["userId"].max()) + 1
    local_user_ratings_df = load_user_ratings(user_ratings_file, synthetic_user_id)
    merged_ratings = pd.concat([ratings_df, local_user_ratings_df], ignore_index=True)

    recommendations = build_recommendations(
        movies_df=movies_df,
        ratings_df=merged_ratings,
        target_user_id=synthetic_user_id,
        top_n=args.top_n,
    )

    export_json(recommendations, output_file)
    print(f"Saved {len(recommendations)} recommendations to {output_file}")

    if args.service_account:
        upload_to_firestore(Path(args.service_account), args.user_id, recommendations)
        project_suffix = (
            f" in project {args.firebase_project}" if args.firebase_project else ""
        )
        print(
            f"Uploaded {len(recommendations)} recommendations to Firestore for {args.user_id}{project_suffix}"
        )


if __name__ == "__main__":
    main()
