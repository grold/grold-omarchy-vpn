# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-10-06

### Fixed
- **Configuration Import**: Fixed `xdg-desktop-portal` file chooser D-Bus serialization failure. Explicitly registered and serialized `a(sa(us))` filter type structs so clicking "Import .conf" (or pressing `A`) opens the native portal file chooser dialog.
- **Repository Security**: Sanitized unit test data in `tests/tests.cpp` to use dummy mock WireGuard keys and RFC 5737 TEST-NET endpoints.

---

## [0.1.0] - 2026-10-06

### Added
- **WireGuard & AmneziaWG 3.1 Support**: Full parser and engine support for standard WireGuard and AmneziaWG obfuscation parameters (`H1`–`H4`, `S1`–`S4`, `I1`–`I2`, `Jc`, `Jmin`, `Jmax`).
- **Omarchy Shell Status Bar Widget (`grold.vpn`)**: Native Quickshell widget conforming to Omarchy design standards (`PanelHero`, `ToggleSwitch`, `CursorSurface`). Includes live transfer speeds, default profile badges, and right-click instant connection.
- **Standalone Desktop Application (`grold-omarchy-vpn`)**: Qt Quick client adhering to the Omarchy desktop dark theme and live accent color.
- **Keyboard-First Navigation**: Shortcuts help overlay (`?`), toggle (`Space`), connect (`Enter`), navigation (`J`/`K`), default selection (`D`), import (`A`), edit (`E`), and split tunneling (`S`).
- **Split Tunneling Engine**: Exclusive (Bypass) and Inclusive routing modes using Linux cgroups v2 and `nftables`.
- **Firewall Kill Switch**: Atomic packet filtering ensuring zero leaks upon tunnel drop.
- **Systemd Daemon & CLI**: `grold-omarchy-vpnd` background service, `grold-omarchy-vpn-ctl`, and `grold-omarchy-vpn-run`.
- **Arch Packaging**: `PKGBUILD`, systemd service unit, `.desktop` launcher, and scalable icon.
