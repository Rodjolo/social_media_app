import argparse
import json
from pathlib import Path

import requests


def parse_args():
    parser = argparse.ArgumentParser(description="Upload JSON records to PocketBase.")
    parser.add_argument("--base-url", required=True, help="PocketBase base URL.")
    parser.add_argument("--superuser-email", required=True, help="PocketBase superuser email.")
    parser.add_argument("--superuser-password", required=True, help="PocketBase superuser password.")
    parser.add_argument("--collection", required=True, help="PocketBase collection name.")
    parser.add_argument("--json-file", required=True, help="Path to JSON array file.")
    parser.add_argument(
        "--lookup-template",
        help='Optional PocketBase filter template, e.g. movieId="{movieId}" or uid="{uid}" && movieId="{movieId}"',
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


def build_filter(template: str, row: dict) -> str:
    result = template
    for key, value in row.items():
        raw_value = str(value).replace('"', '\\"')

        quoted_placeholder = f'"{{{key}}}"'
        if quoted_placeholder in result:
            result = result.replace(quoted_placeholder, f'"{raw_value}"')
        else:
            result = result.replace(f"{{{key}}}", raw_value)
    return result


def find_existing_record(base_url: str, headers: dict, collection: str, lookup_filter: str):
    url = f"{base_url.rstrip('/')}/api/collections/{collection}/records"
    response = requests.get(
        url,
        headers=headers,
        params={"page": 1, "perPage": 1, "filter": lookup_filter},
        timeout=60,
    )
    response.raise_for_status()
    items = response.json().get("items", [])
    return items[0] if items else None


def create_record(base_url: str, headers: dict, collection: str, row: dict):
    url = f"{base_url.rstrip('/')}/api/collections/{collection}/records"
    response = requests.post(url, headers=headers, json=row, timeout=60)
    response.raise_for_status()


def update_record(base_url: str, headers: dict, collection: str, record_id: str, row: dict):
    url = f"{base_url.rstrip('/')}/api/collections/{collection}/records/{record_id}"
    response = requests.patch(url, headers=headers, json=row, timeout=60)
    response.raise_for_status()


def main():
    args = parse_args()
    rows = json.loads(Path(args.json_file).read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("JSON file must contain an array of objects.")

    headers = auth_headers(
        args.base_url,
        args.superuser_email,
        args.superuser_password,
    )

    created = 0
    updated = 0
    for row in rows:
      if args.lookup_template:
          lookup_filter = build_filter(args.lookup_template, row)
          existing = find_existing_record(
              args.base_url,
              headers,
              args.collection,
              lookup_filter,
          )
          if existing:
              update_record(
                  args.base_url,
                  headers,
                  args.collection,
                  existing["id"],
                  row,
              )
              updated += 1
              continue

      create_record(args.base_url, headers, args.collection, row)
      created += 1

    print(f"Created: {created}, updated: {updated}")


if __name__ == "__main__":
    main()
