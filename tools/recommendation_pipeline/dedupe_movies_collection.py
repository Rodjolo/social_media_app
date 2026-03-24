import argparse
from collections import defaultdict

import requests


def parse_args():
    parser = argparse.ArgumentParser(
        description="Remove duplicate PocketBase movie records by movieId.",
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


def fetch_all_movies(base_url: str, headers: dict):
    url = f"{base_url.rstrip('/')}/api/collections/movies/records"
    page = 1
    items = []

    while True:
        response = requests.get(
            url,
            headers=headers,
            params={"page": page, "perPage": 500},
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


def movie_rank(item: dict):
    poster_url = str(item.get("posterUrl") or "")
    has_local_poster = "/api/files/" in poster_url
    has_any_poster = bool(poster_url)
    has_overview = bool(str(item.get("overview") or "").strip())
    popularity = float(item.get("popularity") or 0)
    updated = str(item.get("updated") or "")
    return (
        1 if has_local_poster else 0,
        1 if has_any_poster else 0,
        1 if has_overview else 0,
        popularity,
        updated,
    )


def delete_record(base_url: str, headers: dict, record_id: str):
    url = f"{base_url.rstrip('/')}/api/collections/movies/records/{record_id}"
    response = requests.delete(url, headers=headers, timeout=60)
    response.raise_for_status()


def main():
    args = parse_args()
    headers = auth_headers(
        args.base_url,
        args.superuser_email,
        args.superuser_password,
    )
    movies = fetch_all_movies(args.base_url, headers)

    groups = defaultdict(list)
    for movie in movies:
        groups[str(movie.get("movieId") or "")].append(movie)

    deleted = 0
    duplicate_groups = 0
    for movie_id, group in groups.items():
        if not movie_id or len(group) < 2:
            continue

        duplicate_groups += 1
        ordered = sorted(group, key=movie_rank, reverse=True)
        keep = ordered[0]["id"]
        for movie in ordered[1:]:
            delete_record(args.base_url, headers, movie["id"])
            deleted += 1
        print(f"movieId={movie_id}: kept {keep}, removed {len(group) - 1}")

    print(f"Duplicate groups: {duplicate_groups}, deleted records: {deleted}")


if __name__ == "__main__":
    main()
