import argparse
import json
import os
import time
from pathlib import Path

import pandas as pd
import requests


def parse_args():
    parser = argparse.ArgumentParser(
        description="Enrich MovieLens movies with TMDB metadata."
    )
    parser.add_argument(
        "--input-file",
        help=(
            "Optional existing movies JSON to enrich in place. "
            "If omitted, movies.csv is used as the source catalog."
        ),
    )
    parser.add_argument(
        "--dataset-dir",
        required=True,
        help="Path to MovieLens dataset folder.",
    )
    parser.add_argument(
        "--tmdb-token",
        default=os.getenv("TMDB_BEARER_TOKEN", ""),
        help="TMDB v4 bearer token. Can also be provided via TMDB_BEARER_TOKEN.",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Output JSON file path.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=200,
        help="Maximum number of movies to enrich.",
    )
    parser.add_argument(
        "--delay-ms",
        type=int,
        default=150,
        help="Delay between TMDB requests in milliseconds.",
    )
    parser.add_argument(
        "--language",
        default="en-US",
        help="TMDB response language, for example en-US or ru-RU.",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=25,
        help="How often to print progress updates. Set 0 to disable.",
    )
    return parser.parse_args()


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


def tmdb_headers(token: str):
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }


def fetch_image_base_url(headers: dict):
    response = requests.get(
        "https://api.themoviedb.org/3/configuration",
        headers=headers,
        timeout=60,
    )
    response.raise_for_status()
    payload = response.json()
    secure_base_url = payload["images"]["secure_base_url"]
    poster_sizes = payload["images"]["poster_sizes"]
    preferred_size = "w500" if "w500" in poster_sizes else poster_sizes[-1]
    return f"{secure_base_url}{preferred_size}"


def fetch_tmdb_movie(tmdb_id: str, headers: dict, language: str):
    response = requests.get(
        f"https://api.themoviedb.org/3/movie/{tmdb_id}",
        headers=headers,
        params={"language": language},
        timeout=60,
    )
    if response.status_code == 404:
        return None
    response.raise_for_status()
    return response.json()


def load_source_records(dataset_dir: Path, input_file: Path | None, limit: int):
    if input_file:
        raw_records = json.loads(input_file.read_text(encoding="utf-8"))
        return [
            {
                "movieId": str(record.get("movieId", "")),
                "title": str(record.get("title", "")).strip(),
                "genres": list(record.get("genres", [])),
                "posterUrl": str(record.get("posterUrl", "")).strip(),
                "overview": str(record.get("overview", "")).strip(),
                "year": int(record.get("year", 0) or 0),
                "popularity": float(record.get("popularity", 0) or 0),
            }
            for record in raw_records[:limit]
        ]

    movies_df = pd.read_csv(dataset_dir / "movies.csv").head(limit)
    records = []
    for _, row in movies_df.iterrows():
        title = str(row["title"])
        records.append(
            {
                "movieId": str(row["movieId"]),
                "title": clean_title(title),
                "genres": split_genres(row.get("genres", "")),
                "posterUrl": "",
                "overview": "",
                "year": extract_year(title),
                "popularity": 0.0,
            }
        )
    return records


def extract_tmdb_year(release_date: str, fallback_year: int):
    if release_date and len(release_date) >= 4 and release_date[:4].isdigit():
        return int(release_date[:4])
    return fallback_year


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset_dir)
    input_file = Path(args.input_file) if args.input_file else None
    output_file = Path(args.output_file)
    if not args.tmdb_token:
        raise ValueError(
            "TMDB token is required. Pass --tmdb-token or set TMDB_BEARER_TOKEN."
        )

    links_df = pd.read_csv(dataset_dir / "links.csv")
    links_map = {
        str(int(row["movieId"])): str(int(row["tmdbId"]))
        for _, row in links_df.iterrows()
        if pd.notna(row.get("tmdbId"))
    }
    source_records = load_source_records(dataset_dir, input_file, args.limit)

    headers = tmdb_headers(args.tmdb_token)
    poster_base_url = fetch_image_base_url(headers)

    records = []
    enriched_count = 0
    missing_tmdb_count = 0
    request_error_count = 0
    started_at = time.perf_counter()
    total_records = len(source_records)

    for index, record in enumerate(source_records, start=1):
        movie_id = record["movieId"]
        title = record["title"]
        tmdb_id = links_map.get(movie_id)
        try:
            tmdb_data = (
                fetch_tmdb_movie(tmdb_id, headers, args.language) if tmdb_id else None
            )
        except requests.RequestException as error:
            print(f"Skipping movieId={movie_id}: TMDB request failed: {error}")
            tmdb_data = None
            request_error_count += 1

        poster_path = tmdb_data.get("poster_path") if tmdb_data else None
        overview = (
            str(tmdb_data.get("overview", "")).strip()
            if tmdb_data
            else record["overview"]
        )
        popularity = (
            float(tmdb_data.get("popularity", 0) or 0)
            if tmdb_data
            else record["popularity"]
        )
        genres = (
            [genre["name"] for genre in tmdb_data.get("genres", [])]
            if tmdb_data and tmdb_data.get("genres")
            else record["genres"]
        )
        release_date = tmdb_data.get("release_date", "") if tmdb_data else ""
        year = extract_tmdb_year(release_date, record["year"])

        if tmdb_data:
            enriched_count += 1
        else:
            missing_tmdb_count += 1

        records.append(
            {
                "movieId": movie_id,
                "title": clean_title(title),
                "genres": genres,
                "posterUrl": (
                    f"{poster_base_url}{poster_path}"
                    if poster_path
                    else record["posterUrl"]
                ),
                "overview": overview,
                "year": year,
                "popularity": popularity,
            }
        )

        if args.progress_every > 0 and (
            index == 1
            or index % args.progress_every == 0
            or index == total_records
        ):
            elapsed_seconds = time.perf_counter() - started_at
            print(
                f"[{index}/{total_records}] processed "
                f"(matched: {enriched_count}, fallback: {missing_tmdb_count}, "
                f"request errors: {request_error_count}, elapsed: {elapsed_seconds:.1f}s)"
            )

        time.sleep(args.delay_ms / 1000)

    output_file.write_text(
        json.dumps(records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    elapsed_seconds = time.perf_counter() - started_at
    print(
        f"Saved {len(records)} enriched movies to {output_file} "
        f"(TMDB matched: {enriched_count}, fallback-only: {missing_tmdb_count}, "
        f"request errors: {request_error_count}, elapsed: {elapsed_seconds:.1f}s)"
    )


if __name__ == "__main__":
    main()
