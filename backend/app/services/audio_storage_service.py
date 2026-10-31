from pathlib import Path
from uuid import uuid4

from app.core.config import get_settings

ALLOWED_EXTENSIONS = {"mp3", "m4a", "wav"}
CONTENT_TYPES = {
    "mp3": {"audio/mpeg", "audio/mp3", "application/octet-stream"},
    "m4a": {"audio/mp4", "audio/x-m4a", "application/octet-stream"},
    "wav": {"audio/wav", "audio/x-wav", "audio/wave", "application/octet-stream"},
}
RESPONSE_MEDIA_TYPES = {
    "mp3": "audio/mpeg",
    "m4a": "audio/mp4",
    "wav": "audio/wav",
}


class AudioStorageError(Exception):
    pass


class AudioStorageService:
    def __init__(self, root: Path | None = None) -> None:
        self.root = root or Path(get_settings().audio_storage_dir)

    def create_path(self, extension: str) -> tuple[Path, str]:
        extension = extension.lower().lstrip(".")
        if extension not in ALLOWED_EXTENSIONS:
            raise AudioStorageError("Unsupported audio format")
        self.root.mkdir(parents=True, exist_ok=True)
        relative_path = f"{uuid4().hex}.{extension}"
        return self.root / relative_path, relative_path

    def resolve(self, relative_path: str) -> Path:
        root = self.root.resolve()
        path = (root / relative_path).resolve()
        if path != root and root not in path.parents:
            raise AudioStorageError("Invalid audio path")
        return path

    def delete(self, relative_path: str) -> None:
        path = self.resolve(relative_path)
        if path.exists():
            path.unlink()
