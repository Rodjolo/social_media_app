import argparse
import json
from pathlib import Path

import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(description="Export MovieLens movies to app-ready JSON.")
    parser.add_argument("--dataset-dir", required=True, help="Path to MovieLens dataset folder.")
    parser.add_argument("--output-file", required=True, help="Output JSON file path.")
    parser.add_argument("--limit", type=int, default=200, help="Maximum number of movies.")
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


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset_dir)
    output_file = Path(args.output_file)

    movies_df = pd.read_csv(dataset_dir / "movies.csv").head(args.limit)

    records = []
    for _, row in movies_df.iterrows():
        title = str(row["title"])
        records.append(
            {
                "id": str(row["movieId"]),
                "title": clean_title(title),
                "genres": split_genres(row.get("genres", "")),
                "posterUrl": "",
                "overview": "",
                "year": extract_year(title),
                "popularity": 0.0,
            }
        )

    output_file.write_text(
        json.dumps(records, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Saved {len(records)} movies to {output_file}")


if __name__ == "__main__":
    main()
