import argparse
import json
from pathlib import Path

import requests


def parse_args():
    parser = argparse.ArgumentParser(description="Export a user's ratings from PocketBase.")
    parser.add_argument("--base-url", required=True, help="PocketBase base URL.")
    parser.add_argument("--superuser-email", required=True, help="PocketBase superuser email.")
    parser.add_argument("--superuser-password", required=True, help="PocketBase superuser password.")
    parser.add_argument("--user-id", required=True, help="Application user id.")
    parser.add_argument("--output-file", required=True, help="Output JSON file path.")
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


def main():
    args = parse_args()
    headers = auth_headers(
        args.base_url,
        args.superuser_email,
        args.superuser_password,
    )

    url = f"{args.base_url.rstrip('/')}/api/collections/ratings/records"
    response = requests.get(
        url,
        headers=headers,
        params={
            "page": 1,
            "perPage": 500,
            "filter": f'uid="{args.user_id}"',
            "sort": "-timestamp",
        },
        timeout=60,
    )
    response.raise_for_status()

    items = response.json().get("items", [])
    movie_id_map = build_movie_id_map(args.base_url, headers)
    rows = [
        {
            "movieId": normalize_movie_id(item.get("movieId"), movie_id_map),
            "rating": float(item.get("rating", 0)),
        }
        for item in items
        if normalize_movie_id(item.get("movieId"), movie_id_map) is not None
    ]

    Path(args.output_file).write_text(
        json.dumps(rows, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Saved {len(rows)} ratings to {args.output_file}")


def build_movie_id_map(base_url: str, headers: dict):
    url = f"{base_url.rstrip('/')}/api/collections/movies/records"
    page = 1
    mapping = {}

    while True:
        response = requests.get(
            url,
            headers=headers,
            params={
                "page": page,
                "perPage": 500,
                "fields": "id,movieId",
            },
            timeout=60,
        )
        response.raise_for_status()
        payload = response.json()
        items = payload.get("items", [])

        for item in items:
            record_id = item.get("id")
            external_movie_id = item.get("movieId")
            if record_id and external_movie_id is not None:
                mapping[str(record_id)] = str(external_movie_id)

        if page >= payload.get("totalPages", 0):
            break
        page += 1

    return mapping


def normalize_movie_id(movie_id_value, movie_id_map):
    if movie_id_value is None:
        return None

    movie_id = str(movie_id_value)
    if movie_id.isdigit():
        return movie_id

    return movie_id_map.get(movie_id)


if __name__ == "__main__":
    main()
