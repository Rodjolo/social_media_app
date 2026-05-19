import argparse
from pathlib import Path

import pandas as pd
import requests


def parse_args():
    parser = argparse.ArgumentParser(
        description="Restore English MovieLens titles directly in PocketBase movies."
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
        "--dataset-dir",
        required=True,
        help="Path to MovieLens dataset folder.",
    )
    parser.add_argument(
        "--collection",
        default="movies",
        help="PocketBase movies collection name.",
    )
    parser.add_argument(
        "--per-page",
        type=int,
        default=200,
        help="Records per PocketBase page.",
    )
    return parser.parse_args()


def clean_title(title: str) -> str:
    if title.endswith(")") and "(" in title:
        return title.rsplit("(", maxsplit=1)[0].strip()
    return title.strip()


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


def fetch_page(base_url: str, headers: dict, collection: str, page: int, per_page: int):
    url = f"{base_url.rstrip('/')}/api/collections/{collection}/records"
    response = requests.get(
        url,
        headers=headers,
        params={"page": page, "perPage": per_page},
        timeout=60,
    )
    response.raise_for_status()
    return response.json()


def update_title(base_url: str, headers: dict, collection: str, record_id: str, title: str):
    url = f"{base_url.rstrip('/')}/api/collections/{collection}/records/{record_id}"
    response = requests.patch(url, headers=headers, json={"title": title}, timeout=60)
    response.raise_for_status()


def main():
    args = parse_args()
    movies_df = pd.read_csv(Path(args.dataset_dir) / "movies.csv")
    title_by_movie_id = {
        str(int(row["movieId"])): clean_title(str(row["title"]))
        for _, row in movies_df.iterrows()
    }

    headers = auth_headers(
        args.base_url,
        args.superuser_email,
        args.superuser_password,
    )

    page = 1
    checked = 0
    updated = 0
    skipped = 0
    while True:
        payload = fetch_page(
            args.base_url,
            headers,
            args.collection,
            page,
            args.per_page,
        )
        items = payload.get("items", [])
        if not items:
            break

        for item in items:
            checked += 1
            movie_id = str(item.get("movieId", ""))
            english_title = title_by_movie_id.get(movie_id)
            if not english_title:
                skipped += 1
                continue
            if item.get("title") == english_title:
                continue

            update_title(args.base_url, headers, args.collection, item["id"], english_title)
            updated += 1

        if page >= int(payload.get("totalPages", page)):
            break
        page += 1

    print(f"Checked: {checked}, updated: {updated}, skipped: {skipped}")


if __name__ == "__main__":
    main()
