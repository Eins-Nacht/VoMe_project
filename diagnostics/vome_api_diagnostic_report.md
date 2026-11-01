# VoMe API Diagnostic Report

Generated: 2026-11-01T10:17:39.284400+00:00

## 1. Environment Information
- Host: Windows-11-10.0.26200-SP0; Python: 3.14.6
- API base: `http://127.0.0.1:8000`; prefix: `/api/v1`
- Source defaults: SQLite `sqlite:///./audiary.db`, temporary storage `./uploads/audio`, max upload 50 MiB.
- Source defaults select Mock STT and Mock LLM unless environment overrides them. Faster-Whisper and OpenAI are configurable independently.
- Diagnostic audio: `C:\Users\sheeg\Downloads\VoMe_project\backend\uploads\audio\83f03986318d49f5a01ea253e1afdd85.m4a`; title: `VoMe API Diagnostic 13832e691328`.
- IDs: event `62`, audio `24`, job `24`, summary `2` (returned by the audio-summary persistence lookup).

## 2. Backend Process Information
- Process inventory saved in `diagnostics/backend_processes.txt`.
- Port 8000 was tested; no process was terminated.
- The responding API is `127.0.0.1:8000`.

## 3. Live OpenAPI Route Verification
- OpenAPI status: 200; title/version: Audiary API / 1.0.0
- `POST /api/v1/events`: present
- `GET /api/v1/events`: present
- `POST /api/v1/audio`: present
- `POST /api/v1/processing/audio/{audio_record_id}`: present
- `GET /api/v1/processing/{job_id}`: present
- `GET /api/v1/processing/{job_id}/result`: present
- `POST /api/v1/processing/{job_id}/summary`: MISSING
- `POST /api/v1/processing/audio/{audio_record_id}/summary`: MISSING
- `GET /api/v1/summaries`: present
- `GET /api/v1/summaries/{summary_id}`: present
- `GET /api/v1/audio/{audio_record_id}/summary`: present

## 4. Authentication Test
- Registration: 201 {"id": 2, "email": "vome-diagnostic-13832e691328@example.com", "display_name": "VoMe API Diagnostic", "is_active": true, "created_at": "2026-11-01T10:17:36"}
- Login: 200; JWT redacted.
- Existing event/audio inspection: 200 / 200.

## 5. Event Creation Test
- 201 {"id": 62, "title": "VoMe API Diagnostic 13832e691328", "category": "Diagnostic", "created_at": "2026-11-01T10:17:37", "updated_at": "2026-11-01T10:17:37"}

## 6. Audio Upload Test
- Existing repository `.m4a` audio used; multipart fields `event_id`, `client_recording_id`, `file`, MIME `audio/mp4`.
- 201 {"id": 24, "event_id": 62, "filename": "83f03986318d49f5a01ea253e1afdd85.m4a", "format": "m4a", "size": 22577, "duration": null, "audio_path": "016078a4931c404cb32a6c29164affc3.m4a", "created_at": "2026-11-01T10:17:37", "updated_at": "2026-11-01T10:17:37", "client_recording_id": "diagnostic-13832e691328"}

## 7. Processing Job Test
- Start: 202 {"id": 24, "audio_record_id": 24, "status": "pending", "transcription_status": null, "error_message": null, "created_at": "2026-11-01T10:17:37", "updated_at": "2026-11-01T10:17:37"}
- Transitions: `[{"timestamp": "2026-11-01T10:17:37.142043+00:00", "status": "processing", "error_message": null}, {"timestamp": "2026-11-01T10:17:39.154203+00:00", "status": "completed", "error_message": null}]`
- Poll elapsed: 2.03 seconds
- Result: 200 {"id": 24, "audio_record_id": 24, "status": "completed", "transcription_status": "success", "error_message": null, "created_at": "2026-11-01T10:17:37", "updated_at": "2026-11-01T10:17:37", "audio": {"id": 24, "event_id": 62, "filename": "83f03986318d49f5a01ea253e1afdd85.m4a", "format": "m4a", "size": 22577, "duration": null, "audio_path": "016078a4931c404cb32a6c29164affc3.m4a", "created_at": "2026-11-01T10:17:37", "updated_at": "2026-11-01T10:17:37", "client_recording_id": "diagnostic-13832e691328"}, "event_title": "VoMe API Diagnostic 13832e691328", "event_category": "Diagnostic", "transcript_text": "Mock transcript for 83f03986318d49f5a01ea253e1afdd85.m4a", "transcript_language": "en", "summary": "Mock summary: Mock transcript for 83f03986318d49f5a01ea253e1afdd85.m4a", "key_points": ["Mock processing completed"], "action_items": [], "keywords": ["mock", "audio"], "category": "General", "mood": "Neutral", "action_status": "No Action", "message": null}

