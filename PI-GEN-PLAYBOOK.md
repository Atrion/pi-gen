## 1) What this repo does

- Clones the official [`pi-gen`](https://github.com/RPi-Distro/pi-gen) **arm64** branch on each run
- Injects your **config** (release, locale, SSH, etc.) and custom stages (`lite-extras`, `desktop-extras`, `kiosk-extras`)
- Builds multiple images via a **matrix** in `.github/workflows/build.yml`
- Uploads compressed images (`.img.xz`) and checksums to **one** Release with clear release notes

### Default image settings (from workflow’s config step)
- **Release:** `trixie`
- **Hostname:** `rpi`
- **User:** created on first boot (rename allowed), password set on first boot
- **SSH:** enabled (password login allowed)
- **Locale:** `en_CA.UTF-8`
- **Timezone:** `America/Halifax`
- **Keyboard:** `ca`
- **Compression:** `xz` level `6`

## 2) Build flavors (matrix)

| Flavor        | Stage list                                                   | Output file                              | Notes |
|---|---|---|---|
| `lite-base`   | `stage0 stage1 stage2`                                       | `rpios-arm64-lite-base.img.xz`           | Bare Lite (no extras) |
| `lite`        | `stage0 stage1 ./lite-extras stage2`                         | `rpios-arm64-lite.img.xz`                | Lite + server/dev tools |
| `desktop`     | `stage0 stage1 stage2 stage3 ./desktop-extras stage4`        | `rpios-arm64-desktop.img.xz`             | Standard Desktop + extras |
| `desktop-full`| `stage0 stage1 stage2 stage3 ./desktop-extras stage4 stage5` | `rpios-arm64-desktop-full.img.xz`        | Desktop + Recommended Software |
| `kiosk`       | `stage0 stage1 stage2 stage3 ./kiosk-extras stage4`          | `rpios-arm64-kiosk.img.xz`               | Desktop with Chromium auto-start (kiosk) |

> All flavors are already included in the workflow. You can remove or add flavors by editing the `matrix.include` list.

## 3) How to run a build

1. Open **GitHub → Actions → Build RPi OS arm64… → Run workflow**.
2. Wait for the **build** matrix jobs to complete (one per flavor).
3. The **release** job downloads whatever artifacts exist (`*.img.xz`) and publishes one Release:
   - All `.img.xz`
   - Individual `.img.xz.sha256`
   - Combined `sha256sums.txt`
   - `build-info.txt` (timestamp, commit, runner, release, arch)
   - Human-friendly **Release Notes** (already in the workflow).

### Optional: scheduled builds
Add to `on:` in the workflow:
```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * 1"  # Mondays 03:00 UTC
```

## 4) Where to change things

### 4.1 OS release (e.g., trixie → bookworm)
- In the workflow step that creates `config`, change:
  ```bash
  RELEASE="trixie"
  ```
- In the **release** job `env`, keep `REL: trixie` in sync (used for tag/title).

### 4.2 Locale, timezone, keyboard, SSH
Edit their lines in the **Create pi-gen config** step:
```bash
LOCALE_DEFAULT="en_CA.UTF-8"
TIMEZONE_DEFAULT="America/Halifax"   # or "UTC"
KEYBOARD_KEYMAP="ca"
ENABLE_SSH="1"                       # leave enabled
```

### 4.3 Packages per flavor
- Add/remove packages **one per line** in:
  - `lite-extras/01-packages/00-packages`
  - `desktop-extras/01-packages/00-packages`
  - `kiosk-extras/01-packages/00-packages`
- Heavy deps? Create `00-packages-nr` to install with `--no-install-recommends`.

### 4.4 Kiosk start URL
After flashing, edit the boot partition file:
```
/boot/kiosk-url.txt
```

### 4.5 Add or remove a flavor
In `.github/workflows/build.yml` under `jobs.build.strategy.matrix.include` add an entry like:
```yaml
- flavor: my-flavor
  stage_list: "stage0 stage1 ./my-extras stage2"
  out_name: "rpios-arm64-my-flavor.img.xz"
```
Then create your `my-extras` stage folder (see §6). Nothing else required.

## 5) Release format, tagging & notes

The release job tags like:
```
rpios-<REL>-arm64-YYYYMMDD-<shortsha>
```
and publishes a `name` like:
```
RPi OS arm64 (<REL>) - Images - YYYYMMDD
```
Release notes are included via a `body: |` block that already explains each flavor and common defaults.

## 6) Custom stages layout

Each custom stage can include:
```
<stage>/prerun.sh
<stage>/01-packages/00-packages
<stage>/01-packages/00-packages-nr   # (optional, installs without recommends)
<stage>/files/...                    # overlay into image filesystem
<stage>/NN-run-chroot.sh             # commands run inside chroot
```
This repo includes:
- `lite-extras` (server/dev toolset for Lite)
- `desktop-extras` (extras for Desktop)
- `kiosk-extras` (autologin + startx + Openbox + Chromium in kiosk)

## 7) Verification & flashing

### 7.1 Verify downloads
On Linux/macOS:
```bash
# Option A: verify combined list
sha256sum -c sha256sums.txt

# Option B: verify a single image
sha256sum -c rpios-arm64-desktop.img.xz.sha256
```

### 7.2 Flash to SD
- **Raspberry Pi Imager** or **balenaEtcher** can write `.img.xz` directly.
- On Linux CLI:
  ```bash
  xz -d -c rpios-arm64-desktop.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
  ```

## 8) Right-sizing images (Lite)

If Lite is bigger than you want:
- Move heavy packages (Apache, MariaDB, PHP, Samba, Node/NPM, build-essential) to Desktop flavors
- Use `00-packages-nr` for heavy packages (no recommends)
- Optional space savers (use with care):
  - `/etc/dpkg/dpkg.cfg.d/01_nodoc` with doc/man/locale excludes
  - `/etc/apt/apt.conf.d/90norecommends` to skip recommends
- Add a cleanup script (e.g., `99-clean.sh`) in the stage:
  ```bash
  #!/bin/bash -e
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  journalctl --rotate || true
  journalctl --vacuum-time=1s || true
  ```

## 9) Troubleshooting

### “Artifact not found for name: …” in release job
Your release job is already **tolerant**: it downloads `*.img.xz` via wildcard. If you see a missing artifact error, ensure you replaced the release job with the wildcard version and removed any hard-coded per-flavor download steps.

### “No space left on device”
The build job frees space and relocates Docker’s data-root to `/mnt`. If you still hit limits:
- Temporarily remove a flavor from the matrix
- Use a self-hosted runner with larger disk

### YAML “Unexpected value” / indentation errors
Make sure `release:` is **inside** `jobs:` and that steps are indented consistently with spaces (no tabs).

### QEMU/binfmt issues
The workflow installs `qemu-user-static` and enables binfmt on the host. If Docker can’t run ARM executables, re-check the “Install qemu-user-static” step logs.

### Permissions
Set **Actions → General → Workflow permissions → Read and write** for Releases.

## 10) Local testing (optional)

On a Linux host with Docker and qemu-user-static:
```bash
git clone --branch arm64 https://github.com/RPi-Distro/pi-gen.git
cp config pi-gen/config
cp -r lite-extras desktop-extras kiosk-extras pi-gen/
cd pi-gen
STAGE_LIST="stage0 stage1 ./lite-extras stage2" ./build-docker.sh
```

## 11) Handy snippets

### Add a new flavor
```yaml
- flavor: server-kiosk
  stage_list: "stage0 stage1 ./lite-extras ./kiosk-extras stage2 stage3 stage4"
  out_name: "rpios-arm64-server-kiosk.img.xz"
```

### Change compression level
```bash
COMPRESSION_LEVEL="9"   # smaller artifacts, longer build time
```

### Quick size report inside the image (optional)
Add to a stage:
```bash
#!/bin/bash -e
dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n > /boot/installed-size-${IMG_NAME}.txt
```
