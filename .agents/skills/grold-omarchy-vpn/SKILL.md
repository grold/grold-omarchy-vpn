---
name: grold-omarchy-vpn
description: >-
  Work on, build, test, package, debug, and publish grold-omarchy-vpn.
  Use when developing, debugging, modifying, or testing the WireGuard / AmneziaWG
  desktop client, the daemon (grold-omarchy-vpnd), the CLI tools (grold-omarchy-vpn-ctl/run),
  the status bar widget plugin (grold.vpn), or handling releases and packaging.
---

# grold-omarchy-vpn Development & Maintenance

This skill guides development, testing, architecture patterns, and release procedures for `grold-omarchy-vpn` — the WireGuard and AmneziaWG 3.1 VPN management suite for Omarchy Linux.

---

## 1. Project Architecture

The project consists of 4 integrated components:

1. **Background Daemon (`daemon/` -> `grold-omarchy-vpnd`)**:
   - C++ system daemon communicating via Unix domain socket `/run/grold-omarchy-vpn/daemon.sock` (JSON-RPC).
   - Manages WireGuard / AmneziaWG interfaces (`awg`, `awg-quick`, `wg`, `wg-quick`).
   - Implements split tunneling using Linux cgroups v2 (`/sys/fs/cgroup/grold-vpn`) and `nftables`.
   - Manages firewall Kill Switch and DNS rules.
   - Collects telemetry (Rx/Tx bytes, rates, last handshakes, uptime).
   - Systemd unit: `daemon/grold-omarchy-vpnd.service`.

2. **Standalone Desktop Application (`src/` -> `grold-omarchy-vpn`)**:
   - C++ and Qt Quick / QML GUI following the Omarchy Material Dark design system.
   - Watches `~/.local/state/omarchy/current/theme/colors.toml` via `Theme` to live-follow the desktop accent color.
   - Keyboard-first navigation (`?` shortcuts overlay, `Space` toggle, `Enter` connect, `Down`/`J`, `Up`/`K`, `D` default, `A` portal import, `E` edit, `S` split tunnel, `Delete` delete, `Q` quit).
   - Uses `PortalFilePicker` (`org.freedesktop.portal.FileChooser` over D-Bus) for file dialogs.
   - Persists profiles in `~/.config/grold-omarchy-vpn/profiles/` and default profile in `~/.config/grold-omarchy-vpn/default-profile`.

3. **Status Bar Widget (`plugin/` -> `grold.vpn`)**:
   - Native Quickshell plugin installed to `~/.config/omarchy/plugins/grold.vpn/` (or `/usr/share/omarchy/shell/plugins/grold.vpn/`).
   - Conforms strictly to Omarchy system UI primitives: `PanelHero`, `ToggleSwitch`, `CursorSurface`, `PanelSeparator`.
   - Right-click on panel icon connects/disconnects directly to the default profile.
   - Left-click opens popup panel with live transfer metrics, profile switching, and app launcher.

4. **CLI Utilities (`cli/`)**:
   - `grold-omarchy-vpn-ctl`: Query status and command daemon from terminal or scripts.
   - `grold-omarchy-vpn-run`: Run terminal commands or apps inside target routing cgroups (supports `--bypass`).

---

## 2. Common Workflows & Commands

### Build & Test
Always run `./bin/build` and `./bin/test` after modifying code:
```bash
# Build all components (daemon, GUI app, CLI tools, tests)
./bin/build

# Run Qt unit tests (tests execute offscreen)
./bin/test

# Run GUI offscreen to verify zero QML runtime errors or binding loops
env QT_QPA_PLATFORM=offscreen timeout 2s ./build/src/grold-omarchy-vpn || test $? -eq 124

# Install updated binary to local user path
install -m 755 build/src/grold-omarchy-vpn ~/.local/bin/grold-omarchy-vpn
```

### Quickshell Widget Testing & Verification
When modifying files in `plugin/`:
```bash
# Sync files to user's quickshell plugins directory
mkdir -p ~/.config/omarchy/plugins/grold.vpn
cp -r plugin/* ~/.config/omarchy/plugins/grold.vpn/

# Rescan plugins via Quickshell IPC
qs ipc call shell rescanPlugins

# Test toggling the widget popup via IPC
qs ipc call grold.vpn toggle

# Verify Quickshell journal logs are clean (no warnings, binding loops, or errors)
journalctl --user -u quickshell.service -n 50 --no-pager
```

---

## 3. Important Implementation Guidelines

### Protocol & Config Parsing
- AmneziaWG 3.1 configurations contain obfuscation parameters: `H1`–`H4` (can be decimal numbers or ranges like `79463399-782207545`), `S1`–`S4` (byte sizes), `I1`–`I2` (e.g. `<r 246>`), `Jc` (packet count), `Jmin`, `Jmax`.
- Standard WireGuard configs must remain 100% compatible.
- All config parser logic is in `src/configparser.{h,cpp}`. Ensure `tests/tests.cpp` passes.

### Security & Sanitization Policy
- **NEVER** commit real private keys, public keys, or real VPN server IP addresses to the repository or test files.
- Always use RFC 5737 documentation IP prefixes (`198.51.100.0/24`, `192.0.2.0/24`, `203.0.113.0/24`) and dummy keys (`aaaaaaaa...=`, `eeeeeeee...=`) in tests and examples.

### D-Bus & Desktop Portal File Chooser
- The portal file picker (`src/portalfilepicker.{h,cpp}`) calls `org.freedesktop.portal.FileChooser.OpenFile`.
- The `filters` option strictly requires signature `a(sa(us))` (`FilterList`). Custom stream operators are registered via `qDBusRegisterMetaType`. Never pass raw `QVariantList` for filters.

### Theme & Colors
- Do not hardcode static colors for highlighted or active states.
- Read dynamic colors from `theme.accent` and `theme.accentForeground`.
- Main background uses Omarchy dark neutral `#0e0e10`, cards use `#141416`, borders use `#27272a`.

---

## 4. Release & Publishing Checklist

When releasing a new version:

1. **Update Version Numbers**:
   - `pkgbuild/PKGBUILD`: update `pkgver=X.Y.Z` and reset `pkgrel=1`.
   - `src/main.cpp`: update `app.setApplicationVersion("X.Y.Z")`.

2. **Update `CHANGELOG.md`**:
   - Add a new section `## [X.Y.Z] - YYYY-MM-DD` following [Keep a Changelog](https://keepachangelog.com/).
   - Document `Added`, `Changed`, `Fixed`, or `Security` entries.

3. **Verify Build & Tests**:
   ```bash
   ./bin/build
   ./bin/test
   ```

4. **Commit & Push Tag**:
   ```bash
   git add PKGBUILD src/main.cpp CHANGELOG.md
   git commit -m "chore(release): prepare vX.Y.Z"
   git push origin master
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

5. **GitHub Actions**:
   - The workflow `.github/workflows/release.yml` will automatically extract the changelog for that tag, compile in Arch Linux container, run tests, and publish the release with `.pkg.tar.zst` and `.tar.gz` packages.
