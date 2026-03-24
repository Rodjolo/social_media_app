import argparse
import mimetypes
import os
from pathlib import Path
from urllib.parse import urlparse

import requests


def parse_args():
    parser = argparse.ArgumentParser(
        description="Mirror remote movie posters into PocketBase media storage.",
    )
    parser.add_argument("--base-url", required=True, help="PocketBase base URL.")
    parser.add_argument(
        "--public-base-url",
        default=os.getenv("POCKETBASE_PUBLIC_URL", ""),
        help=(
            "Public PocketBase URL that the Flutter app can reach. "
            "Defaults to --base-url when omitted."
        ),
    )
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
        "--limit",
        type=int,
        default=200,
        help="Maximum number of movies to process.",
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


def iter_movies(base_url: str, headers: dict, limit: int):
    url = f"{base_url.rstrip('/')}/api/collections/movies/records"
    page = 1
    seen = 0

    while seen < limit:
        response = requests.get(
            url,
            headers=headers,
            params={
                "page": page,
                "perPage": min(100, limit - seen),
                "sort": "-popularity",
            },
            timeout=60,
        )
        response.raise_for_status()
        payload = response.json()
        items = payload.get("items", [])
        if not items:
            break

        for item in items:
            yield item
            seen += 1
            if seen >= limit:
                break

        if page >= payload.get("totalPages", 0):
            break
        page += 1


def find_existing_media(base_url: str, headers: dict, movie_id: str):
    url = f"{base_url.rstrip('/')}/api/collections/media/records"
    response = requests.get(
        url,
        headers=headers,
        params={
            "page": 1,
            "perPage": 1,
            "filter": f'ownerId="{movie_id}" && category="movie_poster"',
        },
        timeout=60,
    )
    response.raise_for_status()
    items = response.json().get("items", [])
    return items[0] if items else None


def build_file_url(base_url: str, record: dict, filename: str):
    collection_id_or_name = record.get("collectionId") or record.get("collectionName")
    return (
        f"{base_url.rstrip('/')}/api/files/"
        f"{collection_id_or_name}/{record['id']}/{filename}"
    )


def extract_filename(file_field) -> str:
    if isinstance(file_field, list):
        return str(file_field[0]) if file_field else ""
    if isinstance(file_field, str):
        return file_field
    return ""


def infer_filename(movie_id: str, source_url: str, content_type: str | None):
    parsed = urlparse(source_url)
    extension = Path(parsed.path).suffix
    if not extension:
        extension = mimetypes.guess_extension(content_type or "") or ".jpg"
    if not extension.startswith("."):
        extension = f".{extension}"
    return f"movie_{movie_id}{extension}"


def upload_media_record(
    base_url: str,
    headers: dict,
    movie_id: str,
    poster_url: str,
    existing_record: dict | None,
):
    image_response = requests.get(poster_url, timeout=60)
    image_response.raise_for_status()
    filename = infer_filename(
        movie_id,
        poster_url,
        image_response.headers.get("content-type"),
    )

    data = {
        "ownerId": movie_id,
        "category": "movie_poster",
    }
    files = {
        "file": (
            filename,
            image_response.content,
            image_response.headers.get("content-type", "image/jpeg"),
        ),
    }

    if existing_record:
        url = f"{base_url.rstrip('/')}/api/collections/media/records/{existing_record['id']}"
        response = requests.patch(url, headers=headers, data=data, files=files, timeout=60)
    else:
        url = f"{base_url.rstrip('/')}/api/collections/media/records"
        response = requests.post(url, headers=headers, data=data, files=files, timeout=60)

    response.raise_for_status()
    return response.json()


def update_movie_poster_url(base_url: str, headers: dict, movie_record_id: str, poster_url: str):
    url = f"{base_url.rstrip('/')}/api/collections/movies/records/{movie_record_id}"
    response = requests.patch(
        url,
        headers=headers,
        json={"posterUrl": poster_url},
        timeout=60,
    )
    response.raise_for_status()


def is_local_pocketbase_url(base_url: str, url: str):
    normalized_base = base_url.rstrip("/")
    return url.startswith(normalized_base) and "/api/files/" in url


def has_plausible_filename(url: str) -> bool:
    parsed = urlparse(url)
    filename = Path(parsed.path).name
    return len(filename) > 4 and "." in filename


def main():
    args = parse_args()
    public_base_url = (args.public_base_url or args.base_url).rstrip("/")
    headers = auth_headers(
        args.base_url,
        args.superuser_email,
        args.superuser_password,
    )

    mirrored = 0
    skipped = 0

    for movie in iter_movies(args.base_url, headers, args.limit):
        poster_url = str(movie.get("posterUrl") or "").strip()
        movie_id = str(movie.get("movieId") or "")
        existing_media = find_existing_media(args.base_url, headers, movie_id)

        if not movie_id:
            skipped += 1
            continue

        if existing_media:
            filename = extract_filename(existing_media.get("file"))
            if filename:
                desired_poster_url = build_file_url(
                    public_base_url,
                    existing_media,
                    filename,
                )
                if poster_url != desired_poster_url:
                    update_movie_poster_url(
                        args.base_url,
                        headers,
                        movie["id"],
                        desired_poster_url,
                    )
                    mirrored += 1
                else:
                    skipped += 1
                continue

        if not poster_url:
            skipped += 1
            continue

        if (
            is_local_pocketbase_url(public_base_url, poster_url)
            and has_plausible_filename(poster_url)
        ):
            skipped += 1
            continue

        try:
            media_record = upload_media_record(
                args.base_url,
                headers,
                movie_id,
                poster_url,
                existing_media,
            )
            filename = extract_filename(media_record.get("file"))
            if not filename:
                skipped += 1
                continue

            local_poster_url = build_file_url(public_base_url, media_record, filename)
            update_movie_poster_url(
                args.base_url,
                headers,
                movie["id"],
                local_poster_url,
            )
            mirrored += 1
        except requests.RequestException as error:
            print(f"Skipping movieId={movie_id}: failed to mirror poster: {error}")
            skipped += 1

    print(f"Mirrored posters: {mirrored}, skipped: {skipped}")


if __name__ == "__main__":
    main()
