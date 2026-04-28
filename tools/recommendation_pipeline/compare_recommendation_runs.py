import argparse
import json
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Compare two recommendation JSON files and build a small diploma-friendly report.",
    )
    parser.add_argument("--previous-file", required=True, help="Path to previous recommendations JSON.")
    parser.add_argument("--current-file", required=True, help="Path to current recommendations JSON.")
    parser.add_argument("--output-file", required=True, help="Path to summary JSON report.")
    return parser.parse_args()


def load_items(path: Path):
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def average_score(items):
    if not items:
        return 0.0
    return sum(float(item.get("score", 0)) for item in items) / len(items)


def top_genres(items, limit=3):
    counts = {}
    for item in items:
        for genre in item.get("genres", []):
            normalized = str(genre).strip()
            if not normalized:
                continue
            counts[normalized] = counts.get(normalized, 0) + 1

    sorted_items = sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))
    return [name for name, _ in sorted_items[:limit]]


def build_report(previous_items, current_items):
    previous_ids = [str(item.get("movieId", "")) for item in previous_items]
    current_ids = [str(item.get("movieId", "")) for item in current_items]

    previous_set = set(previous_ids)
    current_set = set(current_ids)

    overlap = sorted(previous_set & current_set)
    added = [movie_id for movie_id in current_ids if movie_id not in previous_set]
    removed = [movie_id for movie_id in previous_ids if movie_id not in current_set]

    return {
        "previousCount": len(previous_items),
        "currentCount": len(current_items),
        "overlapCount": len(overlap),
        "overlapRatio": round(len(overlap) / len(current_items), 4) if current_items else 0,
        "newMovieIds": added,
        "removedMovieIds": removed,
        "previousAverageScore": round(average_score(previous_items), 4),
        "currentAverageScore": round(average_score(current_items), 4),
        "currentTopGenres": top_genres(current_items),
    }


def main():
    args = parse_args()
    previous_file = Path(args.previous_file)
    current_file = Path(args.current_file)
    output_file = Path(args.output_file)

    previous_items = load_items(previous_file)
    current_items = load_items(current_file)
    report = build_report(previous_items, current_items)

    output_file.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Saved comparison report to {output_file}")


if __name__ == "__main__":
    main()