## 8. Transcript / STT Test
- Classification: **Mock STT (confirmed by response prefix)**
- Language: `en`
- Transcript: "Mock transcript for 83f03986318d49f5a01ea253e1afdd85.m4a"

## 9. Summary Generation Test
- Job-ID endpoint: 404 {"detail": "Not Found"}
- Audio-ID fallback: 404 {"detail": "Not Found"}
- Repeated fallback: not executed
- Provider classification: **Mock LLM (confirmed in the processing result response)**; summary ID `2`.

## 10. Summary Persistence Test
- Summary by ID: not executed because the job/audio POST routes were absent and the diagnostic token was intentionally not persisted.
- Summary by audio: 200 {"id": 2, "transcript_id": 23, "audio_record_id": 24, "client_recording_id": "diagnostic-13832e691328", "event_id": 62, "event_title": "VoMe API Diagnostic 13832e691328", "audio_filename": "83f03986318d49f5a01ea253e1afdd85.m4a", "summary": "Mock summary: Mock transcript for 83f03986318d49f5a01ea253e1afdd85.m4a", "key_points": ["Mock processing completed"], "action_items": [], "keywords": ["mock", "audio"], "category": "General", "mood": "Neutral", "action_status": "No Action", "created_at": "2026-11-01T10:17:37", "updated_at": "2026-11-01T10:17:37"}
- Summary list status: 200.
- The processing result and audio-summary lookup confirm that summary ID `2` was already persisted by the live runtime. Duplicate POST behavior could not be tested because both summary-generation POST routes are missing from the live OpenAPI.

## 11. Flutter?Backend API Compatibility
- Flutter sends authenticated multipart `POST /api/v1/audio`, then `POST /api/v1/processing/audio/{audio_record_id}`, polls `GET /api/v1/processing/{job_id}`, gets `/result`, and sends `POST /api/v1/processing/{job_id}/summary`.
- Live job-ID summary route: **MISSING**.

## 12. Failed Requests and Tracebacks
- Sanitized failures: `[{"method": "POST", "url": "http://127.0.0.1:8000/api/v1/processing/24/summary", "status": 404, "response": {"detail": "Not Found"}}, {"method": "POST", "url": "http://127.0.0.1:8000/api/v1/processing/audio/24/summary", "status": 404, "response": {"detail": "Not Found"}}]`
- No traceback was returned in HTTP responses.

## 13. Root Cause Analysis
- The live API is missing both summary-generation POST routes despite the checked-in source defining them. This indicates a stale/different running backend process or imported checkout.
- The live processing result already contained `"summary": "Mock summary: ..."`, and the audio-summary GET returned persisted summary ID `2`. This proves the running process is not the current source behavior: it is summarizing during/inside processing while also not exposing the current POST summary routes.

## 14. Recommended Fixes
1. Run one backend process from `C:\Users\sheeg\Downloads\VoMe_project\backend` and verify `/openapi.json` contains the job-ID summary POST route before starting Flutter.
2. Keep Flutter endpoint paths unchanged; they match the checked-in source.
3. Configure `STT_PROVIDER=faster_whisper` and `LLM_PROVIDER=mock` or `openai` explicitly when real inference is required.

## 15. Overall Test Results
- Health: 200; auth: passed; event: passed; upload: passed.
- Processing: completed; job summary: failed/missing; fallback: failed; persistence-by-audio: passed (summary ID `2`).
- Real Faster-Whisper: no/not confirmed; real LLM: no/not confirmed.

Credentials and tokens were not written to diagnostic files.
