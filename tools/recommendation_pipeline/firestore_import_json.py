import argparse
import json
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


def parse_args():
    parser = argparse.ArgumentParser(description="Upload JSON records to Firestore.")
    parser.add_argument("--service-account", required=True, help="Path to Firebase service account JSON.")
    parser.add_argument("--collection", required=True, help="Top-level Firestore collection name.")
    parser.add_argument("--json-file", required=True, help="Path to JSON array file.")
    parser.add_argument("--doc-id-field", default="id", help="Field name to use as Firestore document id.")
    parser.add_argument("--subcollection-user-id", help="Optional user id for recommendations/{uid}/items style uploads.")
    parser.add_argument("--subcollection", help="Optional subcollection name.")
    return parser.parse_args()


def main():
    args = parse_args()
    service_account_path = Path(args.service_account)
    json_file = Path(args.json_file)

    app = firebase_admin.initialize_app(
        credentials.Certificate(str(service_account_path))
    )
    db = firestore.client(app=app)

    rows = json.loads(json_file.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("JSON file must contain an array of objects.")

    if args.subcollection_user_id and args.subcollection:
        target = (
            db.collection(args.collection)
            .document(args.subcollection_user_id)
            .collection(args.subcollection)
        )
    else:
        target = db.collection(args.collection)

    batch = db.batch()
    count = 0
    for row in rows:
        doc_id = str(row.get(args.doc_id_field) or row.get("movieId"))
        if not doc_id:
            raise ValueError(f"Missing document id field in row: {row}")
        batch.set(target.document(doc_id), row)
        count += 1

        if count % 400 == 0:
            batch.commit()
            batch = db.batch()

    batch.commit()
    print(f"Uploaded {count} documents to Firestore.")


if __name__ == "__main__":
    main()
