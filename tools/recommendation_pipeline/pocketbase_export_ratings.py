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
    rows = [
        {
            "movieId": item.get("movieId"),
            "rating": float(item.get("rating", 0)),
        }
        for item in items
        if item.get("movieId") is not None
    ]

    Path(args.output_file).write_text(
        json.dumps(rows, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Saved {len(rows)} ratings to {args.output_file}")


if __name__ == "__main__":
    main()
