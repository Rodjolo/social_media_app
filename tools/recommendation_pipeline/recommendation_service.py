import argparse
import json
import subprocess
import threading
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import requests


def parse_args():
    parser = argparse.ArgumentParser(
        description="Локальный HTTP-сервис для пересчета рекомендаций.",
    )
    parser.add_argument("--host", default="0.0.0.0", help="Адрес привязки.")
    parser.add_argument("--port", type=int, default=8091, help="Порт сервиса.")
    parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8090",
        help="URL PocketBase.",
    )
    parser.add_argument(
        "--superuser-email",
        required=True,
        help="Email superuser в PocketBase.",
    )
    parser.add_argument(
        "--superuser-password",
        required=True,
        help="Пароль superuser в PocketBase.",
    )
    parser.add_argument(
        "--dataset-dir",
        default="./assets/db/ml-latest-small",
        help="Путь к MovieLens.",
    )
    parser.add_argument(
        "--working-dir",
        default="./assets/db/generated",
        help="Папка для промежуточных файлов и статусов.",
    )
    parser.add_argument(
        "--top-n",
        type=int,
        default=10,
        help="Сколько рекомендаций строить.",
    )
    parser.add_argument(
        "--minimum-ratings",
        type=int,
        default=5,
        help="Минимальный порог оценок для предупреждения.",
    )
    return parser.parse_args()


class RecommendationJobStore:
    def __init__(self, working_dir: Path):
        self.working_dir = working_dir
        self.working_dir.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._jobs: dict[str, dict[str, Any]] = {}

    def status_file(self, user_id: str) -> Path:
        safe_user_id = "".join(
            char if char.isalnum() or char in {"_", "-"} else "_"
            for char in user_id
        )
        return self.working_dir / f"service_status_{safe_user_id}.json"

    def set_status(self, user_id: str, payload: dict[str, Any]):
        with self._lock:
            self._jobs[user_id] = payload
            self.status_file(user_id).write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )

    def get_status(self, user_id: str):
        with self._lock:
            if user_id in self._jobs:
                return self._jobs[user_id]

        path = self.status_file(user_id)
        if path.exists():
            return json.loads(path.read_text(encoding="utf-8"))
        return None


def utc_now_iso():
    return datetime.now(tz=timezone.utc).isoformat()


def load_report(working_dir: Path, user_id: str):
    safe_user_id = "".join(
        char if char.isalnum() or char in {"_", "-"} else "_"
        for char in user_id
    )
    path = working_dir / f"recommendation_report_{safe_user_id}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def verify_pocketbase_credentials(base_url: str, email: str, password: str):
    response = requests.post(
        f"{base_url.rstrip('/')}/api/collections/_superusers/auth-with-password",
        json={"identity": email, "password": password},
        timeout=30,
    )
    response.raise_for_status()


def clean_command_output(value: str):
    lines = [line.strip() for line in value.splitlines() if line.strip()]
    noise_prefixes = (
        "at ",
        "строка:",
        "CategoryInfo",
        "FullyQualifiedErrorId",
        "+ CategoryInfo",
        "+ FullyQualifiedErrorId",
        "+",
    )
    return [line for line in lines if not line.startswith(noise_prefixes)]


def build_failure_message(stdout: str, stderr: str):
    stderr_lines = clean_command_output(stderr)
    stdout_lines = clean_command_output(stdout)

    if stderr_lines:
        return stderr_lines[0], " | ".join(stderr_lines[:4])
    if stdout_lines:
        return stdout_lines[-1], " | ".join(stdout_lines[-4:])
    return "Пересчет завершился с ошибкой", ""


