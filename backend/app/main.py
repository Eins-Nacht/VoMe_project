import asyncio
import json
import os
import shutil
import sqlite3
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from faster_whisper import WhisperModel
from openai import OpenAI

DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
JOB_DIR = DATA_DIR / "jobs"
DB_PATH = DATA_DIR / "jobs.db"
MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(25 * 1024 * 1024)))
ALLOWED_SUFFIXES = {".mp3", ".m4a", ".wav"}


def connect() -> sqlite3.Connection:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def initialise_store() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    JOB_DIR.mkdir(parents=True, exist_ok=True)
    with connect() as db:
        db.execute(
            """CREATE TABLE IF NOT EXISTS jobs (
                id TEXT PRIMARY KEY, recording_id TEXT NOT NULL, title TEXT NOT NULL,
                event_type TEXT NOT NULL, audio_path TEXT NOT NULL, status TEXT NOT NULL,
                transcript TEXT, summary_json TEXT, error TEXT, created_at INTEGER NOT NULL
            )"""
        )
        db.execute("UPDATE jobs SET status = 'queued' WHERE status IN ('transcribing', 'summarizing')")


def get_job(job_id: str) -> dict[str, Any]:
    with connect() as db:
        row = db.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Processing job not found")
    return dict(row)


def set_job(job_id: str, status: str, **values: Any) -> None:
    assignments = ["status = ?"]
    arguments: list[Any] = [status]
    for key, value in values.items():
        assignments.append(f"{key} = ?")
        arguments.append(value)
    arguments.append(job_id)
    with connect() as db:
        db.execute(f"UPDATE jobs SET {', '.join(assignments)} WHERE id = ?", arguments)


def authenticate(authorization: str | None) -> None:
    expected = os.getenv("APP_API_TOKEN", "")
    if not expected or authorization != f"Bearer {expected}":
        raise HTTPException(status_code=401, detail="Invalid processing API token")


class Processor:
    def __init__(self) -> None:
        self._whisper: WhisperModel | None = None
        self._openai: OpenAI | None = None

    def whisper(self) -> WhisperModel:
        if self._whisper is None:
            self._whisper = WhisperModel(
                os.getenv("FASTER_WHISPER_MODEL", "small"),
                device="cpu",
                compute_type=os.getenv("FASTER_WHISPER_COMPUTE_TYPE", "int8"),
                download_root="/models",
            )
        return self._whisper

    def openai(self) -> OpenAI:
        if self._openai is None:
            self._openai = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
        return self._openai

    def process(self, job: dict[str, Any]) -> None:
        job_id = job["id"]
        try:
            set_job(job_id, "transcribing")
            segments, _ = self.whisper().transcribe(job["audio_path"], vad_filter=True)
            transcript = " ".join(segment.text.strip() for segment in segments).strip()
            if not transcript:
                raise RuntimeError("No speech was detected in this audio")

            set_job(job_id, "summarizing", transcript=transcript)
            response = self.openai().responses.create(
                model=os.getenv("OPENAI_SUMMARY_MODEL", "gpt-4o-mini"),
                input=[
                    {
                        "role": "system",
                        "content": "Summarize audio transcripts faithfully. Do not invent facts.",
                    },
                    {
                        "role": "user",
                        "content": f"Event title: {job['title']}\nEvent type: {job['event_type']}\n\nTranscript:\n{transcript}",
                    },
                ],
                text={
                    "format": {
                        "type": "json_schema",
                        "name": "event_summary",
                        "strict": True,
                        "schema": {
                            "type": "object",
                            "additionalProperties": False,
                            "properties": {
                                "overview": {"type": "string"},
                                "key_points": {"type": "array", "items": {"type": "string"}},
                                "decisions": {"type": "array", "items": {"type": "string"}},
                                "action_items": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "additionalProperties": False,
                                        "properties": {
                                            "task": {"type": "string"},
                                            "owner": {"type": ["string", "null"]},
                                            "due_date": {"type": ["string", "null"]},
                                        },
                                        "required": ["task", "owner", "due_date"],
                                    },
                                },
                                "open_questions": {"type": "array", "items": {"type": "string"}},
                            },
                            "required": ["overview", "key_points", "decisions", "action_items", "open_questions"],
                        },
                    }
                },
            )
            summary = json.loads(response.output_text)
            set_job(job_id, "completed", transcript=transcript, summary_json=json.dumps(summary))
        except Exception as error:
            set_job(job_id, "failed", error=str(error))
        finally:
            Path(job["audio_path"]).unlink(missing_ok=True)


processor = Processor()
worker_task: asyncio.Task[None] | None = None


async def worker() -> None:
    while True:
        with connect() as db:
            row = db.execute("SELECT * FROM jobs WHERE status = 'queued' ORDER BY created_at LIMIT 1").fetchone()
        if row is None:
            await asyncio.sleep(1)
            continue
        await asyncio.to_thread(processor.process, dict(row))


@asynccontextmanager
async def lifespan(_: FastAPI):
    global worker_task
    initialise_store()
    worker_task = asyncio.create_task(worker())
    yield
    if worker_task:
        worker_task.cancel()


app = FastAPI(title="Vome Processing API", lifespan=lifespan)
origins = [value for value in os.getenv("CORS_ALLOWED_ORIGINS", "").split(",") if value]
if origins:
    app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["GET", "POST"], allow_headers=["Authorization", "Content-Type"])


@app.post("/api/v1/processing-jobs", status_code=202)
async def create_job(
    audio: UploadFile = File(...),
    recording_id: str = Form(...),
    title: str = Form(...),
    event_type: str = Form(...),
    authorization: str | None = Header(default=None),
):
    authenticate(authorization)
    suffix = Path(audio.filename or "").suffix.lower()
    if suffix not in ALLOWED_SUFFIXES:
        raise HTTPException(status_code=415, detail="Supported formats: mp3, m4a, wav")
    job_id = str(uuid.uuid4())
    destination = JOB_DIR / f"{job_id}{suffix}"
    size = 0
    try:
        with destination.open("wb") as output:
            while chunk := await audio.read(1024 * 1024):
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="Audio file exceeds the configured size limit")
                output.write(chunk)
    except Exception:
        destination.unlink(missing_ok=True)
        raise
    finally:
        await audio.close()
    with connect() as db:
        db.execute(
            "INSERT INTO jobs VALUES (?, ?, ?, ?, ?, 'queued', NULL, NULL, NULL, strftime('%s','now'))",
            (job_id, recording_id, title, event_type, str(destination)),
        )
    return {"job_id": job_id, "status": "queued"}


@app.get("/api/v1/processing-jobs/{job_id}")
def job_status(job_id: str, authorization: str | None = Header(default=None)):
    authenticate(authorization)
    job = get_job(job_id)
    return {
        "job_id": job["id"],
        "status": job["status"],
        "transcript": job["transcript"],
        "summary": json.loads(job["summary_json"]) if job["summary_json"] else None,
        "error": job["error"],
    }
