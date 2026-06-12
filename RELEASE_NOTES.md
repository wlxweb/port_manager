# Port Manager 1.0.0

Initial open-source release of Port Manager.

## Highlights

- Inspect local TCP and UDP port usage.
- Search and filter port lists.
- View process details, command line, user, PID, parent PID, and network endpoints.
- Open local HTTP services from listening TCP ports.
- Copy port addresses and terminate processes.
- Paginated table for smoother desktop rendering.

## macOS

Build:

```bash
flutter build macos --release
```

Package:

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/macos/Build/Products/Release/port_manager.app \
  port_manager-macos-v1.0.0.zip
```

## Known Notes

- Some system processes may require elevated permissions to terminate.
- Browser opening assumes the selected local port serves HTTP.
