# Contributing

Thanks for your interest in Port Manager.

## Development Setup

```bash
flutter pub get
flutter run -d macos
```

## Checks

Before opening a pull request, run:

```bash
dart format lib
flutter analyze
flutter build macos --debug
```

If you change platform-specific Windows code, also test on Windows when possible:

```bash
flutter build windows --debug
```

## Pull Requests

- Keep changes focused.
- Include screenshots or short recordings for UI changes.
- Mention the operating system used for validation.
- Avoid committing generated build output.

## Code Style

- Prefer Flutter built-in Material components where possible.
- Keep desktop layouts compact and predictable.
- Avoid adding dependencies unless they clearly reduce complexity.
