# Build & Maintenance Guide

This document explains how the workflow is wired, how to add/remove flavors, and how to customize images safely.

## 1) Repository layout

```
.github/workflows/build.yml   # CI pipeline (matrix builds + release)
lite-extras/                  # custom stage injected before stage2
  prerun.sh
  01-packages/00-packages
desktop-extras/               # custom stage injected before stage4
  prerun.sh
  01-packages/00-packages
kiosk-extras/                 # custom stage for kiosk flavor
  prerun.sh
  01-packages/00-packages
  02-run-chroot.sh            # sets autologin + startx + Chromium kiosk
```

> The workflow creates `config` on the runner (if absent) and clones `pi-gen` at build time.

## 2) Flavors (matrix)

Defined in `.github/workflows/build.yml` under `strategy.matrix.include`.

Examples:
```yaml
- flavor: lite-base
  stage_list: "stage0 stage1 stage2"
  out_name: "rpios-arm64-lite-base.img.xz"

- flavor: lite
  stage_list: "stage0 stage1 ./lite-extras stage2"
  out_name: "rpios-arm64-lite.img.xz"

- flavor: desktop
  stage_list: "stage0 stage1 stage2 stage3 ./desktop-extras stage4"
  out_name: "rpios-arm64-desktop.img.xz"

- flavor: desktop-full
  stage_list: "stage0 stage1 stage2 stage3 ./desktop-extras stage4 stage5"
  out_name: "rpios-arm64-desktop-full.img.xz"

- flavor: kiosk
  stage_list: "stage0 stage1 stage2 stage3 ./kiosk-extras stage4"
  out_name: "rpios-arm64-kiosk.img.xz"
```

Add or remove flavors by editing this list—no other changes needed.

## 3) Adding packages

- Put *recommended* installs in `01-packages/00-packages`.
- Put *no-recommends* installs in `01-packages/00-packages-nr`.
- Create additional steps with `NN-run-chroot.sh` for apt pinning, custom `.deb`, or configuration changes.

Example `02-run-chroot.sh`:
```bash
#!/bin/bash -e
apt-get update
apt-get install -y mytool
```

## 4) Overlay files

Anything under `<stage>/files/` is copied into the image at the same path.

Examples:
```
desktop-extras/files/etc/motd
desktop-extras/files/home/pi/Desktop/Readme.txt
kiosk-extras/files/etc/xdg/openbox/autostart
```

## 5) Release metadata

The release job computes:
- **Tag**: `rpios-${REL}-arm64-YYYYMMDD-<shortsha>`
- **Manifest**: `build-info.txt` (date, commit, runner, release, arch)
- **Checksums**: `sha256sums.txt`

Change `REL:` in the `release` job when you change `RELEASE` in `config`.

## 6) Common size reductions (Lite)

- Move heavy items to Desktop flavor.
- Use `00-packages-nr` for `apache2 mariadb-server php samba nodejs npm build-essential`.
- Add (optional) files:
  - `/etc/dpkg/dpkg.cfg.d/01_nodoc` to drop docs/manpages/locales.
  - `/etc/apt/apt.conf.d/90norecommends` to skip recommends.
- Add `99-clean.sh`:
  ```bash
  #!/bin/bash -e
  apt-get clean
  rm -rf /var/lib/apt/lists/*
  journalctl --rotate || true
  journalctl --vacuum-time=1s || true
  ```

## 7) Scheduling

To rebuild on a cadence, add to the workflow:
```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * 1"  # Mondays 03:00 UTC
```

## 8) Local testing (optional)

Run `pi-gen` locally with Docker on a Linux machine:
```
git clone --branch arm64 https://github.com/RPi-Distro/pi-gen.git
cp config pi-gen/config
cp -r lite-extras desktop-extras kiosk-extras pi-gen/
cd pi-gen && STAGE_LIST="stage0 stage1 ./lite-extras stage2" ./build-docker.sh
```
(Requires `qemu-user-static` and binfmt registrations.)
