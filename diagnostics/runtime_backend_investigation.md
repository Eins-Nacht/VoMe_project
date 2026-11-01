# VoMe Runtime Backend Investigation

Generated: 2026-11-01 17:20-17:23 local time

## Scope and safety

This was a read-only investigation. No process was killed, restarted, or modified. No
application source, database schema, configuration, or records were changed.

## 1. Backend listeners

`Get-NetTCPConnection -State Listen` found exactly one listener on the requested ports:

| Address | Port | Owning PID | State |
|---|---:|---:|---|
| 127.0.0.1 | 8000 | 35224 | Listen |

Ports 8001 and 8002 were not listening. Requests to
`http://127.0.0.1:8001/openapi.json` and
`http://127.0.0.1:8002/openapi.json` failed with connection errors.

## 2. Process identity and lineage

The backend process tree is:

| PID | Parent PID | Executable | Command line | Working directory | Started |
|---:|---:|---|---|---|---|
| 37508 | 35904 | `C:\Windows\system32\cmd.exe` | `C:\Windows\system32\cmd.exe /c ""C:\Users\sheeg\Downloads\VoMe_project\run_vome.bat""` | not queried; launcher path is the repository | 17:12:57 |
| 23344 | 37508 | `C:\Windows\system32\cmd.exe` | `cmd /k "python -m alembic upgrade head && python -m uvicorn app.main:app --reload"` | `C:\Users\sheeg\Downloads\VoMe_project\backend\` | 17:12:57 |
| 35536 | 23344 | `C:\Program Files\WindowsApps\PythonSoftwareFoundation.PythonManager_26.4.240.0_x64__3847v3x7pw1km\python.exe` | `python -m uvicorn app.main:app --reload` | `C:\Users\sheeg\Downloads\VoMe_project\backend\` | 17:12:57 |
| 35224 | 35536 | `C:\Users\sheeg\AppData\Local\Python\pythoncore-3.14-64\python.exe` | `"...python.exe" -m uvicorn app.main:app --reload` | `C:\Users\sheeg\Downloads\VoMe_project\backend\` | 17:12:57 |
| 27232 | 35224 | `C:\Users\sheeg\AppData\Local\Python\pythoncore-3.14-64\python.exe` | `"...python.exe" -c "from multiprocessing.spawn import spawn_main; ..."` | `C:\Users\sheeg\Downloads\VoMe_project\backend\` | 17:12:57 |

PID 35224 is the process associated with the port-8000 listener. PID 27232 is the
reload-created serving child. The launcher uses the WindowsApps Python command
resolver, which starts the actual Uvicorn processes with the AppData Python 3.14
executable. No virtual environment was present in `backend`.

## 3. Live OpenAPI comparison

`GET http://127.0.0.1:8000/openapi.json` returned HTTP 200, with title `Audiary API`
and version `1.0.0`.

Relevant live paths:

- Present: `POST /api/v1/processing/audio/{audio_record_id}`
- Present: `GET /api/v1/processing/{job_id}`
- Present: `DELETE /api/v1/processing/{job_id}`
- Present: `GET /api/v1/processing/{job_id}/result`
- **Missing: `POST /api/v1/processing/{job_id}/summary`**
- **Missing: `POST /api/v1/processing/audio/{audio_record_id}/summary`**
- Present: `GET /api/v1/audio/{audio_record_id}/summary`
- Present: `GET /api/v1/summaries/{summary_id}`

The same OpenAPI request on ports 8001 and 8002 could not connect because those
ports have no listener.

## 4. Checked-in source and local import verification

The checked-in route composition is:

- [processing.py](../backend/app/api/v1/processing.py): `@router.post("/{job_id}/summary")`
  at line 205 and `@router.post("/audio/{audio_record_id}/summary")` at line 217.
- [router.py](../backend/app/api/v1/router.py): includes `processing_router`.

Using the exact executable used by the serving process and the confirmed backend
working directory, a fresh local import resolved:

