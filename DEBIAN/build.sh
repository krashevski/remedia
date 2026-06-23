#!/usr/bin/env bash
# DEBIAN/build.sh

set -euo pipefail

PKG="remedia"
VERSION="1.0.0"
ARCH="all"

STAGE="build/${PKG}_${VERSION}_${ARCH}"

echo "[BUILD] preparing..."
rm -rf build
mkdir -p "$STAGE"

echo "[BUILD] creating filesystem..."

mkdir -p "$STAGE/usr/lib/remedia"
mkdir -p "$STAGE/usr/bin"
mkdir -p "$STAGE/etc"

mkdir -p "$STAGE/etc/remedia"

echo "[BUILD] copying core..."

cp -r core modules "$STAGE/usr/lib/remedia/"
cp bin/remedia "$STAGE/usr/bin/remedia"
cp bin/remedia-setup "$STAGE/usr/bin/remedia-setup"
cp bin/remedia-doctor "$STAGE/usr/bin/remedia-doctor"

cp -r DEBIAN "$STAGE/"

echo "[BUILD] permissions..."
chmod 755 "$STAGE/DEBIAN/postinst" || true
chmod 755 "$STAGE/DEBIAN/prerm" || true
chmod 755 "$STAGE/DEBIAN/postrm" || true

echo "[BUILD] building .deb..."
dpkg-deb --build --root-owner-group "$STAGE"

echo "[BUILD] done"
ls -lh build/*.deb
