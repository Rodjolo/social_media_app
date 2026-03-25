import argparse

import requests


def parse_args():
    parser = argparse.ArgumentParser(
        description="Copy movie metadata into PocketBase recommendations.",
    )
    parser.add_argument("--base-url", required=True, help="PocketBase base URL.")
    parser.add_argument(
        "--superuser-email",
        required=True,
        help="PocketBase superuser email.",
    )
    parser.add_argument(
        "--superuser-password",
        required=True,
        help="PocketBase superuser password.",
    )
    parser.add_argument(
        "--user-id",
        help="Optional application user id. If omitted, all recommendations are synced.",
    )
    return parser.parse_args()


def auth_headers(base_url: str, email: str, password: str):
    url = f"{base_url.rstrip('/')}/api/collections/_superusers/auth-with-password"
    response = requests.post(
        url,
        json={"identity": email, "password": password},
        timeout=60,
    )
    response.raise_for_status()
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}


def fetch_all_records(base_url: str, headers: dict, collection: str, filter_expr: str | None = None):
    url = f"{base_url.rstrip('/')}/api/collections/{collection}/records"
    page = 1
    items = []

    while True:
        params = {"page": page, "perPage": 500}
        if filter_expr:
            params["filter"] = filter_expr

        response = requests.get(
            url,
            headers=headers,
            params=params,
            timeout=60,
        )
        response.raise_for_status()
        payload = response.json()
        batch = payload.get("items", [])
        if not batch:
            break
        items.extend(batch)
        if page >= payload.get("totalPages", 0):
            break
        page += 1

    return items


def update_recommendation(base_url: str, headers: dict, record_id: str, payload: dict):
    url = f"{base_url.rstrip('/')}/api/collections/recommendations/records/{record_id}"
    response = requests.patch(
        url,
        headers=headers,
        json=payload,
        timeout=60,
    )
    response.raise_for_status()


def main():
    args = parse_args()
    headers = auth_headers(
        args.base_url,
        args.superuser_email,
        args.superuser_password,
    )

    movies = fetch_all_records(args.base_url, headers, "movies")
    movies_by_id = {
        str(movie.get("movieId") or ""): movie
        for movie in movies
        if movie.get("movieId") is not None
    }

    rec_filter = f'uid="{args.user_id}"' if args.user_id else None
    recommendations = fetch_all_records(
        args.base_url,
        headers,
        "recommendations",
        filter_expr=rec_filter,
    )

    updated = 0
    skipped = 0
    for recommendation in recommendations:
        movie_id = str(recommendation.get("movieId") or "")
        movie = movies_by_id.get(movie_id)
        if not movie:
            skipped += 1
            continue

        payload = {
            "title": movie.get("title") or recommendation.get("title") or "",
            "genres": movie.get("genres") or recommendation.get("genres") or [],
            "posterUrl": movie.get("posterUrl") or recommendation.get("posterUrl") or "",
            "overview": movie.get("overview") or recommendation.get("overview") or "",
            "year": movie.get("year") or recommendation.get("year") or 0,
            "popularity": movie.get("popularity") or recommendation.get("popularity") or 0,
        }
        update_recommendation(args.base_url, headers, recommendation["id"], payload)
        updated += 1

    print(f"Updated recommendations: {updated}, skipped: {skipped}")


if __name__ == "__main__":
    main()