- `app`: `C:\Users\sheeg\Downloads\VoMe_project\backend\app\__init__.py`
- `app.main`: `C:\Users\sheeg\Downloads\VoMe_project\backend\app\main.py`
- `app.api.v1.processing`: `C:\Users\sheeg\Downloads\VoMe_project\backend\app\api\v1\processing.py`
- `app.api.v1.router`: `C:\Users\sheeg\Downloads\VoMe_project\backend\app\api\v1\router.py`

That fresh import registered both summary POST routes. This is a confirmed
source/import result, not an introspection response from inside PID 27232.

Direct source-module introspection inside the live process was not performed:
doing so would require debugger attachment or code injection, which is not
appropriate for this read-only safety scope. The process command, working
directory, executable, and fresh import all point to the repository checkout,
but they cannot prove what objects were already loaded in the serving process.

## 5. Alternate checkout and environment check

The recursive search under `C:\Users\sheeg\Downloads` found only one
`app\api\v1\processing.py`:

`C:\Users\sheeg\Downloads\VoMe_project\backend\app\api\v1\processing.py`

The broader user-directory search found Cursor project-metadata directories, but
no additional `processing.py` source copy in them. The backend contains no
`.venv`, `venv`, or alternate environment directory.
The process uses Python 3.14 from
`C:\Users\sheeg\AppData\Local\Python\pythoncore-3.14-64\`.

Therefore, no second active VoMe source checkout or virtual environment was found
to explain the route discrepancy. The two Python executable paths are the
WindowsApps launcher and its resolved AppData interpreter, not two backend
installations.

## 6. Summary generation behavior

The checked-in implementation separates the stages:

- `_run_job` in [processing.py](../backend/app/api/v1/processing.py) calls only
  `service.run_transcription(job_id)` (line 45).
- `run_transcription` in
  [processing_service.py](../backend/app/services/processing_service.py) persists
  the transcript and language, then removes temporary audio. It does not call
  `generate_summary`.
- `generate_summary` reads the persisted transcript and is called by the two
  checked-in summary POST handlers.
- `_result_response` only reads an existing `transcript.summary`.

The prior live diagnostic created a new record and observed a Mock transcript and
a persisted Mock summary in the completed processing result before either
summary POST route was available. This cannot be produced by the checked-in
`_run_job` path for a new record unless a summary was created by another process
or by different loaded application code. SQLite has no trigger that generates
summaries; the database trigger query returned no triggers.

## 7. Root cause assessment

### Confirmed facts

1. PID 35224 owns `127.0.0.1:8000`.
2. Its reload child PID 27232 runs from the expected repository `backend`
   directory with the expected AppData Python 3.14 executable.
3. The live OpenAPI document omits both checked-in summary POST routes.
4. A fresh import using that same executable and working directory includes both
   routes.
5. The live behavior includes a persisted summary during processing, while the
   checked-in worker does not generate summaries.
6. No alternate checkout, virtual environment, or listener on 8001/8002 was found.

### Most likely explanation

The serving process has a stale or otherwise divergent in-memory application
module graph: it is not serving the same route table and worker implementation
represented by the current files, despite having the expected process command,
working directory, and Python executable. The in-memory divergence may have been
inherited from an earlier application load or caused by the reload process not
reloading the changed module graph.

This is a supported hypothesis, not a directly proven memory inspection. The
available safe evidence rules out a second active listener, an alternate checkout
under Downloads, and a different virtual environment, but cannot inspect Python
module objects inside a running process without attaching a debugger or injecting
code.

## 8. Conclusion

The request to `127.0.0.1:8000` is handled by PID 35224 and its serving child
PID 27232, both launched from the repository backend directory. The checked-in
source and a fresh import from the same executable register the missing summary
routes, but the live OpenAPI route table does not. The runtime therefore does not
match the current source in memory. The existing Mock summary is further evidence
that the runtime worker is an older/different implementation that performs
summary generation during processing.

No process was terminated or restarted, and no application data was changed.
