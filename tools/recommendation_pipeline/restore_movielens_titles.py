import argparse
import json
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Restore English MovieLens titles in an enriched movies JSON file."
    )
    parser.add_argument(
        "--dataset-dir",
        required=True,
        help="Path to MovieLens dataset folder.",
    )
    parser.add_argument(
        "--input-file",
        required=True,
        help="Movies JSON file with existing metadata.",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Where to save movies JSON with restored English titles.",
    )
    return parser.parse_args()


def clean_title(title: str) -> str:
    if title.endswith(")") and "(" in title:
        return title.rsplit("(", maxsplit=1)[0].strip()
    return title.strip()


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset_dir)
    input_file = Path(args.input_file)
    output_file = Path(args.output_file)

    movies_df = pd.read_csv(dataset_dir / "movies.csv")
    title_by_movie_id = {
        str(int(row["movieId"])): clean_title(str(row["title"]))
        for _, row in movies_df.iterrows()
    }

    records = json.loads(input_file.read_text(encoding="utf-8-sig"))
    changed_count = 0
    for record in records:
        movie_id = str(record.get("movieId", ""))
        english_title = title_by_movie_id.get(movie_id)
        if english_title and record.get("title") != english_title:
            record["title"] = english_title
            changed_count += 1

    output_file.write_text(
        json.dumps(records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        f"Saved {len(records)} movies to {output_file}. "
        f"Restored English titles: {changed_count}."
    )


if __name__ == "__main__":
    main()
