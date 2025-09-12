#!/bin/bash -e
# Standard pi-gen stage contract: copy previous stage rootfs
if [ ! -d "${ROOTFS_DIR}" ]; then
  mkdir -p "${ROOTFS_DIR}"
fi
if [ -d "${PREV_ROOTFS_DIR}" ]; then
  rsync -aHAXx --numeric-ids --delete "${PREV_ROOTFS_DIR}/" "${ROOTFS_DIR}/"
fi
