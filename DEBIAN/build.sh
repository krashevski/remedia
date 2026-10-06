#!/usr/bin/env bash
# DEBIAN/build.sh

set -euo pipefail

PKG="remedia"
VERSION="1.3.2"
ARCH="all"

STAGE="build/${PKG}_${VERSION}_${ARCH}"

echo "[BUILD] preparing..."
rm -rf build
mkdir -p "$STAGE"

echo "[BUILD] creating filesystem..."

mkdir -p "$STAGE/usr/lib/remedia"
mkdir -p "$STAGE/usr/bin"
mkdir -p "$STAGE/etc/remedia"
mkdir -p "$STAGE/DEBIAN"

echo "[BUILD] copying core..."

cp -r core modules "$STAGE/usr/lib/remedia/"

cp bin/remedia "$STAGE/usr/bin/remedia"
cp bin/remedia-setup "$STAGE/usr/bin/remedia-setup"
cp bin/remedia-doctor "$STAGE/usr/bin/remedia-doctor"

cp DEBIAN/control "$STAGE/DEBIAN/"
cp DEBIAN/postinst "$STAGE/DEBIAN/"
cp DEBIAN/prerm "$STAGE/DEBIAN/"
cp DEBIAN/postrm "$STAGE/DEBIAN/"

echo "[BUILD] creating filter sets..."

FILTERSET_DEST="$STAGE/usr/share/remedia/filter-sets"

mkdir -p "$FILTERSET_DEST"

cp -a \
    docs/filter-sets/Open_Camera/Open_Camera_Spots_correction \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/Open_Camera/Open_Camera_Deband \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/Open_Camera/Open_Camera_Deband_studio \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/Open_Camera/Open_Camera_Deband_studio_bright \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/OPPO_RENO/Oppo_Reno_11F_Concert \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/OPPO_RENO/OPPO_RENO_Pub \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/Stabilization/Stabilizer_Gimbal \
    "$FILTERSET_DEST/"

cp -a \
    docs/filter-sets/Stabilization/Stabilizer_Smooth_manual_panorama \
    "$FILTERSET_DEST/"

echo "[BUILD] permissions..."

chmod 755 "$STAGE/DEBIAN/postinst" || true
chmod 755 "$STAGE/DEBIAN/prerm" || true
chmod 755 "$STAGE/DEBIAN/postrm" || true

chmod 755 "$STAGE/usr/bin/remedia"
chmod 755 "$STAGE/usr/bin/remedia-setup"
chmod 755 "$STAGE/usr/bin/remedia-doctor"

chmod 644 "$FILTERSET_DEST"/*

echo "[BUILD] building .deb..."

dpkg-deb --build --root-owner-group "$STAGE"

echo "[BUILD] done"

ls -lh build/*.deb