def run_rebuild(args, store: RecommendationJobStore, user_id: str, top_n: int):
    store.set_status(
        user_id,
        {
            "userId": user_id,
            "state": "running",
            "isRunning": True,
            "message": "Пересчет рекомендаций выполняется",
            "details": "",
            "startedAt": utc_now_iso(),
            "finishedAt": None,
            "exitCode": None,
            "report": None,
        },
    )

    command = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(Path("tools/recommendation_pipeline/rebuild_recommendations.ps1")),
        "-BaseUrl",
        args.base_url,
        "-SuperuserEmail",
        args.superuser_email,
        "-SuperuserPassword",
        args.superuser_password,
        "-UserId",
        user_id,
        "-DatasetDir",
        args.dataset_dir,
        "-WorkingDir",
        args.working_dir,
        "-TopN",
        str(top_n),
        "-MinimumRatings",
        str(args.minimum_ratings),
    ]

    result = subprocess.run(
        command,
        cwd=Path(__file__).resolve().parents[2],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )

    report = load_report(Path(args.working_dir), user_id)
    stdout = (result.stdout or "").strip()
    stderr = (result.stderr or "").strip()

    if result.returncode == 0:
        lines = clean_command_output(stdout)
        message = lines[-1] if lines else "Пересчет завершен"
        details = " | ".join(lines[-4:])
    else:
        message, details = build_failure_message(stdout, stderr)

    previous_status = store.get_status(user_id) or {}
    store.set_status(
        user_id,
        {
            "userId": user_id,
            "state": "completed" if result.returncode == 0 else "failed",
            "isRunning": False,
            "message": message,
            "details": details,
            "startedAt": previous_status.get("startedAt"),
            "finishedAt": utc_now_iso(),
            "exitCode": result.returncode,
            "report": report,
        },
    )


class RecommendationServiceHandler(BaseHTTPRequestHandler):
    service_args = None
    store = None

    def _send_json(self, status_code: int, payload: dict[str, Any]):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        return

    def do_GET(self):
        if self.path.startswith("/health"):
            self._send_json(HTTPStatus.OK, {"ok": True})
            return

        if self.path.startswith("/status"):
            user_id = ""
            if "?" in self.path:
                query = self.path.split("?", maxsplit=1)[1]
                params = {}
                for part in query.split("&"):
                    if "=" in part:
                        key, value = part.split("=", maxsplit=1)
                        params[key] = value
                user_id = params.get("userId", "")

            if not user_id:
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"message": "userId query parameter is required"},
                )
                return

            status = self.store.get_status(user_id)
            if status is None:
                self._send_json(
                    HTTPStatus.NOT_FOUND,
                    {"message": "No rebuild status for this user yet"},
                )
                return

            self._send_json(HTTPStatus.OK, status)
            return

        self._send_json(HTTPStatus.NOT_FOUND, {"message": "Not found"})

    def do_POST(self):
        if self.path != "/rebuild":
            self._send_json(HTTPStatus.NOT_FOUND, {"message": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length) if content_length else b"{}"
        payload = json.loads(raw_body.decode("utf-8"))
        user_id = str(payload.get("userId", "")).strip()
        top_n = int(payload.get("topN", self.service_args.top_n))

        if not user_id:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"message": "userId is required"},
            )
            return

        existing = self.store.get_status(user_id)
        if existing and existing.get("isRunning") is True:
            self._send_json(
                HTTPStatus.CONFLICT,
                {"message": "Rebuild is already running for this user"},
            )
            return

        thread = threading.Thread(
            target=run_rebuild,
            args=(self.service_args, self.store, user_id, top_n),
            daemon=True,
        )
        thread.start()

        self._send_json(
            HTTPStatus.ACCEPTED,
            {
                "message": "Rebuild started",
                "userId": user_id,
                "topN": top_n,
            },
        )


def main():
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    working_dir = (repo_root / args.working_dir).resolve()
    args.dataset_dir = str((repo_root / args.dataset_dir).resolve())
    args.working_dir = str(working_dir)

    try:
        verify_pocketbase_credentials(
            args.base_url,
            args.superuser_email,
            args.superuser_password,
        )
    except Exception as error:
        raise SystemExit(f"PocketBase auth check failed: {error}") from error

    store = RecommendationJobStore(working_dir)
    RecommendationServiceHandler.service_args = args
    RecommendationServiceHandler.store = store

    server = ThreadingHTTPServer(
        (args.host, args.port),
        RecommendationServiceHandler,
    )
    print(
        f"Recommendation service listening on http://{args.host}:{args.port} "
        f"for PocketBase {args.base_url}"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
