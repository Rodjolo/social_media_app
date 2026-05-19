import argparse
import json
import math
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
    parser = argparse.ArgumentParser(
        description="Построить рекомендации по фильмам на основе MovieLens.",
    )
    parser.add_argument(
        "--dataset-dir",
        required=True,
        help="Путь к папке с датасетом MovieLens.",
    )
    parser.add_argument("--user-id", required=True, help="UID пользователя приложения.")
    parser.add_argument(
        "--user-ratings-file",
        required=True,
        help="JSON-файл с текущими оценками пользователя.",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Куда сохранить JSON с рекомендациями.",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=10,
        help="Сколько рекомендаций экспортировать.",
    )
    parser.add_argument(
        "--validation-output-file",
        help="Необязательный путь для JSON-отчета по качеству рекомендаций.",
    )
    parser.add_argument(
        "--service-account",
        help="Необязательный Firebase service account JSON для прямой загрузки.",
    )
    parser.add_argument(
        "--firebase-project",
        help="Необязательный id проекта Firebase. Используется только в логах.",
    )
    return parser.parse_args()


def load_movielens(dataset_dir: Path):
    movies = pd.read_csv(dataset_dir / "movies.csv")
    ratings = pd.read_csv(dataset_dir / "ratings.csv")
    return movies, ratings


def load_user_ratings(user_ratings_file: Path, synthetic_user_id: int):
    raw = json.loads(user_ratings_file.read_text(encoding="utf-8"))
    rows = []
    current_timestamp = int(datetime.now(tz=timezone.utc).timestamp())

    for index, entry in enumerate(raw):
        rows.append(
            {
                "userId": synthetic_user_id,
                "movieId": int(entry["movieId"]),
                "rating": float(entry["rating"]),
                "timestamp": current_timestamp + index,
            }
        )

    return pd.DataFrame(rows)


def build_movie_similarity(ratings_df: pd.DataFrame):
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
    return matrix, similarity_df


def rank_candidate_movies(matrix: pd.DataFrame, similarity_df: pd.DataFrame, target_user_id: int):
    target_ratings = matrix.loc[target_user_id]
    rated_movies = target_ratings[target_ratings > 0]

    scores = {}
    for movie_id, rating in rated_movies.items():
        similar_items = similarity_df[movie_id].sort_values(ascending=False)
        for candidate_id, similarity_score in similar_items.items():
            if candidate_id in rated_movies.index:
                continue
            scores.setdefault(candidate_id, 0.0)
            scores[candidate_id] += float(similarity_score) * float(rating)

    return sorted(scores.items(), key=lambda item: item[1], reverse=True)


def build_recommendations(
    movies_df,
    ratings_df,
    target_user_id: int,
    top_n: int,
    app_user_id: str,
):
    matrix, similarity_df = build_movie_similarity(ratings_df)
    ranked = rank_candidate_movies(matrix, similarity_df, target_user_id)[:top_n]

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
                "uid": app_user_id,
                "movieId": str(movie_id),
                "score": round(float(score), 4),
                "reason": "Рекомендовано на основе похожих оценок пользователей в MovieLens.",
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


