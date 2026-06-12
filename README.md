# Port Manager

Port Manager is a lightweight Flutter desktop app for inspecting local port usage, viewing process details, opening local web services, copying addresses, and terminating processes when needed.

The current UI is optimized for macOS, with Windows support in the service layer.

## Features

- View TCP and UDP port usage.
- Search by port, PID, process name, local address, or remote address.
- Filter by protocol.
- Inspect detailed process and network information.
- Open listening TCP ports in the browser.
- Copy `localhost:<port>` and process identifiers.
- Terminate processes from the UI.
- Paginated table rendering for smoother large port lists.

## Screenshots

Screenshots are not included yet. A good first contribution would be adding macOS and Windows screenshots to `docs/images/`.

## Requirements

- Flutter SDK compatible with Dart `^3.12.0`.
- macOS or Windows.
- macOS: `lsof` and `ps` are used to collect port and process details.
- Windows: `netstat`, `tasklist`, and `wmic` are used where available.

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Run on macOS:

```bash
flutter run -d macos
```

Build a macOS release:

```bash
flutter build macos --release
```

Build a Windows release:

```bash
flutter build windows --release
```

## Release Packaging

After building macOS release, the app is generated at:

```text
build/macos/Build/Products/Release/port_manager.app
```

You can package it as a zip:

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/macos/Build/Products/Release/port_manager.app \
  port_manager-macos-v1.0.0.zip
```

## Notes

- Terminating system processes may require elevated privileges.
- Opening a port in the browser assumes the service speaks HTTP on `localhost:<port>`.
- Windows process detail collection depends on commands available on the host system.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening an issue or pull request.

## Security

Please report security issues privately. See [SECURITY.md](SECURITY.md).

## License

Port Manager is released under the [MIT License](LICENSE).
