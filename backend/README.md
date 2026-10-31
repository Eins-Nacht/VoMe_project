# VoMe backend processing

Processing runs through the existing authenticated FastAPI API and
`ProcessingJob` database model. Audio remains in the configured filesystem
storage; the database stores metadata, transcripts, and summaries only.

## Provider configuration

Copy `.env.example` to `.env`.

- `PROCESSING_PROVIDER=mock` uses deterministic providers for local development
  and automated tests.
- `PROCESSING_PROVIDER=whisper_openai` enables Faster-Whisper transcription and
  OpenAI summaries. This mode requires `OPENAI_API_KEY`; jobs fail clearly when
  it is missing.

The Whisper model is cached once per backend worker process and reused by
subsequent jobs. The OpenAI key is only read by the backend and is never sent
to Flutter or included in API responses.
