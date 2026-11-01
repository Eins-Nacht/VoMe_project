# VoMe backend processing

Processing runs through the existing authenticated FastAPI API and
`ProcessingJob` database model. Uploaded audio is stored only temporarily
while Faster-Whisper reads it; the database stores metadata, transcripts, and
summaries, never permanent audio binaries.

Temporary audio is removed in a processing `finally` block after transcription
and on cancellation before processing starts. Files older than
`TEMPORARY_AUDIO_MAX_AGE_SECONDS` are removed during backend startup.

## Provider configuration

Copy `.env.example` to `.env`.

- Faster-Whisper is the mandatory transcription provider. Configure its model
  with the `WHISPER_*` settings below.
- Summary generation is currently disabled in the normal processing workflow.
  The existing LLM settings and provider architecture remain available for a
  future integration, but `OPENAI_API_KEY` is not required for transcription.

Whisper defaults to the `small` model on CPU with `int8` compute. Set
`WHISPER_MODEL`, `WHISPER_DEVICE`, `WHISPER_COMPUTE_TYPE`, and optionally
`WHISPER_LANGUAGE=th` for Thai. Leaving `WHISPER_LANGUAGE` empty enables
automatic language detection. `WHISPER_MODEL_DIR` controls the model cache;
Docker uses `/models`, which is backed by the `whisper-models` volume.
The older `FASTER_WHISPER_MODEL` and `FASTER_WHISPER_COMPUTE_TYPE` variables
remain accepted for compatibility and are used when the corresponding new
variables are not set.

The first real transcription downloads the selected model into that cache.
Model storage and CPU memory requirements increase with model size. The Docker
image installs FFmpeg, and Faster-Whisper uses PyAV for MP3, M4A, and WAV
decoding. GPU execution requires a compatible CUDA runtime and corresponding
Faster-Whisper/CTranslate2 setup; CPU is the configured default.

The OpenAI key, when configured for future use, is only read by the backend and
is never sent to Flutter or included in API responses. A successful transcript
is committed before the processing request completes. The processing result
endpoint returns that transcript directly. The legacy summary endpoints remain
for compatibility but return a clear STT-only-mode response and are never
called automatically.

Completed jobs also expose `transcription_status`:

- `success`: meaningful transcript was produced.
- `invalid_audio`: the file is empty or cannot be decoded.
- `no_speech`: decoding succeeded but Whisper returned no text.
- `unclear_speech`: every returned segment met all conservative quality
  indicators (`no_speech_prob >= 0.85`, `avg_logprob <= -1.5`, and
  `compression_ratio >= 2.4`). A single weak segment is not enough.
- `failed`: model initialization, decoding, or another technical error failed.

Non-success transcription outcomes are completed processing jobs with no
transcript or summary. Technical failures remain failed jobs.

Examples:

```text
# STT-only processing
WHISPER_MODEL=Systran/faster-whisper-small
WHISPER_DEVICE=cpu
WHISPER_COMPUTE_TYPE=int8
```
