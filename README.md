# Raspberry Pi OS Image Builder (arm64) — GitHub Actions

This repository builds **Raspberry Pi OS (arm64)** images entirely on **GitHub Actions** using the official [`pi-gen`](https://github.com/RPi-Distro/pi-gen) toolchain. Each run publishes images to **GitHub Releases**.

**Build flavors (matrix):**
- `lite-base` — **bare** Raspberry Pi OS Lite (stage2), no extras *(optional; see BUILD.md)*
- `lite` — Lite **plus server/dev tools** (Apache, MariaDB, PHP, Samba, Node.js, etc.)
- `desktop` — Standard Desktop (stage4) + your selected extras
- `desktop-full` — Desktop + **Recommended Software** (stage5)
- `kiosk` — Desktop with **Chromium auto-start (kiosk mode)**

Artifacts are compressed as **`.img.xz`** with compression level **6** and accompanied by **`sha256sums.txt`** and a small **`build-info.txt`** manifest.

---

## Quick start

1. **Fork** this repo to your GitHub account and enable Actions:
   - Repo → **Settings → Actions → General → Workflow permissions → Read and write**.
2. Trigger: **Actions → “Build RPi OS arm64 …” → Run workflow**.
3. When finished, open **Releases** to download the images.

> First boot: user rename is allowed and the password is empty by default. The first-boot wizard will prompt to create/set a user and password. SSH is enabled.

---

## Customize

### Change OS release
Edit the `config` creation step inside `.github/workflows/build.yml`:
```bash
RELEASE="trixie"   # change to "bookworm" or others supported by pi-gen
```
Also update `REL: trixie` in the `release` job (tag name & title).

### Locale, timezone, keyboard
In the same `config` block:
```bash
LOCALE_DEFAULT="en_CA.UTF-8"
TIMEZONE_DEFAULT="America/Halifax"   # or "UTC"
KEYBOARD_KEYMAP="ca"
KEYBOARD_LAYOUT="English (Canada)"
```

### Packages
Each flavor’s extra packages live in:
```
lite-extras/01-packages/00-packages
desktop-extras/01-packages/00-packages
kiosk-extras/01-packages/00-packages
```
Add one package **per line**. For leaner images, put heavy items in `00-packages-nr` to install with **--no-install-recommends**.

### Kiosk URL
After flashing, set the URL by editing the boot partition file:
```
/boot/kiosk-url.txt
```
Default: `about:blank`.

### Versioning & tagging
Releases are tagged like:
```
rpios-<release>-arm64-YYYYMMDD-<shortsha>
```
and include a `build-info.txt` manifest.

---

## What this repo actually does

- Uses GitHub Actions to **clone** upstream `pi-gen` `arm64` branch on each run.
- Injects your `config` + custom stages (`lite-extras`, `desktop-extras`, `kiosk-extras`).
- Builds via `./build-docker.sh`, one flavor per matrix job (disk-safe).
- Publishes all images to **one Release** with checksums + manifest.

---

## Troubleshooting

- **No space left on device**: the workflow frees space and moves Docker’s data-root to `/mnt`. If needed, remove a flavor or use a self-hosted runner with more disk.
- **`qemu-aarch64-static` not found**: the workflow installs `qemu-user-static` and registers binfmt before building.
- **Package not found**: use correct names for Debian (e.g., `usbutils` provides `lsusb`; `chromium` not `chromium-browser`).

---

## License & attribution

This repo orchestrates builds of the official **pi-gen** project. Keep the upstream license file and attribution. See [LICENSE](LICENSE) (mirror of upstream).
