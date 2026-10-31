# Vome processing service

This service transcribes temporary audio uploads with Faster-Whisper and uses OpenAI only to create a structured summary. The OpenAI key stays in this service's environment; do not put it in the Flutter app.

## Run locally

1. Copy `.env.example` to `.env` and populate `OPENAI_API_KEY` and a long random `APP_API_TOKEN`.
2. From this folder, run `docker compose up --build`.
3. Launch Flutter with matching values:

```powershell
flutter run --dart-define=VOME_API_BASE_URL=http://10.0.2.2:8000 --dart-define=VOME_API_TOKEN=YOUR_APP_API_TOKEN
```

For a physical device, replace `10.0.2.2` with the LAN address of the computer running Docker. The first request downloads the Faster-Whisper `small` model into the Docker volume.

The service deletes each uploaded audio file after processing, whether the job succeeds or fails. The Flutter user's **Keep audio after processing** choice controls only the app-local copy.
