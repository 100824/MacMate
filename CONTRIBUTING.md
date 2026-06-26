# Contributing

Thanks for helping improve MacMate.

## Development requirements

- Apple Silicon Mac
- macOS 14 or newer
- Xcode Command Line Tools
- Swift Package Manager

## Build and test

```bash
./scripts/run_tests.sh
./scripts/build_app.sh
```

To produce a local DMG:

```bash
./scripts/package_dmg.sh
```

The DMG is ad-hoc signed and not notarized.

## Pull request checklist

- Keep secrets out of source code, commits, screenshots, and logs.
- Do not log selected text, clipboard contents, API keys, prompts, or AI response bodies.
- Run `./scripts/run_tests.sh` before submitting.
- If you change packaging, verify the generated DMG can be mounted and opened.
- If you change permissions behavior, update `README.md` and `PRIVACY.md`.

## Code style

Prefer small, focused changes. Keep user-facing copy in Simplified Chinese unless a feature is explicitly English-only.
