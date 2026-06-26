# Privacy

MacMate is designed as a local-first macOS assistant.

## Local data

- Clipboard history is stored locally under `~/Library/Application Support/MacMate/`.
- Logs are stored locally under `~/Library/Logs/MacMate/`.
- Diagnostics exports are generated locally and are never uploaded automatically.
- API credentials are stored locally by the app and are not committed to this repository.

## Data sent to AI services

MacMate only sends selected text to an AI-compatible service when you explicitly use an AI-backed action, such as AI explanation or manual AI translation. System speech, local pronunciation, pinyin, and local clipboard history do not require a network request.

The app does not bundle an API key. Users must configure their own Base URL, API Key, and model.

## Logs and diagnostics

Logs intentionally avoid recording:

- selected text
- clipboard contents
- API keys
- full prompts
- full AI responses

Diagnostic bundles contain redacted logs, version information, permission status, and configuration summaries with secrets hidden.

## macOS permissions

MacMate may ask for:

- Accessibility: read selected text/location where supported and perform paste operations for clipboard history.
- Input Monitoring: observe global mouse/key events so the selection floating panel can appear after mouse release and disappear when you continue typing/click elsewhere.

If permissions are denied, related features degrade locally; no permission state is uploaded.