def compute_validation_report(
    movies_df: pd.DataFrame,
    base_ratings_df: pd.DataFrame,
    local_user_ratings_df: pd.DataFrame,
    synthetic_user_id: int,
    top_n: int,
):
    rating_count = len(local_user_ratings_df.index)
    if rating_count < 5:
        return {
            "status": "insufficient_data",
            "ratingCount": rating_count,
            "message": "Для валидации качества пока недостаточно оценок. Желательно минимум 5.",
        }

    candidate_holdout = local_user_ratings_df[
        local_user_ratings_df["rating"] >= 4.0
    ].copy()
    if candidate_holdout.empty:
        candidate_holdout = local_user_ratings_df.sort_values(
            by=["rating", "timestamp"],
            ascending=[False, False],
        ).head(max(1, min(3, rating_count // 3)))

    holdout_count = max(1, min(5, math.ceil(len(candidate_holdout.index) * 0.3)))
    holdout_df = candidate_holdout.sort_values(
        by=["rating", "timestamp"],
        ascending=[False, False],
    ).head(holdout_count)
    training_df = local_user_ratings_df.drop(index=holdout_df.index)

    if training_df.empty:
        return {
            "status": "insufficient_data",
            "ratingCount": rating_count,
            "message": "После выделения контрольных оценок не осталось данных для обучения.",
        }

    merged_ratings = pd.concat([base_ratings_df, training_df], ignore_index=True)
    matrix, similarity_df = build_movie_similarity(merged_ratings)
    ranked = rank_candidate_movies(matrix, similarity_df, synthetic_user_id)
    ranked_ids = [int(movie_id) for movie_id, _ in ranked]
    recommended_ids = ranked_ids[:top_n]

    actual_ids = [int(movie_id) for movie_id in holdout_df["movieId"].tolist()]
    actual_relevance = {
        int(row.movieId): float(row.rating)
        for row in holdout_df.itertuples(index=False)
    }
    precision_at_k, recall_at_k, hit_rate_at_k, ndcg_at_k, hit_ids = hit_metrics(
        recommended_ids,
        actual_ids,
        actual_relevance,
        top_n,
    )
    _, recall_at_50, hit_rate_at_50, _, hit_ids_50 = hit_metrics(
        ranked_ids,
        actual_ids,
        actual_relevance,
        50,
    )
    _, recall_at_100, hit_rate_at_100, _, hit_ids_100 = hit_metrics(
        ranked_ids,
        actual_ids,
        actual_relevance,
        100,
    )

    rank_by_movie_id = {
        movie_id: index + 1
        for index, movie_id in enumerate(ranked_ids)
    }
    hidden_ranks = {
        str(movie_id): rank_by_movie_id.get(movie_id)
        for movie_id in actual_ids
    }
    ranks = [
        rank
        for rank in hidden_ranks.values()
        if rank is not None
    ]

    candidate_count = max(1, len(ranked_ids))
    best_rank = min(ranks) if ranks else None
    mean_rank = sum(ranks) / len(ranks) if ranks else None
    mean_percentile = (
        sum(1 - ((rank - 1) / candidate_count) for rank in ranks) / len(ranks)
        if ranks
        else 0.0
    )

    holdout_genres = set()
    for movie_id in actual_ids:
        holdout_genres.update(movie_genres(movies_df, movie_id))

    recommended_genres = set()
    for movie_id in recommended_ids:
        recommended_genres.update(movie_genres(movies_df, movie_id))

    training_liked_ids = [
        int(row.movieId)
        for row in training_df[training_df["rating"] >= 4.0].itertuples(index=False)
    ]
    profile_genres = set()
    for movie_id in training_liked_ids:
        profile_genres.update(movie_genres(movies_df, movie_id))

    holdout_genre_overlap = genre_jaccard(holdout_genres, recommended_genres)
    profile_genre_overlap = genre_jaccard(profile_genres, recommended_genres)

    movie_titles = {}
    for movie_id in actual_ids:
        row = movies_df[movies_df["movieId"] == movie_id]
        if not row.empty:
            movie_titles[str(movie_id)] = clean_title(str(row.iloc[0]["title"]))

    if recall_at_k >= 0.3 or recall_at_50 >= 0.5:
        quality_label = "хорошее"
    elif (
        recall_at_100 > 0
        or mean_percentile >= 0.8
        or holdout_genre_overlap >= 0.35
        or profile_genre_overlap >= 0.45
    ):
        quality_label = "базовое"
    elif holdout_genre_overlap >= 0.2 or profile_genre_overlap >= 0.3:
        quality_label = "жанрово близкое"
    else:
        quality_label = "слабое"

    return {
        "status": "ok",
        "ratingCount": rating_count,
        "holdoutCount": len(actual_ids),
        "evaluatedTopN": len(recommended_ids),
        "precisionAtK": round(precision_at_k, 4),
        "recallAtK": round(recall_at_k, 4),
        "hitRateAtK": round(hit_rate_at_k, 4),
        "ndcgAtK": round(ndcg_at_k, 4),
        "recallAt50": round(recall_at_50, 4),
        "hitRateAt50": round(hit_rate_at_50, 4),
        "recallAt100": round(recall_at_100, 4),
        "hitRateAt100": round(hit_rate_at_100, 4),
        "bestHiddenMovieRank": best_rank,
        "meanHiddenMovieRank": round(mean_rank, 2) if mean_rank is not None else None,
        "meanHiddenMoviePercentile": round(mean_percentile, 4),
        "holdoutGenreOverlap": round(holdout_genre_overlap, 4),
        "profileGenreOverlap": round(profile_genre_overlap, 4),
        "candidateCount": len(ranked_ids),
        "hiddenMovieRanks": hidden_ranks,
        "heldOutMovieIds": [str(movie_id) for movie_id in actual_ids],
        "hitMovieIds": [str(movie_id) for movie_id in hit_ids],
        "hitMovieIdsAt50": [str(movie_id) for movie_id in hit_ids_50],
        "hitMovieIdsAt100": [str(movie_id) for movie_id in hit_ids_100],
        "heldOutTitles": [movie_titles.get(str(movie_id), str(movie_id)) for movie_id in actual_ids],
        "hitTitles": [movie_titles.get(str(movie_id), str(movie_id)) for movie_id in hit_ids],
        "hitTitlesAt50": [movie_titles.get(str(movie_id), str(movie_id)) for movie_id in hit_ids_50],
        "hitTitlesAt100": [movie_titles.get(str(movie_id), str(movie_id)) for movie_id in hit_ids_100],
        "qualityLabel": quality_label,
        "message": (
            "Валидация выполнена по holdout-сценарию: часть высоких оценок скрывается, "
            "а алгоритм пытается вернуть эти фильмы в рекомендации. Top-10 считается строгой "
            "проверкой, поэтому дополнительно показываются попадания в top-50/top-100, ранги и жанровая близость."
        ),
    }


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


def movie_genres(movies_df: pd.DataFrame, movie_id: int):
    row = movies_df[movies_df["movieId"] == movie_id]
    if row.empty:
        return set()
    return set(split_genres(row.iloc[0].get("genres", "")))


def genre_jaccard(left: set[str], right: set[str]):
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)


def hit_metrics(recommended_ids, actual_ids, actual_relevance, k: int):
    top_ids = recommended_ids[:k]
    hit_ids = [movie_id for movie_id in top_ids if movie_id in actual_relevance]
    precision = len(hit_ids) / len(top_ids) if top_ids else 0.0
    recall = len(hit_ids) / len(actual_ids) if actual_ids else 0.0
    hit_rate = 1.0 if hit_ids else 0.0

    dcg = 0.0
    for index, movie_id in enumerate(top_ids, start=1):
        relevance = actual_relevance.get(movie_id, 0.0)
        if relevance <= 0:
            continue
        dcg += (2**relevance - 1) / math.log2(index + 1)

    ideal_relevances = sorted(actual_relevance.values(), reverse=True)[: len(top_ids)]
    idcg = 0.0
    for index, relevance in enumerate(ideal_relevances, start=1):
        idcg += (2**relevance - 1) / math.log2(index + 1)

    ndcg = dcg / idcg if idcg > 0 else 0.0
    return precision, recall, hit_rate, ndcg, hit_ids


def export_json(payload, output_file: Path):
    output_file.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
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

    collection = db.collection("recommendations").document(user_id).collection("items")

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
        app_user_id=args.user_id,
    )

    export_json(recommendations, output_file)
    print(f"Saved {len(recommendations)} recommendations to {output_file}")

    if args.validation_output_file:
        validation_report = compute_validation_report(
            movies_df=movies_df,
            base_ratings_df=ratings_df,
            local_user_ratings_df=local_user_ratings_df,
            synthetic_user_id=synthetic_user_id,
            top_n=args.top_n,
        )
        export_json(validation_report, Path(args.validation_output_file))
        print(f"Saved validation report to {args.validation_output_file}")

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
